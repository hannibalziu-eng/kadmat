-- Function to find nearby available technicians
-- Uses PostGIS for geospatial queries

CREATE OR REPLACE FUNCTION find_nearby_technicians(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius INTEGER, -- in meters
    p_service_id UUID
)
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    phone TEXT,
    rating NUMERIC,
    distance_meters DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.full_name,
        u.phone,
        u.rating,
        ST_DistanceSphere(
            tp.current_location,
            ST_MakePoint(p_lng, p_lat)
        ) AS distance_meters
    FROM users u
    INNER JOIN technician_profiles tp ON tp.user_id = u.id
    WHERE 
        u.user_type = 'technician'
        AND tp.is_available = true
        AND tp.is_verified = true
        AND tp.current_location IS NOT NULL
        -- Check if technician offers this service (if service_ids array exists)
        AND (
            tp.service_ids IS NULL 
            OR p_service_id = ANY(tp.service_ids)
        )
        -- Check distance
        AND ST_DistanceSphere(
            tp.current_location,
            ST_MakePoint(p_lng, p_lat)
        ) <= p_radius
    ORDER BY distance_meters ASC
    LIMIT 20;
END;
$$;

-- Add search_radius and search_data columns to jobs if not exists
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS search_radius INTEGER DEFAULT 2000;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS search_data JSONB;

-- Create notifications table if not exists
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'new_job', 'job_accepted', 'job_completed', etc.
    title TEXT NOT NULL,
    body TEXT,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- Enable RLS on notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Grant execute on function
GRANT EXECUTE ON FUNCTION find_nearby_technicians TO authenticated;
GRANT EXECUTE ON FUNCTION find_nearby_technicians TO service_role;
