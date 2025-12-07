-- Create job_images table
CREATE TABLE IF NOT EXISTS job_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    media_type TEXT DEFAULT 'image', -- 'image' or 'video'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE job_images ENABLE ROW LEVEL SECURITY;

-- Policies
-- Everyone can view images (technicians need to see them)
CREATE POLICY "Images are viewable by everyone" ON job_images
    FOR SELECT USING (true);

-- Users can upload images to their own jobs
CREATE POLICY "Users can upload images to own jobs" ON job_images
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM jobs 
            WHERE jobs.id = job_images.job_id 
            AND jobs.customer_id = auth.uid()
        )
    );
