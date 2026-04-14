# Personas

Pre-written prompt templates for dispatching Codex with a specific focus or "mode of operation". Each file is a drop-in prompt body that Claude (or you, directly) can feed to `codex exec` for a known-good result in that domain.

Think of personas as **multi-modal dispatch profiles**. The skill is the dispatch engine; personas are the modes.

## Available personas

| File | Mode | Best for |
|---|---|---|
| [reviewer.md](reviewer.md) | Code review | PR-style severity-ranked review with file:line citations |
| [debugger.md](debugger.md) | Root-cause debugging | "fresh pair of eyes" on a failing test or bug |
| [auditor.md](auditor.md) | Security audit | OWASP-flavored scan, severity-ordered findings |
| [researcher.md](researcher.md) | Web research | Library version checks, API changes, docs lookups |
| [refactorer.md](refactorer.md) | Refactor / cleanup | Dead code, stale TODOs, complexity hotspots |

## How to use

### From Claude

Just tell Claude which persona to use:

```
用 codex 的 auditor persona 審計 src/api/auth/
```

```
Dispatch to codex in debugger mode — the test at tests/test_payment.py::test_refund is failing
```

Claude will read the persona file, substitute your task-specific context into the template, and run `codex exec` with the appropriate sandbox and reasoning effort defaults specified in the persona.

### From the command line (if you want to dispatch yourself)

Use the helper script:

```bash
./scripts/codex-dispatch.sh --persona auditor --cd /path/to/repo \
  "Focus on src/api/auth/ — authentication bypass, session token handling, CSRF."
```

The wrapper reads `personas/<name>.md`, fills the task slot with your argument, applies the persona's recommended flags, and runs `codex exec` with the canonical logging pattern.

## Writing your own persona

Copy one of the existing files and edit. The contract:

- Start with frontmatter specifying **recommended sandbox**, **reasoning effort**, and **when to use** (free-form)
- Write the prompt body in the imperative, with a `{{TASK}}` placeholder where task-specific detail will be injected
- Explicitly specify the **return format** — this is where personas earn their keep (consistent structured output per mode)

Minimum template:

```markdown
---
persona: my-persona-name
sandbox: full-auto|bypass
effort: low|medium|high|default
when-to-use: one-line description
---

You are a <role> working for another AI. Your job is to <goal>.

Scope: {{TASK}}

Follow these rules:
- <rule 1>
- <rule 2>

Return format:
<explicit format specification>
```

Personas are just markdown, so they're hackable, composable, and you can ship your own in your fork.
