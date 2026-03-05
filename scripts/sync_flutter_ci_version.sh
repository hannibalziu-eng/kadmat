#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_FLUTTER_VERSION="${1:-3.30.0}"

if [[ ! -f "$ROOT_DIR/pubspec.yaml" ]]; then
  echo "ERROR: pubspec.yaml not found at repo root: $ROOT_DIR"
  exit 1
fi

required_dart_sdk="$(
  awk '
    /^environment:/ { in_environment = 1; next }
    in_environment && /^[[:space:]]*sdk:/ {
      gsub(/"/, "", $2)
      print $2
      exit
    }
  ' "$ROOT_DIR/pubspec.yaml"
)"

if [[ -z "$required_dart_sdk" ]]; then
  echo "ERROR: Could not detect Dart SDK constraint from pubspec.yaml"
  exit 1
fi

workflow_files=()
while IFS= read -r workflow_file; do
  workflow_files+=("$workflow_file")
done < <(rg -l "subosito/flutter-action@" "$ROOT_DIR/.github/workflows" -g "*.yml" -g "*.yaml" | sort)

if [[ ${#workflow_files[@]} -eq 0 ]]; then
  echo "No workflows using subosito/flutter-action were found."
  exit 0
fi

echo "Detected Dart SDK constraint: $required_dart_sdk"
echo "Target Flutter version: $TARGET_FLUTTER_VERSION"
echo

updated_count=0

for workflow_file in "${workflow_files[@]}"; do
  before_hash="$(shasum "$workflow_file" | awk '{print $1}')"

  TARGET_VERSION="$TARGET_FLUTTER_VERSION" perl -i -pe \
    's/(flutter-version:\s*["\047])[^"\047]+(["\047])/$1.$ENV{TARGET_VERSION}.$2/ge' \
    "$workflow_file"

  after_hash="$(shasum "$workflow_file" | awk '{print $1}')"

  if [[ "$before_hash" != "$after_hash" ]]; then
    updated_count=$((updated_count + 1))
    current_line="$(rg -n "flutter-version:" "$workflow_file" -N || true)"
    current_line="${current_line//$'\n'/}"
    echo "Updated: ${workflow_file#$ROOT_DIR/} -> $current_line"
  fi
done

echo
if [[ $updated_count -eq 0 ]]; then
  echo "No flutter-version changes were needed."
else
  echo "Updated $updated_count workflow file(s)."
fi
