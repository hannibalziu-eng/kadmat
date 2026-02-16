-- =============================================
-- EMERGENCY REPAIR: restore get_nearby_jobs contract
-- Use only when audit reports drift or technicians stop receiving jobs.
-- =============================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.rpc_contract_versions (
  rpc_name TEXT PRIMARY KEY,
  signature TEXT NOT NULL,
  expected_hash TEXT NOT NULL,
  definition_snapshot TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP FUNCTION IF EXISTS public.get_nearby_jobs(double precision, double precision, integer, integer);
DROP FUNCTION IF EXISTS public.get_nearby_jobs(float, float, int, int);

CREATE OR REPLACE FUNCTION public.get_nearby_jobs(
  technician_lat DOUBLE PRECISION,
  technician_lng DOUBLE PRECISION,
  radius_meters INT DEFAULT 5000,
  limit_count INT DEFAULT 50
)
RETURNS SETOF public.jobs
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT j.*
  FROM public.jobs j
  WHERE
    j.technician_id IS NULL
    AND j.lat IS NOT NULL
    AND j.lng IS NOT NULL
    AND (
      (j.status IN ('pending', 'searching') AND j.created_at >= NOW() - INTERVAL '24 hours')
      OR
      (j.status = 'no_technician_found' AND j.created_at >= NOW() - INTERVAL '2 hours')
    )
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(technician_lng, technician_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(j.lng, j.lat), 4326)::geography,
      radius_meters
    )
  ORDER BY j.created_at DESC
  LIMIT LEAST(GREATEST(limit_count, 1), 200);
$$;

GRANT EXECUTE ON FUNCTION public.get_nearby_jobs(double precision, double precision, integer, integer)
TO authenticated, service_role;

WITH canonical AS (
  SELECT
    'get_nearby_jobs'::text AS rpc_name,
    'public.get_nearby_jobs(double precision, double precision, integer, integer)'::text AS signature,
    pg_get_functiondef(
      'public.get_nearby_jobs(double precision, double precision, integer, integer)'::regprocedure
    ) AS definition_snapshot
),
normalized AS (
  SELECT
    rpc_name,
    signature,
    definition_snapshot,
    md5(regexp_replace(definition_snapshot, '\s+', ' ', 'g')) AS expected_hash
  FROM canonical
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
  expected_hash,
  definition_snapshot,
  NOW()
FROM normalized
ON CONFLICT (rpc_name) DO UPDATE
SET
  signature = EXCLUDED.signature,
  expected_hash = EXCLUDED.expected_hash,
  definition_snapshot = EXCLUDED.definition_snapshot,
  updated_at = NOW();

COMMIT;

SELECT public.audit_get_nearby_jobs_rpc() AS audit_after_restore;
