# Installation guide

Three install paths, pick whichever fits your setup.

## Prerequisites

Before installing this skill, make sure you have:

1. **Claude Code** working — either the CLI, desktop app, web app, or an IDE extension. If `claude` runs in your terminal, you're good.
2. **Codex CLI** installed and authenticated:
   ```bash
   npm install -g @openai/codex
   codex login
   codex --version   # sanity check
   ```
3. **A bash-compatible shell**:
   - **macOS / Linux** — built-in `bash` or `zsh`, nothing to do.
   - **Windows** — either [Git for Windows](https://git-scm.com/download/win) (provides git-bash), or [WSL](https://learn.microsoft.com/en-us/windows/wsl/install). Claude Code uses git-bash by default on Windows — no extra setup.

Verify all three work by running in your terminal:

```bash
claude --version
codex --version
bash --version
```

---

## Option A — Manual skill copy (recommended for most people)

The simplest, most portable install. Works on every platform, no plugin system required.

### macOS / Linux

```bash
git clone https://github.com/dwgx/claude-codex-subagent.git /tmp/claude-codex-subagent
mkdir -p ~/.claude/skills
cp -r /tmp/claude-codex-subagent/skills/codex-subagent ~/.claude/skills/
rm -rf /tmp/claude-codex-subagent
```

### Windows (git-bash)

```bash
git clone https://github.com/dwgx/claude-codex-subagent.git /tmp/claude-codex-subagent
mkdir -p ~/.claude/skills
cp -r /tmp/claude-codex-subagent/skills/codex-subagent ~/.claude/skills/
rm -rf /tmp/claude-codex-subagent
```

(Same commands — git-bash maps `~` to your Windows user home and `/tmp` to `%LOCALAPPDATA%\Temp`.)

### Windows (PowerShell)

```powershell
git clone https://github.com/dwgx/claude-codex-subagent.git $env:TEMP\claude-codex-subagent
New-Item -ItemType Directory -Force -Path $HOME\.claude\skills | Out-Null
Copy-Item -Recurse -Force $env:TEMP\claude-codex-subagent\skills\codex-subagent $HOME\.claude\skills\
Remove-Item -Recurse -Force $env:TEMP\claude-codex-subagent
```

### Verify

Run the built-in health check — it validates everything in one go:

```bash
./scripts/doctor.sh
```

A clean install shows 17+ passes, 0 failures. If anything fails, the script tells you exactly what to fix.

If you installed via curl (Option C) and don't have the scripts locally, verify manually:

```bash
ls ~/.claude/skills/codex-subagent/SKILL.md
codex --version
```

Then restart Claude Code so the skill index loads, and run the 30-second smoke test below.

### 30-second smoke test

Open a fresh Claude Code conversation and ask:

```
用 codex 查一下 bun 的最新穩定版本,只回一行
```

Expected behavior:

1. Claude announces the dispatch in one line, mentioning the sandbox choice (should be `--dangerously-bypass-approvals-and-sandbox` because the task needs network).
2. You see Claude run a Bash call to `codex exec`.
3. After 10–30 seconds, Claude comes back with a single line like `bun 1.2.4 released 2026-03-28`.

If Claude **doesn't dispatch** and instead tries to WebSearch / WebFetch itself: the skill didn't trigger. Check that the skill file is actually at `~/.claude/skills/codex-subagent/SKILL.md` and that Claude Code was restarted after install.

If Claude dispatches but the call fails: re-run the command Claude showed in your own terminal (without the `2>>` redirect) to see the raw error, then check the troubleshooting section below.

---

## Option B — As a Claude Code plugin (marketplace install)

Claude Code plugins are installed via marketplaces. This repo is a single-plugin marketplace, so installing is a two-step process:

```
/plugin marketplace add dwgx/claude-codex-subagent
/plugin install claude-codex-subagent@claude-codex-subagent
```

The first command registers this repo as a marketplace source. The second installs the plugin from it.

To update later:
```
/plugin update claude-codex-subagent@claude-codex-subagent
```

To remove:
```
/plugin uninstall claude-codex-subagent@claude-codex-subagent
/plugin marketplace remove claude-codex-subagent
```

> **Note:** If `/plugin marketplace add` doesn't resolve the repo (different Claude Code build, older version, or network restrictions), fall back to **Option A — manual copy**. That path has zero moving parts and always works.

---

## Option C — One-liner (curl)

Skip the clone, just grab the SKILL.md directly:

```bash
mkdir -p ~/.claude/skills/codex-subagent && \
curl -fsSL https://raw.githubusercontent.com/dwgx/claude-codex-subagent/main/skills/codex-subagent/SKILL.md \
  -o ~/.claude/skills/codex-subagent/SKILL.md
```

Fastest install, but you won't have the README / examples locally.

---

## Updating

### Manual / curl install
Re-run the install command. It overwrites the old SKILL.md.

### Plugin install
```
/plugin update claude-codex-subagent
```

---

## Uninstalling

```bash
rm -rf ~/.claude/skills/codex-subagent
```

Or via plugin system:
```
/plugin uninstall claude-codex-subagent
```

---

## Platform notes

### Pure Windows (cmd.exe or PowerShell without git-bash)

Claude Code on Windows uses bash by default for shell commands — if you installed via the Windows installer, you already have git-bash bundled. This is the path we test.

If you have a Claude Code build that routes commands through PowerShell or cmd.exe:

- `/tmp/` doesn't exist → the skill's temp-log path won't work. Set the env var `CODEX_DISPATCH_TMPDIR=%TEMP%` in your Claude Code environment so `scripts/codex-dispatch.sh` writes logs to the Windows temp directory instead.
- `openssl rand -hex 4` may not exist → `scripts/codex-dispatch.sh` falls back to a `date`/`sha256sum` based filename. The SKILL.md also documents the fallback.
- Heredoc syntax (`<<'EOF'`) works in PowerShell 5.1+ via `@'...'@` but **not** in cmd.exe. If you're in cmd.exe, switch to PowerShell or install git-bash.

**The recommended setup is still Git for Windows (git-bash)** — it's what Claude Code defaults to on Windows and it's what the skill is tested against. Pure cmd.exe is not supported.

### WSL

WSL works out of the box. Install Codex inside your WSL distro (`npm install -g @openai/codex` from inside WSL, not Windows), and make sure Claude Code's working directory is a WSL path (`/mnt/c/...` or `~`).

### macOS

No special considerations. The only watchout: some macOS versions ship an older bash (3.2) that's missing features used by `codex-dispatch.sh`. Install a newer bash via Homebrew if you hit syntax errors:

```bash
brew install bash
```

The skill itself (SKILL.md) has no bash version requirement — it's Claude constructing each `codex exec` call, not a shell script.

### Linux

Just works.

---

## Troubleshooting install

**`codex: command not found` after install**
The skill is installed but Codex CLI isn't. Run:
```bash
npm install -g @openai/codex
codex login
```
Then restart your terminal so the new PATH takes effect.

**`claude` doesn't see the skill**
Check the file is actually there:
```bash
ls -la ~/.claude/skills/codex-subagent/SKILL.md
```
If it's there but not showing up, fully quit and restart Claude Code — the skill index is loaded on startup.

**`mkdir: cannot create directory '~/.claude/skills'`**
On Windows PowerShell, `~` doesn't expand the same way. Use `$HOME\.claude\skills` explicitly.

**Windows permission errors**
If `Copy-Item` errors with access-denied, run PowerShell as Administrator, or use git-bash instead (it doesn't hit the same ACL issues).

**Git clone fails behind a corporate proxy**
Set git's proxy:
```bash
git config --global http.proxy http://your-proxy:port
```
Or use Option C (curl) which may work even when git doesn't.

Still stuck? [Open an issue.](https://github.com/dwgx/claude-codex-subagent/issues)
