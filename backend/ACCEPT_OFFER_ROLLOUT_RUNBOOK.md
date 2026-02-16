# Accept Offer Rollout Runbook

## Scope
Close accept-offer failures in production by enforcing the DB contract used by:
- `POST /api/jobs/:id/accept-offer`
- `POST /api/technician/location`

This runbook covers migrations `22 -> 23 -> 24 -> 25`, verification, and smoke checks.

## Prerequisites
- Production DB backup snapshot is available.
- Backend release contains latest `jobService` fallback logic.
- Environment variables are set for audit scripts:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`

## 1) Apply Migrations (Strict Order)
Run in Supabase SQL editor, one file at a time:

1. `backend/migrations/22_add_jobs_accepted_bid_id.sql`
2. `backend/migrations/23_create_update_user_location_rpc.sql`
3. `backend/migrations/24_accept_job_offer_atomic_rpc.sql`
4. `backend/migrations/25_offer_acceptance_on_the_way_and_locks.sql`

Do not skip order.

## 2) Contract Verification
From backend directory:

```bash
npm run audit:accept-offer-contract
npm run audit:rpc
```

Expected:
- Both commands exit with code `0`.
- No `PGRST202` missing function errors.

## 3) Functional Smoke (Manual)
Run with two accounts (customer + technician):

1. Customer creates a new job.
2. Technician sees the request and submits offer.
3. Customer accepts offer.
4. Confirm job status becomes `on_the_way` (legacy env may show `in_progress` once).
5. Technician sends progress `arrived`.
6. Technician sends progress `start_work` and status becomes `in_progress`.
7. Verify customer and technician are both locked from starting parallel jobs while status is:
   - `on_the_way`
   - `arrived`
   - `in_progress`
   - `pending_confirm`

## 4) Post-Deploy Monitoring (30-60 min)
Track logs and alert immediately on:
- `Accept Offer Error` with `ACCEPT_FAILED`
- `PGRST202` for `accept_job_offer_atomic` or `update_user_location`
- repeated `409` for same job without status progression

## 5) Rollback Strategy
If release must be rolled back:
- Keep DB migrations (non-destructive, forward-compatible).
- Roll back only backend app version.
- Re-run `npm run audit:accept-offer-contract` after rollback to confirm DB contract still healthy.
