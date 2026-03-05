-- Function to process job payment (deduct commission + debt lock policy)
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
    -- 1. Get commission rate for the service
    SELECT s.commission_rate INTO service_commission_rate
    FROM public.jobs j
    JOIN public.services s ON j.service_id = s.id
    WHERE j.id = job_id;

    -- Default to 10% if not found
    IF service_commission_rate IS NULL THEN
        service_commission_rate := 0.10;
    END IF;

    -- 2. Lock wallet row for consistent commission + debt calculation
    SELECT w.id, COALESCE(w.balance, 0) INTO wallet_id, current_balance
    FROM public.wallets w
    WHERE w.user_id = tech_id
    FOR UPDATE;

    IF wallet_id IS NULL THEN
        RAISE EXCEPTION 'Technician wallet not found for user %', tech_id;
    END IF;

    -- 3. Calculate commission and resulting debt/lock state
    commission_amount := COALESCE(amount, 0) * service_commission_rate;
    resulting_balance := current_balance - commission_amount;
    debt_amount := GREATEST(0, ABS(LEAST(resulting_balance, 0)));

    -- 4. Deduct commission from technician's wallet
    UPDATE public.wallets
    SET balance = resulting_balance,
        is_frozen = (resulting_balance < 0),
        updated_at = NOW()
    WHERE id = wallet_id;

    commission_description := 'خصم عمولة الطلب';
    IF debt_amount > 0 THEN
        commission_description := commission_description || ' | مديونية حالية: ' || to_char(debt_amount, 'FM999999990.00');
    END IF;

    -- 5. Record transaction
    INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, reference_id)
    VALUES (wallet_id, -commission_amount, 'commission', commission_description, job_id);
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
