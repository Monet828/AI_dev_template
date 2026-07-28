#!/usr/bin/env bash
# doctor.sh must be a mechanically trustworthy diagnostic:
#   - exit 0 when every required path is present
#   - exit 1 when any required path is missing
#   - a missing *warning*-only (soft) path must never affect the exit code
#   - --json must emit exactly one line of valid-shaped JSON, with no
#     human-readable text mixed into stdout
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/assert.sh"

ROOT_DIR="${AI_DEV_TEMPLATE_ROOT:?AI_DEV_TEMPLATE_ROOT must be set by the test runner}"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-template-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

TARGET="$TMP_ROOT/project"
if ! "$ROOT_DIR/scripts/setup/scaffold.sh" "$TARGET" >/dev/null 2>&1; then
  echo "  FAIL: scaffold.sh failed to generate the test project"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  assert_case_result
fi

# ---- fresh project: doctor.sh should exit 0 ----
( cd "$TARGET" && ./scripts/setup/doctor.sh >/dev/null 2>&1 )
assert_exit_code 0 "$?" "doctor.sh exits 0 on a freshly scaffolded project"

# ---- deleting a warning-only path must not affect the exit code ----
rm -rf "$TARGET/tests"
( cd "$TARGET" && ./scripts/setup/doctor.sh >/dev/null 2>&1 )
assert_exit_code 0 "$?" "doctor.sh still exits 0 after removing the warn-only tests/ directory"

# ---- deleting a required path must fail the run ----
rm -f "$TARGET/memory/decisions.md"
( cd "$TARGET" && ./scripts/setup/doctor.sh >/dev/null 2>&1 )
assert_exit_code 1 "$?" "doctor.sh exits 1 after removing the required memory/decisions.md"

# ---- --json output must be exactly one line of well-shaped JSON, human text absent ----
json_output="$( cd "$TARGET" && ./scripts/setup/doctor.sh --json 2>/dev/null )"
line_count="$(printf '%s\n' "$json_output" | wc -l | tr -d ' ')"
assert_exit_code 1 "$line_count" "--json output is exactly one line"
assert_contains "$json_output" '"status":"fail"' "--json reflects the current error state"
assert_contains "$json_output" '"checks":[' "--json includes the checks array"
assert_not_contains "$json_output" "== AI Project Doctor ==" "--json must not mix in human-readable headers"
assert_not_contains "$json_output" "[missing]" "--json must not mix in human-readable [missing] lines"

assert_case_result
