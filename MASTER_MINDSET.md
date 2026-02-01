# 🚀 KADMAT - Master Mindset Document  
## الملف الشامل والعقل المدبر لـ Code Agent

**آخر تحديث:** 2025-01-19  
**الحالة:** ✅ نشط وفعّال  
**الإصدار:** 2.0 (Supabase Edition - Complete)

---

## 📋 جدول المحتويات

1. [المقدمة والرؤية](#-المقدمة-والرؤية)
2. [معمارية المشروع](#-معمارية-المشروع)
3. [قاعدة البيانات (Database Schema)](#-قاعدة-البيانات)
4. [Backend API](#-backend-api)
5. [Flutter App Structure](#-flutter-app-structure)
6. [سياسات الأمان (RLS)](#-سياسات-الأمان-rls)
7. [دورة حياة الطلب (Job Flow)](#-دورة-حياة-الطلب)
8. [معايير الجودة](#-معايير-الجودة)
9. [Workflows الأساسية](#-workflows-الأساسية)
10. [الأوامر السريعة](#-الأوامر-السريعة)
11. [Troubleshooting](#-troubleshooting)

---

## 🎯 المقدمة والرؤية

### ما هو Kadmat؟

**تطبيق سوق خدمات ليبي يربط العملاء مع التقنيين والحرفيين.**

| للعملاء | للتقنيين | للنظام |
|---------|----------|--------|
| إنشاء طلبات خدمة | البحث عن الوظائف | إدارة آمنة |
| متابعة التقني | تقديم عروض أسعار | تقييمات عادلة |
| الدفع الآمن | كسب دخل مستمر | محفظة آمنة |

### معايير النجاح

```
📊 Performance: زمن تحميل < 1 ثانية
🔐 Security: Zero RLS breaches
⭐ Rating: > 4.5 stars
📈 Adoption: 500+ مستخدم خلال 6 أشهر
💻 Stability: 99.5% uptime
```

---

## 🏗️ معمارية المشروع

### Stack التقني الكامل

```
┌──────────────────────────────────────────────────────────────┐
│                        FRONTEND                               │
├──────────────────────────────────────────────────────────────┤
│  Flutter (iOS + Android)  │  React (Admin Dashboard)         │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                     BACKEND (Node.js)                         │
├──────────────────────────────────────────────────────────────┤
│  Express.js API Server                                        │
│  ├── /api/auth      → Authentication (JWT)                   │
│  ├── /api/jobs      → Job Management                         │
│  ├── /api/technicians → Technician Operations                │
│  ├── /api/wallet    → Wallet & Transactions                  │
│  ├── /api/services  → Service Catalog                        │
│  └── /api/notifications → Push Notifications                 │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                  SUPABASE (BaaS)                              │
├──────────────────────────────────────────────────────────────┤
│  PostgreSQL    │ PostGIS (Geo) │ Auth │ Realtime │ Storage  │
└──────────────────────────────────────────────────────────────┘
```

### هيكلية المجلدات

```
kadmat/
├── lib/src/                    # Flutter App
│   ├── config/                 # (supabase, routes, theme)
│   ├── features/               # Feature Modules
│   │   ├── auth/               # Login, Register, OTP
│   │   ├── jobs/               # Job Creation, Details, Status
│   │   ├── technician/         # Technician Dashboard, Accept
│   │   ├── wallet/             # Balance, Transactions
│   │   ├── messages/           # Chat System
│   │   ├── notifications/      # Push Notifications
│   │   ├── profile/            # User Profile
│   │   ├── booking/            # Scheduling
│   │   ├── tracking/           # Location Tracking
│   │   ├── home/               # Home Screen
│   │   ├── main/               # Main Navigation
│   │   └── orders/             # Order History
│   └── shared/                 # Shared Widgets & Utils
│
├── backend/                    # Node.js API Server
│   ├── src/
│   │   ├── controllers/        # Business Logic
│   │   │   ├── authController.js
│   │   │   ├── jobController.js
│   │   │   ├── technicianController.js
│   │   │   ├── walletController.js
│   │   │   ├── notificationController.js
│   │   │   └── serviceController.js
│   │   ├── routes/             # API Endpoints
│   │   ├── services/           # External Services
│   │   ├── middleware/         # Auth, Validation
│   │   └── config/             # Database Config
│   ├── *.sql                   # Migration Scripts
│   └── tests/                  # API Tests
│
└── .agent/                     # Agent Configuration
    └── rules.md                # Security Rules
```

---

## 🗄️ قاعدة البيانات

### الجداول الأساسية

#### 1. users - المستخدمون
```sql
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    full_name VARCHAR(255),
    profile_image_url TEXT,
    address TEXT,
    location GEOGRAPHY(POINT),        -- موقع PostGIS
    user_type VARCHAR(20) DEFAULT 'customer',  -- customer | technician
    rating DECIMAL(3, 2) DEFAULT 5.0,
    is_online BOOLEAN DEFAULT FALSE,  -- حالة الفني
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 2. jobs - الطلبات
```sql
CREATE TABLE public.jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES users(id),
    technician_id UUID REFERENCES users(id),
    service_id UUID REFERENCES services(id),
    
    -- الحالة
    status VARCHAR(20) DEFAULT 'pending',
    -- القيم: pending, accepted, price_pending, counter_offer,
    --        in_progress, completed, cancelled, no_technician_found
    
    -- الموقع
    location GEOGRAPHY(POINT),
    address_text TEXT,
    
    -- الأسعار
    initial_price DECIMAL(10, 2),
    final_price DECIMAL(10, 2),
    technician_price DECIMAL(10, 2),
    customer_offer DECIMAL(10, 2),
    price_notes TEXT,
    
    -- التواريخ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    price_confirmed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    
    -- التقييم
    customer_rating INT CHECK (customer_rating >= 1 AND customer_rating <= 5),
    customer_review TEXT,
    rated_at TIMESTAMP WITH TIME ZONE,
    
    -- الإلغاء
    cancelled_by UUID REFERENCES users(id),
    cancel_reason TEXT
);
```

#### 3. wallets - المحافظ
```sql
CREATE TABLE public.wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) UNIQUE,
    balance DECIMAL(10, 2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'LYD',
    is_frozen BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 4. wallet_transactions - حركات المحفظة
```sql
CREATE TABLE public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    wallet_id UUID REFERENCES wallets(id),
    amount DECIMAL(10, 2) NOT NULL,  -- موجب = إيداع، سالب = خصم
    type VARCHAR(20),  -- deposit, withdrawal, commission, payment, penalty
    description TEXT,
    reference_id UUID,  -- Job ID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 5. services - الخدمات
```sql
CREATE TABLE public.services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255),
    base_price DECIMAL(10, 2) NOT NULL,
    commission_rate DECIMAL(4, 2) DEFAULT 0.10,  -- 10%
    icon_url TEXT,
    is_active BOOLEAN DEFAULT TRUE
);
```

#### 6. notifications - الإشعارات
```sql
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) NOT NULL,
    type VARCHAR(50) NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### 7. messages - الرسائل (Chat)
```sql
CREATE TABLE public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs(id) NOT NULL,
    sender_id UUID REFERENCES users(id) NOT NULL,
    receiver_id UUID REFERENCES users(id) NOT NULL,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);
```

### الدوال الأساسية (Functions)

#### البحث عن فنيين قريبين
```sql
SELECT * FROM find_nearby_technicians(
    p_lat := 32.8872,     -- Latitude
    p_lng := 13.1913,     -- Longitude  
    p_radius := 5000      -- 5 كم
);
-- Returns: id, full_name, phone, rating, distance_meters
```

#### معالجة الدفع
```sql
SELECT process_job_payment(
    job_id := 'uuid',
    tech_id := 'uuid',
    amount := 100.00
);
-- يخصم العمولة تلقائياً من محفظة الفني
```

### Indexes للأداء
```sql
idx_jobs_status              -- البحث بالحالة
idx_jobs_customer            -- طلبات العميل
idx_jobs_technician          -- طلبات الفني
idx_jobs_pending             -- الطلبات المنتظرة
idx_users_technician_online  -- الفنيين المتصلين
idx_notifications_user_unread -- الإشعارات غير المقروءة
```

---

## 🔌 Backend API

### Base URL
```
/api
```

### Authentication
```
Authorization: Bearer <supabase_jwt_token>
```

### Jobs Endpoints

| Method | Endpoint | الوصف |
|--------|----------|-------|
| `POST` | `/jobs` | إنشاء طلب جديد |
| `GET` | `/jobs/:id` | تفاصيل الطلب |
| `GET` | `/jobs/my-jobs` | طلباتي |
| `POST` | `/jobs/:id/accept` | قبول الطلب (فني) |
| `POST` | `/jobs/:id/propose-price` | اقتراح سعر |
| `POST` | `/jobs/:id/confirm-price` | تأكيد السعر |
| `POST` | `/jobs/:id/start` | بدء العمل |
| `POST` | `/jobs/:id/complete` | إنهاء العمل |
| `POST` | `/jobs/:id/cancel` | إلغاء الطلب |
| `POST` | `/jobs/:id/rate` | تقييم الفني |

### Technician Endpoints

| Method | Endpoint | الوصف |
|--------|----------|-------|
| `GET` | `/technicians/nearby` | فنيين قريبين |
| `PATCH` | `/technicians/location` | تحديث الموقع |
| `PATCH` | `/technicians/online-status` | تغيير الحالة |

### Wallet Endpoints

| Method | Endpoint | الوصف |
|--------|----------|-------|
| `GET` | `/wallet` | رصيد المحفظة |
| `GET` | `/wallet/transactions` | سجل الحركات |

### Job Statuses

```
pending          → طلب جديد، في انتظار فني
accepted         → فني قبل الطلب ⚠️ (LOCKED)
price_pending    → الفني اقترح سعر (UNLOCKED)
counter_offer    → العميل قدم عرض مضاد
in_progress      → العمل جاري ⚠️ (LOCKED)
completed        → تم الإنجاز
rated            → تم التقييم
cancelled        → ملغي
no_technician_found → لم يُوجد فني
```

> ⚠️ **LOCKED = الفني لا يستطيع قبول طلبات أخرى**

---

## 📱 Flutter App Structure

### Feature Modules

| Module | المحتوى | الملفات الرئيسية |
|--------|---------|------------------|
| **auth** | تسجيل، دخول، OTP | `auth_repository.dart`, `login_screen.dart` |
| **jobs** | إنشاء، تفاصيل، حالة | `job_repository.dart`, `job_details_screen.dart` |
| **technician** | لوحة الفني، القبول | `technician_dashboard.dart`, `accept_job.dart` |
| **wallet** | رصيد، حركات | `wallet_repository.dart`, `wallet_screen.dart` |
| **messages** | الدردشة | `chat_screen.dart` |
| **notifications** | الإشعارات | `notifications_screen.dart` |
| **profile** | الملف الشخصي | `profile_screen.dart` |
| **tracking** | تتبع الموقع | `tracking_screen.dart` |

### Repository Pattern
```dart
// ✅ صحيح - استخدم Repository
final job = await jobRepository.getJob(jobId);

// ❌ خطأ - لا تستخدم Supabase مباشرة في UI
final data = await Supabase.instance.client.from('jobs').select();
```

### Error Handling
```dart
try {
  final job = await jobRepository.getJob(id);
} catch (e) {
  if (e is PostgrestException) {
    if (e.code == 'PGRST116') throw JobNotFoundException();
    if (e.code == '42501') throw UnauthorizedException();
  }
  rethrow;
}
```

---

## 🔐 سياسات الأمان (RLS)

### قواعد أساسية ⚠️

```
1. جميع الجداول تستخدم RLS
2. لا تستخدم service_role_key في Flutter أبداً
3. التحقق من الصلاحيات في Backend
4. التحقق من technician_id = authenticated user
```

### RLS Policies

#### Users
```sql
-- المستخدم يرى بياناته فقط
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

-- الجميع يرى الفنيين (للبحث)
CREATE POLICY "Anyone can view technicians" ON users
    FOR SELECT USING (user_type = 'technician');

-- المستخدم يعدل بياناته فقط
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);
```

#### Jobs
```sql
-- العميل والفني يرون الطلب
CREATE POLICY "Users can view own jobs" ON jobs
    FOR SELECT USING (
        auth.uid() = customer_id OR 
        auth.uid() = technician_id OR
        status = 'pending'  -- للبحث
    );

-- العميل ينشئ الطلب
CREATE POLICY "Customers can create jobs" ON jobs
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- الفني يعدل الطلبات المقبولة
CREATE POLICY "Technicians can update accepted jobs" ON jobs
    FOR UPDATE USING (auth.uid() = technician_id);
```

#### Wallets
```sql
-- المالك فقط يرى محفظته
CREATE POLICY "Users can view own wallet" ON wallets
    FOR SELECT USING (auth.uid() = user_id);
```

#### Notifications
```sql
-- المستخدم يرى إشعاراته فقط
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);
```

---

## 🔄 دورة حياة الطلب

```
┌─────────────┐
│   pending   │  ← العميل أنشأ الطلب
└──────┬──────┘
       │ فني يقبل
       ▼
┌─────────────┐
│  accepted   │  ← الفني مقفول LOCKED
└──────┬──────┘
       │ الفني يقترح سعر
       ▼
┌──────────────┐
│price_pending │  ← الفني حر UNLOCKED
└──────┬───────┘
       │ العميل يوافق
       ▼
┌─────────────┐
│ in_progress │  ← الفني مقفول LOCKED، العمل جاري
└──────┬──────┘
       │ الفني ينهي
       ▼
┌─────────────┐
│  completed  │  ← يمكن التقييم
└──────┬──────┘
       │ العميل يقيّم
       ▼
┌─────────────┐
│   rated     │  ← انتهى
└─────────────┘
```

### قواعد القفل (Locking Rules)

| الحالة | الفني؟ | ملاحظات |
|--------|--------|---------|
| `pending` | حر | يمكن قبول أي طلب |
| `accepted` | **مقفول** | لا يمكن قبول طلبات أخرى |
| `price_pending` | حر | يمكن قبول طلبات أخرى |
| `in_progress` | **مقفول** | لا يمكن قبول طلبات أخرى |
| `completed` | حر | انتهى الطلب |

---

## ✅ معايير الجودة

### Code Quality
```
☐ Repository Pattern في Flutter
☐ Clean Architecture (Data → Domain → Presentation)
☐ RLS على جميع الجداول
☐ Error Handling with meaningful messages
☐ DartDoc للـ public APIs
☐ Unit Tests (70%+ coverage)
```

### Performance
```
☐ App Startup < 3 seconds
☐ Job List Load < 1 second
☐ Database Query < 200ms
☐ Lazy Loading للقوائم
☐ Image Compression
```

### Security
```
☐ لا service_role_key في Flutter
☐ JWT validation في Backend
☐ Input Validation لكل endpoint
☐ Rate Limiting
☐ Audit Logs للعمليات الحساسة
```

---

## 🔄 Workflows الأساسية

### 1. إضافة Feature جديدة (4-8 ساعات)

```
1️⃣ Planning (30 min)
   - فهم المتطلبات
   - تصميم Database Schema
   - تصميم API Endpoints

2️⃣ Database (1 hour)
   - إنشاء Tables
   - إضافة RLS Policies
   - إنشاء Functions

3️⃣ Backend (2-3 hours)
   - Controller logic
   - Routes
   - Validation

4️⃣ Flutter (2-3 hours)
   - Repository
   - Models (Freezed)
   - UI Screens

5️⃣ Testing (1-2 hours)
   - Unit tests
   - Integration tests
```

### 2. إصلاح Bug (1-3 ساعات)

```
1️⃣ Reproduce (15 min)
2️⃣ Analyze logs (30 min)
3️⃣ Fix (30-60 min)
4️⃣ Test (30 min)
5️⃣ Deploy (15 min)
```

### 3. Database Migration

```
1️⃣ كتابة SQL script
2️⃣ اختبار محلي: supabase db reset
3️⃣ Backup: supabase db dump -f backup.sql
4️⃣ تطبيق: supabase db push
5️⃣ Verify & Monitor
```

---

## 🖥️ الأوامر السريعة

### Flutter
```bash
cd kadmat
flutter pub get
flutter run
flutter test --coverage
flutter analyze
```

### Supabase
```bash
supabase start
supabase stop
supabase status
supabase db push
supabase db reset
supabase functions deploy <function_name>
```

### Backend (Node.js)
```bash
cd backend
npm install
npm run dev      # Development
npm test         # Run tests
```

### Git
```bash
git checkout -b feature/feature-name
git commit -m "feat: description"
git push origin feature/feature-name
```

---

## 🐛 Troubleshooting

### أخطاء شائعة

| الخطأ | السبب | الحل |
|-------|-------|------|
| `PGRST116` | الصف غير موجود | تحقق من ID |
| `42501` | صلاحيات غير كافية | تحقق من RLS Policy |
| `23505` | قيمة مكررة (UNIQUE) | تحقق من البيانات |
| `401 Unauthorized` | Token منتهي | أعد تسجيل الدخول |
| `Function timeout` | استعلام بطيء | حسّن الـ Query |

### Debug Commands
```bash
# Flutter logs
flutter logs

# Supabase logs
supabase functions logs

# Check Supabase status
supabase status
```

### RLS Debug
```sql
-- تحقق من السياسات على جدول
SELECT * FROM pg_policies WHERE tablename = 'jobs';

-- اختبر كـ مستخدم معين
SET request.jwt.claims = '{"sub": "user-uuid"}';
SELECT * FROM jobs;
```

---

## 📞 الدعم والتواصل

| القناة | للمسائل |
|--------|---------|
| 📧 support@kadmat.ly | أسئلة عامة |
| 💬 #kadmat-dev (Slack) | أسئلة سريعة |
| 🐛 GitHub Issues | Bugs & Features |
| 📚 GitHub Wiki | توثيق إضافي |

---

## ⭐ Best Practices Summary

### ✅ افعل (DO)
- استخدم **RLS** دائماً
- استخدم **PostGIS** للموقع
- استخدم **Repository Pattern**
- اكتب **Unit Tests**
- راقب **Supabase Dashboard**
- تعامل مع **Errors** بوضوح

### ❌ لا تفعل (DON'T)
- ❌ `service_role_key` في Flutter
- ❌ جداول بدون RLS
- ❌ تجاهل Error Handling
- ❌ الوثوق بـ User Input
- ❌ Hardcoded values
- ❌ Skip Code Review

---

**KADMAT MASTER MINDSET v2.0**  
**Last Updated:** 2025-01-19  
**Status:** ✅ COMPLETE

🚀 **أنت الآن جاهز للعمل على مشروع Kadmat!**
