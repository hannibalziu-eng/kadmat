# Kadmat – Execution Tasks for AI Agents

## Overview
هذا الملف يحتوي على Tasks مفصلة ومهيكلة يمكن لأي ذكاء اصطناعي أو مطور استخدامها لتنفيذ تعديلات على تطبيق Kadmat خطوة بخطوة. الرجاء الالتزام بالـ architecture الحالي (Repositories, Controllers, Riverpod, Router) وعدم كسر التقسيم feature-based.

التقسيم:
- Phase 1 – Critical Fixes
- Phase 2 – Messages Feature
- Phase 3 – Notifications & FCM
- Phase 4 – Wallet & Technician Profile TODOs
- Phase 5 – Cleanup & Refactors

كل مهمة تحتوي على:
- الوصف
- الملفات المتأثرة
- خطوات التنفيذ

---

## Phase 1 – Critical Fixes (Stability First)

### Task 1.1 – Fix wallet.dart Annotations
- **Goal**: إصلاح أخطاء `invalid_annotation_target` في `wallet.dart` وتشغيل التوليد بنجاح.
- **Files**:
  - `lib/src/features/wallet/domain/wallet.dart`
- **Steps**:
  1. افتح ملف `wallet.dart` وابحث عن أي `@JsonKey` أو annotations داخل أماكن غير مسموح بها (مثلاً فوق constructors أو فوق fields غير مدعومة).
  2. عدّل annotations لتكون فوق الحقول الصحيحة فقط (properties داخل الـ class). تأكد أن أسماء الـ keys تطابق API.
  3. تأكد أن الكلاس معرف باستخدام `@freezed` وبشكل متوافق مع باقي الـ models في المشروع.
  4. شغّل:
     - `flutter pub run build_runner build --delete-conflicting-outputs`
  5. تأكد أن ملفات `wallet.freezed.dart` و `wallet.g.dart` تولدت بدون Errors.

### Task 1.2 – Update Deprecated Riverpod Ref Types
- **Goal**: تحديث جميع أماكن استخدام ref/WidgetRef القديمة إلى النسخة المناسبة لـ Riverpod المستخدمة.
- **Files** (أمثلة – يجب البحث عام):
  - أي ملفات تحتوي على `ScopedReader`, `Ref`, أو تحذيرات deprecated من Riverpod.
- **Steps**:
  1. شغّل `flutter analyze lib/` واحصل على قائمة ملفات التحذيرات المتعلقة بـ Riverpod.
  2. لكل ملف:
     - استبدل الأنواع القديمة بالأنواع الموصى بها (مثل `WidgetRef`, `Ref`, أو `AutoDisposeRef` حسب النمط المستخدم في باقي المشروع).
     - اتبع نفس الـ pattern المستخدم في الملفات الأحدث داخل المشروع.
  3. تأكد أن جميع الـ providers والـ controllers تبنى بدون تحذيرات deprecated.

---

## Phase 2 – Messages Feature (Real-time Chat)

### Task 2.1 – Create Message Model
- **Goal**: إنشاء model للمحادثة يدعم JSON + Freezed.
- **Files**:
  - New: `lib/src/features/messages/domain/message.dart`
- **Steps**:
  1. أنشئ ملف `message.dart` داخل `lib/src/features/messages/domain/`.
  2. أنشئ كلاس Freezed باسم `Message` يحتوي على الحقول الأساسية:
     - `String id`
     - `String jobId`
     - `String senderId`
     - `String receiverId`
     - `String content`
     - `DateTime createdAt`
     - `bool isRead` (اختياري)
  3. أضف `factory Message.fromJson(Map<String, dynamic> json)`.
  4. توليد الملفات:
     - `flutter pub run build_runner build --delete-conflicting-outputs`

### Task 2.2 – Implement MessagesRepository
- **Goal**: إنشاء Repository لقراءة وكتابة الرسائل وربط Real-time مع Supabase.
- **Files**:
  - New: `lib/src/features/messages/data/messages_repository.dart`
- **Steps**:
  1. أنشئ كلاس `MessagesRepository` باتباع نفس pattern باقي الـ repositories (مثل `job_repository.dart`).
  2. أضف دوال أساسية:
     - `Future<List<Message>> getMessagesForJob(String jobId)`
     - `Future<void> sendMessage({required String jobId, required String content, required String receiverId})`
     - `Stream<Message> subscribeToMessages(String jobId)` (Real-time من Supabase).
  3. استخدم `api_client` أو Supabase client (حسب ما هو معتمد في المشروع) لعمليات CRUD.
  4. أضف Provider لـ `MessagesRepository` (Riverpod) في ملف مناسب (مثلاً `messages_repository.dart` نفسه أو ملف providers مستقل).

### Task 2.3 – Messages Controller & Providers
- **Goal**: إدارة حالة الرسائل وربطها بالـ UI.
- **Files**:
  - New/Updated: `lib/src/features/messages/presentation/messages_controller.dart` (أو اسم مشابه)
  - `lib/src/features/messages/presentation/messages_screen.dart`
- **Steps**:
  1. أنشئ Controller (Notifier/AsyncNotifier) لإدارة:
     - قائمة الرسائل الحالية.
     - إرسال رسالة جديدة.
     - الاشتراك في stream للرسائل الجديدة.
  2. أضف Providers:
     - Provider للـ controller.
     - Provider أو StreamProvider للـ messages حسب تصميمك.
  3. في `messages_screen.dart`:
     - اربط الـ UI بـ controller/StreamProvider.
     - عرض قائمة الرسائل.
     - حقل إدخال نص + زر إرسال.
     - Scroll إلى آخر رسالة عند التحديث.

### Task 2.4 – Real-time + Notifications Integration (Messages)
- **Goal**: ربط وصول رسالة جديدة بإشعار للمستخدم.
- **Files**:
  - `lib/src/core/services/notification_service.dart`
  - `lib/src/features/notifications/data/notification_repository.dart`
- **Steps**:
  1. عند استقبال رسالة جديدة من Stream Supabase (Task 2.2):
     - أضف call لحفظ الإشعار في `notification_repository` إن كان مناسب.
  2. إعداد trigger في الـ backend (Supabase/Server) لإرسال FCM عند إدخال صف جديد في جدول messages (خارج هذا المشروع لكن يجب توثيقه).

---

## Phase 3 – Notifications & FCM

### Task 3.1 – Complete FCM Setup
- **Goal**: تفعيل استقبال الإشعارات في foreground/background وربط الـ token بالـ Backend.
- **Files**:
  - `lib/src/core/services/fcm_service.dart`
  - `lib/src/core/services/notification_service.dart`
- **Steps**:
  1. في `fcm_service.dart`:
     - طلب صلاحيات الإشعارات (خاصة iOS).
     - الحصول على FCM token وحفظه في الـ backend/Supabase.
     - إعداد handlers لحالات foreground/background.
  2. في `notification_service.dart`:
     - توحيد المنطق لاستقبال الإشعارات (order status change, new message, wallet updates).
     - تمرير payload المناسب لشاشات معينة عبر الـ router.

### Task 3.2 – Notifications for Job Status Changes
- **Goal**: عند تغيير حالة الطلب، يصل إشعار للعميل/الفني.
- **Files**:
  - `lib/src/features/jobs/data/job_repository.dart`
  - `lib/src/features/notifications/data/notification_repository.dart`
- **Steps**:
  1. تأكد أن الـ backend يرسل FCM أو يسجل notification event عند تغيير حالة الـ Job.
  2. في التطبيق، عرّف types للإشعارات (مثلاً: `job_status_changed`).
  3. عند استلام إشعار بهذا النوع، استخدم الـ router لفتح شاشة الـ Job المناسبة.

### Task 3.3 – Notifications for New Messages
- **Goal**: عند وصول رسالة جديدة، يصل إشعار للمستلم.
- **Files**:
  - نفس ملفات Task 2.4 + `notifications_screen.dart`.
- **Steps**:
  1. استخدام نفس البنية العامة للإشعارات لتخزين إشعار رسالة جديدة.
  2. عند الضغط على الإشعار، فتح `messages_screen.dart` مع تمرير `jobId` أو `conversationId`.

---

## Phase 4 – Wallet & Technician Profile TODOs

### Task 4.1 – Finalize Wallet Flows
- **Goal**: جعل شاشات المحفظة تعمل بكامل المنطق (عميل + فني).
- **Files**:
  - `lib/src/features/wallet/domain/wallet.dart`
  - `lib/src/features/wallet/data/wallet_repository.dart`
  - `lib/src/features/wallet/presentation/wallet_controller.dart`
  - `lib/src/features/profile/presentation/customer_wallet_screen.dart`
  - `lib/src/features/technician/presentation/wallet/technician_wallet_screen.dart`
- **Steps**:
  1. مراجعة واجهة `Wallet` model والتأكد أنها تغطي: الرصيد الحالي، المعاملات، type (in/out)، التاريخ.
  2. في `wallet_repository.dart`:
     - تأكد من وجود دوال: `getWallet`, `getTransactions`, وربما `topUp`, `withdraw`.
  3. في `wallet_controller.dart`:
     - إدارة الحالة loading/error/data لشاشات المحفظة.
  4. ربط `customer_wallet_screen.dart` و `technician_wallet_screen.dart` مع controller.

### Task 4.2 – Handle Technician Profile TODOs
- **Goal**: إكمال وظائف رئيسية في ملف الفني.
- **Files (مع TODOs)**:
  - `lib/src/features/technician/presentation/profile/add_portfolio_work_screen.dart`
  - `lib/src/features/technician/presentation/profile/edit_technician_profile_screen.dart`
  - `lib/src/features/technician/presentation/technician_wallet_screen.dart`
  - `lib/src/features/technician/presentation/requests/technician_requests_screen.dart`
- **Steps**:
  1. افتح كل ملف وابحث عن `TODO`.
  2. نفذ الـ TODOs التي تؤثر على:
     - إكمال بيانات الفني (اسم، مهارات، مدينة، أسعار تقريبية).
     - عرض وقبول الطلبات الجديدة للفني.
     - عرض المحفظة للفني.
  3. استخدم نفس الـ repositories والـ controllers الموجودة بدلاً من منطق جديد.

---

## Phase 5 – Cleanup & Refactors

### Task 5.1 – Replace Deprecated withOpacity
- **Goal**: إزالة استخدام `withOpacity` deprecated.
- **Files**:
  - أي ملفات تحتوي على `.withOpacity(` حسب `flutter analyze` أو search.
- **Steps**:
  1. استخدم خاصية البحث في المشروع عن `withOpacity(`.
  2. استبدلها بالبديل الموصى به (مثل `withValues` أو ما تقترحه نسخة Flutter الحالية).
  3. تأكد أن الـ UI لم يتغير شكله بشكل غير مرغوب.

### Task 5.2 – Fix use_build_context_synchronously
- **Goal**: منع استخدام `BuildContext` بعد await بدون check.
- **Files**:
  - الملفات التي تحتوي تحذير `use_build_context_synchronously`.
- **Steps**:
  1. بعد كل `await` في دوال تستخدم `context`, أضف:
     - `if (!context.mounted) return;`
  2. تأكد أن الدوال لا تكمل التنفيذ عند إغلاق الشاشة.

### Task 5.3 – Remove Unused Imports & Variables
- **Goal**: تنظيف الكود وتحسين القراءة.
- **Files**:
  - عدة ملفات في `lib/src/...` حسب Lint.
- **Steps**:
  1. شغّل `flutter analyze lib/` وحدد الملفات.
  2. استخدم أدوات IDE لإزالة `unused import` و `unused local variables`.

### Task 5.4 – Resolve Remaining TODOs
- **Goal**: إغلاق كل TODOs المهمة أو تحويلها إلى تذاكر رسمية.
- **Files (جزء منها)**:
  - `technician_wallet_screen.dart`
  - `add_portfolio_work_screen.dart`
  - `fcm_service.dart`
  - `edit_technician_profile_screen.dart`
  - `technician_requests_screen.dart`
  - `searching_for_technician_screen.dart`
  - `customer_active_job_screen.dart`
  - `customer_service_completion_confirmation_screen.dart`
  - `customer_job_tracking_screen.dart`
  - `customer_screens.dart`
  - `technician_screens.dart`
  - `technician_price_input_screen.dart`
  - `edit_profile_screen.dart`
  - `account_security_screen.dart`
- **Steps**:
  1. افتح كل ملف وابحث عن `TODO`.
  2. صنّف الـ TODOs:
     - Must have قبل الإطلاق.
     - Nice to have لاحقاً.
  3. نفذ الـ Must have، ودوّن الباقي في تذاكر مستقلة إن لزم.

---

## Useful Commands
- Regenerate code:
  - `flutter pub run build_runner build --delete-conflicting-outputs`
- Analyze code:
  - `flutter analyze lib/`
- Run app (web):
  - `flutter run -d chrome --web-port=8080`

هذا الملف جاهز لإعطائه لأي نموذج ذكاء اصطناعي أو مطور ليعمل مباشرة على Tasks واضحة ومرتبة بدون ضياع في بنية المشروع.