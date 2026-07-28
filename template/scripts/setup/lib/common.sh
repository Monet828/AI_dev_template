#!/usr/bin/env bash

required_paths=(
  "AGENTS.md"
  "CLAUDE.md"
  "app"
  "app/README.md"
  "docs/adr"
  "memory/current-state.md"
  "memory/decisions.md"
  "memory/tasks.md"
  "memory/sessions"
  "skills"
  "assets/patterns"
  "scripts/setup/bootstrap.sh"
  "scripts/setup/doctor.sh"
  "scripts/hooks/save-memory.sh"
  "src"
  "tests"
)

root_project_markers=(
  "package.json"
  "pyproject.toml"
  "Cargo.toml"
  "go.mod"
  "Gemfile"
)

app_project_markers=(
  "app/package.json"
  "app/pyproject.toml"
  "app/Cargo.toml"
  "app/go.mod"
  "app/Gemfile"
  "app/requirements.txt"
  "app/next.config.ts"
  "app/next.config.js"
  "app/vercel.json"
)

print_required_paths() {
  local root_dir="$1"
  for path in "${required_paths[@]}"; do
    if [[ -e "$root_dir/$path" ]]; then
      echo "[ok] $path"
    else
      echo "[missing] $path"
    fi
  done
}

print_root_project_markers() {
  local root_dir="$1"
  local found=false
  for marker in "${root_project_markers[@]}"; do
    if [[ -f "$root_dir/$marker" ]]; then
      echo "[detected] $marker"
      found=true
    fi
  done
  if [[ "$found" == false ]]; then
    echo "[info] no common root project manifest detected"
  fi
}

print_app_project_markers() {
  local root_dir="$1"
  local found=false
  for marker in "${app_project_markers[@]}"; do
    if [[ -f "$root_dir/$marker" ]]; then
      echo "[detected] $marker"
      found=true
    fi
  done
  if [[ "$found" == false ]]; then
    echo "[info] no common app manifest detected under app/"
  fi
}
