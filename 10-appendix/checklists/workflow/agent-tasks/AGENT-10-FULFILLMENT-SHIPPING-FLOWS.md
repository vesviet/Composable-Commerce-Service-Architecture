# AGENT TASK - FULFILLMENT & SHIPPING FLOWS (AGENT-10)

## STATUS
**State:** [x] Done | [ ] In Progress | [ ] In Review | [ ] Done

## ASSIGNMENT
**Focus Area:** Fulfillment Picklist Race Conditions & Shipping Saga Compensations
**Primary Services:** `fulfillment`, `shipping`
**Priority:** Critical (P0 fixes required)

## 📌 P0: Blind Quantity Update in Picklist Confirmation
**Risk:** In `fulfillment/internal/biz/picklist/picklist.go`, the `ConfirmPickedItems` method loops over `pickedItems` and uses `uc.repo.UpdateItem(txCtx, item)` to update quantities. The update uses the full `item` struct loaded at the beginning of the transaction. If two pickers concurrently confirm items, or if a retry happens, one blind update will overwrite the other's, leaking the `QuantityPicked` value without database-level protection. Additionally, it executes N queries in a loop, stalling the database.
**Location:** `fulfillment/internal/biz/picklist/picklist.go` (Method `ConfirmPickedItems`)

### Implementation Plan
1.  **Phase 1 - Incremental Update Repository Method:**
    *   Create a method in the `PicklistRepo` interface: `IncrementItemQuantity(ctx context.Context, itemID string, delta int) error`.
    *   Implement this method in the GORM repository using an atomic increment: `UPDATE picklist_items SET quantity_picked = quantity_picked + ? WHERE id = ?`.
    *   Alternatively, add a check to prevent `quantity_picked` from exceeding `quantity_to_pick`.
2.  **Phase 2 - Update Usecase:**
    *   Modify `ConfirmPickedItems` to use `IncrementItemQuantity` instead of `UpdateItem` with a blind struct update.
    *   Consider batching updates if the number of items is large, but for now, switching to atomic increments is the P0 requirement.

### 🔍 Verification Steps
*   Run unit tests: `go test -v ./fulfillment/internal/biz/picklist/...`
*   Verify that concurrent picklist confirmations do not overwrite each other (this might require an integration test or careful reasoning over the SQL generated).

---

## 📌 P1: Blind Saga Compensation in Shipping
**Risk:** When the Fulfillment client fails to accept a `PackageShipped` update in `shipping/internal/biz/shipment/package_shipped_handler.go`, it triggers `compensatePackageShipped`. This compensation invokes `UpdateStatus` backwards to `previousStatus` based solely on the incoming `oldStatus` enum. If the shipping order had been separately canceled by an admin in the few seconds it took the retries to fail, the compensation will blindly revert the system back to `ready` or `processing`, destroying the valid `cancelled` state.
**Location:** `shipping/internal/biz/shipment/package_shipped_handler.go` (Method `compensatePackageShipped`)

### Implementation Plan
1.  **Idempotent / Conditional Revert:**
    *   In `compensatePackageShipped`, before calling `UpdateStatus`, reload the shipment from the DB inside the transaction.
    *   Check if the current state is STILL `StatusShipped`. If it is NOT `StatusShipped`, it means another process (like cancellation) mutated it during the retry window. In that case, **abort the compensation** peacefully (log a message and return nil), as the state has moved on.
    *   Only if the state is still `StatusShipped` should the revert to `previousStatus` proceed.

### 🔍 Verification Steps
*   Run tests: `go test -v ./shipping/internal/biz/shipment/...`

---

## 📌 P1: Missing Transaction in Picklist Completed Event
**Risk:** In `fulfillment/internal/biz/fulfillment/picklist_status_handler.go`, `handlePicklistCompleted` reads a fulfillment, updates its status and items in memory, calls `uc.repo.Update(ctx, fulfillment)`, and then publishes an event `uc.eventPub.PublishFulfillmentStatusChanged(...)`. If the event publisher fails (or the outbox insert fails if not linked to the same DB session), the fulfillment is stuck in "Picked" status, and packing will never start.
**Location:** `fulfillment/internal/biz/fulfillment/picklist_status_handler.go` (Method `handlePicklistCompleted`)

### Implementation Plan
1.  **Wrap in Transaction:**
    *   Use `uc.tx.InTx(ctx, func(txCtx context.Context) error { ... })` around the fulfillment DB setup, update, and the event publishing. Ensure the event publisher utilizes `txCtx` so it writes to the outbox synchronously.

### 🔍 Verification Steps
*   Run tests: `go test -v ./fulfillment/internal/biz/fulfillment/...`

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
git add fulfillment/internal/biz/picklist/picklist.go
git add shipping/internal/biz/shipment/package_shipped_handler.go
git add fulfillment/internal/biz/fulfillment/picklist_status_handler.go

git commit -m "fix(fulfillment): resolve race condition in picklist confirmation and ensure Tx parity
fix(shipping): make package shipped saga compensation idempotent to avoid overwriting valid states

# Agent-10 Fixes based on 250-Round Meeting Review
# P0: Picklist Quantity updates converted to transactional atomic patterns to prevent inventory leak
# P1: Fulfillment status transition outbox wrapped in identical transaction
# P1: Shipping saga compensation correctly checks external mutations before reverting"
```
