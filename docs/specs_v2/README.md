# Kadmat Smart Bidding System - Technical Specification v2.0 (Cash Only)

## نظرة عامة
نظام مناقصة ذكي للخدمات المنزلية مع دفع كاش ونظام نزاعات يدوي عبر WhatsApp.
الهدف هو إدارة عملية المناقصة بين العملاء والفنيين بشكل عادل وفعال مع ضمان حقوق الطرفين.

## التقنيات
- **Frontend**: Flutter + Riverpod + GoRouter
- **Backend**: Supabase (PostgreSQL + Realtime + Auth)
- **Functions**: Edge Functions (Deno/TypeScript) for Notifications
- **Legacy/Support**: Node.js Backend (Express) for specific complex logic if needed

## الفلو الكامل (User Journey)
1. **Discovery**: العميل يطلب خدمة.
2. **Creation (Waves)**: النظام يرسل الطلب للفنيين تدريجياً (15km -> 50km -> الكل).
3. **Bidding (15 min)**: الفنيون يقدمون عروضهم (السعر والوقت). العميل يرى العروض.
4. **Locked**: العميل يقبل عرضاً. يتم "قفل" الطلب للفني المختار.
5. **Execution**: الفني يصل وينفذ الخدمة.
6. **Cash Payment**: الدفع كاش. الفني يؤكد الاستلام بكود سري من العميل.
7. **Completion/Dispute**: إغلاق الطلب وتقييم، أو رفع نزاع.

## المميزات الفريدة
- **Smart Timer**: مؤقت 15 دقيقة للمزاد، مع تمديد لمرة واحدة لآخر 5 دقائق.
- **Rate Limiting**: حد أقصى (5 عروض/ساعة) للفني لمنع التلاعب.
- **AI Badges**: أوسمة تلقائية للعروض (الأرخص، الأسرع، الأنسب).
- **Waves Geographical**: توسيع نطاق البحث جغرافياً كل دقيقتين إذا لم توجد عروض.
- **Waitlist System**: إذا ألغى الفني المختار، ينتقل الطلب تلقائياً للفني التالي في القائمة.
- **Manual Dispute Resolution**: حل النزاعات يدوياً عبر واتساب كحل سريع وموثوق.

## هيكل الملفات والمواصفات (v2 Specs)
تم إنشاء الملفات التالية في هذا المجلد لتوثيق النظام الجديد:

1.  **01_database_schema.sql**:
    - تعريف الجداول (jobs, bids, users, services, disputes).
    - تعريف الأنواع (ENUMs) للحالات.
    - الفهارس (Indexes) للأداء الجغرافي والزمني.

2.  **02_postgresql_functions.sql**:
    - `accept_bid_and_lock_job_safe`: الدالة الجوهرية لقبول العرض ومنع التضارب.
    - `process_job_waves`: دالة مجدولة لتوسيع نطاق البحث.
    - `handle_technician_cancellation`: إدارة إلغاء الفني ونقل الطلب لقائمة الانتظار.

3.  **03_edge_functions.ts**:
    - كود TypeScript لـ Supabase Edge Functions.
    - معالجة الإشعارات (Push Notifications) عبر FCM عند الأحداث (قبول العرض، دفع، نزاع).

## استراتيجية النشر (Deployment Strategy)
يرجى مراجعة ملف `MIGRATION_GUIDE.md` لمعرفة خطوات تطبيق هذه التغييرات على مشروعك الحالي.
