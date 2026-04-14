# claude-codex-subagent

**Save Claude's tokens by delegating grunt work to the local Codex CLI.**

A Claude Code skill that turns `codex exec` into a worker subagent. Claude stays the orchestrator — planning, deciding, verifying — while Codex handles everything that would otherwise burn Claude's context: web searches, large reads, bulk analysis, long file writes, running tests, audits.

Works on macOS, Linux, and Windows (git-bash or WSL). Zero config beyond having `codex` on your PATH.

---

## The problem

Claude Code is great, but every WebFetch, every Read of a 2000-line file, every long grep output eats into your context window. Do it enough times in one session and you've paid thousands of tokens for work that produced a one-sentence conclusion.

Codex CLI solves this if you use it right: it has its own fresh context, its own network, and its own sandboxed shell. You hand it a scoped task, it does a ton of work internally, and it hands back a short answer. **You (Claude) only pay for the prompt in and the answer out.**

This skill teaches Claude when to delegate, how to write good dispatch prompts, how to pick the right sandbox mode adaptively, and how to classify the result.

## How it works

```
  ┌────────────┐    1. dispatch         ┌────────────┐
  │            │ ──────────────────▶   │            │
  │   Claude   │                        │   Codex    │
  │ (orchestr.)│ ◀──────────────────    │  (worker)  │
  │            │    2. final answer     │            │
  └────────────┘                        └────────────┘
        │                                     │
        │ owns: planning, decisions,          │ owns: web search, file I/O,
        │ judgment, verification,             │ long reads, bulk analysis,
        │ conversation state                  │ writes, tests, audits
```

Claude's context stays tiny. Codex's context absorbs all the grunt work. The conversation you care about is unaffected.

## Features

- **Adaptive sandbox** — defaults to `--full-auto` (workspace-write), automatically escalates to `--dangerously-bypass-approvals-and-sandbox` when the task needs network or cross-workspace access. **No approval prompts** — Claude announces the choice in one line and proceeds.
- **Thin-forwarder contract** — Codex's stdout is the authoritative return. No Claude-side freelancing, no phantom-answer drift.
- **Smart stderr logging** — captures Codex's thinking stream to `/tmp/codex-<rand>.log` instead of `/dev/null`, so the happy path stays clean but failures are fully debuggable.
- **Reasoning effort by task class** — audits and security reviews get `high`, normal edits use the default. No extra config.
- **Resume-first pattern** — follow-ups reuse Codex's prior session state via `codex exec resume --last`, avoiding redundant context re-loading.
- **Parallel batch dispatch** — independent subtasks fire in parallel via Claude Code's background task system.
- **Background lifecycle** — long runs go background (`run_in_background: true`), poll with `TaskOutput`, cancel with `TaskStop`.
- **Structured outcome classification** — every result is classified as `success` / `partial` / `error` and handled accordingly. No silent retries.

## Prerequisites

1. **[Claude Code](https://claude.com/claude-code)** (CLI, desktop app, or IDE extension)
2. **[Codex CLI](https://github.com/openai/codex)** — OpenAI's `codex` command-line agent. Install via npm:
   ```bash
   npm install -g @openai/codex
   codex login    # first-time auth
   ```
3. **A bash-compatible shell**:
   - macOS, Linux: native
   - Windows: git-bash (comes with Git for Windows) or WSL

That's it. No Node dependencies for the skill itself, no config files, no MCP servers.

## Install

Pick one:

### Option A — Manual skill copy (works anywhere, 10 seconds)

```bash
git clone https://github.com/dwgx/claude-codex-subagent.git
cp -r claude-codex-subagent/skills/codex-subagent ~/.claude/skills/
```

That's it. Claude Code auto-discovers skills under `~/.claude/skills/`.

### Option B — As a Claude Code plugin

If your Claude Code supports marketplace plugins:

```bash
/plugin install https://github.com/dwgx/claude-codex-subagent
```

Or add this repo as a marketplace and install normally.

### Option C — One-liner (curl)

```bash
mkdir -p ~/.claude/skills/codex-subagent && \
curl -fsSL https://raw.githubusercontent.com/dwgx/claude-codex-subagent/main/skills/codex-subagent/SKILL.md \
  -o ~/.claude/skills/codex-subagent/SKILL.md
```

Detailed platform-specific instructions in **[INSTALL.md](INSTALL.md)**.

## Usage

Once installed, just talk to Claude normally. The skill self-triggers on phrases like:

- "用 codex 查一下 bun 最新版本"
- "丟給 codex 掃一下這個 repo 裡的 TODO"
- "delegate this audit to codex"
- "codex 幫我分析一下這個長 log"
- "I'm stuck — ask codex for a fresh pass"

Claude will announce the dispatch in one line (including which sandbox it picked and why), run `codex exec`, and summarize the result. You never see the raw stdout unless you ask.

See **[examples/sample-dispatches.md](examples/sample-dispatches.md)** for real dispatch patterns you can copy.

## Design philosophy

Five principles, stolen from the best parts of five other projects:

1. **Thin forwarder** (from [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)) — one call in, stdout out. No freelancing.
2. **Adaptive escalation** (our own) — default low-privilege, escalate automatically, announce the choice. No prompts.
3. **Stderr to temp log, not /dev/null** (from [@timurkhakhalev/codex-cli-setup](https://github.com/timurkhakhalev/codex-cli-setup)) — `filename=$(openssl rand -hex 4); codex exec ... 2>>"/tmp/codex-${filename}.log"`. Clean happy path, full debug on failure.
4. **Structured outcome classification** (from [shinpr/sub-agents-skills](https://github.com/shinpr/sub-agents-skills)) — `success` / `partial` / `error`, each with a handling rule.
5. **Resume-first** (from [skills-directory/skill-codex](https://github.com/skills-directory/skill-codex)) — follow-ups reuse session state via `codex exec resume --last`, never paying to reload context.

## What it is NOT

- **Not a replacement for Read/Edit on small, known targets.** Direct tools are cheaper for tiny ops. This skill only earns its keep when the alternative would cost ≥3k Claude tokens.
- **Not a way to offload thinking.** Claude still owns planning, decisions, and judgment. Codex is a worker, not a co-pilot.
- **Not a silent fallback.** Every dispatch is announced so you can course-correct.
- **Not a queue system.** For heavy async lifecycle (multiple long jobs, status polling), pair this with [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — they complement each other.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `codex: command not found` | Codex CLI not installed or not on PATH | `npm install -g @openai/codex`, then restart your terminal |
| `refusing to run outside a git repository` | Codex's default guard | Skill passes `--skip-git-repo-check` by default; if you see this, check the skill file is actually loaded |
| `operation not permitted` / sandbox denial | Task needs higher sandbox | Skill should auto-escalate; if it didn't, check the task description matched an escalation trigger |
| `network unreachable` | On `--full-auto` without network | Escalate to `--dangerously-bypass-approvals-and-sandbox` (skill does this automatically for network tasks) |
| Skill doesn't trigger when expected | Description phrasing didn't match | Say "用 codex" or "delegate to codex" explicitly; phrasing matters for skill triggering |

Still stuck? Open an [issue](https://github.com/dwgx/claude-codex-subagent/issues).

## Credits

This skill is a synthesis of the best patterns from five prior projects. Each one contributed something essential:

- **[openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)** — thin-forwarder contract, background lifecycle, resume-candidate detection
- **[skills-directory/skill-codex](https://github.com/skills-directory/skill-codex)** — `2>/dev/null` default, resume-first follow-up pattern, Claude-vs-Codex disagreement loop
- **[leonardsellem/codex-subagents-mcp](https://github.com/leonardsellem/codex-subagents-mcp)** — file-based persona registry, Codex profile mapping
- **[shinpr/sub-agents-skills](https://github.com/shinpr/sub-agents-skills)** — structured outcome classification, single-responsibility prompt rules
- **[@timurkhakhalev/codex-cli-setup](https://github.com/timurkhakhalev/codex-cli-setup)** — `openssl rand` temp-log pattern, task-class model defaults

Go star them too. This skill exists because they did the groundwork.

## License

MIT — see [LICENSE](LICENSE).
