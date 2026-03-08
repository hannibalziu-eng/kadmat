#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/_db_url_utils.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/autopilot-update.sh [staging|prod|auto] [--skip-release-audits]

Behavior:
  1) Loads env from .env and optional .env.autopilot
  2) Resolves DB URL automatically (or from explicit vars)
  3) Applies migrations 29 -> 35 safely
  4) Runs release contract audits (unless skipped)

Supported env inputs:
  - DATABASE_URL / STAGING_DB_URL / PROD_DB_URL
  - SUPABASE_URL + SUPABASE_DB_PASSWORD (auto-build DB URL)
  - STAGING_SUPABASE_URL + STAGING_SUPABASE_DB_PASSWORD
  - PROD_SUPABASE_URL + PROD_SUPABASE_DB_PASSWORD
  - STAGING_SUPABASE_SERVICE_ROLE_KEY / PROD_SUPABASE_SERVICE_ROLE_KEY
EOF
}

TARGET="auto"
SKIP_RELEASE_AUDITS="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    staging|stage|prod|production|auto)
      TARGET="$1"
      shift
      ;;
    --skip-release-audits)
      SKIP_RELEASE_AUDITS="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1"
      echo
      usage
      exit 1
      ;;
  esac
done

cd "$BACKEND_DIR"

preserve_external_db_urls

if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [[ -f ".env.autopilot" ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.autopilot
  set +a
fi

restore_external_db_urls
sanitize_configured_db_urls
autofill_db_urls_from_supabase_env
apply_target_supabase_env "$TARGET"

if [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" && "${SUPABASE_SERVICE_ROLE_KEY}" == sb_publishable_* ]]; then
  echo "❌ SUPABASE_SERVICE_ROLE_KEY is set to a publishable key."
  echo "   Put the real Service Role key in .env.autopilot (STAGING/PROD_SUPABASE_SERVICE_ROLE_KEY)."
  exit 1
fi

DB_URL="$(resolve_db_url_for_target "$TARGET")"
if [[ -z "$DB_URL" ]]; then
  echo "❌ Missing DB URL for target='$TARGET'."
  echo "   Fill backend/.env.autopilot with real Supabase values."
  echo "   Quick start: cp .env.autopilot.example .env.autopilot"
  exit 1
fi

if ! validate_resolved_db_url "$DB_URL"; then
  echo "❌ Could not resolve a valid DB URL for target='$TARGET'."
  exit 1
fi

export DATABASE_URL="$DB_URL"

PSQL_BIN="${PSQL_BIN:-}"
if [[ -z "$PSQL_BIN" ]]; then
  if command -v /opt/homebrew/opt/libpq/bin/psql >/dev/null 2>&1; then
    PSQL_BIN="/opt/homebrew/opt/libpq/bin/psql"
  else
    PSQL_BIN="psql"
  fi
fi

echo "🚀 Autopilot update started (target=$TARGET)"
echo "🗄️  DB: $(mask_db_url "$DB_URL")"
echo

MIGRATIONS=(
  "29_create_api_idempotency_keys.sql"
  "30_wallet_commission_idempotency.sql"
  "31_add_jobs_after_photos.sql"
  "32_notifications_dedupe_key_upsert_fix.sql"
  "33_notification_lifecycle_events.sql"
  "34_private_media_buckets_and_signed_only.sql"
  "35_backfill_media_storage_refs.sql"
  "36_add_users_fcm_token.sql"
)

for migration in "${MIGRATIONS[@]}"; do
  migration_path="$BACKEND_DIR/migrations/$migration"
  if [[ ! -f "$migration_path" ]]; then
    echo "❌ Migration file missing: $migration_path"
    exit 1
  fi

  echo "==> Applying $migration"
  "$PSQL_BIN" "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration_path"
done

echo
echo "✅ Database migrations completed."

if [[ "$SKIP_RELEASE_AUDITS" == "true" ]]; then
  echo "⚠️ Skipping release audits (--skip-release-audits)."
else
  echo
  echo "==> Running release contract audits"
  bash "$SCRIPT_DIR/run_release_contract_audits.sh"
fi

echo
echo "✅ Autopilot update completed for target='$TARGET'."
