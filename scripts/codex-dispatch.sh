#!/usr/bin/env bash
# codex-dispatch.sh — canonical codex exec wrapper
#
# Thin CLI wrapper around `codex exec` that applies the skill's
# conventions automatically: --skip-git-repo-check, adaptive sandbox,
# stderr to a random /tmp log, heredoc prompt via stdin, optional
# persona loading.
#
# Usage:
#   ./scripts/codex-dispatch.sh [OPTIONS] "<prompt>"
#   echo "prompt" | ./scripts/codex-dispatch.sh [OPTIONS]
#
# Options:
#   --persona <name>     Load personas/<name>.md as the prompt body,
#                        replacing {{TASK}} with the argument.
#   --sandbox <mode>     full-auto | bypass | read-only (default: full-auto)
#   --effort <level>     low | medium | high | default (default: default)
#   --cd <dir>           Set Codex working directory (-C).
#   --profile <name>     Use a codex config profile (-p).
#   --resume             Resume the last session instead of starting fresh.
#   --show-stderr        Print the /tmp log on exit (for debugging).
#   --debug              Print the assembled command and exit 0.
#   -h, --help           Show this help.
#
# Exit codes:
#   0    success
#   1    usage error
#   2    codex binary not found
#   3    persona file not found
#   N    codex's exit code on failure
#
# Environment:
#   CODEX_DISPATCH_TMPDIR  override /tmp for log files (default: /tmp)

set -euo pipefail

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# --- defaults ---
PERSONA=""
SANDBOX="full-auto"
EFFORT="default"
CD_DIR=""
PROFILE=""
RESUME=0
SHOW_STDERR=0
DEBUG=0
PROMPT=""

# --- arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --persona)     PERSONA="$2"; shift 2 ;;
    --sandbox)     SANDBOX="$2"; shift 2 ;;
    --effort)      EFFORT="$2"; shift 2 ;;
    --cd)          CD_DIR="$2"; shift 2 ;;
    --profile)     PROFILE="$2"; shift 2 ;;
    --resume)      RESUME=1; shift ;;
    --show-stderr) SHOW_STDERR=1; shift ;;
    --debug)       DEBUG=1; shift ;;
    -h|--help)     usage 0 ;;
    --)            shift; PROMPT="${*:-}"; break ;;
    -*)            echo "unknown option: $1" >&2; usage 1 >&2 ;;
    *)             PROMPT="$*"; break ;;
  esac
done

# --- sanity checks ---
if ! command -v codex >/dev/null 2>&1; then
  echo "error: codex CLI not found on PATH" >&2
  echo "install: npm install -g @openai/codex && codex login" >&2
  exit 2
fi

# --- read prompt from stdin if not provided ---
if [[ -z "$PROMPT" ]] && [[ ! -t 0 ]]; then
  PROMPT="$(cat)"
fi

# --- apply persona if set ---
if [[ -n "$PERSONA" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PERSONA_FILE="$SCRIPT_DIR/../personas/${PERSONA}.md"
  if [[ ! -f "$PERSONA_FILE" ]]; then
    echo "error: persona file not found: $PERSONA_FILE" >&2
    echo "available: $(ls "$SCRIPT_DIR/../personas/" 2>/dev/null | grep '\.md$' | grep -v README | sed 's/\.md$//' | tr '\n' ' ')" >&2
    exit 3
  fi
  # strip frontmatter, substitute {{TASK}}
  PERSONA_BODY="$(awk '/^---$/{c++; next} c>=2' "$PERSONA_FILE")"

  # pull persona's recommended sandbox/effort from frontmatter if caller
  # didn't override on the CLI (frontmatter is hint, CLI wins)
  if [[ "$SANDBOX" == "full-auto" ]]; then
    P_SANDBOX="$(awk '/^sandbox:/{print $2; exit}' "$PERSONA_FILE")"
    [[ -n "$P_SANDBOX" ]] && SANDBOX="$P_SANDBOX"
  fi
  if [[ "$EFFORT" == "default" ]]; then
    P_EFFORT="$(awk '/^effort:/{print $2; exit}' "$PERSONA_FILE")"
    [[ -n "$P_EFFORT" ]] && EFFORT="$P_EFFORT"
  fi

  PROMPT="${PERSONA_BODY//\{\{TASK\}\}/$PROMPT}"
fi

if [[ -z "$PROMPT" ]]; then
  echo "error: no prompt provided (pass as argument, stdin, or use --persona)" >&2
  usage 1 >&2
fi

# --- map sandbox name to codex flag ---
case "$SANDBOX" in
  full-auto)  SANDBOX_FLAG="--full-auto" ;;
  bypass)     SANDBOX_FLAG="--dangerously-bypass-approvals-and-sandbox" ;;
  read-only)  SANDBOX_FLAG="--sandbox read-only" ;;
  *)          echo "error: unknown sandbox: $SANDBOX (want: full-auto|bypass|read-only)" >&2; exit 1 ;;
esac

# --- build command pieces ---
TMPDIR_="${CODEX_DISPATCH_TMPDIR:-/tmp}"
mkdir -p "$TMPDIR_"
LOGFILE="$TMPDIR_/codex-$(openssl rand -hex 4 2>/dev/null || date +%s%N | sha256sum | head -c 8).log"

CMD=(codex exec --skip-git-repo-check)
[[ $RESUME -eq 1 ]] && CMD+=(resume --last) || CMD+=($SANDBOX_FLAG)
[[ -n "$CD_DIR"  ]] && CMD+=(-C "$CD_DIR")
[[ -n "$PROFILE" ]] && CMD+=(-p "$PROFILE")
if [[ "$EFFORT" != "default" ]] && [[ $RESUME -eq 0 ]]; then
  CMD+=(--config "model_reasoning_effort=\"$EFFORT\"")
fi

# --- debug mode: print and exit ---
if [[ $DEBUG -eq 1 ]]; then
  echo "Would run:"
  printf '  %q ' "${CMD[@]}"
  echo
  echo "Stderr log: $LOGFILE"
  echo "Prompt via stdin (first 300 chars):"
  echo "${PROMPT:0:300}"
  exit 0
fi

# --- dispatch ---
# feed prompt via stdin (heredoc equivalent)
if [[ $RESUME -eq 1 ]]; then
  # resume takes prompt on stdin
  printf '%s\n' "$PROMPT" | "${CMD[@]}" 2>>"$LOGFILE"
else
  # fresh call: prompt as positional via stdin redirection
  printf '%s\n' "$PROMPT" | "${CMD[@]}" - 2>>"$LOGFILE"
fi
EXIT_CODE=$?

if [[ $SHOW_STDERR -eq 1 ]] || [[ $EXIT_CODE -ne 0 ]]; then
  echo "--- stderr log: $LOGFILE ---" >&2
  cat "$LOGFILE" >&2
fi

exit $EXIT_CODE
