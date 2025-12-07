-- Add reviews_count to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS reviews_count INTEGER DEFAULT 0;

-- Function to update reviews count and average rating automatically
CREATE OR REPLACE FUNCTION update_technician_rating()
RETURNS TRIGGER AS $$
DECLARE
    new_rating DECIMAL(3,2);
    new_count INTEGER;
    tech_id UUID;
BEGIN
    -- Determine technician ID
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        tech_id := NEW.technician_id;
    ELSE
        tech_id := OLD.technician_id;
    END IF;

    -- Calculate new stats
    SELECT 
        COUNT(id), 
        COALESCE(AVG(customer_rating), 5.0)
    INTO 
        new_count, 
        new_rating
    FROM public.jobs
    WHERE technician_id = tech_id 
    AND customer_rating IS NOT NULL;

    -- Update user table
    UPDATE public.users
    SET 
        rating = new_rating,
        reviews_count = new_count
    WHERE id = tech_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create Trigger on Jobs table
DROP TRIGGER IF EXISTS on_job_rating_change ON public.jobs;
CREATE TRIGGER on_job_rating_change
AFTER INSERT OR UPDATE OF customer_rating OR DELETE ON public.jobs
FOR EACH ROW EXECUTE PROCEDURE update_technician_rating();
