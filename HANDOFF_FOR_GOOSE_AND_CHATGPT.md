# HANDOFF FOR GOOSE AND CHATGPT

## Executive summary

`kadmat` is a Flutter + Node/Supabase service marketplace app with active customer and technician flows already implemented. The codebase is in a stronger state than earlier sessions: backend contracts are stable, Flutter analysis is clean, backend tests are green, and Flutter tests are green.

The most important caveat is this:

- the **current local working tree is materially ahead of the latest committed baseline**
- the repository is on `main`, but the worktree is **dirty**
- any new agent must treat the **current working tree** as the active state if continuing local work

Latest confirmed committed HEAD during inspection:

- `0398fd8` — `test: harden playwright local qa baseline`

## What was recently developed

The current working tree includes significant local work across:

- theme/token unification
- auth/welcome redesign
- customer home redesign
- customer request creation redesign
- orders/profile/messages/account surfaces
- technician dashboard/requests/job detail simplification
- communication gating and API-backed message behavior
- manual location fallbacks for request/dispatch flows

Files with major recent churn include:

- `lib/main.dart`
- `lib/src/core/app_theme.dart`
- `lib/src/core/design/kadmat_tokens.dart`
- `lib/src/core/widgets/kadmat_components.dart`
- `lib/src/features/home/presentation/home_screen.dart`
- `lib/src/features/jobs/presentation/screens/customer_service_request_screen.dart`
- `lib/src/features/jobs/presentation/screens/customer_screens.dart`
- `lib/src/features/jobs/presentation/screens/customer_job_tracking_screen.dart`
- `lib/src/features/orders/presentation/orders_screen.dart`
- `lib/src/features/profile/presentation/profile_screen.dart`
- `lib/src/features/technician/presentation/dashboard/technician_dashboard_screen.dart`
- `lib/src/features/technician/presentation/requests/technician_requests_screen.dart`
- `lib/src/features/technician/presentation/jobs/technician_job_detail_screen.dart`

## What any agent must understand before changing anything

### 1. The repository state is not clean

Do **not** assume HEAD tells the whole story.

At inspection time:

- branch: `main`
- dozens of tracked files modified locally
- many untracked files present

This means:

- local app behavior may differ from the latest commit history
- handoff must be grounded in the current files on disk

### 2. There is a clean canonical app flow, and it should not be broken

Primary references:

- `docs/MASTER_FLOW_SPEC.md`
- `lib/src/core/router_modular.dart`
- `lib/src/core/router/route_modules.dart`
- `lib/src/core/navigation/app_routes.dart`

Canonical customer flow:

- create request
- searching
- offer/price review
- in progress
- confirm completion
- payment processing
- rate
- completed

Canonical technician flow:

- go online
- receive nearby jobs
- offer / price
- accepted / waiting
- on the way / arrived / in progress
- completion

### 3. Communication is intentionally gated

Read first:

- `backend/src/utils/jobCommunication.js`
- `backend/src/controllers/messageController.js`
- `lib/src/features/messages/data/messages_repository.dart`

Do not reintroduce direct-table messaging or pre-accept communication by accident.

### 4. Current web/device behavior has environment constraints

Important file:

- `lib/src/core/api/endpoints.dart`

Notes:

- on web, API base derives from the page host if `API_BASE` is not set
- local phone access over `http://192.168.x.x` is not a secure origin
- browser geolocation on phones is therefore limited unless using HTTPS
- the request flow now includes a manual map fallback to compensate

## First files to read

If a new agent needs to get oriented fast, start here:

1. `docs/MASTER_FLOW_SPEC.md`
2. `docs/EXECUTION_BACKLOG.md`
3. `lib/src/core/router_modular.dart`
4. `lib/src/core/router/route_modules.dart`
5. `lib/src/core/navigation/app_routes.dart`
6. `lib/src/features/jobs/presentation/screens/customer_service_request_screen.dart`
7. `lib/src/features/jobs/presentation/screens/customer_screens.dart`
8. `lib/src/features/technician/presentation/requests/technician_requests_screen.dart`
9. `backend/src/services/jobService.js`
10. `backend/src/utils/jobStateMachine.js`
11. `backend/src/utils/jobCommunication.js`
12. `backend/src/utils/responseFormatter.js`

## Current risks

### 1. Dirty worktree risk

There is a large amount of local work not yet represented in the latest committed history. Any merge/rebase/cherry-pick work is risky unless the agent first understands whether to preserve or discard current local edits.

### 2. Migration ordering risk

The migration directory is not perfectly clean. Duplicate numbers and bundled/split migration sets coexist:

- `22_25_accept_offer_bundle.sql`
- `22_add_jobs_accepted_bid_id.sql`
- `23_create_update_user_location_rpc.sql`
- `24_accept_job_offer_atomic_rpc.sql`
- `25_offer_acceptance_on_the_way_and_locks.sql`
- duplicated numbers for `26`, `27`, `36`

Any production migration work should be planned carefully.

### 3. QA artifact mismatch risk

The documented QA baseline is good:

- `docs/testing/qa-audit-2026-03-08.md`

But current artifact output disagrees:

- `output/playwright/results.json`

Treat Playwright state as “needs re-run before trusting artifacts” rather than fully canonical.

### 4. Excluded paths hide some debt

`analysis_options.yaml` excludes:

- `integration_test/**`
- `**/* 2.dart`
- `**/* 3.dart`

The clean analyzer result applies to the active code baseline, not necessarily all files on disk.

### 5. Local mobile geolocation on LAN is constrained

This is not a bug in business logic; it is a local-preview limitation for non-HTTPS origins. Avoid misdiagnosing it as a repository-wide location failure.

## Current priorities that still make sense

### Product / feature priorities

1. Real electronic payments
2. Production migration application and DB rollout discipline
3. Reduce polling duplication / improve realtime efficiency
4. Finish device-level QA on real phones

### Engineering / QA priorities

1. Re-run and refresh Playwright artifacts so `results.json` matches the documented baseline
2. Reduce Playwright skip-heavy areas:
   - `data-consistency.spec.ts`
   - `network.spec.ts`
   - `responsive.spec.ts`
3. Decide whether the current UI redesign in the worktree should be committed, split, or reduced

## Open questions / unresolved areas

1. Which parts of the current dirty worktree are intended for the next commit, and which are still exploratory?
2. Should compatibility routes remain long-term, or be removed after one stable release?
3. What is the final production migration strategy for the accept-offer stack, given the numbering/bundle duplication?
4. Is the current light-theme redesign the approved final visual direction, or still an in-progress experiment?
5. Should local phone demos continue to rely on LAN HTTP plus manual location, or should a proper HTTPS preview path be added?

## Things a new agent should not assume

1. Do not assume demo accounts or demo data in the database are configured just because they were used in a past session.
2. Do not assume all files in the repository are authoritative:
   - duplicate `* 2.dart` and `* 3.dart` files exist
   - `.tmp` and local artifact files exist
3. Do not assume Playwright artifacts are fresh unless re-run.
4. Do not assume payment is production-ready; it is explicitly not.

## Suggested next analysis/fix after reading this handoff

The highest-value next step is:

### Option A: stabilize the repository state

- separate intentional redesign changes from noise
- remove or isolate accidental duplicate files
- commit the intended current UX/theme work cleanly

### Option B: re-validate the QA baseline

- re-run Playwright
- regenerate `output/playwright/results.json`
- confirm it matches or supersedes `docs/testing/qa-audit-2026-03-08.md`

### Option C: prepare release-readiness work

- plan production DB migration application
- close the remaining payment strategy gap
- finish real-device smoke tests

If only one thing is to be done next, choose **A first**. The dirty worktree is the biggest source of ambiguity for any future agent.
