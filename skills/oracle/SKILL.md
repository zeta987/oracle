---
name: oracle
description: Use the Oracle CLI for a second-model review with selected files, browser or API execution, and recoverable sessions. Apply to debugging, architecture review, refactoring, and cross-validation when Oracle is requested or authorized.
---

# Oracle consultations

Oracle sends a prompt and selected context to an advisory model. Check its answer
against the repository and relevant tests before making changes. Follow the
user's current instructions and existing external-consultation authorization;
installing this skill does not authorize a new provider or a different task.

## Local installation and defaults

Use the installed `oracle` command (`Get-Command oracle -All` locates Windows
shims). Do not switch to
`npx @steipete/oracle` just to invoke it: the downloaded package can differ from
the installed build. Check `oracle --version` and `oracle --help --verbose` on
first use in an environment; inspect the actual implementation when help text
lags supported options.

For a locally maintained fork, build it and use `npm link --ignore-scripts`
from its stable checkout when that installation change is requested. Keep the
checkout, dependencies, and `dist` in place; rebuild after source changes.
Ordinary `npm update -g` preserved this link in an isolated npm 12.0.2 check;
an explicit registry installation can replace it. Do not switch an existing
installation merely because this skill was loaded.

The user configuration is `~/.oracle/config.json` (JSON5), unless
`ORACLE_HOME_DIR` selects another home. Prefer an explicit model and effort for
each consultation. The two browser recipes below select GPT-5.6 Sol Extra High
or GPT-6 Pro (Astra), with explicit model selection. Preserve an explicit
user request for another model, effort, or transport. Configuration and skills
do not change the calling agent's model or permissions.

Use the original signed-in Windows user's execution environment when browser
attachment or session access requires it. Use the host's narrow approval
mechanism when necessary; do not copy credentials or replace the user's home.
Follow other hosts' normal permission mechanisms rather than copying Codex
shell parameters into their commands.

## Browser model and effort

| Requested target               | Model argument        | Browser effort argument                                 |
| ------------------------------ | --------------------- | ------------------------------------------------------- |
| GPT-5.6 Sol xhigh / Extra High | `--model gpt-5.6-sol` | `--browser-thinking-time xhigh` (alias of `extra-high`) |
| GPT-6 Pro (Astra)              | `--model gpt-6-pro`   | `--browser-thinking-time pro`                           |

Use these browser arguments, not API-only `--reasoning-effort`. The spelling is
`xhigh`, not `xihgh`. Sol Extra High and Sol Pro are different tiers.

### GPT-6 Astra selection

Oracle's Astra-capable builds support these browser mappings:

- `gpt-6-astra` selects the advanced picker's `Latest` / localized equivalent.
- `gpt-6-pro` is a browser alias for the same model with Pro effort by default.
- Use `--browser-thinking-time pro` with `gpt-6-astra` to request Pro explicitly.
- Use `--browser-model-strategy select` when a particular model is required.
  `current` retains the active model; `ignore` skips selection. Neither is proof
  that the requested model was selected.

Model and effort are separate. Look for verified model-selection evidence and
verified thinking-selection evidence in the stored session. In the current UI,
`Latest` / `最新的` together with the `6 Pro` composer pill is Astra Pro selection evidence;
a generic `Pro` label or a `5.6 Pro` pill is insufficient. UI labels demonstrate
selection, not independent attestation of the server-side model. `Latest` may
change in future releases: recheck its generation when ChatGPT's lineup changes.

If Astra or Pro cannot be selected, report the missing condition and use another
route only when authorized. Do not silently downgrade or click ChatGPT's
`Answer now` button. Let Pro finish, preserving the session for reattachment.

Unpatched 0.20.3 builds can reject the Traditional Chinese `最新的` radio before
submission. Use a build containing its exact-label selection and verification
fix. Changing only the skill/config or using `current` is not that fix.

## Preview, execute, recover

1. Choose the smallest useful context. A connectivity check needs only a prompt;
   code analysis needs the relevant files, constraints, and prior observations.
2. Preview with the same model, effort, engine, and files as the real run.
3. Execute once, record the printed session ID, and verify the returned evidence.
4. After a detach or timeout, inspect that session before starting another run.

PowerShell-compatible examples (replace the task and file selection):

```powershell
oracle --engine browser --model gpt-5.6-sol --browser-thinking-time xhigh --browser-model-strategy select --dry-run full --files-report --prompt "Review this module for correctness." --file "src/module/**"
oracle --engine browser --model gpt-5.6-sol --browser-thinking-time xhigh --browser-model-strategy select --prompt "Review this module for correctness." --file "src/module/**"
oracle --engine browser --model gpt-6-pro --browser-thinking-time pro --browser-model-strategy select --dry-run full --files-report --prompt "Review this module for correctness." --file "src/module/**"
oracle --engine browser --model gpt-6-pro --browser-thinking-time pro --browser-model-strategy select --prompt "Review this module for correctness." --file "src/module/**"
oracle status --hours 72
oracle session <session-id> --render
```

When the local config enables `browser.attachRunning`, Oracle opens a dedicated
tab in the existing Chrome-compatible browser and does not need cookie copying.
Allow the browser's remote-debugging prompt if it appears. Do not change browser
profiles or synchronize cookies merely because attachment needs approval.

Use `--followup <session-id>` only when continuing that consultation is intended.
To preserve a conversation for follow-up, set `--browser-archive never` when
starting it; successful non-project one-shots otherwise archive automatically.
Sessions live under `~/.oracle/sessions` unless `ORACLE_HOME_DIR` is set. Inspect
`meta.json`, `output.log`, and available transcript artifacts without exposing
credentials. Use a 3-to-5-word slug for a readable session ID. `--force` starts a
new identical request; it is not a recovery mechanism.

## Files and prompts

Repeat `--file` for paths, directories, or globs; prefix exclusions with `!`.
For example: `--file "src/**" --file "!src/**/*.test.ts"`. Globs honor
`.gitignore`, do not follow symlinks, and need explicit dot segments for hidden
paths. The default single-file limit is 1 MB; inspect `--files-report` or
`--dry-run json` before expanding it. Model context limits and browser upload
limits are separate; do not infer a browser payload budget from the API window.

Do not attach credentials, private keys, or `.env` contents. Include the task,
relevant stack and paths, exact failures, constraints, and desired answer format.
Each fresh consultation starts without the calling agent's conversation history;
explicit follow-ups use the saved conversation.

### Uploads and text-paste fallback

`--browser-attachments auto` usually pastes small text/source inputs directly
into the composer; it is not proof of a file upload. To test actual upload, use
`--browser-attachments always` and confirm upload readiness and that the answer
uses information available only in the file. In `auto`, the current inline/upload
decision uses approximately 60,000 composer characters, not an API token limit.

If an upload fails or stays pending, inspect its existing session and browser
state first. If the prompt was submitted or submission is uncertain, recover
that conversation instead of resending it. Do not loop on the same failed upload.
After a confirmed pre-submission upload failure, text/source inputs may use the
already-authorized paste fallback while preserving the model, effort, task, and
selected files:

```powershell
oracle --engine browser --model gpt-5.6-sol --browser-thinking-time xhigh --browser-model-strategy select --browser-attachments never --dry-run full --prompt "Review the selected files." --file "src/module/**"
oracle --engine browser --model gpt-5.6-sol --browser-thinking-time xhigh --browser-model-strategy select --browser-attachments never --prompt "Review the selected files." --file "src/module/**"
```

Remove forced bundling flags for this fallback. `never` makes Oracle paste the
resolved text contents, including file labels, without using the OS clipboard.
Preview the complete text before sending; reduce or deliberately split oversized
context instead of truncating it. Raw PDF, Office, image, and other binary inputs
cannot be pasted this way. Extract and verify the necessary text first when text
alone satisfies the task; retain a real upload when layout or images matter.

For manual handoff, use `oracle --render --prompt "..." --file "..."`.
Add `--copy-markdown` only when clipboard replacement is wanted. Rendering creates
a bundle, not a model answer or completed consultation.

## Explicit API use

Use API mode only when that provider and any associated usage cost are authorized.
Existing applicable authorization persists. Browser access does not establish
API access. Do not auto-fallback to API after a browser failure.

For authorized GPT-6 Astra API Pro execution, the existing CLI accepts:

```powershell
oracle --engine api --model gpt-6-astra --reasoning-mode pro --reasoning-effort max --wait --prompt "Review this architecture." --file "docs/architecture.md"
```

`gpt-6-pro` is browser-only; use `gpt-6-astra` plus API reasoning settings.
API reasoning settings do not control the browser picker. Check provider routing
with `oracle --route --model gpt-6-astra` or the installed doctor's provider
preflight without printing secrets. This skill does not assert live API access.

Return the answer or incomplete state, session reference, actual transport,
requested model/effort, available selection evidence, and any unverified
constraint that matters to the request.
