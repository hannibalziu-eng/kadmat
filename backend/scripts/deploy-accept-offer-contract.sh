#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/_db_url_utils.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/deploy-accept-offer-contract.sh [staging|prod|auto] [--skip-audit]

Behavior:
  1) Loads env from .env and optional .env.autopilot
  2) Resolves DB URL automatically (or from explicit vars)
  3) Applies migrations 22 -> 25
  4) Runs accept-offer contract audit (unless --skip-audit)

Supported env inputs:
  - DATABASE_URL / STAGING_DB_URL / PROD_DB_URL
  - SUPABASE_URL + SUPABASE_DB_PASSWORD (auto-build DB URL)
  - STAGING_SUPABASE_URL + STAGING_SUPABASE_DB_PASSWORD
  - PROD_SUPABASE_URL + PROD_SUPABASE_DB_PASSWORD
  - STAGING_SUPABASE_SERVICE_ROLE_KEY / PROD_SUPABASE_SERVICE_ROLE_KEY
EOF
}

TARGET="auto"
SKIP_AUDIT="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    staging|stage|prod|production|auto)
      TARGET="$1"
      shift
      ;;
    --skip-audit)
      SKIP_AUDIT="true"
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

DB_URL="$(resolve_db_url_for_target "$TARGET")"
if [[ -z "$DB_URL" ]]; then
  echo "❌ Missing DB URL for target='$TARGET'."
  echo "   Fill backend/.env.autopilot with real Supabase values."
  echo "   Quick start: cp .env.autopilot.example .env.autopilot"
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

echo "🚀 Accept-offer contract deployment started (target=$TARGET)"
echo "🗄️  DB: $(mask_db_url "$DB_URL")"
echo

MIGRATIONS=(
  "22_add_jobs_accepted_bid_id.sql"
  "23_create_update_user_location_rpc.sql"
  "24_accept_job_offer_atomic_rpc.sql"
  "25_offer_acceptance_on_the_way_and_locks.sql"
)

for migration in "${MIGRATIONS[@]}"; do
  migration_path="$BACKEND_DIR/migrations/$migration"
  if [[ ! -f "$migration_path" ]]; then
    echo "❌ Migration file missing: $migration_path"
    exit 1
  fi

  echo "==> Applying $migration"
  if ! "$PSQL_BIN" "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration_path"; then
    echo
    echo "❌ Failed while applying $migration."
    echo "   If this is a DNS/host resolution issue, use Supabase SQL Editor fallback:"
    echo "   1) Run files in order:"
    printf '      - %s\n' "${MIGRATIONS[@]}"
    echo "   2) Then run audit SQL:"
    echo "      - scripts/audit-accept-offer-contract.sql"
    exit 1
  fi
done

echo
echo "✅ Accept-offer migrations (22->25) completed."

if [[ "$SKIP_AUDIT" == "true" ]]; then
  echo "⚠️ Skipping accept-offer contract audit (--skip-audit)."
  echo "✅ Accept-offer contract deployment completed for target='$TARGET'."
  exit 0
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "⚠️ Skipping audit because SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY are missing."
  echo "   Run manually after setting env: npm run audit:accept-offer-contract"
  echo "✅ Accept-offer migrations applied for target='$TARGET'."
  exit 0
fi

echo
echo "==> Running accept-offer contract audit"
npm run audit:accept-offer-contract

echo
echo "✅ Accept-offer contract deployment completed for target='$TARGET'."
