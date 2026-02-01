# 🔄 KADMAT - Complete Workflows Guide
## دليل العمل العملي المفصل لـ Code Agent

---

## 🔐 Workflow 1: Fix Bug (Job Locking Issue) - مثال تطبيقي

### 🃋 Problem Description
```
❌ المشكلة:
   التقني لا يستطيع قبول مزيد من الطلبات
   لو كان لديه طلب واحد في حالة price_pending

❌ التاثير:
   - قللة دخل التقنيين
   - عناصر لا تزال في النظام (inactive jobs)
   - تقيمات منخفضة

✅ الاستباقة:
   المنطق: مرحلة price_pending ليست مرحلة locking
   فقط accepted و in_progress بيقفلو التقني
```

### 📄 Files to Modify
 
 **1. Backend - Edge Functions**
 ```
 File: backend/functions/accept_job/index.ts
 File: backend/functions/propose_price/index.ts
 
 Changes:
   - عدل لوجيك القفل
   - أضف validation
   - أضف logging
 ```
 
 **2. Flutter - App**
 ```
 File: flutter/lib/src/features/jobs/data/job_repository.dart
 
 Methods to change:
   - isTechnicianLocked(String technicianId)
   - watchTechnicianLockStatus(String technicianId)
   - canAcceptNewJob(String technicianId)
 
 Logic:
   only 'accepted' and 'in_progress' lock the technician
   REMOVE 'price_pending' from locked statuses
 ```
 
 **3. Database - SQL**
 ```
 File: backend/migration/fix_expiration_and_visibility.sql
 
 Changes:
   - Job visibility window for 'no_technician_found' = 2 hours (not 24)
   - Jobs in 'pending' or 'searching' = 24 hours
   - Other jobs = permanent
 ```
 
 ### ⏱️ Timeline Estimate
 ```
 📍 Step 1: Backend Logic - 1 hour
    ☐ Update Edge Functions
    ☐ Test with curl/Postman
    ☐ Check Supabase logs
 
 📍 Step 2: Flutter Repository - 45 minutes
    ☐ Update lock checking logic
    ☐ Write unit tests
    ☐ Test on emulator
 
 📍 Step 3: Database - 30 minutes
    ☐ Update SQL function
    ☐ Test query results
 
 📍 Step 4: Integration Testing - 1 hour
    ☐ Create test user (technician)
    ☐ Create test job
    ☐ Verify full flow
 
 📍 Step 5: Code Review + Deploy - 1 hour
 ```
 
 ### 🔍 Testing Checklist
 
 ```
 ✅ Unit Tests:
    ☐ isTechnicianLocked() returns false for price_pending
    ☐ isTechnicianLocked() returns true for accepted
    ☐ isTechnicianLocked() returns true for in_progress
 
 ✅ Integration Tests:
    ☐ Tech accepts job 1 → status = accepted
    ☐ Tech proposes price → status = price_pending
    ☐ Tech can accept job 2 → should succeed
    ☐ Tech accepts job 2 → now has 2 active jobs
 
 ✅ Job Visibility:
    ☐ Job in 'no_technician_found' disappears after 2 hours
    ☐ Job in 'pending' stays for 24 hours
    ☐ Job in 'searching' stays for 24 hours
    ☐ Completed/Cancelled jobs don't appear
 
 ✅ Performance:
    ☐ Query runs in < 500ms
    ☐ RLS policies validated
    ☐ No N+1 queries
 ```
 
 ### 🚀 Deployment Steps
 
 ```
 1️⃣ Local Testing
    supabase start
    flutter run (or iOS/Android)
    Test complete flow
 
 2️⃣ Staging Deployment
    git checkout -b feature/fix-job-locking
    git add .
    git commit -m "fix: allow technicians to accept jobs while price_pending"
    git push origin feature/fix-job-locking
    → Create PR
    → Deploy to staging
 
 3️⃣ Production Deployment
    supabase functions deploy
    supabase db push
    → Monitor error logs
    → Check job acceptance rate
 ```

---

## 🚀 Workflow 2: Add New Feature (Messaging System)

### 🃄 Feature Requirements

```
✍️ USER STORIES:
   Story 1: Customer can send message to technician
   Story 2: Technician can reply to customer
   Story 3: Messages appear in real-time
   Story 4: Notification when new message arrives
   Story 5: Chat history is saved

📚 ACCEPTANCE CRITERIA:
   ✓ Messages sent in < 1 second
   ✓ Messages load in < 500ms
   ✓ Notifications arrive within 5 seconds
   ✓ No message loss
   ✓ Works offline (sync when online)
```
 
### 📄 Implementation Plan

**Phase 1: Database Design (1 hour)**
```sql
 -- Create Tables in Supabase (SQL)
 
 CREATE TABLE conversations (
   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
   created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
   updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
 );
 
 CREATE TABLE conversation_participants (
   conversation_id UUID REFERENCES conversations(id),
   user_id UUID REFERENCES auth.users(id),
   PRIMARY KEY (conversation_id, user_id)
 );
 
 CREATE TABLE messages (
   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
   conversation_id UUID REFERENCES conversations(id),
   sender_id UUID REFERENCES auth.users(id),
   content TEXT NOT NULL,
   created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
   read_at TIMESTAMP WITH TIME ZONE
 );
 
 -- DON'T FORGET RLS POLICIES!
 ```

**Phase 2: Backend Functions (3 hours)**
```
Edge Functions (Deno):
  ✓ send_message (can be done via direct SQL too)
  ✓ send_notification (trigger on new message)

Realtime:
  ✓ Enable Realtime on 'messages' table
  ✓ Client subscribes to INSERT events
```

**Phase 3: Flutter Implementation (4 hours)**
```
Models:
  ✓ Message model (Freezed)
  ✓ ChatRepository (SupabaseClient)

UI Pages:
  ✓ ConversationListPage
  ✓ ChatPage (detailed view)
  ✓ ChatBubble widget

Features:
  ✓ Real-time message updates (Supabase Stream)
  ✓ Auto-scroll to latest
  ✓ Typing indicator (Presence)
  ✓ Read receipts
```

**Phase 4: Testing (2 hours)**
```
✓ Unit tests for models
✓ Widget tests for UI
✓ Integration tests for flow
✓ Performance tests
```

### 🔍 Quality Gate

```
✅ Code Review:
   ☐ 70%+ code coverage
   ☐ No security issues (RLS)
   ☐ Performance OK
   ☐ Documentation complete

✅ Testing:
   ☐ All tests passing
   ☐ Tested on real device
   ☐ Offline mode works
   ☐ Notifications work

✅ Performance:
   ☐ Message send < 1s
   ☐ List load < 500ms
   ☐ Memory < 150MB
```

---

## 🚀 Workflow 3: Deploy to Production (Release Process)

### 📄 Pre-Deployment Checklist

**Week Before Release**
```
☐ Code freeze
☐ All features merged to main
☐ Run full test suite
☐ Performance profiling
☐ Security audit
☐ Staging deployment
☐ UAT testing
☐ Stakeholder approval
```

**Day Before Release**
```
☐ Supabase Database backup
☐ Document migration steps
☐ Prepare rollback plan
☐ Notify team
☐ Set monitoring alerts
☐ Prepare release notes
☐ Update documentation
```

### 🚀 Release Steps

```
1️⃣ Update Version
   flutter/pubspec.yaml: version: 1.3.0
   web/package.json: "version": "1.3.0"
   Create tag: git tag v1.3.0

2️⃣ Build Artifacts
   # Flutter
   flutter build apk --release --build-number=130
   flutter build ios --release --build-number=130
   
   # Web
   npm run build
   # Deploy Web Admin to Vercel/Netlify or Supabase Storage

3️⃣ Deploy Backend
   supabase functions deploy
   supabase db push
   → Monitor Supabase logs for errors
   → Check invocation count

4️⃣ Smoke Tests
   ☐ Login works
   ☐ Create job works
   ☐ Accept job works
   ☐ Payment flow works
   ☐ Notifications work
   ☐ Real-time updates work

5️⃣ Monitor
   ☐ Error rate < 0.1%
   ☐ Performance OK
   ☐ No database issues
   ☐ User feedback positive

6️⃣ Announce
   ☐ Release notes published
   ☐ Team notified
   ☐ Users notified (if needed)
   ☐ Status page updated
```

### 🔟 Rollback Plan

```
IF CRITICAL ISSUE:

1️⃣ Identify Problem
   - Check error logs
   - User reports
   - Monitoring alerts

2️⃣ Assess Severity
   - Can it be fixed quickly?
   - How many users affected?
   - Is rollback needed?

3️⃣ Rollback (if needed)
   git revert <commit-hash>
   supabase functions deploy
   → Redeploy previous APK version

4️⃣ Post-Mortem
   - What went wrong?
   - How to prevent?
   - Update docs
```

---

## 🔐 Workflow 4: Security Audit

### 📄 Security Checklist

**Code Security**
```
☐ No hardcoded passwords/API keys
☐ No SQL injection vulnerabilities (Use Parameterized Queries)
☐ No XSS vulnerabilities
☐ CSRF tokens in place
☐ Input validation everywhere
☐ Output encoding
☐ HTTPS enforced
☐ secure HTTP headers
```

**Supabase Security**
```
☐ RLS Policies reviewed (CRITICAL)
☐ Read rules restrictive
☐ Write rules restrictive
☐ Authentication required
☐ Role-based access control (Technician vs Customer)
☐ No public data exposed
```

**Data Protection**
```
☐ Sensitive data encrypted
☐ Passwords hashed (Supabase Auth handles this)
☐ Data retention policy
☐ Audit logs kept
```

**Infrastructure**
```
☐ Supabase PITR (Point in Time Recovery) enabled
☐ Rate limiting enabled
☐ Logging enabled
```

**Dependency Security**
```
☐ flutter pub outdated
☐ npm audit
☐ Check for CVE vulnerabilities
☐ Update vulnerable packages
```

---

## 🐛 Workflow 5: Performance Optimization

### 📄 Performance Targets

```
💡 App Startup: < 3 seconds
💡 Job List Load: < 1 second
💡 Chat Load: < 500ms
💡 Memory Usage: < 100MB
💡 Database Query: < 200ms
💡 FPS: 60 FPS constant
```

### 📄 Optimization Steps

**1. Database Optimization (2 hours)**
```
☐ Create indexes on frequently queried fields (Postgres Indexes)
☐ Analyze slow queries (Explain Analyze)
☐ Remove unnecessary data fetch (Select specific columns)
☐ Use pagination (limit/offset)
☐ Cache frequently accessed data
```

**2. Frontend Optimization (2 hours)**
```
☐ Image compression
☐ Lazy loading of widgets
☐ Use const constructors
☐ Remove unused dependencies
☐ Use ListView.builder for lists
☐ Minimize rebuilds
```

**3. Network Optimization (1 hour)**
```
☐ Reduce payload size
☐ Implement caching
☐ Batch requests
```

**4. Testing (1 hour)**
```
☐ Use DevTools profiler
☐ Check memory leaks
☐ Measure load times
☐ Test on low-end device
```

---

## 📋 Workflow 6: Code Review & Quality Gate

### 📄 Code Review Checklist

```
✅ Functionality:
   ☐ Does it solve the problem?
   ☐ Does it break anything else?
   ☐ Edge cases handled?
   ☐ Error cases handled?

✅ Code Quality:
   ☐ Follows project conventions?
   ☐ Naming makes sense?
   ☐ No duplicate code?
   ☐ Functions < 50 lines?
   ☐ Comments clear?

✅ Testing:
   ☐ Unit tests written?
   ☐ Integration tests written?
   ☐ 70%+ coverage?
   ☐ All tests passing?

✅ Security:
   ☐ No hardcoded secrets?
   ☐ Input validated?
   ☐ No SQL injection? (Use Parameterized Queries)
   ☐ RLS Policies validated?

✅ Performance:
   ☐ No N+1 queries?
   ☐ Algorithms efficient?
   ☐ Memory usage OK?
   ☐ No memory leaks?

✅ Documentation:
   ☐ Code documented?
   ☐ API documented?
   ☐ Migration docs (if needed)?
```

### 📄 Quality Gate Passing Criteria

```
✅ ALL of the following must be true:
   1. Code compiles without errors
   2. All tests passing (100%)
   3. Code coverage > 70%
   4. Linter: 0 errors, 0 warnings
   5. No security vulnerabilities
   6. Performance acceptable
   7. Documentation complete
   8. At least 1 approval
   9. No merge conflicts
  10. Ready for production
```

---

## 🃋 Workflow 7: Database Migration

### 📄 Safe Migration Steps

```
1️⃣ Planning (1 hour)
   ☐ Write migration SQL script
   ☐ Create backup
   ☐ Test on local supabase
   ☐ Estimate time
   ☐ Plan rollback

2️⃣ Backup (30 min)
   supabase db dump -f backup.sql
   → Store in safe place
   → Verify backup integrity

3️⃣ Run Migration (varies)
   ☐ supabase db push (Remote)
   ☐ Verify data

4️⃣ Validation (30 min)
   ☐ Check data integrity
   ☐ Run queries
   ☐ Monitor performance
   ☐ No errors in logs

5️⃣ Monitoring (2-4 hours)
   ☐ Watch error rate
   ☐ Monitor queries
   ☐ Check user reports
```

---

**✨ End of Workflows Guide**
