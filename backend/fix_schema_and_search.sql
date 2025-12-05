-- ============================================
-- FIX SCHEMA AND SEARCH FUNCTION (FINAL VERSION)
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Add updated_at column to jobs table
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

-- 2. Create trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_jobs_updated_at ON jobs;
CREATE TRIGGER update_jobs_updated_at
    BEFORE UPDATE ON jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 3. Fix find_nearby_technicians function
-- Drop first to avoid signature conflicts
DROP FUNCTION IF EXISTS find_nearby_technicians(FLOAT, FLOAT, INT, UUID);

CREATE OR REPLACE FUNCTION find_nearby_technicians(
    p_lat FLOAT,
    p_lng FLOAT,
    p_radius INT DEFAULT 5000,
    p_service_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    full_name VARCHAR,
    phone VARCHAR,
    rating NUMERIC,
    profile_image_url TEXT,
    distance_meters FLOAT
) 
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.full_name::VARCHAR,
        u.phone::VARCHAR,
        COALESCE(u.rating, 0)::NUMERIC,
        u.profile_image_url,
        ST_Distance(
            u.location, 
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
        )::FLOAT as distance_meters
    FROM public.users u
    LEFT JOIN public.wallets w ON u.id = w.user_id
    WHERE 
        u.user_type = 'technician'
        AND u.is_online = TRUE
        AND (w.is_frozen IS NULL OR w.is_frozen = FALSE)
        AND u.location IS NOT NULL
        AND ST_DWithin(
            u.location,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
            p_radius
        )
    ORDER BY distance_meters ASC
    LIMIT 50;
END;
$$;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';

SELECT 'Schema and function fixed successfully! ✅' as result;
