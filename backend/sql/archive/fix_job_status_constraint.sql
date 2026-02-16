-- Fix for "new row for relation 'jobs' violates check constraint"
-- This error happens because the 'status' column likely has a CHECK constraint 
-- that doesn't include the newer statuses like 'payment_pending' or 'pending_confirm'.

-- 1. Drop existing constraint (name might vary, so we try common names or just replacing it)
-- To be safe, we will drop the constraint by name if creating it fails, but first let's just 
-- alter the column type or constraint. Use a safe approach.

DO $$
DECLARE
    -- No variables needed for this simple block
BEGIN
    -- Remove the old check constraint. 
    -- NOTE: You might need to find the exact name of your constraint. 
    -- Common default is "jobs_status_check".
    
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'jobs_status_check') THEN
        ALTER TABLE public.jobs DROP CONSTRAINT jobs_status_check;
    END IF;
    
    -- Also check for 'jobs_status_fkey' or similar if it was an enum, 
    -- but usually it's a text column with a check.

    -- 2. Add the updated constraint with ALL valid statuses
    ALTER TABLE public.jobs
    ADD CONSTRAINT jobs_status_check 
    CHECK (status IN (
        'pending', 
        'searching', 
        'accepted', 
        'price_pending', 
        'in_progress', 
        'pending_confirm',   -- New status
        'completed', 
        'rated', 
        'cancelled', 
        'no_technician_found',
        'payment_pending'    -- Used in fallback logic
    ));

END $$;
