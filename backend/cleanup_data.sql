-- 🧹 تنظيف البيانات القديمة (اختياري للاختبار)

-- 1. مسح جميع الطلبات المعلقة القديمة (أقدم من 12 ساعة)
DELETE FROM jobs 
WHERE status = 'pending' 
AND created_at < (NOW() - INTERVAL '12 hours');

-- 2. مسح الطلبات التي لم يجد لها فني منذ فترة طويلة
DELETE FROM jobs 
WHERE status = 'no_technician_found' 
AND created_at < (NOW() - INTERVAL '24 hours');

-- 3. (اختياري) مسح كل الطلبات للبدء من جديد
-- UNCOMMENT THE LINE BELOW TO DELETE ALL JOBS
-- DELETE FROM jobs;
