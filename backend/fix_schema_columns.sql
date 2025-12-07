-- Fix missing updated_at columns
DO $$ BEGIN
    ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Re-apply the upgrade logic just in case
UPDATE public.users 
SET 
    user_type = 'technician',
    metadata = jsonb_set(COALESCE(metadata, '{}'), '{service_id}', '"a72136c3-7055-4da5-aeab-5a072a3fc742"'),
    updated_at = NOW()
WHERE email = 'techtest@test.com';

-- Ensure wallet
INSERT INTO public.wallets (user_id, balance, currency)
SELECT id, 100.00, 'SAR'
FROM public.users 
WHERE email = 'techtest@test.com'
ON CONFLICT (user_id) DO UPDATE 
SET balance = 100.00;
