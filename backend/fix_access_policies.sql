-- 1. السماح للجميع بقراءة جدول الخدمات (Services)
-- هذا يضمن عدم حدوث مشاكل عند جلب تفاصيل الخدمة مع الطلب
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Everyone can view services" ON public.services;

CREATE POLICY "Everyone can view services" ON public.services
    FOR SELECT USING (true);

-- 2. السماح للمستخدمين المسجلين (مثل الفنيين) برؤية البيانات الأساسية للمستخدمين الآخرين (مثل العملاء)
-- هذا ضروري لأن الفني يحتاج لرؤية اسم العميل صاحب الطلب
DROP POLICY IF EXISTS "Authenticated users can view basic profile info" ON public.users;

CREATE POLICY "Authenticated users can view basic profile info" ON public.users
    FOR SELECT USING (auth.role() = 'authenticated');
