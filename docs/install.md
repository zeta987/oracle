---
title: Install
description: "Install the prebuilt @zeta987/oracle fork from npm. Node 24+ required."
---

## Install the Zeta fork

```bash
npm install -g @zeta987/oracle
oracle --version
```

Requires Node.js 24 or newer. The npm package includes built JavaScript; users do not need Git, pnpm, or a local source build. Keep browser authentication and personal configuration local to each computer.

If the upstream package or its development link owns the same commands, migrate once:

```bash
npm uninstall -g @steipete/oracle
npm install -g @zeta987/oracle
```

This does not remove the source checkout behind an old npm link or your `~/.oracle` state.

## Update

```bash
npm update -g @zeta987/oracle
# Or update all global packages:
npm update -g
oracle --version
npm view @zeta987/oracle version
```

Releases use `<upstream-version>-zeta.<revision>`, such as `0.20.3-zeta.1`, and are deliberately published to this package's `latest` tag. A GitHub commit alone is not an npm release.

## Run without installing

```bash
npx -y @zeta987/oracle --help
# Pin a specific published fork release:
npx -y @zeta987/oracle@0.20.3-zeta.1 --version
```

## Browser and API setup

Use your own signed-in Chrome-compatible browser for ChatGPT automation. See [Browser Mode](browser-mode.md) for manual login and attach-running setup. API use is optional and requires your own configured provider.

The package includes `skills/oracle/SKILL.md`; install it separately into the host's actual skill directory. `npm root -g` locates the global package root. Installing or updating the CLI does not overwrite personal skills or settings.

## State paths

| Path                       | Contents                                              |
| -------------------------- | ----------------------------------------------------- |
| `~/.oracle/config.json`    | Defaults in JSON5                                     |
| `~/.oracle/sessions/<id>/` | Run logs, bundles, transcripts and selection evidence |

Override the state root with `ORACLE_HOME_DIR`. See [Configuration](configuration.md) for supported fields.

## Source development and migration details

See [the fork guide](../README-ZETA.md) for clone/link development, command-path checks, revision increments, and text-paste fallback.

The original project's Homebrew distribution installs the upstream Oracle, not this scoped npm fork. Upstream history and attribution remain available at [steipete/oracle](https://github.com/steipete/oracle).
