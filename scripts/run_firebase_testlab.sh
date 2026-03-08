#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-lykadmat}"
APP_APK="${APP_APK:-/Users/wew/Desktop/kadmat/tmp/apks/app-debug.apk}"
TEST_APK="${TEST_APK:-/Users/wew/Desktop/kadmat/tmp/apks/app-debug-androidTest.apk}"

if [[ ! -f "$APP_APK" ]]; then
  echo "Missing app APK: $APP_APK"
  exit 1
fi

if [[ ! -f "$TEST_APK" ]]; then
  echo "Missing test APK: $TEST_APK"
  exit 1
fi

gcloud firebase test android run \
  --project="$PROJECT_ID" \
  --type=instrumentation \
  --app="$APP_APK" \
  --test="$TEST_APK" \
  --device=model=redfin,version=30,locale=en,orientation=portrait \
  --device=model=redfin,version=31,locale=en,orientation=portrait \
  --device=model=redfin,version=34,locale=en,orientation=portrait \
  --timeout=15m \
  --num-flaky-test-attempts=1

