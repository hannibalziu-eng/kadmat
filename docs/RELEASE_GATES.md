# RELEASE GATES (Mandatory)

## Gate A - Code Quality
- `flutter analyze` = PASS
- `flutter test` = PASS
- `npm test -- --runInBand` = PASS

## Gate B - Database Contract
- Apply migrations in order:
  - `18`
  - `19`
  - `20`
  - `22` (accepted bid reference)
- Run RPC audit:
  - `backend/sql/rpc/check_get_nearby_jobs_contract.sql`
- Expected:
  - `audit_report.ok = true`

## Gate C - Functional Smoke (Manual)
1. Customer creates new job.
2. Technician sees job in new requests.
3. Technician submits offer.
4. Customer accepts offer.
5. Job moves to `in_progress` without error page/toast.

## Gate D - Cancel Consistency
1. Customer cancels open job.
2. Job disappears from technician queue in realtime (<= 2s) or fallback (<= 10s).

## Gate E - Error Contract
- No raw stack traces in user UI.
- API error codes mapped to user-friendly Arabic messages.

## Blockers (Do Not Release If)
- Any `accept-offer` returns `500` in smoke scenario.
- Missing critical DB function used by live flow (e.g. location update RPC).
- Repeated stale/open jobs appear after app restart without valid status.
