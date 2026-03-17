-- Sprint 1: services pricing foundation
-- Adds default pricing/dispatch metadata to services without changing active flows.

ALTER TABLE public.services
  ADD COLUMN IF NOT EXISTS pricing_mode_default TEXT NOT NULL DEFAULT 'technician_quote',
  ADD COLUMN IF NOT EXISTS dispatch_mode_default TEXT NOT NULL DEFAULT 'manual_quote',
  ADD COLUMN IF NOT EXISTS is_catalog_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS requires_quote BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS service_config JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.services.pricing_mode_default IS 'Default pricing mode for the service in Hybrid Pricing MVP';
COMMENT ON COLUMN public.services.dispatch_mode_default IS 'Default dispatch mode for the service in Hybrid Pricing MVP';
COMMENT ON COLUMN public.services.is_catalog_enabled IS 'Whether the service exposes fixed-price catalog items';
COMMENT ON COLUMN public.services.requires_quote IS 'Whether the service requires technician quote flow by default';
COMMENT ON COLUMN public.services.service_config IS 'Service-level pricing configuration payload for Hybrid Pricing MVP';
