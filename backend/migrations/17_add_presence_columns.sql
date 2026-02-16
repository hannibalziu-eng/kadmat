-- Migration: Add missing presence columns to users table
-- This fixes the error: "Could not find the 'last_seen' column of 'users'"

-- Add last_seen column for tracking user presence
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();

-- Add status column for presence status (online, away, busy, etc.)
ALTER TABLE users ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'offline';

-- Create index for faster presence queries
CREATE INDEX IF NOT EXISTS idx_users_last_seen ON users(last_seen);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_is_online ON users(is_online);

-- Update RLS policy to allow users to update their own presence
DROP POLICY IF EXISTS "Users can update own presence" ON users;
CREATE POLICY "Users can update own presence" ON users
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Grant necessary permissions
GRANT UPDATE (is_online, status, last_seen) ON users TO authenticated;
