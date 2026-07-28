#!/usr/bin/env bash
# verify.sh must be a real verification runner, and record-verification.sh
# must retain the old checklist/self-report behavior under its own name --
# neither should silently take over the other's job, including when a
# pack (problem-first ships its own record-verification.sh customization)
# is applied on top of the base template.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/assert.sh"

ROOT_DIR="${AI_DEV_TEMPLATE_ROOT:?AI_DEV_TEMPLATE_ROOT must be set by the test runner}"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-template-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

# ---- base template: verify.sh runs real checks, record-verification.sh keeps the old job ----
BASE_TARGET="$TMP_ROOT/base-project"
"$ROOT_DIR/scripts/setup/scaffold.sh" "$BASE_TARGET" >/dev/null 2>&1

verify_output="$( cd "$BASE_TARGET" && ./scripts/loop/verify.sh < /dev/null 2>&1 )"
verify_exit=$?
assert_contains "$verify_output" "[PASS] shell syntax" "verify.sh actually runs a shell syntax check"
assert_contains "$verify_output" "== Summary ==" "verify.sh prints a PASS/SKIP/FAIL summary"
assert_exit_code 0 "$verify_exit" "verify.sh exits 0 on a clean generated project"

record_output="$( cd "$BASE_TARGET" && ./scripts/loop/record-verification.sh < /dev/null 2>&1 )"
assert_contains "$record_output" "Verify Loop" "record-verification.sh keeps the old checklist heading"
assert_not_contains "$record_output" "[PASS]" "record-verification.sh does not emit PASS/FAIL check signals"

# ---- a broken shell script must make verify.sh fail ----
echo 'if [[ true' > "$BASE_TARGET/scripts/broken.sh"
( cd "$BASE_TARGET" && ./scripts/loop/verify.sh < /dev/null >/dev/null 2>&1 )
assert_exit_code 1 "$?" "verify.sh exits non-zero when a shell script has a syntax error"

# ---- problem-first pack must not overwrite the real verify.sh with its checklist variant ----
PACK_TARGET="$TMP_ROOT/pack-project"
"$ROOT_DIR/scripts/setup/scaffold.sh" "$PACK_TARGET" --with problem-first >/dev/null 2>&1

pack_verify_output="$( cd "$PACK_TARGET" && ./scripts/loop/verify.sh < /dev/null 2>&1 )"
assert_contains "$pack_verify_output" "[PASS] shell syntax" \
  "verify.sh is still the real runner after applying the problem-first pack"

if grep -q "North Star" "$PACK_TARGET/scripts/loop/record-verification.sh" 2>/dev/null; then
  echo "  PASS: problem-first's record-verification.sh customization was applied instead"
else
  echo "  FAIL: problem-first's record-verification.sh customization was not applied"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

assert_case_result
