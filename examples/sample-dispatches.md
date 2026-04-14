# Sample dispatches

Real-world patterns for delegating to Codex. Copy, adapt, or just read them to get a feel for how the skill wants to be used.

Every example uses the canonical invocation shape:

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check <sandbox-flags> [other flags] \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
<prompt>
EOF
```

---

## 1. Web lookup — "what's the current version of X"

**Why delegate:** WebSearch + WebFetch in Claude costs real tokens for what is ultimately a one-line answer. Codex does the fetching in its own context and returns the one line.

**Sandbox:** `--dangerously-bypass-approvals-and-sandbox` (network needed)

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Search the web for the current stable version of Bun (as of today).
Check bun.sh and the GitHub releases page at https://github.com/oven-sh/bun/releases.
Return exactly one line:
  bun <version> released <YYYY-MM-DD>
No other output.
EOF
```

**Expected return:**
```
bun 1.2.4 released 2026-03-28
```

---

## 2. Bulk TODO audit — "which of these are stale"

**Why delegate:** Scanning dozens of files for TODO comments, cross-referencing git blame for each, and judging staleness would cost Claude thousands of tokens of `grep` + `blame` output. Codex runs it all internally and returns a structured table.

**Sandbox:** `--full-auto` (read-only workload, no network)

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --full-auto -C /path/to/your/repo \
  --config model_reasoning_effort="high" \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Find every TODO/FIXME/HACK comment under src/. For each one, judge whether
it looks stale using these rules:
  - references a function/variable that no longer exists → stale
  - git blame shows it's older than 1 year AND surrounding code was rewritten → stale
  - the work described is already done elsewhere in the codebase → stale
  - otherwise → not stale

Return a markdown table, nothing else:
| file:line | comment (truncated to 60 chars) | stale? | reason |

No prose, no preamble, no summary. Just the table.
EOF
```

**Expected return:**
```
| file:line | comment | stale? | reason |
|---|---|---|---|
| src/auth/login.ts:42 | TODO: add rate limiting | no | feature still pending |
| src/utils/cache.ts:17 | FIXME: race condition in... | yes | code rewritten 2024, no race exists |
...
```

---

## 3. Long file write — "generate a full X"

**Why delegate:** A 400-line generated file costs 400 lines of Claude output tokens if Claude writes it. If Codex writes it, Claude just sees "wrote foo.py (412 lines)".

**Sandbox:** `--full-auto` (write to workspace)

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --full-auto -C /path/to/repo \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Generate a Python module at src/schemas/user.py with:
  - a Pydantic v2 BaseModel called User
  - fields: id (UUID4), email (EmailStr), name (str), created_at (datetime),
    is_active (bool, default True), role (Enum: admin/user/viewer)
  - a class method `from_dict(cls, data: dict) -> User` with proper type coercion
  - a method `to_public_dict(self) -> dict` that excludes email
  - full type hints, docstrings on the class and both methods

Match the existing code style in src/schemas/*.py if any exist.
Write the file, then report just: "wrote src/schemas/user.py (<N> lines)".
EOF
```

---

## 4. Security audit — "find bugs in this"

**Why delegate:** Audits are explicitly what `model_reasoning_effort="high"` is for, and the output is often "X issues found at lines A, B, C" — a small return value for a large analytical effort.

**Sandbox:** `--full-auto`

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --full-auto -C /path/to/repo \
  --config model_reasoning_effort="high" \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Security audit src/api/auth/. Focus on:
  - authentication bypass
  - session token handling (storage, expiry, invalidation)
  - timing attacks on comparisons
  - CSRF protection
  - SQL injection in raw queries
  - secrets leaked via logs or error messages

For each finding, return:
  severity (critical|high|medium|low) | file:line | issue | recommended fix

Order by severity descending. If you find no issues at a given severity,
skip that section rather than writing "none found".
EOF
```

---

## 5. Parallel batch — analyzing N independent things

**Why delegate:** Running N Codex calls in parallel via Claude Code's background task system means all N run in wall-clock parallel, and Claude only sees the N short summaries at the end.

**How:** Dispatch each call with Bash `run_in_background: true`, collect task_ids, then `TaskOutput` each one.

```bash
# Call 1 — in background
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --full-auto -C /repo/service-a \
  2>>"/tmp/codex-${filename}.log" \
  "Report service-a's public HTTP endpoints as a list: METHOD /path - description. No prose." &
# (Claude dispatches the other N-1 calls the same way in parallel.)

# Later, collect all results via TaskOutput on each task_id.
```

In practice, Claude handles the task-id tracking — you just say "analyze all 5 services in parallel and summarize".

---

## 6. Resume — follow-up without re-context

**Why:** The original Codex session already knows the project, the files it read, and the conversation so far. Starting a fresh session for a follow-up means paying to reload all of that. Resuming is free.

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check resume --last \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Follow-up: for each stale TODO you found, also check if there's a
corresponding open issue in the GitHub tracker (search for the file
path in issue bodies). Add a column "tracked?" to the table: yes (with
issue #) or no.
EOF
```

**Resume rules:**
- Prompt goes via **stdin** (echo pipe or heredoc), not as a positional argument.
- **Don't** re-specify `--sandbox`, `--model`, `--config`, `-p`. The session inherits from the original.
- Use resume for refinement, "now also do X", disagreement discussions.
- Use a fresh call for unrelated tasks or when the last session was derailed.

---

## 7. Disagreement — peer discussion mode

**Why:** Codex can be wrong, especially about recent library versions or post-cutoff APIs. If you (Claude) have reason to believe Codex is wrong, push back explicitly rather than silently ignoring — either AI could be mistaken and the user deserves to see the discussion.

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check resume --last \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
This is Claude following up. I disagree with your claim that React 18's
useEffect runs twice in development mode because of "hot reload". My
understanding is that it's React 18's strict-mode intentional double-
invocation, not hot reload — it happens even on cold starts in dev.

Can you check the React 18 docs on StrictMode and either confirm or
correct me? If I'm right, we should update the earlier analysis.
EOF
```

---

## 8. "I'm stuck" rescue mode

**Why:** When Claude's own attempt has stalled (bad assumption, wrong tool, circular reasoning), dispatching a fresh Codex session with a clean problem statement is often faster than continuing. Codex gets no context pollution.

**Sandbox:** depends on the task — usually `--full-auto` for local or bypass for network.

```bash
filename=$(openssl rand -hex 4)
codex exec --skip-git-repo-check --full-auto -C /path/to/repo \
  --config model_reasoning_effort="high" \
  2>>"/tmp/codex-${filename}.log" <<'EOF'
Fresh pair of eyes needed. I'm debugging this failing test:

  tests/test_user_auth.py::test_login_with_2fa FAILS with
  AssertionError: Expected session to be active after 2FA verify

I've already checked:
  - the 2FA secret is valid (verified via pyotp directly)
  - the test DB has the user record
  - session.py:verify_2fa returns True

But session.is_active is still False after the verify call.

Please investigate from scratch — don't trust my assumptions. Look at:
  - session.py (session state transitions)
  - tests/test_user_auth.py (what the test actually asserts)
  - any middleware between verify_2fa and the session object

Return: the root cause in 2-3 sentences, plus the exact file:line of the bug.
EOF
```

---

## Prompt-writing tips

Patterns that consistently produce good Codex results:

1. **State the return format explicitly.** "Return exactly one line...", "Return a markdown table with columns X, Y, Z", "No prose, no preamble". Codex is very willing to be terse if asked.

2. **Scope aggressively.** "under src/auth/", "in files matching *.test.ts", "only check functions that start with handle_". Don't let Codex wander.

3. **Say what NOT to do.** "Don't modify tests.", "Don't touch anything outside src/api/.", "Don't write a summary at the end."

4. **Give a decision rule, not just a question.** Instead of "is this stale?", spell out the rule: "stale if git blame > 1 year AND referenced code is gone".

5. **When you care about reasoning, set it high.** `--config model_reasoning_effort="high"` for audits, security, tricky debugging. Leave default for routine work.

6. **Heredoc for anything multi-line.** Much less quoting pain than positional args.
