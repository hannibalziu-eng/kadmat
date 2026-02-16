# RPC Audit: `get_nearby_jobs`

## Source of truth
- `backend/migrations/18_finalize_get_nearby_jobs_rpc.sql`
- `backend/migrations/20_lock_get_nearby_jobs_contract.sql` (re-locks canonical hash)

## Contract guard migration
- `backend/migrations/19_add_get_nearby_jobs_rpc_audit.sql`

This migration stores an expected hash in `public.rpc_contract_versions` and creates:
- `public.audit_get_nearby_jobs_rpc()`

## Operations runbook
- `backend/RPC_ROLLOUT_RUNBOOK.md`

## SQL helper scripts
- Verify live DB: `backend/sql/rpc/check_get_nearby_jobs_contract.sql`
- Emergency restore: `backend/sql/rpc/restore_get_nearby_jobs_contract.sql`

## Local execution
Run from `backend/`:

```bash
npm run audit:rpc
```

Required environment variables:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

## CI execution
Workflow:
- `.github/workflows/rpc_audit.yml`

It runs on:
- `push` to `main` (when RPC-related files change)
- hourly schedule
- manual dispatch
