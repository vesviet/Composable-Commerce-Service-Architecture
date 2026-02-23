# Priority Roadmap - E-Commerce Microservices

**Last Updated**: 2025-12-02  
**Current Progress**: Needs verification (previously an estimate)  
**Target**: Needs verification (previously an estimate)

---

## Executive summary

This document is a planning aid. Status/percentages/sprint timelines may be outdated and should be verified against the codebase and delivery tracking.

## Implemented now (code reference)

- Returns & exchanges workflow exists in the `order` service (this roadmap previously marked it as not implemented):
  - Biz: `order/internal/biz/return/return.go`
  - Service: `order/internal/service/return.go`
  - Migration: `order/migrations/018_create_return_requests_table.sql`

For additional planned items, track gap work in `docs/workflow/CHECKLIST_IMPLEMENT_LATER.md`.

---

## Current status (needs verification)

- Services production-ready / MVP-ready counts: needs verification
- Partial services and missing features list: needs verification

---

## Sprint 1 - Complete existing work (needs verification)

### Priority 1: Loyalty service

- Status: needs verification
- Effort: needs verification
- Impact/Risk: needs verification

Planned tasks (example):

- Bonus campaigns
- Points expiration
- Analytics
- Integration testing
- Documentation

### Priority 2: Verify order editing module

- Status: needs verification
- Effort: needs verification

Planned verification:

- Review existing order editing code
- Edge cases testing
- Integration testing
- Documentation

---

## Sprint 2 - Critical customer features (needs verification)

### Priority 3: Returns & exchanges workflow

- Status: partially implemented (return domain exists in `order` service).
- Remaining gaps (likely):
  - Return shipping label generation
  - Warehouse restock integration
  - Refund policy alignment and end-to-end wiring
  - Notifications and customer tracking UX

Code reference: `order/internal/biz/return/return.go`, `order/internal/service/return.go`.

---

## Notes

- Avoid relying on percentage completion without a source of truth.
- Prefer linking to code references for anything marked as implemented.
