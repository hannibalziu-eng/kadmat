-- 1. Create the 'job-photos' bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('job-photos', 'job-photos', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/jpg'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Insert" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update/delete their own images" ON storage.objects;

-- 3. Enable RLS on objects (Skipped: Already enabled on Supabase by default, avoiding permission error)
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 4. Create Policies

-- Allow public read access to all files in the bucket
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'job-photos' );

-- Allow authenticated users to upload files
CREATE POLICY "Authenticated Insert"
ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'job-photos' AND auth.role() = 'authenticated' );

-- Allow users to update/delete their own files (optional, good for cleanup)
CREATE POLICY "Users can update/delete their own images"
ON storage.objects FOR ALL
USING ( bucket_id = 'job-photos' AND auth.uid() = owner );
