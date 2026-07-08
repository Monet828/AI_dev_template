#!/usr/bin/env bash

required_paths=(
  "AGENTS.md"
  "CLAUDE.md"
  "memory/current-state.md"
  "memory/decisions.md"
  "memory/tasks.md"
  "src"
  "tests"
  "docs/adr"
  "memory/sessions"
  "assets/patterns"
  "scripts/setup/bootstrap.sh"
  "scripts/setup/doctor.sh"
  "scripts/hooks/save-memory.sh"
)

project_markers=(
  "package.json"
  "pyproject.toml"
  "Cargo.toml"
  "go.mod"
  "Gemfile"
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

print_project_markers() {
  local root_dir="$1"
  local found=false
  for marker in "${project_markers[@]}"; do
    if [[ -f "$root_dir/$marker" ]]; then
      echo "[detected] $marker"
      found=true
    fi
  done
  if [[ "$found" == false ]]; then
    echo "[info] no common root project manifest detected"
  fi
}
