-- Harden get_nearby_jobs visibility:
-- only technicians (or service_role) can execute discovery query.

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
    (
      auth.role() = 'service_role'
      OR EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = auth.uid()
          AND u.user_type = 'technician'
      )
    )
    AND j.technician_id IS NULL
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

REVOKE ALL ON FUNCTION public.get_nearby_jobs(double precision, double precision, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_nearby_jobs(double precision, double precision, integer, integer)
TO authenticated, service_role;
