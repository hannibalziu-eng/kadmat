-- Hotfix: ensure ON CONFLICT(dedupe_key) has a full unique index.
-- Existing partial unique index (WHERE dedupe_key IS NOT NULL) may not be
-- inferable by ON CONFLICT in all execution paths.
BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_dedupe_key_full
ON public.notifications (dedupe_key);

COMMIT;
