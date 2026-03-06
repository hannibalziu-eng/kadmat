# Navigation Blueprint

## Goal
Keep navigation deterministic and prevent random/duplicate pages by enforcing one routing source of truth.

## Runtime Router
- Canonical router: `lib/src/core/router_modular.dart`
- Route assembly source: `lib/src/core/router/route_modules.dart`
- Compatibility import: `lib/src/core/router.dart` (re-export only)

## Guardrails
- Route composition must pass duplicate-path validation in `RouteModules.buildAppRoutes()`.
- Unknown technician flow steps under `/jobs/:jobId/technician/*` are redirected to:
  - `/jobs/:jobId/technician/detail`
- Unknown customer flow steps under `/jobs/:jobId/customer/*` are redirected to:
  - `/jobs/:jobId/customer/searching`

## Route Ownership
- Path constants and builders: `lib/src/core/navigation/app_routes.dart`
- Flow fallbacks for malformed/dead links: `lib/src/core/navigation/router_fallbacks.dart`
- Status-driven customer flow redirection: `lib/src/core/navigation/job_flow_redirects.dart`

## Canonical Flow Screens
### Customer
- `searching` -> `CustomerSearchingScreen`
- `technician-found` -> `CustomerTechnicianFoundScreen`
- `price-offer` -> `CustomerPriceOfferScreen`
- `in-progress` -> `CustomerJobTrackingScreen`
- `payment-processing` -> `CustomerPaymentProcessingScreen`
- `payment-approval` -> `CustomerPaymentApprovalScreen`
- `confirm-completion` -> `CustomerServiceCompletionConfirmationScreen`
- `rate` -> `CustomerRateScreen`
- `completed` -> `CustomerCompletedScreen`

### Technician
- `detail` -> `TechnicianJobDetailScreen`
- `accepted` -> `TechnicianAcceptedScreen`
- `set-price` -> `TechnicianPriceInputScreen`
- `waiting` -> `TechnicianWaitingScreen`
- `pre-photos` -> `PreServicePhotoScreen`
- `in-progress` -> `TechnicianInProgressScreen`
- `post-photos` -> `PostServicePhotoScreen`
- `price-confirmation` -> `PriceConfirmationScreen`
- `complete-work-input` -> `TechnicianCompleteWorkScreen`
- `completed` -> `TechnicianCompletedScreen`

## Deprecated/Removed
- Old split route files under `lib/src/core/router/` were removed because they were not used by runtime and created maintenance drift.
