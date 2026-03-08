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
-- Add missing RPC expected by Flutter LocationSyncService:
-- public.update_user_location(p_lat, p_lng, p_user_id)
-- Idempotent and backward-compatible across minor schema drift.

CREATE OR REPLACE FUNCTION public.update_user_location(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_location_udt TEXT;
  v_has_updated_at BOOLEAN;
  v_has_last_seen BOOLEAN;
  v_has_is_online BOOLEAN;
  v_has_status BOOLEAN;
  v_set_clauses TEXT[];
  v_sql TEXT;
  v_rows INT;
BEGIN
  IF p_lat IS NULL OR p_lng IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_lat, p_lng and p_user_id are required';
  END IF;

  IF p_lat < -90 OR p_lat > 90 OR p_lng < -180 OR p_lng > 180 THEN
    RAISE EXCEPTION 'Invalid coordinates: lat/lng out of range';
  END IF;

  -- Allow only self-update for authenticated users, unless service role.
  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to update this user location';
  END IF;

  SELECT c.udt_name
  INTO v_location_udt
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'users'
    AND c.column_name = 'location'
  LIMIT 1;

  IF v_location_udt IS NULL THEN
    RAISE EXCEPTION 'users.location column not found';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'updated_at'
  ) INTO v_has_updated_at;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'last_seen'
  ) INTO v_has_last_seen;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'is_online'
  ) INTO v_has_is_online;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'status'
  ) INTO v_has_status;

  v_set_clauses := ARRAY[]::TEXT[];

  IF v_location_udt IN ('geography', 'geometry') THEN
    v_set_clauses := array_append(
      v_set_clauses,
      'location = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography'
    );
  ELSE
    -- Fallback when location is a text column in older environments.
    v_set_clauses := array_append(
      v_set_clauses,
      'location = format(''SRID=4326;POINT(%s %s)'', $1, $2)'
    );
  END IF;

  IF v_has_updated_at THEN
    v_set_clauses := array_append(v_set_clauses, 'updated_at = NOW()');
  END IF;

  IF v_has_last_seen THEN
    v_set_clauses := array_append(v_set_clauses, 'last_seen = NOW()');
  END IF;

  IF v_has_is_online THEN
    v_set_clauses := array_append(v_set_clauses, 'is_online = TRUE');
  END IF;

  IF v_has_status THEN
    v_set_clauses := array_append(v_set_clauses, 'status = ''online''');
  END IF;

  v_sql := format(
    'UPDATE public.users SET %s WHERE id = $3',
    array_to_string(v_set_clauses, ', ')
  );

  EXECUTE v_sql USING p_lng, p_lat, p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_user_location(DOUBLE PRECISION, DOUBLE PRECISION, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_user_location(DOUBLE PRECISION, DOUBLE PRECISION, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_location(DOUBLE PRECISION, DOUBLE PRECISION, UUID) TO service_role;
-- Atomic offer acceptance RPC.
-- Locks job + selected offer and performs deterministic acceptance in one DB transaction.
-- This is the source-of-truth contract for backend accept-offer flow.

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
BEGIN
  IF p_job_id IS NULL OR p_customer_id IS NULL OR p_offer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'VALIDATION_FAILED',
      'message', 'job_id, customer_id and offer_id are required'
    );
  END IF;

  -- Lock target job row first.
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

  -- Idempotent success: same offer already selected and job advanced.
  IF v_job.accepted_bid_id = p_offer_id
     AND v_job.technician_id IS NOT NULL
     AND v_job.status IN ('accepted', 'price_pending', 'in_progress', 'pending_confirm', 'completed', 'rated') THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Offer already accepted',
      'current_status', v_job.status,
      'job', to_jsonb(v_job),
      'technician_id', v_job.technician_id,
      'accepted_price', COALESCE(v_job.final_price, v_job.technician_price)
    );
  END IF;

  -- Different offer already selected.
  IF v_job.accepted_bid_id IS NOT NULL AND v_job.accepted_bid_id <> p_offer_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_STATUS_TRANSITION',
      'message', 'Offer is no longer available',
      'current_status', v_job.status
    );
  END IF;

  -- Must still be open for accepting offers.
  IF v_job.status NOT IN ('pending', 'searching', 'no_technician_found') THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_STATUS_TRANSITION',
      'message', 'Job is no longer available for accepting offers',
      'current_status', v_job.status
    );
  END IF;

  -- Lock selected offer row.
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
    -- Idempotent accepted case (offer accepted + job advanced)
    IF v_offer.status = 'accepted'
       AND v_job.technician_id IS NOT NULL
       AND v_job.status IN ('accepted', 'price_pending', 'in_progress', 'pending_confirm', 'completed', 'rated') THEN
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

  -- Perform assignment atomically on still-open unassigned job.
  UPDATE public.jobs
  SET
    status = 'in_progress',
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
    -- Race fallback: if already assigned and advanced, treat as success.
    SELECT * INTO v_updated_job FROM public.jobs WHERE id = p_job_id;
    IF v_updated_job.technician_id IS NOT NULL
       AND v_updated_job.status IN ('accepted', 'price_pending', 'in_progress', 'pending_confirm', 'completed', 'rated') THEN
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

  -- Update offers state.
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
