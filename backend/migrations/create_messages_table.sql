-- Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES public.jobs(id) NOT NULL,
    sender_id UUID REFERENCES public.users(id) NOT NULL,
    receiver_id UUID REFERENCES public.users(id) NOT NULL,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_messages_job_id ON public.messages(job_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON public.messages(receiver_id);

-- RLS Policies
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view messages they are involved in (sender or receiver)
CREATE POLICY "Users can view own messages" ON public.messages
    FOR SELECT USING (
        auth.uid() = sender_id OR 
        auth.uid() = receiver_id
    );

-- Policy: Users can insert messages if they are sender and part of the job context
-- (Ideally, we should check if they are customer or technician of the job, but for now simple sender check + auth)
CREATE POLICY "Users can send messages" ON public.messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id
    );

-- Policy: Users can update messages (e.g. mark as read) if they are receiver
CREATE POLICY "Users can update received messages" ON public.messages
    FOR UPDATE USING (
        auth.uid() = receiver_id
    );
