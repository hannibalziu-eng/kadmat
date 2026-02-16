#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"
cd "$ROOT_DIR"

exit_code=0

print_section() {
  printf '\n[%s]\n' "$1"
}

print_section "Duplicate name artifacts (... 2)"
duplicate_items="$(find . -name '* 2*' -not -path './.git/*' | sort || true)"
if [[ -n "$duplicate_items" ]]; then
  printf '%s\n' "$duplicate_items"
  exit_code=1
else
  echo "none"
fi

print_section "Mac metadata files (.DS_Store)"
ds_store_items="$(find . -name '.DS_Store' -not -path './.git/*' | sort || true)"
if [[ -n "$ds_store_items" ]]; then
  printf '%s\n' "$ds_store_items"
  exit_code=1
else
  echo "none"
fi

print_section "Root temporary artifacts"
root_temp_items=""
for f in analysis_output.txt analysis.txt analysis_final.txt; do
  if [[ -f "$f" ]]; then
    root_temp_items+="$f"$'\n'
  fi
done

if [[ -n "$root_temp_items" ]]; then
  printf '%s' "$root_temp_items"
  exit_code=1
else
  echo "none"
fi

if [[ "$exit_code" -ne 0 ]]; then
  print_section "Result"
  echo "FAILED: repository hygiene violations found."
  exit "$exit_code"
fi

print_section "Result"
echo "OK: repository hygiene checks passed."
