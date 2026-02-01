-- 🚨 سكربت تصفير النظام بالكامل (Strict Reset)
-- هذا السكربت سيقوم بحذف جميع الطلبات وإعادة تعيين منطق الفلترة ليكون صارماً جداً

-- 1. حذف جميع الطلبات (All Jobs)
DELETE FROM jobs;

-- 2. تحديث دالة البحث لتجلب الطلبات الجديدة *فقط* (آخر ساعة)
CREATE OR REPLACE FUNCTION get_nearby_jobs(
  technician_lat FLOAT, 
  technician_lng FLOAT, 
  radius_meters INT DEFAULT 5000000, -- زيادة النطاق مؤقتاً للاختبار (5000 كم) لتجاوز مشكلة الموقع
  limit_count INT DEFAULT 50
)
RETURNS SETOF jobs AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM jobs
  WHERE status IN ('pending', 'no_technician_found')
    AND jobs.lat IS NOT NULL 
    AND jobs.lng IS NOT NULL
    AND jobs.technician_id IS NULL
    -- فلترة صارمة: فقط الطلبات التي أنشئت في آخر ساعة (لإخفاء القديم تماماً)
    AND jobs.created_at > (NOW() - INTERVAL '1 hour')
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(technician_lng, technician_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(jobs.lng, jobs.lat), 4326)::geography,
      radius_meters
    )
  ORDER BY created_at DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public;

-- 3. تفعيل Realtime (فقط للتأكيد)
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
COMMIT;
