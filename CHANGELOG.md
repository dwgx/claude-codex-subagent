# Changelog

All notable changes to this project will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/).

## [1.0.0] — 2026-04-14

### Added
- Initial release of `claude-codex-subagent`.
- `skills/codex-subagent/SKILL.md` — core skill teaching Claude to delegate
  expensive work (web search, large reads, long writes, bulk analysis,
  audits) to the local `codex exec` CLI.
- `.claude-plugin/plugin.json` — Claude Code plugin manifest for
  `/plugin install` users.
- `personas/` — 5 pre-written persona templates (`reviewer`, `debugger`,
  `auditor`, `researcher`, `refactorer`) with frontmatter, `{{TASK}}`
  placeholder, and explicit return-format contracts.
- `scripts/codex-dispatch.sh` — CLI wrapper for direct dispatch with
  persona loading, sandbox/effort flags, and canonical logging pattern.
- `scripts/doctor.sh` — health check covering Codex CLI presence, flag
  support, shell environment, skill install location, and personas dir.
- `scripts/sync-skill.sh` — maintainer helper for syncing
  `~/.claude/skills/codex-subagent/SKILL.md` to/from the repo.
- `README.md`, `INSTALL.md`, `CONTRIBUTING.md`, `LICENSE` (MIT),
  `.gitattributes`, `.gitignore`.
- `examples/sample-dispatches.md` — 8 real dispatch patterns you can
  copy (web lookup, bulk analysis, long writes, audit, parallel batch,
  resume, disagreement, rescue mode).
- GitHub Actions CI: validates JSON manifest, SKILL.md frontmatter,
  and runs `shellcheck` on all scripts.
- Issue templates for bug reports and feature requests.

### Design decisions captured in this release

- **Adaptive sandbox** — defaults to `--full-auto`, auto-escalates to
  `--dangerously-bypass-approvals-and-sandbox` for network/cross-workspace
  tasks without prompting the user. Transparency via one-line status,
  not approval gates.
- **Thin-forwarder contract** — Codex's stdout is authoritative. No
  Claude-side answer editing.
- **Stderr to temp log** — `2>>"/tmp/codex-$(openssl rand -hex 4).log"`
  instead of `/dev/null`. Clean happy path, full debug on failure.
- **Structured outcome classification** — `success` / `partial` / `error`
  drives the post-dispatch decision tree.
- **Resume-first follow-ups** — `codex exec resume --last` preferred
  over fresh calls when context is still relevant.
- **Zero runtime dependencies** — no Node, no Python, no MCP server.
  Just markdown + bash.

[1.0.0]: https://github.com/dwgx/claude-codex-subagent/releases/tag/v1.0.0
