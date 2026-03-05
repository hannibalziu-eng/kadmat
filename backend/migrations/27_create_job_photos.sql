-- Create job_photos table to support technician documentation (pre/post service).
-- Matches Flutter repository implementation.

CREATE TABLE IF NOT EXISTS public.job_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
    uploaded_by UUID REFERENCES public.users(id), -- Optional: can be derived from technician_id
    photo_type TEXT NOT NULL CHECK (photo_type IN ('pre', 'post', 'before', 'after', 'additional_work', 'dispute_evidence')),
    photo_url TEXT NOT NULL,
    thumbnail_url TEXT,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.job_photos ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Job photos are viewable by participants" ON public.job_photos
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.jobs j
            WHERE j.id = job_photos.job_id
            AND (j.customer_id = auth.uid() OR j.technician_id = auth.uid())
        )
    );

CREATE POLICY "Technicians can upload photos to their assigned jobs" ON public.job_photos
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.jobs j
            WHERE j.id = job_photos.job_id
            AND j.technician_id = auth.uid()
        )
    );

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_job_photos_job_id_type ON public.job_photos(job_id, photo_type);
