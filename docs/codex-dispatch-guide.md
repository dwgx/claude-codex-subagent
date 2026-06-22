# Codex Dispatch Guide

Last updated: 2026-06-22 for Codex CLI 0.141.0.

This guide is the practical reference for using Codex as a worker subagent from
Claude, from this repository's helper script, or directly from a shell.

For broader prompt, agent, skill, command, result-handling, and publication
patterns, read [Prompt And Agent Patterns](prompt-and-agent-patterns.md).

## Core Contract

Claude is the orchestrator. Codex is the worker.

Claude owns:

- user conversation and final judgment,
- whether delegation is useful,
- prompt scope and return format,
- verification of load-bearing results.

Codex owns:

- web searches and current docs lookups,
- large file or repo reads,
- bulk analysis,
- long file writes,
- test/lint/build runs,
- fresh-context debugging and audits.

Codex stdout is the return value. Do not silently rewrite Codex's answer in
your head. If the result is wrong, incomplete, or ambiguous, resume the session
or dispatch a better prompt.

## Current Command Shape

This helper is a non-interactive `codex exec` wrapper. It is designed for an AI
or script to choose the right mode up front and then run to completion. It is
not Codex TUI's step-by-step approval flow; use interactive Codex when you want
manual per-command accept/deny.

Use this for normal local repository work:

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --sandbox workspace-write -C /path/to/repo \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
<prompt>
EOF
```

Windows PowerShell equivalent:

```powershell
$prompt = @'
<prompt>
'@
$prompt | codex.cmd exec --skip-git-repo-check --sandbox workspace-write -C D:\path\to\repo -
```

When a prompt asks Codex on Windows to read Markdown containing Chinese text,
tell it to use UTF-8 explicitly, for example
`Get-Content -Raw -Encoding UTF8 README.md`, otherwise PowerShell output can
display mojibake even though the file is valid UTF-8.

`--full-auto` is deprecated. Codex 0.141.0 keeps it as a compatibility alias
and prints a warning. New docs and scripts should use
`--sandbox workspace-write`.

## Permission Decision Tree

Precedence is strict: explicit helper CLI flags beat persona frontmatter, and
persona frontmatter beats wrapper defaults. If no explicit sandbox is provided,
Claude/Codex may choose the persona default or an adaptive mode such as bypass
for network-heavy work. If `--sandbox workspace-write`, `--sandbox read-only`,
or `--sandbox danger-full-access` is explicitly provided, the persona must not
escalate or downgrade it.

| Task | Preferred flags | Notes |
| --- | --- | --- |
| Read or edit files inside one repo | `--sandbox workspace-write -C <repo>` | Default local automation mode. |
| Read-only question with no tools needed | Do not dispatch | Answer directly. |
| Current public web facts | `--sandbox workspace-write --config web_search="live"` | Use when Codex's web search tool is enough. The helper accepts `--search` and emits this config override. |
| Shell network: `curl`, `npm view`, `pip install`, `gh api` | `--dangerously-bypass-approvals-and-sandbox` | Workspace sandbox usually blocks command network. |
| Cross-workspace local files | `--sandbox workspace-write -C <repo> --add-dir <dir>` | Use one scoped extra dir; explain why. |
| System paths, global installs, user config writes | `--dangerously-bypass-approvals-and-sandbox` | Stop first for destructive or security-sensitive changes. |
| Throwaway CI/check where resume is unwanted | add `--ephemeral` | No persisted session state. |
| Machine-readable final answer | `--output-schema <schema.json> -o <file>` | Schema controls final response shape. |
| Need event stream | `--json` | Emits JSONL events, not just a clean final answer. |

## Windows Sandbox Fallback

On some Windows setups, Codex's `read-only` or `workspace-write` sandbox can
fail before a command runs with an error like:

```text
windows sandbox: helper_unknown_error: apply deny-read ACLs
```

Treat this as a partial result, not as a normal task failure.

Safe handling:

1. Report the exact sandbox error.
2. Confirm the task is non-destructive.
3. Retry with `--dangerously-bypass-approvals-and-sandbox` only when the current
   workflow already allows full local access.
4. Keep destructive actions gated by explicit user confirmation regardless of
   sandbox mode.

## Prompt Template

Use this structure for most dispatches:

```text
Goal: <what done looks like>

Scope:
- Working directory: <path>
- Files/areas to inspect: <paths>
- Out of scope: <what not to touch>

Permissions:
- File edits: allowed|not allowed
- Network: allowed through web search only|shell network allowed|not needed

Instructions:
- Read real files and run relevant commands.
- Do not guess. Mark unverified items explicitly.
- Keep the final answer short.

Return format:
<exact structure, e.g. markdown table, one-line answer, JSON fields>
```

For complex work, prefer a block contract that is easy for a worker agent to
parse:

```xml
<task>
Do <specific goal>. Done means <observable done condition>.
</task>

<scope>
Workspace: <repo>
Inspect: <paths, commands, docs>
Out of scope: <things not to touch>
</scope>

<execution_policy>
Edits: allowed|not allowed
Network: none|web-search-only|shell-network-ok
Destructive actions: stop and ask before executing
</execution_policy>

<grounding_rules>
Use current files, command output, tests, and official docs. Do not guess.
Separate verified facts, inference, and unknowns.
</grounding_rules>

<verification_loop>
Run relevant checks after edits. If a check fails, diagnose and make the
smallest scoped fix unless blocked by missing credentials, external state, or a
safety gate.
</verification_loop>

<output_contract>
Return the requested format plus validation outcomes and unverified items.
</output_contract>
```

Keep small dispatches small. Use the full block template when the task has
meaningful scope, permissions, verification, or publication constraints.

## Reasoning Effort

Use `--config model_reasoning_effort="<level>"` sparingly:

| Task | Effort |
| --- | --- |
| Quick lookup or single-file read | default |
| Normal edits/refactors | default |
| Bulk scan with judgment | medium |
| Debugging subtle failures | high |
| Security audit or code review | high |

Do not override the user's model unless they asked. If you need a model, use
`-m <model>` explicitly and mention why.

## Output Controls

Use the simplest output that fits the caller.

| Need | Flag |
| --- | --- |
| Clean human answer | no extra output flag |
| Save final answer | `-o <file>` or `--output-last-message <file>` |
| Event stream for wrappers | `--json` |
| Stable downstream fields | `--output-schema <schema.json>` |
| Ignore user config for reproducibility | `--ignore-user-config` |
| Ignore execpolicy rules in controlled automation | `--ignore-rules` |
| Fail on unknown config fields | `--strict-config` |

`--json` changes stdout into JSONL events, so do not use it when a human expects
plain text unless a wrapper extracts the final message.

## Resume

Use resume for iterative follow-up when the last Codex session has useful
context:

```bash
echo "Now also check peerDependencies and add a tracked? column." | \
  codex exec --skip-git-repo-check resume --last - \
  2>>"/tmp/codex-${filename}.log"
```

Do not resume for unrelated work, a different repo, or a derailed session. Use
a fresh dispatch instead.

For generated multiline prompts, pass `-` and stdin. Codex 0.141.0 accepts a
positional resume prompt, but stdin is more reliable across shells.

Resume is not a fresh session. The helper rejects `--resume` with `--cd`,
`--profile`, `--add-dir`, or non-bypass sandbox values such as
`--sandbox workspace-write` because those options describe initial session
context. Codex 0.141.0 does support some resume-time controls, so the helper
allows `--model`, `--config`, `--json`, `-o/--output-last-message`,
`--output-schema`, `--ephemeral`, `--ignore-user-config`, `--ignore-rules`,
`--strict-config`, `--enable`, `--disable`, and explicit
`--sandbox bypass` when a resumed run must bypass approvals and sandboxing.

## Persona Defaults

Persona frontmatter uses stable names for humans:

- Persona `sandbox` and `effort` are defaults only. They apply when the caller
  did not pass `--sandbox` or `--effort`.
- Explicit helper flags always win, including `--sandbox workspace-write` on a
  normally network-heavy persona and `--effort default` on a high-effort
  persona.
- `sandbox: full-auto` is accepted as legacy vocabulary and mapped by
  `scripts/codex-dispatch.sh` to `--sandbox workspace-write`.
- `sandbox: bypass` maps to `--dangerously-bypass-approvals-and-sandbox`.
- `effort: high` maps to `--config model_reasoning_effort="high"`.

Prefer new personas to use:

```yaml
sandbox: workspace-write
```

Use `bypass` only for network-heavy personas such as `researcher`.

## Direct Helper Examples

Local repo summary:

```bash
./scripts/codex-dispatch.sh --sandbox workspace-write --cd /path/to/repo \
  "Read README.md and return one sentence describing this project. Do not edit files."
```

Web research:

```bash
./scripts/codex-dispatch.sh --persona researcher --search \
  "Find the current stable Bun version from official sources. Return one line."
```

Structured review:

```bash
./scripts/codex-dispatch.sh --persona reviewer --cd /path/to/repo \
  --output-last-message /tmp/codex-review.md \
  "Review the current git diff. Findings only."
```

Automation with schema:

```bash
./scripts/codex-dispatch.sh --sandbox workspace-write --cd /path/to/repo \
  --output-schema ./schemas/repo-summary.schema.json \
  --output-last-message ./tmp/repo-summary.json \
  "Summarize this repo according to the schema."
```

## Validation For This Repo

Run:

```powershell
bash scripts/doctor.sh
bash scripts/test-dispatch-wrapper.sh
bash scripts/codex-dispatch.sh --debug 'Return exactly: OK'
bash scripts/codex-dispatch.sh --sandbox workspace-write 'Return exactly: OK'
git diff --check
git status --short
```

On Windows PowerShell, use the Git Bash executable path if `bash` is not on
PATH. If `workspace-write` cannot read files because of the Windows sandbox ACL
failure, also validate a non-destructive file-read dispatch with bypass and
record the caveat in the handoff.
