-- Enable Realtime for the jobs table
-- This allows the technician app to receive live updates when a new job is created
begin;
  -- Check if publication exists, if not create it (standard supabase setup usually has it)
  -- But we just want to add the table to it.
  
  -- The publication 'supabase_realtime' is default in Supabase.
  alter publication supabase_realtime add table public.jobs;

commit;
