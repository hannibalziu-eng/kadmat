-- السماح للمستخدمين بإنشاء طلبات جديدة
-- هذا يحل مشكلة: new row violates row-level security policy for table "jobs"

-- 1. تفعيل RLS على الجدول (للتأكد فقط)
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

-- 2. حذف السياسة القديمة إذا وجدت لتجنب التكرار
DROP POLICY IF EXISTS "Users can create their own jobs" ON jobs;
DROP POLICY IF EXISTS "Customers can create jobs" ON jobs;

-- 3. إنشاء سياسة تسمح للمستخدم بإضافة طلب إذا كان هو صاحب الطلب (customer_id)
CREATE POLICY "Users can create their own jobs" ON jobs
    FOR INSERT 
    WITH CHECK (auth.uid() = customer_id);

-- 4. سياسة لرؤية الطلبات الخاصة بالمستخدم (للتأكد)
DROP POLICY IF EXISTS "Users can view their own jobs" ON jobs;
CREATE POLICY "Users can view their own jobs" ON jobs
    FOR SELECT
    USING (auth.uid() = customer_id OR auth.uid() = technician_id);

-- 5. سياسة لتحديث الطلب (لإلغاء الطلب مثلاً)
DROP POLICY IF EXISTS "Users can update their own jobs" ON jobs;
CREATE POLICY "Users can update their own jobs" ON jobs
    FOR UPDATE
    USING (auth.uid() = customer_id OR auth.uid() = technician_id);

-- إعادة تحميل الـ Schema
NOTIFY pgrst, 'reload schema';
