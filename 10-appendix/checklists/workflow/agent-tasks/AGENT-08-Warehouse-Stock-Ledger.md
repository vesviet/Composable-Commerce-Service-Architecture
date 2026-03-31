# AGENT-08: Fix Stock Transaction Ledger Double-Deduction

> **Created**: 2026-03-31
> **Priority**: P0 (critical audit accuracy)
> **Sprint**: Hardening Sprint
> **Services**: `warehouse`
> **Estimated Effort**: 0.5 days

---

## 📋 Overview

Fixed a critical double-deduction bug in the Warehouse service's `StockTransaction` audit ledger. Prior to this fix, the `ReserveStock` API would log `-Quantity` against physical stock bounds, followed by `ConfirmReservation` logging ANOTHER `-Quantity` against the physical bounds. This caused analytical double-counting for single stock movements. `ReleaseReservation` was also incorrectly tracking reserved bounds rather than standard physical bounds. The fix normalizes all audit logs across the reservation lifecycle to strictly audit physical stock (`QuantityAvailable`).

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix ReserveStock Double Deduction
**File**: `warehouse/internal/biz/reservation/reservation.go`
**Lines**: ~270
**Risk**: Audit double-deduction.
**Problem**: Logic was logging `-req.Quantity` for physical drops during reservations despite physical boundaries not being crossed yet.
**Fix**: `QuantityChange` changed to `0` and bounds standardized.

### [x] Task 2: Fix ReleaseReservation Inconsistent Bounds
**File**: `warehouse/internal/biz/reservation/reservation_release.go`
**Lines**: ~60
**Risk**: Audit log mathematical break.
**Problem**: Logic was tracking `inv.QuantityReserved` instead of physical logic.
**Fix**: Standardized `QuantityBefore` and `QuantityAfter` against `inv.QuantityAvailable` with `QuantityChange: 0`.

---

## 🔧 Pre-Commit Checklist

```bash
cd warehouse && go build ./...
cd warehouse && go test -race ./...
cd warehouse && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(warehouse): correct stock ledger double-deduction bug

- fix(reservation): update ReserveStock audit log to prevent faking a physical drop
- fix(reservation): update ReleaseReservation to track physical availability consistently

Closes: AGENT-08
```
