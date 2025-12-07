-- Enable Full Replica Identity for Realtime Updates
ALTER TABLE public.jobs REPLICA IDENTITY FULL;

-- ==========================================
-- FIX MISSING TABLES (Consolidated Fix)
-- ==========================================

-- 1. Create job_images table (if missing)
CREATE TABLE IF NOT EXISTS public.job_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    media_type TEXT DEFAULT 'image',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for job_images
ALTER TABLE public.job_images ENABLE ROW LEVEL SECURITY;

-- Policies for job_images
DROP POLICY IF EXISTS "Images are viewable by everyone" ON public.job_images;
CREATE POLICY "Images are viewable by everyone" ON public.job_images FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can upload images to own jobs" ON public.job_images;
CREATE POLICY "Users can upload images to own jobs" ON public.job_images
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.jobs 
            WHERE jobs.id = job_images.job_id 
            AND jobs.customer_id = auth.uid()
        )
    );

-- 2. Create technician_badges table (if missing)
CREATE TABLE IF NOT EXISTS public.technician_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    technician_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    badge_type VARCHAR(50) NOT NULL,
    label VARCHAR(50),
    icon_name VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(technician_id, badge_type)
);

-- Enable RLS for technician_badges
ALTER TABLE public.technician_badges ENABLE ROW LEVEL SECURITY;

-- Policies for technician_badges
DROP POLICY IF EXISTS "Anyone can view badges" ON public.technician_badges;
CREATE POLICY "Anyone can view badges" ON public.technician_badges FOR SELECT USING (true);

DROP POLICY IF EXISTS "Technicians can insert own badges (Prototype)" ON public.technician_badges;
CREATE POLICY "Technicians can insert own badges (Prototype)" ON public.technician_badges
    FOR INSERT WITH CHECK (auth.uid() = technician_id);

