-- Create technician service evidence photos table (pre/post).
-- This table is consumed by Flutter flows and backend validation.

CREATE TABLE IF NOT EXISTS public.job_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    photo_type TEXT NOT NULL CHECK (photo_type IN ('pre', 'post')),
    description TEXT,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL DEFAULT auth.uid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_job_photos_job_id ON public.job_photos(job_id);
CREATE INDEX IF NOT EXISTS idx_job_photos_job_type ON public.job_photos(job_id, photo_type);

ALTER TABLE public.job_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants can view job photos" ON public.job_photos;
CREATE POLICY "Participants can view job photos" ON public.job_photos
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM public.jobs j
            WHERE j.id = job_photos.job_id
              AND (j.customer_id = auth.uid() OR j.technician_id = auth.uid())
        )
    );

DROP POLICY IF EXISTS "Technicians can insert own job photos" ON public.job_photos;
CREATE POLICY "Technicians can insert own job photos" ON public.job_photos
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.jobs j
            WHERE j.id = job_photos.job_id
              AND j.technician_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Technicians can delete own job photos" ON public.job_photos;
CREATE POLICY "Technicians can delete own job photos" ON public.job_photos
    FOR DELETE USING (
        EXISTS (
            SELECT 1
            FROM public.jobs j
            WHERE j.id = job_photos.job_id
              AND j.technician_id = auth.uid()
        )
    );
