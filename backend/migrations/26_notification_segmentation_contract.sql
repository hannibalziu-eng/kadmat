-- Notification segmentation contract hardening
-- Adds audience/category/channel metadata with dedupe support.

BEGIN;

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS audience_role TEXT,
    ADD COLUMN IF NOT EXISTS category TEXT,
    ADD COLUMN IF NOT EXISTS channels TEXT[],
    ADD COLUMN IF NOT EXISTS entity_type TEXT,
    ADD COLUMN IF NOT EXISTS entity_id UUID,
    ADD COLUMN IF NOT EXISTS dedupe_key TEXT,
    ADD COLUMN IF NOT EXISTS priority SMALLINT;

UPDATE public.notifications
SET audience_role = 'all'
WHERE audience_role IS NULL;

UPDATE public.notifications
SET category = 'system'
WHERE category IS NULL;

UPDATE public.notifications
SET channels = ARRAY['inbox']::TEXT[]
WHERE channels IS NULL;

UPDATE public.notifications
SET priority = 3
WHERE priority IS NULL;

ALTER TABLE public.notifications
    ALTER COLUMN audience_role SET DEFAULT 'all',
    ALTER COLUMN audience_role SET NOT NULL,
    ALTER COLUMN category SET DEFAULT 'system',
    ALTER COLUMN category SET NOT NULL,
    ALTER COLUMN channels SET DEFAULT ARRAY['inbox']::TEXT[],
    ALTER COLUMN channels SET NOT NULL,
    ALTER COLUMN priority SET DEFAULT 3,
    ALTER COLUMN priority SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'notifications_audience_role_check'
          AND conrelid = 'public.notifications'::regclass
    ) THEN
        ALTER TABLE public.notifications
            ADD CONSTRAINT notifications_audience_role_check
            CHECK (audience_role IN ('customer', 'technician', 'admin', 'all'));
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'notifications_category_check'
          AND conrelid = 'public.notifications'::regclass
    ) THEN
        ALTER TABLE public.notifications
            ADD CONSTRAINT notifications_category_check
            CHECK (category IN ('job', 'offer', 'payment', 'message', 'system'));
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'notifications_priority_check'
          AND conrelid = 'public.notifications'::regclass
    ) THEN
        ALTER TABLE public.notifications
            ADD CONSTRAINT notifications_priority_check
            CHECK (priority BETWEEN 1 AND 5);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_notifications_user_audience_created_at
    ON public.notifications(user_id, audience_role, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_category_read
    ON public.notifications(user_id, category, is_read);

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_dedupe_key
    ON public.notifications(dedupe_key)
    WHERE dedupe_key IS NOT NULL;

COMMIT;
