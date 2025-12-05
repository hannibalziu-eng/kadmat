-- السماح للفنيين (أو الجميع) برؤية الطلبات المعلقة (Pending Jobs)
-- هذا ضروري لكي تظهر الطلبات في شاشة "الطلبات القريبة"
CREATE POLICY "Technicians can view pending jobs" ON public.jobs
    FOR SELECT USING (status = 'pending');
