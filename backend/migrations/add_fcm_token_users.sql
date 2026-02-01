-- Add fcm_token column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Create index for faster lookups if valid tokens are queried often
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON public.users(fcm_token);
