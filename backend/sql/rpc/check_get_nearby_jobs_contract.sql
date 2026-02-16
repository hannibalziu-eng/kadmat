-- =============================================
-- PRODUCTION CHECKLIST QUERY: get_nearby_jobs
-- Run this in Supabase SQL editor to verify live DB contract.
-- =============================================

SELECT NOW() AS checked_at_utc;

SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS signature_args,
  pg_get_function_result(p.oid) AS returns_type,
  p.prosecdef AS is_security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'get_nearby_jobs'
ORDER BY p.oid;

SELECT
  rpc_name,
  signature,
  expected_hash,
  updated_at
FROM public.rpc_contract_versions
WHERE rpc_name = 'get_nearby_jobs';

SELECT public.audit_get_nearby_jobs_rpc() AS audit_report;

-- Optional smoke test (replace coordinates with your city if needed).
SELECT COUNT(*) AS visible_jobs
FROM public.get_nearby_jobs(24.7136, 46.6753, 3000, 20);
