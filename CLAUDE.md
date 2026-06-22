# Claude Maintainer Guide

Default answer language for this maintainer is Chinese unless the user asks for
English. Keep responses direct and evidence-backed.

## What This Repo Teaches

This repo teaches Claude Code to use local Codex as a worker subagent. Claude
keeps orchestration, judgment, and user conversation state. Codex handles
context-heavy or tool-heavy work: current web facts, large reads, bulk repo
analysis, long file writes, audits, test runs, and fresh-context debugging.

## Dispatch Defaults

For Codex CLI 0.141.0+:

```bash
codex exec --skip-git-repo-check --sandbox workspace-write -C <repo> -
```

Use stdin for generated or multiline prompts. Do not teach new examples with
`--full-auto`; it is deprecated. If a persona still says `sandbox: full-auto`,
the wrapper treats it as a legacy alias for `--sandbox workspace-write`.

Escalate deliberately:

- `--sandbox workspace-write`: normal local repo reads, edits, tests, lint, build.
- `--search`: helper-script shorthand for current public web facts. Direct
  `codex exec` uses `--config web_search="live"`; top-level interactive
  `codex` supports `--search`.
- `--dangerously-bypass-approvals-and-sandbox`: shell network, cross-workspace
  access, global installs, or Windows sandbox ACL fallback after reporting the
  exact error.
- `--ephemeral`: throwaway checks that should not persist a session.
- `--json`, `-o`, `--output-schema`: automation and machine-readable outputs.

## How To Prompt Codex

Every dispatch prompt should include:

- goal and done condition,
- scope and working directory,
- what not to touch,
- exact return format,
- verification expectations,
- whether file edits are allowed.

Prefer short final returns. The point of this skill is to avoid reinflating the
main Claude context with Codex's full internal work.

## Use Personas

- `reviewer`: severity-ranked code review.
- `debugger`: fresh root-cause analysis.
- `auditor`: security audit.
- `researcher`: current web/docs research.
- `refactorer`: cleanup/dead-code/stale TODO survey.

When using a persona through `scripts/codex-dispatch.sh`, pass only the task
specific scope as the argument; the persona supplies the contract.

## Maintenance Workflow

Read in this order before changing behavior:

1. `AGENTS.md`
2. `skills/codex-subagent/SKILL.md`
3. `docs/codex-dispatch-guide.md`
4. `docs/prompt-and-agent-patterns.md`
5. `scripts/codex-dispatch.sh`
6. `scripts/doctor.sh`
7. `personas/README.md`
8. `README.md` and `INSTALL.md`

Use the dispatch guide for exact Codex CLI parameters. Use the prompt and agent
patterns guide for public-facing prompt contracts, persona design, skill design,
command design, result handling, and release-safe redaction rules.

Before finishing, run the validation commands in `AGENTS.md`. If a real Codex
dispatch fails because of Windows sandbox ACL setup, report that as a local
Codex sandbox limitation and validate the non-destructive path with bypass only
when the task permits it.
