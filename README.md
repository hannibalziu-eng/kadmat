# Kadmat

Kadmat is a Flutter + Node.js/Supabase service marketplace platform.

## Repository Layout
- `lib/`: Flutter application code.
- `backend/`: Node.js backend API and schedulers.
- `backend/migrations/`: ordered production migrations.
- `backend/sql/`: curated SQL helpers and archived legacy scripts.
- `test/` and `backend/tests/`: automated tests.
- `docs/`: technical plans, specs, and operational guides.

## Local Run

### Flutter app
```bash
flutter pub get
flutter run
```

### Backend API
```bash
cd backend
npm install
npm start
```

## Validation Gates

### Backend
```bash
cd backend
npm test -- --runInBand
```

### Flutter
```bash
dart analyze
flutter test test/unit/job_repository_test.dart test/unit/job_flow_redirects_test.dart
```

## Repository Hygiene

### Check hygiene
```bash
./scripts/repo_hygiene_check.sh
```

### Clean local artifacts
```bash
./scripts/clean_local_artifacts.sh
```

## Structural Governance
- Structure rules: `docs/REPO_STRUCTURE.md`
- Cleanup plan: `docs/REPO_TREE_CLEANUP_PLAN.md`
- Cleanup classification snapshot: `docs/CLEANUP_CLASSIFICATION.md`
