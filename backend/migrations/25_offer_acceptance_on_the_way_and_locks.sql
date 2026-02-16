-- Ensure offer-acceptance moves to on_the_way and enforce active-job locks.
-- Safe to run multiple times.

DO $$
DECLARE
  v_definition TEXT;
BEGIN
  SELECT pg_get_constraintdef(c.oid)
  INTO v_definition
  FROM pg_constraint c
  WHERE c.conname = 'jobs_status_check'
    AND c.conrelid = 'public.jobs'::regclass
  LIMIT 1;

  IF v_definition IS NULL
     OR POSITION('on_the_way' IN LOWER(v_definition)) = 0
     OR POSITION('arrived' IN LOWER(v_definition)) = 0 THEN
    IF v_definition IS NOT NULL THEN
      ALTER TABLE public.jobs DROP CONSTRAINT jobs_status_check;
    END IF;

    ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_status_check
    CHECK (
      status IN (
        'pending',
        'searching',
        'accepted',
        'price_pending',
        'counter_offer',
        'on_the_way',
        'arrived',
        'in_progress',
        'pending_confirm',
        'pending_confirmation',
        'completed',
        'rated',
        'cancelled',
        'no_technician_found'
      )
    );
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.accept_job_offer_atomic(
  p_job_id UUID,
  p_customer_id UUID,
  p_offer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job public.jobs%ROWTYPE;
  v_offer public.job_offers%ROWTYPE;
  v_updated_job public.jobs%ROWTYPE;
  v_locked_job_id UUID;
BEGIN
  IF p_job_id IS NULL OR p_customer_id IS NULL OR p_offer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'VALIDATION_FAILED',
      'message', 'job_id, customer_id and offer_id are required'
    );
  END IF;

  SELECT *
  INTO v_job
  FROM public.jobs
  WHERE id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'JOB_NOT_FOUND',
      'message', 'Job not found'
    );
  END IF;

  IF v_job.customer_id IS DISTINCT FROM p_customer_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'UNAUTHORIZED',
      'message', 'Unauthorized'
    );
  END IF;

  IF v_job.accepted_bid_id = p_offer_id
     AND v_job.technician_id IS NOT NULL
     AND v_job.status IN (
       'accepted',
       'price_pending',
       'on_the_way',
       'arrived',
       'in_progress',
       'pending_confirm',
       'completed',
       'rated'
     ) THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Offer already accepted',
      'current_status', v_job.status,
      'job', to_jsonb(v_job),
      'technician_id', v_job.technician_id,
      'accepted_price', COALESCE(v_job.final_price, v_job.technician_price)
    );
  END IF;

  IF v_job.accepted_bid_id IS NOT NULL AND v_job.accepted_bid_id <> p_offer_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_STATUS_TRANSITION',
      'message', 'Offer is no longer available',
      'current_status', v_job.status
    );
  END IF;

  IF v_job.status NOT IN ('pending', 'searching', 'no_technician_found') THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_STATUS_TRANSITION',
      'message', 'Job is no longer available for accepting offers',
      'current_status', v_job.status
    );
  END IF;

  SELECT *
  INTO v_offer
  FROM public.job_offers
  WHERE id = p_offer_id
    AND job_id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'NOT_FOUND',
      'message', 'Offer not found',
      'current_status', v_job.status
    );
  END IF;

  IF COALESCE(v_offer.status, 'pending') <> 'pending' THEN
    IF v_offer.status = 'accepted'
       AND v_job.technician_id IS NOT NULL
       AND v_job.status IN (
         'accepted',
         'price_pending',
         'on_the_way',
         'arrived',
         'in_progress',
         'pending_confirm',
         'completed',
         'rated'
       ) THEN
      RETURN jsonb_build_object(
        'success', true,
        'message', 'Offer already accepted',
        'current_status', v_job.status,
        'job', to_jsonb(v_job),
        'technician_id', v_job.technician_id,
        'accepted_price', COALESCE(v_job.final_price, v_job.technician_price)
      );
    END IF;

    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_STATUS_TRANSITION',
      'message', 'Offer is no longer available',
      'current_status', v_job.status
    );
  END IF;

  SELECT j.id
  INTO v_locked_job_id
  FROM public.jobs j
  WHERE j.technician_id = v_offer.technician_id
    AND j.id <> p_job_id
    AND j.status IN ('on_the_way', 'arrived', 'in_progress', 'pending_confirm')
  LIMIT 1;

  IF v_locked_job_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ACTIVE_JOB_LOCKED',
      'message', 'Technician has an active job',
      'locked_job_id', v_locked_job_id
    );
  END IF;

  UPDATE public.jobs
  SET
    status = 'on_the_way',
    technician_id = v_offer.technician_id,
    technician_price = v_offer.price,
    final_price = v_offer.price,
    accepted_bid_id = v_offer.id,
    accepted_at = COALESCE(accepted_at, NOW()),
    price_confirmed_at = COALESCE(price_confirmed_at, NOW()),
    updated_at = NOW()
  WHERE id = p_job_id
    AND technician_id IS NULL
    AND status IN ('pending', 'searching', 'no_technician_found')
  RETURNING * INTO v_updated_job;

  IF NOT FOUND THEN
    SELECT * INTO v_updated_job FROM public.jobs WHERE id = p_job_id;
    IF v_updated_job.technician_id IS NOT NULL
       AND v_updated_job.status IN (
         'accepted',
         'price_pending',
         'on_the_way',
         'arrived',
         'in_progress',
         'pending_confirm',
         'completed',
         'rated'
       ) THEN
      RETURN jsonb_build_object(
        'success', true,
        'message', 'Offer already accepted',
        'current_status', v_updated_job.status,
        'job', to_jsonb(v_updated_job),
        'technician_id', v_updated_job.technician_id,
        'accepted_price', COALESCE(v_updated_job.final_price, v_updated_job.technician_price)
      );
    END IF;

    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_STATUS_TRANSITION',
      'message', 'Job is no longer available',
      'current_status', v_updated_job.status
    );
  END IF;

  UPDATE public.job_offers
  SET
    status = 'accepted',
    is_active = TRUE,
    updated_at = NOW()
  WHERE id = p_offer_id;

  UPDATE public.job_offers
  SET
    status = 'rejected',
    is_active = FALSE,
    updated_at = NOW()
  WHERE job_id = p_job_id
    AND id <> p_offer_id
    AND status = 'pending';

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Offer accepted',
    'current_status', v_updated_job.status,
    'job', to_jsonb(v_updated_job),
    'technician_id', v_updated_job.technician_id,
    'accepted_price', COALESCE(v_updated_job.final_price, v_updated_job.technician_price)
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ACCEPT_FAILED',
      'message', format('Failed to assign job: %s', SQLERRM),
      'sqlstate', SQLSTATE
    );
END;
$$;

REVOKE ALL ON FUNCTION public.accept_job_offer_atomic(UUID, UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_job_offer_atomic(UUID, UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.accept_job_offer_atomic(UUID, UUID, UUID) TO authenticated;
