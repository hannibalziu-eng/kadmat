-- Create job_offers table for bidding system
CREATE TABLE IF NOT EXISTS public.job_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    technician_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, accepted, rejected
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add RLS Policies
ALTER TABLE public.job_offers ENABLE ROW LEVEL SECURITY;

-- Technicians can view their own offers
CREATE POLICY "Technicians can view own offers" ON public.job_offers
    FOR SELECT USING (auth.uid() = technician_id);

-- Technicians can insert their own offers
CREATE POLICY "Technicians can create offers" ON public.job_offers
    FOR INSERT WITH CHECK (auth.uid() = technician_id);

-- Customers can view offers for their jobs
CREATE POLICY "Customers can view offers for their jobs" ON public.job_offers
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.jobs
            WHERE jobs.id = job_offers.job_id
            AND jobs.customer_id = auth.uid()
        )
    );

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_job_offers_job_id ON public.job_offers(job_id);
CREATE INDEX IF NOT EXISTS idx_job_offers_technician_id ON public.job_offers(technician_id);
