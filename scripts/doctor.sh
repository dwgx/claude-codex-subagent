#!/usr/bin/env bash
# doctor.sh — health check for a claude-codex-subagent install
#
# Runs every check that might break a fresh install, reports a clean
# pass/fail summary, and gives actionable remediation for each failure.
#
# Usage:
#   ./scripts/doctor.sh

set -uo pipefail

PASS=0
FAIL=0
WARN=0

check() {
  local label="$1"; shift
  local status="$1"; shift
  local detail="${1:-}"
  case "$status" in
    pass) printf '  [\033[32mPASS\033[0m] %s\n' "$label"; PASS=$((PASS+1)) ;;
    fail) printf '  [\033[31mFAIL\033[0m] %s\n' "$label"; FAIL=$((FAIL+1))
          [[ -n "$detail" ]] && printf '         ↳ %s\n' "$detail" ;;
    warn) printf '  [\033[33mWARN\033[0m] %s\n' "$label"; WARN=$((WARN+1))
          [[ -n "$detail" ]] && printf '         ↳ %s\n' "$detail" ;;
  esac
}

section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

section "1. Codex CLI"

if command -v codex >/dev/null 2>&1; then
  check "codex on PATH" pass
  if CODEX_VERSION="$(codex --version 2>/dev/null)"; then
    check "codex --version returns cleanly" pass
    printf '         version: %s\n' "$CODEX_VERSION"
  else
    check "codex --version returns cleanly" fail "codex exists but --version failed; reinstall with: npm install -g @openai/codex"
  fi
else
  check "codex on PATH" fail "install with: npm install -g @openai/codex && codex login"
fi

section "2. Required flags on this codex build"

# Test each flag by running `codex exec --help` and grepping
if command -v codex >/dev/null 2>&1; then
  HELP_OUT="$(codex exec --help 2>&1 || true)"
  for flag in "--skip-git-repo-check" "--full-auto" "--dangerously-bypass-approvals-and-sandbox" "-C" "--cd" "-p" "--profile" "--config"; do
    if echo "$HELP_OUT" | grep -q -- "$flag"; then
      check "$flag supported" pass
    else
      check "$flag supported" fail "your codex CLI is missing this flag — upgrade: npm install -g @openai/codex@latest"
    fi
  done
else
  check "flag checks" warn "skipped — codex not available"
fi

section "3. Shell environment"

if command -v bash >/dev/null 2>&1; then
  check "bash available" pass
else
  check "bash available" fail "install git-bash or WSL on Windows, or a standard bash on Unix"
fi

if command -v openssl >/dev/null 2>&1; then
  check "openssl available (for temp log filenames)" pass
else
  check "openssl available (for temp log filenames)" warn "skill will fall back to date-based filename; install openssl for best behavior"
fi

TMPDIR_TEST="${CODEX_DISPATCH_TMPDIR:-/tmp}"
if [[ -d "$TMPDIR_TEST" ]] && [[ -w "$TMPDIR_TEST" ]]; then
  check "$TMPDIR_TEST is writable" pass
else
  check "$TMPDIR_TEST is writable" fail "set CODEX_DISPATCH_TMPDIR to a writable directory"
fi

section "4. Claude Code skill install"

SKILL_PATH="${HOME}/.claude/skills/codex-subagent/SKILL.md"
if [[ -f "$SKILL_PATH" ]]; then
  check "SKILL.md installed at $SKILL_PATH" pass
  SKILL_SIZE=$(wc -c < "$SKILL_PATH" 2>/dev/null || echo 0)
  if [[ "$SKILL_SIZE" -gt 5000 ]]; then
    check "SKILL.md has reasonable size ($SKILL_SIZE bytes)" pass
  else
    check "SKILL.md has reasonable size" warn "file is only $SKILL_SIZE bytes — may be truncated"
  fi
  if head -1 "$SKILL_PATH" | grep -q '^---'; then
    check "SKILL.md has frontmatter" pass
  else
    check "SKILL.md has frontmatter" fail "SKILL.md is missing YAML frontmatter — skill won't load"
  fi
else
  check "SKILL.md installed at $SKILL_PATH" fail "run: cp -r skills/codex-subagent ~/.claude/skills/"
fi

section "5. Personas (optional)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSONA_DIR="$SCRIPT_DIR/../personas"
if [[ -d "$PERSONA_DIR" ]]; then
  PERSONA_COUNT=$(find "$PERSONA_DIR" -maxdepth 1 -name '*.md' -not -name 'README.md' 2>/dev/null | wc -l)
  check "personas/ directory ($PERSONA_COUNT persona files)" pass
else
  check "personas/ directory" warn "not found — personas are optional"
fi

# --- summary ---
printf '\n\033[1mSummary\033[0m\n'
printf '  \033[32m%d passed\033[0m, \033[33m%d warnings\033[0m, \033[31m%d failed\033[0m\n\n' "$PASS" "$WARN" "$FAIL"

if [[ $FAIL -eq 0 ]]; then
  printf '\033[32m✓ doctor clean — skill is ready to use\033[0m\n'
  exit 0
else
  printf '\033[31m✗ doctor found %d blocking issue(s)\033[0m\n' "$FAIL"
  printf '  Fix the FAILs above, then re-run: ./scripts/doctor.sh\n'
  exit 1
fi
