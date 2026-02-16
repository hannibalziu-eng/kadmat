# MASTER FLOW SPEC (Source of Truth)

## Purpose
هذا الملف هو المرجع الرسمي لفلو التطبيق (عميل + فني + باكند). أي تعديل سلوكي يجب أن ينعكس هنا قبل الدمج النهائي.

## Canonical Job Lifecycle
- `pending` -> `searching`
- `pending|searching|no_technician_found` -> `on_the_way` (عند قبول عرض من العميل)
- `on_the_way` -> `arrived` (الفني وصل)
- `arrived` -> `in_progress` (بدء التنفيذ)
- `searching` -> `no_technician_found` (بعد انتهاء البحث)
- `no_technician_found` -> `pending` أو `searching` (retry)
- `in_progress` -> `pending_confirm` (طلب تأكيد الإكمال)
- `pending_confirm` -> `completed`
- `completed` -> `rated`
- `any_open_state` -> `cancelled`

`any_open_state` = `pending`, `searching`, `no_technician_found`, `accepted`, `price_pending`, `on_the_way`, `arrived`, `in_progress`.

## Customer Flow (Official)
1. العميل ينشئ طلب خدمة.
2. يدخل شاشة البحث/الخريطة (`/jobs/:jobId/customer/searching`).
3. العروض تأتي من `job_offers` وتظهر في نفس الشاشة.
4. العميل يختار عرضًا واحدًا (Accept Offer).
5. الطلب ينتقل إلى `on_the_way` مع تثبيت الفني والسعر وقفل الطرفين (عميل/فني) على الطلب النشط.
6. الفني يحدّث التقدم إلى `arrived` ثم `in_progress`.
7. بعدها يتابع مراحل التنفيذ/الإكمال/التقييم.

## Technician Flow (Official)
1. الفني المتصل وموقعه محدث يستقبل الطلبات القريبة.
2. يفتح الطلب من قائمة الطلبات الجديدة.
3. يقدّم عرض سعر.
4. إذا قبل العميل العرض، ينتقل الطلب للفني بشكل حصري إلى حالة `on_the_way`.
5. الفني يحدّث الحالة إلى `arrived` عند الوصول ثم `in_progress` عند بدء العمل.

## Accept Offer Contract
- Endpoint: `POST /api/jobs/:id/accept-offer`
- Input accepted keys: `offerId` + legacy aliases (`offer_id`, `bidId`, `bid_id`).
- Success: `200 { success: true, data: job }`
- Success state target: `job.status = on_the_way` (مع fallback legacy إلى `in_progress` في البيئات غير المحدثة).
- Conflict only when logical race/invalid state: `409 INVALID_STATUS_TRANSITION`
- Lock conflict: `409 ACTIVE_JOB_LOCKED` إذا الفني لديه طلب نشط آخر.
- Server failure (DB/schema issues): `500 SERVER_ERROR`

## Routing Contract
- المصدر التشغيلي: `lib/src/core/router_modular.dart`
- يجب دعم:
  - `/jobs/:jobId/technician/detail`
  - `/jobs/:jobId/technician/bidding`
- أي route غير معروف ضمن job/technician يعمل fallback إلى تفاصيل الطلب.

## Non-Functional Requirements
- لا تظهر رسائل تقنية خام للمستخدم.
- أخطاء API تعتمد عقد موحد (`code`, `message`, `details`).
- لا توجد شاشات placeholder في المسار الأساسي للفني.
