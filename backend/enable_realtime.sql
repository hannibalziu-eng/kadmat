-- ⚡️ تفعيل Realtime لجدول jobs
-- شغل هذا الكود في SQL Editor مرة واحدة فقط

BEGIN;
  -- إضافة جدول jobs إلى قائمة النشر (Realtime)
  ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
COMMIT;

-- ملاحظة: إذا ظهر لك خطأ يقول:
-- relation "jobs" is already member of publication "supabase_realtime"
-- فهذا يعني أن التفعيل تم بالفعل، ولا داعي للقلق! ✅
