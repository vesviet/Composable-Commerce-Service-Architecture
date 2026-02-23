# Return & Refund Flow - Code Review Issues

**Last Updated**: 2026-02-23

This document lists issues found during the review of the Return & Refund Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

> Source of truth: `return/internal/biz/return/` (dedicated Return microservice, port 8013).
> Comprehensive checklist: [return-refund-flow-checklist.md](../checklists/workflow/return-refund-flow-checklist.md)

---

## 🚩 PENDING ISSUES (Unfixed)

### P1 — High Priority
- [High] **RET-P1-01** No granular failure statuses — `completed` hides refund/restock failures. `refund_failed`/`restock_failed` statuses now added to state machine (P0-NEW-02), but the full status machine flow (inspection → pending_refund → refund_processing → completed) is still simplified. See `return/internal/biz/return/validation.go`.

### P2 — Roadmap
- [Medium] **RET-P2-01** Refund does not include proportional shipping or tax refund. See `return/internal/biz/return/refund.go:36`.
- [Medium] **RET-P2-02** All items eligible regardless of product category — no per-category exclusion policy. See `return/internal/biz/return/return.go` `CheckReturnEligibility`.
- [Medium] **RET-P2-03** Exchange items have `ProductName: ""` and `UnitPrice: 0` in `ExchangeRequestedEvent`. See `return/internal/biz/return/events.go:233-236`.
- [Low] **RET-P2-05** Return window hardcoded to 30 days — no per-category policy. See `return/internal/biz/return/return.go:156`.
- [Low] **RET-P2-06** No return item evidence (photo/video) upload mechanism. Not implemented.
- [Low] **RET-P2-08** Loyalty points not reversed on return completion. No call to loyalty/customer service.
- [Low] **EDGE-01** Partial quantity double-return possible — no `already_returned_qty` tracking per order item.
- [Low] **EDGE-02** No seller approval flow — returns go straight to admin-approved.
- [Low] **EDGE-03** No dispute escalation (section 10.5 of flows doc).
- [Low] **EDGE-04** No split payment refund support.
- [Low] **EDGE-05** Exchange doesn't check stock for replacement item before confirming.

---

## 🆕 NEWLY DISCOVERED ISSUES
- None (all issues incorporated into PENDING or RESOLVED sections below)

---

## ✅ RESOLVED / FIXED

### P0 — Critical (All Fixed)
- [FIXED ✅] **RET-P0-001** All primary lifecycle events now saved to outbox inside DB transaction. Fixed in `return.go` (TX block for approved/rejected/completed events) and P0-NEW-01 fix (TX block for requested event).
- [FIXED ✅] **RET-P0-002** `return.refund_retry` and `return.restock_retry` now consumed by `ReturnCompensationWorker` (`internal/worker/compensation_worker.go`), wired via `WorkerServer`.
- [FIXED ✅] **RET-P0-003** Order status updated to `return_requested` (approved) and `returned` (completed) via `orderService.UpdateOrderStatus`.
- [FIXED ✅] **P0-NEW-01** `CreateReturnRequest` outbox save moved inside transaction — was previously outside TX.
- [FIXED ✅] **P0-NEW-02** `refund_failed` and `restock_failed` added to state machine `validTransitions` map. Compensation worker now updates return request status after successful retry.
- [FIXED ✅] **P0-NEW-03** Config volume mount added to `gitops/apps/return/base/deployment.yaml` — was missing, pod would crash-loop.

### P1 — High Priority (Fixed)
- [FIXED ✅] **RET-P1-02** Idempotency key added: `returnID + ":refund"` in `refund.go:54`.
- [FIXED ✅] **RET-P1-03** Return shipping label now uses `order.ShippingAddress` (Origin) + `config.business.warehouse_return_address` (Destination).
- [FIXED ✅] **RET-P1-04** Restock uses `item.Metadata["warehouse_id"]` from order; no longer defaults to `"default"` unless metadata is missing.
- [FIXED ✅] **RET-P1-05** `ReturnCompensationWorker` implemented and wired via `WorkerServer`.
- [FIXED ✅] **P1-NEW-01** Compensation worker now updates return request status from `refund_failed`/`restock_failed` → `completed` after successful retry.
- [FIXED ✅] **P1-NEW-03** `validateReturnWindow` aligned with `CheckReturnEligibility` — both deny when `CompletedAt` is nil (fail-safe).
- [FIXED ✅] **P1-NEW-05** Exchange order created event now routes through outbox for durable delivery.

### P2 — Normal (Fixed)
- [FIXED ✅] **RET-P2-04** Max refund cap added: `refundAmount <= order.TotalAmount` in `refund.go:43-47`.
- [FIXED ✅] **RET-P2-07** `ReceiveReturnItems` now applies `inspectionResults` to update `item.Condition` and `item.Restockable`.
