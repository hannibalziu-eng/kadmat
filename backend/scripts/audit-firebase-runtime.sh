#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/_db_url_utils.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/audit-firebase-runtime.sh [staging|prod|auto] [--user <uuid>] [--non-strict]

Options:
  --user <uuid>     Optional user id for live push smoke (requires valid users.fcm_token)
  --non-strict      Do not fail if Firebase init is disabled/missing

Environment sources:
  - .env
  - .env.autopilot (optional)
  - target-aware vars:
      STAGING_SUPABASE_URL / STAGING_SUPABASE_SERVICE_ROLE_KEY
      PROD_SUPABASE_URL / PROD_SUPABASE_SERVICE_ROLE_KEY
      STAGING_FIREBASE_SERVICE_ACCOUNT / PROD_FIREBASE_SERVICE_ACCOUNT
      FIREBASE_SERVICE_ACCOUNT (fallback)
EOF
}

TARGET="auto"
PUSH_SMOKE_USER_ID=""
STRICT_MODE="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    staging|stage|prod|production|auto)
      TARGET="$1"
      shift
      ;;
    --user)
      if [[ $# -lt 2 ]]; then
        echo "❌ --user requires a UUID value"
        exit 1
      fi
      PUSH_SMOKE_USER_ID="$2"
      shift 2
      ;;
    --non-strict)
      STRICT_MODE="false"
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

case "$TARGET" in
  staging|stage)
    if [[ -n "${STAGING_FIREBASE_SERVICE_ACCOUNT:-}" ]]; then
      FIREBASE_SERVICE_ACCOUNT="$STAGING_FIREBASE_SERVICE_ACCOUNT"
    fi
    ;;
  prod|production)
    if [[ -n "${PROD_FIREBASE_SERVICE_ACCOUNT:-}" ]]; then
      FIREBASE_SERVICE_ACCOUNT="$PROD_FIREBASE_SERVICE_ACCOUNT"
    fi
    ;;
esac

export SUPABASE_URL="${SUPABASE_URL:-}"
export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
export FIREBASE_SERVICE_ACCOUNT="${FIREBASE_SERVICE_ACCOUNT:-}"
export AUDIT_FIREBASE_STRICT="$STRICT_MODE"
export PUSH_SMOKE_USER_ID="$PUSH_SMOKE_USER_ID"

if [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" && "${SUPABASE_SERVICE_ROLE_KEY}" == sb_publishable_* ]]; then
  echo "❌ SUPABASE_SERVICE_ROLE_KEY is publishable; service-role key is required for this audit."
  echo "   Update target env with real service-role secret and retry."
  exit 1
fi

echo "🔍 Running Firebase runtime audit (target=$TARGET, strict=$STRICT_MODE)"
if [[ -n "$PUSH_SMOKE_USER_ID" ]]; then
  echo "🧪 Push smoke user: $PUSH_SMOKE_USER_ID"
else
  echo "🧪 Push smoke user: <none>"
fi

node scripts/audit-firebase-runtime.js
