# Post-Deploy Monitoring Log - 2026-02-16

## Context
- Scope: accept-offer stabilization + location RPC compatibility
- Reference checklist: `docs/POST_DEPLOY_MONITORING_CHECKLIST.md`
- Commit: `8b85035978bfaa847db76ed358ed8147dcf3bfd7`

## Pre-Monitoring Baseline
- Contract audits: PASS
- Live smoke transitions: PASS (`on_the_way -> arrived -> in_progress`)
- Live `update_user_location` check: PASS

## Monitoring Window
- Start: Pending
- End: Pending
- Owner: Pending

## Signals to Capture During Window
- Accept-offer success/error ratio
- Repeated 409 on same `jobId`
- Any `PGRST202` for `accept_job_offer_atomic` / `update_user_location`
- Any `ACCEPT_FAILED` spikes

## Rollback Trigger
- If `accept-offer` 500 errors exceed 1%, rollback backend app version only.
