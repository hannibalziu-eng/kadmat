# Post-Deploy Monitoring Checklist (Accept-Offer)

## Window
- Required minimum monitoring window: **60 minutes** after production rollout.
- Recommended follow-up review: **after 24 hours**.

## A) Live Log Signals
- [ ] No `PGRST202` for `accept_job_offer_atomic`.
- [ ] No `PGRST202` for `update_user_location`.
- [ ] No burst of `Accept Offer Error` with code `ACCEPT_FAILED`.
- [ ] No repeated `409 INVALID_STATUS_TRANSITION` for the same `jobId` without progression.

## B) Functional Signals
- [ ] New requests are visible to technicians.
- [ ] Accepted offer transitions to `on_the_way` (or legacy `in_progress` once during compatibility).
- [ ] Technician progress endpoints work: `arrived`, `start_work`.
- [ ] Customer/technician locking is enforced for active states.

## C) UX Signals
- [ ] Customer does not see raw technical stack traces.
- [ ] Race condition on accept-offer shows a friendly message and redirects to latest state.
- [ ] No repetitive blocking toasts for normal transition races.

## D) Rollback Triggers
- [ ] Accept-offer `500` rate exceeds 1%.
- [ ] Core flow broken in smoke (cannot reach in-progress path).
- [ ] Contract audits fail after deploy.

## E) Rollback Scope
- Roll back backend app version only.
- Keep applied DB migrations (forward-compatible and non-destructive).
- Re-run:
  - `npm run audit:accept-offer-contract`
  - `npm run audit:rpc`
