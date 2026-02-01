-- ============================================
-- Kadmat Database Setup Script
-- Execute this in Supabase SQL Editor
-- ============================================

-- 1. Create job_photos table
CREATE TABLE IF NOT EXISTS job_photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  photo_type TEXT NOT NULL CHECK (photo_type IN ('pre', 'post')),
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_job_photos_job_id ON job_photos(job_id);
CREATE INDEX IF NOT EXISTS idx_job_photos_type ON job_photos(photo_type);
CREATE INDEX IF NOT EXISTS idx_job_photos_created_at ON job_photos(created_at DESC);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE job_photos ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for job_photos

-- Allow authenticated users to insert photos for their jobs
CREATE POLICY "Users can insert photos for their jobs"
ON job_photos FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM jobs
    WHERE jobs.id = job_photos.job_id
    AND (jobs.customer_id = auth.uid() OR jobs.technician_id = auth.uid())
  )
);

-- Allow users to view photos for their jobs
CREATE POLICY "Users can view photos for their jobs"
ON job_photos FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM jobs
    WHERE jobs.id = job_photos.job_id
    AND (jobs.customer_id = auth.uid() OR jobs.technician_id = auth.uid())
  )
);

-- Allow users to delete photos for their jobs
CREATE POLICY "Users can delete photos for their jobs"
ON job_photos FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM jobs
    WHERE jobs.id = job_photos.job_id
    AND (jobs.customer_id = auth.uid() OR jobs.technician_id = auth.uid())
  )
);

-- 5. Verify Realtime is enabled (already enabled for all tables by default)
-- Note: Supabase enables Realtime for all tables automatically
-- No need to add tables manually

-- 6. Verify setup
SELECT 
  'job_photos table created' as status,
  COUNT(*) as row_count 
FROM job_photos;

SELECT 
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies 
WHERE tablename = 'job_photos';

-- Success message
SELECT '✅ Database setup complete!' as message;
