-- Harden commission deduction against duplicate processing.
-- Also adds an index to support stale-lock recovery scans.

BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_transactions_commission_once_per_job
ON public.wallet_transactions(reference_id, type)
WHERE reference_id IS NOT NULL
  AND type = 'commission';

CREATE INDEX IF NOT EXISTS idx_jobs_stale_lock_scan
ON public.jobs(updated_at)
WHERE status IN ('on_the_way', 'arrived', 'in_progress', 'pending_confirm');

CREATE OR REPLACE FUNCTION public.process_job_payment(
    job_id UUID,
    tech_id UUID,
    amount DECIMAL
)
RETURNS void AS $$
DECLARE
    commission_amount DECIMAL;
    service_commission_rate DECIMAL;
    v_wallet_id UUID;
    v_inserted_tx_id UUID;
BEGIN
    SELECT
        s.commission_rate,
        w.id
    INTO service_commission_rate, v_wallet_id
    FROM public.jobs j
    JOIN public.services s ON j.service_id = s.id
    JOIN public.wallets w ON w.user_id = tech_id
    WHERE j.id = job_id
    LIMIT 1;

    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'wallet not found for technician %', tech_id USING ERRCODE = 'P0001';
    END IF;

    IF service_commission_rate IS NULL THEN
        service_commission_rate := 0.10;
    END IF;

    commission_amount := amount * service_commission_rate;
    IF commission_amount <= 0 THEN
        RETURN;
    END IF;

    -- Idempotent insert: if commission already recorded for this job, skip entirely.
    INSERT INTO public.wallet_transactions (
        wallet_id,
        amount,
        type,
        description,
        reference_id
    )
    VALUES (
        v_wallet_id,
        -commission_amount,
        'commission',
        'خصم عمولة الطلب',
        job_id
    )
    ON CONFLICT (reference_id, type) WHERE type = 'commission'
    DO NOTHING
    RETURNING id INTO v_inserted_tx_id;

    IF v_inserted_tx_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE public.wallets
    SET balance = COALESCE(balance, 0) - commission_amount,
        updated_at = NOW()
    WHERE id = v_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;

