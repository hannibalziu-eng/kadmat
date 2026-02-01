# Kadmat – Production-Ready Full Workflow

هذا الملف يعرّف ورْك فلو شامل للتطبيق من زاوية تقنية + بزنيس، جاهز للاستخدام مع أي AI Agent أو فريق تطوير للوصول إلى نسخة Production.

يتكوّن من:
- A) App Core Workflow
- B) Customer Journey Workflow
- C) Technician Journey Workflow
- D) Admin & Business Workflow
- E) Security & Compliance Workflow
- F) Observability & Quality Workflow
- G) Advanced Tech Enhancements

حافظ على فصل الطبقات: `core/`, `features/`, مع Domains/Data/Presentation.

---

## A) App Core Workflow

1) التهيئة (App Bootstrap)
- `main.dart`:
  - يهيئ `AppConfig` (بيئات: dev/stage/prod).
  - يلف التطبيق بـ `ProviderScope` (Riverpod).
  - يطبق `KadmatTheme` من `core/app_theme.dart` (يدعم Light/Dark).
  - يحمّل الترجمة من `core/localization/localization_service.dart` (إن وجدت).
  - يستخدم `core/router.dart` + `deep_linking.dart` لتحديد البداية (عميل/فني) حسب حالة الـ Auth.

2) خدمات البنية التحتية (Infrastructure Services)
- Networking:
  - `core/api/api_client.dart` + `endpoints.dart`: إعداد Base URL, interceptors, auth headers, retries (سيتم تعزيزه لاحقاً).
- Storage & Security:
  - `core/security/secure_storage.dart` + `security_providers.dart`.
  - (مستقبلاً) `core/security/encryption_service.dart` لتشفير بيانات حساسة.
  - `session_manager.dart` لإدارة الجلسات وتجديد التوكن.
- Notifications & Background:
  - `fcm_service.dart`, `notification_service.dart`, `local_notifications.dart`.
  - ربط FCM مع Routes (Jobs, Messages, Wallet).
- Performance:
  - `performance/cache_manager.dart`, `offline_service.dart`, `deferred_loading.dart`, `memory_management.dart`.
- Error Handling:
  - استخدام `error_dialog.dart`, `error_retry_widget.dart`, `kadmat_toast.dart`.
  - (مستقبلاً) `core/error_handling/global_error_handler.dart` لالتقاط الأخطاء العامة.

---

## B) Customer Journey Workflow

1) Onboarding & Auth (Customer)
- Screens:
  - `welcome_screen.dart` → اختيار العميل/الفني، عرض مقدمة، زر التسجيل/الدخول.
  - `login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart`.
  - (مستقبلاً) `phone_verification_screen.dart`, `terms_acceptance_screen.dart`.
- Logic:
  - `auth_controller.dart` + `auth_repository.dart`:
    - تسجيل/دخول بكلمة مرور ورقم هاتف/إيميل.
    - إدارة توكن Supabase / JWT.
    - تخزين التوكن في `secure_storage`.
  - `session_manager.dart` (مستقبلاً): تجديد التوكن، تسجيل الخروج من كل الأجهزة.

2) Home & Services
- Screens:
  - `home_screen.dart`: عرض الخدمات حسب التصنيفات.
  - `service_details_screen.dart`: تفاصيل خدمة، مدة تقديرية، السعر، التقييم.
- Logic:
  - `service.dart` (Domain + Freezed).
  - `service_repository.dart` (Data): جلب قائمة الخدمات مع caching.
  - (مستقبلاً) Favorites:
    - `favorite_services_screen.dart` + `favorites_repository.dart`.

3) Booking Flow
- Screens:
  - `booking_screen.dart`: اختيار الخدمة، وصف المشكلة، العنوان، الوقت، صور اختيارية.
- Logic:
  - `booking_model.dart` (Domain).
  - `booking_repository.dart` (Data): إنشاء Booking في الـ Backend.
  - (مستقبلاً) Coupons:
    - توسيع `booking_model` بحقول `couponCode`, `discountAmount`.

4) Jobs & Tracking (Customer)
- Screens:
  - `customer_active_job_screen.dart`: عرض الوظيفة المفتوحة.
  - `customer_job_tracking_screen.dart` + `tracking_screen.dart`:
    - تتبع الفني على الخريطة/حالة الطلب.
  - `customer_service_completion_confirmation_screen.dart`: تأكيد إتمام الخدمة.
  - `rating_screen.dart`: تقييم الفني بعد انتهاء الخدمة.
- Logic:
  - `job.dart`, `job_status.dart` (Domain).
  - `job_repository.dart` (Data): CRUD على الطلبات.
  - `tracking_repository.dart`: إحضار/تحديث موقع الفني.

5) Wallet (Customer)
- Screens:
  - `customer_wallet_screen.dart`: عرض الرصيد + العمليات.
- Logic:
  - `wallet.dart` (Domain).
  - `wallet_repository.dart`: رصيد، معاملات، خصومات، عمليات دفع.
  - `wallet_controller.dart`: التحكم في حالة المحفظة.

6) Messages (Customer Side)
- Screens:
  - `messages_screen.dart`: محادثة مع الفني.
- Logic:
  - `message.dart` (Domain).
  - `messages_repository.dart` (Data): جلب/إرسال/Real-time Stream.
  - `messages_controller.dart`: إدارة قائمة الرسائل، الإدخال، التمرير.

7) Profile & Settings (Customer)
- Screens:
  - `profile_screen.dart`: بيانات الحساب، إعدادات، روابط لمحفظة/مفضلة.
  - `edit_profile_screen.dart`: تعديل البيانات.
  - `account_security_screen.dart`: تغيير كلمة المرور، إدارة الأمان.
  - (مستقبلاً) `notification_preferences_screen.dart`, `privacy_policy_screen.dart`, `terms_screen.dart`.

---

## C) Technician Journey Workflow

1) Onboarding & Auth (Technician)
- Screens:
  - `technician_landing_screen.dart`: تعريف للفني، زر بدء.
  - `technician_login_screen.dart`, `technician_register_screen.dart`.
  - (مستقبلاً) `document_upload_screen.dart` (رفع هوية/رخصة), KYC.
- Logic:
  - استخدام `auth_repository.dart` مع Endpoints فني.
  - حفظ نوع المستخدم (Technician) في Session.

2) Technician Main Shell
- Screens:
  - `technician_main_screen.dart`: هيكل التبويبات.
  - Tabs نموذجيًا:
    - Dashboard → `technician_dashboard_screen.dart`.
    - Requests → `technician_requests_screen.dart`.
    - Wallet → `technician_wallet_screen.dart`.
    - Profile → `technician_profile_screen.dart`.

3) Requests & Jobs (Technician)
- Screens:
  - `technician_requests_screen.dart`: الطلبات الجديدة.
  - `technician_job_detail_screen.dart`: تفاصيل الطلب، قبول/رفض، بدء/إنهاء.
  - `pre_service_photo_screen.dart`, `post_service_photo_screen.dart`.
  - `technician_price_input_screen.dart`: إدخال السعر المقترح.
- Logic:
  - `technician_repository.dart` + `job_repository.dart`.
  - تفاعل مع `tracking_repository.dart` لتحديث موقع الفني.
  - استخدام `photo_upload_service.dart` + `photo_upload_provider.dart` لرفع الصور.

4) Technician Wallet & Earnings
- Screens:
  - `technician_wallet_screen.dart`: الأرباح، الرصيد، طلب السحب.
- Logic:
  - إعادة استخدام `wallet_repository.dart`, `wallet_controller.dart` مع Role = Technician.

5) Technician Profile & Portfolio
- Screens:
  - `technician_profile_screen.dart`: البيانات، التقييم، عدد الطلبات.
  - `edit_technician_profile_screen.dart`.
  - `add_portfolio_work_screen.dart`: صور أعمال سابقة.
- Logic:
  - `technician_repository.dart`: تحديث بيانات الفني والـ Portfolio.

---

## D) Admin & Business Workflow

> يمكن تنفيذ لوحة تحكم بسيطة داخل نفس المشروع (Web) أو عبر مشروع منفصل. هنا تعريف مبدئي لو تم بناؤها داخل `features/admin/`.

1) Admin Access
- Screens (Web-only أو Role-based داخل نفس التطبيق):
  - `admin_dashboard_screen.dart` (داخل `features/admin/presentation`).
- Features:
  - عرض إحصائيات: عدد الطلبات، الإيرادات، عدد الفنيين النشطين، الشكاوى.

2) Commission & Pricing
- Logic:
  - `commission_service.dart` (في `core/business` أو `features/wallet/business`).
  - حساب نسبة المنصة من كل Job.
  - دعم ضرائب/رسوم إضافية.

3) Regions & Zones Management
- Logic:
  - تعريف مناطق الخدمة، تسعير مختلف حسب المدينة أو الحي.
  - تخزينها في `regions_repository.dart` + Models.

4) Disputes & Support
- Features:
  - `features/support/`:
    - `ticket.dart` (Domain).
    - `support_screens.dart` (Presentation): فتح شكوى، متابعة حالة الشكوى.

---

## E) Security & Compliance Workflow

1) Privacy & Terms
- Screens:
  - `privacy_policy_screen.dart`.
  - `terms_and_conditions_screen.dart`.
- Logic:
  - إجبار المستخدم على قبول الشروط في أول تسجيل (`terms_acceptance_screen.dart`).

2) KYC & Verification (Technicians)
- Screens:
  - `document_upload_screen.dart`: رفع هوية/سجل تجاري.
- Logic:
  - تخزين حالة التحقق في `technician_profile` (Pending/Verified/Rejected).
  - تقييد وصول الفني للطلبات إلا بعد التحقق.

3) Session & Encryption
- Services:
  - `session_manager.dart` في `core/security`:
    - تجديد التوكن، كشف الجلسات المنتهية.
  - `encryption_service.dart`:
    - تشفير بيانات حساسة في التخزين المحلي.

4) Multi-Factor Authentication (MFA)
- (خيار متقدم): إضافة خطوة رمز SMS/OTP أثناء تسجيل الدخول، خاصة للفنيين.

---

## F) Observability & Quality Workflow

1) Analytics
- `core/analytics/analytics_service.dart` + `events.dart`:
  - تعريف Events مثل:
    - `service_viewed`.
    - `job_created`.
    - `job_completed`.
    - `message_sent`.
    - `wallet_topped_up`.
  - إرسال الأحداث إلى Firebase Analytics أو بديل.

2) Crash Reporting
- دمج Crashlytics (أو Sentry):
  - تهيئة في `main.dart`.
  - ربط مع `global_error_handler.dart` لإرسال الأخطاء غير المتوقعة.

3) Quality Gates
- CI/CD (مقترح):
  - تشغيل:
    - `flutter analyze`.
    - `flutter test` (يوجد الآن `job_repository_test.dart`, `wallet_repository_test.dart`).
  - رفض الـ build إذا كان هناك Lint Errors حرجة.

---

## G) Advanced Technical Enhancements

1) Networking Robustness
- إضافة:
  - Retry Policies في `api_client.dart` (محاولات إعادة في حالات معينة).
  - Rate Limiting أو Queue للـ requests لو احتجت.

2) Background Sync
- للمحادثات والطلبات:
  - استخدام background fetch أو WorkManager (Android) لمزامنة الرسائل/الطلبات عند فتح التطبيق.

3) Image Optimization
- في `photo_upload_service.dart`:
  - ضغط الصور قبل الرفع.
  - تقليل الأبعاد العالية.

4) Pagination & Infinite Scroll
- تطبيق Pagination في:
  - قوائم الطلبات (Jobs lists).
  - الرسائل (Messages history).
  - الإشعارات (Notifications).

---

## Usage Notes for AI Agents

- عند تنفيذ أي ميزة جديدة:
  1. حدد الـ Feature (Customer, Technician, Wallet, Messages, Notifications, Admin, Security).
  2. عدّل Domain (Models + Freezed) أولاً.
  3. حدث Data (Repositories + API/ Supabase integration).
  4. عدّل Controllers (Riverpod Notifiers/Providers).
  5. عدّل UI (Screens/Widgets) مع إعادة استخدام الـ core widgets.
  6. اربط التغيير مع Router و Notifications و Analytics إذا كان له أثر على UX.

- تأكد من تشغيل:
  - `flutter pub run build_runner build --delete-conflicting-outputs`
  - `flutter analyze lib/`
  - اختبارات الوحدة المتاحة + إضافة اختبارات جديدة عند تعديل Repositories أو Business Logic.

هذا الورك فلو يمثل صورة شاملة لتطبيق Kadmat كمنتج حقيقي جاهز للإنتاج، مع مساحات واضحة للتوسع الأمني والتجاري وتقوية المراقبة والتحليلات.