-- Fix for Registration Issue
-- This policy allows the database trigger to insert new users into the public.users table

-- 1. Enable RLS on users table (if not already enabled)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 2. Allow the trigger (which runs as the user or service role) to insert into users table
-- We use a broad check here because the trigger handles the data integrity
CREATE POLICY "Enable insert for authenticated users only" ON "public"."users"
AS PERMISSIVE FOR INSERT
TO public
WITH CHECK (auth.uid() = id);

-- 3. Just in case the trigger runs as service_role (which bypasses RLS), 
-- but if it doesn't, we add this:
CREATE POLICY "Enable insert for service role" ON "public"."users"
AS PERMISSIVE FOR INSERT
TO service_role
WITH CHECK (true);

-- 4. Ensure the trigger function exists and is secure (Optional, just to be safe)
-- You can't run this if you don't have superuser, but usually in Supabase SQL editor you do.
-- If this fails, ignore it.
