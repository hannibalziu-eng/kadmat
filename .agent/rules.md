# 🔧 Antigravity Rules for Kadmat Project
## قواعد العمل ومشروع كدمات (Kadmat)

***

## 🔐 Security & Architecture Guidelines

### Terminal Execution Policy
- **Recommended:** Agent-Assisted (Auto) mode
- **Allow List:** Only essential safe commands (npm, flutter, git)
- **Deny List:** Destructive commands (rm -rf, dd, system modifications)

### Code Generation Standards
* All code must follow **Dart/Flutter** style guide (Clean Architecture).
* All code must follow **Node.js/Express** best practices.
* Separate business logic from UI layer using **Repository pattern**.
* Use dependency injection (GetIt/Riverpod).
* **Strictly Typed:** Use `Freezed` models for all data transfers.
* **Localization:** Use `easy_localization` or standard `l10n`. All UI strings must be localized.

***

## 🛡️ Security Rules for Kadmat (Supabase Edition)

### Database Security
* **Row Level Security (RLS) is MANDATORY:** All tables MUST have RLS enabled.
* **Service Role Key:** 
  - ❌ NEVER use `SUPABASE_SERVICE_ROLE_KEY` in the Flutter app.
  - ✅ ONLY use it in the Node.js Backend or Edge Functions.
* **Data Access:**
  - Technicians can ONLY `SELECT` jobs that are `'pending'`, `'searching'` (within radius), or assigned to them via RLS.
  - Customers can ONLY view their own jobs.
* **Sensitive Data:** Phone numbers are hidden from the technician until job status is `accepted`.

### API & Backend Security
* All API endpoints MUST validate the `Authorization: Bearer <token>` header (Supabase JWT).
* Validate `technician_id` matches the authenticated user in all operations.
* Sanitize all inputs to prevent SQL Injection (even with ORMs).
* Rate Limit sensitive endpoints (Auth, Search) in Node.js.

### Job Status Flow Security
* **price_pending:** Technician is **UNLOCKED** (Can explore other jobs).
* **accepted/in_progress:** Technician is **LOCKED** (Cannot accept new jobs).
* **no_technician_found:** Auto-flagged via Scheduled Job or Cron after 2 hours.
* **State Transitions:** MUST be validated on Backend (Node.js/SQL), never trust the Client.

***

## 🏗️ Architecture Rules

### Directory Structure
* **Flutter:** `lib/src/features/` (Feature-based structure).
* **Backend:** `src/controllers`, `src/services`, `src/routes`.

### Repository Pattern Rules
* **Flutter:** `UI` → `Controller` → `Repository` → `DataSource` (Supabase SDK / API).
* **Backend:** `Route` → `Controller` → `Service` → `Supabase Client`.
* **Caching:** Don't cache job status aggressively; it requires real-time accuracy.

### Supabase & Real-time
* Use `Supabase.instance.client.channel` for real-time status updates (e.g., job acceptance).
* Use `rpc` calls for complex geospatial queries (`get_nearby_jobs`).

***

## 🔄 Kadmat Status Logic

### Job Status Lifecycle
1. **pending / searching:**
   - Job created. Visible to nearby technicians.
   - Expires/Hides after 24h (general) or 2 hours (if no technician found logic triggers).
2. **accepted:**
   - Technician accepted.
   - **Restriction:** Technician is **LOCKED**.
3. **price_pending:**
   - Technician proposed price.
   - **Restriction:** Technician is **UNLOCKED** (can browse).
4. **in_progress:**
   - Work started.
   - **Restriction:** Technician is **LOCKED**.
5. **pending_confirm:**
   - Work done, waiting for payment/confirmation.
6. **completed:**
   - Finished and paid.
7. **cancelled:**
   - Terminated.

### Location Logic (PostGIS)
* Use `ST_DWithin` for all distance queries.
* Update Technician location:
    - **Idle:** Every 5-10 minutes.
    - **Active (Traveling/Working):** Every 30 seconds.

***

## ⚠️ Prohibited Actions
* ❌ Hard-coding `SUPABASE_SERVICE_ROLE_KEY` in the mobile app.
* ❌ Client-side status manipulation (e.g., `job.status = 'completed'` directly from Flutter). MUST call API endpoint.
* ❌ Storing Credit Card info in `users` table.
* ❌ Creating tables without RLS policies.

***

## 🎯 Priority Rules (Kadmat Specific)

1.  **Backend Authority:** The Node.js API (or Supabase Edge Functions) is the source of truth, not the Flutter App state.
2.  **Concurrency:** Handle the case where two technicians accept the same job at the exact same millisecond (Database Constraints/Transactions).
3.  **Notifications:** Critical flows (Accept, Arrive, Complete) MUST send FCM notifications.

***
