#!/usr/bin/env bash
# The discovery queue is the two-layer design in
# skills/delegating-to-codex/SKILL.md section 9: discover.sh patrols on
# whatever schedule the human sets up (cron/launchd) and only ever writes to
# a queue file; dispatch.sh is the human-triggered layer that actually calls
# Codex. Nothing here should ever let discover.sh reach Codex.
#
# Uses a fake codex on PATH for dispatch.sh, same approach as
# 50_codex_delegation.sh, so no real quota is spent and every branch is
# deterministic.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/assert.sh"

ROOT_DIR="${AI_DEV_TEMPLATE_ROOT:?AI_DEV_TEMPLATE_ROOT must be set by the test runner}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "  SKIP: python3 unavailable; discover.sh/dispatch.sh require it"
  assert_case_result
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-template-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

TARGET="$TMP_ROOT/project"
"$ROOT_DIR/scripts/setup/scaffold.sh" "$TARGET" >/dev/null 2>&1
git -C "$TARGET" init -q
git -C "$TARGET" add -A >/dev/null 2>&1
git -C "$TARGET" -c user.email=t@example.com -c user.name=t commit -qm init >/dev/null 2>&1

assert_file_exists "$TARGET/scripts/codex/discover.sh" "discover.sh ships in every project"
assert_file_exists "$TARGET/scripts/codex/dispatch.sh" "dispatch.sh ships in every project"

cat >> "$TARGET/README.md" <<'EOF'

<!-- codex:verify -->
- claim one: single line

<!-- codex:verify -->
- claim two:
  wraps onto a second line
<!-- codex:verify -->
- claim three: immediately adjacent, no blank line before it
<!-- codex:verify -->
- claim four:
  also adjacent, and also wraps
EOF

# ---- discover.sh never touches PATH's codex, even if one is present ----
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/codex" <<'FAKE'
#!/usr/bin/env bash
echo "CODEX WAS CALLED" >&2
exit 1
FAKE
chmod +x "$FAKE_BIN/codex"

out="$(cd "$TARGET" && PATH="$FAKE_BIN:$PATH" ./scripts/codex/discover.sh 2>&1)"
assert_not_contains "$out" "CODEX WAS CALLED" "discover.sh never invokes codex, even when present on PATH"
assert_contains "$out" "4 new candidate" "all four markers are found in one pass, including adjacent ones"

QUEUE="$TARGET/memory/codex-queue.jsonl"
assert_file_exists "$QUEUE" "the queue file is created"
LINES="$(wc -l < "$QUEUE" | tr -d '[:space:]')"
assert_exit_code 4 "$LINES" "four entries are queued"

MULTILINE="$(grep 'claim two' "$QUEUE")"
assert_contains "$MULTILINE" "wraps onto a second line" "a claim wrapping onto the next line is joined"

# Regression: markers with no blank line between them (the common case in a
# dense bulleted list) must not swallow the next marker plus the start of
# the next claim. Found by running this against a real README, not caught
# by the original test, which only used blank-line-separated markers.
CLAIM_THREE="$(grep 'claim three' "$QUEUE")"
assert_not_contains "$CLAIM_THREE" "codex:verify" "an adjacent marker is never absorbed into the previous claim text"
assert_not_contains "$CLAIM_THREE" "claim four" "an adjacent claim never bleeds into the previous one"

CLAIM_FOUR="$(grep 'claim four' "$QUEUE")"
assert_contains "$CLAIM_FOUR" "also adjacent, and also wraps" "a wrapped claim still joins correctly when adjacent to other markers"
assert_not_contains "$CLAIM_FOUR" "codex:verify" "the marker itself never leaks into an adjacent wrapped claim"

# ---- re-running discover.sh does not duplicate unchanged claims ----
out2="$(cd "$TARGET" && ./scripts/codex/discover.sh 2>&1)"
assert_contains "$out2" "0 new candidate" "an unchanged claim is not re-queued"
LINES2="$(wc -l < "$QUEUE" | tr -d '[:space:]')"
assert_exit_code 4 "$LINES2" "the queue is still exactly four entries"

# ---- editing a claim's text re-queues it under a new id ----
sed -i.bak 's/claim one: single line/claim one: edited text/' "$TARGET/README.md"
out3="$(cd "$TARGET" && ./scripts/codex/discover.sh 2>&1)"
assert_contains "$out3" "1 new candidate" "an edited claim is re-queued as a new candidate"

# ---- dispatch.sh --list shows only pending items ----
LIST_BEFORE="$(cd "$TARGET" && ./scripts/codex/dispatch.sh --list 2>&1)"
assert_contains "$LIST_BEFORE" "5 pending" "list shows all pending items, including the re-queued one"

# fake codex shaped like the real CLI's JSONL, returning a schema-shaped report
make_fake_codex() {
  local exit_code="$1" verdict="${2:-falsified}"
  cat > "$FAKE_BIN/codex" <<FAKE
#!/usr/bin/env bash
cat <<EVENTS
{"type":"thread.started","thread_id":"th_test"}
{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"{\\"summary\\":\\"checked\\",\\"claims\\":[{\\"claim\\":\\"c\\",\\"status\\":\\"$verdict\\",\\"evidence\\":\\"src/x.ts:1\\"}],\\"risks\\":[],\\"unresolved\\":[]}"}}
{"type":"turn.completed","usage":{"input_tokens":100}}
EVENTS
exit ${exit_code}
FAKE
  chmod +x "$FAKE_BIN/codex"
}

# ---- --next dispatches the oldest pending item and folds the verdict back ----
make_fake_codex 0 falsified
out4="$(cd "$TARGET" && PATH="$FAKE_BIN:$PATH" ./scripts/codex/dispatch.sh --next 2>&1)"
assert_exit_code 0 "$?" "a successful dispatch exits 0"
assert_contains "$out4" "result: falsified" "the verdict from the report is folded back into the queue"

PENDING_AFTER="$(grep -c '"status": "pending"' "$QUEUE" || true)"
assert_exit_code 4 "$PENDING_AFTER" "four items left pending after dispatching one of five"
FALSIFIED_COUNT="$(grep -c '"status": "falsified"' "$QUEUE" || true)"
assert_exit_code 1 "$FALSIFIED_COUNT" "the dispatched item is now marked falsified"

# ---- a failed codex exit marks the item delegation_failed, not silently dropped ----
make_fake_codex 7
cd "$TARGET" && PATH="$FAKE_BIN:$PATH" ./scripts/codex/dispatch.sh --next >/dev/null 2>&1
assert_exit_code 7 "$?" "codex's exit code propagates through dispatch.sh"
assert_contains "$(cat "$QUEUE")" "delegation_failed" "a failed delegation is recorded, not dropped"

# ---- a read-only violation leaves the queue item untouched ----
LAST_PENDING_ID="$(cd "$TARGET" && ./scripts/codex/dispatch.sh --list 2>&1 | head -1 | awk '{print $1}')"
cat > "$FAKE_BIN/codex" <<FAKE
#!/usr/bin/env bash
printf 'x' > '$TARGET/violation.txt'
echo '{"type":"thread.started","thread_id":"z"}'
exit 0
FAKE
chmod +x "$FAKE_BIN/codex"
cd "$TARGET" && PATH="$FAKE_BIN:$PATH" ./scripts/codex/dispatch.sh --id "$LAST_PENDING_ID" >/dev/null 2>&1
assert_exit_code 3 "$?" "a read-only violation during dispatch exits 3"
assert_contains "$(grep "$LAST_PENDING_ID" "$QUEUE")" '"status": "pending"' "the item stays pending after a read-only violation"
rm -f "$TARGET/violation.txt"

# ---- with nothing pending, --next is a no-op, not an error ----
# Drain whatever is left rather than assuming a fixed count -- the exact
# number of items still pending here depends on how many earlier steps
# consumed one, and hardcoding it makes the test brittle to reordering.
make_fake_codex 0 confirmed
for _ in $(seq 1 10); do
  remaining="$(cd "$TARGET" && ./scripts/codex/dispatch.sh --list 2>&1 | tail -1)"
  case "$remaining" in "-- 0 pending") break ;; esac
  (cd "$TARGET" && PATH="$FAKE_BIN:$PATH" ./scripts/codex/dispatch.sh --next >/dev/null 2>&1)
done
out7="$(cd "$TARGET" && PATH="$FAKE_BIN:$PATH" ./scripts/codex/dispatch.sh --next 2>&1)"
assert_exit_code 0 "$?" "nothing pending is not treated as an error"
assert_contains "$out7" "nothing to dispatch" "the empty-queue case says so explicitly"

assert_case_result
