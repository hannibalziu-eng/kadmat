-- ============================================
-- 🧹 تنظيف الطلبات القديمة وإعداد الـ Realtime
-- ============================================
-- هذا السكربت يحذف الطلبات القديمة ويضمن عمل Realtime

-- 1️⃣ حذف جميع الطلبات القديمة (أكثر من ساعة)
DELETE FROM jobs 
WHERE created_at < (NOW() - INTERVAL '1 hour')
  AND status IN ('pending', 'no_technician_found', 'searching');

-- 2️⃣ حذف الطلبات الملغاة القديمة
DELETE FROM jobs 
WHERE status = 'cancelled'
  AND created_at < (NOW() - INTERVAL '24 hours');

-- 3️⃣ تحديث RPC function مع فلتر أقصر (ساعة واحدة بدلاً من 12)
DROP FUNCTION IF EXISTS get_nearby_jobs;

CREATE OR REPLACE FUNCTION get_nearby_jobs(
  technician_lat FLOAT, 
  technician_lng FLOAT, 
  radius_meters INT DEFAULT 50000,  -- 50 كم للاختبار
  limit_count INT DEFAULT 50
)
RETURNS SETOF jobs AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM jobs
  WHERE 
    -- فقط pending أو no_technician_found
    status IN ('pending', 'no_technician_found')
    -- يجب أن يكون الموقع موجوداً
    AND jobs.lat IS NOT NULL 
    AND jobs.lng IS NOT NULL
    -- لم يتم تعيين فني بعد
    AND jobs.technician_id IS NULL
    -- فقط آخر ساعة (للتنظيف)
    AND jobs.created_at > (NOW() - INTERVAL '1 hour')
    -- فلتر المسافة
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

-- 4️⃣ التأكد من تفعيل Realtime
-- (إذا كان FOR ALL TABLES، هذا لن يؤثر)
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
  EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN OTHERS THEN NULL;
  END;
END $$;

-- 5️⃣ عرض الطلبات الحالية للتأكد
SELECT id, status, created_at, 
       EXTRACT(EPOCH FROM (NOW() - created_at))/60 as minutes_ago
FROM jobs 
WHERE status IN ('pending', 'no_technician_found')
ORDER BY created_at DESC
LIMIT 10;

-- ✅ Done!
-- بعد تشغيل هذا:
-- 1. الطلبات القديمة حُذفت
-- 2. RPC تفلتر لآخر ساعة فقط
-- 3. Realtime مفعّل
-- 4. اضغط R في Flutter لـ Hot Restart
