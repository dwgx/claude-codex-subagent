#!/usr/bin/env bash
# sync-skill.sh — maintainer workflow: sync the repo's SKILL.md to
# your locally-installed copy, or vice versa.
#
# Usage:
#   ./scripts/sync-skill.sh to-local    # repo -> ~/.claude/skills/
#   ./scripts/sync-skill.sh from-local  # ~/.claude/skills/ -> repo
#   ./scripts/sync-skill.sh diff        # show diff without copying

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_SKILL="$SCRIPT_DIR/../skills/codex-subagent/SKILL.md"
LOCAL_SKILL="${HOME}/.claude/skills/codex-subagent/SKILL.md"

direction="${1:-}"

case "$direction" in
  to-local)
    mkdir -p "$(dirname "$LOCAL_SKILL")"
    cp "$REPO_SKILL" "$LOCAL_SKILL"
    echo "synced $REPO_SKILL -> $LOCAL_SKILL"
    ;;
  from-local)
    if [[ ! -f "$LOCAL_SKILL" ]]; then
      echo "error: local skill not found at $LOCAL_SKILL" >&2
      exit 1
    fi
    cp "$LOCAL_SKILL" "$REPO_SKILL"
    echo "synced $LOCAL_SKILL -> $REPO_SKILL"
    echo "don't forget: cd $(dirname "$SCRIPT_DIR") && git add -A && git commit && git push"
    ;;
  diff)
    if [[ ! -f "$LOCAL_SKILL" ]]; then
      echo "error: local skill not found at $LOCAL_SKILL" >&2
      exit 1
    fi
    diff -u "$REPO_SKILL" "$LOCAL_SKILL" || true
    ;;
  *)
    echo "usage: $0 {to-local|from-local|diff}" >&2
    exit 1
    ;;
esac
