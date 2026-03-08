-- Backfill legacy media URLs into canonical storage refs:
--   storage://<bucket>/<path>
--
-- Targets:
-- - public.job_photos.photo_url (default bucket: job-photos)
-- - public.job_images.image_url (default bucket: job_images)

BEGIN;

CREATE OR REPLACE FUNCTION public.__to_storage_ref(raw_value TEXT, default_bucket TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    value TEXT;
    m TEXT[];
    bucket TEXT;
    object_path TEXT;
BEGIN
    value := btrim(COALESCE(raw_value, ''));
    IF value = '' THEN
        RETURN raw_value;
    END IF;

    -- Already canonical.
    IF value LIKE 'storage://%' THEN
        RETURN value;
    END IF;

    -- Legacy plain path.
    IF value !~* '^https?://' THEN
        RETURN format('storage://%s/%s', default_bucket, value);
    END IF;

    -- Supabase object public/sign/authenticated URL.
    m := regexp_match(value, '/storage/v1/object/(public|sign|authenticated)/([^/]+)/(.+)$');
    IF m IS NOT NULL THEN
        bucket := m[2];
        object_path := regexp_replace(m[3], '\?.*$', '');
        object_path := replace(replace(object_path, '%2F', '/'), '%2f', '/');
        RETURN format('storage://%s/%s', bucket, object_path);
    END IF;

    -- Supabase transformed render URL.
    m := regexp_match(value, '/storage/v1/render/image/(public|sign|authenticated)/([^/]+)/(.+)$');
    IF m IS NOT NULL THEN
        bucket := m[2];
        object_path := regexp_replace(m[3], '\?.*$', '');
        object_path := replace(replace(object_path, '%2F', '/'), '%2f', '/');
        RETURN format('storage://%s/%s', bucket, object_path);
    END IF;

    -- Any other external URL stays unchanged.
    RETURN value;
END;
$$;

UPDATE public.job_photos
SET photo_url = public.__to_storage_ref(photo_url, 'job-photos')
WHERE photo_url IS NOT NULL
  AND photo_url <> ''
  AND photo_url IS DISTINCT FROM public.__to_storage_ref(photo_url, 'job-photos');

UPDATE public.job_images
SET image_url = public.__to_storage_ref(image_url, 'job_images')
WHERE image_url IS NOT NULL
  AND image_url <> ''
  AND image_url IS DISTINCT FROM public.__to_storage_ref(image_url, 'job_images');

DROP FUNCTION IF EXISTS public.__to_storage_ref(TEXT, TEXT);

COMMIT;

