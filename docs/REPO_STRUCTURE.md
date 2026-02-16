# Kadmat Repository Structure

## Canonical Runtime Paths

### Flutter App
- `lib/main.dart`: app entrypoint.
- `lib/src/core/`: platform-agnostic core (routing, api, services, utils, widgets).
- `lib/src/features/`: feature modules (auth, jobs, technician, wallet, etc).
- `assets/translations/`: localization dictionaries.
- `test/`: unit and feature tests.

### Backend
- `backend/src/`: API runtime code.
- `backend/migrations/`: ordered database migrations (source of truth for rollout).
- `backend/sql/`: curated SQL helpers grouped by purpose:
  - `schema/`
  - `rpc/`
  - `seed/`
  - `archive/` (legacy scripts retained for reference)
- `backend/tests/`: backend tests.

### CI / Governance
- `.github/workflows/`: build, tests, hygiene checks.
- `scripts/repo_hygiene_check.sh`: local + CI repository hygiene gate.
- `scripts/repo_status_report.sh`: quick status distribution report (modified/untracked/deleted by root).

## Structural Rules
1. New DB changes go to `backend/migrations/` first.
2. Keep one active implementation per screen path; avoid parallel legacy copies.
3. Do not keep temporary analysis files at repository root.
4. Any obsolete SQL/docs should move under `backend/sql/archive` or documented `docs/`.
5. Every structural cleanup must end with:
   - `npm test -- --runInBand` in `backend/`
   - `dart analyze`
   - targeted `flutter test`
