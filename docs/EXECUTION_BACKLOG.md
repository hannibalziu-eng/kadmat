# EXECUTION BACKLOG

## Legend
- `TODO`
- `IN_PROGRESS`
- `BLOCKED`
- `DONE`

## P0 - Must Fix Before Release

- [ ] `IN_PROGRESS` Fix Accept Offer server-side assignment stability
  - Files:
    - `backend/src/services/jobService.js`
    - `backend/src/controllers/jobController.js`
  - Target:
    - no `Failed to assign job` for valid offer acceptance.

- [ ] `TODO` Apply DB migration for accepted offer lock column
  - File:
    - `backend/migrations/22_add_jobs_accepted_bid_id.sql`
  - Owner: Production DB execution
  - Evidence required:
    - SQL success output + column existence check.

- [ ] `TODO` Fix missing RPC/function for location updates
  - Symptom:
    - `PGRST202` missing `public.update_user_location(p_lat, p_lng, p_user_id)`
  - Target:
    - no location queue growth due to missing function.

- [ ] `TODO` Reduce aggressive polling duplication
  - Symptom:
    - كثرة `GET /api/jobs/:id` و `GET /api/jobs/my-jobs`.
  - Target:
    - polling/realtime balanced, no overload.

## P1 - UX Hardening

- [ ] `TODO` Remove repeated technical warnings from user-facing logs where possible.
- [ ] `TODO` Unify technician app bar and request-first layout as approved.
- [ ] `TODO` Improve error toasts for actionable Arabic messages only.

## P2 - Release Readiness

- [ ] `TODO` Staging smoke for full flow:
  - create request -> submit offer -> accept offer -> in_progress.
- [ ] `TODO` Verify cancel propagation latency:
  - customer cancel -> technician list removal in <= 10s.

## Completed Recently

- [x] `DONE` Accept-offer input validation and legacy key support.
- [x] `DONE` UI-level UUID validation for `offerId` before sending.
- [x] `DONE` Route and profile navigation hardening.
- [x] `DONE` Backend tests + Flutter analyze/tests passing after fixes.
