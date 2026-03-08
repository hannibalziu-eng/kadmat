-- Enforce idempotency for critical POST endpoints.
-- Scope: user_id + endpoint + key
-- TTL: 48 hours (configurable from backend, persisted in expires_at)

BEGIN;

CREATE TABLE IF NOT EXISTS public.api_idempotency_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    endpoint TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    request_hash TEXT,
    status TEXT NOT NULL DEFAULT 'processing' CHECK (status IN ('processing', 'completed')),
    response_status INTEGER,
    response_body JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '48 hours')
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_api_idempotency_keys_unique
ON public.api_idempotency_keys(user_id, endpoint, idempotency_key);

CREATE INDEX IF NOT EXISTS idx_api_idempotency_keys_expires_at
ON public.api_idempotency_keys(expires_at);

CREATE INDEX IF NOT EXISTS idx_api_idempotency_keys_lookup
ON public.api_idempotency_keys(user_id, endpoint, idempotency_key, expires_at DESC);

CREATE OR REPLACE FUNCTION public.touch_api_idempotency_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_api_idempotency_updated_at'
          AND tgrelid = 'public.api_idempotency_keys'::regclass
    ) THEN
        CREATE TRIGGER trg_api_idempotency_updated_at
        BEFORE UPDATE ON public.api_idempotency_keys
        FOR EACH ROW
        EXECUTE FUNCTION public.touch_api_idempotency_updated_at();
    END IF;
END $$;

COMMIT;

