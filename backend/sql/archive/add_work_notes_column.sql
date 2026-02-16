-- Add 'work_notes' column to 'jobs' table
ALTER TABLE public.jobs 
ADD COLUMN IF NOT EXISTS work_notes TEXT;

-- Verify the column is added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'jobs' AND column_name = 'work_notes';
