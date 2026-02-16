#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

echo "==> Pre-Deploy Hard Gate"
echo "Root: $ROOT_DIR"

echo
echo "==> Flutter analyze"
cd "$ROOT_DIR"
dart analyze

echo
echo "==> Flutter tests"
flutter test

echo
echo "==> Backend tests"
cd "$BACKEND_DIR"
npm test -- --runInBand

echo
if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "==> Contract audits (SUPABASE secrets detected)"
  npm run audit:accept-offer-contract
  npm run audit:rpc
else
  echo "==> Skipping contract audits (missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)"
  echo "    Run manually with secrets:"
  echo "    npm run audit:accept-offer-contract"
  echo "    npm run audit:rpc"
fi

echo
echo "✅ Pre-Deploy Hard Gate completed successfully."
