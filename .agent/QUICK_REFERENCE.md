# 🚀 KADMAT - Quick Reference Guide
## دليل سريع لعمليات البرمجة اليومية

---

## 🔛 Commands السريعة

### 🟠 Setup & Run

```bash
# إعداد مرة أولى
cd kadmat/flutter
flutter pub get
flutter doctor

# تشغيل على Android
flutter run

# تشغيل على iOS
flutter run -d ios

# تشغيل Supabase Local Development
supabase start

# إيقاف Supabase Local
supabase stop

# Web
cd ../web
npm start
```

### 🔐 Git Commands

```bash
# إنشاء feature branch
git checkout -b feature/feature-name

# البحث عن changes
git status
git diff

# حفظ المتغيرات
git add .
git commit -m "type: description"

# رفع للريموت
git push origin feature/feature-name

# تحديث من main
git pull origin main
```

### 🔧 Testing Commands

```bash
# الإختبارات
flutter test
flutter test --coverage

# التطبيقات
flutter test -v
flutter drive --target=test_driver/app.dart

# DevTools (Profiler)
flutter pub global activate devtools
devtools
```

### 🚀 Deploy Commands (Supabase)

```bash
# Deploy Database Changes
supabase db push

# Deploy Edge Functions
supabase functions deploy <function_name> --no-verify-jwt
# Example: supabase functions deploy create_job

# Check status
supabase status
```

---

## 📄 File Structure Quick Map

```
kadmat/
├── flutter/lib/src/
│   ├── config/          ← ثابته (routes, theme, supabase_config)
│   ├── features/       ← الميزات
│   │   ├── jobs/
│   │   ├── auth/
│   │   ├── technician/
│   │   ├── customer/
│   │   └── payment/
│   └── core/           ← services و utils
│
├── backend/ (Supabase)
│   ├── functions/       ← Edge Functions (Deno)
│   │   ├── create_job/
│   │   ├── update_status/
│   │   └── index.ts
│   ├── migration/      ← SQL Schema
│   └── seed/           ← Mock Data
│
├── .agent/
│   ├── MASTER_MINDSET.md        ← ابدأ هنا!
│   ├── QUICK_REFERENCE.md      ← أنت هنا
│   └── workflows/      ← مفاشل عمل
└── docs/
    ├── API.md
    ├── DATABASE.md
    └── DEPLOYMENT.md
```

---

## 📝 Code Patterns - The Way We Code Here

### ✅ Flutter - Repository Pattern (Supabase)

```dart
// ❌ DON'T - Direct Supabase access in UI
final data = await Supabase.instance.client
    .from('jobs')
    .select()
    .eq('id', jobId);

// ✅ DO - Use Repository
final job = await jobRepository.getJob(jobId);

// Repository Pattern Example
class JobRepository {
  final SupabaseClient _client;

  JobRepository({required SupabaseClient client})
      : _client = client;

  Future<Job> getJob(String jobId) async {
    try {
      final response = await _client
          .from('jobs')
          .select()
          .eq('id', jobId)
          .single(); // Throws if not found
      
      return Job.fromJson(response);
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST116') {
         throw JobNotFoundException(); 
      }
      print('Error: $e');
      rethrow;
    }
  }
}
```

### ✅ Edge Functions (Deno/TypeScript) - Error Handling

```typescript
// ❌ DON'T - Silent failure
Deno.serve(async (req) => {
  const { title } = await req.json();
  const supabase = createClient(...);
  await supabase.from('jobs').insert({ title });
  return new Response("Ok");
});

// ✅ DO - Proper error handling
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // 1. Validate Input
    const { title } = await req.json();
    if (!title) {
        return new Response(JSON.stringify({ error: 'Title required' }), { status: 400 });
    }

    // 2. Auth Context (Optional - handled by Gateway usually but good to check)
    const authHeader = req.headers.get('Authorization')!;
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
        global: { headers: { Authorization: authHeader } }
    });
    
    // 3. Execute
    const { data, error } = await supabase
        .from('jobs')
        .insert({ title, status: 'pending' })
        .select()
        .single();
    
    if (error) throw error;

    return new Response(JSON.stringify({ data }), { 
        headers: { "Content-Type": "application/json" } 
    });

  } catch (error) {
    console.error('Error creating job:', error);
    return new Response(JSON.stringify({ error: error.message }), { 
        status: 500,
        headers: { "Content-Type": "application/json" } 
    });
  }
});
```

### ✅ Comments & Documentation

```dart
/// Checks if technician can accept new jobs via RPC
/// 
/// Returns true if technician has no active jobs
/// (accepted or in_progress status)
/// 
/// [technicianId] - The technician's user ID
Future<bool> canAcceptNewJob(String technicianId) async {
  try {
    // Call Postgres RPC function
    final result = await _client.rpc('can_accept_job', params: {
        'tech_id': technicianId
    });
    return result as bool;
  } catch (e) {
    print('Error checking if can accept job: $e');
    return false; // Fail safe
  }
}
```

---

## 📋 Common Tasks - Copy & Modify

### 📝 Add New Edge Function

```typescript
// File: backend/functions/new_function/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
    // CORS (Optional helper)
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: { ...corsHeaders } })
    }

    try {
        const { name } = await req.json();
        
        // Logic here...
        
        return new Response(JSON.stringify({ message: `Hello ${name}` }), {
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }
});
```

### 📝 Add New Flutter Feature

```dart
// File: flutter/lib/src/features/newFeature/data/new_feature_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class NewFeatureRepository {
  final SupabaseClient _client;

  NewFeatureRepository(this._client);

  /// Get data from Supabase Table
  Future<List<Map<String, dynamic>>> getData() async {
    final response = await _client.from('my_table').select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Watch real-time changes
  Stream<List<Map<String, dynamic>>> watchData() {
    return _client
        .from('my_table')
        .stream(primaryKey: ['id'])
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}
```

---

## 🐛 Debug & Troubleshoot

### 🔍 Check Logs

```bash
# Flutter app logs
flutter logs

# Supabase Edge Function logs
supabase functions logs

# Database Queries (via Dashboard or SQL)
select * from supabase_stat_activity;
```

### 🔍 Common Errors & Solutions

```
❌ "PGRST116" (JSON object requested, multiple (or no) rows returned)
   ✅ Check if using `.single()` on a query returning regular list.
   ✅ Ensure ID exists.

❌ "42501" (Insufficient Privilege)
   ✅ Check RLS Policies on the table.
   ✅ Verify user is authenticated.

❌ "Function timeout"
   ✅ Check logic in Edge Function.
   ✅ Optimize SQL queries used inside.

❌ "Hot reload fails"
   ✅ Check for syntax errors.
   ✅ Run `flutter pub get`.
   ✅ Restart app (full restart).

❌ "Auth Session Missing"
   ✅ Check `Supabase.initialize` in main.dart.
   ✅ Check if session expired.
```

---

## 📚 Documentation Links

```
📄 Main Docs:
   - MASTER_MINDSET.md (Start here!)
   - docs/API.md
   - docs/DATABASE.md

🔗 External:
   - Flutter: https://flutter.dev/docs
   - Supabase: https://supabase.com/docs
   - Dart: https://dart.dev/guides
```

---

## 🚀 You're Ready!

**Next Steps:**
1. Read MASTER_MINDSET.md (full Supabase overview)
2. Use this QUICK_REFERENCE.md for day-to-day tasks
3. Check Supabase Dashboard for data

**Happy coding! 🚀**
