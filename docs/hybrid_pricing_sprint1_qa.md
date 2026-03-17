# Hybrid Pricing MVP — Sprint 1 QA Baseline

## Test Data Fixtures
Use these records in development/staging:

### 1) Quote-based service
- services.pricing_mode_default = technician_quote
- services.dispatch_mode_default = manual_quote
- services.is_catalog_enabled = false
- services.requires_quote = true
- Expected UI label: يحتاج تسعير

### 2) Fixed-price catalog service
- services.pricing_mode_default = catalog_fixed
- services.dispatch_mode_default = direct_catalog
- services.is_catalog_enabled = true
- services.requires_quote = false
- Expected UI label: سعر ثابت
- Expected hint: تحتوي على خيارات ثابتة

### 3) Catalog-enabled service with items
- Same as fixed-price catalog service
- Must have active rows in service_catalog_items
- Expected API catalog-items response count > 0

## Backend QA Checklist
- [x] Services list response still returns success, data.services, count, services
- [x] Services list now includes pricing metadata fields
- [x] Service by id still returns success, data.service, service
- [x] Service by id now includes pricing metadata fields
- [x] Service by id can include catalog_items when catalog is enabled
- [x] Dedicated catalog read endpoint exists: GET /services/:id/catalog-items
- [x] Catalog endpoint returns success, data.items, items, count
- [x] No create/update runtime behavior was added in Sprint 1 backend

## Flutter QA Checklist
- [x] Service model supports pricing metadata with safe defaults
- [x] ServiceCatalogItem model exists for read support
- [x] Repository can fetch service by id without create-flow logic
- [x] Repository can fetch catalog items from backend endpoint
- [x] Endpoint helper exists for catalog read path only
- [x] Home screen includes pricing indicators for fixed-price vs quote-based services
- [x] No Flutter create-flow behavior added in Sprint 1

## Scope Creep Check
Allowed in Sprint 1:
- Schema foundation
- Backend read support
- Flutter read support
- QA readiness

Explicitly excluded and not part of Sprint 1 completion:
- Fixed-price job creation flow
- customer_service_request_screen.dart changes
- Routing changes
- Technician flow changes
- Notifications changes
- jobController.js changes
- jobService.js changes
- job_catalog_items
- Offer guard logic
- Sprint 2 behavior

## Sprint 1 Readiness Verdict
Sprint 1 is functionally complete only if:
- Day 1 DB foundation files exist and are coherent
- Day 2 backend read path is valid and backward-compatible
- Day 3 Flutter read path is valid and home screen indicators are present
- No scope creep outside Sprint 1 foundation/read readiness
