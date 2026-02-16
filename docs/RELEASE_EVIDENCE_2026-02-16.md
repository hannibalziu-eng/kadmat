# Release Evidence - 2026-02-16

## 1) Release Metadata
- Date: 2026-02-16
- Commit SHA: `8b85035978bfaa847db76ed358ed8147dcf3bfd7`
- Branch: `main`
- Git push: `main -> origin/main` completed
- Supabase project ref (from `backend/.env`): `wwukyrixgkgagofyrlsq`

## 2) Build/Test Gate
- `bash scripts/run_predeploy_gate.sh`: PASS
  - `dart analyze`: PASS
  - `flutter test`: PASS
  - `backend npm test -- --runInBand`: PASS (6 suites, 25 tests)

## 3) Contract Audits (Live)
- Executed with `backend/.env` credentials:
  - `npm run audit:accept-offer-contract`: PASS
  - `npm run audit:rpc`: PASS
  - `npm run audit:release-contracts`: PASS

## 4) Live Smoke Checks (Supabase, cleaned up after run)
- Smoke #1: `accept_job_offer_atomic`
  - Created temporary job + offer
  - Accepted offer through RPC
  - Verified final status `on_the_way`
  - Result: PASS

- Smoke #2: backend service flow (`jobService`)
  - Created temporary job + offer
  - Called `jobService.acceptOffer(...)` -> `on_the_way`
  - Called `jobService.updateTechnicianProgress(..., 'arrived')` -> `arrived`
  - Called `jobService.updateTechnicianProgress(..., 'start_work')` -> `in_progress`
  - Result: PASS

## 5) Migrations Verification Status
- Direct SQL migration execution from this workspace was not required in this run because the live contract and smoke checks prove migration effects are already present:
  - `jobs.accepted_bid_id` readable
  - `accept_job_offer_atomic` exists and returns contract payload
  - `update_user_location` exists and executes
  - `on_the_way` / `arrived` transitions are accepted in live flow

## 6) Remaining Operational Steps
- Monitor production for 60 minutes using `docs/POST_DEPLOY_MONITORING_CHECKLIST.md`.
- If backend hosting does not auto-deploy from `main`, trigger manual deploy on the hosting platform.
