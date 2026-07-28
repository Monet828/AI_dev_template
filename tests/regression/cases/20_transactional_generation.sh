#!/usr/bin/env bash
# scaffold.sh must generate transactionally:
#   - a failure mid-generation leaves no partial target directory
#   - an existing target (even non-empty) is never overwritten/destroyed
#   - space-in-path targets work
#   - duplicate pack specification is applied only once (no doubled
#     append-fragment content, no doubled installed_packs entry)
#   - .ai-dev-template.yml is written with the expected fields
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/assert.sh"

ROOT_DIR="${AI_DEV_TEMPLATE_ROOT:?AI_DEV_TEMPLATE_ROOT must be set by the test runner}"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-template-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

# ---- mid-generation failure leaves no partial artifact ----
FAIL_TARGET="$TMP_ROOT/failed-project"
"$ROOT_DIR/scripts/setup/scaffold.sh" "$FAIL_TARGET" --with does-not-exist >/dev/null 2>&1
assert_file_absent "$FAIL_TARGET" "a failed generation leaves no partial target directory"

# ---- existing non-empty target is never destroyed ----
EXISTING_TARGET="$TMP_ROOT/existing-project"
mkdir -p "$EXISTING_TARGET"
echo "user data" > "$EXISTING_TARGET/keep-me.txt"
( "$ROOT_DIR/scripts/setup/scaffold.sh" "$EXISTING_TARGET" >/dev/null 2>&1 )
scaffold_over_existing_exit=$?
assert_exit_code 1 "$scaffold_over_existing_exit" "scaffold.sh refuses to run against an existing target"
if [[ -f "$EXISTING_TARGET/keep-me.txt" ]]; then
  echo "  PASS: pre-existing user file survives the aborted scaffold attempt"
else
  echo "  FAIL: pre-existing user file was lost"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# ---- space-in-path target ----
SPACE_TARGET="$TMP_ROOT/a project with spaces"
"$ROOT_DIR/scripts/setup/scaffold.sh" "$SPACE_TARGET" >/dev/null 2>&1
assert_file_exists "$SPACE_TARGET/AGENTS.md" "scaffolding into a path containing spaces succeeds"

# ---- duplicate pack specification is applied exactly once ----
DUP_TARGET="$TMP_ROOT/dup-project"
"$ROOT_DIR/scripts/setup/scaffold.sh" "$DUP_TARGET" --with understand-first,understand-first >/dev/null 2>&1
occurrences="$(grep -c '^## Understand-First Development Addon$' "$DUP_TARGET/AGENTS.md" 2>/dev/null || true)"
occurrences="${occurrences:-0}"
if [[ "$occurrences" -le 1 ]]; then
  echo "  PASS: duplicate pack spec does not duplicate appended content ($occurrences occurrence(s))"
else
  echo "  FAIL: duplicate pack spec duplicated appended content ($occurrences occurrences)"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi
installed_pack_lines="$(grep -c '^  understand-first:' "$DUP_TARGET/.ai-dev-template.yml" 2>/dev/null || true)"
installed_pack_lines="${installed_pack_lines:-0}"
if [[ "$installed_pack_lines" -eq 1 ]]; then
  echo "  PASS: .ai-dev-template.yml lists the duplicated pack exactly once"
else
  echo "  FAIL: .ai-dev-template.yml pack entry count is $installed_pack_lines, expected 1"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

# ---- .ai-dev-template.yml has the expected fields ----
META_TARGET="$TMP_ROOT/meta-project"
"$ROOT_DIR/scripts/setup/new-project.sh" "$META_TARGET" full >/dev/null 2>&1
meta="$(cat "$META_TARGET/.ai-dev-template.yml" 2>/dev/null || echo "")"
assert_contains "$meta" "schema_version: 1" "metadata includes schema_version"
assert_contains "$meta" "profile: full" "metadata records the profile used"
assert_contains "$meta" "evidence-first: 0.1.0" "metadata records real per-pack versions"
assert_contains "$meta" "created_at:" "metadata includes created_at"

assert_case_result
