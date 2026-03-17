# Release Evidence - 2026-02-19

## 1) Release Metadata
- Date: 2026-02-19
- Commit SHA: `68f6b206029b64caccf7d165a4f1ff75a702d480`
- Branch: `main`
- Supabase project ref: `wwukyrixgkgagofyrlsq`

## 2) Production Database Migrations (Executed)
- `29_create_api_idempotency_keys.sql`: PASS (`BEGIN`/`COMMIT`, idempotent notices only)
- `30_wallet_commission_idempotency.sql`: PASS (`BEGIN`/`COMMIT`, idempotent notices only)
- `31_add_jobs_after_photos.sql`: PASS (`BEGIN`/`COMMIT`, idempotent notices only)
- `32_notifications_dedupe_key_upsert_fix.sql`: PASS (`BEGIN`/`COMMIT`, idempotent notices only)

## 3) Runtime Config (Production)
- `FEATURE_WALLET_SYSTEM=true`
- `FEATURE_PRICE_CHANGE=true`
- `FEATURE_STALE_LOCK_RECOVERY=true`
- `FEATURE_IDEMPOTENCY_STRICT=true`
- `STALE_LOCK_HOURS=6`
- `IDEMPOTENCY_TTL_HOURS=48`

## 4) Runtime Restart Verification
- Backend startup logs confirmed:
  - `Server listening on port: 3000`
  - `Job Retry Scheduler started`
  - `Job Expiry Scheduler started`
  - `Notification Cleanup Scheduler started`
  - `Stale Lock Recovery Scheduler started`

## 5) Production Smoke Results

### 5.1 Idempotency (accept-offer replay)
- Job: `10d1e973-41c7-489d-82e3-764316aa331b`
- Offer: `f65536dd-5d2c-4e5e-ba17-88a38d84c0ed`
- Request 1: `POST /api/jobs/:id/accept-offer` -> `200 OK`
- Request 2 (same `X-Idempotency-Key`): `200 OK` + `X-Idempotency-Replayed: true`
- Outcome: PASS

### 5.2 End-to-end flow to completion (test accounts only)
- Customer test user created
- Technician test user created
- Flow:
  - `create job` -> `201`
  - `submit offer` -> `201`
  - `accept offer` -> `200` (status `on_the_way`)
  - `technician arrived` -> `200`
  - `technician start_work` -> `200` (status `in_progress`)
  - `request completion` (no photos) -> `400 MISSING_PHOTOS` (expected)
  - `request completion` (with `afterPhotos`) -> `200` (status `pending_confirm`)
  - `confirm completion` (`payment_method=cash`) -> `200` (status `completed`)
  - `GET /api/jobs/:id` final -> `completed`
- Validation IDs:
  - Job: `a5a6acde-e05e-4552-84a5-4a29229230c9`
  - Offer: `d36c1be5-1837-4615-abda-2d12b8d6102b`
- Outcome: PASS

## 6) Data Plane Checks
- Tables present:
  - `public.api_idempotency_keys`
  - `public.jobs`
  - `public.notifications`
- Hotfix schema checks:
  - `jobs.after_photos` exists
  - `idx_notifications_dedupe_key_full` exists
- Recent idempotency rows include:
  - `/accept-offer` -> `200`
  - `/request-completion` -> `400` (expected negative test) and `200`
  - `/confirm-completion` -> `200`

## 7) Observability Snapshot
- `/metrics` confirms:
  - `job_accept_offer_requests_total{status_code="200"} = 2`
  - `idempotency_events_total{endpoint="/api/jobs/:id/accept-offer", outcome="replayed"} = 1`
  - No `notification_audience_mismatch_total` samples observed
- `api_idempotency_keys` since `2026-02-19 15:00:00+00`:
  - `5xx = 0`
  - `4xx = 1` (expected `MISSING_PHOTOS` negative test)
  - `2xx = 4`

## 8) Known Non-Blocking Notes
- Push delivery skipped when `FIREBASE_SERVICE_ACCOUNT` is not configured in this runtime session.
- Node-cron printed several `missed execution` warnings in this session; no flow break was observed in smoke outcomes.

## 9) Final Status
- Release Gates: PASS
- Production status: LIVE
- Monitoring: active and stable for the validated smoke window
