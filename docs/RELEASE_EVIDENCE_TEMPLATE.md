# Release Evidence Template (Accept-Offer Stabilization)

## 1) Release Metadata
- Date:
- Environment: `staging` / `production`
- Backend commit SHA:
- Mobile commit SHA:
- Operator:

## 2) Database Migration Evidence
- Applied migrations (ordered):
  - `22_add_jobs_accepted_bid_id.sql`
  - `23_create_update_user_location_rpc.sql`
  - `24_accept_job_offer_atomic_rpc.sql`
  - `25_offer_acceptance_on_the_way_and_locks.sql`
- SQL editor execution status:
  - [ ] 22 PASS
  - [ ] 23 PASS
  - [ ] 24 PASS
  - [ ] 25 PASS
- Notes/errors:

## 3) Contract Audit Evidence
- `npm run audit:accept-offer-contract`:
  - Exit code:
  - Summary:
- `npm run audit:rpc`:
  - Exit code:
  - Summary:

## 4) Functional Smoke Evidence
- Scenario: Create request -> Submit offer -> Accept offer -> `on_the_way` -> `arrived` -> `in_progress`
  - [ ] PASS / [ ] FAIL
- Idempotent accept-offer (same offer repeated)
  - [ ] PASS / [ ] FAIL
- ACTIVE_JOB_LOCKED behavior
  - [ ] PASS / [ ] FAIL
- Cancel propagation SLA (<=10s fallback)
  - [ ] PASS / [ ] FAIL

## 5) Monitoring Window Evidence (60 min)
- Start time:
- End time:
- Metrics:
  - Accept-offer success rate (%):
  - Accept-offer 409 repeated conflicts (%):
  - Accept-offer 500 rate (%):
  - Count of `PGRST202` (accept/location):
  - Count of `ACCEPT_FAILED`:
- Outcome:
  - [ ] Release stable
  - [ ] Needs rollback / hotfix

## 6) Decision Log
- Go / No-Go decision:
- Decision maker:
- Follow-up actions:
