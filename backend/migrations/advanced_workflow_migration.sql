-- ============================================
-- Advanced Workflow Migration
-- Adds columns needed for timer-based job expiry
-- ============================================

-- Add accepted_at column for tracking when technician accepted
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP WITH TIME ZONE;

-- Add expired_at column for tracking when job expired
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS expired_at TIMESTAMP WITH TIME ZONE;

-- Add search_attempts to track retry count
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS search_attempts INTEGER DEFAULT 0;

-- Add last_search_at and next_search_at for retry scheduling
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS last_search_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS next_search_at TIMESTAMP WITH TIME ZONE;

-- Add expired status to job status enum if not exists
-- Note: This assumes you're using TEXT for status. If enum, run:
-- ALTER TYPE job_status_enum ADD VALUE IF NOT EXISTS 'expired';

-- Add fcm_token column to users for push notifications
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Create index for expiry queries (faster scheduler)
CREATE INDEX IF NOT EXISTS idx_jobs_pending_created_at 
ON jobs (created_at) 
WHERE status IN ('pending', 'searching') AND technician_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_jobs_accepted_at 
ON jobs (accepted_at) 
WHERE status = 'accepted';

-- Create function to update accepted_at on status change
CREATE OR REPLACE FUNCTION update_accepted_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
        NEW.accepted_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for accepted_at
DROP TRIGGER IF EXISTS trg_update_accepted_at ON jobs;
CREATE TRIGGER trg_update_accepted_at
    BEFORE UPDATE ON jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_accepted_at();

-- Optional: RPC function for incrementing technician penalty
CREATE OR REPLACE FUNCTION increment_technician_penalty(
    p_technician_id UUID,
    p_penalty_type TEXT
)
RETURNS void AS $$
BEGIN
    -- You can customize penalty tracking here
    -- For now, just log it or update a penalties table
    INSERT INTO technician_penalties (technician_id, penalty_type, created_at)
    VALUES (p_technician_id, p_penalty_type, NOW())
    ON CONFLICT DO NOTHING;
    
    -- Update penalty count on user if you have such a column
    -- UPDATE users 
    -- SET penalty_count = COALESCE(penalty_count, 0) + 1
    -- WHERE id = p_technician_id;
END;
$$ LANGUAGE plpgsql;

-- Create penalties table if you want to track them
CREATE TABLE IF NOT EXISTS technician_penalties (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    technician_id UUID REFERENCES users(id),
    penalty_type TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for penalties
CREATE INDEX IF NOT EXISTS idx_technician_penalties_tech_id 
ON technician_penalties (technician_id);

-- ============================================
-- Run this script in Supabase SQL Editor
-- ============================================
