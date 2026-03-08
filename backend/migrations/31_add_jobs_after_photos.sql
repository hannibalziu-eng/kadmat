-- Hotfix: add missing after_photos column required by request-completion flow.
BEGIN;

ALTER TABLE public.jobs
ADD COLUMN IF NOT EXISTS after_photos JSONB DEFAULT '[]'::jsonb;

COMMIT;
