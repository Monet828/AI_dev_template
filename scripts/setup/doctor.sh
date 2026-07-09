#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMMON_LIB="$ROOT_DIR/scripts/setup/lib/common.sh"

# shellcheck source=/dev/null
source "$COMMON_LIB"

echo "== AI Project Doctor =="
echo "root: $ROOT_DIR"
echo

check_file() {
  local path="$1"
  if [[ -e "$ROOT_DIR/$path" ]]; then
    echo "[ok] $path"
  else
    echo "[missing] $path"
  fi
}

print_required_paths "$ROOT_DIR"

echo
echo "== Root Manifests =="
print_root_project_markers "$ROOT_DIR"

echo
echo "== app/ Manifests =="
print_app_project_markers "$ROOT_DIR"

echo
echo "== Environment Files =="
env_found=false
for file in .env .env.local .env.example .env.development .env.production app/.env app/.env.local app/.env.example app/.env.development app/.env.production; do
  if [[ -f "$ROOT_DIR/$file" ]]; then
    echo "[ok] $file"
    env_found=true
  fi
done
if [[ "$env_found" == false ]]; then
  echo "[info] no root or app env files detected"
fi

echo
echo "== Supabase Workspace =="
check_file "supabase"
check_file "supabase/migrations"
check_file "supabase/seed"
if [[ -d "$ROOT_DIR/supabase/functions" ]]; then
  check_file "supabase/functions"
else
  echo "[info] no supabase/functions directory"
fi

echo
echo "== Optional Slide Assets =="
if [[ -d "$ROOT_DIR/assets/slides" ]]; then
  check_file "assets/slides/SLIDE-md"
  check_file "assets/slides/SLIDE-PATTERN"
else
  echo "[info] slide pack not installed"
fi

echo
echo "== Pattern Assets =="
check_file "assets/patterns"
if [[ -f "$ROOT_DIR/assets/patterns/PATTERN-TEMPLATE.md" ]]; then
  check_file "assets/patterns/PATTERN-TEMPLATE.md"
else
  echo "[info] no pattern template installed"
fi

echo
echo "== Session Freshness =="
latest_session="$(find "$ROOT_DIR/memory/sessions" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort | tail -n 1 || true)"
if [[ -n "$latest_session" ]]; then
  echo "[latest] ${latest_session#$ROOT_DIR/}"
else
  echo "[info] no session markdown files found"
fi

echo
echo "== Git Status =="
if [[ -d "$ROOT_DIR/.git" ]]; then
  git -C "$ROOT_DIR" status --short || true
else
  echo "[info] no .git directory detected"
fi
