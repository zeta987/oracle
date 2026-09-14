import { execFileSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, delimiter, dirname, join, resolve } from "node:path";

const repoRoot = process.cwd();
const { name: packageName, version: packageVersion } = JSON.parse(
  readFileSync(join(repoRoot, "package.json"), "utf8"),
);
if (typeof packageName !== "string" || typeof packageVersion !== "string") {
  throw new Error("package.json must contain a package name and version");
}
if (process.argv.length > 3) {
  throw new Error("Usage: node scripts/packed-cli-smoke.mjs [prepared-archive.tgz]");
}
const tempParent = realpathSync(tmpdir());
const tmpRoot = mkdtempSync(join(tempParent, "oracle-packed-cli-"));

function run(command, args, options = {}) {
  return execFileSync(command, args, {
    cwd: options.cwd ?? repoRoot,
    encoding: "utf8",
    stdio: options.inherit ? "inherit" : ["ignore", "pipe", "pipe"],
  });
}

function runNpm(args, options = {}) {
  if (process.platform !== "win32") {
    return run("npm", args, options);
  }

  const searchDirs = [...(process.env.PATH ?? "").split(delimiter), dirname(process.execPath)];
  const candidates = [
    process.env.npm_execpath,
    ...searchDirs
      .filter(Boolean)
      .map((directory) => join(directory, "node_modules", "npm", "bin", "npm-cli.js")),
  ];
  const npmCli = candidates.find(
    (candidate) =>
      candidate && basename(candidate).toLowerCase() === "npm-cli.js" && existsSync(candidate),
  );
  if (!npmCli) {
    throw new Error("Could not locate npm-cli.js for the current Node installation");
  }
  return run(process.execPath, [npmCli, ...args], options);
}

try {
  let archivePath;
  if (process.argv[2]) {
    archivePath = realpathSync(resolve(repoRoot, process.argv[2]));
    if (!archivePath.endsWith(".tgz")) {
      throw new Error("Prepared archive must be a .tgz file");
    }
  } else {
    runNpm(["pack", "--ignore-scripts", "--pack-destination", tmpRoot]);
    const tarball = readdirSync(tmpRoot).find((entry) => entry.endsWith(".tgz"));
    if (!tarball) {
      throw new Error("npm pack did not produce a .tgz file");
    }
    archivePath = join(tmpRoot, tarball);
  }
  const archivePackage = JSON.parse(run("tar", ["-xOzf", archivePath, "package/package.json"]));
  if (archivePackage.name !== packageName || archivePackage.version !== packageVersion) {
    throw new Error(
      `Archive contains ${archivePackage.name}@${archivePackage.version}; expected ${packageName}@${packageVersion}`,
    );
  }

  const installDir = join(tmpRoot, "install");
  mkdirSync(installDir);
  writeFileSync(join(installDir, "package.json"), '{"private":true}\n');
  runNpm(["install", "--ignore-scripts", "--no-audit", "--no-fund", archivePath], {
    cwd: installDir,
  });
  const packageDir = join(installDir, "node_modules", ...packageName.split("/"));
  const cliPath = join(packageDir, "dist", "bin", "oracle-cli.js");
  const skillPath = join(packageDir, "skills", "oracle", "SKILL.md");
  if (!existsSync(skillPath)) {
    throw new Error("packed package is missing skills/oracle/SKILL.md");
  }
  const version = run(process.execPath, [cliPath, "--version"], { cwd: installDir }).trim();
  if (version !== packageVersion) {
    throw new Error(`packed CLI reports version ${version}; expected ${packageVersion}`);
  }
  const help = run(process.execPath, [cliPath, "--help", "--verbose"], { cwd: installDir });

  for (const expected of [
    "--no-azure",
    "--provider <provider>",
    "--http-timeout",
    "--allow-partial",
    "--preflight",
    "docs",
  ]) {
    if (!help.includes(expected)) {
      throw new Error(`packed CLI help is missing ${expected}`);
    }
  }
  console.log("Packed CLI help smoke: ok");
} finally {
  const cleanupTarget = realpathSync(tmpRoot);
  if (
    dirname(cleanupTarget) !== tempParent ||
    !basename(cleanupTarget).startsWith("oracle-packed-cli-")
  ) {
    console.error(`Refusing to remove unexpected temporary path: ${cleanupTarget}`);
    process.exitCode = 1;
  } else {
    rmSync(cleanupTarget, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
  }
}
