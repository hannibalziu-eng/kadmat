-- Add FCM token support to users table for push notifications.
-- Safe to run multiple times.

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

CREATE INDEX IF NOT EXISTS idx_users_fcm_token
ON public.users(fcm_token);

