#!/usr/bin/env bash
# The codex scripts are standard equipment in template/, shipped to every
# generated project. They are the mechanical half of the delegation report
# contract that skills/delegating-to-codex/SKILL.md defines.
# These cases drive delegate.sh against a *fake* codex on PATH, so every branch
# is exercised deterministically and without consuming real Codex quota.
#
# What is asserted:
#   - the scripts land in EVERY generated project, with no pack opt-in
#   - a missing `codex` refuses (exit 2) instead of degrading
#   - status comes from the exit code, NOT from the presence of `error` items
#     (Codex emits those for advisory notices; a healthy run has them)
#   - a non-zero Codex exit is reported as failure and propagated
#   - files_modified is derived from git, and a read-only violation exits 3
#   - --sandbox read-only is always passed and cannot be overridden
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/assert.sh"

ROOT_DIR="${AI_DEV_TEMPLATE_ROOT:?AI_DEV_TEMPLATE_ROOT must be set by the test runner}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "  SKIP: python3 unavailable; delegate.sh requires it"
  assert_case_result
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-template-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

TARGET="$TMP_ROOT/project"
if ! "$ROOT_DIR/scripts/setup/scaffold.sh" "$TARGET" >/dev/null 2>&1; then
  echo "  FAIL: scaffold.sh failed"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  assert_case_result
fi

DELEGATE="$TARGET/scripts/codex/delegate.sh"
assert_file_exists "$DELEGATE" "delegate.sh is delivered"
assert_file_exists "$TARGET/scripts/codex/review.sh" "review.sh is delivered"
assert_file_exists "$TARGET/scripts/codex/report-schema.json" "report-schema.json is delivered"
assert_contains "$(cat "$TARGET/AGENTS.md")" "scripts/codex/delegate.sh" "AGENTS.md lists delegate.sh as a standard command"
assert_contains "$(cat "$TARGET/AGENTS.md")" "exit 3" "AGENTS.md stop conditions cover a read-only violation"
assert_file_exists "$TARGET/skills/delegating-to-codex/SKILL.md" "the skill that governs these scripts ships too"

# The generated project is not a git repo; make it one so the read-only
# invariant check has a tree to compare.
git -C "$TARGET" init -q 2>/dev/null
git -C "$TARGET" add -A >/dev/null 2>&1
git -C "$TARGET" -c user.email=t@example.com -c user.name=t commit -qm init >/dev/null 2>&1

LOGS="$TMP_ROOT/logs"
mkdir -p "$LOGS"

# ---- codex missing -> refuse, do not degrade ----
EMPTY_PATH_DIR="$TMP_ROOT/nobin"
mkdir -p "$EMPTY_PATH_DIR"
out="$(PATH="$EMPTY_PATH_DIR:/usr/bin:/bin" "$DELEGATE" "task" 2>&1)"
assert_exit_code 2 "$?" "missing codex refuses"
assert_contains "$out" "not on PATH" "missing codex explains why"

# ---- no prompt -> usage error ----
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"
PATH="$FAKE_BIN:$PATH" "$DELEGATE" >/dev/null 2>&1
assert_exit_code 2 "$?" "missing prompt is a usage error"

# fake codex: records argv, emits JSONL shaped like the real one
make_fake_codex() {
  local exit_code="$1" extra_event="${2:-}" side_effect="${3:-}"
  cat > "$FAKE_BIN/codex" <<FAKE
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$TMP_ROOT/argv.txt"
${side_effect}
cat <<'EVENTS'
{"type":"thread.started","thread_id":"th_test"}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item_0","type":"error","message":"Skill descriptions were shortened to fit the 2% skills context budget."}}
{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"wc -l VERSION","exit_code":0,"status":"completed"}}
${extra_event}
{"type":"item.completed","item":{"id":"item_9","type":"agent_message","text":"{\"summary\":\"ok\",\"claims\":[{\"claim\":\"c\",\"status\":\"falsified\",\"evidence\":\"e\"}],\"risks\":[],\"unresolved\":[]}"}}
{"type":"turn.completed","usage":{"input_tokens":43826,"cached_input_tokens":22272,"output_tokens":331}}
EVENTS
exit ${exit_code}
FAKE
  chmod +x "$FAKE_BIN/codex"
}

# ---- success: advisory `error` item present, status must still be success ----
make_fake_codex 0
report="$(PATH="$FAKE_BIN:$PATH" CODEX_DELEGATE_LOG_DIR="$LOGS" "$DELEGATE" --cd "$TARGET" "task" 2>/dev/null)"
assert_exit_code 0 "$?" "successful delegation exits 0"
assert_contains "$report" '"status": "success"' "an advisory error item does not make status failure"
assert_contains "$report" '"notices"' "the advisory notice is still surfaced, not swallowed"
assert_contains "$report" '"thread_id": "th_test"' "thread_id is extracted for resume"
assert_contains "$report" '"falsified"' "the model's structured claims survive into the report"
assert_contains "$report" '"files_modified": []' "files_modified is empty for a clean read-only run"

# ---- --sandbox read-only is always passed ----
argv="$(cat "$TMP_ROOT/argv.txt")"
assert_contains "$argv" "read-only" "codex is invoked with --sandbox read-only"
assert_contains "$argv" "--output-schema" "codex is invoked with the report schema"

# ---- a failed inner command is counted, not hidden ----
make_fake_codex 0 '{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"npm test","exit_code":1,"status":"completed"}}'
report="$(PATH="$FAKE_BIN:$PATH" CODEX_DELEGATE_LOG_DIR="$LOGS" "$DELEGATE" --cd "$TARGET" "task" 2>/dev/null)"
assert_contains "$report" '"commands_failed": 1' "a non-zero inner command exit code is counted"

# ---- codex itself fails -> failure, exit code propagated ----
make_fake_codex 7
report="$(PATH="$FAKE_BIN:$PATH" CODEX_DELEGATE_LOG_DIR="$LOGS" "$DELEGATE" --cd "$TARGET" "task" 2>/dev/null)"
assert_exit_code 7 "$?" "codex's exit code is propagated"
assert_contains "$report" '"status": "failure"' "a non-zero codex exit is reported as failure"

# ---- read-only violated -> exit 3, and no report is emitted ----
make_fake_codex 0 "" "printf 'x' > '$TARGET/violation.txt'"
out="$(PATH="$FAKE_BIN:$PATH" CODEX_DELEGATE_LOG_DIR="$LOGS" "$DELEGATE" --cd "$TARGET" "task" 2>&1)"
assert_exit_code 3 "$?" "a write under read-only exits 3"
assert_contains "$out" "FILES CHANGED" "the read-only violation is named explicitly"
assert_not_contains "$out" '"status": "success"' "no success report is emitted after a violation"

assert_case_result
