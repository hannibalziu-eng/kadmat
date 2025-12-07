-- =============================================
-- FIX SMART SEARCH & TECHNICIAN FINDING
-- =============================================

-- 1. Drop the function first to ensure clean recreation
DROP FUNCTION IF EXISTS get_nearby_technicians;

-- 2. Re-create the function with robust logic
CREATE OR REPLACE FUNCTION get_nearby_technicians(
  lat float, 
  long float, 
  radius_meters int,
  service_type uuid DEFAULT NULL 
)
RETURNS TABLE (
  id UUID, 
  full_name text, 
  profile_image_url text,
  dist_meters float, 
  rating decimal,
  is_online boolean
) 
LANGUAGE sql
SECURITY DEFINER -- IMPORTANT: Run as admin to bypass RLS on users table during search
AS $$
  SELECT 
    u.id, 
    u.full_name,
    u.profile_image_url,
    ST_Distance(u.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography) as dist_meters,
    u.rating,
    u.is_online
  FROM public.users u
  -- Optional: Join wallets only if you want to strictly enforce balance checks
  -- For now, let's be lenient to ensure jobs are delivered
  -- JOIN public.wallets w ON u.id = w.user_id 
  WHERE 
    u.user_type = 'technician'
    AND u.is_online = TRUE 
    AND u.location IS NOT NULL -- Ensure location exists
    -- AND w.is_frozen = FALSE 
    AND ST_DWithin(u.location, ST_SetSRID(ST_MakePoint(long, lat), 4326)::geography, radius_meters)
  ORDER BY dist_meters ASC
  LIMIT 20;
$$;

-- 3. Verify it works by calling it with generous radius
-- Riyadh Check: 24.7136, 46.6753
SELECT * FROM get_nearby_technicians(24.7136, 46.6753, 50000);
