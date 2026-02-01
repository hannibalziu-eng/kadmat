-- Create storage buckets for job images and portfolio images
-- Run this in Supabase SQL Editor

-- 1. Create job_images bucket (for customer job photos)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'job_images',
  'job_images',
  true,  -- Public bucket for easy access
  5242880, -- 5MB limit per file
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Create portfolio bucket (for technician portfolio images)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'portfolio',
  'portfolio',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- 3. Enable public access policies for job_images
CREATE POLICY "Public Access for job_images" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'job_images');

CREATE POLICY "Authenticated users can upload job_images" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'job_images' 
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can delete own job_images" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'job_images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- 4. Enable public access policies for portfolio
CREATE POLICY "Public Access for portfolio" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'portfolio');

CREATE POLICY "Authenticated users can upload portfolio" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'portfolio' 
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can delete own portfolio images" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'portfolio' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Done! The buckets are now ready for use.
