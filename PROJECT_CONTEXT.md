# PROJECT CONTEXT

## 1. What `kadmat` does

`kadmat` is a two-sided service marketplace for home and field services:

- Customers create service requests, track execution, communicate with the assigned technician, confirm completion, and rate the job.
- Technicians discover nearby requests, submit offers, set pricing, execute work, upload required photos, and complete jobs.
- The system uses a backend contract layer, Supabase/Postgres persistence, and a Flutter client for customer and technician experiences.

The repository currently contains both:

- the latest committed baseline on `main`, and
- a **dirty working tree** with substantial local UI/UX and flow changes that are **not necessarily committed yet**.

This document describes the **current working tree as inspected on 2026-03-12**, not only the last commit.

Latest confirmed committed HEAD during inspection:

- `0398fd8` — `test: harden playwright local qa baseline`

## 2. High-level architecture

### Frontend

- Flutter app: `lib/`
- State management: Riverpod
- Routing: GoRouter
- HTTP/API: Dio-based repositories
- Auth/session: Supabase Auth plus app-side profile/session handling
- Maps/location:
  - `flutter_map`
  - `geolocator`
  - app-side location service and fallback/manual selection

Key frontend bootstrap:

- `lib/main.dart`
- `lib/src/core/router_modular.dart`
- `lib/src/core/router/route_modules.dart`
- `lib/src/core/navigation/app_routes.dart`
- `lib/src/core/app_theme.dart`

### Backend

- Node.js + Express API: `backend/src/index.js`
- Business logic in service/controller layers
- Validation and contract formatting centralized in utility modules
- Database migrations live under `backend/migrations/`

Key backend entry points:

- `backend/src/index.js`
- `backend/src/controllers/`
- `backend/src/services/`
- `backend/src/utils/`
- `backend/src/routes/`

### Data / infra

- Primary data store: Supabase/Postgres
- Migration history: `backend/migrations/`
- Push and mobile support artifacts exist for Firebase:
  - `android/app/google-services.json` (currently untracked)
  - `ios/Runner/GoogleService-Info.plist` (currently untracked)

### Test layers

- Flutter unit/widget tests: `test/`
- Backend Jest suites: `backend/tests/`
- Browser E2E / harnesses: `e2e/playwright/`
- QA artifacts and reports: `docs/testing/`, `output/playwright/`

## 3. Main modules and important files

### Core application shell

- `lib/main.dart`
- `lib/src/core/router_modular.dart`
- `lib/src/core/router/route_modules.dart`
- `lib/src/core/navigation/app_routes.dart`
- `lib/src/core/api/endpoints.dart`
- `lib/src/core/design/kadmat_tokens.dart`
- `lib/src/core/design/kadmat_theme_extension.dart`
- `lib/src/core/widgets/kadmat_components.dart`
- `lib/src/core/widgets/kadmat_shell_navigation.dart`
- `lib/src/core/widgets/kadmat_toast.dart`

### Customer-facing modules

- Auth:
  - `lib/src/features/auth/presentation/welcome_screen.dart`
  - `lib/src/features/auth/presentation/login_screen.dart`
  - `lib/src/features/auth/presentation/register_screen.dart`
  - `lib/src/features/auth/presentation/forgot_password_screen.dart`
- Home:
  - `lib/src/features/home/presentation/home_screen.dart`
  - `lib/src/features/home/data/service_repository.dart`
- Jobs / request flow:
  - `lib/src/features/jobs/presentation/screens/customer_service_request_screen.dart`
  - `lib/src/features/jobs/presentation/screens/customer_screens.dart`
  - `lib/src/features/jobs/presentation/screens/customer_job_tracking_screen.dart`
  - `lib/src/features/jobs/presentation/screens/customer_service_completion_confirmation_screen.dart`
  - `lib/src/features/jobs/presentation/screens/customer_payment_processing_screen.dart`
  - `lib/src/features/jobs/data/job_repository.dart`
- Orders / messages / account:
  - `lib/src/features/orders/presentation/orders_screen.dart`
  - `lib/src/features/messages/presentation/messages_screen.dart`
  - `lib/src/features/messages/data/messages_repository.dart`
  - `lib/src/features/profile/presentation/profile_screen.dart`
  - `lib/src/features/profile/presentation/customer_wallet_screen.dart`
  - `lib/src/features/profile/presentation/customer_wallet_transactions_screen.dart`
  - `lib/src/features/profile/presentation/account_security_screen.dart`

### Technician-facing modules

- Entry/auth:
  - `lib/src/features/auth/presentation/technician_landing_screen.dart`
  - `lib/src/features/auth/presentation/technician_login_screen.dart`
  - `lib/src/features/auth/presentation/technician_register_screen.dart`
- Shell and dashboard:
  - `lib/src/features/technician/presentation/technician_main_screen.dart`
  - `lib/src/features/technician/presentation/dashboard/technician_dashboard_screen.dart`
- Dispatch / requests / execution:
  - `lib/src/features/technician/presentation/requests/technician_requests_screen.dart`
  - `lib/src/features/technician/presentation/jobs/technician_job_detail_screen.dart`
  - `lib/src/features/technician/presentation/providers/technician_dispatch_feed_provider.dart`
  - `lib/src/features/technician/presentation/providers/technician_providers.dart`
  - `lib/src/features/technician/presentation/widgets/online_status_toggle.dart`

### Backend logic of interest

- Job lifecycle and rules:
  - `backend/src/services/jobService.js`
  - `backend/src/utils/jobStateMachine.js`
- Communication gate:
  - `backend/src/utils/jobCommunication.js`
  - `backend/src/controllers/messageController.js`
- Notifications:
  - `backend/src/controllers/notificationController.js`
- Response contract:
  - `backend/src/utils/responseFormatter.js`

### Source-of-truth docs

- `docs/MASTER_FLOW_SPEC.md`
- `docs/EXECUTION_BACKLOG.md`
- `docs/testing/qa-audit-2026-03-08.md`

## 4. What has been completed so far

The following is verified from the current codebase.

### A. Core flow and backend hardening

- The canonical customer/technician job lifecycle is documented in `docs/MASTER_FLOW_SPEC.md`.
- Server-side job state rules are enforced in `backend/src/utils/jobStateMachine.js`.
- Communication is gated behind accepted/eligible job states in:
  - backend: `backend/src/utils/jobCommunication.js`
  - frontend policy usage: `lib/src/features/jobs/domain/job_communication_policy.dart`
- Messages use backend APIs rather than direct client-side table access:
  - `lib/src/features/messages/data/messages_repository.dart`
- Backend contract formatting is centralized in:
  - `backend/src/utils/responseFormatter.js`

### B. Significant UI/UX redesign work exists in the current working tree

The current working tree contains a large uncommitted redesign and simplification effort across:

- auth/welcome screens
- customer home
- customer service request screen
- orders, messages, profile, wallet
- technician entry, dashboard, requests, job detail
- shared tokens/theme/components

This work is visible in modified files such as:

- `lib/src/core/app_theme.dart`
- `lib/src/core/design/kadmat_tokens.dart`
- `lib/src/core/widgets/kadmat_components.dart`
- `lib/src/features/home/presentation/home_screen.dart`
- `lib/src/features/jobs/presentation/screens/customer_service_request_screen.dart`
- `lib/src/features/orders/presentation/orders_screen.dart`
- `lib/src/features/profile/presentation/profile_screen.dart`
- `lib/src/features/technician/presentation/dashboard/technician_dashboard_screen.dart`

### C. Request creation flow is now materially richer

Verified in `lib/src/features/jobs/presentation/screens/customer_service_request_screen.dart`:

- service selection
- current-location toggle
- manual map-based location selection fallback
- details field
- expected price field
- photo upload

Important: video upload is **not** part of the current request screen implementation.

### D. Theme and direction changes

- The app currently forces `ThemeMode.light` in `lib/main.dart`
- The local design system uses shared tokens in:
  - `lib/src/core/design/kadmat_tokens.dart`
  - `lib/src/core/design/kadmat_theme_extension.dart`
- Currency normalization has been moved toward Libyan Dinar display in frontend wallet/domain work:
  - `lib/src/features/wallet/domain/wallet.dart`

### E. CI / testing baseline

Verified in this inspection:

- `flutter analyze`: clean
- backend Jest suite: `21/21` suites passed, `92/92` tests passed
- `flutter test`: `177` tests passed

The repository also contains a stronger QA baseline described in:

- `docs/testing/qa-audit-2026-03-08.md`

But see the “known problems” section below about stale/mismatched artifacts.

## 5. What is still missing or incomplete

### A. Real electronic payments

Still not implemented as a production-ready capability.

Evidence:

- `lib/src/features/jobs/presentation/screens/customer_payment_processing_screen.dart`
- uses `AppConstants.useRealPayments`
- when disabled, the UI falls back to cash-only confirmation messaging

### B. Advanced account security

Not fully implemented.

Evidence:

- `lib/src/features/profile/presentation/account_security_screen.dart`
- only password change is currently active
- 2FA and connected devices are explicitly labeled as later/planned

### C. Production migration application is still pending

The code and migrations exist, but `docs/EXECUTION_BACKLOG.md` still records production DB execution tasks as pending, especially around the accept-offer stack:

- `backend/migrations/22_add_jobs_accepted_bid_id.sql`
- `backend/migrations/23_create_update_user_location_rpc.sql`
- `backend/migrations/24_accept_job_offer_atomic_rpc.sql`
- `backend/migrations/25_offer_acceptance_on_the_way_and_locks.sql`

### D. Polling/realtime efficiency work is still open

Documented in:

- `docs/EXECUTION_BACKLOG.md`

Open item:

- reduce aggressive polling duplication for `jobs/:id` and `my-jobs`

### E. Phone geolocation in local LAN preview remains constrained

Not a code bug, but a real limitation of local testing:

- when opening the app on a phone through `http://192.168.x.x`, automatic geolocation is limited because the origin is not secure (`HTTPS`)
- current UI contains a manual-location fallback in the customer request flow

## 6. Key application flows

### Customer flow

Canonical flow from `docs/MASTER_FLOW_SPEC.md` and current routes:

1. Create request
2. `/jobs/:jobId/customer/searching`
3. Receive/view offers
4. Accept one offer
5. `/jobs/:jobId/customer/price-offer`
6. `/jobs/:jobId/customer/in-progress`
7. `/jobs/:jobId/customer/confirm-completion`
8. `/jobs/:jobId/customer/payment-processing`
9. `/jobs/:jobId/customer/rate`
10. `/jobs/:jobId/customer/completed`

### Technician flow

1. Go online
2. Provide usable location context (automatic or manual path depending screen/state)
3. Receive nearby jobs
4. Open job detail
5. Submit offer / set price
6. Wait for customer acceptance
7. Move through:
   - `on_the_way`
   - `arrived`
   - `in_progress`
   - `pending_confirm`

### Communication flow

- Messages are not universally open.
- Communication is allowed only once the job reaches accepted/eligible states.
- This is enforced in backend policy and reflected in frontend behavior.

## 7. Current architectural decisions

These are visible in code today.

### A. Web API origin resolution is host-derived by default

`lib/src/core/api/endpoints.dart`

- If `API_BASE` is supplied at compile time, it is used.
- On web, otherwise the app derives `scheme://host:3000/api`
- On non-web, default local target is `http://localhost:3000/api`

This is important for local LAN testing from other devices.

### B. Web auth path differs from native intent

`lib/src/features/auth/data/auth_repository.dart`

- Web auth is biased toward direct Supabase/browser-friendly session handling
- Native/local backend auth endpoints still exist in the contract surface

### C. Legacy route compatibility is still retained

Compatibility aliases still exist instead of being fully deleted:

- `booking/:serviceId`
- `service-details`
- `tracking/:bookingId`
- `payment-approval`
- `active-job/:jobId`

These help avoid broken links, but they are not the primary routing model anymore.

### D. Analyzer cleanliness is achieved partly by exclusion

`analysis_options.yaml`

The analyzer excludes:

- `integration_test/**`
- `**/* 2.dart`
- `**/* 3.dart`
- `test/**/*.mocks.dart`

This keeps `flutter analyze` clean, but also means those paths are not part of the active static-analysis baseline.

## 8. Known problems and important caveats

### A. The worktree is dirty

At inspection time:

- branch: `main`
- many tracked files modified
- many untracked files present

This means:

- the current local app is ahead of the last committed baseline in several areas
- any future agent must first decide whether to operate on:
  - current working tree
  - or latest committed state

### B. Duplicate / suspicious files exist in the tree

Examples:

- `backend/src/controllers/messageController 2.js`
- `lib/src/core/router.g 2.dart`
- `lib/src/core/security/security_providers.g 2.dart`
- `lib/src/features/auth/data/auth_repository.g 2.dart`
- `lib/src/features/bidding/data/models/dispute_model.freezed 2.dart`
- `.github/workflows/.tmp_test.yml`

These are not part of the intended clean source set and should not be treated as authoritative.

### C. Migration numbering is not perfectly clean

There are duplicate sequence numbers in `backend/migrations/`, for example:

- `26_notification_segmentation_contract.sql`
- `26_wallet_debt_lock_on_commission.sql`
- `27_backfill_notification_audience_and_category.sql`
- `27_create_job_photos.sql`
- `36_add_title_to_technician_portfolio.sql`
- `36_add_users_fcm_token.sql`

There is also both:

- bundled accept-offer migration set:
  - `22_25_accept_offer_bundle.sql`
- and split numbered files:
  - `22_...` through `25_...`

This is a real operational risk when applying or reasoning about production migration order.

### D. QA doc and current Playwright artifact do not fully agree

`docs/testing/qa-audit-2026-03-08.md` records a strong baseline:

- Playwright: `56 passed`, `24 skipped`, `0 failed`

However, the current `output/playwright/results.json` inspected during this session reports:

- `unexpected: 1`

This strongly suggests the artifact file is stale, inconsistent, or from a different run.

Practical implication:

- treat `docs/testing/qa-audit-2026-03-08.md` as the documented baseline
- treat current `output/playwright/results.json` as needing re-validation before relying on it

### E. Some earlier conversational assumptions are not guaranteed by the repo

Examples that should **not** be assumed from code alone:

- demo-account preparation in the database
- live device state used in ad hoc demos
- external staging data setup

Those are operational/runtime conditions, not durable repository state.

### F. The backend entry point is `backend/src/index.js`

If any previous notes or agents refer to a different backend entry file, that would be outdated. The current repo uses:

- `backend/src/index.js`

## 9. Current verification snapshot (this inspection)

Verified during this session:

- `flutter analyze` -> clean
- `flutter test` -> `177` tests passed
- `cd backend && npm run test -- --runInBand` -> `21/21` suites, `92/92` tests passed

This is the strongest current evidence that the inspected working tree is internally consistent at the code/test level.
