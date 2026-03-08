-- Notification lifecycle telemetry storage
-- Tracks sent/received/opened/actioned with correlation IDs.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.notification_lifecycle_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    notification_id UUID NULL REFERENCES public.notifications(id) ON DELETE SET NULL,
    event_stage TEXT NOT NULL,
    event_type TEXT NOT NULL,
    request_id TEXT NOT NULL,
    dedupe_key TEXT NULL,
    entity_id UUID NULL,
    source TEXT NOT NULL DEFAULT 'unknown',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'notification_lifecycle_events_stage_check'
          AND conrelid = 'public.notification_lifecycle_events'::regclass
    ) THEN
        ALTER TABLE public.notification_lifecycle_events
            ADD CONSTRAINT notification_lifecycle_events_stage_check
            CHECK (event_stage IN ('sent', 'received', 'opened', 'actioned'));
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_notification_lifecycle_events_user_created
    ON public.notification_lifecycle_events(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_lifecycle_events_request
    ON public.notification_lifecycle_events(request_id, dedupe_key);

CREATE INDEX IF NOT EXISTS idx_notification_lifecycle_events_entity
    ON public.notification_lifecycle_events(entity_id, event_stage, occurred_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS uq_notification_lifecycle_event_fingerprint
    ON public.notification_lifecycle_events (
        user_id,
        event_stage,
        request_id,
        COALESCE(dedupe_key, ''),
        COALESCE(notification_id::text, ''),
        source
    );

ALTER TABLE public.notification_lifecycle_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'notification_lifecycle_events'
          AND policyname = 'notification_lifecycle_events_select_own'
    ) THEN
        CREATE POLICY notification_lifecycle_events_select_own
            ON public.notification_lifecycle_events
            FOR SELECT
            TO authenticated
            USING (auth.uid() = user_id);
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'notification_lifecycle_events'
          AND policyname = 'notification_lifecycle_events_insert_own'
    ) THEN
        CREATE POLICY notification_lifecycle_events_insert_own
            ON public.notification_lifecycle_events
            FOR INSERT
            TO authenticated
            WITH CHECK (auth.uid() = user_id);
    END IF;
END
$$;

COMMIT;
