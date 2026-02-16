-- Add accepted bid reference for bidding flow job lock.
-- Safe to run multiple times.

ALTER TABLE public.jobs
ADD COLUMN IF NOT EXISTS accepted_bid_id UUID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'jobs_accepted_bid_id_fkey'
  ) THEN
    ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_accepted_bid_id_fkey
    FOREIGN KEY (accepted_bid_id)
    REFERENCES public.job_offers(id)
    ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_jobs_accepted_bid_id
ON public.jobs(accepted_bid_id);
