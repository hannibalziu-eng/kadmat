-- One-time cleanup for legacy stuck jobs that remained open before cancel-flow fixes.
-- Run in Supabase SQL Editor when needed.

-- 1) Preview open searchable jobs for a specific customer.
-- Replace :customer_id with actual UUID.
-- SELECT id, customer_id, status, technician_id, created_at, updated_at
-- FROM public.jobs
-- WHERE customer_id = ':customer_id'
--   AND status IN ('pending', 'searching', 'no_technician_found')
-- ORDER BY created_at DESC;

-- 2) Cancel ALL unassigned searchable jobs for a specific customer.
-- Replace :customer_id with actual UUID.
-- UPDATE public.jobs
-- SET
--   status = 'cancelled',
--   cancelled_at = NOW(),
--   updated_at = NOW(),
--   metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
--     'cancellation_reason', 'legacy_stuck_cleanup',
--     'cancelled_by', ':customer_id'
--   )
-- WHERE customer_id = ':customer_id'
--   AND technician_id IS NULL
--   AND status IN ('pending', 'searching', 'no_technician_found');

-- 3) Global safe dedupe (optional):
-- Keeps ONLY the newest unassigned searchable job per customer; cancels older duplicates.
WITH ranked AS (
  SELECT
    id,
    customer_id,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id
      ORDER BY created_at DESC, id DESC
    ) AS rn
  FROM public.jobs
  WHERE technician_id IS NULL
    AND status IN ('pending', 'searching', 'no_technician_found')
)
UPDATE public.jobs j
SET
  status = 'cancelled',
  cancelled_at = NOW(),
  updated_at = NOW(),
  metadata = COALESCE(j.metadata, '{}'::jsonb) || jsonb_build_object(
    'cancellation_reason', 'dedupe_stale_open_job',
    'cancelled_by', j.customer_id
  )
FROM ranked r
WHERE j.id = r.id
  AND r.rn > 1;
