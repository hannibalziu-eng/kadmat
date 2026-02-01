-- ============================================
-- 🎯 KADMAT REAL-TIME FIX - COMPREHENSIVE SQL
-- ============================================
-- هذا السكربت يضمن أن كل شيء مُعد بشكل صحيح للـ Real-Time

-- ============================================
-- 1️⃣ INDEXES - لتسريع البحث
-- ============================================

-- Index على status للفلترة السريعة
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);

-- Index على customer_id للبحث عن طلبات العميل
CREATE INDEX IF NOT EXISTS idx_jobs_customer_id ON jobs(customer_id);

-- Index على technician_id للبحث عن طلبات الفني
CREATE INDEX IF NOT EXISTS idx_jobs_technician_id ON jobs(technician_id);

-- Index على created_at للترتيب
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at DESC);

-- Index على updated_at للـ Real-Time
CREATE INDEX IF NOT EXISTS idx_jobs_updated_at ON jobs(updated_at DESC);

-- Composite index للبحث الشائع (status + created_at)
CREATE INDEX IF NOT EXISTS idx_jobs_status_created ON jobs(status, created_at DESC);

-- ============================================
-- 2️⃣ TRIGGER - تحديث updated_at تلقائياً
-- ============================================

-- إنشاء الدالة (إذا لم تكن موجودة)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- حذف الـ trigger القديم إن وجد ثم إنشاء جديد
DROP TRIGGER IF EXISTS update_jobs_updated_at ON jobs;
CREATE TRIGGER update_jobs_updated_at 
  BEFORE UPDATE ON jobs 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 3️⃣ RPC FUNCTION - البحث عن الطلبات القريبة
-- ============================================

-- تأكد من وجود PostGIS
CREATE EXTENSION IF NOT EXISTS "postgis";

-- حذف الدالة القديمة
DROP FUNCTION IF EXISTS get_nearby_jobs;

-- إنشاء دالة محسّنة للبحث
CREATE OR REPLACE FUNCTION get_nearby_jobs(
  technician_lat FLOAT, 
  technician_lng FLOAT, 
  radius_meters INT DEFAULT 50000,  -- 50 كم افتراضياً
  limit_count INT DEFAULT 50
)
RETURNS SETOF jobs AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM jobs
  WHERE 
    -- ✅ فقط الطلبات المعلقة أو التي لم يُعثر لها فني
    status IN ('pending', 'no_technician_found')
    -- ✅ يجب أن يكون الموقع موجوداً
    AND jobs.lat IS NOT NULL 
    AND jobs.lng IS NOT NULL
    -- ✅ يجب ألا يكون هناك فني مُعين
    AND jobs.technician_id IS NULL
    -- ✅ فقط الطلبات الجديدة (آخر 24 ساعة)
    AND jobs.created_at > (NOW() - INTERVAL '24 hours')
    -- ✅ فلترة المسافة
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

-- ============================================
-- 4️⃣ RLS POLICIES - التأكد من صحة الصلاحيات
-- ============================================

-- تفعيل RLS
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

-- حذف السياسات القديمة إن وجدت
DROP POLICY IF EXISTS "Allow technicians to view pending jobs" ON jobs;
DROP POLICY IF EXISTS "Allow customers to view their own jobs" ON jobs;
DROP POLICY IF EXISTS "Allow technicians to view their own jobs" ON jobs;
DROP POLICY IF EXISTS "Allow service role full access" ON jobs;

-- سياسة: السماح للفنيين بمشاهدة الطلبات المعلقة
CREATE POLICY "Allow technicians to view pending jobs" ON jobs
  FOR SELECT
  USING (
    status IN ('pending', 'no_technician_found')
    AND technician_id IS NULL
  );

-- سياسة: السماح للعملاء بمشاهدة طلباتهم
CREATE POLICY "Allow customers to view their own jobs" ON jobs
  FOR SELECT
  USING (auth.uid() = customer_id);

-- سياسة: السماح للفنيين بمشاهدة طلباتهم المقبولة
CREATE POLICY "Allow technicians to view their own jobs" ON jobs
  FOR SELECT
  USING (auth.uid() = technician_id);

-- سياسة: السماح لـ service role بالوصول الكامل
CREATE POLICY "Allow service role full access" ON jobs
  FOR ALL
  USING (auth.role() = 'service_role');

-- ============================================
-- 5️⃣ REALTIME - التأكد من تفعيله
-- ============================================

-- ملاحظة: إذا كان الـ publication مُعد لـ ALL TABLES فلا حاجة لهذا
-- هذا للتأكيد فقط
DO $$
BEGIN
  -- التحقق من أن jobs موجود في الـ publication
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'jobs'
  ) THEN
    -- إذا كان الـ publication ليس FOR ALL TABLES، أضف الجدول
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
    EXCEPTION
      WHEN duplicate_object THEN NULL;
      WHEN OTHERS THEN NULL; -- قد يكون FOR ALL TABLES
    END;
  END IF;
END $$;

-- ============================================
-- 6️⃣ NOTIFICATION FUNCTION (اختياري)
-- ============================================

-- دالة لإرسال إشعار عند إنشاء طلب جديد
CREATE OR REPLACE FUNCTION notify_new_job()
RETURNS TRIGGER AS $$
BEGIN
  -- إرسال إشعار عبر pg_notify
  PERFORM pg_notify(
    'new_job',
    json_build_object(
      'job_id', NEW.id,
      'customer_id', NEW.customer_id,
      'status', NEW.status,
      'lat', NEW.lat,
      'lng', NEW.lng,
      'created_at', NEW.created_at
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger لإطلاق الإشعار عند إنشاء طلب جديد
DROP TRIGGER IF EXISTS trigger_notify_new_job ON jobs;
CREATE TRIGGER trigger_notify_new_job
  AFTER INSERT ON jobs
  FOR EACH ROW
  WHEN (NEW.status IN ('pending', 'no_technician_found'))
  EXECUTE FUNCTION notify_new_job();

-- ============================================
-- ✅ VERIFICATION - التحقق من نجاح التنفيذ
-- ============================================

-- عرض الـ indexes الموجودة
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'jobs';

-- عرض الـ triggers الموجودة
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'jobs';

-- عرض الـ policies الموجودة
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'jobs';

-- ============================================
-- 🎉 DONE!
-- ============================================
-- بعد تشغيل هذا السكربت:
-- 1. ستكون الـ Indexes موجودة لتسريع البحث
-- 2. سيتم تحديث updated_at تلقائياً عند أي تعديل
-- 3. ستكون دالة get_nearby_jobs جاهزة ومحسّنة
-- 4. ستكون RLS Policies صحيحة
-- 5. سيكون Realtime مفعلاً
