#!/usr/bin/env bash
set -uo pipefail
# Intentionally not `set -e`: this runner must execute every case even if an
# earlier one fails, so it can print a full summary at the end.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CASES_DIR="$ROOT_DIR/tests/regression/cases"

if [[ ! -d "$CASES_DIR" ]]; then
  echo "[error] no cases directory: $CASES_DIR" >&2
  exit 1
fi

total=0
failed=0
failed_names=()

while IFS= read -r case_file; do
  total=$((total + 1))
  name="$(basename "$case_file")"
  echo "== $name =="
  if AI_DEV_TEMPLATE_ROOT="$ROOT_DIR" bash "$case_file"; then
    echo "[PASS] $name"
  else
    echo "[FAIL] $name"
    failed=$((failed + 1))
    failed_names+=("$name")
  fi
  echo
done < <(find "$CASES_DIR" -maxdepth 1 -type f -name '*.sh' | sort)

echo "== Summary =="
echo "total: $total, passed: $((total - failed)), failed: $failed"
if [[ "$failed" -gt 0 ]]; then
  echo "failed cases:"
  for n in "${failed_names[@]}"; do
    echo "  - $n"
  done
  exit 1
fi

exit 0
