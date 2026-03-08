#!/usr/bin/env bash

set -euo pipefail

API_BASE="${API_BASE:-http://127.0.0.1:3000}"
JOB_ID="${JOB_ID:-}"
TTL_EXPIRES_SECONDS="${TTL_EXPIRES_SECONDS:-60}"
TTL_WAIT_SECONDS="${TTL_WAIT_SECONDS:-90}"

if [[ -z "${JOB_ID}" ]]; then
  cat <<'EOF'
❌ Missing JOB_ID.
Usage:
  API_BASE=http://127.0.0.1:3000 JOB_ID=<uuid> bash scripts/smoke-signed-media.sh

Auth options:
  1) Provide tokens directly:
     CUSTOMER_TOKEN, TECHNICIAN_TOKEN, OTHER_USER_TOKEN
  2) Or provide credentials and script will login:
     CUSTOMER_EMAIL + CUSTOMER_PASS
     TECH_EMAIL + TECH_PASS
     OTHER_EMAIL + OTHER_PASS
EOF
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

get_token() {
  local role="${1:-user}"
  local email="${2:-}"
  local pass="${3:-}"

  if [[ -z "${email}" || -z "${pass}" ]]; then
    echo "ℹ️ ${role}: missing email/password, skipping auto-login" >&2
    echo ""
    return 0
  fi

  email="$(echo "$email" | xargs)"

  local payload
  payload=$(python3 -c 'import json,sys; print(json.dumps({"email": sys.argv[1], "password": sys.argv[2]}))' "$email" "$pass")

  local resp status
  status=$(curl -sS -m 20 -o "$TMP_DIR/login_resp.json" -w "%{http_code}" \
    -X POST "${API_BASE}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "$payload" || true)
  resp="$(cat "$TMP_DIR/login_resp.json" 2>/dev/null || true)"

  if [[ "${status}" != "200" ]]; then
    local message
    message="$(python3 - <<'PY' "$resp"
import json, sys
raw = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    data = json.loads(raw or "{}")
except Exception:
    print("")
    raise SystemExit(0)
msg = data.get("message") if isinstance(data, dict) else ""
print(msg if isinstance(msg, str) else "")
PY
)"
    if [[ "${status}" == "429" ]]; then
      echo "❌ ${role}: login rate-limited (429). Wait 15 minutes then retry." >&2
    else
      echo "❌ ${role}: login failed (status=${status})${message:+ - ${message}}" >&2
    fi
    echo ""
    return 0
  fi

  echo "✅ ${role}: login successful" >&2

  python3 - <<'PY' "$resp"
import json, sys
raw = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    data = json.loads(raw or "{}")
except Exception:
    print("")
    raise SystemExit(0)
token = data.get("token")
print(token if isinstance(token, str) else "")
PY
}

status_of() {
  local out_file="$1"
  shift
  curl -sS -m 20 -o "$out_file" -w "%{http_code}" "$@" || true
}

extract_first_signed_url() {
  local file="$1"
  python3 - <<'PY' "$file"
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        body = json.load(f)
except Exception:
    print("")
    raise SystemExit(0)
data = body.get("data") if isinstance(body, dict) else {}
if not isinstance(data, dict):
    print("")
    raise SystemExit(0)
arr = []
for key in ("prePhotos", "postPhotos", "customerPhotos"):
    val = data.get(key, [])
    if isinstance(val, list):
        arr.extend([x for x in val if isinstance(x, str) and x.strip()])
print(arr[0] if arr else "")
PY
}

print_check() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  local ok="$4"
  if [[ "$ok" == "1" ]]; then
    echo "✅ ${label}: ${actual} (expected ${expected})"
  else
    echo "❌ ${label}: ${actual} (expected ${expected})"
  fi
}

CUSTOMER_TOKEN="${CUSTOMER_TOKEN:-}"
TECHNICIAN_TOKEN="${TECHNICIAN_TOKEN:-}"
OTHER_USER_TOKEN="${OTHER_USER_TOKEN:-}"

if [[ -z "$CUSTOMER_TOKEN" ]]; then
  CUSTOMER_TOKEN="$(get_token "customer" "${CUSTOMER_EMAIL:-}" "${CUSTOMER_PASS:-}")"
fi
if [[ -z "$TECHNICIAN_TOKEN" ]]; then
  TECHNICIAN_TOKEN="$(get_token "technician" "${TECH_EMAIL:-}" "${TECH_PASS:-}")"
fi
if [[ -z "$OTHER_USER_TOKEN" ]]; then
  OTHER_USER_TOKEN="$(get_token "other_user" "${OTHER_EMAIL:-}" "${OTHER_PASS:-}")"
fi

echo "🔎 Signed media smoke"
echo "API_BASE=${API_BASE}"
echo "JOB_ID=${JOB_ID}"
echo "Token lengths: customer=${#CUSTOMER_TOKEN} technician=${#TECHNICIAN_TOKEN} other=${#OTHER_USER_TOKEN}"
echo

FAIL=0

NO_TOKEN_STATUS=$(status_of "$TMP_DIR/no_token.json" "${API_BASE}/api/jobs/${JOB_ID}/media-signed")
[[ "$NO_TOKEN_STATUS" == "401" ]] && OK=1 || OK=0
print_check "No token" "$NO_TOKEN_STATUS" "401" "$OK"
[[ "$OK" == "1" ]] || FAIL=1

EMPTY_BEARER_STATUS=$(status_of "$TMP_DIR/empty_bearer.json" \
  -H "Authorization: Bearer " \
  "${API_BASE}/api/jobs/${JOB_ID}/media-signed")
[[ "$EMPTY_BEARER_STATUS" == "401" ]] && OK=1 || OK=0
print_check "Empty bearer" "$EMPTY_BEARER_STATUS" "401" "$OK"
[[ "$OK" == "1" ]] || FAIL=1

if [[ -n "$CUSTOMER_TOKEN" ]]; then
  CUSTOMER_STATUS=$(status_of "$TMP_DIR/customer.json" \
    -H "Authorization: Bearer ${CUSTOMER_TOKEN}" \
    "${API_BASE}/api/jobs/${JOB_ID}/media-signed?expiresIn=600")
  [[ "$CUSTOMER_STATUS" == "200" ]] && OK=1 || OK=0
  print_check "Customer token" "$CUSTOMER_STATUS" "200" "$OK"
  [[ "$OK" == "1" ]] || FAIL=1
else
  echo "❌ Customer token unavailable"
  FAIL=1
fi

if [[ -n "$TECHNICIAN_TOKEN" ]]; then
  TECH_STATUS=$(status_of "$TMP_DIR/tech.json" \
    -H "Authorization: Bearer ${TECHNICIAN_TOKEN}" \
    "${API_BASE}/api/jobs/${JOB_ID}/media-signed?expiresIn=600")
  [[ "$TECH_STATUS" == "200" ]] && OK=1 || OK=0
  print_check "Technician token" "$TECH_STATUS" "200" "$OK"
  [[ "$OK" == "1" ]] || FAIL=1
else
  echo "❌ Technician token unavailable"
  FAIL=1
fi

if [[ -n "$OTHER_USER_TOKEN" ]]; then
  OTHER_STATUS=$(status_of "$TMP_DIR/other.json" \
    -H "Authorization: Bearer ${OTHER_USER_TOKEN}" \
    "${API_BASE}/api/jobs/${JOB_ID}/media-signed?expiresIn=600")
  if [[ "$OTHER_STATUS" == "403" || "$OTHER_STATUS" == "404" ]]; then
    OK=1
  else
    OK=0
  fi
  print_check "Other user token" "$OTHER_STATUS" "403/404" "$OK"
  [[ "$OK" == "1" ]] || FAIL=1
else
  echo "❌ Other-user token unavailable"
  FAIL=1
fi

echo
echo "🕒 TTL check"
TTL_AUTH_TOKEN="$CUSTOMER_TOKEN"
if [[ -z "$TTL_AUTH_TOKEN" ]]; then
  TTL_AUTH_TOKEN="$TECHNICIAN_TOKEN"
fi

if [[ -z "$TTL_AUTH_TOKEN" ]]; then
  echo "❌ TTL cannot run (no authorized token available)"
  FAIL=1
else
  TTL_STATUS=$(status_of "$TMP_DIR/ttl_payload.json" \
    -H "Authorization: Bearer ${TTL_AUTH_TOKEN}" \
    "${API_BASE}/api/jobs/${JOB_ID}/media-signed?expiresIn=${TTL_EXPIRES_SECONDS}")
  if [[ "$TTL_STATUS" != "200" ]]; then
    echo "❌ TTL bootstrap request failed with status=${TTL_STATUS}"
    FAIL=1
  else
    SIGNED_URL="$(extract_first_signed_url "$TMP_DIR/ttl_payload.json")"
    if [[ -z "$SIGNED_URL" ]]; then
      echo "⚠️ TTL skipped (no media URL in response)"
    else
      if [[ "$SIGNED_URL" == *"/object/sign/"* ]]; then
        echo "✅ Signed URL kind: /object/sign/"
      else
        echo "❌ Signed URL kind is not /object/sign/"
        FAIL=1
      fi

      TTL_NOW=$(curl -s -o /dev/null -w "%{http_code}" "$SIGNED_URL" || true)
      echo "ttl-now=${TTL_NOW}"
      if [[ "$TTL_NOW" != "200" ]]; then
        echo "❌ TTL now expected 200"
        FAIL=1
      fi

      echo "sleeping ${TTL_WAIT_SECONDS}s..."
      sleep "$TTL_WAIT_SECONDS"

      TTL_LATER=$(curl -s -o /dev/null -w "%{http_code}" "$SIGNED_URL" || true)
      echo "ttl-later=${TTL_LATER}"
      if [[ "$TTL_LATER" == "200" ]]; then
        echo "❌ TTL later expected != 200"
        FAIL=1
      else
        echo "✅ TTL expiry observed"
      fi
    fi
  fi
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "✅ Signed media smoke: PASS"
  exit 0
fi

echo "❌ Signed media smoke: FAIL"
exit 1
