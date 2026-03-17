# Hybrid Pricing MVP — Sprint 1 Scope

## Objective
Sprint 1 is limited to foundation work for the Hybrid Pricing MVP on the correct project root.

## Included in Sprint 1
- Database foundation for service pricing metadata
- Database foundation for job pricing metadata
- Create service_catalog_items table
- Keep safe defaults so current quote-based behavior remains intact
- Backend read readiness only for later work
- Flutter read readiness only for later work
- QA baseline readiness only for later work

## Excluded from Sprint 1
- Fixed-price job creation end-to-end
- Technician quote execution flow changes
- Technician app flow changes
- Customer checkout flow changes
- Routing changes
- Notification changes
- Realtime changes
- Mixed pricing mode
- job_catalog_items table
- Any Sprint 2 or Sprint 3 work

## Day 1 Scope
Day 1 is limited to:
- New migrations under backend/migrations using non-conflicting numbering
- Update backend/database/schema_v2.sql
- Minimal scope documentation only

## Day 1 Guardrails
- Do not modify Flutter files during Day 1
- Do not modify jobController.js during Day 1
- Do not modify jobService.js during Day 1
- Do not modify routing or notifications during Day 1
- Do not create job_catalog_items during Day 1
- Preserve backward-safe defaults for existing records
