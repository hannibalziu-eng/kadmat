# Prompt جاهز لـ Playwright E2E (مخصص لـ Kadmat)

استخدم هذا البرومبت عند توليد/توسيع اختبارات `@playwright/test` لمشروع Kadmat:

## الهدف

بناء اختبارات E2E حقيقية لتطبيق Flutter-Web (Kadmat) مع تركيز على:
- سلامة التنقل بين الصفحات
- اتساق البيانات بين صفحات العميل والفني
- كشف أي بيانات Mock في الشاشات الإنتاجية
- تغطية أدوار: Guest / Customer / Technician

## متطلبات التهيئة

- استخدم المسارات الفعلية الحالية للتطبيق:
  - `/welcome`, `/login`, `/register`, `/forgot-password`
  - `/technician/landing`, `/technician/login`, `/technician/register`, `/technician/home`
  - `/customer/create-request`, `/notifications`
  - `/technician-profile/:technicianId`
- لا تعتمد على مسارات غير موجودة.
- لا تفترض أن صفحة `service-details` قابلة للفتح URL مباشر بدون `state.extra`.

## Environment Variables

- `BASE_URL`
- `API_BASE`
- `CUSTOMER_EMAIL`, `CUSTOMER_PASS`
- `TECHNICIAN_EMAIL`, `TECHNICIAN_PASS`
- اختياري: `CUSTOMER_TOKEN`, `TECHNICIAN_TOKEN`, `TECHNICIAN_PUBLIC_ID`, `STRICT_REAL_DATA`

## Scope المطلوب

1. Authentication + Role Guards
- Guest لا يصل للصفحات المحمية.
- Customer لا يمكنه البقاء في مساحة الفني الخاصة.
- Technician يُعاد توجيهه لمساحة الفني.

2. Customer Journey
- تسجيل دخول العميل
- التنقل بين تبويبات العميل الأساسية
- الوصول لصفحة إنشاء طلب والتحقق من أقسام النموذج
- فتح بروفايل فني عام والتحقق أن البيانات من API/Supabase

3. Technician Journey
- تسجيل دخول الفني
- التنقل بين تبويبات الفني
- فحص API المحفظة/الإشعارات باستخدام token

4. Data Integrity Checks
- إذا ظهرت بطاقات رسائل Mock بدون نداءات `/api/messages`:
  - سجّل Defect annotation
  - واجعل الاختبار يفشل فقط عند `STRICT_REAL_DATA=true`

5. Network Resilience
- Chromium فقط: 3G / 4G / Offline عبر CDP
- تأكيد ظهور حالة خطأ مناسبة عند Offline ثم التعافي بعد استعادة الشبكة

6. Reporting
- تفعيل trace + screenshots + video عند الفشل
- توليد HTML report + JSON report
- توليد coverage matrix من نتائج التشغيل

## ملاحظات مهمة

- استخدم Playwright auto-waiting ولا تستخدم sleep.
- الاختبارات يجب أن تكون قابلة للتشغيل في Chromium/Firefox/WebKit + iPhone 14 Pro emulation.
- عند اكتشاف تناقض بين البيانات المعروضة وبيانات الـ API، اعتبره defect واضح.
