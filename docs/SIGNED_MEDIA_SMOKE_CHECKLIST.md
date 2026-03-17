# Signed Media Smoke Checklist (Staging + Production)

Last updated: 2026-02-22
Owner: Backend + Mobile QA

## Goal
Validate that job media is served through signed URLs, access is role-scoped, and expiry behavior is correct.

## Preconditions
- Backend deployed with `GET /api/jobs/:id/media-signed`.
- Test job exists with at least one:
  - `pre` photo
  - `post` photo
  - `customer` photo
- Three tokens ready:
  - `CUSTOMER_TOKEN` (job owner)
  - `TECHNICIAN_TOKEN` (assigned to same job)
  - `OTHER_USER_TOKEN` (not related to the job)

Set variables:

```bash
export API_BASE="https://<staging-or-prod-domain>"
export JOB_ID="<job-id>"
export CUSTOMER_TOKEN="<jwt>"
export TECHNICIAN_TOKEN="<jwt>"
export OTHER_USER_TOKEN="<jwt>"
```

## One-command run (recommended)

```bash
cd /Users/wew/Desktop/kadmat/backend
API_BASE="https://<staging-or-prod-domain>" \
JOB_ID="<job-id>" \
CUSTOMER_TOKEN="<jwt>" \
TECHNICIAN_TOKEN="<jwt>" \
OTHER_USER_TOKEN="<jwt>" \
npm run smoke:signed-media
```

Optional: instead of tokens, pass credentials and script logs in automatically:

```bash
cd /Users/wew/Desktop/kadmat/backend
API_BASE="https://<staging-or-prod-domain>" \
JOB_ID="<job-id>" \
CUSTOMER_EMAIL="<customer-email>" CUSTOMER_PASS="<customer-pass>" \
TECH_EMAIL="<tech-email>" TECH_PASS="<tech-pass>" \
OTHER_EMAIL="<other-email>" OTHER_PASS="<other-pass>" \
npm run smoke:signed-media
```

## Test 1: Customer can fetch signed media

```bash
curl -sS -i "$API_BASE/api/jobs/$JOB_ID/media-signed?expiresIn=600" \
  -H "Authorization: Bearer $CUSTOMER_TOKEN"
```

Expected:
- HTTP `200`
- Response contains arrays:
  - `data.prePhotos`
  - `data.postPhotos`
  - `data.customerPhotos`
- At least one URL starts with Supabase signed URL format.

## Test 2: Assigned technician can fetch same media

```bash
curl -sS -i "$API_BASE/api/jobs/$JOB_ID/media-signed?expiresIn=600" \
  -H "Authorization: Bearer $TECHNICIAN_TOKEN"
```

Expected:
- HTTP `200`
- Same media groups available for technician.

## Test 3: Unrelated user is blocked

```bash
curl -sS -i "$API_BASE/api/jobs/$JOB_ID/media-signed?expiresIn=600" \
  -H "Authorization: Bearer $OTHER_USER_TOKEN"
```

Expected:
- HTTP `403` (or `404` if policy hides existence)
- Never `200`.

## Test 4: Unauthenticated request is blocked

```bash
curl -sS -i "$API_BASE/api/jobs/$JOB_ID/media-signed?expiresIn=600"
```

Expected:
- HTTP `401`.

## Test 5: TTL expiration behavior
1. Fetch signed media with short expiry:

```bash
curl -sS "$API_BASE/api/jobs/$JOB_ID/media-signed?expiresIn=300" \
  -H "Authorization: Bearer $CUSTOMER_TOKEN"
```

2. Open one returned URL immediately -> should load.
3. Wait 6-10 minutes.
4. Open same URL again.

Expected:
- URL eventually expires and no longer grants access.
- Re-fetching endpoint returns fresh working signed URLs.

## Pass Criteria
- Tests 1/2 return `200`.
- Tests 3/4 block access (`403/404`, `401`).
- TTL behaves as expected (old link expires, fresh link works).

## Fail / Rollback Triggers
- Any unrelated user receives `200`.
- Signed URLs never expire.
- App cannot render media for valid participant.

## Post-Smoke Logging
Record in release evidence:
- environment (`staging` or `prod`)
- `job_id` used
- status code per test
- screenshot/snippet of one successful signed URL load
