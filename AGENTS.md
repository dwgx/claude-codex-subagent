# claude-codex-subagent Agent Rules

This repository packages a Claude Code skill that teaches Claude to delegate
expensive work to local `codex exec`. The job of every agent in this repo is to
keep that delegation workflow accurate, current, and directly runnable.

## Repository Role

- `skills/codex-subagent/SKILL.md` is the source of truth for Claude behavior.
- `scripts/codex-dispatch.sh` is the executable reference implementation.
- `docs/codex-dispatch-guide.md` is the detailed parameter and workflow guide
  for both Claude and Codex.
- `docs/prompt-and-agent-patterns.md` is the public guide for prompt, agent,
  skill, command, result-handling, and publication patterns.
- `personas/*.md` are prompt templates. Their frontmatter must stay simple:
  `persona`, `sandbox`, `effort`, and `when-to-use`.

## Codex CLI Baseline

Target Codex CLI 0.141.0 or newer.

- Prefer `--sandbox workspace-write` for normal local repo work.
- Do not introduce new `--full-auto` examples. It is a deprecated compatibility
  alias; scripts may accept `full-auto` as a user-facing alias only if they emit
  `--sandbox workspace-write`.
- Use `--dangerously-bypass-approvals-and-sandbox` only for tasks that truly need
  shell network, cross-workspace access, global installs, or as a documented
  Windows sandbox fallback.
- Use helper `--search` for current public web facts when shell network is not
  needed; direct `codex exec` uses `--config web_search="live"`.
- Use `--json`, `-o/--output-last-message`, and `--output-schema` when the
  result is consumed by automation.
- Keep `--skip-git-repo-check` in all `codex exec` examples and wrappers.
- Treat resume as a separate parameter surface: `--cd`, `--profile`,
  `--add-dir`, and non-bypass `--sandbox` are fresh-session context flags and
  should be rejected by the helper on `--resume`; `--model`, `--config`,
  `--json`, `-o`, `--output-schema`, `--ephemeral`, and explicit bypass are
  resume-time controls in Codex CLI 0.141.0.

## Editing Rules

- Keep the project zero-dependency: markdown plus bash only.
- If you change Codex flags or sandbox rules, update all of these together:
  `skills/codex-subagent/SKILL.md`, `scripts/codex-dispatch.sh`,
  `scripts/doctor.sh`, `docs/codex-dispatch-guide.md`, `README.md`,
  `INSTALL.md`, and `examples/sample-dispatches.md`.
- If you add or change a persona, ensure it has YAML frontmatter, a `{{TASK}}`
  placeholder, and an explicit return format.
- If you change durable prompt, agent, skill, command, or publication guidance,
  update `docs/prompt-and-agent-patterns.md` and keep private local details out
  of public examples.
- Do not add generated artifacts, logs, transcripts, credentials, or real local
  session data to the repo.
- Use UTF-8 and LF line endings. `.gitattributes` enforces LF.

## Validation

Run these before handing off changes:

```powershell
bash scripts/doctor.sh
bash scripts/test-dispatch-wrapper.sh
bash scripts/codex-dispatch.sh --debug 'Return exactly: OK'
bash scripts/codex-dispatch.sh --sandbox workspace-write 'Return exactly: OK'
git diff --check
git status --short
```

On Windows PowerShell, run these through Git Bash if plain `bash` is not on
PATH. Prefer `codex.cmd` and `claude.cmd` over `.ps1` shims when execution
policy blocks scripts.

When reading Markdown or other UTF-8 text through Windows PowerShell, force
UTF-8 output so Chinese examples and box drawing characters do not turn into
mojibake:

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Get-Content -Raw -Encoding UTF8 README.md
```

## Handoff Standard

When leaving a substantial change for the next agent, include:

- current branch and dirty state,
- files changed,
- exact validation commands and outcomes,
- any Codex CLI version assumptions,
- known Windows sandbox caveats,
- next recommended command.
