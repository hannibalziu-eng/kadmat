-- Add profile fields to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS title TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS location TEXT;

-- Update RLS policies if necessary (usually public profile fields are readable by everyone)
-- Assuming 'users' table is public readable for profile info or has specific policies.
-- If not, ensure these fields are accessible.
