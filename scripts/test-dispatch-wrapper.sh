#!/usr/bin/env bash
# test-dispatch-wrapper.sh - semantic tests for scripts/codex-dispatch.sh
#
# These tests use a temporary fake `codex` binary and `--debug`, so they verify
# wrapper command construction without invoking a model, using network, or
# requiring Codex authentication.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISPATCH="$SCRIPT_DIR/codex-dispatch.sh"

PASS=0
FAIL=0
LAST_OUT=""

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  if [[ -n "${2:-}" ]]; then
    printf '         %s\n' "$2" >&2
  fi
  FAIL=$((FAIL + 1))
}

pass() {
  printf '  [PASS] %s\n' "$1"
  PASS=$((PASS + 1))
}

run_debug() {
  LAST_OUT="$(bash "$DISPATCH" "$@" --debug "Return OK" 2>&1)"
}

run_expect_fail() {
  set +e
  LAST_OUT="$(bash "$DISPATCH" "$@" 2>&1)"
  local code=$?
  set -e
  [[ "$code" -ne 0 ]]
}

assert_contains() {
  local label="$1"
  local needle="$2"
  if grep -q -- "$needle" <<<"$LAST_OUT"; then
    pass "$label"
  else
    fail "$label" "expected to find: $needle"$'\n'"output: $LAST_OUT"
  fi
}

assert_not_contains() {
  local label="$1"
  local needle="$2"
  if grep -q -- "$needle" <<<"$LAST_OUT"; then
    fail "$label" "did not expect: $needle"$'\n'"output: $LAST_OUT"
  else
    pass "$label"
  fi
}

assert_fail_contains() {
  local label="$1"
  shift
  if run_expect_fail "$@"; then
    if grep -q -- "$label" <<<"$LAST_OUT"; then
      pass "$label"
    else
      fail "$label" "command failed, but message did not match"$'\n'"output: $LAST_OUT"
    fi
  else
    fail "$label" "command unexpectedly succeeded"$'\n'"output: $LAST_OUT"
  fi
}

setup_fake_codex() {
  FAKEBIN="$(mktemp -d)"
  cat >"$FAKEBIN/codex" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "codex-cli fake"
  exit 0
fi
if [[ "${1:-}" == "exec" && "${2:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: codex exec [OPTIONS] [PROMPT]
--skip-git-repo-check --sandbox workspace-write read-only danger-full-access
--dangerously-bypass-approvals-and-sandbox -C --cd --add-dir -p --profile
--config --json --output-last-message --output-schema --ephemeral
--ignore-user-config --ignore-rules --strict-config --enable --disable
HELP
  exit 0
fi
exit 0
EOF
  chmod +x "$FAKEBIN/codex"
  export PATH="$FAKEBIN:$PATH"
}

cleanup() {
  if [[ -n "${FAKEBIN:-}" && -d "$FAKEBIN" ]]; then
    rm -rf "$FAKEBIN"
  fi
}

trap cleanup EXIT

cd "$REPO_ROOT"
setup_fake_codex

printf 'Dispatch wrapper behavior tests\n'

run_debug
assert_contains "default sandbox is workspace-write" "--sandbox[[:space:]]*workspace-write"
assert_not_contains "default sandbox is not bypass" "--dangerously-bypass-approvals-and-sandbox"

run_debug --sandbox full-auto
assert_contains "full-auto alias maps to workspace-write" "--sandbox[[:space:]]*workspace-write"
assert_not_contains "full-auto alias does not emit deprecated flag" "--full-auto"

run_debug --sandbox bypass
assert_contains "bypass sandbox emits yolo flag" "--dangerously-bypass-approvals-and-sandbox"

run_debug --sandbox read-only
assert_contains "read-only sandbox emits read-only" "--sandbox[[:space:]]*read-only"

run_debug --sandbox danger-full-access
assert_contains "danger-full-access sandbox emits danger-full-access" "--sandbox[[:space:]]*danger-full-access"

run_debug --persona researcher
assert_contains "researcher persona defaults to bypass" "--dangerously-bypass-approvals-and-sandbox"
assert_contains "researcher persona defaults to medium effort" "model_reasoning_effort=\\\\\\\"medium\\\\\\\""

run_debug --persona researcher --sandbox workspace-write
assert_contains "explicit workspace-write beats researcher bypass" "--sandbox[[:space:]]*workspace-write"
assert_not_contains "explicit workspace-write is not escalated" "--dangerously-bypass-approvals-and-sandbox"

run_debug --persona researcher --sandbox read-only
assert_contains "explicit read-only beats researcher bypass" "--sandbox[[:space:]]*read-only"
assert_not_contains "explicit read-only is not escalated" "--dangerously-bypass-approvals-and-sandbox"

run_debug --persona reviewer --effort default
assert_not_contains "explicit effort default suppresses persona effort" "model_reasoning_effort"

run_debug --persona reviewer
assert_contains "reviewer persona defaults to high effort" "model_reasoning_effort=\\\\\\\"high\\\\\\\""

run_debug --search
assert_contains "search maps to live web_search config" "web_search=\\\\\\\"live\\\\\\\""

run_debug --json -o /tmp/out.md --output-schema schema.json --ephemeral --ignore-user-config --ignore-rules --strict-config --enable js_repl --disable old_flag
assert_contains "json flag is forwarded" "--json"
assert_contains "output-last-message is forwarded" "-o[[:space:]]*/tmp/out.md"
assert_contains "output-schema is forwarded" "--output-schema[[:space:]]*schema.json"
assert_contains "ephemeral is forwarded" "--ephemeral"
assert_contains "ignore-user-config is forwarded" "--ignore-user-config"
assert_contains "ignore-rules is forwarded" "--ignore-rules"
assert_contains "strict-config is forwarded" "--strict-config"
assert_contains "enable is forwarded" "--enable[[:space:]]*js_repl"
assert_contains "disable is forwarded" "--disable[[:space:]]*old_flag"

run_debug --add-dir /tmp/extra --config 'model="gpt-test"'
assert_contains "add-dir is forwarded" "--add-dir[[:space:]]*/tmp/extra"
assert_contains "custom config flag is forwarded" "--config[[:space:]]*model="
assert_contains "custom config value is forwarded" "gpt-test"

assert_fail_contains "error: --resume cannot be combined" --resume --cd /tmp "Return OK"
assert_fail_contains "error: --resume cannot be combined with --sandbox workspace-write" --resume --sandbox workspace-write "Return OK"

run_debug --resume --sandbox bypass
assert_contains "resume can explicitly bypass" "resume[[:space:]]*--last[[:space:]]*--dangerously-bypass-approvals-and-sandbox"

run_debug --resume --persona reviewer
assert_not_contains "resume persona does not add default effort" "model_reasoning_effort"
assert_not_contains "resume persona does not add fresh sandbox" "--sandbox"

run_debug --resume --effort high
assert_contains "resume explicit effort is forwarded as config" "model_reasoning_effort=\\\\\\\"high\\\\\\\""

assert_fail_contains "error: --sandbox requires a value" --sandbox
assert_fail_contains "error: --config requires a value" --config
assert_fail_contains "unknown option: --bogus" --bogus

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
