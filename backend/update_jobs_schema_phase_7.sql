-- Phase 7 Field Updates for Service Marketplace Flow

-- 1. Add missing columns to 'jobs' table
ALTER TABLE public.jobs
ADD COLUMN IF NOT EXISTS after_photos TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS work_notes TEXT,
ADD COLUMN IF NOT EXISTS final_price DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS payment_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS payment_method TEXT,
ADD COLUMN IF NOT EXISTS customer_rating DECIMAL(2, 1),
ADD COLUMN IF NOT EXISTS customer_review TEXT,
ADD COLUMN IF NOT EXISTS tech_rating DECIMAL(2, 1),
ADD COLUMN IF NOT EXISTS tech_review TEXT;

-- 2. Add comments for clarity
COMMENT ON COLUMN public.jobs.after_photos IS 'URLs of photos uploaded by technician after work';
COMMENT ON COLUMN public.jobs.work_notes IS 'Description of work done by technician';
COMMENT ON COLUMN public.jobs.final_price IS 'Final agreed price after completion';

-- 3. Verify columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'jobs';
