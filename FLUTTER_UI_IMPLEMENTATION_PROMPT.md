# 🚀 KADMAT Flutter UI Implementation - Complete Specification
## Production-Ready Flutter Screens for Job Post-Acceptance Flow

**Document Version:** 1.0 Implementation Guide  
**Status:** Ready for Implementation  
**Target AI Tool:** Google Antigravity, Claude 3.5, GPT-4  
**Language:** English (Primary) + العربية (Secondary)  
**Date:** December 7, 2025  
**Framework:** Flutter + Riverpod + GoRouter

---

## 📑 Table of Contents

1. [Project Context](#project-context)
2. [Current Status Analysis](#current-status-analysis)
3. [Implementation Scope](#implementation-scope)
4. [Customer App - Screen Specifications](#customer-app---screen-specifications)
5. [Technician App - Screen Specifications](#technician-app---screen-specifications)
6. [Reusable Components & Utilities](#reusable-components--utilities)
7. [Navigation & Routing](#navigation--routing)
8. [Code Standards & Best Practices](#code-standards--best-practices)
9. [Testing Requirements](#testing-requirements)

---

## 🎯 Project Context

### KADMAT Overview
**KADMAT** is an on-demand service marketplace for Arabic markets (Saudi Arabia, UAE).
- Customers request services (AC repair, plumbing, electrical, etc.)
- Technicians accept and complete services
- Real-time status updates, pricing negotiation, and ratings

### Tech Stack
```
Frontend:          Flutter (iOS + Android)
State Management:  Riverpod (no_rebuild family)
Routing:           GoRouter with named routes
API Client:        Dio + Retrofit
JSON Serialization: json_serializable
Localization:      Flutter intl (l10n)
Testing:           Widgettest + Integration tests
```

### Backend Status ✅
**Backend is 100% Complete:**
- Job State Machine ✅ (9 states with valid transitions)
- Response Formatter ✅ (standardized API responses)
- Job Service ✅ (accept, setPrice, confirmPrice, complete, rate)
- Job Controller ✅ (all endpoints working)
- Job Retry Scheduler ✅ (automatic retry after no technicians found)
- Proper error handling ✅
- Full authentication ✅

**Available API Endpoints:**
```
POST   /api/jobs                    - Create job
GET    /api/jobs/:id               - Get job details (with enriched data)
POST   /api/jobs/:id/accept        - Accept job
POST   /api/jobs/:id/set-price     - Set price
POST   /api/jobs/:id/confirm-price - Confirm price
POST   /api/jobs/:id/complete      - Complete job
POST   /api/jobs/:id/rate          - Rate technician
POST   /api/jobs/:id/cancel        - Cancel job
GET    /api/jobs                   - List my jobs (with pagination)
GET    /api/jobs/nearby            - Get nearby jobs
```

---

## 📊 Current Status Analysis

### What's Already Built
✅ Backend: 100% complete  
✅ Database: PostgreSQL + PostGIS + RLS policies  
✅ Authentication: Supabase Auth (JWT)  
✅ API: All job endpoints working  

### What Needs to be Built
❌ Flutter Jobs Feature: 0% (completely missing)
- No screens for post-acceptance flow
- No job status visualization
- No polling/real-time updates
- No reusable components
- No navigation setup

### File Structure Currently
```
lib/
├── src/
│   ├── core/
│   │   ├── api/
│   │   ├── router/
│   │   ├── security/
│   │   └── services/
│   ├── features/
│   │   ├── auth/          ✅ EXISTS
│   │   ├── booking/       ✅ EXISTS
│   │   ├── home/          ✅ EXISTS
│   │   ├── jobs/          ❌ MISSING - NEEDS CREATION
│   │   ├── notifications/ ✅ EXISTS
│   │   ├── wallet/        ✅ EXISTS
│   │   └── ...
│   └── common_widgets/
│
backend/ ✅ COMPLETE
├── src/
│   ├── controllers/
│   ├── services/
│   ├── utils/
│   ├── routes/
│   └── index.js
```

---

## 🎯 Implementation Scope

### What You Need to Build (Step-by-Step)

**Priority 1 - Core Screens (Critical Path)**
1. Customer Searching Screen (status: pending/searching)
2. Technician Found Screen (status: accepted)
3. Price Offer Screen (status: price_pending)
4. In Progress Screen (status: in_progress)
5. Rate Technician Screen (status: completed)
6. Job Completed Summary Screen (status: rated)

**Priority 2 - Technician Screens**
1. Job Accepted Confirmation Screen
2. Set Price Screen
3. Waiting for Confirmation Screen
4. In Progress Screen
5. Job Completed Summary Screen

**Priority 3 - Reusable Components**
1. JobStatusBadge Widget
2. ProfileCard Widget
3. PriceCard Widget
4. JobPollingController (Riverpod)
5. Error Handling Utilities
6. Loading States

**Priority 4 - Infrastructure**
1. Navigation Routes
2. API Integration
3. Error Handling
4. Localization

---

## 👥 Customer App - Screen Specifications

### Screen 1: "Searching for Technician"
**File:** `lib/src/features/jobs/presentation/screens/customer_searching_screen.dart`

**When to Show:** Job status = `pending` or `searching`

**UI Components:**
- Animated search icon (spinning 360°)
- "جاري البحث عن فني..." heading
- Job details card (service icon, name, location, price)
- Elapsed time counter
- "إلغاء الطلب" button (red outline)
- Auto-refresh GET `/api/jobs/{id}` every 3 seconds

**Behavior:**
- When status changes to `accepted` → auto-navigate to "Technician Found"
- On 404 error → show "Job no longer exists"
- On network error → show retry button

**Code Structure:**
```dart
class CustomerSearchingScreen extends ConsumerWidget {
  final String jobId;
  
  // Poll job status every 3 seconds
  // Handle status transitions
  // Manage error states
}
```

---

### Screen 2: "Technician Found"
**File:** `lib/src/features/jobs/presentation/screens/customer_technician_found_screen.dart`

**When to Show:** Job status = `accepted` AND `technician_id` is set

**UI Components:**
- Success badge "✅ تم العثور على فني"
- **Technician Card** (prominent, with avatar):
  - Large circular avatar (from `technician.profile_image_url`)
  - Name, rating (⭐⭐⭐⭐⭐), completed jobs count
  - Phone number
  - Call button (green, large, clickable)
  - Message button (blue outline)
- Service & location details
- Timeline showing:
  - ✅ طلب تم إنشاؤه
  - ✅ تم العثور على فني
  - ⏳ في انتظار تحديد السعر
- "عرض الموقع على الخريطة" button
- "إلغاء الطلب" button (red outline)

**Behavior:**
- Auto-poll every 5 seconds
- When status → `price_pending` → auto-navigate to "Price Offer"
- Call button opens phone dialer
- Message button opens WhatsApp (or SMS fallback)

---

### Screen 3: "Price Offer"
**File:** `lib/src/features/jobs/presentation/screens/customer_price_offer_screen.dart`

**When to Show:** Job status = `price_pending`

**UI Components:**
- Status badge "💰 عرض سعر جديد"
- **Price Comparison Card:**
  - "السعر المتوقع: SAR {initial_price}" (gray, strikethrough)
  - "عرض الفني: SAR {technician_price}" (large, green, bold)
  - Breakdown:
    - السعر: SAR X
    - رسوم المنصة (10%): -SAR Y
    - **إجمالي للفني:** SAR (X - Y) ← green highlight
- Technician notes (if provided): "ملاحظات: {notes}"
- Technician card (compact)
- "تأكيد السعر" button (green, primary, 56px height)
- "رفض والإلغاء" button (red outline)

**Behavior on "Confirm Price":**
- Call `POST /api/jobs/{id}/confirm-price`
- Show loading dialog with spinner
- On success:
  - Toast: "✅ تم تأكيد السعر"
  - Auto-navigate to "In Progress"
- On error:
  - Show error dialog with error message
  - Provide "إعادة المحاولة" button

---

### Screen 4: "In Progress"
**File:** `lib/src/features/jobs/presentation/screens/customer_in_progress_screen.dart`

**When to Show:** Job status = `in_progress`

**UI Components:**
- Status badge "⚙️ جاري تنفيذ الخدمة"
- Technician info card (compact):
  - Avatar, name, rating
  - Location address
  - Time elapsed: "منذ 15 دقيقة"
- **Action Buttons:**
  - "اتصال" button (green, with phone icon)
  - "رسالة" button (blue)
  - "طلب دعم" button (orange)
- Service details card
- Map preview (if location tracking available)
- Timeline showing progress

**Behavior:**
- Auto-poll every 5 seconds
- When status → `completed` → auto-navigate to "Rate"
- Call, message, support buttons are functional
- Show real-time location if available

---

### Screen 5: "Rate Technician"
**File:** `lib/src/features/jobs/presentation/screens/customer_rate_screen.dart`

**When to Show:** Job status = `completed`

**UI Components:**
- Success badge "✅ تم إنهاء الخدمة"
- Job summary card:
  - Service name, date, final price
- **Rating Section:**
  - "كيف كانت تجربتك؟" heading
  - 5-star interactive rating widget
    - Initially 0 stars
    - Tap to select (1-5)
    - Show selected count: "تقييم رائع! 5 نجوم"
- Optional review text field:
  - "هل تريد إضافة ملاحظة؟" (max 250 chars)
  - Counter: "100/250"
- Technician card (small)
- "إرسال التقييم" button (green, primary)
- "تخطي" button (outline)

**Behavior on "Submit Rating":**
- Validate rating >= 1
- Call `POST /api/jobs/{id}/rate` with { rating, review }
- Show loading dialog
- On success:
  - Toast: "✅ شكراً! تم حفظ تقييمك"
  - Wait 1 second
  - Auto-navigate to "Completed Summary"
- On error:
  - Show error dialog with retry option

---

### Screen 6: "Job Completed Summary"
**File:** `lib/src/features/jobs/presentation/screens/customer_completed_summary_screen.dart`

**When to Show:** Job status = `rated` or `completed` (after rating)

**UI Components:**
- Success badge "🎉 تم إكمال الطلب بنجاح"
- **Job Summary Card:**
  - Service name & icon
  - Technician name & avatar
  - Date completed: "اكتمل في 2025-12-07 18:45"
  - Final price: "SAR 250"
- **Your Rating Display:**
  - ⭐⭐⭐⭐⭐ (5 stars)
  - "تقييم رائع! الخدمة ممتازة"
  - "ملاحظتك: (review text)"
- Technician info card
- **Action Buttons:**
  - "طلب الفني نفسه" button (blue)
  - "طلب خدمة أخرى" button (green, primary)
  - "عرض الفاتورة" button (outline)
- "رجوع للرئيسية" link at bottom

---

## 🔧 Technician App - Screen Specifications

### Screen 1: "Job Accepted Confirmation"
**File:** `lib/src/features/jobs/presentation/screens/technician_accepted_confirmation_screen.dart`

**When to Show:** Just after technician accepts a job (status = `accepted`)

**UI Components:**
- Success badge "✅ تم قبول الطلب"
- **Customer Card** (prominent):
  - Large avatar
  - Name, rating (⭐), completed jobs count
  - "العملاء الراضون: 98%"
  - Call button (green)
  - Message button (blue)
- Service & job details:
  - Service name & icon
  - Location address
  - Initial estimate: "السعر المتوقع: SAR 250"
- Timeline:
  - ✅ تم قبول الطلب
  - ⏳ في انتظار تحديد السعر
  - ⏳ في انتظار موافقة العميل
  - ⏳ تنفيذ الخدمة
- **Action Buttons:**
  - "تحديد السعر الآن" button (green, primary, 56px)
  - "عرض على الخريطة" button (outline)

---

### Screen 2: "Set Price"
**File:** `lib/src/features/jobs/presentation/screens/technician_set_price_screen.dart`

**When to Show:** Job status = `accepted`

**UI Components:**
- Heading "تحديد السعر 💰"
- Customer info (compact): name, rating
- Initial estimate (read-only, gray):
  - "السعر المتوقع: SAR 250"
- **Price Input Section:**
  - Large numeric input field (SAR format)
  - Currency symbol (ر.س) on right
  - Hint: "أدخل السعر"
  - On focus, show numeric keyboard
- **Quick Amount Buttons:**
  - Suggested prices: "150", "200", "250", "300"
  - Tab-style buttons, tap to fill input
- **Breakdown Preview** (updates real-time):
  - السعر المقترح: SAR X
  - رسوم المنصة (10%): -SAR Y
  - **الذي ستحصل عليه:** SAR (X-Y) ← green, bold
- Optional **Notes Section:**
  - Text area: "أضف ملاحظات (اختياري)"
  - Max 200 chars, counter: "50/200"
- **Action Buttons:**
  - "إرسال السعر" button (green, primary)
  - "إلغاء" button (red outline)

**Behavior on "Submit Price":**
- Validate price > 0
- Call `POST /api/jobs/{id}/set-price` with { price, notes }
- Show loading dialog
- On success:
  - Toast: "✅ تم إرسال السعر للعميل"
  - Auto-navigate to "Waiting for Confirmation"
- On error:
  - Show error dialog with retry

---

### Screen 3: "Waiting for Confirmation"
**File:** `lib/src/features/jobs/presentation/screens/technician_waiting_confirmation_screen.dart`

**When to Show:** Job status = `price_pending`

**UI Components:**
- Status badge "⏳ في انتظار موافقة العميل"
- **Price Display** (large, centered):
  - "السعر المقترح"
  - "SAR 250" (very large, bold, green)
  - "تم الإرسال في 18:45"
- Customer info (compact)
- "العميل يراجع عرضك الآن..." (animated dots)
- Timeline:
  - ✅ تم قبول الطلب
  - ✅ تم تحديد السعر
  - ⏳ في انتظار الموافقة
  - ⏳ تنفيذ الخدمة
- **Action Buttons:**
  - "تعديل السعر" button (outline, blue)
  - "إلغاء الطلب" button (red outline)
  - "رجوع للطلبات" button (gray)

**Behavior:**
- Poll every 5 seconds
- When status → `in_progress` → auto-navigate to "In Progress"
- Handle customer cancellation (show notification)

---

### Screen 4: "In Progress"
**File:** `lib/src/features/jobs/presentation/screens/technician_in_progress_screen.dart`

**When to Show:** Job status = `in_progress`

**UI Components:**
- Status badge "⚙️ جاري العمل"
- Customer info:
  - Name, location, phone
  - Call button
- Service & job details
- Final agreed price: "السعر المتفق عليه: SAR 250"
- **Work Progress** (optional checklist):
  - ☐ وصول للموقع
  - ☐ تشخيص المشكلة
  - ☐ إصلاح الخدمة
  - ☐ اختبار الخدمة
  - Tappable to check off
- **Timer** (optional):
  - "المدة المنقضية: 45 دقيقة"
- "إرسال رسالة للعميل" button
- **"إنهاء الخدمة" button** (green, primary, 56px)
  - Opens confirmation dialog:
    - "هل انتهيت من الخدمة فعلاً؟"
    - "لا" (cancel) | "نعم" (confirm)
    - On "نعم": call `POST /api/jobs/{id}/complete`

---

### Screen 5: "Job Completed Summary"
**File:** `lib/src/features/jobs/presentation/screens/technician_completed_summary_screen.dart`

**When to Show:** Job status = `completed`

**UI Components:**
- Success badge "✅ تم إكمال الخدمة"
- **Earnings Summary** (prominent, green background):
  - "سعر الخدمة: SAR 250"
  - "رسوم المنصة (10%): -SAR 25"
  - **"أرباحك: SAR 225"** ← very large, bold
  - "تم إضافتها لمحفظتك"
- Customer info (waiting for rating):
  - "العميل سيقيم الخدمة الآن..."
- Timeline (all ✅)
- **Action Buttons:**
  - "عرض طلبات أخرى" button (green, primary)
  - "عرض أرباحك" button (blue outline)
  - "رجوع للرئيسية" button (gray)

---

## 🎨 Reusable Components & Utilities

### Component 1: JobStatusBadge Widget
**File:** `lib/src/features/jobs/presentation/widgets/job_status_badge.dart`

```dart
class JobStatusBadge extends StatelessWidget {
  final String status; // 'pending', 'accepted', 'price_pending', etc.
  final bool animated; // Default: false
  
  // Returns colored badge with icon + Arabic label
  // Status colors:
  // - pending/searching: blue (#2196F3)
  // - accepted: orange (#FF9800)
  // - price_pending: amber (#FFC107)
  // - in_progress: green (#4CAF50)
  // - completed: teal (#009688)
  // - rated: purple (#9C27B0)
  // - cancelled: gray (#757575)
}
```

**Example Usage:**
```dart
JobStatusBadge(status: 'accepted', animated: true)
// Output: Orange badge with "✅ تم قبول الطلب" text
```

---

### Component 2: ProfileCard Widget
**File:** `lib/src/features/jobs/presentation/widgets/profile_card.dart`

```dart
class ProfileCard extends StatelessWidget {
  final String name;
  final double rating;
  final int completedJobs;
  final String? profileImageUrl;
  final String? phone;
  final String? address;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final bool isCompact; // Default: false
  
  // Large or compact version depending on context
  // Shows avatar, name, rating, stats, action buttons
}
```

---

### Component 3: PriceCard Widget
**File:** `lib/src/features/jobs/presentation/widgets/price_card.dart`

```dart
class PriceCard extends StatelessWidget {
  final double? initialPrice;
  final double? proposedPrice;
  final double? finalPrice;
  final double commission; // Usually 10%
  final bool showBreakdown; // Default: true
  
  // Displays price comparison and breakdown
  // Shows initital estimate, technician offer, final price
  // Highlights key values with color
}
```

---

### Controller: JobPollingController
**File:** `lib/src/features/jobs/presentation/controllers/job_polling_controller.dart`

```dart
// Riverpod Provider for polling job status
final jobPollingProvider = FutureProvider.autoDispose.family<Job, String>(
  (ref, jobId) async {
    final repository = ref.watch(jobRepositoryProvider);
    return repository.getJob(jobId);
  },
);

// Auto-refresh every 3-5 seconds based on status
final jobAutoRefreshProvider = StreamProvider.autoDispose.family<Job, String>(
  (ref, jobId) async* {
    // Poll every 3 seconds if searching
    // Poll every 5 seconds if other statuses
    // Stop polling if terminal state (rated, cancelled)
  },
);
```

---

### Utility: Error Handling
**File:** `lib/src/features/jobs/presentation/utils/job_error_handler.dart`

```dart
class JobErrorHandler {
  static String getErrorMessage(dynamic error) {
    // Maps error codes to Arabic messages
    // JOB_NOT_FOUND → "لم يتم العثور على الطلب"
    // JOB_ALREADY_ACCEPTED → "تم قبول الطلب من قبل فني آخر"
    // INVALID_STATUS_TRANSITION → "لا يمكن إجراء هذا التحويل"
    // UNAUTHORIZED → "ليس لديك صلاحية"
    // etc.
  }
  
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error,
    VoidCallback onRetry,
  ) {
    // Shows error dialog with message + retry button
  }
  
  static void showSuccessToast(BuildContext context, String message) {
    // Brief green toast notification
  }
}
```

---

## 🧭 Navigation & Routing

### Route Structure
**File:** `lib/src/core/router.dart` (update existing)

```dart
GoRouter router = GoRouter(
  routes: [
    // Job Detail Routes
    GoRoute(
      path: '/jobs/:jobId',
      name: 'jobDetail',
      pageBuilder: (context, state) {
        final jobId = state.pathParameters['jobId']!;
        return MaterialPage(
          child: JobDetailScreen(jobId: jobId),
        );
      },
      routes: [
        // Customer Routes
        GoRoute(
          path: 'customer/searching',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: CustomerSearchingScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'customer/technician-found',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: CustomerTechnicianFoundScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'customer/price-offer',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: CustomerPriceOfferScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'customer/in-progress',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: CustomerInProgressScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'customer/rate',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: CustomerRateScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'customer/completed',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: CustomerCompletedSummaryScreen(jobId: jobId),
            );
          },
        ),
        
        // Technician Routes
        GoRoute(
          path: 'technician/accepted',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: TechnicianAcceptedConfirmationScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'technician/set-price',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: TechnicianSetPriceScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'technician/waiting',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: TechnicianWaitingConfirmationScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'technician/in-progress',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: TechnicianInProgressScreen(jobId: jobId),
            );
          },
        ),
        GoRoute(
          path: 'technician/completed',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return MaterialPage(
              child: TechnicianCompletedSummaryScreen(jobId: jobId),
            );
          },
        ),
      ],
    ),
  ],
);
```

### Smart Navigation Logic
```dart
// In job detail/polling logic:
// Detect job status change → navigate to appropriate screen

void handleJobStatusChange(String jobId, String newStatus, String userType) {
  if (userType == 'customer') {
    switch (newStatus) {
      case 'pending':
      case 'searching':
        context.goNamed('jobDetail', 
          pathParameters: {'jobId': jobId},
          extra: {'screen': 'searching'});
      case 'accepted':
        context.go('/jobs/$jobId/customer/technician-found');
      case 'price_pending':
        context.go('/jobs/$jobId/customer/price-offer');
      case 'in_progress':
        context.go('/jobs/$jobId/customer/in-progress');
      case 'completed':
        context.go('/jobs/$jobId/customer/rate');
      case 'rated':
        context.go('/jobs/$jobId/customer/completed');
    }
  } else if (userType == 'technician') {
    switch (newStatus) {
      case 'accepted':
        context.go('/jobs/$jobId/technician/accepted');
      case 'price_pending':
        // Technician stays on "set-price" or moves to "waiting"
        context.go('/jobs/$jobId/technician/waiting');
      case 'in_progress':
        context.go('/jobs/$jobId/technician/in-progress');
      case 'completed':
        context.go('/jobs/$jobId/technician/completed');
    }
  }
}
```

---

## 📝 Code Standards & Best Practices

### 1. Localization (Arabic/English)
**Requirement:** All user-facing strings in `l10n/app_ar.arb`

```dart
// ❌ DON'T hardcode strings
Text('جاري البحث عن فني')

// ✅ DO use localization
Text(context.loc.searchingForTechnician)
```

### 2. State Management (Riverpod)
**Requirement:** Use `ConsumerWidget` or `ConsumerStatefulWidget`

```dart
class CustomerSearchingScreen extends ConsumerWidget {
  final String jobId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobPollingProvider(jobId));
    
    return jobAsync.when(
       (job) => _buildContent(context, job),
      loading: () => const LoadingIndicator(),
      error: (err, st) => _buildError(context, err),
    );
  }
}
```

### 3. Error Handling Pattern
```dart
try {
  final job = await repository.confirmPrice(jobId);
  
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.loc.priceConfirmed)),
    );
    context.go('/jobs/$jobId/customer/in-progress');
  }
} catch (e) {
  if (context.mounted) {
    JobErrorHandler.showErrorDialog(
      context,
      e,
      () => _confirmPrice(), // Retry callback
    );
  }
}
```

### 4. Loading States
```dart
// ✅ Always show loading indicator
if (isLoading) {
  return const Center(
    child: CircularProgressIndicator(),
  );
}

// ✅ Disable buttons during async operations
ElevatedButton(
  onPressed: isLoading ? null : () => _handleTap(),
  child: isLoading
    ? const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
    : Text(context.loc.confirmPrice),
)
```

### 5. Polling Best Practices
```dart
// Stop polling on lifecycle changes
class _MyScreenState extends ConsumerState<MyScreen>
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Stop polling
      ref.refresh(jobPollingProvider(jobId));
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

### 6. Testing Each Screen
```dart
void main() {
  testWidgets('CustomerSearchingScreen shows spinner', (tester) async {
    await tester.pumpWidget(const TestApp(
      home: CustomerSearchingScreen(jobId: 'test-123'),
    ));
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('جاري البحث عن فني...'), findsOneWidget);
  });
}
```

### 7. Network Throttling (for testing)
```dart
// Test with 2G/3G speed
// Use device settings or code-level throttling to verify:
// - Loading states show correctly
// - Timeouts are handled
// - Retry logic works
```

---

## ✅ Testing Requirements

### Widget Tests (Minimum)
**Each screen must have:**
- ✅ Shows correct UI elements for status
- ✅ Shows loading indicator
- ✅ Handles error states
- ✅ Buttons are clickable
- ✅ Navigation works

**File:** `test/features/jobs/presentation/screens/*_test.dart`

```dart
void main() {
  group('CustomerSearchingScreen', () {
    testWidgets('renders searching state', (ester) async {
      // Test: spinner visible
      // Test: job details visible
      // Test: cancel button works
      // Test: navigation on status change
    });
    
    testWidgets('handles error gracefully', (tester) async {
      // Mock API error
      // Verify error dialog shows
      // Verify retry works
    });
  });
}
```

### Integration Tests (Recommended)
**Full flow:**
1. Create job → Searching screen
2. Accept job → Technician found
3. Set price → Waiting screen
4. Confirm price → In progress
5. Complete → Rate
6. Submit rating → Summary

### Manual Testing Checklist
- [ ] Test on iPhone 12, iPhone SE, iPad
- [ ] Test on Android devices (Samsung, Pixel)
- [ ] Test portrait and landscape
- [ ] Test with poor network (slow 3G)
- [ ] Test RTL layout (Arabic)
- [ ] Test with large text (accessibility)
- [ ] Test dark mode
- [ ] Test permissions (location, contacts)

---

## 🎯 Implementation Priority & Timeline

### Phase 1 (Week 1): Customer Screens Foundation
**Priority: CRITICAL**
- [ ] CustomerSearchingScreen
- [ ] CustomerTechnicianFoundScreen
- [ ] JobStatusBadge widget
- [ ] ProfileCard widget
- [ ] Basic polling logic

**Estimated:** 16 hours

### Phase 2 (Week 2): Price & Completion Flow
**Priority: CRITICAL**
- [ ] CustomerPriceOfferScreen
- [ ] CustomerInProgressScreen
- [ ] CustomerRateScreen
- [ ] CustomerCompletedSummaryScreen
- [ ] Error handling utilities

**Estimated:** 14 hours

### Phase 3 (Week 3): Technician Screens
**Priority: HIGH**
- [ ] TechnicianAcceptedConfirmationScreen
- [ ] TechnicianSetPriceScreen
- [ ] TechnicianWaitingConfirmationScreen
- [ ] TechnicianInProgressScreen
- [ ] TechnicianCompletedSummaryScreen

**Estimated:** 18 hours

### Phase 4 (Week 4): Integration & Polish
**Priority: HIGH**
- [ ] Navigation routing setup
- [ ] API integration
- [ ] Widget tests for all screens
- [ ] Error handling edge cases
- [ ] Localization complete
- [ ] Performance optimization

**Estimated:** 16 hours

**Total: ~64 hours (~2 weeks with 32 hours/week)**

---

## 📦 Deliverables

### Code Files
```
lib/src/features/jobs/
├── presentation/
│   ├── screens/
│   │   ├── customer_searching_screen.dart
│   │   ├── customer_technician_found_screen.dart
│   │   ├── customer_price_offer_screen.dart
│   │   ├── customer_in_progress_screen.dart
│   │   ├── customer_rate_screen.dart
│   │   ├── customer_completed_summary_screen.dart
│   │   ├── technician_accepted_confirmation_screen.dart
│   │   ├── technician_set_price_screen.dart
│   │   ├── technician_waiting_confirmation_screen.dart
│   │   ├── technician_in_progress_screen.dart
│   │   └── technician_completed_summary_screen.dart
│   ├── widgets/
│   │   ├── job_status_badge.dart
│   │   ├── profile_card.dart
│   │   ├── price_card.dart
│   │   └── job_timeline.dart
│   ├── controllers/
│   │   └── job_polling_controller.dart
│   └── utils/
│       └── job_error_handler.dart
├── domain/
│   └── job.dart (update if needed)
└── data/
    └── job_repository.dart (update if needed)

lib/src/core/
└── router.dart (update with job routes)

lib/l10n/
└── app_ar.arb (add all job-related strings)

test/
└── features/jobs/
    └── presentation/
        └── screens/ (widget tests)
```

### Documentation
- [ ] README for jobs feature
- [ ] Screen-by-screen specifications
- [ ] API integration guide
- [ ] Testing guide

---

## 🚀 Key Success Criteria

✅ All screens implement correct status conditions  
✅ Polling updates screens automatically  
✅ Error handling is comprehensive  
✅ Navigation flows work smoothly  
✅ Localization is 100% Arabic  
✅ All screens are tested  
✅ Performance is optimized  
✅ Code follows Flutter best practices  
✅ Accessibility standards met  
✅ Works on iOS and Android  

---

## 📞 Support & Troubleshooting

### Common Issues

**Q: How to handle network timeout during polling?**
```dart
// Use FutureProvider with timeout
final jobPollingProvider = FutureProvider.autoDispose.family<Job, String>(
  (ref, jobId) async {
    final repository = ref.watch(jobRepositoryProvider);
    return repository.getJob(jobId)
      .timeout(const Duration(seconds: 30));
  },
);
```

**Q: How to cancel ongoing requests when screen closes?**
```dart
// Riverpod's autoDispose handles this automatically
// When screen is disposed, providers are cleaned up
```

**Q: How to implement call/message buttons?**
```dart
// For calling
await launchUrl(Uri(scheme: 'tel', path: phone));

// For WhatsApp
await launchUrl(Uri(scheme: 'https', host: 'wa.me', path: '/$phone'));

// For SMS fallback
await launchUrl(Uri(scheme: 'sms', path: phone));
```

---

**Document Status:** ✅ Production Ready  
**Last Updated:** December 7, 2025  
**Next Steps:** Implementation with Google Antigravity

---

## 🎯 Final Notes for AI Implementation

1. **Backend is 100% complete** - All APIs are ready and tested
2. **Database is optimized** - RLS policies, indexes, schema all set
3. **Focus on Flutter UI/UX** - This is the only thing missing
4. **All screens are independent** - Can be built in any order
5. **Follow the specifications exactly** - They're based on best practices
6. **Test as you build** - Widget tests for each screen
7. **Use Riverpod for state** - Consistent with existing app architecture
8. **Implement error handling** - Every API call needs error handling
9. **Consider accessibility** - Proper labels, colors, text sizes
10. **Optimize performance** - Avoid rebuilds, manage memory

---

**Ready to implement? 🚀**

Pass this document to Google Antigravity and request:
- "Implement all Flutter screens according to these specifications"
- "Ensure 100% API integration with error handling"
- "Include widget tests for all screens"
- "Complete Arabic localization"
- "Implement proper routing and navigation"

The specifications are complete, detailed, and production-ready. ✨
