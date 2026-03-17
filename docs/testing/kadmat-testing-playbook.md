# Kadmat Testing Playbook

This playbook matches the current Kadmat stack:
- Supabase for auth/data/storage
- Firebase for messaging, crash reporting, and performance

## 1) Local smoke test flow

```bash
cd /Users/wew/Desktop/kadmat
flutter pub get
flutter test test/unit test/core test/features
flutter test integration_test/comprehensive_test.dart --dart-define=KADMAT_E2E_ENABLED=false
```

## 2) Build instrumentation APKs

```bash
cd /Users/wew/Desktop/kadmat/android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

./gradlew :app:clean :app:assembleDebug :app:assembleDebugAndroidTest \
  -Ptarget=/Users/wew/Desktop/kadmat/integration_test/comprehensive_test.dart

mkdir -p /Users/wew/Desktop/kadmat/tmp/apks
cp -f /Users/wew/Desktop/kadmat/build/app/outputs/apk/debug/app-debug.apk /Users/wew/Desktop/kadmat/tmp/apks/
cp -f /Users/wew/Desktop/kadmat/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk /Users/wew/Desktop/kadmat/tmp/apks/
```

## 3) Run Firebase Test Lab

```bash
cd /Users/wew/Desktop/kadmat
PROJECT_ID=lykadmat ./scripts/run_firebase_testlab.sh
```

## 4) Optional live E2E runs

By default journey tests are guarded and skipped.

Enable live E2E against a dedicated test Supabase project:

```bash
cd /Users/wew/Desktop/kadmat
flutter test integration_test \
  --dart-define=KADMAT_E2E_ENABLED=true \
  --dart-define=KADMAT_TEST_SUPABASE_URL=https://YOUR_TEST_PROJECT.supabase.co \
  --dart-define=KADMAT_TEST_SUPABASE_ANON_KEY=YOUR_TEST_ANON_KEY
```

Important:
- Never use production Supabase credentials for automated destructive E2E tests.
- Keep fixture users/data isolated from production.

