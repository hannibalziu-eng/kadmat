-- =============================================
-- Migration: Create Reviews and Portfolio Tables
-- =============================================

-- 1. Create Reviews Table
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    reviewer_id UUID REFERENCES public.users(id), -- Who wrote the review (Customer)
    reviewee_id UUID REFERENCES public.users(id), -- Who is being reviewed (Technician)
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Ensure one review per job per reviewer role (simplified: one review per job)
    UNIQUE(job_id)
);

-- 2. Create Technician Portfolio Table
CREATE TABLE IF NOT EXISTS public.technician_portfolio (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    technician_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    description TEXT,
    project_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Enable RLS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.technician_portfolio ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies

-- Reviews: public can read, customer can insert their own
CREATE POLICY "Public can view reviews" ON public.reviews
    FOR SELECT USING (true);

CREATE POLICY "Users can create reviews" ON public.reviews
    FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Portfolio: public can read, technician can manage their own
CREATE POLICY "Public can view portfolio" ON public.technician_portfolio
    FOR SELECT USING (true);

CREATE POLICY "Technicians can manage own portfolio" ON public.technician_portfolio
    FOR ALL USING (auth.uid() = technician_id);


-- 5. Trigger Function: Update Technician Rating
CREATE OR REPLACE FUNCTION update_technician_rating()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the user's rating average
    UPDATE public.users
    SET rating = (
        SELECT COALESCE(AVG(rating), 5.0)
        FROM public.reviews
        WHERE reviewee_id = NEW.reviewee_id
    )
    WHERE id = NEW.reviewee_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Attach Trigger
DROP TRIGGER IF EXISTS on_review_created ON public.reviews;
CREATE TRIGGER on_review_created
    AFTER INSERT ON public.reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_technician_rating();
