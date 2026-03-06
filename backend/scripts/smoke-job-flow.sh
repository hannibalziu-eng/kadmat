#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://127.0.0.1:3000/api}"
CUSTOMER_TOKEN="${CUSTOMER_TOKEN:-}"
TECHNICIAN_TOKEN="${TECHNICIAN_TOKEN:-}"
SERVICE_ID="${SERVICE_ID:-}"
LAT="${LAT:-24.7136}"
LNG="${LNG:-46.6753}"
ADDRESS_TEXT="${ADDRESS_TEXT:-Riyadh Smoke Address}"
INITIAL_PRICE="${INITIAL_PRICE:-120}"
OFFER_PRICE="${OFFER_PRICE:-150}"

if [[ -z "$CUSTOMER_TOKEN" || -z "$TECHNICIAN_TOKEN" ]]; then
  echo "❌ CUSTOMER_TOKEN and TECHNICIAN_TOKEN are required"
  echo "Usage example:"
  echo "API_BASE=https://api.example.com/api CUSTOMER_TOKEN=... TECHNICIAN_TOKEN=... bash scripts/smoke-job-flow.sh"
  exit 1
fi

tmp_files=()
cleanup() {
  local f
  for f in "${tmp_files[@]-}"; do
    if [[ -n "$f" && -f "$f" ]]; then
      rm -f "$f"
    fi
  done
  return 0
}
trap cleanup EXIT

make_tmp() {
  local f
  f="$(mktemp)"
  tmp_files+=("$f")
  printf '%s' "$f"
}

json_pick() {
  local file="$1"
  shift
  python3 - "$file" "$@" <<'PY'
import json
import sys

file_path = sys.argv[1]
paths = sys.argv[2:]

try:
    with open(file_path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    print("")
    sys.exit(0)

def get_path(obj, path):
    cur = obj
    for segment in path.split("."):
        if isinstance(cur, dict):
            cur = cur.get(segment)
        elif isinstance(cur, list):
            try:
                idx = int(segment)
            except ValueError:
                return None
            if idx < 0 or idx >= len(cur):
                return None
            cur = cur[idx]
        else:
            return None
    return cur

for path in paths:
    value = get_path(data, path)
    if value is None:
        continue
    if isinstance(value, str):
        value = value.strip()
    if value in ("", [], {}):
        continue
    if isinstance(value, (dict, list)):
        print(json.dumps(value))
    else:
        print(value)
    sys.exit(0)

print("")
PY
}

api_request() {
  local method="$1"
  local url="$2"
  local token="${3:-}"
  local data="${4:-}"
  local idem_key="${5:-}"
  local out_file
  out_file="$(make_tmp)"

  local code
  if [[ -n "$data" ]]; then
    if [[ -n "$token" && -n "$idem_key" ]]; then
      code="$(curl -sS -m 30 -o "$out_file" -w "%{http_code}" \
        -X "$method" "$url" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "Idempotency-Key: $idem_key" \
        --data "$data")"
    elif [[ -n "$token" ]]; then
      code="$(curl -sS -m 30 -o "$out_file" -w "%{http_code}" \
        -X "$method" "$url" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        --data "$data")"
    else
      code="$(curl -sS -m 30 -o "$out_file" -w "%{http_code}" \
        -X "$method" "$url" \
        -H "Content-Type: application/json" \
        --data "$data")"
    fi
  else
    if [[ -n "$token" ]]; then
      code="$(curl -sS -m 30 -o "$out_file" -w "%{http_code}" \
        -X "$method" "$url" \
        -H "Authorization: Bearer $token")"
    else
      code="$(curl -sS -m 30 -o "$out_file" -w "%{http_code}" \
        -X "$method" "$url")"
    fi
  fi

  printf '%s|%s' "$code" "$out_file"
}

assert_status() {
  local code="$1"
  shift
  local valid=("$@")
  for v in "${valid[@]}"; do
    if [[ "$code" == "$v" ]]; then
      return 0
    fi
  done
  return 1
}

echo "🔎 Smoke job flow"
echo "   API_BASE=$API_BASE"

if [[ -z "$SERVICE_ID" ]]; then
  response="$(api_request "GET" "$API_BASE/services")"
  code="${response%%|*}"
  body_file="${response##*|}"
  if ! assert_status "$code" 200; then
    echo "❌ Failed to fetch services (status=$code)"
    cat "$body_file"
    exit 1
  fi
  SERVICE_ID="$(json_pick "$body_file" "data.services.0.id" "services.0.id" "data.0.id" "0.id")"
fi

if [[ -z "$SERVICE_ID" ]]; then
  echo "❌ SERVICE_ID missing and auto-resolve failed"
  exit 1
fi

echo "ℹ️ Using service_id=$SERVICE_ID"

status_payload='{"isOnline":true}'
response="$(api_request "POST" "$API_BASE/technician/status" "$TECHNICIAN_TOKEN" "$status_payload")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200; then
  echo "❌ Technician status update failed (status=$code)"
  cat "$body_file"
  exit 1
fi

location_payload="{\"latitude\":$LAT,\"longitude\":$LNG}"
response="$(api_request "POST" "$API_BASE/technician/location" "$TECHNICIAN_TOKEN" "$location_payload")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200; then
  echo "❌ Technician location update failed (status=$code)"
  cat "$body_file"
  exit 1
fi

create_payload="$(cat <<JSON
{
  "service_id": "$SERVICE_ID",
  "lat": $LAT,
  "lng": $LNG,
  "address_text": "$ADDRESS_TEXT",
  "description": "smoke job flow",
  "initial_price": $INITIAL_PRICE
}
JSON
)"
response="$(api_request "POST" "$API_BASE/jobs" "$CUSTOMER_TOKEN" "$create_payload")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200 201; then
  echo "❌ Create job failed (status=$code)"
  cat "$body_file"
  exit 1
fi

job_id="$(json_pick "$body_file" "data.id" "data.job.id" "job.id" "id")"
if [[ -z "$job_id" ]]; then
  echo "❌ Could not extract job_id from create response"
  cat "$body_file"
  exit 1
fi
echo "✅ Created job_id=$job_id"

submit_payload="{\"price\":$OFFER_PRICE}"
response="$(api_request "POST" "$API_BASE/jobs/$job_id/submit-offer" "$TECHNICIAN_TOKEN" "$submit_payload")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200 201; then
  echo "❌ Submit offer failed (status=$code)"
  cat "$body_file"
  exit 1
fi

offer_id="$(json_pick "$body_file" "data.id" "data.offer_id" "data.offer.id" "offer.id" "id")"
if [[ -z "$offer_id" ]]; then
  echo "❌ Could not extract offer_id from submit-offer response"
  cat "$body_file"
  exit 1
fi
echo "✅ Submitted offer_id=$offer_id"

accept_payload="{\"offerId\":\"$offer_id\"}"
accept_idem_key="smoke-accept-$job_id-$(date +%s)"
response="$(api_request "POST" "$API_BASE/jobs/$job_id/accept-offer" "$CUSTOMER_TOKEN" "$accept_payload" "$accept_idem_key")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200; then
  echo "❌ Accept offer failed (status=$code)"
  cat "$body_file"
  exit 1
fi
accept_status="$(json_pick "$body_file" "data.status" "status")"
echo "✅ Accepted offer status=${accept_status:-unknown}"

arrived_payload='{"progress":"arrived"}'
response="$(api_request "POST" "$API_BASE/jobs/$job_id/technician-progress" "$TECHNICIAN_TOKEN" "$arrived_payload")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200; then
  echo "❌ Arrived progress failed (status=$code)"
  cat "$body_file"
  exit 1
fi

start_payload='{"progress":"start_work"}'
response="$(api_request "POST" "$API_BASE/jobs/$job_id/technician-progress" "$TECHNICIAN_TOKEN" "$start_payload")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200; then
  echo "❌ Start-work progress failed (status=$code)"
  cat "$body_file"
  exit 1
fi

response="$(api_request "GET" "$API_BASE/jobs/$job_id" "$CUSTOMER_TOKEN")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200; then
  echo "❌ Get job failed (status=$code)"
  cat "$body_file"
  exit 1
fi

final_status="$(json_pick "$body_file" "data.status" "status")"
if [[ "$final_status" != "in_progress" ]]; then
  echo "❌ Final status mismatch (expected=in_progress, actual=${final_status:-<empty>})"
  cat "$body_file"
  exit 1
fi

echo "✅ Smoke job flow PASS (job_id=$job_id, offer_id=$offer_id, status=$final_status)"
