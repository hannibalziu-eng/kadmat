# get_nearby_jobs RPC Rollout Runbook

## Scope
- RPC: `public.get_nearby_jobs(double precision, double precision, integer, integer)`
- Audit RPC: `public.audit_get_nearby_jobs_rpc()`
- Contract table: `public.rpc_contract_versions`

## Canonical source
- `/Users/wew/Desktop/kadmat/backend/migrations/18_finalize_get_nearby_jobs_rpc.sql`
- `/Users/wew/Desktop/kadmat/backend/migrations/19_add_get_nearby_jobs_rpc_audit.sql`
- `/Users/wew/Desktop/kadmat/backend/migrations/20_lock_get_nearby_jobs_contract.sql`

## Preconditions
- PostGIS is enabled in the database.
- Required secrets are configured for CI:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Service role access is available for manual checks.

## Rollout steps (production)
1. Apply migrations in strict order: `18 -> 19 -> 20`.
2. Run local/CI audit script:
   - `cd /Users/wew/Desktop/kadmat/backend`
   - `npm run audit:rpc`
3. Run SQL verification checklist:
   - `/Users/wew/Desktop/kadmat/backend/sql/rpc/check_get_nearby_jobs_contract.sql`
4. Confirm `audit_report.ok = true`.
5. Confirm technicians can see new `pending/searching` requests only.

## Incident triage
- Symptom: technician requests page shows stale or canceled jobs.
  - Check `audit_get_nearby_jobs_rpc()` first.
  - If `ok = false`, run restore SQL immediately.
  - If `ok = true`, inspect app-side cache/realtime subscriptions and status update path.

- Symptom: no jobs reach technicians.
  - Verify job rows include valid `lat/lng`.
  - Verify status is one of: `pending`, `searching`, `no_technician_found`.
  - Verify `created_at` is inside visibility windows (24h / 2h).
  - Verify distance from technician coordinates is within requested radius.

## Emergency restore (rollback-to-known-good)
1. Open Supabase SQL editor.
2. Execute:
   - `/Users/wew/Desktop/kadmat/backend/sql/rpc/restore_get_nearby_jobs_contract.sql`
3. Verify output:
   - `audit_after_restore.ok = true`
4. Re-run backend check:
   - `npm run audit:rpc`

## Release gate (must pass)
- `audit_get_nearby_jobs_rpc().ok = true`
- `npm run audit:rpc` exits with code `0`
- CI workflow `/Users/wew/Desktop/kadmat/.github/workflows/rpc_audit.yml` is green
