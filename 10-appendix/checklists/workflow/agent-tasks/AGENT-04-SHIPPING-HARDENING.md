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

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Swallowing Errors in `parseStatusSafe` ✅ IMPLEMENTED

**File**: `shipping/internal/data/postgres/shipment.go`
**Lines**: ~493-506
**Risk**: Swallowing errors and defaulting to `StatusDraft` when DB state is inconsistent can cause catastrophic data issues, such as resetting a `Delivered` shipment to `Draft` and triggering re-packing.
**Problem**: The function `parseStatusSafe` logs a critical error but returns `StatusDraft`.

**Solution Applied**: Updated `parseStatusSafe` to return `(bizShipment.Status, error)` instead of eating the error. And updated its references in `toBizShipment` to bubble up the error to `GetByID` and `List` instead of silently changing the status.

```go
func parseStatusSafe(s string) (bizShipment.Status, error) {
	st, err := bizShipment.ParseStatus(s)
	if err != nil {
		log.Errorf("CRITICAL: invalid shipment status in database: %q", s)
		return "", fmt.Errorf("invalid shipment status in database: %q", s)
	}
	return st, nil
}
```

**Validation**:
```bash
cd shipping && go test ./internal/data/postgres/... -v
```

### [x] Task 2: Block `CancelShipment` when `Status >= Shipped` ✅ IMPLEMENTED

**File**: `shipping/internal/biz/shipment/shipment_usecase.go`
**Function**: `isValidStatusTransition`
**Lines**: ~598-646
**Risk**: Once a package is shipped or delivered, cancelling it breaks real-world logistics and financial sync. Returns and refunds must be used instead.
**Problem**: `StatusShipped` transitions map allows `StatusCancelled`, which contradicts standard logistic procedures.

**Solution Applied**: Removed `StatusCancelled` from the `StatusShipped` allowed transitions in `isValidStatusTransition` list so shipments cannot be incorrectly transitioned to canceled after they depart.

```go
		StatusShipped: {
			StatusOutForDelivery: true,
			StatusDelivered:      true,
			StatusFailed:         true,
			// Removed StatusCancelled. Cancellation must go through Return process.
		},
```

**Validation**:
```bash
# Verify unit tests to ensure `CalculateRates` and logic fail to cancel a shipped item.
cd shipping && go test ./internal/biz/shipment/... -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Implement Max Batch Size limit in `BatchCreateShipments` ✅ IMPLEMENTED

**File**: `shipping/internal/biz/shipment/shipment_usecase.go`
**Function**: `BatchCreateShipments`
**Risk**: Without a limit, processing a batch insert of 10,000+ items can cause high memory usage, block PostgreSQL transaction pool, and bring down the service API.
**Problem**: No batch chunking or limits inside the usecase.

**Solution Applied**: Implemented a hard limit on batch array sizes, rejecting payloads larger than 100 shipments.

```go
func (uc *ShipmentUseCase) BatchCreateShipments(ctx context.Context, shipments []*Shipment) ([]*Shipment, error) {
	if len(shipments) == 0 {
		return nil, ErrInvalidInput
	}
	// Add batch size limit validation
	if len(shipments) > 100 {
		return nil, fmt.Errorf("batch size exceeds maximum limit of 100")
	}
    // ...
```

**Validation**:
```bash
cd shipping && go test ./internal/biz/shipment/... -run=TestBatchCreateShipments -v
```

### [x] Task 4: Ensure Auth/HMAC Validation in Carrier Webhooks ✅ IMPLEMENTED

**File**: `shipping/internal/service/shipping.go` (or `carrier.go` / `webhook` handlers)
**Risk**: Webhooks are external endpoints. An attacker could bypass auth and mark random shipments as `Delivered`.
**Problem**: Emphasize checking `WebhookValidator` interface calls inside the webhook endpoint handler.

**Solution Applied**: Made the presence of WebhookValidator mandatory. If it is disabled or absent, the process will immediately reject with a security error rather than allowing a pass-through.

```go
	if s.webhookValidator != nil {
		err := s.webhookValidator.ValidateSignature(ctx, req.Carrier, req.Payload, req.Headers)
		if err != nil {
            // ...
		}
	} else {
		s.log.WithContext(ctx).Errorf("SECURITY: webhook validator not configured, rejecting webhook for carrier=%s", req.Carrier)
		return &v1.ProcessWebhookResponse{
			Success:   false,
			Message:   "webhook signature validation is required but not configured",
			Processed: false,
		}, nil
	}
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 5: Remove Deprecated `EventBus` ✅ IMPLEMENTED

**File**: `shipping/internal/biz/shipment/events.go` AND `shipping/internal/biz/shipment/shipment_usecase.go`
**Risk**: Leaving dead code confuses developers and creates tech debt.
**Problem**: `EventBus` is marked as deprecated since all systems have migrated to the `Transactional Outbox` pattern.

**Solution Applied**: Deleted the `EventBus` struct entirely from the shipping codebase, removed its usage from `shipment_usecase.go`, updated its tests, and removed `eventBus` reference from `wire.go`.

### [x] Task 6: Optimize PostgreSQL Advisory Lock Collision ✅ IMPLEMENTED

**File**: `shipping/internal/data/postgres/shipment.go`
**Lines**: 38-52
**Risk**: High scale collision with `fnv.New64a()`.
**Problem**: FNV-1a is not perfectly collision-resistant for UUIDs mapped to `int64`. 

**Solution Applied**: Replaced `fnv.New64a` with `sha256.Sum256` and binary BigEndian parsing to generate the 64-bit advisory lock key securely with significantly fewer hash collisions.

```go
	// Use SHA-256 to hash the UUID and extract the first 8 bytes as an int64 
	// This provides much better collision resistance than FNV-1a for UUIDs.
	h := sha256.Sum256([]byte("shipment:" + id))
	lockKey := int64(binary.BigEndian.Uint64(h[:8]))
	
	return r.DB(ctx).Exec("SELECT pg_advisory_xact_lock(?)", lockKey).Error
```

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
- perf: optimize PostgreSQL advisory lock collision with SHA256

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| 1. DB parser returns explicit error | Code review & tests pass for `parseStatusSafe` error paths | ✅ Done |
| 2. Cannot Cancel Shipped Package | `isValidStatusTransition` tests confirm invalid change | ✅ Done |
| 3. Batch Create limited to 100 | Tests pass, >100 throws err | ✅ Done |
| 4. Deprecated EventBus removed | `wire.go` builds fine without EventBus | ✅ Done |
