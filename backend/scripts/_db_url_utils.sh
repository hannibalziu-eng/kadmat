#!/usr/bin/env bash

preserve_external_db_urls() {
  EXTERNAL_DATABASE_URL="${DATABASE_URL:-}"
  EXTERNAL_STAGING_DB_URL="${STAGING_DB_URL:-}"
  EXTERNAL_PROD_DB_URL="${PROD_DB_URL:-}"
}

restore_external_db_urls() {
  DATABASE_URL="${EXTERNAL_DATABASE_URL:-${DATABASE_URL:-}}"
  STAGING_DB_URL="${EXTERNAL_STAGING_DB_URL:-${STAGING_DB_URL:-}}"
  PROD_DB_URL="${EXTERNAL_PROD_DB_URL:-${PROD_DB_URL:-}}"
}

extract_project_ref_from_url() {
  local supabase_url="${1:-}"
  if [[ -z "$supabase_url" ]]; then
    return 1
  fi

  echo "$supabase_url" | sed -nE 's#^https://([a-z0-9]+)\.supabase\.co/?$#\1#p'
}

url_encode_component() {
  local raw="${1:-}"
  if command -v node >/dev/null 2>&1; then
    node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$raw"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$raw"
    return 0
  fi

  printf '%s' "$raw"
}

build_direct_db_url() {
  local project_ref="${1:-}"
  local raw_password="${2:-}"
  if [[ -z "$project_ref" || -z "$raw_password" ]]; then
    return 1
  fi

  local encoded_password
  encoded_password="$(url_encode_component "$raw_password")"
  printf 'postgresql://postgres:%s@db.%s.supabase.co:5432/postgres' "$encoded_password" "$project_ref"
}

autofill_db_urls_from_supabase_env() {
  local explicit_global_db_url="${SUPABASE_DB_URL:-}"
  local explicit_staging_db_url="${STAGING_SUPABASE_DB_URL:-}"
  local explicit_prod_db_url="${PROD_SUPABASE_DB_URL:-}"

  local default_supabase_url="${SUPABASE_URL:-}"
  local default_db_password="${SUPABASE_DB_PASSWORD:-${DB_PASSWORD:-}}"

  local staging_supabase_url="${STAGING_SUPABASE_URL:-$default_supabase_url}"
  local staging_db_password="${STAGING_SUPABASE_DB_PASSWORD:-${STAGING_DB_PASSWORD:-$default_db_password}}"
  local prod_supabase_url="${PROD_SUPABASE_URL:-$default_supabase_url}"
  local prod_db_password="${PROD_SUPABASE_DB_PASSWORD:-${PROD_DB_PASSWORD:-$default_db_password}}"

  if [[ -z "${STAGING_DB_URL:-}" && -n "$explicit_staging_db_url" ]]; then
    STAGING_DB_URL="$explicit_staging_db_url"
  fi

  if [[ -z "${PROD_DB_URL:-}" && -n "$explicit_prod_db_url" ]]; then
    PROD_DB_URL="$explicit_prod_db_url"
  fi

  if [[ -z "${DATABASE_URL:-}" && -n "$explicit_global_db_url" ]]; then
    DATABASE_URL="$explicit_global_db_url"
  fi

  if [[ -z "${STAGING_DB_URL:-}" ]]; then
    local staging_ref
    staging_ref="$(extract_project_ref_from_url "$staging_supabase_url" || true)"
    if [[ -n "$staging_ref" && -n "$staging_db_password" ]]; then
      STAGING_DB_URL="$(build_direct_db_url "$staging_ref" "$staging_db_password")"
    fi
  fi

  if [[ -z "${PROD_DB_URL:-}" ]]; then
    local prod_ref
    prod_ref="$(extract_project_ref_from_url "$prod_supabase_url" || true)"
    if [[ -n "$prod_ref" && -n "$prod_db_password" ]]; then
      PROD_DB_URL="$(build_direct_db_url "$prod_ref" "$prod_db_password")"
    fi
  fi

  if [[ -z "${DATABASE_URL:-}" ]]; then
    DATABASE_URL="${STAGING_DB_URL:-${PROD_DB_URL:-}}"
  fi
}

resolve_db_url_for_target() {
  local target="${1:-auto}"
  case "$target" in
    prod|production)
      echo "${PROD_DB_URL:-}"
      ;;
    staging|stage)
      echo "${STAGING_DB_URL:-}"
      ;;
    default|database|auto)
      if [[ -n "${DATABASE_URL:-}" ]]; then
        echo "${DATABASE_URL}"
      elif [[ -n "${STAGING_DB_URL:-}" ]]; then
        echo "${STAGING_DB_URL}"
      else
        echo "${PROD_DB_URL:-}"
      fi
      ;;
    *)
      echo ""
      ;;
  esac
}

validate_resolved_db_url() {
  local db_url="${1:-}"
  if [[ -z "$db_url" ]]; then
    echo "❌ Missing DB URL. Set DATABASE_URL or STAGING_DB_URL or PROD_DB_URL."
    return 1
  fi

  if [[ "$db_url" == *"..."* || "$db_url" == *"[PASSWORD]"* || "$db_url" == *"[STAGING_REF]"* || "$db_url" == *"[PROD_REF]"* || "$db_url" == *"القيمة الحقيقية"* || "$db_url" == *"YOUR_REAL_"* || "$db_url" == *"REAL_"* ]]; then
    echo "❌ DB URL appears to be a placeholder, not a real connection string."
    echo "   Copy the exact Direct connection string from Supabase -> Connect."
    return 1
  fi

  if [[ "$db_url" == *" "* ]]; then
    echo "❌ DB URL contains spaces. Use the exact URI without spaces."
    echo "   If password has special chars, set SUPABASE_DB_PASSWORD and let scripts encode it."
    return 1
  fi

  return 0
}

is_placeholder_or_malformed_db_url() {
  local db_url="${1:-}"
  if [[ -z "$db_url" ]]; then
    return 1
  fi

  if [[ "$db_url" == *"..."* || "$db_url" == *"[PASSWORD]"* || "$db_url" == *"[STAGING_REF]"* || "$db_url" == *"[PROD_REF]"* || "$db_url" == *"القيمة الحقيقية"* || "$db_url" == *"YOUR_REAL_"* || "$db_url" == *"REAL_"* ]]; then
    return 0
  fi

  if [[ "$db_url" == *" "* ]]; then
    return 0
  fi

  if [[ "$db_url" == *"@db..supabase.co"* || "$db_url" == "postgresql://postgres:@"* ]]; then
    return 0
  fi

  return 1
}

sanitize_configured_db_urls() {
  if is_placeholder_or_malformed_db_url "${DATABASE_URL:-}"; then
    unset DATABASE_URL
  fi

  if is_placeholder_or_malformed_db_url "${STAGING_DB_URL:-}"; then
    unset STAGING_DB_URL
  fi

  if is_placeholder_or_malformed_db_url "${PROD_DB_URL:-}"; then
    unset PROD_DB_URL
  fi
}

mask_db_url() {
  local db_url="${1:-}"
  if [[ -z "$db_url" ]]; then
    echo "<empty>"
    return 0
  fi

  echo "$db_url" | sed -E 's#(postgresql://[^:]+:).+(@.+)#\1***\2#'
}

apply_target_supabase_env() {
  local target="${1:-auto}"
  case "$target" in
    staging|stage)
      if [[ -n "${STAGING_SUPABASE_URL:-}" ]]; then
        SUPABASE_URL="$STAGING_SUPABASE_URL"
      fi
      if [[ -n "${STAGING_SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
        SUPABASE_SERVICE_ROLE_KEY="$STAGING_SUPABASE_SERVICE_ROLE_KEY"
      fi
      ;;
    prod|production)
      if [[ -n "${PROD_SUPABASE_URL:-}" ]]; then
        SUPABASE_URL="$PROD_SUPABASE_URL"
      fi
      if [[ -n "${PROD_SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
        SUPABASE_SERVICE_ROLE_KEY="$PROD_SUPABASE_SERVICE_ROLE_KEY"
      fi
      ;;
  esac
}
