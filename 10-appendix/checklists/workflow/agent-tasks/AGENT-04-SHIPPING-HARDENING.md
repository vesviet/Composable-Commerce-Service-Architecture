# AGENT-04: Shipping Service Core Workflow & Architecture Hardening

> **Created**: 2026-03-14
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `shipping`
> **Estimated Effort**: 2-3 days
> **Source**: [Shipping Service Meeting Review (1000 Round Style)](../../../../../../.gemini/antigravity/brain/81ccb67b-c989-4770-916f-5db9d15fafb7/shipping_review.md)

---

## 📋 Overview

Refactor and harden the `shipping` service to address issues identified during the multi-agent Meeting Review. The focus is to fix critical logic flaws (e.g. status transition from Shipped to Cancelled, swallowing errors in `parseStatusSafe`) and improve concurrency controls (advisory locks, DB connections, batch creation limits).

---

### [x] Task 1: Fix Swallowing Errors in `parseStatusSafe`
### [x] Task 2: Block `CancelShipment` when `Status >= Shipped`
### [x] Task 3: Implement Max Batch Size limit in `BatchCreateShipments`
### [x] Task 4: Ensure Auth/HMAC Validation in Carrier Webhooks
### [x] Task 5: Remove Deprecated `EventBus`
### [x] Task 6: Optimize PostgreSQL Advisory Lock Collision

---

## 🔧 Pre-Commit Checklist

```bash
cd shipping && wire gen ./cmd/server/ ./cmd/worker/
cd shipping && go build ./...
cd shipping && go test -race ./...
cd shipping && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(shipping): harden shipment core architecture and edge cases

- fix: prevent swallowing errors in DB enum parser parseStatusSafe
- fix: forbid cancel transition when shipment is already shipped
- feat: impose limit of 100 on batch shipment creation
- refactor: remove deprecated EventBus logic from biz layer

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| 1. DB parser returns explicit error | Code review & tests pass for `parseStatusSafe` error paths | |
| 2. Cannot Cancel Shipped Package | `isValidStatusTransition` tests confirm invalid change | |
| 3. Batch Create limited to 100 | Tests pass, >100 throws err | |
| 4. Deprecated EventBus removed | `wire.go` builds fine without EventBus | |
