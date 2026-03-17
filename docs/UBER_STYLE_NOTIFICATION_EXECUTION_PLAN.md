# Uber-Style Notification Execution Plan (Production-Grade)

Last updated: 2026-02-20
Owner: Platform + Mobile

## 1) Objective
Build an Uber-style notification system that is:
- reliable across app states (foreground/background/terminated)
- stateful (active order survives app restart)
- anti-spam (dedupe, collapse, TTL, channel discipline)
- observable (sent/delivered/opened/actioned metrics)
- cost-aware (FCM-first, Realtime where needed)

## 1.1) Current implementation progress
- Week 1 Day 1-5: completed (event contract, orchestrator, idempotency wiring, channels/permission readiness, 3-state push navigation).
- Week 2 Day 6: completed (local active-order persistence + cold-start rehydrate flow for customer/technician).
- Week 2 Day 7: completed (resume-time reconciliation; server truth overrides stale cache).
- Week 2 Day 8: completed in codebase (new realtime+RLS contract audit scripts; run-ready once DB URL is provided).
- Week 2 Day 9: completed (jittered reconnect, capped backoff, and conditional fallback polling only during realtime degradation).
- Week 2 Day 10: completed in codebase (notification lifecycle telemetry for sent/received/opened/actioned with requestId+dedupeKey correlation and `/api/notifications/lifecycle` ingestion endpoint).

## 2) Internet-verified constraints to enforce
1. Android 8+ requires notification channels; posting without channel on API 26+ fails.
2. Android 13+ requires POST_NOTIFICATIONS runtime permission.
3. FCM high priority is for truly urgent user-visible events; misuse can lead to deprioritization.
4. FCM does not guarantee message order.
5. Use collapsible messages + collapse keys for replaceable updates (for example, order status).
6. Use TTL intentionally; short TTL for expiring events (arrival), longer for non-urgent.
7. Flutter FCM requires handling all 3 states: onMessage, onMessageOpenedApp, getInitialMessage.
8. iOS force-quit behavior: remote notifications won’t resume until app is relaunched.
9. Live Activities require ActivityKit + Widget Extension + NSSupportsLiveActivities and 4KB payload bound.
10. Supabase Realtime must be explicitly enabled for tables (replication), and protected by RLS.

## 3) Target architecture
- Push rail: Firebase Cloud Messaging (data-first payloads for app-controlled behavior)
- Realtime rail: Supabase Realtime for live order streams (status/location/chat)
- Source of truth: Backend order state machine (client is cache + view)
- Orchestrator: backend notification decision layer (priority, channel, dedupe_key, ttl, collapse)
- Persistence: local active-order snapshot + server rehydrate on app launch
- iOS premium UX: Live Activities for active order timeline

## 4) Delivery phases (5 weeks)

## Week 1 — Platform hardening + contract lock
### Day 1 (Security + contract freeze)
- Rotate all leaked or shared keys (Firebase, Supabase, API keys).
- Freeze Notification Event Contract v1:
  - event_type, order_id, dedupe_key, deep_link, priority, ttl_seconds, collapse_key.
- Add schema validation for all outbound notification payloads.
DoD:
- No plaintext secrets in repo/history/docs.
- Contract test passes for all event types.

### Day 2 (Orchestrator skeleton)
- Create `NotificationOrchestrator` in backend.
- Add routing map:
  - `TECHNICIAN_ARRIVING` -> high + critical channel + short TTL.
  - `QUOTE_RECEIVED` -> default + important channel.
  - marketing/non-urgent -> low + standard channel.
- Add dedupe storage (`dedupe_key`, `sent_at`, `status`).
DoD:
- Same dedupe key cannot send twice within window.

### Day 3 (Idempotency + retries)
- Enforce `X-Idempotency-Key` on critical POSTs (`accept-offer`, `request-completion`, `payment`).
- Retry policy:
  - retry only on transient errors (5xx/timeout)
  - exponential backoff + jitter
  - no retry on 4xx business errors
DoD:
- Replay returns same result + replay header/metric.

### Day 4 (Android channels + permission)
- Verify channels at app startup (`critical`, `important`, `standard`, `marketing`).
- Android 13 permission flow with tracked prompt state.
- Fallback UX if permission denied (in-app banner + settings deeplink).
DoD:
- No notification posted without channel on API 26+.
- Permission state visible in diagnostics screen.

### Day 5 (Flutter 3-state navigation)
- Harden handlers:
  - foreground: `onMessage`
  - background open: `onMessageOpenedApp`
  - terminated open: `getInitialMessage`
- Queue deep links until router is ready.
- Add invalid deep-link fallback route.
DoD:
- Notification tap always opens intended screen from all 3 states.

## Week 2 — Active order persistence + realtime reliability
### Day 6
- Persist active order pointer locally (`active_order_id`) + cached order object.
- Startup flow: show cache immediately, then refresh from server.
DoD: cold start returns user to active order within 1-2 screens.

### Day 7
- Add reconciliation worker on app resume:
  - detect stale cache/version mismatch
  - force order sync if mismatch
DoD: version conflicts auto-resolve without user confusion.

### Day 8
- Supabase realtime hardening:
  - ensure replication enabled for required tables
  - RLS policies verified for customer/technician roles
DoD: no unauthorized realtime payload leakage.

### Day 9
- Connection recovery policy:
  - jittered reconnect
  - max backoff caps
  - fallback polling every N seconds when disconnected
DoD: order state continues even under unstable network.

### Day 10
- Delivery telemetry first cut:
  - sent, received, opened, actioned events
  - requestId + dedupeKey correlation IDs
DoD: single trace can follow one event end-to-end.

## Week 3 — Uber-like UX and anti-spam controls
### Day 11
- Collapse strategy per order:
  - status update events share `collapse_key=order_{id}_status`
- Non-collapsible for truly critical one-off events.
DoD: old redundant status notifications are replaced.

### Day 12
- TTL policy matrix:
  - arriving: 120-300s
  - quote/payment/confirm: medium TTL
  - informational: long TTL
DoD: stale notifications reduced in test scenarios.

### Day 13
- Rate limiting per user/order/event_type.
- Quiet-hours policy for non-urgent classes.
DoD: no notification bursts on repeated backend updates.

### Day 14
- Actionable notifications (where supported):
  - quick actions: view order / call / chat
DoD: action taps mapped to correct deep links + analytics.

### Day 15
- UX polish pass:
  - concise Arabic copy
  - no technical error surface to users
DoD: no raw exception text visible in UI.

## Week 4 — iOS Live Activities rollout
### Day 16
- Add/verify Widget Extension + ActivityKit integration.
- Set `NSSupportsLiveActivities=YES`.
DoD: Live Activity starts for active order on supported devices.

### Day 17
- Live Activity state model:
  - pending -> on_the_way -> arrived -> in_progress -> pending_confirm -> completed
DoD: each state update reflected on lock screen.

### Day 18
- Push-token lifecycle for Live Activities.
- Server mapping activity_id <-> order_id <-> user_id.
DoD: token refresh does not orphan ongoing activities.

### Day 19
- Alert configuration tuning for meaningful updates only.
- Enforce payload budget limits and field validation.
DoD: no rejected updates due to malformed payloads in tests.

### Day 20
- End-of-activity policies:
  - immediate end on complete/cancel
  - cleanup for stuck activities
DoD: no zombie live activities after order closure.

## Week 5 — Observability, load, canary, go-live
### Day 21
- Dashboard build:
  - delivery rate, open rate, p95 delivery time, high-priority ratio
DoD: live dashboard with role/environment filters.

### Day 22
- Alert rules:
  - 5xx spikes
  - replay anomalies
  - payload mismatch spikes
  - drop in open rate
DoD: alerts route to on-call channel.

### Day 23
- Load test orchestrator and provider throughput.
- Validate retry/backoff and no duplicate sends.
DoD: pass target RPS without burst-induced failure.

### Day 24
- Canary rollout: 10% -> 50%.
- Compare KPIs against baseline.
DoD: no rollback trigger crossed.

### Day 25
- Full rollout 100% + 60-minute live monitoring checklist.
- Final release evidence snapshot.
DoD: launch signed off by Backend + Mobile + QA.

## 5) Non-negotiable acceptance gates
- Delivery success rate >= 99.5%
- Duplicate notifications <= 0.1%
- Terminated-state deep-link success >= 98%
- Active-order rehydration success = 100%
- No raw Dio/stack errors shown to users

## 6) Immediate execution (start now)
1. Day 1 security rotation + secret audit.
2. Day 1 contract freeze PR (event schema + tests).
3. Day 2 orchestrator scaffold PR.

## 7) Reference links (official + primary)
- Firebase FCM at scale: https://firebase.google.com/docs/cloud-messaging/scale-fcm
- FCM Android priority: https://firebase.google.com/docs/cloud-messaging/android-message-priority
- FCM collapsible messages: https://firebase.google.com/docs/cloud-messaging/customize-messages/collapsible-message-types
- FCM message lifespan (TTL): https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan
- FCM Flutter receive messages: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- Android notification channels: https://developer.android.com/develop/ui/views/notifications/channels
- Android 13 notification permission: https://developer.android.com/develop/ui/views/notifications/notification-permission
- Flutter deep linking: https://docs.flutter.dev/ui/navigation/deep-linking
- Supabase Realtime Postgres Changes: https://supabase.com/docs/guides/realtime/postgres-changes
- Supabase Flutter subscribe: https://supabase.com/docs/reference/dart/subscribe
- Apple ActivityKit overview: https://developer.apple.com/documentation/ActivityKit/
- Apple Live Activities guide: https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities
- Uber push platform (engineering reference): https://www.uber.com/en-US/blog/ubers-next-gen-push-platform-on-grpc/
