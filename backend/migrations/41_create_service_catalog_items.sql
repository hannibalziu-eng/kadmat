-- Sprint 1: service catalog items foundation
-- Creates read-only catalog structure for fixed-price service items.

CREATE TABLE IF NOT EXISTS public.service_catalog_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  name_ar TEXT,
  description TEXT,
  description_ar TEXT,
  price NUMERIC(10,2) NOT NULL,
  currency_code TEXT NOT NULL DEFAULT 'LYD',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  item_config JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_service_catalog_items_service_id
  ON public.service_catalog_items(service_id);

CREATE INDEX IF NOT EXISTS idx_service_catalog_items_active
  ON public.service_catalog_items(service_id, is_active, sort_order);
