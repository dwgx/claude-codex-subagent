---
name: codex-subagent
description: >
  Delegate expensive work to the local Codex CLI (`codex exec`) as a worker
  subagent to save Claude's token budget. Use this skill whenever a task
  involves web search / online lookup, reading or scanning large files,
  bulk code analysis, writing long files, running tests or scripts, or any
  chore that would otherwise burn a lot of Claude context. Claude stays
  the orchestrator — planning, deciding, verifying — while Codex does the
  heavy I/O-bound or context-heavy work. Trigger on phrases like "用 codex",
  "丟給 codex", "讓 codex 查", "codex 搜一下", "codex 分析", "dispatch to
  codex", "delegate to codex", whenever the user hints they want to
  conserve Claude's tokens or offload work, or whenever Claude is stuck
  and wants a second pass with a fresh context.
user-invocable: true
---

# Codex as Worker Subagent

Claude is the **orchestrator**. Codex is a **worker subagent** with its own
fresh context window, its own network access, and its own sandboxed shell.
You hand Codex a well-scoped task and take back a short answer. Codex's
thinking, tool calls, and file reads happen **in Codex's context, not
yours** — that is where the token savings come from.

## Thin-forwarder contract

Treat each Codex call like a function call:

- You write the prompt (the "arguments")
- Codex runs its own full agent loop inside its own context
- You take Codex's stdout as the **authoritative return value**
- No Claude-side freelancing — don't "edit" what Codex said in your head
  and then act on a phantom version. If Codex's answer is wrong or under-
  specified, **resume the session** with a follow-up or dispatch a fresh
  call with a better prompt. Do not pretend you know what it meant.

## When to delegate

Delegate when any of these apply:

- **Network needed.** Web search, fetching docs, scraping an API,
  checking a package version, `gh api`, `npm view`, `pip install`. You
  (Claude) pay steep token cost for WebFetch/WebSearch; Codex's network
  calls happen in its own context.
- **Large reads.** Scanning a repo, digesting a long file/log, cross-
  referencing many sources.
- **Long output that just needs a conclusion.** E.g. "find all TODOs and
  tell me which are stale" — Codex emits the list internally and returns
  only the verdict.
- **Writing long files.** Codex writes in its sandbox; you only see
  "wrote foo.py (240 lines)".
- **Running tools you'd rather not stream.** Tests, builds, linters,
  data-processing scripts.
- **You're stuck.** If your own attempt has stalled or you want a fresh
  second pass with no prior context, dispatch Codex with a clean problem
  statement. That's explicitly the best-case use from the
  `codex-plugin-cc` design — "rescue" mode.

## When NOT to delegate

- Quick decisions you can make from existing context.
- Tasks that depend tightly on conversation state that would be painful
  to re-explain.
- One-line edits you could `Edit` directly with less overhead than
  composing a Codex prompt.
- The user is clearly expecting *you* to do it interactively ("let's walk
  through this together").

Gut check: if the task would cost you more than ~3k tokens of reads/
searches, delegate. If it's under ~1k, just do it.

## Command shape

Canonical invocation:

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --sandbox <MODE> [--full-auto] \
  [-C <DIR>] [-p <PROFILE>] \
  [--config model_reasoning_effort="<level>"] \
  "<PROMPT>" \
  2>>"/tmp/codex-${filename}.log"
```

Flag meanings:

- `exec` — non-interactive. No TUI, no mid-run approval prompts.
- `--skip-git-repo-check` — **always pass this.** We don't want Codex
  refusing to run just because the cwd isn't a git repo.
- `--sandbox <MODE>` — see the adaptive ladder below.
- `--full-auto` — alias for `--sandbox workspace-write`. Use this instead
  of writing the sandbox flag explicitly when you want writes.
- `-C <DIR>` — run Codex with a specific working directory. Pass this
  whenever the task is scoped to a specific project folder; saves Codex
  a `cd` round-trip.
- `-p <PROFILE>` — if the user has profiles defined in `~/.codex/config.toml`
  (reviewer, debugger, security, etc.), reference them by profile name
  and let the profile carry model/sandbox/approval preferences.
- `--config model_reasoning_effort="<low|medium|high>"` — raise for
  audits, security reviews, and tricky debugging; leave unset for normal
  work. Don't override the user's default model unless they asked.
- Prompt as the **last positional argument**, quoted. For long/multi-
  line prompts, use heredoc on stdin:

  ```bash
  filename=$(openssl rand -hex 4)
  codex exec --skip-git-repo-check --full-auto \
    2>>"/tmp/codex-${filename}.log" <<'EOF'
  Your multi-line
  prompt here.
  EOF
  ```

### Why the `openssl rand` log pattern instead of `2>/dev/null`

`2>/dev/null` throws away stderr, so when a call fails you have nothing
to diagnose. The alternative here — steal from `codex-cli-setup` — is:

1. Generate a random per-call filename.
2. Redirect stderr to `/tmp/codex-<name>.log` instead of `/dev/null`.
3. On **success**, ignore the log (temp file, OS cleans it up later).
4. On **failure** (non-zero exit or suspicious output), read the log to
   see Codex's thinking stream and real error messages.

You get clean stdout for happy path **and** full debugging info on
failure, without ever bloating Claude's context on the happy path.

## Sandbox ladder (adaptive, no-prompt)

The user has authorized adaptive escalation: **default to `--full-auto`,
escalate to `--dangerously-bypass-approvals-and-sandbox` whenever the task
actually needs it, without stopping to ask.** Don't over-escalate — use
the minimum that gets the job done.

| Task shape | Sandbox | Flag |
| --- | --- | --- |
| Read-only analysis inside workspace | workspace-write is fine | `--full-auto` |
| Local edits / file writes inside a project | workspace-write | `--full-auto` |
| **Anything needing network** (web search, fetch, `pip install`, `npm view`, `curl`, `gh api`, remote access) | bypass | `--dangerously-bypass-approvals-and-sandbox` |
| Operating outside the workspace (system paths, `~/.config`, other drives) | bypass | `--dangerously-bypass-approvals-and-sandbox` |
| Installing global tools, modifying global state | bypass | `--dangerously-bypass-approvals-and-sandbox` |

**Do tell the user** in your one-line status update *which* sandbox you
picked and *why* — so they can correct you if your read was wrong. No
approval needed, but transparency yes.

**Truly destructive ops** (`rm -rf` outside workspace, dropping a
database, force-push, rewriting git history) → stop and confirm with the
user first regardless of sandbox mode. The sandbox protects the
filesystem; it does not divine the user's intent.

## Reasoning effort by task class

Default to codex's configured defaults. Override with
`--config model_reasoning_effort="<level>"` only when the task class
warrants it:

| Task class | Effort | Why |
| --- | --- | --- |
| Quick lookup, version check, single-file read | (default) | Not worth the extra tokens |
| Normal code edits and refactors | (default) | Codex's default is tuned for this |
| Audit, security review, "find all bugs" | `high` | Needs exhaustive exploration |
| Debugging a subtle failure | `high` | Needs careful reasoning |
| Bulk scan / pattern matching over many files | `medium` | Balance speed and coverage |

Don't ask the user which model or effort to use — pick a sensible
default and mention it in the status line. If they want different,
they'll say so.

## Writing prompts for Codex

Codex is a capable coding agent, not a dumb shell. Treat it like a
competent colleague who just walked into the room — no memory of your
conversation, no context on why the task matters.

A good Codex prompt has:

1. **The goal.** What "done" looks like.
2. **Scope hints.** Which directory, which files, which language.
3. **Return format.** What you want back. "Reply with just the version
   number.", "Return a JSON array of {file, line, issue}.", "Summary
   under 200 words." Codex is very willing to be terse if asked — and
   terseness is token savings.
4. **Guardrails**, when non-obvious. "Don't modify tests.", "Don't touch
   anything outside src/api/."

Example — bad:

```
"check what version of react we're on"
```

Example — good:

```
"Read package.json in the current directory and report just the 'react'
 version string. No other output."
```

Example — web-search delegation:

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Search the web for the current stable version of Bun (as of today).
Check bun.sh and the GitHub releases page. Return a single line:
  bun <version> released <date>
EOF
```

Example — bulk analysis with structured return:

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --full-auto -C /path/to/repo \
  --config model_reasoning_effort="high" \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Find every TODO/FIXME comment under src/. For each, judge whether it
looks stale (references removed code, completed work, or is >1 year old
based on git blame). Return a markdown table:
  | file:line | comment | stale? | reason |
No prose. Just the table.
EOF
```

## Resume-first pattern

Before launching a **new** call, consider: is there a recent Codex
session still relevant to what you're about to ask? Codex keeps session
state. Resume is cheap; a new session discards everything Codex already
learned.

Resume syntax (prompt via stdin, no flags):

```bash
filename=$(openssl rand -hex 4)
echo "Your follow-up prompt" | codex exec --skip-git-repo-check \
  resume --last 2>>"/tmp/codex-${filename}.log"
```

Or with heredoc:

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check resume --last \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Follow-up: now also check the peerDependencies field and flag mismatches.
EOF
```

Resume rules:

- Feed the follow-up prompt via **stdin** (echo pipe or heredoc), not as
  a positional argument — `resume` doesn't accept a prompt positional.
- **Don't re-specify** flags like `--sandbox`, `--model`, `--config`,
  `-p` on resume. The resumed session inherits from the original.
  Passing them causes errors.
- Resume is the right tool for: iterative refinement, "now also do X",
  disagreement discussions, fed-back corrections.
- If you need a clean slate (different project, unrelated task, or last
  session was derailed), start fresh instead.

## Parallel batch dispatch

When you have multiple **independent** subtasks, fire them in parallel
instead of sequentially. Use Bash with `run_in_background: true`, then
collect via `TaskOutput` on each task_id. This is a token-savings
multiplier — each subagent runs in its own context, all in wall-clock
parallel, and you only see the summaries.

Good candidates for parallel batch:

- Analyzing N independent files/packages/repos
- Cross-checking an answer from two different angles
- Running lint + tests + build in parallel

Bad candidates:

- Sequential dependencies (step B needs step A's output)
- Tasks that should share context — use resume instead

## Background lifecycle for long runs

Long Codex calls (>30s, big analyses, audits, large writes) should go
into the background rather than blocking your turn:

1. Dispatch with Bash `run_in_background: true`. You get a task_id
   immediately and can continue other work.
2. Do other useful work while it runs — read a related file, plan the
   next step, write a helper.
3. When you need the result, call `TaskOutput` on the task_id with
   `block: true`. You'll either get the finished output or wait for it.
4. If the user wants to cancel, use `TaskStop`.

This is the closest equivalent to `codex-plugin-cc`'s
`/codex:status` + `/codex:result` + `/codex:cancel` lifecycle, using
primitives you already have.

## Handling the outcome

Codex's stdout is your return value. Before you act on it, classify it:

- **`success`** — call exited 0, stdout answers the prompt, nothing
  looks off. Proceed. Ignore the stderr log.
- **`partial`** — call exited 0 but stdout is empty, truncated, asks
  clarifying questions back at you, or hits a known failure mode
  (refused to run, couldn't find file, hit a permission wall). Check
  the stderr log for why, then either: (a) fix the prompt and dispatch
  fresh, (b) escalate the sandbox and retry, or (c) resume with a
  clarification.
- **`error`** — non-zero exit. **Don't silently retry.** Read the
  stderr log first and diagnose. Common failures and fixes:

  | Symptom | Likely cause | Fix |
  |---|---|---|
  | `refusing to run outside a git repository` | Missing `--skip-git-repo-check` | Add the flag |
  | `operation not permitted` / sandbox denial | Need higher sandbox | Escalate `--full-auto` → bypass |
  | `network unreachable` / DNS failure | On `--full-auto` without network | Use `--dangerously-bypass-approvals-and-sandbox` |
  | `127` command not found | `codex` not on PATH | Surface to user, don't retry |
  | Codex asked a clarifying question in output | Under-specified prompt | Rewrite prompt with clearer goal / return format |
  | Empty output / hit timeout | Task too big for one call | Split into subtasks, or raise timeout |

## Using Codex's answer

Once you have a `success` result:

1. **Read carefully.** Don't parrot stdout back to the user verbatim —
   extract what they actually need and summarize.
2. **Verify when it matters.** Codex runs on OpenAI models with their own
   cutoffs and can be wrong — especially about recent library versions,
   model names, APIs, or post-cutoff changes. If the answer is load-
   bearing and you have reason to doubt, cross-check (your own
   knowledge, a second Codex call with a different phrasing, or a
   direct tool).
3. **Disagree explicitly and resume.** If Codex is wrong, don't just
   quietly ignore it. Resume the session and push back with evidence.
   Frame it as peer discussion, not correction — either AI could be
   wrong:

   ```bash
   filename=$(openssl rand -hex 4)
   echo "This is Claude following up. I disagree with [X] because \
   [evidence]. What's your take?" | \
   codex exec --skip-git-repo-check resume --last \
     2>>"/tmp/codex-${filename}.log"
   ```

4. **Trust file ops.** If Codex said it wrote a file, it wrote it — its
   sandboxed shell actually ran the write. A quick `ls -la` or targeted
   Read is enough to confirm; don't re-read the whole file.
5. **Summarize for the user.** One or two sentences: what you delegated,
   what came back, what you did with it. Don't dump Codex's stdout into
   the chat unless the user asked — that re-inflates the context you
   were trying to save.

## Status updates to the user

Before dispatch — one line, in your normal chat voice:

- "Dispatching to codex for the web lookup (bypass sandbox for network)."
- "Delegating the repo scan to codex — full-auto, medium effort, read-
  only workload."
- "Codex rescue: I'm stuck, handing off with a fresh context."

After — short result summary. One or two sentences. What changed, what's
next.

## Token-budget sanity checks

This skill only earns its keep if it actually saves tokens. Gut checks
before dispatching:

- Prompt you'd send Codex is <1k tokens → usually worth it if the work
  Codex avoids is >3k tokens.
- About to delegate something you could answer in 2 sentences from
  memory → just answer it.
- About to delegate 5 tiny independent questions → batch them into one
  Codex call with a structured return format, not 5 calls. (Or
  parallel-batch them if each is big enough to warrant its own context.)

## What this skill is NOT

- Not a replacement for `Edit`/`Read` on small, known targets. Direct
  tools are cheaper for tiny ops.
- Not a way to offload thinking. Claude still owns planning, decisions,
  and judgment. Codex is a worker, not a co-pilot.
- Not a reason to avoid your own tools. If `Grep` finds the answer in
  200ms, use Grep.
- Not a silent fallback. Every dispatch is announced in one line so the
  user knows what's happening and can course-correct.
