#!/usr/bin/env bash
set -euo pipefail

API_BASE="${API_BASE:-http://127.0.0.1:3000/api}"
CUSTOMER_TOKEN="${CUSTOMER_TOKEN:-}"
TECHNICIAN_TOKEN="${TECHNICIAN_TOKEN:-}"
SERVICE_ID="${SERVICE_ID:-}"
LAT="${LAT:-24.7136}"
LNG="${LNG:-46.6753}"
RADIUS="${RADIUS:-5000}"
INITIAL_PRICE="${INITIAL_PRICE:-95}"
MAX_CANCEL_LATENCY_SECONDS="${MAX_CANCEL_LATENCY_SECONDS:-10}"
MAX_DISCOVERY_SECONDS="${MAX_DISCOVERY_SECONDS:-20}"

if [[ -z "$CUSTOMER_TOKEN" || -z "$TECHNICIAN_TOKEN" ]]; then
  echo "❌ CUSTOMER_TOKEN and TECHNICIAN_TOKEN are required"
  echo "Usage example:"
  echo "API_BASE=https://api.example.com/api CUSTOMER_TOKEN=... TECHNICIAN_TOKEN=... bash scripts/smoke-cancel-latency.sh"
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

json_contains_job() {
  local file="$1"
  local job_id="$2"
  python3 - "$file" "$job_id" <<'PY'
import json
import sys

file_path = sys.argv[1]
job_id = sys.argv[2]

try:
    with open(file_path, 'r', encoding='utf-8') as fh:
        payload = json.load(fh)
except Exception:
    print("false")
    sys.exit(0)

candidate_lists = []
for path in ("data.jobs", "jobs", "data"):
    cur = payload
    ok = True
    for seg in path.split("."):
        if isinstance(cur, dict):
            cur = cur.get(seg)
        else:
            ok = False
            break
    if ok and isinstance(cur, list):
        candidate_lists.append(cur)

for items in candidate_lists:
    for row in items:
        if isinstance(row, dict) and str(row.get("id", "")).strip() == job_id:
            print("true")
            sys.exit(0)

print("false")
PY
}

api_request() {
  local method="$1"
  local url="$2"
  local token="${3:-}"
  local data="${4:-}"
  local out_file
  out_file="$(make_tmp)"

  local code
  if [[ -n "$data" ]]; then
    if [[ -n "$token" ]]; then
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

echo "🔎 Smoke cancel propagation latency"
echo "   API_BASE=$API_BASE"
echo "   SLA=${MAX_CANCEL_LATENCY_SECONDS}s"

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
  "address_text": "Riyadh Cancel Smoke Address",
  "description": "cancel latency smoke",
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

nearby_url="$API_BASE/jobs/nearby?lat=$LAT&lng=$LNG&radius=$RADIUS&limit=50"

echo "⏳ Waiting for job to appear in technician nearby feed..."
appeared="false"
for ((s=0; s<=MAX_DISCOVERY_SECONDS; s++)); do
  response="$(api_request "GET" "$nearby_url" "$TECHNICIAN_TOKEN")"
  code="${response%%|*}"
  body_file="${response##*|}"
  if assert_status "$code" 200; then
    if [[ "$(json_contains_job "$body_file" "$job_id")" == "true" ]]; then
      appeared="true"
      echo "✅ Job became visible to technician after ${s}s"
      break
    fi
  fi
  sleep 1
done

if [[ "$appeared" != "true" ]]; then
  echo "❌ Job did not appear in nearby feed within ${MAX_DISCOVERY_SECONDS}s"
  exit 1
fi

cancel_payload='{"reason":"smoke_cancel_latency"}'
response="$(api_request "POST" "$API_BASE/jobs/$job_id/cancel" "$CUSTOMER_TOKEN" "$cancel_payload")"
code="${response%%|*}"
body_file="${response##*|}"
if ! assert_status "$code" 200; then
  echo "❌ Cancel job failed (status=$code)"
  cat "$body_file"
  exit 1
fi
echo "✅ Cancel requested for job_id=$job_id"

start_ts="$(date +%s)"
removed="false"
for ((s=0; s<=MAX_CANCEL_LATENCY_SECONDS; s++)); do
  response="$(api_request "GET" "$nearby_url" "$TECHNICIAN_TOKEN")"
  code="${response%%|*}"
  body_file="${response##*|}"
  if assert_status "$code" 200; then
    if [[ "$(json_contains_job "$body_file" "$job_id")" != "true" ]]; then
      removed="true"
      break
    fi
  fi
  sleep 1
done

end_ts="$(date +%s)"
latency=$((end_ts - start_ts))

if [[ "$removed" != "true" ]]; then
  echo "❌ Cancel propagation SLA failed. Job still visible after ${MAX_CANCEL_LATENCY_SECONDS}s"
  exit 1
fi

echo "✅ Cancel propagation PASS (latency=${latency}s, SLA=${MAX_CANCEL_LATENCY_SECONDS}s)"
