#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCAFFOLD_SCRIPT="$ROOT_DIR/scripts/setup/scaffold.sh"

usage() {
  cat <<EOF
Usage:
  ./scripts/setup/new-project.sh <target_dir> [profile]
  ./scripts/setup/new-project.sh <target_dir> --packs pack1,pack2

Profiles:
  minimal            No packs
  understand         understand-first
  research           understand-first,evidence-first
  strategy           evidence-first,problem-first
  full               understand-first,evidence-first,problem-first
  full-slides        understand-first,evidence-first,problem-first,slides

Examples:
  ./scripts/setup/new-project.sh /path/to/new-project
  ./scripts/setup/new-project.sh /path/to/new-project full
  ./scripts/setup/new-project.sh /path/to/new-project --packs understand-first,evidence-first
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

target_dir="$1"
shift

profile="minimal"
packs=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packs)
      packs="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      profile="$1"
      shift
      ;;
  esac
done

if [[ -z "$packs" ]]; then
  case "$profile" in
    minimal)
      packs=""
      ;;
    understand)
      packs="understand-first"
      ;;
    research)
      packs="understand-first,evidence-first"
      ;;
    strategy)
      packs="evidence-first,problem-first"
      ;;
    full)
      packs="understand-first,evidence-first,problem-first"
      ;;
    full-slides)
      packs="understand-first,evidence-first,problem-first,slides"
      ;;
    *)
      echo "[error] unknown profile: $profile" >&2
      usage
      exit 1
      ;;
  esac
fi

echo "== New Project =="
echo "target: $target_dir"
if [[ -n "$packs" ]]; then
  echo "packs: $packs"
  "$SCAFFOLD_SCRIPT" "$target_dir" --with "$packs"
else
  echo "packs: none"
  "$SCAFFOLD_SCRIPT" "$target_dir"
fi
