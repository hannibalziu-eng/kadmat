-- Allow pre-registration technician document uploads in a constrained folder.
-- This keeps the bucket private while permitting only INSERT to:
--   job-photos/technician_documents/*

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname = 'Anon can upload technician documents'
    ) THEN
        CREATE POLICY "Anon can upload technician documents"
        ON storage.objects
        FOR INSERT
        TO anon
        WITH CHECK (
            bucket_id = 'job-photos'
            AND COALESCE((storage.foldername(name))[1], '') = 'technician_documents'
        );
    END IF;
END $$;

COMMIT;
