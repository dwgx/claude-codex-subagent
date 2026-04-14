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

```bash
ls ~/.claude/skills/codex-subagent/SKILL.md
```

Restart Claude Code, and the skill should appear in your available skills list. Test it with:

```
用 codex 查一下 bun 的最新版本
```

---

## Option B — As a Claude Code plugin

If your Claude Code build supports plugin installation:

```
/plugin install https://github.com/dwgx/claude-codex-subagent
```

Or, if you're using a marketplace, add this repo as a source and install via the marketplace UI.

The plugin manifest is at `.claude-plugin/plugin.json`.

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
