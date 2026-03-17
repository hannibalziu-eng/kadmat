# Accept-Offer Contract Deploy Checklist (22-25)

## Scope
Apply and verify these migrations in order:
- `/Users/wew/Desktop/kadmat/backend/migrations/22_add_jobs_accepted_bid_id.sql`
- `/Users/wew/Desktop/kadmat/backend/migrations/23_create_update_user_location_rpc.sql`
- `/Users/wew/Desktop/kadmat/backend/migrations/24_accept_job_offer_atomic_rpc.sql`
- `/Users/wew/Desktop/kadmat/backend/migrations/25_offer_acceptance_on_the_way_and_locks.sql`

Then run audit:
- `/Users/wew/Desktop/kadmat/backend/scripts/audit-accept-offer-contract.sql`

## Preferred (CLI)

```bash
cd /Users/wew/Desktop/kadmat/backend
bash scripts/deploy-accept-offer-contract.sh staging
# then
bash scripts/deploy-accept-offer-contract.sh prod
```

## Fallback (Supabase SQL Editor)
Use this when CLI fails with DNS/host resolution errors.

1. Open SQL Editor in the target project.
2. Run either:
   - single bundle: `/Users/wew/Desktop/kadmat/backend/migrations/22_25_accept_offer_bundle.sql`
   - or files in exact order: `22`, `23`, `24`, `25`.
3. Run:
   - `/Users/wew/Desktop/kadmat/backend/scripts/audit-accept-offer-contract.sql`

## Expected Audit Signals
- `has_jobs_accepted_bid_id = true`
- `has_accept_job_offer_atomic_rpc = true`
- `has_update_user_location_rpc = true`
- `accept_job_offer_atomic` smoke returns `success=false` with a valid `code`
- `update_user_location` notice: exists/executed (or user-not-found notice)

## Release Evidence (save in rollout notes)
- SQL execution success output for `22-25`
- Audit output (or screenshot) showing all checks green
