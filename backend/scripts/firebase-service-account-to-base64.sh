#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: bash scripts/firebase-service-account-to-base64.sh <path-to-service-account.json>"
  exit 1
fi

INPUT_FILE="$1"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "❌ File not found: $INPUT_FILE"
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  # Validate JSON structure quickly
  jq -e '.project_id and .client_email and .private_key' "$INPUT_FILE" >/dev/null
fi

# macOS uses -b 0, GNU uses -w 0
if base64 --help 2>/dev/null | rg -q -- '-w'; then
  ENCODED="$(base64 -w 0 < "$INPUT_FILE")"
else
  ENCODED="$(base64 -b 0 < "$INPUT_FILE")"
fi

echo "$ENCODED"

