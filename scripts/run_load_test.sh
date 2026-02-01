#!/usr/bin/env bash
set -euo pipefail

# Basic load test using k6 if available, fallback to Artillery if installed
URL="http://localhost:3000/health"

if command -v k6 >/dev/null 2>&1; then
  echo "Running k6 load test on $URL"
  k6 run - < <(cat <<'SCRIPT'
import http from 'k6/http';
import { check, sleep } from 'k6';
export let options = { vus: 50, duration: '30s' };
export default function () {
  const res = http.get('$URL');
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(0.5);
}
SCRIPT
)
else
  if command -v artillery >/dev/null 2>&1; then
  echo "Running Artillery load test on $URL"
  artillery gun --target 50 http.get $URL || true
else
  echo "No load testing tool found (k6 or artillery). Install one to run this script.";
fi
