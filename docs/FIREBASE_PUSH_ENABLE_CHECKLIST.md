# Firebase Push Enable Checklist (P1)

## Goal
Enable production push notifications with `FIREBASE_SERVICE_ACCOUNT` and verify delivery.

## 1) Prepare service account JSON (Firebase Console)
- Open Firebase Console -> Project Settings -> Service accounts.
- Generate a new private key (JSON).
- Keep it in a secure secret manager only (never commit to git).

## 2) Set runtime secrets
Set one of:
- `FIREBASE_SERVICE_ACCOUNT` (global), or
- `STAGING_FIREBASE_SERVICE_ACCOUNT` / `PROD_FIREBASE_SERVICE_ACCOUNT` (target-specific)

Format supported by backend:
- raw JSON string, or
- base64-encoded JSON string.

Also ensure:
- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set for target audit.

Helper to convert JSON file to base64 (for env secrets):

```bash
cd /Users/wew/Desktop/kadmat/backend
bash scripts/firebase-service-account-to-base64.sh /absolute/path/service-account.json
```

## 3) Runtime audit

```bash
cd /Users/wew/Desktop/kadmat/backend
bash scripts/audit-firebase-runtime.sh staging
# then
bash scripts/audit-firebase-runtime.sh prod
```

If audit reports missing `users.fcm_token`, apply:

```sql
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON public.users(fcm_token);
```

Expected:
- `Firebase init status: initialized=true`
- `users with non-null fcm_token: <number>`
- `Firebase runtime audit passed`

## 4) Optional live push smoke (single user)
Use a user id that already has `users.fcm_token` set:

```bash
cd /Users/wew/Desktop/kadmat/backend
bash scripts/audit-firebase-runtime.sh prod --user <USER_ID>
```

Expected:
- `Push smoke sent successfully to user=<USER_ID>`

## 5) App-level flow smoke
Verify push appears for:
- `new_offer`
- `technician_arrived`
- `job_completed`

## 6) Success criteria
- No log: `Firebase not initialized - skipping push`
- Push events delivered on device for critical flows.
- `P1` push item in backlog can be marked `DONE`.
