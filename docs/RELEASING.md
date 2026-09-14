# Zeta npm release procedure

This guide publishes `@zeta987/oracle` from `zeta987/oracle`. It does not publish the upstream package or update the upstream Homebrew tap.

## Version

Use `<upstream-version>-zeta.<revision>`. The first release based on upstream 0.20.3 is `0.20.3-zeta.1`. For each subsequent fork release:

```powershell
npm run version:zeta
```

For a new upstream base, explicitly set the new base with revision 1 using `npm version <base>-zeta.1 --no-git-tag-version`. Update [CHANGELOG-ZETA.md](../CHANGELOG-ZETA.md); preserve upstream history in CHANGELOG.md.

## Prepare and validate

1. Confirm `npm whoami` is the authorized publisher and check that the target version does not already exist. Never display auth tokens.
2. Check package name, version, repository, license, public access, and the unchanged `oracle` / `oracle-mcp` bin names.
3. Install the locked dependencies, then run the repository checks and tests appropriate to the release:
   `pnpm install --frozen-lockfile --ignore-scripts`, `pnpm run check`, `pnpm test`, `pnpm run build`, and `pnpm test:packed-cli`.
4. Keep the tested tarball under the ignored `.release-artifacts/` directory. Inspect its file list, package identity, version, required built entrypoints, skill and docs. Personal config, sessions, credentials and temporary audit files must not be present.
5. Commit with the configured signature, verify it, and push only to the user's fork. Create and verify a signed `v<version>` tag for the release. Retain the exact tested tarball and checksum.

## Publish the tested artifact

```powershell
npm publish ./.release-artifacts/zeta987-oracle-0.20.3-zeta.1.tgz --access public --tag latest --ignore-scripts
```

Use the actual tarball filename and version for later releases. `latest` is intentional even though `-zeta.N` has SemVer prerelease syntax; it is the fork's normal update channel.

If npm requests interactive login or an OTP, let the account owner complete it. Keep the pending operation and do not restart publishing blindly. Never request or print a long-lived token to work around an authentication error.

## Verify publication

```powershell
npm view @zeta987/oracle version dist-tags dist.integrity --json
```

Compare the published identity/integrity with the tested artifact. Install from npm into a clean temporary directory or prefix and verify `oracle --version`, CLI/MCP entrypoints, and the packaged skill. Migrate any old global `@steipete/oracle` link separately before installing the new package, because both packages provide the same command names.

A GitHub Release may be added using the matching CHANGELOG-ZETA.md entry and exact tested assets when requested. GitHub Actions trusted publishing can automate future releases after its npm package trust is configured; do not assume that trust already exists.
