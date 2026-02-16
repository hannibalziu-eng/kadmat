# Cleanup Classification Snapshot

## Current Status (working tree)
- Modified: 111
- Untracked: 75
- Deleted: 71

## High-Level Distribution

### `lib/`
- Large active refactor footprint (routing, job flow, technician flow, services).
- Includes both modified existing files and new module folders.
- Action: keep as active workstream; validate with `dart analyze` + targeted tests per batch.

### `backend/`
- Active API/service changes plus migration additions.
- Legacy root SQL files already removed from root and normalized to `backend/sql`.
- Action: keep migrations + tests; archive/retain legacy SQL only under `backend/sql/archive`.

### `docs/`
- New operational docs added (flow spec, hardening, release gates, cleanup docs).
- Action: keep under `docs/` and avoid root-level documentation sprawl.

### `test/`
- New contract and routing tests introduced.
- Action: keep and require passing before merge.

## Cleanup Batches (recommended commit slicing)
1. Hygiene/structure:
   - `.gitignore`
   - `.github/workflows/repo_hygiene.yml`
   - `scripts/repo_hygiene_check.sh`
   - `docs/REPO_TREE_CLEANUP_PLAN.md`
   - `docs/REPO_STRUCTURE.md`
   - `docs/CLEANUP_CLASSIFICATION.md`
2. Backend runtime + migrations.
3. Flutter routing + job lifecycle.
4. Supporting tests and docs updates.

## Validation Gates
- Backend: `npm test -- --runInBand` (in `backend/`)
- Flutter static: `dart analyze`
- Flutter focused tests:
  - `flutter test test/unit/job_repository_test.dart test/unit/job_flow_redirects_test.dart`
