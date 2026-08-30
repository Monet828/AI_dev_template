#!/usr/bin/env bash
# Skills must satisfy a mechanically checkable contract:
#   - frontmatter conforms to the Agent Skills spec (name shape, name ==
#     directory name, description present and within the size limit)
#   - SKILL.md body stays under the 500-line guidance
#   - every skill has at least 3 evals, and every eval has the four required
#     sections filled in
#   - no eval directory exists without a matching skill
#   - `AGENTS.md §N` cross-references from skills resolve to a real section
#     (this class of rot was found by hand once; it should not need to be)
#   - tests/evals/ never leaks into a generated project
#
# What this case does NOT check: whether a skill actually changes agent
# behavior. That requires an LLM and is judged by hand -- see
# tests/evals/README.md. A green run here means the evals exist and are
# well-formed, not that the skills work.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/assert.sh"

ROOT_DIR="${AI_DEV_TEMPLATE_ROOT:?AI_DEV_TEMPLATE_ROOT must be set by the test runner}"

SKILLS_DIR="$ROOT_DIR/template/skills"
EVALS_DIR="$ROOT_DIR/tests/evals"
AGENTS_MD="$ROOT_DIR/template/AGENTS.md"

MIN_EVALS=3
MAX_BODY_LINES=500
# The spec limit is 1024 *characters*. We count bytes, because `wc -m` is
# locale-dependent across the ubuntu/macos CI matrix and would make this test
# flaky. Bytes >= characters for UTF-8, so this bound is strictly conservative:
# it can never pass something that is actually over the limit. If it ever does
# fail, check the character count by hand before assuming a real violation.
MAX_DESC_BYTES=1024

# ---- frontmatter field extraction ----
# Reads the block between the first two `---` lines only, so a `name:` in the
# body cannot be mistaken for frontmatter.
frontmatter_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---"  { exit }
    inside {
      prefix = field ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[ \t]+/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

# ---- per-skill checks ----
skill_names=()
while IFS= read -r skill_dir; do
  name="$(basename "$skill_dir")"
  skill_names+=("$name")
  skill_md="$skill_dir/SKILL.md"

  assert_file_exists "$skill_md" "$name: SKILL.md exists"
  [[ -f "$skill_md" ]] || continue

  fm_name="$(frontmatter_field "$skill_md" name)"
  if [[ "$fm_name" =~ ^[a-z0-9-]{1,64}$ ]]; then
    echo "  PASS: $name: frontmatter name is spec-shaped"
  else
    echo "  FAIL: $name: frontmatter name must match ^[a-z0-9-]{1,64}$ (got '$fm_name')"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi

  if [[ "$fm_name" == "$name" ]]; then
    echo "  PASS: $name: frontmatter name matches directory name"
  else
    echo "  FAIL: $name: frontmatter name '$fm_name' != directory name '$name'"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi

  fm_desc="$(frontmatter_field "$skill_md" description)"
  desc_bytes="$(printf '%s' "$fm_desc" | wc -c | tr -d '[:space:]')"
  if [[ -n "$fm_desc" && "$desc_bytes" -le "$MAX_DESC_BYTES" ]]; then
    echo "  PASS: $name: description present and within $MAX_DESC_BYTES bytes ($desc_bytes)"
  else
    echo "  FAIL: $name: description missing or over $MAX_DESC_BYTES bytes ($desc_bytes)"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi

  body_lines="$(wc -l < "$skill_md" | tr -d '[:space:]')"
  if [[ "$body_lines" -lt "$MAX_BODY_LINES" ]]; then
    echo "  PASS: $name: SKILL.md is $body_lines lines (< $MAX_BODY_LINES)"
  else
    echo "  FAIL: $name: SKILL.md is $body_lines lines (>= $MAX_BODY_LINES)"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi

  # ---- evals ----
  eval_dir="$EVALS_DIR/$name"
  eval_count=0
  if [[ -d "$eval_dir" ]]; then
    eval_count="$(find "$eval_dir" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d '[:space:]')"
  fi
  if [[ "$eval_count" -ge "$MIN_EVALS" ]]; then
    echo "  PASS: $name: $eval_count evals (>= $MIN_EVALS)"
  else
    echo "  FAIL: $name: $eval_count evals, need at least $MIN_EVALS (tests/evals/$name/)"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

# ---- every eval file has the four required sections, non-empty ----
if [[ -d "$EVALS_DIR" ]]; then
  while IFS= read -r eval_file; do
    rel="${eval_file#"$ROOT_DIR"/}"
    for heading in "## シナリオ" "## 期待する挙動" "## 落ちる挙動" "## 判定"; do
      # A section counts as present only if it is followed by at least one
      # non-blank, non-heading line -- an empty section is a placeholder.
      if awk -v h="$heading" '
            $0 == h { found = 1; next }
            found && /^## / { exit }
            found && NF { body = 1; exit }
            END { exit(body ? 0 : 1) }
          ' "$eval_file"; then
        :
      else
        echo "  FAIL: $rel: missing or empty section '$heading'"
        ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
      fi
    done
  done < <(find "$EVALS_DIR" -mindepth 2 -type f -name '*.md' | sort)
  echo "  PASS: every eval file checked for the 4 required sections"

  # ---- no orphan eval directory ----
  while IFS= read -r eval_dir; do
    n="$(basename "$eval_dir")"
    if [[ -d "$SKILLS_DIR/$n" ]]; then
      echo "  PASS: eval dir '$n' has a matching skill"
    else
      echo "  FAIL: eval dir '$n' has no matching skill in template/skills/"
      ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    fi
  done < <(find "$EVALS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

# ---- `AGENTS.md §N` references resolve to a real section ----
# Only refs on a line that names AGENTS.md are enforced. A bare §N elsewhere
# refers to the skill's own sections; those are reported as warnings below.
while IFS= read -r line; do
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  text="${rest#*:}"
  for n in $(printf '%s' "$text" | grep -o '§[0-9][0-9]*' | tr -d '§'); do
    if grep -q "^## ${n}\\." "$AGENTS_MD"; then
      echo "  PASS: ${file#"$ROOT_DIR"/}:$lineno -> AGENTS.md §$n resolves"
    else
      echo "  FAIL: ${file#"$ROOT_DIR"/}:$lineno -> AGENTS.md §$n does not exist"
      ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
    fi
  done
done < <(grep -rn 'AGENTS\.md' "$SKILLS_DIR" "$ROOT_DIR/template/agents" 2>/dev/null | grep '§[0-9]')

# ---- warn on unresolvable self-references (does not fail the case) ----
while IFS= read -r line; do
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  text="${rest#*:}"
  case "$text" in *AGENTS.md*) continue ;; esac
  for n in $(printf '%s' "$text" | grep -o '§[0-9][0-9]*' | tr -d '§'); do
    if ! grep -q "^## ${n}\\." "$file"; then
      echo "  WARN: ${file#"$ROOT_DIR"/}:$lineno -> §$n has no matching section in this file"
    fi
  done
done < <(grep -rn '§[0-9]' "$SKILLS_DIR" "$ROOT_DIR/template/agents" 2>/dev/null)

# ---- tests/evals must not leak into a generated project ----
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-dev-template-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
TARGET="$TMP_ROOT/project"
if "$ROOT_DIR/scripts/setup/scaffold.sh" "$TARGET" >/dev/null 2>&1; then
  assert_file_absent "$TARGET/tests/evals" "generated project does not contain tests/evals"
  assert_file_exists "$TARGET/skills" "generated project still ships skills/"
else
  echo "  FAIL: scaffold.sh failed, cannot check for tests/evals leak"
  ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
fi

echo "  (checked ${#skill_names[@]} skills)"
assert_case_result
