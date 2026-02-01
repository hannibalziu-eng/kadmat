-- Function to process job payment (deduct commission)
CREATE OR REPLACE FUNCTION process_job_payment(
    job_id UUID, 
    tech_id UUID, 
    amount DECIMAL
)
RETURNS void AS $$
DECLARE
    commission_amount DECIMAL;
    service_commission_rate DECIMAL;
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

    -- 2. Calculate commission
    commission_amount := amount * service_commission_rate;

    -- 3. Deduct commission from technician's wallet
    UPDATE public.wallets
    SET balance = balance - commission_amount,
        updated_at = NOW()
    WHERE user_id = tech_id;

    -- 4. Record transaction
    INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, reference_id)
    SELECT id, -commission_amount, 'commission', 'خصم عمولة الطلب', job_id
    FROM public.wallets WHERE user_id = tech_id;
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
