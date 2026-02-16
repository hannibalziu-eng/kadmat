-- =============================================
-- RPC CONTRACT AUDIT: get_nearby_jobs
-- Keeps an expected hash in DB and exposes an audit RPC
-- NOTE: migration 20 re-locks expected hash from canonical source.
-- =============================================

CREATE TABLE IF NOT EXISTS public.rpc_contract_versions (
  rpc_name TEXT PRIMARY KEY,
  signature TEXT NOT NULL,
  expected_hash TEXT NOT NULL,
  definition_snapshot TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

WITH current_def AS (
  SELECT
    'get_nearby_jobs'::text AS rpc_name,
    'public.get_nearby_jobs(double precision, double precision, integer, integer)'::regprocedure::text AS signature,
    pg_get_functiondef(
      'public.get_nearby_jobs(double precision, double precision, integer, integer)'::regprocedure
    ) AS definition
),
normalized AS (
  SELECT
    rpc_name,
    signature,
    definition,
    regexp_replace(definition, '\s+', ' ', 'g') AS normalized_definition
  FROM current_def
)
INSERT INTO public.rpc_contract_versions (
  rpc_name,
  signature,
  expected_hash,
  definition_snapshot,
  updated_at
)
SELECT
  rpc_name,
  signature,
  md5(normalized_definition),
  definition,
  NOW()
FROM normalized
ON CONFLICT (rpc_name) DO UPDATE
SET
  signature = EXCLUDED.signature,
  expected_hash = EXCLUDED.expected_hash,
  definition_snapshot = EXCLUDED.definition_snapshot,
  updated_at = NOW();

CREATE OR REPLACE FUNCTION public.audit_get_nearby_jobs_rpc()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rpc_name CONSTANT TEXT := 'get_nearby_jobs';
  v_signature CONSTANT TEXT := 'public.get_nearby_jobs(double precision, double precision, integer, integer)';
  v_definition TEXT;
  v_normalized TEXT;
  v_current_hash TEXT;
  v_expected_hash TEXT;
  v_definition_checks JSONB;
  v_hash_matches BOOLEAN := FALSE;
  v_all_checks_ok BOOLEAN := FALSE;
BEGIN
  BEGIN
    v_definition := pg_get_functiondef(v_signature::regprocedure);
  EXCEPTION
    WHEN undefined_function THEN
      RETURN jsonb_build_object(
        'ok', FALSE,
        'rpc_name', v_rpc_name,
        'signature', v_signature,
        'error', 'FUNCTION_NOT_FOUND'
      );
  END;

  v_normalized := regexp_replace(v_definition, '\s+', ' ', 'g');
  v_current_hash := md5(v_normalized);

  SELECT expected_hash
    INTO v_expected_hash
  FROM public.rpc_contract_versions
  WHERE rpc_name = v_rpc_name;

  v_hash_matches := v_expected_hash IS NOT NULL AND v_current_hash = v_expected_hash;

  v_definition_checks := jsonb_build_object(
    'security_definer', POSITION('security definer' IN LOWER(v_definition)) > 0,
    'uses_st_dwithin', POSITION('st_dwithin' IN LOWER(v_definition)) > 0,
    'unassigned_only', POSITION('technician_id is null' IN LOWER(v_definition)) > 0,
    'pending_searching_filter',
      POSITION('status in (''pending'', ''searching'')' IN LOWER(v_definition)) > 0,
    'no_technician_filter',
      POSITION('status = ''no_technician_found''' IN LOWER(v_definition)) > 0,
    'pending_searching_age_24h', POSITION('24 hours' IN LOWER(v_definition)) > 0,
    'no_technician_age_2h', POSITION('2 hours' IN LOWER(v_definition)) > 0,
    'bounded_limit', POSITION('least(greatest(limit_count, 1), 200)' IN LOWER(v_definition)) > 0
  );

  SELECT
    COALESCE(BOOL_AND(value::boolean), FALSE)
    INTO v_all_checks_ok
  FROM jsonb_each(v_definition_checks);

  RETURN jsonb_build_object(
    'ok', (v_hash_matches AND v_all_checks_ok),
    'rpc_name', v_rpc_name,
    'signature', v_signature,
    'hash_matches_expected', v_hash_matches,
    'current_hash', v_current_hash,
    'expected_hash', v_expected_hash,
    'definition_checks', v_definition_checks,
    'checked_at', NOW()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.audit_get_nearby_jobs_rpc() TO service_role;
