# EXECUTION BACKLOG

## Legend
- `TODO`
- `IN_PROGRESS`
- `BLOCKED`
- `DONE`

## P0 - Must Fix Before Release

- [x] `DONE` Fix Accept Offer server-side assignment stability
  - Files:
    - `backend/src/services/jobService.js`
    - `backend/src/controllers/jobController.js`
  - Target:
    - no `Failed to assign job` for valid offer acceptance.

- [ ] `TODO` Apply DB migration stack for accept-offer and locks (prod)
  - File:
    - `backend/migrations/22_add_jobs_accepted_bid_id.sql`
    - `backend/migrations/23_create_update_user_location_rpc.sql`
    - `backend/migrations/24_accept_job_offer_atomic_rpc.sql`
    - `backend/migrations/25_offer_acceptance_on_the_way_and_locks.sql`
  - Owner: Production DB execution
  - Evidence required:
    - SQL success output + `npm run audit:accept-offer-contract`.

- [x] `DONE` Fix missing RPC/function for location updates (code + migration ready)
  - Symptom:
    - `PGRST202` missing `public.update_user_location(p_lat, p_lng, p_user_id)`
  - Target:
    - no location queue growth due to missing function after prod migration apply.

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
