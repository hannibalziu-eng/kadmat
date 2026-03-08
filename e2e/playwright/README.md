# Kadmat Playwright E2E (Tailored)

This suite is tailored to the current Kadmat Flutter-Web implementation.

## Why this structure

- Routes and assertions match current app paths (for example `/technician-profile/:technicianId`).
- Tests include detection for known risky areas (mock messages, cross-page consistency).
- Runs on Chromium, Firefox, WebKit, plus iPhone 14 Pro emulation.
- Captures `trace`, screenshots, and video on failure.

## Setup

```bash
cd /Users/wew/Desktop/kadmat/e2e/playwright
cp .env.example .env
npm install
npx playwright install
```

## Required env values

- `BASE_URL` (Flutter web URL)
- `API_BASE` (backend API URL, usually `http://127.0.0.1:3000/api`)
- `CUSTOMER_EMAIL`, `CUSTOMER_PASS`
- `TECHNICIAN_EMAIL`, `TECHNICIAN_PASS`

Optional:

- `CUSTOMER_TOKEN`, `TECHNICIAN_TOKEN` (skip login calls)
- `TECHNICIAN_PUBLIC_ID` (enables public profile consistency scenarios)
- `STRICT_REAL_DATA=true` (turn mock data detections into hard failures)

## Run

```bash
npm run test:list
npm run test
npm run matrix
npm run verify:flow
```

## Targeted suites

```bash
npx playwright test tests/auth.spec.ts
npx playwright test tests/customer-flow.spec.ts
npx playwright test tests/technician-flow.spec.ts
npx playwright test tests/network.spec.ts --project=chromium
```

## Snapshot Flow Verification

`npm run verify:flow` builds a live end-to-end snapshot for the current local stack:

- seeds fresh customer + technician users
- creates a real request and real offer
- verifies chat is blocked before acceptance and enabled after acceptance
- captures customer and technician screenshots through the full lifecycle
- records wallet debt lock and notifications after completion

The script writes artifacts under:

- `/Users/wew/Desktop/kadmat/output/playwright/snapshot-flow-*`

Required local services before running it:

- Flutter web served at `BASE_URL`
- backend API served at `API_BASE`

## Notes aligned with current app

- `forgot-password` is currently simulated on UI side.
- `messages` screen is expected to load from backend API, not static cards.
- `service-details` route requires `state.extra`; direct URL navigation without extra payload is intentionally not part of this suite.
