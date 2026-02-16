-- =============================================
-- FIX JOB VISIBILITY & UPDATED RPC
-- إصلاح ظهور الطلبات وتحديث دالة البحث
-- NOTE: Superseded by migration 18_finalize_get_nearby_jobs_rpc.sql for production.
-- =============================================

-- 1. Ensure get_nearby_jobs includes 'searching' status
--    and removes strict time limits for easier testing
DROP FUNCTION IF EXISTS get_nearby_jobs(float, float, int, int);

CREATE OR REPLACE FUNCTION get_nearby_jobs(
  technician_lat FLOAT, 
  technician_lng FLOAT, 
  radius_meters INT DEFAULT 50000, -- Increased default radius for testing (50km)
  limit_count INT DEFAULT 50
)
RETURNS SETOF jobs AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM jobs
  WHERE 
    status IN ('pending', 'searching', 'no_technician_found') -- Added 'searching'
    AND jobs.lat IS NOT NULL 
    AND jobs.lng IS NOT NULL
    AND jobs.technician_id IS NULL -- Only unassigned jobs
    AND (
      -- Distance filter
      ST_DWithin(
        ST_SetSRID(ST_MakePoint(technician_lng, technician_lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint(jobs.lng, jobs.lat), 4326)::geography,
        radius_meters
      )
    )
  ORDER BY created_at DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public;

-- 2. Ensure job_offers table exists (re-asserting if missed)
-- Moved to 14_create_job_offers.sql but ensuring permissions here too just in case
GRANT EXECUTE ON FUNCTION get_nearby_jobs TO authenticated, service_role;
