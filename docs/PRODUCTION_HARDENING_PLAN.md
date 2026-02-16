# Kadmat Production Hardening Plan

Date: 2026-02-12
Scope: Mobile app + backend critical job flow stability.

## 1) Objective

Ship a release-safe build with protected job lifecycle flow, clear failure handling, and regression gates.

## 2) Priorities

P0:
- Protect critical flow state transitions (`pending -> accepted -> price_pending -> in_progress -> pending_confirm -> completed -> rated`).
- Guarantee consistent backend error codes and frontend mapping for all job-flow endpoints.
- Block release unless static analysis and tests pass.

P1:
- Add integration coverage for offer-based flow (`submit-offer -> accept-offer`).
- Add observability fields (request ID, actor ID, job ID) to backend logs.
- Add smoke checks for push/notification fallback behavior.

P2:
- Performance checks for nearby jobs/realtime updates under burst traffic.
- Retry/backoff tuning for offline queue replay.

## 3) Execution Plan

Phase A (2026-02-12 to 2026-02-13):
- Expand backend service tests for critical transitions and invalid states.
- Add failure-path tests for conflict and unauthorized actions.
- Exit criteria: all critical transitions covered by automated tests.

Phase B (2026-02-13 to 2026-02-14):
- Add Flutter integration smoke scenarios for customer and technician primary paths.
- Validate UI routing for each backend status.
- Exit criteria: UI route assertions for accepted, in-progress, pending-confirm, completed.

Phase C (2026-02-14 to 2026-02-15):
- Standardize API error response contract and document code-to-UX mapping.
- Add structured logs for job operations.
- Exit criteria: reproducible logs and deterministic error rendering in app.

## 4) Quality Gates (Release Blocking)

- `dart analyze` returns zero issues.
- `flutter test` passes.
- `npm test -- --runInBand` passes.
- New critical-flow tests pass in CI.

## 5) Deliverables

- Backend flow regression tests under `/backend/tests`.
- Updated flow-risk checklist in this plan.
- CI checklist for release manager.
