-- Enforce private media access for job photos and customer job images.
-- This migration removes public-read exposure and prepares signed-URL-only serving.

BEGIN;

-- 1) Buckets must be private.
UPDATE storage.buckets
SET public = false
WHERE id IN ('job-photos', 'job_images');

-- 2) Remove SELECT policies that expose these buckets publicly (or broadly).
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND cmd = 'SELECT'
          AND (
              COALESCE(qual, '') ILIKE '%job-photos%'
              OR COALESCE(qual, '') ILIKE '%job_images%'
          )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', rec.policyname);
    END LOOP;
END $$;

-- 3) Ensure authenticated upload policies still exist.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname = 'Authenticated users can upload job-photos'
    ) THEN
        CREATE POLICY "Authenticated users can upload job-photos"
        ON storage.objects
        FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'job-photos');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname = 'Authenticated users can upload job_images'
    ) THEN
        CREATE POLICY "Authenticated users can upload job_images"
        ON storage.objects
        FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'job_images');
    END IF;
END $$;

COMMIT;

