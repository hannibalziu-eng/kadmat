-- Create technician_badges table
CREATE TABLE IF NOT EXISTS public.technician_badges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    technician_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    badge_type VARCHAR(50) NOT NULL, -- 'verified_pro', 'top_rated', 'quick_responder'
    label VARCHAR(50), -- Display text like 'Verified Pro'
    icon_name VARCHAR(50), -- e.g., 'verified', 'star', 'flash_on'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(technician_id, badge_type)
);

-- RLS Policies
ALTER TABLE public.technician_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view badges" ON public.technician_badges
    FOR SELECT USING (true);

-- Only system/admin can insert/delete (for now, or maybe triggered by logic)
-- Allowing insert for testing if needed via service role, or authenticated users for now for prototype
CREATE POLICY "Technicians can insert own badges (Prototype)" ON public.technician_badges
    FOR INSERT WITH CHECK (auth.uid() = technician_id);
