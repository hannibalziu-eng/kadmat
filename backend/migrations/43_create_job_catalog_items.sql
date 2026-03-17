-- Sprint 2 Day 1: create job_catalog_items
-- Purpose: persist fixed-price catalog line items as immutable job-time snapshots
-- Scope: DB/data foundation only. No runtime branching or offer-flow logic.

CREATE TABLE IF NOT EXISTS public.job_catalog_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  service_catalog_item_id UUID REFERENCES public.service_catalog_items(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  name_ar TEXT,
  unit_price NUMERIC(10,2) NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  line_total NUMERIC(10,2) NOT NULL,
  currency_code TEXT NOT NULL DEFAULT 'LYD',
  item_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT job_catalog_items_quantity_positive CHECK (quantity > 0),
  CONSTRAINT job_catalog_items_unit_price_nonnegative CHECK (unit_price >= 0),
  CONSTRAINT job_catalog_items_line_total_nonnegative CHECK (line_total >= 0)
);

CREATE INDEX IF NOT EXISTS idx_job_catalog_items_job_id
  ON public.job_catalog_items(job_id);

CREATE INDEX IF NOT EXISTS idx_job_catalog_items_service_catalog_item_id
  ON public.job_catalog_items(service_catalog_item_id);

CREATE INDEX IF NOT EXISTS idx_job_catalog_items_job_id_created_at
  ON public.job_catalog_items(job_id, created_at);

COMMENT ON TABLE public.job_catalog_items IS 'Immutable fixed-price catalog item snapshots stored at job creation time';
COMMENT ON COLUMN public.job_catalog_items.service_catalog_item_id IS 'Original catalog item reference when available';
COMMENT ON COLUMN public.job_catalog_items.name IS 'Snapshot item name at time of job creation';
COMMENT ON COLUMN public.job_catalog_items.name_ar IS 'Snapshot Arabic item name at time of job creation';
COMMENT ON COLUMN public.job_catalog_items.unit_price IS 'Snapshot unit price at time of job creation';
COMMENT ON COLUMN public.job_catalog_items.quantity IS 'Selected quantity for the catalog item';
COMMENT ON COLUMN public.job_catalog_items.line_total IS 'Snapshot line total for the selected quantity';
COMMENT ON COLUMN public.job_catalog_items.currency_code IS 'Snapshot pricing currency code';
COMMENT ON COLUMN public.job_catalog_items.item_snapshot IS 'Structured snapshot payload for future-proof catalog item persistence';
