-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_jobs_technician_id ON jobs(technician_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status_created ON jobs(status, created_at);

-- Update get_nearby_jobs RPC
CREATE OR REPLACE FUNCTION get_nearby_jobs(
  technician_lat DOUBLE PRECISION, 
  technician_lng DOUBLE PRECISION, 
  radius_meters INT DEFAULT 5000,
  limit_count INT DEFAULT 50
) RETURNS SETOF jobs AS $$
  SELECT * FROM jobs
  WHERE 
    -- Filter by radius using PostGIS
    ST_DWithin(
      ST_SetSRID(ST_MakePoint(technician_lng, technician_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(jobs.lng, jobs.lat), 4326)::geography,
      radius_meters
    )
    -- Service type filter could be added here if passed as param
    
    -- Filter out cancelled/completed/archived explicitly if needed, though status logic below handles visibility
    AND status NOT IN ('cancelled', 'completed')
    
    -- Unassigned logic
    AND (technician_id IS NULL OR status = 'searching')

    -- Status-based time filtering
    AND (
      -- Pending and searching jobs: visible for 24 hours
      (status IN ('pending', 'searching') AND created_at >= NOW() - INTERVAL '24 hours')
      OR 
      -- No technician found: visible for only 2 hours
      (status = 'no_technician_found' AND created_at >= NOW() - INTERVAL '2 hours')
      -- Other statuses (if any creep in, though likely filtered by technican_id IS NULL)
      OR status NOT IN ('pending', 'searching', 'no_technician_found')
    )
  ORDER BY created_at DESC
  LIMIT limit_count;
$$ LANGUAGE sql SECURITY DEFINER;
