import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";
import { expect, test } from "vitest";

const proofTimeoutMs = process.platform === "win32" ? 300_000 : 90_000;

test(
  "built service honors host Chrome routing without launching a local browser",
  async () => {
    const { stdout } = await promisify(execFile)(
      process.execPath,
      [path.resolve("scripts/serve-attach-proof.mjs")],
      { timeout: proofTimeoutMs },
    );
    for (const mode of ["flags", "config", "environment", "classic"])
      expect(stdout).toContain(`PASS ${mode}:`);
  },
  proofTimeoutMs + 5000,
);
