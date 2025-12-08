-- Drop existing restrictive policies if they exist
DROP POLICY IF EXISTS "Customer or Technician can view job" ON public.jobs;
DROP POLICY IF EXISTS "Technicians can view pending jobs" ON public.jobs;
DROP POLICY IF EXISTS "Authenticated users can view pending jobs" ON public.jobs;
DROP POLICY IF EXISTS "User can view job if involved" ON public.jobs;

-- Create single unified policy as per Spec v2.0
CREATE POLICY "User can view job if involved" ON public.jobs
    FOR SELECT
    USING (
        -- Case 1: User is the customer
        auth.uid() = customer_id
        OR
        -- Case 2: User is the assigned technician
        auth.uid() = technician_id
        OR
        -- Case 3: Job is available (pending/searching) - visible to all authenticated users
        status IN ('pending', 'searching')
    );
