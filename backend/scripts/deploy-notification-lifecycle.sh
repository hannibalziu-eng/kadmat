#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/_db_url_utils.sh"

cd "$BACKEND_DIR"

preserve_external_db_urls

if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

restore_external_db_urls
sanitize_configured_db_urls
autofill_db_urls_from_supabase_env

TARGET="${1:-auto}"
DB_URL="$(resolve_db_url_for_target "$TARGET")"
if [[ -z "$DB_URL" ]]; then
  echo "❌ Missing DB URL for target='$TARGET'."
  echo "   Set DATABASE_URL or STAGING_DB_URL or PROD_DB_URL."
  echo "   Or set SUPABASE_URL + SUPABASE_DB_PASSWORD and script will auto-build."
  echo "   Usage: bash scripts/deploy-notification-lifecycle.sh [staging|prod|auto]"
  exit 1
fi

if ! validate_resolved_db_url "$DB_URL"; then
  exit 1
fi

PSQL_BIN="${PSQL_BIN:-}"
if [[ -z "$PSQL_BIN" ]]; then
  if command -v /opt/homebrew/opt/libpq/bin/psql >/dev/null 2>&1; then
    PSQL_BIN="/opt/homebrew/opt/libpq/bin/psql"
  else
    PSQL_BIN="psql"
  fi
fi

echo "==> Applying migration 33 (notification lifecycle telemetry)"
"$PSQL_BIN" "$DB_URL" -v ON_ERROR_STOP=1 \
  -f "$BACKEND_DIR/migrations/33_notification_lifecycle_events.sql"

echo
echo "==> Running notification lifecycle contract audit"
"$PSQL_BIN" "$DB_URL" -v ON_ERROR_STOP=1 \
  -f "$BACKEND_DIR/scripts/audit-notification-lifecycle-contract.sql"

echo
echo "✅ Notification lifecycle deployment completed for target='$TARGET'."
