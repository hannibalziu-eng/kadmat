-- =============================================
-- ENABLE REALTIME FOR JOBS TABLE
-- تفعيل البث المباشر لجدول الطلبات
-- =============================================
-- Run this in Supabase SQL Editor: https://app.supabase.com
-- =============================================

-- Step 1: Check current realtime status
-- الخطوة 1: تحقق من الوضع الحالي
SELECT schemaname, tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;

-- Step 2: Enable realtime for jobs table
-- الخطوة 2: تفعيل البث المباشر لجدول jobs
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;

-- Step 3: Also enable for related tables (notifications, users updates)
-- الخطوة 3: تفعيل للجداول المرتبطة
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE users;

-- Step 4: Verify it worked
-- الخطوة 4: تأكد من نجاح العملية
SELECT schemaname, tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
AND tablename IN ('jobs', 'notifications', 'users');

-- =============================================
-- EXPECTED RESULT (النتيجة المتوقعة):
-- =============================================
-- | schemaname | tablename     |
-- |------------|---------------|
-- | public     | jobs          |
-- | public     | notifications |
-- | public     | users         |
-- =============================================

-- =============================================
-- OPTIONAL: Remove 12-hour limit from RPC
-- اختياري: إزالة حد الـ 12 ساعة من دالة البحث
-- =============================================
-- Uncomment and run if old jobs are not appearing:

-- DROP FUNCTION IF EXISTS get_nearby_jobs(float, float, int, int);
-- 
-- CREATE OR REPLACE FUNCTION get_nearby_jobs(
--   technician_lat FLOAT, 
--   technician_lng FLOAT, 
--   radius_meters INT DEFAULT 5000,
--   limit_count INT DEFAULT 50
-- )
-- RETURNS SETOF jobs AS $$
-- BEGIN
--   RETURN QUERY
--   SELECT *
--   FROM jobs
--   WHERE status IN ('pending', 'no_technician_found')
--     AND jobs.lat IS NOT NULL 
--     AND jobs.lng IS NOT NULL
--     AND jobs.technician_id IS NULL
--     -- Removed: AND jobs.created_at > (NOW() - INTERVAL '12 hours')
--     AND ST_DWithin(
--       ST_SetSRID(ST_MakePoint(technician_lng, technician_lat), 4326)::geography,
--       ST_SetSRID(ST_MakePoint(jobs.lng, jobs.lat), 4326)::geography,
--       radius_meters
--     )
--   ORDER BY created_at DESC
--   LIMIT limit_count;
-- END;
-- $$ LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path = public;

-- =============================================
-- TEST: Verify realtime is working
-- اختبار: تأكد من أن البث يعمل
-- =============================================

-- Create a test job (optional):
-- INSERT INTO jobs (customer_id, service_id, status, lat, lng, address_text)
-- VALUES ('your-customer-uuid', 'your-service-uuid', 'pending', 32.8872, 13.1913, 'Test Address');

-- Then check if it appears in the app within 2 seconds!
