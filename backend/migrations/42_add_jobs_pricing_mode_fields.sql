-- Sprint 1: jobs pricing foundation
-- Adds job-level pricing metadata to prepare hybrid pricing without activating new flows.

ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS pricing_mode TEXT NOT NULL DEFAULT 'technician_quote',
  ADD COLUMN IF NOT EXISTS dispatch_mode TEXT NOT NULL DEFAULT 'manual_quote',
  ADD COLUMN IF NOT EXISTS catalog_subtotal NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS pricing_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS quote_required BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS catalog_item_count INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.jobs.pricing_mode IS 'Selected pricing mode for Hybrid Pricing MVP';
COMMENT ON COLUMN public.jobs.dispatch_mode IS 'Selected dispatch mode for Hybrid Pricing MVP';
COMMENT ON COLUMN public.jobs.catalog_subtotal IS 'Pre-total for fixed-price catalog items';
COMMENT ON COLUMN public.jobs.pricing_summary IS 'Structured pricing payload for Hybrid Pricing MVP';
COMMENT ON COLUMN public.jobs.quote_required IS 'Whether job requires technician quote confirmation';
COMMENT ON COLUMN public.jobs.catalog_item_count IS 'Number of fixed-price catalog items associated conceptually to the job';
