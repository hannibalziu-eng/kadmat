# Kadmat Repository Tree Cleanup Plan

## Goal
Create a clean, predictable repository tree with:
- clear ownership of runtime code vs archived assets,
- no duplicate accidental copies,
- no local machine artifacts in version control,
- reproducible validation gates before release.

## Principles
1. Safety first: no destructive cleanup without clear category and rollback path.
2. Runtime-first: production code and migrations have top priority.
3. Archive, do not lose: historical SQL/docs move to structured archive paths.
4. Enforce hygiene by policy (`.gitignore`, structure rules, CI checks).

## Target Structure
- `lib/`, `backend/src/`, `backend/migrations/`, `test/`, `backend/tests/`: active code.
- `backend/sql/schema|rpc|seed|archive`: SQL source-of-truth and legacy archive.
- `docs/`: active technical documentation only.
- No root-level temporary analysis files.

## Execution Phases

### Phase 1: Inventory and Classification
- Collect all `git status` items and classify into:
  - Active feature changes,
  - Legacy deletes,
  - Temporary/local artifacts,
  - Structural additions (new modules/tests/docs).
- Output: categorized cleanup map.

### Phase 2: Low-Risk Cleanup (Immediate)
- Remove known local artifacts and duplicate empty folders.
- Add ignore rules for recurrent noise (`analysis_output.txt`, `memory/`, accidental `... 2` copies).
- Output: reduced tree noise and stable local status.

### Phase 3: Structural Normalization
- Keep one canonical place for SQL (migrations + `backend/sql`).
- Keep one canonical docs set under `docs/`.
- Remove or archive stale files outside canonical paths.
- Output: coherent tree that reflects current architecture.

### Phase 4: Integrity Validation
- Backend: `npm test -- --runInBand`
- Flutter static checks: `dart analyze`
- Flutter flow tests: targeted unit tests for job lifecycle and routing.
- Output: cleanup proven not to break runtime behavior.

### Phase 5: Release Baseline
- Produce final cleanup report with:
  - kept/removed/moved summary,
  - risk notes,
  - remaining technical debt queue.

## Acceptance Criteria
- No accidental duplicate directories/files (`... 2`) in working tree.
- No local machine artifacts tracked.
- Active flow tests pass (backend + Flutter).
- Repository layout follows target structure with documented conventions.

## Current Execution Status
- Phase 1 complete: inventory and classification done.
- Phase 2 complete: local artifacts removed, duplicate `... 2` folders removed, ignore rules hardened.
- Hygiene guard added: `scripts/repo_hygiene_check.sh`.
- Phase 3 in progress: legacy duplicate screens pruned and canonical structure documented in `docs/REPO_STRUCTURE.md`.
- Local cleanup automation added: `scripts/clean_local_artifacts.sh`.
- Commit slicing guide added: `docs/COMMIT_BATCHES.md`.
- Status telemetry helper added: `scripts/repo_status_report.sh`.
