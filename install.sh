#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Install Template =="
required_dirs=(
  "agents"
  "assets/patterns"
  "docs/adr"
  "memory/sessions"
  "src"
  "tests"
  "scripts/hooks"
  "scripts/loop"
  "scripts/setup"
)

for dir in "${required_dirs[@]}"; do
  mkdir -p "$ROOT_DIR/$dir"
done

echo "Template directories are ready."
echo "Run ./scripts/setup/doctor.sh to inspect the project."
