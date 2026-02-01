# 🎓 KADMAT - START HERE!
## ابدأ من هنا للعمل مع المشروع

---

## 🚀 Welcome to Kadmat!

مرحباً بك في مشروع **Kadmat** - تطبيق سوق خدمات ليبيا.

هذا ملف يربطك بباقي ملفات التوثيق. ابدأ بالقراءة بهذا الملف للتعرف على باقي الملفات.

---

## 📋 الخطوات الأربع الأولى

### 1️⃣ اقرأ MASTER_MINDSET.md
```
File: /kadmat/MASTER_MINDSET.md
Why: هذا الملف الرئيسي يتضمن:
  ✓ رؤية المشروع وأهدافه
  ✓ معمارية وبنية الكود (Supabase Edition)
  ✓ التكنولوجيا المستخدمة (Flutter + PostgreSQL)
  ✓ معايير الجودة
  ✓ الممارسات الفضلى
Time: 30-45 دقيقة
```

### 2️⃣ عرّف على KADMAT_MASTER_OVERVIEW.html
```
File: /kadmat/KADMAT_MASTER_OVERVIEW.html
Why: ملخص بصري يعرض:
  ✓ المعمارية بالرسوم
  ✓ الـ workflows بشكل سريع
  ✓ معايير الجودة
  ✓ الأرقام الرئيسية
Time: 20 دقيقة (افتح بالمتصفح)
```

### 3️⃣ مارس QUICK_REFERENCE.md
```
File: /kadmat/.agent/QUICK_REFERENCE.md
Why: المدلول اليومي:
  ✓ Commands السريعة (Supabase CLI)
  ✓ Common tasks المكررة
  ✓ Code patterns للنسخ
  ✓ Troubleshooting
Time: 15 دقيقة
```

### 4️⃣ ادرس COMPLETE_WORKFLOWS_GUIDE.md
```
File: /kadmat/.agent/workflows/COMPLETE_WORKFLOWS_GUIDE.md
Why: الدليل التفصيلي:
  ✓ 7 workflows رئيسية
  ✓ خطوات بخطوة
  ✓ Checklists
  ✓ أمثلة عملية
Time: Refer when needed
```

---

## 📄 Documentation Files - Where to Find What

### 📁 Main Documentation

| File | Purpose | When to Use |
|------|---------|-------------|
| **MASTER_MINDSET.md** | Complete project overview | First time, reference |
| **KADMAT_MASTER_OVERVIEW.html** | Visual summary | Quick overview |
| **QUICK_REFERENCE.md** | Daily tasks & commands | Every day |
| **COMPLETE_WORKFLOWS_GUIDE.md** | Detailed workflow steps | Before starting task |

### 📁 Deep Dive Documentation

| File | Content | Reference |
|------|---------|----------|
| **docs/API.md** | Edge Functions API | When writing/calling functions |
| **docs/DATABASE.md** | PostgreSQL schema | When designing data models |
| **docs/DEPLOYMENT.md** | Deployment procedures | When deploying to prod |
| **docs/TROUBLESHOOTING.md** | Common errors & fixes | When debugging |

### 📁 Workflow-Specific Guides

```
.agent/workflows/
├── COMPLETE_WORKFLOWS_GUIDE.md    ← الرئيسي
├── implement-feature.md         ← Implementing features
├── bug-fix.md                   ← Fixing bugs
├── db-migration.md              ← Database changes
├── performance-optimization.md  ← Making things faster
├── security-audit.md            ← Security checks
├── release-deployment.md        ← Production deployment
└── code-review-prep.md          ← Before PR
```

---

## 🔄 Workflows - الـ 7 الأساسية

### 🚀 Workflow #1: Implement New Feature
**Timeline:** 4-8 hours
**When:** Adding new functionality (Messaging, Ratings, etc.)
**Steps:** Planning → Database (SQL) → Backend (Edge) → UI → Testing → Deploy
→ See COMPLETE_WORKFLOWS_GUIDE.md

### 🐛 Workflow #2: Fix Bug
**Timeline:** 1-3 hours
**When:** Fixing issues (like technician locking problem)
**Steps:** Reproduce → Analyze → Fix (SQL/Logic) → Test → Deploy
→ See COMPLETE_WORKFLOWS_GUIDE.md

### 🚀 Workflow #3: Deploy to Production
**Timeline:** 2-4 hours
**When:** Every week or new release
**Steps:** Migrations → Edge Functions → Release App
→ See COMPLETE_WORKFLOWS_GUIDE.md

---

## 📝 Code Patterns - How We Write Code

### 🎯 Flutter Patterns
```dart
// Use Repository Pattern - NOT direct Client access
✅ class JobRepository {
   Future<Job> getJob(String id) { ... }
}

// Use meaningful error handling
✅ try {
   final job = await jobRepository.getJob(id);
} catch (e) {
   if (e is PostgrestException) ...
}
```

### 🔧 Edge Functions Patterns
```typescript
// Always validate & authenticate
✅ serve(async (req) => {
      const { title } = await req.json();
      if (!title) throw new Error('Title required');
   }
);
```

### 📚 Documentation Patterns
```dart
/// Always document public methods
/// [id] - The item ID
/// Returns Job model
Future<Job> getJob(String id) { ... }
```

→ See QUICK_REFERENCE.md for more code patterns

---

## 🔐 Quick Start Commands

### Setup
```bash
cd kadmat/flutter
flutter pub get
flutter doctor
```

### Development
```bash
# Run app
flutter run

# Supabase Local
supabase start

# Tests
flutter test --coverage
```

### Git Workflow
```bash
# Create feature branch
git checkout -b feature/your-feature

# Commit
git commit -m "type: description"

# Push
git push origin feature/your-feature

# Create PR on GitHub
```

→ See QUICK_REFERENCE.md for more commands

---

## ⭐ Best Practices Summary

### ✅ DO
- [ ] Use **RLS** everywhere
- [ ] Use **PostGIS** for location
- [ ] Write unit tests
- [ ] Handle errors gracefully
- [ ] Monitor **Supabase Dashboard**

### ❌ DON'T
- [ ] Don't use `service_role_key` in App
- [ ] Don't ignore RLS Policies
- [ ] Don't skip error handling
- [ ] Don't trust user input

---

## 📜 Common Tasks - First Time?

### 📄 I want to add a new feature
1. Read COMPLETE_WORKFLOWS_GUIDE.md → Workflow #1
2. Follow the steps
3. Reference QUICK_REFERENCE.md for commands

### 🐛 I found a bug
1. Read COMPLETE_WORKFLOWS_GUIDE.md → Workflow #2
2. Reproduce it
3. Fix it (Check SQL/Logs)
4. Test it

### 🚀 I need to deploy to production
1. Read COMPLETE_WORKFLOWS_GUIDE.md → Workflow #3
2. Check pre-deployment checklist
3. `supabase functions deploy`

---

## 🔍 Troubleshooting

### I don't understand something
1. Check MASTER_MINDSET.md
2. Look in specific docs/ files
3. Ask in Slack #kadmat-dev

### The app won't run
1. Check docs/TROUBLESHOOTING.md
2. Run `flutter doctor`
3. Run `supabase status` (if local)

### Tests are failing
1. Read error message carefully
2. Check QUICK_REFERENCE.md → Testing
3. Debug with DevTools

---

## 🎓 You're All Set!

**Next Step:** Open **MASTER_MINDSET.md** and start reading!

```
1. 📄 Read MASTER_MINDSET.md (30-45 min)
2. 💫 Check KADMAT_MASTER_OVERVIEW.html (20 min)
3. 📢 Practice QUICK_REFERENCE.md commands (15 min)
4. 📊 Pick your first task
5. 🚀 Execute the appropriate workflow
6. 👊 Request code review
7. 📊 Deploy with confidence
```

---

## 📞 Help & Support

- 📧 **Email:** support@kadmat.ly
- 💬 **Slack:** #kadmat-dev
- 🐛 **Issues:** GitHub Issues
- 📚 **Wiki:** GitHub Wiki

---

**Good luck! The world of Kadmat awaits you! 🚀**
