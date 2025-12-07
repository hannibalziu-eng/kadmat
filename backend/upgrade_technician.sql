-- Upgrade the test user to a technician
UPDATE public.users 
SET 
    user_type = 'technician', -- Correct column name is user_type, not role
    -- service_id is not a column, so we store it in metadata
    metadata = jsonb_set(COALESCE(metadata, '{}'), '{service_id}', '"a72136c3-7055-4da5-aeab-5a072a3fc742"'),
    updated_at = NOW()
WHERE email = 'techtest@test.com';

-- Ensure they have a wallet
INSERT INTO public.wallets (user_id, balance, currency)
SELECT id, 100.00, 'SAR'
FROM public.users 
WHERE email = 'techtest@test.com'
ON CONFLICT (user_id) DO UPDATE 
SET balance = 100.00; -- Reset balance for testing
