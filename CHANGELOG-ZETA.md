# Zeta release notes

The version format is `<upstream-version>-zeta.<revision>`. The numeric Zeta
revision increases for each published fork revision. Upstream release history
remains in [CHANGELOG.md](CHANGELOG.md).

## 0.20.3-zeta.1 - 2026-09-15

- Publish the fork as `@zeta987/oracle`, retaining the `oracle` and `oracle-mcp`
  commands and shipping prebuilt JavaScript, usage documentation, and the Oracle skill.
- Recognize the exact Traditional Chinese `最新的` model option when selecting
  and verifying GPT-6 Astra, while rejecting unrelated labels.
- Preserve uploaded-file answer Markdown and recover late response content by
  recapturing the same assistant message when its final text grows.
- Retry transient Windows lock-directory cleanup failures without removing a
  replacement directory or another controller's lock.
- Document GPT-5.6 Sol Extra High and GPT-6 Pro browser commands, verified file
  uploads, and the text-paste fallback with submission-state checks.
