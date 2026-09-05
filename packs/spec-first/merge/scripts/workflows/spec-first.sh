#!/usr/bin/env bash
set -euo pipefail

# Spec-First Development
# 正本: docs/specs/spec-driven-development/requirements.md
# 対話手順: skills/authoring-specs/SKILL.md

ROOT_DIR="$(pwd)"
SPECS="$ROOT_DIR/docs/specs"
APPROVALS="$ROOT_DIR/docs/approvals"
TPL="$ROOT_DIR/docs/templates"

usage() {
  cat <<'EOF'
usage: spec-first.sh <command>

  new-spec <name> [lite|full]  仕様の雛形を作る（既定 lite）
  status                       仕様と承認の対応、ハッシュ照合
  unlinked [base]              要件IDを持たない変更ファイルを列挙（REQ-B08）
  check                        status + unlinked + 点検項目
EOF
}

# ---- 仕様ごとの承認記録を読む ------------------------------------------
approval_hash() { # $1=name
  local f="$APPROVALS/$1.md"
  [[ -f "$f" ]] || return 1
  grep -oE '\b[0-9a-f]{7,40}\b' "$f" | head -1
}

cmd_new_spec() {
  local name="${1:-}" form="${2:-lite}"
  [[ -z "$name" ]] && { usage; exit 1; }
  local dest="$SPECS/$name"
  [[ -e "$dest" ]] && { echo "既にある: $dest"; exit 1; }
  mkdir -p "$dest" "$APPROVALS"
  local today; today="$(date '+%Y-%m-%d')"

  case "$form" in
    lite)
      sed "s/YYYY-MM-DD/$today/; s|<対象>|$name|" \
        "$TPL/spec-lite.md" > "$dest/spec.md"
      echo "作った: $dest/spec.md（lite）"
      ;;
    full)
      for f in requirements design tasks changes; do
        sed "s/YYYY-MM-DD/$today/; s|<対象>|$name|" \
          "$TPL/spec-full/$f.md" > "$dest/$f.md"
      done
      echo "作った: $dest/{requirements,design,tasks,changes}.md（full）"
      ;;
    *) echo "様式は lite か full"; exit 1 ;;
  esac

  sed "s|<仕様名>|$name|; s|<name>|$name|g" \
    "$APPROVALS/_TEMPLATE.md" > "$APPROVALS/$name.md"
  echo "作った: $APPROVALS/$name.md"
  echo
  echo "次にやること:"
  echo "  1. 目的と、作らない範囲を書く"
  echo "  2. 要件に ID を振り、**判定方法まで**受入条件を書く"
  echo "  3. 未確定事項に「何が止まるか」を書く（止まらないものは着手してよい）"
  echo "  4. コミットしてから承認を求める（ハッシュが要る）"
}

cmd_status() {
  echo "== 仕様と承認 =="
  local any=0
  for d in "$SPECS"/*/; do
    [[ -d "$d" ]] || continue
    any=1
    local name; name="$(basename "$d")"
    local spec=""
    for cand in "${d%/}/spec.md" "${d%/}/requirements.md"; do
      [[ -f "$cand" ]] && { spec="$cand"; break; }
    done
    local rel="${spec#"$ROOT_DIR"/}"
    printf "  %-34s %s\n" "$name" "${rel:-（仕様ファイル無し）}"

    if ! [[ -f "$APPROVALS/$name.md" ]]; then
      echo "      承認記録なし → 実装に入らない"
      continue
    fi
    local h; h="$(approval_hash "$name" || true)"
    if [[ -z "$h" ]]; then
      echo "      承認記録にハッシュなし → 照合できない。コミットしてから承認を求める"
      continue
    fi
    if [[ -n "${spec:-}" ]] && git -C "$ROOT_DIR" rev-parse --verify "$h" >/dev/null 2>&1; then
      if git -C "$ROOT_DIR" diff --quiet "$h" -- "$spec" 2>/dev/null; then
        echo "      承認済み ($h) 仕様は承認時から変わっていない"
      else
        echo "      ⚠ 承認後に仕様が変わっている ($h) → 実装を止めて再承認を求める"
      fi
    else
      echo "      ハッシュ $h が見つからない → 照合できない"
    fi
  done
  if [[ "$any" == "0" ]]; then echo "  （仕様なし）"; fi
}

cmd_unlinked() {
  local base="${1:-HEAD}"
  echo "== 要件IDを持たない変更ファイル（REQ-B08） =="
  echo "  基準: $base"
  local files found=0
  files="$(git -C "$ROOT_DIR" diff --name-only "$base" 2>/dev/null || true)"
  [[ -z "$files" ]] && files="$(git -C "$ROOT_DIR" diff --name-only --cached 2>/dev/null || true)"
  if [[ -z "$files" ]]; then
    echo "  変更なし"
    return
  fi
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ -f "$ROOT_DIR/$f" ]] || continue
    case "$f" in
      docs/*|memory/*|*.md|*.json|*.yml|*.yaml|*.lock|*.txt) continue ;;
    esac
    if ! grep -qE 'REQ-[A-Za-z]*[0-9]+|§[0-9]+' "$ROOT_DIR/$f" 2>/dev/null; then
      echo "  要確認: $f"
      found=$((found + 1))
    fi
  done <<< "$files"
  if [[ "$found" == "0" ]]; then
    echo "  なし"
  else
    echo
    echo "  ※ これは「未達」ではなく「要確認」。設定や自動生成物など、"
    echo "     要件に紐づかないのが正しいものもある。"
    echo "  ※ IDは書けば通る。防げるのは書き忘れであって偽装ではない。"
  fi
}

case "${1:-check}" in
  new-spec) shift; cmd_new_spec "$@" ;;
  status)   cmd_status ;;
  unlinked) shift; cmd_unlinked "${1:-HEAD}" ;;
  check)
    cmd_status; echo; cmd_unlinked "HEAD"
    cat <<'EOF'

点検:
- 承認記録にコミットハッシュがあるか
- 受入条件に「判定方法」が書かれているか
- 未確定事項に「何が止まるか」が書かれているか
- 実装中に要件が変わったなら changes.md に記録したか（REQ-B07）
EOF
    ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
