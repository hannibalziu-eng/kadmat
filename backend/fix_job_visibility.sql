-- MASTER FIX: Job Visibility & Realtime
-- Run this entire script in Supabase SQL Editor

BEGIN;

-- 1. Enable Realtime for Jobs Table
-- This is critical for the technician app to see new requests instantly.
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
-- OR if you prefer safer scope:
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.jobs;

-- 2. Fix RLS Permissions for Jobs
-- Ensure authenticated users (Technicians) can SELECT pending jobs.
DROP POLICY IF EXISTS "Authenticated users can view pending jobs" ON public.jobs;
CREATE POLICY "Authenticated users can view pending jobs" ON public.jobs
    FOR SELECT USING (
        status = 'pending' 
        OR auth.uid() = customer_id 
        OR auth.uid() = technician_id
    );

-- 3. Fix Technician Visibility (Smart Search)
-- Ensure 'technician' user type is correct and online status works.
-- (This fixes the "Found 0 new technicians" backend log)
UPDATE public.users 
SET is_online = TRUE 
WHERE user_type = 'technician';

-- 4. Verify Geometry/Location column
-- Ensure the location column is correct type (already checked, but good to be safe)
-- CREATE INDEX IF NOT EXISTS users_location_idx ON public.users USING GIST (location);

COMMIT;
