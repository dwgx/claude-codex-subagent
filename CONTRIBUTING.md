# Contributing

Thanks for considering a contribution. This project is small, focused, and aims to stay that way — improvements are welcome, but scope discipline matters.

## What this project is (and isn't)

**Is**: a Claude Code skill that teaches Claude how to delegate expensive work to the local Codex CLI. One skill, one job, opinionated defaults.

**Isn't**: a full orchestration framework, a cross-LLM router, an MCP server, a queue system. Those all exist as separate projects and are linked in the README. If your idea requires adding any of those layers, it's probably a different project.

## Kinds of contributions we want

- **Prompting improvements to SKILL.md.** If you find that a specific phrasing, decision rule, or example consistently makes Claude make smarter dispatch choices, we want it.
- **New personas.** Drop a new file in `personas/`. Must be useful, non-overlapping with existing ones, and follow the frontmatter + `{{TASK}}` contract from `personas/README.md`.
- **Platform portability fixes.** This needs to work on Mac, Linux, and Windows (git-bash / WSL / PowerShell where reasonable). Bugs on any of those are fair game.
- **Documentation.** Clearer install steps, better troubleshooting, translations.
- **`doctor.sh` checks.** If you hit a breakage that doctor didn't catch, add a check for it.
- **Codex CLI compatibility updates.** If Codex changes flags, update `SKILL.md`, `scripts/codex-dispatch.sh`, `scripts/doctor.sh`, `docs/codex-dispatch-guide.md`, README/INSTALL, and examples together.
- **Prompt and agent guidance updates.** If you improve reusable prompt
  contracts, persona design, skill design, command patterns, result handling,
  or public release hygiene, update `docs/prompt-and-agent-patterns.md`.
- **CI tightening.** More validation in `.github/workflows/ci.yml` is welcome.

## Kinds we'd rather not

- Adding Node/Python/Rust dependencies. The skill is intentionally zero-dep — it's just markdown and a thin bash wrapper. Please don't add a build step.
- Adding new top-level directories unless they serve a clear purpose.
- Renaming core files or directories — it breaks every existing install.
- "Also delegates to Gemini / Cursor / local models." Out of scope for this project — see [shinpr/sub-agents-skills](https://github.com/shinpr/sub-agents-skills) for that.
- Stylistic rewrites of SKILL.md without a concrete reason. The current wording is load-bearing for how well Claude triggers and dispatches.

## Development workflow

```bash
git clone https://github.com/dwgx/claude-codex-subagent.git
cd claude-codex-subagent

# Install the skill into your own Claude Code for testing:
./scripts/sync-skill.sh to-local

# Edit skills/codex-subagent/SKILL.md, then push your changes back
# and re-sync to test:
./scripts/sync-skill.sh to-local

# Before committing, run the health check:
./scripts/doctor.sh

# If you changed wrapper flags or precedence:
bash scripts/test-dispatch-wrapper.sh

# When you're ready:
git add .
git commit -m "short descriptive subject"
git push
```

## PR checklist

Before opening a PR, run through this:

- [ ] `./scripts/doctor.sh` passes
- [ ] `bash scripts/test-dispatch-wrapper.sh` passes if you changed wrapper flags, sandbox logic, persona defaults, or resume behavior
- [ ] SKILL.md still has valid YAML frontmatter (CI validates this)
- [ ] `.claude-plugin/plugin.json` still parses as JSON (CI validates this)
- [ ] Shell scripts pass `shellcheck` if you touched them (CI validates this)
- [ ] You've actually run the skill end-to-end on at least one real dispatch to check your changes don't break triggering or output parsing
- [ ] README / INSTALL updated if you added user-visible behavior
- [ ] If you added a persona: it has frontmatter, a `{{TASK}}` placeholder, and an explicit return-format section
- [ ] If you changed Codex invocation flags: `./scripts/doctor.sh`, `bash scripts/test-dispatch-wrapper.sh`, and `./scripts/codex-dispatch.sh --debug "Return exactly: OK"` show the expected current flags
- [ ] If you changed durable prompt/agent guidance: `docs/prompt-and-agent-patterns.md` is updated and contains no private machine paths, credentials, transcripts, or unreduced local logs
- [ ] One commit, coherent change — no drive-by reformats mixed with functional changes

## Testing changes to SKILL.md

The hardest part of changing SKILL.md is verifying the change didn't break Claude's trigger matching or dispatch behavior. Recommended loop:

1. Sync your edited SKILL.md to `~/.claude/skills/codex-subagent/` via `./scripts/sync-skill.sh to-local`.
2. Restart Claude Code fully (the skill index loads at startup).
3. Open a fresh conversation and try 3 prompts:
   - An obvious dispatch case ("用 codex 查 bun 最新版本")
   - An ambiguous case ("how big is this repo?" — should it dispatch or just ls?)
   - A should-NOT-trigger case ("write me a fibonacci function")
4. Verify each produces the behavior you expected.

If you changed flag defaults, sandbox logic, resume rules, or logging patterns,
add a case to `scripts/test-dispatch-wrapper.sh` for wrapper semantics and a
case to `scripts/doctor.sh` when local Codex help support should be checked.

## Code of conduct

Don't be a jerk. Assume good faith. Keep criticism technical and specific.

## License

By contributing, you agree that your contributions will be licensed under the MIT License, same as the rest of the project.
