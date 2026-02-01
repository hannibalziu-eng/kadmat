# Kadmat Mastermind – Complete AI Agent Guide

> **الملف المرجعي الشامل** لأي AI Agent يعمل على مشروع كدمات

---

## 1. نظرة عامة (Overview)

| العنصر | القيمة |
|--------|--------|
| **اسم المشروع** | Kadmat (كدمات) |
| **الوصف** | تطبيق سوق خدمات منزلية في ليبيا |
| **المنصات** | Android + iOS + Web |
| **اللغات** | Flutter (Dart) + Node.js (Backend) |
| **قاعدة البيانات** | Supabase (PostgreSQL + PostGIS) |
| **المصادقة** | Supabase Auth (JWT) |
| **التخزين** | Supabase Storage |
| **الإشعارات** | Firebase Cloud Messaging (FCM) |

### الأدوار الرئيسية
- **Customer (عميل)**: يطلب خدمات منزلية
- **Technician (فني)**: يقدم الخدمات

---

## 2. المتغيرات البيئية (Environment Variables)

### 2.1 Flutter (.env أو constants.dart)
```dart
// lib/src/core/constants.dart
class AppConstants {
  static const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const supabaseAnonKey = 'eyJ...'; // Public anon key
  static const backendUrl = 'https://your-backend.com/api';
}
```

### 2.2 Backend (.env)
```env
# Supabase
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # ⚠️ Secret - never expose!
SUPABASE_ANON_KEY=eyJ...

# Firebase (for FCM)
FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}

# Server
PORT=3000
NODE_ENV=production

# JWT
JWT_SECRET=your-jwt-secret
```

### 2.3 مفاتيح الوصول المطلوبة
| المفتاح | الاستخدام | الصلاحيات |
|---------|----------|-----------|
| `SUPABASE_ANON_KEY` | Flutter Client | RLS-restricted |
| `SUPABASE_SERVICE_ROLE_KEY` | Backend Only | Full access (bypass RLS) |
| `FIREBASE_SERVICE_ACCOUNT` | FCM Push | Send notifications |

---

## 3. معمارية النظام (System Architecture)

```
┌─────────────────┐         ┌─────────────────┐
│   Flutter App   │────────▶│   Node.js API   │
│  (Customer/Tech)│         │   (/backend)    │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │  Supabase SDK             │  service_role
         ▼                           ▼
┌─────────────────────────────────────────────┐
│              Supabase                        │
│  ┌─────────┐  ┌─────────┐  ┌─────────────┐  │
│  │  Auth   │  │   DB    │  │   Storage   │  │
│  │  (JWT)  │  │(Postgres)│  │ (job-photos)│  │
│  └─────────┘  └─────────┘  └─────────────┘  │
│                    │                         │
│              ┌─────┴─────┐                   │
│              │  PostGIS  │                   │
│              │ (Spatial) │                   │
│              └───────────┘                   │
└─────────────────────────────────────────────┘
```

---

## 4. هيكل الملفات (Directory Structure)

```
kadmat/
├── lib/
│   ├── main.dart                 # Entry point
│   └── src/
│       ├── core/                 # Shared code
│       │   ├── api/
│       │   │   ├── api_client.dart      # Dio HTTP client
│       │   │   └── endpoints.dart       # API endpoints
│       │   ├── router.dart              # GoRouter navigation
│       │   ├── app_theme.dart           # Theme & colors
│       │   ├── constants.dart           # App constants
│       │   ├── services/
│       │   │   ├── fcm_service.dart     # Push notifications
│       │   │   ├── location_service.dart # GPS
│       │   │   └── offline/             # Offline support
│       │   ├── utils/
│       │   │   └── error_messages.dart  # Arabic errors
│       │   └── widgets/                 # Shared UI
│       │
│       └── features/             # Feature modules
│           ├── auth/             # Authentication
│           │   ├── data/         # Repositories
│           │   ├── domain/       # Models
│           │   └── presentation/ # Screens & Controllers
│           ├── jobs/             # Job management
│           ├── technician/       # Technician dashboard
│           ├── home/             # Customer home
│           ├── messages/         # Chat
│           ├── notifications/    # Notifications
│           ├── profile/          # User profile
│           └── wallet/           # Payments
│
├── backend/                      # Node.js API
│   ├── src/
│   │   ├── index.js              # Entry point
│   │   ├── config/               # Supabase config
│   │   ├── controllers/          # Route handlers
│   │   ├── services/             # Business logic
│   │   │   ├── jobService.js
│   │   │   ├── jobSearchService.js
│   │   │   └── fcmService.js
│   │   ├── routes/               # API routes
│   │   └── middleware/           # Auth middleware
│   └── migrations/               # SQL migrations
│
└── .agent/
    └── mastermind.md             # This file
```

---

## 5. قاعدة البيانات (Database Schema)

### 5.1 الجداول الرئيسية

#### users
```sql
id              UUID PRIMARY KEY
email           TEXT UNIQUE
phone           TEXT
full_name       TEXT
user_type       TEXT  -- 'customer' | 'technician'
service_id      UUID  -- Technician specialty
location        GEOGRAPHY(POINT)
is_online       BOOLEAN
rating          DECIMAL
fcm_token       TEXT  -- Push notification token
created_at      TIMESTAMPTZ
```

#### jobs
```sql
id              UUID PRIMARY KEY
customer_id     UUID REFERENCES users(id)
technician_id   UUID REFERENCES users(id)
service_id      UUID REFERENCES services(id)
status          TEXT  -- See status flow below
lat             FLOAT
lng             FLOAT
address_text    TEXT
description     TEXT
initial_price   DECIMAL
technician_price DECIMAL
final_price     DECIMAL
created_at      TIMESTAMPTZ
accepted_at     TIMESTAMPTZ
completed_at    TIMESTAMPTZ
```

#### services
```sql
id              UUID PRIMARY KEY
name            TEXT
name_ar         TEXT
icon_url        TEXT
category        TEXT
```

#### job_images (Customer photos)
```sql
id              UUID PRIMARY KEY
job_id          UUID REFERENCES jobs(id)
image_url       TEXT
media_type      TEXT
```

#### job_photos (Technician photos)
```sql
id              UUID PRIMARY KEY
job_id          UUID REFERENCES jobs(id)
photo_url       TEXT
photo_type      TEXT  -- 'pre' | 'post'
description     TEXT
```

#### notifications
```sql
id              UUID PRIMARY KEY
user_id         UUID REFERENCES users(id)
type            TEXT
title           TEXT
body            TEXT
data            JSONB
is_read         BOOLEAN
created_at      TIMESTAMPTZ
```

### 5.2 مخطط حالة الطلب (Job Status Flow)

```
pending → searching → accepted → price_pending → customer_agreed → in_progress → pending_confirm → completed
    ↓                     ↓                                                              ↓
no_technician_found    cancelled                                                     cancelled
```

| Status | الوصف |
|--------|-------|
| `pending` | تم إنشاء الطلب، في انتظار البحث |
| `searching` | البحث عن فنيين جاري |
| `no_technician_found` | انتهت مهلة البحث |
| `accepted` | قبل الفني الطلب (الفني متاح) |
| `price_pending` | الفني أرسل السعر (الفني متاح) |
| `customer_agreed` | العميل وافق على السعر |
| `in_progress` | الفني يعمل (يقفل الفني) |
| `pending_confirm` | انتهى العمل، بانتظار تأكيد الدفع |
| `completed` | تم الدفع والإنهاء |
| `cancelled` | ملغي |

---

## 6. دوال RPC (Supabase Functions)

### get_nearby_jobs
```sql
-- البحث عن طلبات قريبة للفني
CREATE OR REPLACE FUNCTION get_nearby_jobs(
  technician_lat FLOAT, 
  technician_lng FLOAT, 
  radius_meters INT DEFAULT 5000,
  limit_count INT DEFAULT 50
) RETURNS SETOF jobs AS $$
  SELECT * FROM jobs
  SELECT * FROM jobs
  WHERE status IN ('pending', 'no_technician_found', 'searching')
    AND technician_id IS NULL
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(technician_lng, technician_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(jobs.lng, jobs.lat), 4326)::geography,
      radius_meters
    )
    -- Visibility window filters
    AND (
      -- Pending/Searching: 24h
      (status IN ('pending', 'searching') AND created_at >= NOW() - INTERVAL '24 hours')
      OR 
      -- No technician found: 2h only
      (status = 'no_technician_found' AND created_at >= NOW() - INTERVAL '2 hours')
      -- Fallback for others
      OR status NOT IN ('pending', 'searching', 'no_technician_found')
    )
  ORDER BY created_at DESC
  LIMIT limit_count;
$$ LANGUAGE sql SECURITY DEFINER;
```

### get_nearby_technicians
```sql
-- البحث عن فنيين قريبين لطلب جديد
CREATE OR REPLACE FUNCTION get_nearby_technicians(
  lat FLOAT, 
  long FLOAT, 
  radius_meters INT,
  service_type UUID DEFAULT NULL
) RETURNS TABLE (...) AS $$
  SELECT u.id, u.full_name, u.phone, u.rating, ...
  FROM users u
  WHERE u.user_type = 'technician'
    AND u.is_online = TRUE
    AND ST_DWithin(u.location, ..., radius_meters)
    AND (service_type IS NULL OR u.service_id = service_type)
  ORDER BY dist_meters ASC, rating DESC
  LIMIT 10;
$$ LANGUAGE sql SECURITY DEFINER;
```

---

## 7. نقاط النهاية (API Endpoints)

### Backend API (`/api`)

| Method | Endpoint | الوصف |
|--------|----------|-------|
| POST | `/auth/login` | تسجيل الدخول |
| POST | `/auth/register` | إنشاء حساب |
| POST | `/jobs` | إنشاء طلب جديد |
| GET | `/jobs/:id` | تفاصيل طلب |
| GET | `/jobs/nearby` | طلبات قريبة |
| POST | `/jobs/:id/accept` | قبول طلب |
| POST | `/jobs/:id/set-price` | تحديد السعر |
| POST | `/jobs/:id/confirm-price` | تأكيد السعر |
| POST | `/jobs/:id/start-work` | بدء العمل |
| POST | `/jobs/:id/request-completion` | طلب إتمام |
| POST | `/jobs/:id/confirm-completion` | تأكيد الإتمام |
| POST | `/jobs/:id/cancel` | إلغاء |
| POST | `/jobs/:id/rate` | تقييم |

---

## 8. المصادقة والأمان (Authentication & Security)

### 8.1 تدفق المصادقة
```
1. User login → Backend validates → Returns refresh_token
2. Flutter calls Supabase.auth.setSession(refreshToken)
3. api_client.dart interceptor adds access_token to requests
4. On 401 → Try refreshSession()
5. If refresh fails (refresh_token_already_used) → Force logout
```

### 8.2 Row Level Security (RLS)
```sql
-- Users can only see their own data
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

-- Technicians can see pending jobs
CREATE POLICY "Technicians can view pending jobs" ON jobs
  FOR SELECT USING (
    status IN ('pending', 'no_technician_found')
    OR customer_id = auth.uid()
    OR technician_id = auth.uid()
  );
```

### 8.3 قواعد الأمان
- ❌ لا تخزن `service_role_key` في Flutter
- ❌ لا تعرض بيانات المستخدمين الآخرين
- ✅ استخدم RLS دائماً
- ✅ تحقق من الصلاحيات في Backend

---

## 9. Real-time والإشعارات

### 9.1 Supabase Realtime
```dart
// الاستماع لتغييرات الطلبات
Supabase.instance.client
  .channel('jobs')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    table: 'jobs',
    callback: (payload) {
      // Handle change
    },
  ).subscribe();
```

### 9.2 FCM Push Notifications
```javascript
// backend/src/services/fcmService.js
await admin.messaging().send({
  token: user.fcm_token,
  notification: {
    title: 'طلب جديد',
    body: 'لديك طلب خدمة جديد',
  },
  data: { job_id: jobId },
});
```

---

## 10. أنماط الكود (Coding Patterns)

### 10.1 Feature Structure
```
feature/
├── data/
│   └── feature_repository.dart    # API calls
├── domain/
│   └── feature_model.dart         # Freezed model
└── presentation/
    ├── feature_controller.dart    # Riverpod notifier
    ├── feature_screen.dart        # UI
    └── widgets/                   # Feature-specific widgets
```

### 10.2 Model Pattern (Freezed)
```dart
@freezed
class Job with _$Job {
  const factory Job({
    required String id,
    required String status,
    String? technicianId,
    // ...
  }) = _Job;
  
  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}
```

### 10.3 Repository Pattern
```dart
class JobRepository {
  final Dio _client;
  
  Future<Job> acceptJob(String jobId) async {
    final response = await _client.post('/jobs/$jobId/accept');
    return Job.fromJson(response.data['data']);
  }
}
```

### 10.4 Provider Pattern
```dart
@riverpod
Stream<List<Job>> watchNearbyJobs(ref, {required double lat, required double lng}) {
  return ref.watch(jobRepositoryProvider).watchNearbyJobs(lat: lat, lng: lng);
}
```

---

## 11. الأخطاء الشائعة (Common Gotchas)

### ⚠️ جداول الصور
```dart
// ❌ خطأ: قراءة من job.afterPhotos (فارغ)
final photos = job.afterPhotos;

// ✅ صحيح: استخدم getJobPhotos()
final photosMap = await repository.getJobPhotos(jobId);
final prePhotos = photosMap['pre'];
final postPhotos = photosMap['post'];
```

### ⚠️ Token Errors
```dart
// ❌ خطأ: تجاهل حالة الجلسة
await _client.get('/api/data');

// ✅ صحيح: تحقق من الجلسة أولاً
final session = Supabase.instance.client.auth.currentSession;
if (session == null) throw Exception('يجب تسجيل الدخول');
```

### ⚠️ Realtime Not Working
```sql
-- تأكد من تفعيل Realtime
SELECT * FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';

-- إذا كانت الجداول مفقودة:
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
```

---

## 12. الاختبار (Testing)

### 12.1 أوامر التشغيل
```bash
# Flutter
flutter run -d chrome --web-port=8080  # Customer
flutter run -d chrome --web-port=8081  # Technician

# Backend
cd backend && npm run dev

# تحليل الكود
flutter analyze lib/
```

### 12.2 اختبار RPC
```sql
-- اختبر get_nearby_jobs
SELECT * FROM get_nearby_jobs(32.8872, 13.1913, 10000);

-- اختبر get_nearby_technicians
SELECT * FROM get_nearby_technicians(32.8872, 13.1913, 10000);
```

### 12.3 Debugging Logs
```dart
// في Flutter
debugPrint('🔍 [DEBUG] Message');

// في Backend
console.log('✅ [Success] Message');
console.error('❌ [Error] Message');
```

---

## 13. قواعد العمل للـ AI Agent

### ✅ يجب عليك:
1. **احترام البنية الموجودة** - لا تنشئ بنية جديدة
2. **استخدام Repositories** - لا تستدعِ API من UI مباشرة
3. **استخدام Freezed** - لأي model جديد
4. **الكتابة بالعربية** - للنصوص التي تظهر للمستخدم
5. **التحقق من RLS** - عند إضافة جداول جديدة
6. **التوثيق هنا** - أي تغيير كبير يجب توثيقه

### ❌ لا يجب عليك:
1. تخزين مفاتيح سرية في الكود
2. تجاوز RLS باستخدام service_role في Flutter
3. حذف ملفات بدون تأكيد
4. تغيير هيكل المجلدات الأساسي
5. إنشاء endpoints بدون auth middleware

### 🔄 عند إضافة ميزة جديدة:
1. حدد الـ feature المناسب
2. أنشئ/عدّل الـ model في `domain/`
3. أضف methods في `repository`
4. أنشئ/عدّل `controller`
5. أنشئ/عدّل `screen`
6. سجّل في `router.dart` إذا كانت شاشة جديدة
7. أضف اختبارات
8. **وثّق هنا أي تغيير كبير**

---

## 14. معلومات الاتصال والموارد

| المورد | الرابط |
|--------|--------|
| Supabase Dashboard | https://app.supabase.com |
| Firebase Console | https://console.firebase.google.com |
| Backend Logs | `pm2 logs` or Vercel/Railway logs |

---

> **آخر تحديث**: 2025-12-23
> 
> هذا الملف هو المصدر الوحيد للحقيقة لأي AI Agent يعمل على مشروع كدمات.