# Prompt And Agent Patterns

Last updated: 2026-06-22.

This is the public, reusable guidance for writing prompts, personas, skills,
commands, and agent-facing repository instructions in this project. It is
deliberately broader than the Codex dispatch wrapper: Claude, Codex, and future
agent tools should all be able to learn the same operating model from it.

The intent is not to make agents timid. The intent is to make strong agents
precise, grounded, easy to verify, and safe to publish.

## Public Boundary

Public agent guidance must preserve capability without publishing private
machine state.

Keep:

- reusable workflow rules,
- CLI flag guidance that is current and verified,
- generic examples with fake paths,
- public project architecture,
- validation commands that another user can run,
- safety boundaries and rollback expectations,
- prompt and agent templates.

Do not publish:

- real tokens, cookies, credentials, session files, auth paths, or key names
  that identify a private account,
- private hostnames, private IPs, home-cloud URLs, tunnel domains, or personal
  remote connection commands,
- full local transcripts, vendor logs, private chats, screenshots with secrets,
  or unreduced telemetry,
- machine-specific absolute paths unless they are necessary public examples,
- one-off local state that will be false on another machine.

Use placeholders such as `<repo>`, `<workspace>`, `<extra-dir>`,
`<ticket-id>`, `<redacted-host>`, and `<tool-root>` in public docs. If an
example must mention a platform path, use a generic form such as
`C:\path\to\repo`, `/path/to/repo`, or `$HOME/.codex`.

## Source Priority

Agents should answer from the strongest available source, in this order:

1. Current files, config, commands, tests, logs, screenshots, or UI state in the
   workspace being worked on.
2. Official documentation, release notes, or the upstream repository for facts
   that can change.
3. Public project docs such as `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/`,
   and release notes.
4. Skills, prompts, memories, and search indexes as routing aids.
5. Model memory and inference, clearly labeled as inference when used.

Do not let a search result, index, previous chat summary, or skill description
override current files or current command output.

## Instruction Surfaces

Use the smallest durable surface that matches the scope.

| Surface | Best for | Do not put here |
| --- | --- | --- |
| One prompt or thread | One-off goal, current constraints, exact output contract | Long-lived project rules |
| `AGENTS.md` | Codex-facing repository conventions, validation commands, review expectations | Runtime flags that belong in config, private local facts |
| `CLAUDE.md` | Claude-facing repository context, read order, project maintenance notes | Secrets, stale transcripts, generic best practices |
| Skill `SKILL.md` | Reusable workflow with trigger description and optional references/scripts | Broad personal policy, unrelated reference dumps |
| Persona markdown | A focused dispatch mode with frontmatter, `{{TASK}}`, and return format | Complex implementation logic |
| Slash/custom command | A frequently used prompt entry point with arguments | Generic documentation with no executable instruction |
| CLI wrapper | Stable command shape, compatibility glue, logging, validation | Agent judgment or policy prose |
| `config.toml` or profile | Model, sandbox, MCP, feature, and runtime defaults | Project facts and handoff notes |
| Plugin | Installable bundle of skills, commands, hooks, MCP config, assets | Single one-off prompt |
| MCP server | Live external data or actions | Static documentation that belongs in files |
| Hook/rule | Mechanical enforcement around tool calls or commands | Nuanced judgment that needs model reasoning |
| Handoff | Current status, dirty state, validation evidence, next prompt | Permanent policy or generic tutorials |

If two surfaces would say the same thing, choose one owner and link to it.
Duplication is how stale instructions happen.

## Durable Rule Design

Good durable rules are short, local, testable, and non-obvious.

Add rules that:

- encode commands that future agents should actually run,
- document project-specific gotchas,
- describe architecture boundaries that are not obvious from filenames,
- define safety behavior for destructive, privacy-sensitive, or irreversible
  actions,
- say how to validate work before handoff.

Avoid rules that:

- restate universal programming advice,
- describe obvious class names or directory names,
- preserve one-off debugging history with no future value,
- mix private local state into public docs,
- repeat the same command in multiple files without a single owner.

When a rule conflicts with the current task, prefer the newest explicit user
instruction unless doing so would violate safety, privacy, or factuality.

## Prompt Contract

A strong prompt tells the agent what to do, where to look, what it may change,
how to verify, and what to return.

Minimum useful contract:

```text
Goal:
<the exact result that counts as done>

Scope:
- Working directory: <repo>
- Inspect: <paths or concepts>
- Out of scope: <paths, behaviors, or refactors to avoid>

Permissions:
- File edits: allowed|not allowed
- Network: not needed|web search only|shell network allowed
- Destructive/system actions: forbidden unless explicitly confirmed

Grounding:
- Read current files and run relevant commands before concluding.
- Use official/current sources for versioned or unstable facts.
- Mark inference and unverified items explicitly.

Verification:
- Run <commands> after edits.
- If a check fails, diagnose and fix unless the failure is outside scope.

Return format:
<exact sections, fields, table, JSON schema, or maximum length>
```

Not every task needs every line. Keep small prompts small. Add blocks when they
remove ambiguity or prevent expensive mistakes.

## XML Block Template

XML-style blocks work well for subagent dispatch because they are compact and
hard to misread.

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
Sandbox: workspace-write|danger-full-access only if justified
Destructive actions: stop and ask before executing
</execution_policy>

<grounding_rules>
Use current files, command output, tests, and official docs.
Do not guess. Separate verified facts, evidence-based inference, and unknowns.
</grounding_rules>

<verification_loop>
Run the relevant checks. If a check fails, inspect the failure and make the
smallest scoped fix. Stop only when blocked by missing credentials, external
state, or an explicit safety gate.
</verification_loop>

<output_contract>
Return <format>. Include files changed, validation results, and any unverified
items. Keep raw logs out unless asked.
</output_contract>
```

## Codex Worker Template

Use this when Claude delegates a scoped task to `codex exec`.

```text
You are Codex running as a worker subagent for another AI.

<task>
{{TASK}}
</task>

<scope>
Working directory: {{WORKDIR}}
Read the repository instructions first: AGENTS.md, CLAUDE.md, README.md, and
the relevant docs for this task.
Do not touch unrelated files.
</scope>

<grounding_rules>
Use current files and command output as the source of truth.
For current public facts, use official sources or upstream release notes.
Mark unverified items explicitly.
</grounding_rules>

<verification_loop>
If you edit files, run the smallest relevant validation command. If it fails,
diagnose and fix within scope. If validation cannot run, explain exactly why.
</verification_loop>

<output_contract>
Return a concise handoff:
- what changed or what you found,
- files touched or evidence inspected,
- validation commands and outcomes,
- remaining risks or unknowns.
</output_contract>
```

For a pure read-only question, change `output_contract` to ask for a shorter
answer and set edits to `not allowed`.

## Review Prompt Recipe

Use review mode for bugs, regressions, security problems, missing tests, and
incorrect assumptions. Findings must lead.

```text
Review the current diff for correctness and risk.

Focus on:
- realistic bugs,
- security issues,
- data loss,
- behavior regressions,
- missing tests for changed behavior.

Ignore:
- formatting,
- naming-only nits,
- style that an existing linter already covers.

Return:
## Findings
- [severity] `file:line` - issue, impact, and concrete fix

## Open Questions
<only questions that change the verdict>

## Test Gaps
<missing checks or "none">
```

Do not implement fixes after a review unless the caller asked for an
implementation task. A review answer and a patch task are different jobs.

## Debug Prompt Recipe

Debug prompts should preserve uncertainty and force reproduction.

```text
Debug <failure>.

Known facts:
- <observed error>
- <commands already tried>
- <assumptions that may be wrong>

Investigate from first principles:
- reproduce or inspect the failing path,
- identify the smallest root cause,
- cite the file:line or command output that proves it,
- propose the smallest fix.

Return:
1. Root cause in 2-4 sentences.
2. Evidence.
3. Minimal fix.
4. Verification command.
```

If the first assumption is wrong, say so clearly instead of trying to fit the
evidence to the prompt.

## Research Prompt Recipe

Use research mode when facts can change: versions, APIs, laws, pricing, release
status, dependencies, or product behavior.

```text
Research <question> as of <absolute date>.

Source priority:
1. official documentation,
2. upstream release notes or repository,
3. standards/specifications,
4. reputable secondary sources only as supporting context.

Return:
## Answer
<direct answer>

## Evidence
- <source title and URL>: <short paraphrase or compliant short quote>

## Confidence
high|medium|low - <why>

## Caveats
<source conflicts, stale docs, access limits, or unknowns>
```

Do not widen into blogs or forum posts when official sources already resolve
the claim.

## Security Prompt Recipe

Security prompts need explicit assets, trust boundaries, attacker capability,
and non-capability.

```text
Threat model <system or change>.

Assets:
- <data, credentials, permissions, systems>

Trust boundaries:
- <user input, network, process boundary, file boundary, privilege boundary>

Attacker capabilities:
- <what attacker can do>

Attacker non-capabilities:
- <what attacker cannot do>

Return:
## Summary
## Trust Boundaries
## Abuse Paths
| id | path | impact | likelihood | evidence | mitigation |
## Assumptions To Validate
## Prioritized Fixes
```

Do not report a theoretical issue without tying it to a reachable path or an
explicit assumption.

## Agent Design

An agent is selected before its full prompt is loaded, so the description is
load-bearing.

Good agent frontmatter:

```yaml
---
name: focused-agent-name
description: Use this agent when <specific task>. Typical triggers include
  "<phrase>", "<phrase>", and "<phrase>". Do not use for <near miss>.
model: sonnet
tools: Read, Grep, Bash(git:*)
---
```

Good body structure:

```markdown
# Role
You are a <specific role> for <specific caller>.

## When To Invoke
- <trigger 1>
- <trigger 2>

## Process
1. Read <sources>.
2. Run <commands>.
3. Produce <artifact>.

## Quality Bar
- Evidence-backed claims only.
- Exact file:line references for findings.
- Stop for <safety gate>.

## Output
<fixed structure>

## Edge Cases
- If <missing input>, do <fallback>.
- If <unsafe action>, stop and ask.
```

Agent descriptions should be specific enough to avoid accidental invocation,
but broad enough to catch the intended phrasing. Include "do not use" language
when a neighboring agent might be confused with it.

## Skill Design

Skills are reusable workflows, not dumping grounds for all knowledge.

The `SKILL.md` file should contain:

- frontmatter `name` and `description`,
- a concise trigger definition,
- the workflow steps,
- safety gates,
- reference map for optional deeper docs,
- scripts to run when deterministic behavior matters.

Example:

```markdown
---
name: repo-release-check
description: Use when preparing a repository release, validating changelog,
  tag, build, smoke tests, artifact hashes, and public handoff notes.
---

# Repo Release Check

## Workflow
1. Read README, CHANGELOG, AGENTS, and release docs.
2. Run the release validation command.
3. Verify artifact names, hashes, and upload paths.
4. Produce a release-ready checklist.

## References
- `references/artifacts.md` for artifact naming.
- `scripts/hash-release.sh` for deterministic hashes.
```

Use progressive disclosure:

1. Keep the frontmatter description concise and trigger-rich.
2. Keep `SKILL.md` small enough to load comfortably.
3. Put long details in `references/`.
4. Put repeatable mechanics in `scripts/`.
5. Put output examples in `examples/` only when they teach the expected shape.

Test skills with realistic prompts, near-miss prompts, and should-not-trigger
prompts. A skill that triggers too often is as harmful as one that does not
trigger.

## Persona Design

Personas in this repository are prompt templates for `codex exec`. They should
be boringly predictable.

Required contract:

```markdown
---
persona: <name>
sandbox: workspace-write|read-only|danger-full-access|bypass
effort: low|medium|high|default
when-to-use: <one-line trigger guidance>
---

You are <role> working as a subagent.

Scope: {{TASK}}

Rules:
- <behavior>
- <grounding>
- <safety>

Return format:
<exact output contract>
```

Persona rules:

- Keep one persona focused on one job.
- Include `{{TASK}}` exactly once.
- Treat persona `sandbox` and `effort` as defaults, not hard overrides.
- Explicit caller flags always win over persona defaults.
- Prefer `workspace-write` for local repo work.
- Use `bypass` only when the mode normally needs shell network or broad local
  access.
- Use `high` effort for review, audit, and subtle debugging.
- Always define the return format.

## Command Design

Commands are instructions for the agent, not marketing copy for the user.

Good command frontmatter:

```yaml
---
description: Review pull request for release risk
argument-hint: [pr-number]
allowed-tools: Read, Bash(gh:*), Bash(git:*)
---
```

Good command body:

```markdown
Review PR #$1 for release risk.

Steps:
1. Fetch PR metadata with `gh`.
2. Inspect changed files.
3. Run the relevant local checks if available.
4. Return severity-ranked findings and test gaps.

If `$1` is missing, explain usage and stop.
```

Command quality rules:

- single responsibility,
- clear arguments,
- fast prerequisite checks,
- scoped allowed tools,
- helpful error messages,
- examples that actually work,
- no destructive actions without an explicit confirmation step.

For complex commands, add a short HTML comment at the top with usage,
requirements, examples, and version history. Keep comments useful to future
maintainers, not end-user filler.

## CLI Design For Agent Use

A CLI that agents can use well should be composable, scriptable, and boring.

Recommended command families:

- `doctor --json`: report auth, config, dependencies, and likely fixes.
- `discover --json`: list objects the agent can act on.
- `resolve --json <name>`: turn human names into stable IDs.
- `read --json <id>`: fetch one object by ID.
- `context --json <id>`: gather enough surrounding context for a decision.
- `draft --json`: propose changes without writing.
- `write --json --dry-run`: show what would change.
- `write --json --apply`: perform the write.
- `raw`: escape hatch for unsupported upstream calls.

Stable JSON matters more than pretty text. Human prose can be layered on top;
automation cannot reliably parse changing prose.

Auth rules:

- Prefer environment variables, then config, then explicit flags.
- Never print tokens.
- `doctor --json` should distinguish missing auth, expired auth, and missing
  permissions.

Smoke tests:

- run from outside the repo to catch path assumptions,
- verify `--json` parses,
- verify missing-auth behavior,
- verify dry-run before apply,
- verify generated files are stable.

## Subagent Dispatch

Subagents are useful when work is read-heavy, independent, or noisy.

Good use:

- repo exploration,
- independent package audits,
- CI log triage,
- long-file summarization,
- cross-checking current docs,
- security review split by boundary.

Poor use:

- tiny direct edits,
- tasks requiring one shared evolving mental model,
- parallel write-heavy work in the same files,
- tasks where the caller cannot explain scope.

Prompt the division explicitly:

```text
Use three parallel subagents:
1. Security: inspect auth and input boundaries.
2. Tests: inspect coverage and failing checks.
3. Maintainability: inspect complexity and dead code.

Wait for all three. Return one merged summary with file references and mark
any disagreement between agents.
```

The main agent remains responsible for merging results, resolving conflicts,
and deciding what to do next.

## Result Handling

Treat helper output like a function return.

Classify it:

- `success`: answered the prompt, evidence present, validation passed or not
  needed.
- `partial`: useful but incomplete, validation missing, source conflict, or
  sandbox/tool issue.
- `error`: non-zero command, malformed output, missing auth, or unsafe request.

Rules:

- Preserve severity and evidence when summarizing review or audit findings.
- Do not turn uncertainty into certainty.
- Do not invent file changes if the helper did not make them.
- Do not silently retry an error without inspecting the error.
- Resume or re-prompt when the result is under-specified.
- If a helper performed edits, verify in the current workspace before final
  signoff.

## Handoff Contract

Use a handoff when a task is long, interrupted, high risk, or likely to be
continued by another agent.

Minimum handoff:

```markdown
# Handoff

## Current State
- Branch:
- Dirty files:
- Goal:

## Completed
- <work done>

## Evidence
- <commands run and outcomes>
- <files inspected>

## Known Caveats
- <failed checks, sandbox issues, unverified assumptions>

## Next Step
<the single best next command or prompt>
```

Public handoffs must redact private paths, tokens, session IDs, and hostnames.
Repo-local handoffs may include local paths only when they are needed for the
next maintainer and safe to share in that repository.

## Public Release Checklist

Before publishing prompt, agent, skill, or command guidance:

- [ ] No secrets, tokens, private hostnames, private IPs, or real auth paths.
- [ ] No full local transcripts, unreduced logs, or personal screenshots.
- [ ] Examples use placeholders or public repository paths.
- [ ] CLI flags match the current verified version.
- [ ] Safety gates are explicit for destructive, system, credential, network,
      and broad filesystem actions.
- [ ] The guide names the owner surface for each rule.
- [ ] Commands in examples can be copy-pasted on at least one supported shell.
- [ ] Machine-readable examples are valid JSON/YAML/TOML where applicable.
- [ ] Skill and agent frontmatter is valid.
- [ ] A fresh agent can follow the guide without private local context.

## Repository Reading Order

For this repository, use:

1. `AGENTS.md`
2. `CLAUDE.md`
3. `skills/codex-subagent/SKILL.md`
4. `docs/codex-dispatch-guide.md`
5. `docs/prompt-and-agent-patterns.md`
6. `scripts/codex-dispatch.sh`
7. `scripts/doctor.sh`
8. `personas/README.md`
9. `README.md`, `INSTALL.md`, and `examples/sample-dispatches.md`

Use the dispatch guide for exact Codex CLI flags. Use this guide for prompt,
agent, skill, command, result-handling, and publication patterns.
