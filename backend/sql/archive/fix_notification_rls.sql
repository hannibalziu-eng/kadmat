-- Fix RLS policy for notifications table to allow insertions from authenticated users (Technicians)
-- This is necessary when the app falls back to direct DB updates (Offline/No Backend)
-- The trigger on 'jobs' table tries to insert a notification, which fails without this policy.

DROP POLICY IF EXISTS "Technicians can insert notifications" ON notifications;

CREATE POLICY "Technicians can insert notifications"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Ensure users can read their own notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;

CREATE POLICY "Users can view their own notifications"
ON notifications
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Ensure RLS is enabled
-- Ensure RLS is enabled (Skipped to avoid ownership errors if already enabled)
-- ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
