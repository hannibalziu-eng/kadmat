-- Fix for PGRST116 error when updating location
-- This allows authenticated users to update their own profile (including location)

-- Enable RLS (just in case)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Add policy to allow updates
-- Note: If this fails with "policy already exists", that's fine, it means it's already there.
-- But the error suggests it is missing.
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);
