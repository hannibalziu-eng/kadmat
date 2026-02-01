-- =============================================
-- SEARCH OPTIMIZATION MIGRATION
-- Phase 2: Enhanced RPC + Phase 3: Search Logging
-- =============================================

-- =============================================
-- PHASE 2: Update get_nearby_technicians RPC
-- Now includes phone for FCM, better sorting
-- =============================================

DROP FUNCTION IF EXISTS get_nearby_technicians(float, float, int, uuid);

CREATE OR REPLACE FUNCTION get_nearby_technicians(
  lat float, 
  long float, 
  radius_meters int,
  service_type uuid DEFAULT NULL 
)
RETURNS TABLE (
  id UUID, 
  full_name text,
  phone text,
  profile_image_url text,
  dist_meters float, 
  rating decimal,
  is_online boolean
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    u.id, 
    u.full_name,
    u.phone,
    u.profile_image_url,
    ST_Distance(u.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography) as dist_meters,
    u.rating,
    u.is_online
  FROM public.users u
  WHERE 
    u.user_type = 'technician'
    AND u.is_online = TRUE 
    AND u.location IS NOT NULL
    AND ST_DWithin(u.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography, radius_meters)
    -- Optional: Filter by service (if service_type provided)
    AND (service_type IS NULL OR u.service_id = service_type)
  ORDER BY 
    -- Primary: Distance (nearest first)
    ST_Distance(u.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography) ASC,
    -- Secondary: Rating (highest rating for similar distance)
    u.rating DESC NULLS LAST
  LIMIT 10;
$$;

-- =============================================
-- PHASE 3: Search Logging Table
-- Track search performance for analytics
-- =============================================

CREATE TABLE IF NOT EXISTS search_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
  tier_index INT NOT NULL,
  radius_meters INT NOT NULL,
  technicians_found INT NOT NULL DEFAULT 0,
  search_duration_ms INT,
  was_accepted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_search_logs_job ON search_logs(job_id);
CREATE INDEX IF NOT EXISTS idx_search_logs_created ON search_logs(created_at);

-- Index on users for faster technician search
CREATE INDEX IF NOT EXISTS idx_users_technician_online 
ON users(user_type, is_online) 
WHERE user_type = 'technician' AND is_online = TRUE;

-- Grant permissions
ALTER TABLE search_logs ENABLE ROW LEVEL SECURITY;

-- RLS: Service role can insert/read
CREATE POLICY "Service role can manage search_logs" ON search_logs
  FOR ALL USING (true) WITH CHECK (true);

-- =============================================
-- Verification queries (optional)
-- =============================================

-- Test the updated RPC
-- SELECT * FROM get_nearby_technicians(32.9, 13.1, 10000);

-- Check search logs
-- SELECT * FROM search_logs ORDER BY created_at DESC LIMIT 10;

-- Analytics: Average technicians found per tier
-- SELECT 
--   tier_index,
--   AVG(technicians_found) as avg_found,
--   AVG(search_duration_ms) as avg_duration_ms,
--   COUNT(*) as total_searches
-- FROM search_logs
-- GROUP BY tier_index
-- ORDER BY tier_index;
