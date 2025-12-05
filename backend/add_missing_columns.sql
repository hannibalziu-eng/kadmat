-- إضافة جميع الأعمدة المفقودة لجدول jobs
-- شغّل هذا الملف في Supabase SQL Editor

-- أعمدة الموقع
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS lat DECIMAL(10, 8);
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS lng DECIMAL(11, 8);

-- أعمدة البحث
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS search_radius INT DEFAULT 2000;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS search_data JSONB DEFAULT '{}';

-- أعمدة السعر والتقييم
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS price_notes TEXT;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS customer_offer DECIMAL(10, 2);
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS customer_rating INT;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS customer_review TEXT;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS rated_at TIMESTAMPTZ;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS price_confirmed_at TIMESTAMPTZ;

-- أعمدة الإلغاء
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS cancelled_by UUID;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS cancel_reason TEXT;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- إعادة تحميل الـ Schema Cache
NOTIFY pgrst, 'reload schema';

SELECT 'تم إضافة جميع الأعمدة بنجاح! ✅' AS result;
