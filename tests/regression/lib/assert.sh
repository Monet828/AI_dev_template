#!/usr/bin/env bash
# Minimal assertion helpers for tests/regression case scripts.
# Sourced by each case script; not meant to be executed directly.
#
# Convention: each case script sources this file, calls assert_* functions
# throughout, and finishes with `assert_case_result` to exit 0/1 based on
# whether any assertion failed.

ASSERT_FAILURES=0

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-exit code}"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $msg (exit $actual)"
  else
    echo "  FAIL: $msg (expected exit $expected, got $actual)"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

assert_file_exists() {
  local path="$1"
  local msg="${2:-file exists: $path}"
  if [[ -e "$path" ]]; then
    echo "  PASS: $msg"
  else
    echo "  FAIL: $msg"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

assert_file_absent() {
  local path="$1"
  local msg="${2:-file absent: $path}"
  if [[ ! -e "$path" ]]; then
    echo "  PASS: $msg"
  else
    echo "  FAIL: $msg"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-output contains: $needle}"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $msg"
  else
    echo "  FAIL: $msg"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-output does not contain: $needle}"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "  PASS: $msg"
  else
    echo "  FAIL: $msg"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

# Call at the very end of a case script. Exits 0 if every assertion in this
# case passed, 1 otherwise -- this exit code is what tests/regression/run.sh
# checks to decide PASS/FAIL for the whole case file.
assert_case_result() {
  if [[ "$ASSERT_FAILURES" -eq 0 ]]; then
    exit 0
  else
    exit 1
  fi
}
