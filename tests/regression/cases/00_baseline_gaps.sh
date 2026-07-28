#!/usr/bin/env bash
# Baseline regression case: reproduces 3 known gaps in the pre-hardening
# pipeline. Each is expected to currently FAIL until the corresponding stage
# of the hardening pass lands:
#
#   Case 1: doctor.sh exits 0 even when a required file is missing.
#     -> fixed when doctor.sh gains real exit codes.
#   Case 2: a scaffolded project ships dead template-manufacturing tooling
#     (scaffold.sh present but its required packs/ directory absent).
#     -> fixed by separating template/ (generation source) from the
#        generator-only files that stay at the repo root.
#   Case 3: non-interactive verify.sh never prints a PASS/FAIL signal.
#     -> fixed when verify.sh becomes a real verification runner.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/assert.sh"

ROOT_DIR="${AI_DEV_TEMPLATE_ROOT:?AI_DEV_TEMPLATE_ROOT must be set by the test runner}"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-template-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

# ---- Case 1: doctor.sh should fail (non-zero exit) when a required file is missing ----
TARGET1="$TMP_ROOT/case1-project"
if "$ROOT_DIR/scripts/setup/scaffold.sh" "$TARGET1" >/dev/null 2>&1; then
  rm -f "$TARGET1/memory/tasks.md"
  ( cd "$TARGET1" && ./scripts/setup/doctor.sh >/dev/null 2>&1 )
  doctor_exit=$?
  assert_exit_code 1 "$doctor_exit" "doctor.sh should exit non-zero when memory/tasks.md is missing"
else
  echo "  FAIL: scaffold.sh failed to generate case1-project (cannot test doctor.sh)"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# ---- Case 2 & 3 share one scaffolded project ----
TARGET2="$TMP_ROOT/case2-project"
if "$ROOT_DIR/scripts/setup/scaffold.sh" "$TARGET2" --with understand-first >/dev/null 2>&1; then
  # Case 2: no dead template-manufacturing tooling in the generated output.
  if [[ -f "$TARGET2/scripts/setup/scaffold.sh" && ! -d "$TARGET2/packs" ]]; then
    echo "  FAIL: generated project ships scripts/setup/scaffold.sh but has no packs/ -- it is dead/broken if run there"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  else
    echo "  PASS: no dead scaffold.sh-without-packs/ combination found"
  fi

  # Case 3: non-interactive verify.sh must produce a PASS/FAIL signal.
  verify_output="$( cd "$TARGET2" && ./scripts/loop/verify.sh < /dev/null 2>&1 )"
  assert_contains "$verify_output" "[PASS]" "non-interactive verify.sh should print at least one [PASS]/[FAIL] line"
else
  echo "  FAIL: scaffold.sh failed to generate case2-project (cannot test leak/verify gaps)"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 2))
fi

assert_case_result
