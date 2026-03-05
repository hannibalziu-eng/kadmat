-- Enforce wallet debt lock after commission deduction.
-- Policy:
-- - Commission is always deducted (balance may become negative => debt).
-- - Technician is frozen while balance is negative.
-- - Debt amount is reflected in commission transaction description.

CREATE OR REPLACE FUNCTION process_job_payment(
    job_id UUID,
    tech_id UUID,
    amount DECIMAL
)
RETURNS void AS $$
DECLARE
    commission_amount DECIMAL;
    service_commission_rate DECIMAL;
    wallet_id UUID;
    current_balance DECIMAL;
    resulting_balance DECIMAL;
    debt_amount DECIMAL;
    commission_description TEXT;
BEGIN
    -- 1. Resolve service commission rate for the target job.
    SELECT s.commission_rate INTO service_commission_rate
    FROM public.jobs j
    JOIN public.services s ON j.service_id = s.id
    WHERE j.id = job_id;

    IF service_commission_rate IS NULL THEN
        service_commission_rate := 0.10;
    END IF;

    -- 2. Lock technician wallet row.
    SELECT w.id, COALESCE(w.balance, 0) INTO wallet_id, current_balance
    FROM public.wallets w
    WHERE w.user_id = tech_id
    FOR UPDATE;

    IF wallet_id IS NULL THEN
        RAISE EXCEPTION 'Technician wallet not found for user %', tech_id;
    END IF;

    -- 3. Deduct commission and mark debt lock if resulting balance is negative.
    commission_amount := COALESCE(amount, 0) * service_commission_rate;
    resulting_balance := current_balance - commission_amount;
    debt_amount := GREATEST(0, ABS(LEAST(resulting_balance, 0)));

    UPDATE public.wallets
    SET balance = resulting_balance,
        is_frozen = (resulting_balance < 0),
        updated_at = NOW()
    WHERE id = wallet_id;

    -- 4. Record wallet movement.
    commission_description := 'خصم عمولة الطلب';
    IF debt_amount > 0 THEN
        commission_description := commission_description || ' | مديونية حالية: ' || to_char(debt_amount, 'FM999999990.00');
    END IF;

    INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, reference_id)
    VALUES (
        wallet_id,
        -commission_amount,
        'commission',
        commission_description,
        job_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Keep existing wallets aligned with debt policy.
UPDATE public.wallets
SET is_frozen = (COALESCE(balance, 0) < 0),
    updated_at = NOW()
WHERE is_frozen IS DISTINCT FROM (COALESCE(balance, 0) < 0);
