#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"
cd "$ROOT_DIR"

echo "[1/4] Removing Flutter build outputs..."
rm -rf build

echo "[2/4] Removing backend runtime logs..."
rm -f backend/logs/*.log || true
rmdir backend/logs 2>/dev/null || true

echo "[3/4] Removing macOS metadata files..."
find . -name '.DS_Store' -not -path './.git/*' -delete

echo "[4/4] Running hygiene check..."
chmod +x ./scripts/repo_hygiene_check.sh
./scripts/repo_hygiene_check.sh

echo "Local artifact cleanup complete."
