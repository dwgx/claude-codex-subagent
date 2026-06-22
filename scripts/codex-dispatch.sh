#!/usr/bin/env bash
# codex-dispatch.sh — canonical codex exec wrapper
#
# Thin CLI wrapper around `codex exec` that applies the skill's conventions
# automatically: --skip-git-repo-check, adaptive sandbox, stderr to a random
# /tmp log, prompt via stdin, optional persona loading, and current Codex CLI
# automation flags.
#
# Usage:
#   ./scripts/codex-dispatch.sh [OPTIONS] "<prompt>"
#   echo "prompt" | ./scripts/codex-dispatch.sh [OPTIONS]
#
# Options:
#   --persona <name>     Load personas/<name>.md as the prompt body,
#                        replacing {{TASK}} with the argument.
#   --sandbox <mode>     workspace-write | read-only | danger-full-access |
#                        bypass | full-auto (default: workspace-write)
#   --effort <level>     low | medium | high | default (default: default)
#   --model <name>       Use a specific model (-m).
#   --cd <dir>           Set Codex working directory (-C).
#   --add-dir <dir>      Add an extra writable directory (repeatable).
#   --profile <name>     Use a codex config profile (-p).
#   --config <k=v>       Pass through a Codex config override (repeatable).
#   --search             Enable live web search for this exec run by setting
#                        web_search="live".
#   --json               Emit Codex event JSONL.
#   -o, --output-last-message <file>
#                        Write Codex's final message to a file.
#   --output-schema <file>
#                        Require final response to match a JSON Schema.
#   --ephemeral          Do not persist Codex session files.
#   --ignore-user-config Do not load $CODEX_HOME/config.toml.
#   --ignore-rules       Do not load user/project execpolicy .rules files.
#   --strict-config      Fail if config contains unknown fields.
#   --enable <feature>   Enable a Codex feature flag (repeatable).
#   --disable <feature>  Disable a Codex feature flag (repeatable).
#   --resume             Resume the last session instead of starting fresh.
#                        Fresh-session context flags such as --cd, --profile,
#                        --add-dir, and non-bypass --sandbox are rejected.
#   --show-stderr        Print the /tmp log on exit (for debugging).
#   --debug              Print the assembled command and exit 0.
#   -h, --help           Show this help.
#
# Precedence:
#   Explicit CLI flags win over persona frontmatter. Persona sandbox/effort
#   values are defaults only when --sandbox/--effort were not provided.
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
SANDBOX="workspace-write"
EFFORT="default"
MODEL=""
CD_DIR=""
PROFILE=""
OUTPUT_LAST_MESSAGE=""
OUTPUT_SCHEMA=""
RESUME=0
SHOW_STDERR=0
DEBUG=0
SEARCH=0
JSON_EVENTS=0
EPHEMERAL=0
IGNORE_USER_CONFIG=0
IGNORE_RULES=0
STRICT_CONFIG=0
PROMPT=""
ADD_DIRS=()
CONFIGS=()
ENABLES=()
DISABLES=()
SANDBOX_SET=0
EFFORT_SET=0
RESUME_BYPASS=0

need_value() {
  local opt="$1"
  local argc="$2"
  if [[ "$argc" -lt 2 ]]; then
    echo "error: $opt requires a value" >&2
    usage 1 >&2
  fi
}

# --- arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --persona)             need_value "$1" "$#"; PERSONA="$2"; shift 2 ;;
    --sandbox)             need_value "$1" "$#"; SANDBOX="$2"; SANDBOX_SET=1; shift 2 ;;
    --effort)              need_value "$1" "$#"; EFFORT="$2"; EFFORT_SET=1; shift 2 ;;
    --model)               need_value "$1" "$#"; MODEL="$2"; shift 2 ;;
    --cd)                  need_value "$1" "$#"; CD_DIR="$2"; shift 2 ;;
    --add-dir)             need_value "$1" "$#"; ADD_DIRS+=("$2"); shift 2 ;;
    --profile)             need_value "$1" "$#"; PROFILE="$2"; shift 2 ;;
    --config)              need_value "$1" "$#"; CONFIGS+=("$2"); shift 2 ;;
    --search)              SEARCH=1; shift ;;
    --json)                JSON_EVENTS=1; shift ;;
    -o|--output-last-message)
                            need_value "$1" "$#"; OUTPUT_LAST_MESSAGE="$2"; shift 2 ;;
    --output-schema)       need_value "$1" "$#"; OUTPUT_SCHEMA="$2"; shift 2 ;;
    --ephemeral)           EPHEMERAL=1; shift ;;
    --ignore-user-config)  IGNORE_USER_CONFIG=1; shift ;;
    --ignore-rules)        IGNORE_RULES=1; shift ;;
    --strict-config)       STRICT_CONFIG=1; shift ;;
    --enable)              need_value "$1" "$#"; ENABLES+=("$2"); shift 2 ;;
    --disable)             need_value "$1" "$#"; DISABLES+=("$2"); shift 2 ;;
    --resume)              RESUME=1; shift ;;
    --show-stderr)         SHOW_STDERR=1; shift ;;
    --debug)               DEBUG=1; shift ;;
    -h|--help)             usage 0 ;;
    --)                    shift; PROMPT="${*:-}"; break ;;
    -*)                    echo "unknown option: $1" >&2; usage 1 >&2 ;;
    *)                     PROMPT="$*"; break ;;
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
    avail=""
    for f in "$SCRIPT_DIR/../personas/"*.md; do
      [[ -f "$f" ]] || continue
      base="$(basename "$f" .md)"
      [[ "$base" == "README" ]] && continue
      avail+="$base "
    done
    echo "available: $avail" >&2
    exit 3
  fi
  # strip frontmatter, substitute {{TASK}}
  PERSONA_BODY="$(awk '/^---$/{c++; next} c>=2' "$PERSONA_FILE")"

  # Pull persona's recommended sandbox/effort from frontmatter if caller
  # didn't override on the CLI (frontmatter is hint, CLI wins). Runtime
  # defaults only apply to fresh sessions; resume inherits prior context unless
  # the caller explicitly supplies resume-supported flags.
  if [[ $RESUME -eq 0 && $SANDBOX_SET -eq 0 ]]; then
    P_SANDBOX="$(awk '/^sandbox:/{print $2; exit}' "$PERSONA_FILE")"
    [[ -n "$P_SANDBOX" ]] && SANDBOX="$P_SANDBOX"
  fi
  if [[ $RESUME -eq 0 && $EFFORT_SET -eq 0 ]]; then
    P_EFFORT="$(awk '/^effort:/{print $2; exit}' "$PERSONA_FILE")"
    [[ -n "$P_EFFORT" ]] && EFFORT="$P_EFFORT"
  fi

  PROMPT="${PERSONA_BODY//\{\{TASK\}\}/$PROMPT}"
fi

if [[ -z "$PROMPT" ]]; then
  echo "error: no prompt provided (pass as argument, stdin, or use --persona)" >&2
  usage 1 >&2
fi

# --- map sandbox name to codex flag(s) ---
case "$SANDBOX" in
  workspace|workspace-write|full-auto)
    # `--full-auto` is deprecated in Codex CLI 0.141.0. Keep the old
    # user-facing alias, but emit the current explicit sandbox flag.
    SANDBOX_FLAGS=(--sandbox workspace-write)
    ;;
  read-only)
    SANDBOX_FLAGS=(--sandbox read-only)
    ;;
  danger-full-access)
    SANDBOX_FLAGS=(--sandbox danger-full-access)
    ;;
  bypass)
    SANDBOX_FLAGS=(--dangerously-bypass-approvals-and-sandbox)
    ;;
  *)
    echo "error: unknown sandbox: $SANDBOX (want: workspace-write|read-only|danger-full-access|bypass|full-auto)" >&2
    exit 1
    ;;
esac

if [[ $RESUME -eq 1 ]]; then
  if [[ -n "$CD_DIR" || -n "$PROFILE" || ${#ADD_DIRS[@]} -gt 0 ]]; then
    echo "error: --resume cannot be combined with --cd, --profile, or --add-dir; resume inherits the previous session context" >&2
    exit 1
  fi
  if [[ $SANDBOX_SET -eq 1 ]]; then
    case "$SANDBOX" in
      bypass)
        RESUME_BYPASS=1
        ;;
      *)
        echo "error: --resume cannot be combined with --sandbox $SANDBOX; Codex resume only supports bypass escalation, not setting a fresh sandbox" >&2
        exit 1
        ;;
    esac
  fi
fi

# --- build command pieces ---
TMPDIR_="${CODEX_DISPATCH_TMPDIR:-/tmp}"
mkdir -p "$TMPDIR_"
LOGFILE="$TMPDIR_/codex-$(openssl rand -hex 4 2>/dev/null || date +%s%N | sha256sum | head -c 8).log"

CMD=(codex exec --skip-git-repo-check)
if [[ $RESUME -eq 1 ]]; then
  CMD+=(resume --last)
else
  CMD+=("${SANDBOX_FLAGS[@]}")
fi
[[ $RESUME_BYPASS -eq 1 ]] && CMD+=(--dangerously-bypass-approvals-and-sandbox)
[[ -n "$MODEL" ]] && CMD+=(-m "$MODEL")
[[ -n "$CD_DIR"  ]] && CMD+=(-C "$CD_DIR")
for dir in "${ADD_DIRS[@]}"; do
  CMD+=(--add-dir "$dir")
done
[[ -n "$PROFILE" ]] && CMD+=(-p "$PROFILE")
[[ $SEARCH -eq 1 ]] && CMD+=(--config "web_search=\"live\"")
[[ $JSON_EVENTS -eq 1 ]] && CMD+=(--json)
[[ -n "$OUTPUT_LAST_MESSAGE" ]] && CMD+=(-o "$OUTPUT_LAST_MESSAGE")
[[ -n "$OUTPUT_SCHEMA" ]] && CMD+=(--output-schema "$OUTPUT_SCHEMA")
[[ $EPHEMERAL -eq 1 ]] && CMD+=(--ephemeral)
[[ $IGNORE_USER_CONFIG -eq 1 ]] && CMD+=(--ignore-user-config)
[[ $IGNORE_RULES -eq 1 ]] && CMD+=(--ignore-rules)
[[ $STRICT_CONFIG -eq 1 ]] && CMD+=(--strict-config)
for feature in "${ENABLES[@]}"; do
  CMD+=(--enable "$feature")
done
for feature in "${DISABLES[@]}"; do
  CMD+=(--disable "$feature")
done
if [[ "$EFFORT" != "default" ]]; then
  CMD+=(--config "model_reasoning_effort=\"$EFFORT\"")
fi
for config in "${CONFIGS[@]}"; do
  CMD+=(--config "$config")
done

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
  # Codex 0.141.0 accepts a resume prompt positionally or as `-` from stdin.
  # Use stdin for multiline prompts and stable quoting.
  printf '%s\n' "$PROMPT" | "${CMD[@]}" - 2>>"$LOGFILE"
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
