-- السماح للفنيين (أو الجميع) برؤية الطلبات المعلقة (Pending Jobs)
-- هذا ضروري لكي تظهر الطلبات في شاشة "الطلبات القريبة"
DROP POLICY IF EXISTS "Technicians can view pending jobs" ON public.jobs;

CREATE POLICY "Technicians can view pending jobs" ON public.jobs
    FOR SELECT USING (status IN ('pending', 'no_technician_found'));
