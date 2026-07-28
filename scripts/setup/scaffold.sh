#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE_ROOT="$ROOT_DIR/template"
ADDON_ROOT_DEFAULT="$ROOT_DIR/packs"
ADDON_ROOT="${AI_DEV_TEMPLATE_ADDON_ROOT:-$ADDON_ROOT_DEFAULT}"

usage() {
  cat <<EOF
Usage:
  ./scripts/setup/scaffold.sh <target_dir> [--with pack1,pack2]

Example:
  ./scripts/setup/scaffold.sh /path/to/new-project --with problem-first
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

TARGET_DIR=""
PACKS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with)
      PACKS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="$1"
      else
        echo "[error] unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  echo "[error] target_dir is required" >&2
  exit 1
fi

if [[ -e "$TARGET_DIR" ]]; then
  echo "[error] target already exists: $TARGET_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

copy_base_template() {
  local source_dir="$1"
  local dest_dir="$2"

  local entries=()
  while IFS= read -r entry; do
    entries+=("$entry")
  done < <(find "$source_dir" -mindepth 1 -maxdepth 1 \
    ! -name '.DS_Store' \
    ! -name '.git' \
    ! -name 'memory' \
    -print | sort)

  for entry in "${entries[@]}"; do
    cp -R "$entry" "$dest_dir/"
  done

  mkdir -p "$dest_dir/memory"
  cp -R "$source_dir/memory/README.md" "$dest_dir/memory/"
  cp -R "$source_dir/memory/current-state.md" "$dest_dir/memory/"
  cp -R "$source_dir/memory/decisions.md" "$dest_dir/memory/"
  cp -R "$source_dir/memory/tasks.md" "$dest_dir/memory/"
  mkdir -p "$dest_dir/memory/sessions"
  touch "$dest_dir/memory/sessions/.gitkeep"
  if [[ -f "$source_dir/.gitignore" ]]; then
    cp "$source_dir/.gitignore" "$dest_dir/.gitignore"
  fi
  find "$dest_dir" -name '.DS_Store' -delete
}

if [[ ! -d "$ADDON_ROOT" ]]; then
  echo "[error] pack root not found: $ADDON_ROOT" >&2
  echo "Set AI_DEV_TEMPLATE_ADDON_ROOT or create packs under $ROOT_DIR/packs" >&2
  exit 1
fi

apply_pack() {
  local pack_name="$1"
  local pack_dir="$ADDON_ROOT/$pack_name"
  local manifest="$pack_dir/pack-manifest.sh"

  if [[ ! -f "$manifest" ]]; then
    echo "[error] pack manifest not found: $manifest" >&2
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$manifest"

  local merge_dir="$pack_dir/$PACK_MERGE_DIR"
  local append_dir="$pack_dir/$PACK_APPEND_DIR"

  if [[ -d "$merge_dir" ]]; then
    while IFS= read -r file; do
      local rel_path="${file#$merge_dir/}"
      mkdir -p "$TARGET_DIR/$(dirname "$rel_path")"
      cp "$file" "$TARGET_DIR/$rel_path"
      if [[ "$file" == *.sh ]]; then
        chmod +x "$TARGET_DIR/$rel_path"
      fi
    done < <(find "$merge_dir" -type f | sort)
  fi

  if [[ -d "$append_dir" ]]; then
    while IFS= read -r fragment; do
      local rel_path="${fragment#$append_dir/}"
      local target_file="$TARGET_DIR/$rel_path"
      if [[ ! -f "$target_file" ]]; then
        echo "[error] append target missing: $rel_path" >&2
        exit 1
      fi
      {
        echo
        echo
        cat "$fragment"
      } >> "$target_file"
    done < <(find "$append_dir" -type f | sort)
  fi

  find "$TARGET_DIR" -name '.DS_Store' -delete
}

if [[ ! -d "$TEMPLATE_ROOT" ]]; then
  echo "[error] template root not found: $TEMPLATE_ROOT" >&2
  exit 1
fi

echo "== Scaffold Project =="
echo "base: $TEMPLATE_ROOT"
echo "target: $TARGET_DIR"
echo "pack root: $ADDON_ROOT"

copy_base_template "$TEMPLATE_ROOT" "$TARGET_DIR"

if [[ -n "$PACKS" ]]; then
  IFS=',' read -r -a pack_list <<< "$PACKS"
  for pack in "${pack_list[@]}"; do
    trimmed_pack="$(printf '%s' "$pack" | sed 's/^ *//;s/ *$//')"
    if [[ -n "$trimmed_pack" ]]; then
      echo "[pack] $trimmed_pack"
      apply_pack "$trimmed_pack"
    fi
  done
fi

echo
echo "Scaffold complete."
echo "Next steps:"
echo "- cd \"$TARGET_DIR\""
echo "- ./scripts/setup/doctor.sh"
echo "- ./scripts/setup/bootstrap.sh"
