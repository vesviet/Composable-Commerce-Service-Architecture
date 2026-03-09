# AGENT-18: Fulfillment & Shipping Flows — Hardening

> **Created**: 2026-03-08  
> **Completed**: 2026-03-08  
> **Priority**: P1 (Critical Stability)  
> **Services**: `fulfillment`, `shipping`  
> **Status**: ✅ DONE — All tasks verified, builds clean, tests green

---

## ✅ P1 — Task 1: `ShipFulfillment` — gRPC Outside Transaction

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_dispatch.go:273`

| Step | Code | Inside TX? |
|------|------|-----------|
| Read fulfillment | `repo.FindByID` (L277) | ❌ Outside |
| Idempotency check | `Metadata["shipment_id"]` (L298-303) | ❌ Outside |
| Create shipment gRPC | `shippingClient.CreateShipment` (L367) | ❌ Outside |
| Update status + store shipment_id | `tx.InTx` → `repo.Update` (L382-421) | ✅ Inside |
| Re-read inside TX (TOCTOU guard) | `repo.FindByID` (L384) | ✅ Inside |

---

## ✅ P1 — Task 2: `CancelFulfillment` — gRPC Outside Transaction

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_lifecycle.go:263`

| Step | Code | Inside TX? |
|------|------|-----------|
| Read fulfillment | `repo.FindByID` (L267) | ❌ Outside |
| Restore stock (picked/packed) | `warehouseClient.AdjustStock` (L290) | ❌ Outside |
| Release reservation (pending) | `warehouseClient.ReleaseReservation` (L302) | ❌ Outside |
| Update status + cancel packages | `tx.InTx` → `repo.Update` (L311-368) | ✅ Inside |
| Re-read inside TX (TOCTOU guard) | `repo.FindByID` (L313) | ✅ Inside |

---

## ✅ P1 — Task 3: Shipping "Volcano" — Outbox Pattern

**Files**: `shipping/internal/biz/shipment/shipment_usecase.go:338`, `shipping/internal/worker/outbox_worker.go:24`

| Step | Code | Inside TX? |
|------|------|-----------|
| Update shipment status | `repo.Update` (L345) | ✅ Inside |
| Save `shipped_internal` event | `saveOutboxEvent` (L358) | ✅ Inside (outbox) |
| Handle package shipped (gRPC + retry) | `outbox_worker.go` → `HandlePackageShipped` (L60) | ❌ Outside (async worker) |
| Saga compensation on failure | `compensatePackageShipped` (L86 in handler) | Separate TX |

---

## ✅ P2 — Task 4: `packageRepo.Update` Error Handling

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_packing.go:103`

- **Before**: `Warnf` — error swallowed silently, TX commits with inconsistent state.
- **After**: `return fmt.Errorf(...)` — TX rolls back properly on failure.

---

## ✅ P2 — Task 5: `compensation_requested` Event

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_lifecycle.go:401-405`

- Added `PublishFulfillmentError(ctx, fulfillment, "compensation_requested", errMsg, reason, "critical")` in `MarkCompensationPending`.
- Publishes to `system.errors` topic for ops alerting (Telegram/Slack).
- Non-blocking: failure to publish alert does not fail the status transition.

---

## ✅ P2 — Task 6: Standardize Transaction Naming

**Service**: `shipping`

- Verified: **zero** `InTx` usage in `shipping/internal/biz/` — consistently uses `WithTransaction`.

---

## ✅ P1 — Task 7: `ConfirmPicked` — gRPC Outside Transaction

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_picking.go:59`

| Step | Code | Inside TX? |
|------|------|-----------|
| Read fulfillment | `repo.FindByID` (L68) | ❌ Outside |
| Check picklist completion | `picklistRepo.FindByID` (L96) | ❌ Outside |
| Confirm reservation gRPC | `warehouseClient.ConfirmReservation` (L111) | ❌ Outside |
| Adjust stock gRPC (per-item) | `warehouseClient.AdjustStock` (L127) | ❌ Outside |
| Re-read + update DB + events | `tx.InTx` → `repo.Update` (L136-195) | ✅ Inside |

---

## ✅ P1 — Task 8: `HandleQCFailed` — gRPC Outside Transaction

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_qc.go:51`

| Step | Code | Inside TX? |
|------|------|-----------|
| Read fulfillment | `repo.FindByID` (L55) | ❌ Outside |
| Release reservation gRPC | `warehouseClient.ReleaseReservation` (L66) | ❌ Outside |
| Re-read + update DB + events | `tx.InTx` → `repo.Update` (L74-131) | ✅ Inside |

---

## ✅ P3 — Task 9: `CreateFromOrder` — `GetReservation` gRPC Outside TX

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_lifecycle.go:18`

- Moved `GetReservation` gRPC validation from `CreateFromOrderMulti` (inside double-nested TX) to `CreateFromOrder` (outside TX).
- Removed unnecessary outer TX wrapper — `CreateFromOrderMulti` already has its own `InTx`.
- Simplified reservation status check (`res.Status != "active"` only, removed confusing `fulfilled` branch).

---

## ✅ P3 — Task 10: `StartPlanning` — `selectWarehouse` gRPC Outside TX

**File**: `fulfillment/internal/biz/fulfillment/fulfillment_lifecycle.go:172`

| Step | Code | Inside TX? |
|------|------|-----------|
| Read fulfillment | `repo.FindByID` (L179) | ❌ Outside |
| Select warehouse gRPC (3 calls) | `ListWarehouses`, `GetBulkStock`, `CheckWarehouseCapacity` | ❌ Outside |
| Re-read + update DB + events | `tx.InTx` → `repo.Update` (L202-237) | ✅ Inside |

---

## 🔧 Bonus Fixes

- [x] **Shipping**: Regenerated stale `wire_gen.go` for worker binary (was missing `usecase` and `logger` args to `NewOutboxPublisherAdapter`).
- [x] **Fulfillment**: Fixed pre-existing `TestUpdateStatus_Shipped_DelegatesToShipFulfillment` — was missing `shippingClient` mock (fail-closed path).
- [x] **Shipping**: Fixed pre-existing `TestShippingService_UpdateShipmentStatus` — expected 1 outbox `Create` but code now creates 2 (`shipped_internal` + `status_changed`).
- [x] **Fulfillment**: Updated `TestConfirmPicked_PartialPick`, `TestConfirmPicked_CompletePick`, `TestHandleQCFailed_Damaged`, `TestHandleQCFailed_Repack`, and gap coverage tests for TOCTOU re-read pattern.
- [x] **Fulfillment**: Updated `TestStartPlanning_Success`, `TestHandleOrderStatusChanged_Confirmed`, `TestHandleOrderConfirmed_ExistingPending` for outside-TX reads.
