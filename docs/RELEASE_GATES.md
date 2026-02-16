# RELEASE GATES (Mandatory)

## Gate A - Code Quality
- `flutter analyze` = PASS
- `flutter test` = PASS
- `npm test -- --runInBand` = PASS
- optional one-shot gate: `bash scripts/run_predeploy_gate.sh`

## Gate B - Database Contract
- Apply migrations in order:
  - `18`
  - `19`
  - `20`
  - `22` (accepted bid reference)
  - `23` (update_user_location RPC)
  - `24` (atomic accept-offer RPC)
  - `25` (on_the_way/arrived + active locks)
- Run RPC audit:
  - `backend/sql/rpc/check_get_nearby_jobs_contract.sql`
- Run acceptance contract audit:
  - `cd backend && npm run audit:accept-offer-contract`
- CI monitor:
  - `.github/workflows/accept_offer_contract_audit.yml` = PASS
- Expected:
  - `audit_report.ok = true`
  - accept-offer audit = PASS

## Gate C - Functional Smoke (Manual)
1. Customer creates new job.
2. Technician sees job in new requests.
3. Technician submits offer.
4. Customer accepts offer.
5. Job moves to `on_the_way` (or legacy `in_progress`) without error page/toast.
6. Technician marks `arrived`.
7. Technician marks `start_work` -> status `in_progress`.

## Gate D - Cancel Consistency
1. Customer cancels open job.
2. Job disappears from technician queue in realtime (<= 2s) or fallback (<= 10s).

## Gate E - Error Contract
- No raw stack traces in user UI.
- API error codes mapped to user-friendly Arabic messages.

## Gate F - Evidence & Monitoring
- `docs/RELEASE_EVIDENCE_TEMPLATE.md` filled for staging + production.
- `docs/POST_DEPLOY_MONITORING_CHECKLIST.md` filled after 60-minute window.

## Blockers (Do Not Release If)
- Any `accept-offer` returns `500` in smoke scenario.
- Missing critical DB function used by live flow (e.g. location update RPC).
- Repeated stale/open jobs appear after app restart without valid status.
