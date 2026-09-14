#!/usr/bin/env bash
set -euo pipefail

# Oracle release helper (npm + GitHub)
# Phases: gates | artifacts | publish | smoke | tag | github-release | all
# Defaults to using the guardrail runner (MCP_RUNNER or ./runner).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
RUNNER="${MCP_RUNNER:-./runner}"
PACKAGE_VERSION="$(node -p "require('./package.json').version")"
VERSION="${VERSION:-$PACKAGE_VERSION}"
PACKAGE_NAME="$(node -p "require('./package.json').name")"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT_DIR/.release-artifacts}"
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG-ZETA.md}"
TGZ="oracle-${VERSION}.tgz"
REPO="${REPO:-zeta987/oracle}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "Invalid VERSION: expected a version such as 0.18.1 or 0.18.1-beta.1." >&2
  exit 1
fi

if [[ "${CODEX_MANAGED_BY_NPM:-}" == "1" ]]; then
  export NPM_CONFIG_PROGRESS=false
  export npm_config_progress=false
fi

banner() { printf "\n==== %s ====" "$1"; printf "\n"; }
run() { echo ">> $*" >&2; "$@"; }

phase_gates() {
  banner "Gates (check/lint/test/build)"
  run "$RUNNER" pnpm run check
  run "$RUNNER" pnpm run lint
  run "$RUNNER" pnpm run test
  run "$RUNNER" pnpm run build
}

phase_artifacts() (
  banner "Artifacts (npm pack + checksums)"
  run "$RUNNER" pnpm run build
  local packdir packed
  packdir=$(mktemp -d)
  trap 'rm -rf "$packdir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  chmod 700 "$packdir"
  # shellcheck disable=SC2016 # Template literals must expand in JavaScript, not Bash.
  packed=$(run "$RUNNER" npm pack --json --pack-destination "$packdir" | node -e '
    const fs = require("node:fs");
    const path = require("node:path");
    // npm <= 11 prints an array; npm >= 12 prints an object keyed by package name.
    const parsed = JSON.parse(fs.readFileSync(0, "utf8"));
    const packageName = process.argv[2];
    const pack = Array.isArray(parsed) ? parsed[0] : parsed[packageName];
    if (pack?.name !== packageName || pack?.version !== process.argv[1]) {
      throw new Error(`Unexpected npm pack metadata: ${pack?.name}@${pack?.version}; expected ${packageName}@${process.argv[1]}`);
    }
    if (typeof pack.filename !== "string" || !pack.filename.endsWith(".tgz") || path.basename(pack.filename) !== pack.filename) {
      throw new Error("npm pack did not return a tarball basename");
    }
    process.stdout.write(pack.filename);
  ' "$VERSION" "$PACKAGE_NAME")

  mkdir -p "$ARTIFACT_DIR"
  rm -f "$ARTIFACT_DIR/$TGZ"*
  mv "$packdir/$packed" "$ARTIFACT_DIR/$TGZ"
  cd "$ARTIFACT_DIR"
  shasum -a 1 "$TGZ" > "$TGZ.sha1"
  shasum -a 256 "$TGZ" > "$TGZ.sha256"
  cat "$TGZ.sha1" "$TGZ.sha256"
)

phase_publish() {
  banner "Publish to npm"
  [[ "$VERSION" == "$PACKAGE_VERSION" ]] || { echo "VERSION $VERSION differs from package.json version $PACKAGE_VERSION" >&2; exit 1; }
  [[ -f "$ARTIFACT_DIR/$TGZ" ]] || { echo "Missing tested artifact: $ARTIFACT_DIR/$TGZ" >&2; exit 1; }
  [[ -f "$ARTIFACT_DIR/$TGZ.sha256" ]] || { echo "Missing checksum: $ARTIFACT_DIR/$TGZ.sha256" >&2; exit 1; }
  # shellcheck disable=SC2016 # Template literals must expand in JavaScript, not Bash.
  node -e '
    const fs = require("node:fs");
    const path = require("node:path");
    const { createHash } = require("node:crypto");
    const archive = process.argv[1];
    const checksumFile = process.argv[2];
    const stored = fs.readFileSync(checksumFile, "utf8").trimEnd();
    const match = /^([a-fA-F0-9]{64})  ([^\r\n]+)$/.exec(stored);
    if (!match || match[2] !== path.basename(archive)) {
      throw new Error(`Invalid checksum for ${path.basename(archive)} in ${checksumFile}`);
    }
    const actual = createHash("sha256").update(fs.readFileSync(archive)).digest("hex");
    if (actual !== match[1].toLowerCase()) {
      throw new Error(`SHA-256 mismatch for ${archive}`);
    }
    console.log(`Prepared SHA-256: ${actual}`);
  ' "$ARTIFACT_DIR/$TGZ" "$ARTIFACT_DIR/$TGZ.sha256"
  run node "$ROOT_DIR/scripts/packed-cli-smoke.mjs" "$ARTIFACT_DIR/$TGZ"
  run "$RUNNER" npm publish "$ARTIFACT_DIR/$TGZ" --tag latest --access public --ignore-scripts
  run "$RUNNER" npm view "$PACKAGE_NAME@$VERSION" version
  run "$RUNNER" npm view "$PACKAGE_NAME" time
}

phase_smoke() {
  banner "Smoke test in empty dir"
  local tmp=/tmp/oracle-empty
  rm -rf "$tmp" && mkdir -p "$tmp"
  ( cd "$tmp" && npx -y "$PACKAGE_NAME@$VERSION" "Smoke from empty dir" --dry-run )
}

phase_tag() {
  banner "Tag and push"
  git tag -s "v${VERSION}" -m "Release ${VERSION}"
  git push origin "v${VERSION}"
}

extract_release_notes() {
  # shellcheck disable=SC2016 # Template literals must expand in JavaScript, not Bash.
  node -e '
    const fs = require("node:fs");
    const version = process.argv[1];
    const changelogFile = process.argv[2];
    const lines = fs.readFileSync(changelogFile, "utf8").split(/\r?\n/);
    const heading = `## ${version}`;
    const start = lines.findIndex((line) => line === heading || line.startsWith(`${heading} `));
    if (start < 0) throw new Error(`Missing ${changelogFile} section for ${version}`);
    let end = start + 1;
    while (end < lines.length && !lines[end].startsWith("## ")) end++;
    const body = lines.slice(start + 1, end);
    while (body.length && !body[0].trim()) body.shift();
    while (body.length && !body[body.length - 1].trim()) body.pop();
    if (!body.length) throw new Error(`Empty ${changelogFile} section for ${version}`);
    process.stdout.write(`${body.join("\n")}\n`);
  ' "$VERSION" "$CHANGELOG_FILE"
}

phase_github_release() (
  banner "GitHub Release (upload, verify, publish)"
  run gh auth status
  local tag="v$VERSION" asset tmp release_info is_draft local_sha256 remote_sha256 local_asset_sha256
  local assets=("$TGZ" "$TGZ.sha1" "$TGZ.sha256")
  for asset in "${assets[@]}"; do
    if [[ ! -f "$ARTIFACT_DIR/$asset" ]]; then
      echo "Missing artifact: $ARTIFACT_DIR/$asset; run scripts/release.sh artifacts first." >&2
      exit 1
    fi
  done
  (cd "$ARTIFACT_DIR" && shasum -a 256 -c "$TGZ.sha256" && shasum -a 1 -c "$TGZ.sha1")
  local_sha256=$(shasum -a 256 "$ARTIFACT_DIR/$TGZ")
  local_sha256="${local_sha256%% *}"
  if ! git ls-remote --exit-code --tags origin "refs/tags/$tag"; then
    echo "Tag $tag must exist on origin; run scripts/release.sh tag first." >&2
    exit 1
  fi

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  chmod 700 "$tmp"
  extract_release_notes > "$tmp/notes.md"
  if release_info=$(gh release view "$tag" --repo "$REPO" --json isDraft,assets --jq '.isDraft, .assets[].name' 2> "$tmp/release-error"); then
    is_draft="${release_info%%$'\n'*}"
    [[ "$is_draft" == true || "$is_draft" == false ]] || { echo 'Invalid release metadata from gh.' >&2; exit 1; }
    echo "Reusing existing release $tag without changing its notes."
  else
    # Only a missing release permits creation; auth/network failures must stop here.
    cat "$tmp/release-error" >&2
    if [[ "$(cat "$tmp/release-error")" != *"release not found"* ]]; then
      echo "Unable to inspect release $tag; refusing to create it." >&2
      exit 1
    fi
    local create_args=(--draft --verify-tag --title "$VERSION" --notes-file "$tmp/notes.md")
    if [[ "$VERSION" == *-* ]]; then
      create_args+=(--prerelease)
    fi
    run gh release create "$tag" --repo "$REPO" "${create_args[@]}"
    is_draft=true
    release_info=true
  fi

  local uploads=()
  for asset in "${assets[@]}"; do
    if [[ $'\n'"$release_info"$'\n' == *$'\n'"$asset"$'\n'* ]]; then
      gh release download "$tag" --repo "$REPO" --dir "$tmp" --pattern "$asset"
      remote_sha256=$(shasum -a 256 "$tmp/$asset")
      remote_sha256="${remote_sha256%% *}"
      local_asset_sha256=$(shasum -a 256 "$ARTIFACT_DIR/$asset")
      local_asset_sha256="${local_asset_sha256%% *}"
      if [[ "$remote_sha256" != "$local_asset_sha256" ]]; then
        printf 'Error: existing asset %s differs.\n  local sha256: %s\n  remote sha256: %s\n' "$asset" "$local_asset_sha256" "$remote_sha256" >&2
        # shellcheck disable=SC2016 # Backticks quote a suggested command, not command substitution.
        printf 'Delete it manually with `gh release delete-asset %s %s --repo %s`, then rerun this phase.\n' "$tag" "$asset" "$REPO" >&2
        exit 1
      fi
      echo "Identical asset already uploaded; skipping $asset."
    else
      uploads+=("$ARTIFACT_DIR/$asset")
    fi
  done
  if [[ ${#uploads[@]} -gt 0 ]]; then
    run gh release upload "$tag" --repo "$REPO" "${uploads[@]}"
  fi

  # A failed download/hash check exits before the draft can be published.
  REPO="$REPO" RELEASE_ASSET_PUBLIC_URL_CHECK=0 RELEASE_ASSET_EXPECT_SHA256="$local_sha256" \
    "$ROOT_DIR/scripts/verify-release-assets.sh" "$tag"
  if [[ "$is_draft" == true ]]; then
    if [[ "$VERSION" == *-* ]]; then
      run gh release edit "$tag" --repo "$REPO" --draft=false
    else
      run gh release edit "$tag" --repo "$REPO" --draft=false --latest
    fi
  else
    echo "Release $tag is already published; skipping publication."
  fi
  # The publish event starts the tap workflow, whose own preflight also waits for the CDN.
  REPO="$REPO" RELEASE_ASSET_PUBLIC_URL_CHECK=1 RELEASE_ASSET_EXPECT_SHA256="$local_sha256" \
    "$ROOT_DIR/scripts/verify-release-assets.sh" "$tag"
)

usage() {
  cat <<'EOF'
Usage: scripts/release.sh [phase]

Phases (run individually or all):
  gates          pnpm check, lint, test, build
  artifacts      npm pack + sha1/sha256 in ARTIFACT_DIR
  publish        verify checksum and packed CLI, then publish that tarball to latest
  smoke          empty-dir npx <package-name>@<version> --dry-run
  tag            create a signed v<version> tag and push it to origin
  github-release upload/verify assets, publish GitHub Release, verify public URL
  all            gates, artifacts, publish, smoke, tag, github-release

Environment:
  MCP_RUNNER (default ./runner) - guardrail wrapper
  VERSION    (default from package.json)
  ARTIFACT_DIR (default .release-artifacts/ under the repo root)
  CHANGELOG_FILE (default CHANGELOG-ZETA.md) - GitHub release notes
  REPO       (default zeta987/oracle) - GitHub release repository
EOF
}

main() {
  local phase="${1:-all}"
  case "$phase" in
    gates) phase_gates ;;
    artifacts) phase_artifacts ;;
    publish) phase_publish ;;
    smoke) phase_smoke ;;
    tag) phase_tag ;;
    github-release) phase_github_release ;;
    all) phase_gates; phase_artifacts; phase_publish; phase_smoke; phase_tag; phase_github_release ;;
    *) usage; exit 1 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
