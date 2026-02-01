-- =========================================================
-- 🛠️ الإصلاح النهائي: التنظيف التلقائي + تحسين البحث
-- =========================================================

-- 1️⃣ دالة التنظيف التلقائي (تعمل عند كل بحث)
-- لن نعتمد على جدول زمني خارجي، سننظف البيانات عند طلبها!
CREATE OR REPLACE FUNCTION auto_cleanup_jobs()
RETURNS void AS $$
BEGIN
  -- 1. تحويل الطلبات المعلقة لأكثر من 24 ساعة إلى 'expired' أو حذفها
  -- هنا سنقوم بحذفها للحفاظ على نظافة الجدول كما يفضل المستخدم
  DELETE FROM jobs 
  WHERE status IN ('pending', 'searching', 'no_technician_found')
    AND created_at < (NOW() - INTERVAL '24 hours');

  -- 2. تحويل الطلبات "غير موجود فني" لأكثر من ساعتين إلى محذوفة
  DELETE FROM jobs 
  WHERE status = 'no_technician_found'
    AND created_at < (NOW() - INTERVAL '2 hours');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2️⃣ تحديث دالة البحث لتشمل التنظيف + منطق محسن
DROP FUNCTION IF EXISTS get_nearby_jobs;

CREATE OR REPLACE FUNCTION get_nearby_jobs(
  technician_lat FLOAT, 
  technician_lng FLOAT, 
  radius_meters INT DEFAULT 50000, -- 50 كم (افتراضي واسع)
  limit_count INT DEFAULT 50
)
RETURNS SETOF jobs AS $$
BEGIN
  -- ✅ الخطوة الأولى: نداء التنظيف (Lazy Cleanup)
  -- هذا يضمن أن التقني لا يرى أبداً طلبات منتهية الصلاحية
  PERFORM auto_cleanup_jobs();

  -- ✅ الخطوة الثانية: إرجاع الطلبات الصالحة
  RETURN QUERY
  SELECT *
  FROM jobs
  WHERE 
    -- الحالات المسموح برؤيتها
    status IN ('pending', 'no_technician_found', 'searching')
    
    -- شرط الموقع
    AND jobs.lat IS NOT NULL 
    AND jobs.lng IS NOT NULL
    
    -- لم يتم قبولها بعد
    AND jobs.technician_id IS NULL

    -- ⚠️ إزالة شرط "آخر ساعة" الذي كان يسبب اختفاء الطلبات بسرعة أثناء الاختبار
    -- نعتمد الآن على auto_cleanup_jobs للتنظيف، لذا أي شيء متبقي هو صالح.
    
    -- فلتر المسافة (الأهم)
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(jobs.lng, jobs.lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(technician_lng, technician_lat), 4326)::geography,
      radius_meters
    )
  ORDER BY created_at DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3️⃣ التأكد من الفهارس (Indexes) للأداء العالي (مثل Firebase)
CREATE INDEX IF NOT EXISTS jobs_geo_index ON jobs USING GIST (ST_SetSRID(ST_MakePoint(lng, lat), 4326));
CREATE INDEX IF NOT EXISTS jobs_status_created_idx ON jobs (status, created_at);

-- 4️⃣ تنظيف فوري الآن لتبدأ نظيفاً
SELECT auto_cleanup_jobs();

-- 5️⃣ تفعيل Realtime للجدول (تم التحقق: مفعل بالفعل للجميع)
-- DO $$
-- BEGIN
--   ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
-- EXCEPTION
--   WHEN duplicate_object THEN NULL;
-- END $$;
