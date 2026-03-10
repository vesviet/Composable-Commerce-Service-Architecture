# AGENT-04: Payment Service Hardening

> **Created**: 2026-03-10
> **Priority**: P0/P1
> **Sprint**: Hardening Sprint
> **Services**: `payment`
> **Estimated Effort**: 3-4 days
> **Source**: [Payment Flows 150-Round Meeting Review Artifact](file:///home/user/.gemini/antigravity/brain/2b1e1b9b-b02e-4879-a8a1-0af061864a7b/payment_flows_150round_review.md)

---

## 📋 Overview

Based on the 150-round Payment Flows meeting review, the Payment service contains critical vulnerabilities regarding gateway capture idempotency, memory exhaustion during reconciliation, and floating-point precision loss in COD flows. This hardening task re-assigns AGENT-04 to resolve these P0 and P1 issues.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Pass Idempotency Key in Public CapturePayment

**File**: `payment/internal/biz/payment/usecase.go`
**Lines**: ~495-505
**Risk**: Network retries on the capture endpoint will double-charge customers if the gateway doesn't receive an idempotency key.
**Problem**: The `CapturePayment` function passes an empty string `""` for the idempotency key to `gateway.CapturePayment()`.
**Fix**:
Generate and pass an idempotency key based on the payment ID.
```go
// BEFORE:
result, err := gateway.CapturePayment(ctx, payment.GatewayPaymentID, captureAmount, "")

// AFTER:
idempotencyKey := fmt.Sprintf("capture_%s", payment.PaymentID)
result, err := gateway.CapturePayment(ctx, payment.GatewayPaymentID, captureAmount, idempotencyKey)
```

**Validation**:
```bash
cd payment && go test ./internal/biz/payment/... -v -run TestCapturePayment
```

---

### [ ] Task 2: Implement Pagination in Reconciliation Worker

**File**: `payment/internal/biz/reconciliation/reconciliation.go`
**Lines**: ~144-150
**Risk**: Hardcoded `limit=10000` means silently ignoring records during high volume; loading massive records causes memory spikes (OOM).
**Problem**: The `RunReconciliation` function fetches all internal payments with a single `FindByFilters` call.
**Fix**:
Implement a `for` loop to fetch and process reconciliation in chunks of 500 or 1,000 using cursor-based pagination or offset pagination.
```go
// BEFORE:
payments, err := uc.paymentRepo.FindByFilters(ctx, filters, 10000, 0)
// ...
mismatches := uc.reconcileTransactions(payments, gatewayTxns)

// AFTER (Conceptual):
var allMismatches []*payment.ReconciliationMismatch
limit := 1000
offset := 0
for {
    paymentsBatch, err := uc.paymentRepo.FindByFilters(ctx, filters, limit, offset)
    if err != nil { ... }
    if len(paymentsBatch) == 0 { break }

    batchMismatches := uc.reconcileTransactions(paymentsBatch, gatewayTxns)
    allMismatches = append(allMismatches, batchMismatches...)
    offset += limit
}
mismatches = allMismatches
```

**Validation**:
```bash
cd payment && go test ./internal/biz/reconciliation/... -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Use Decimal for COD Fee Calculation

**File**: `payment/internal/biz/payment/cod.go`
**Lines**: ~70-75
**Risk**: Precision loss in COD total amounts leads to reconciliation ledger mismatches.
**Problem**: `calculateCODFee` uses `float64` for critical financial calculations and additions.
**Fix**:
Refactor the fee calculation logic and the `totalAmount` addition in `CreateCODPayment` to use `shopspring/decimal`.
```go
// BEFORE:
codFee := uc.calculateCODFee(req.Amount.Float64(), req.ShippingAddress)
totalAmount := req.Amount.Float64() + codFee

// AFTER:
codFeeFloat := uc.calculateCODFee(req.Amount.Float64(), req.ShippingAddress)
codFeeDec := decimal.NewFromFloat(codFeeFloat).Round(int32(money.DefaultScale))
totalAmountDec := req.Amount.Decimal.Add(codFeeDec)
```

**Validation**:
```bash
cd payment && go test ./internal/biz/payment/... -v -run CreateCOD
```

---

### [ ] Task 4: Auto-Heal Status Mismatches During Reconciliation

**File**: `payment/internal/biz/reconciliation/reconciliation.go`
**Lines**: ~245-255
**Risk**: Webhook drops leave orders stuck in Pending forever without manual intervention.
**Problem**: The reconciliation process publishes mismatch events but leaves the payment untouched.
**Fix**:
Add logic in `reconcileTransactions` (or after it) to auto-update payment status when the gateway is confirmed `paid`/`succeeded` but internal is `pending`. Update the `Status` field and persist via the repository.

**Validation**:
```bash
cd payment && go test ./internal/biz/reconciliation/... -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd payment && wire gen ./cmd/server/ ./cmd/worker/
cd payment && go build ./...
cd payment && go test -race ./...
cd payment && golangci-lint run ./...
```

---

## 📝 Commit Format

```text
refactor(payment): harden payment flows and reconciliation

- fix: add missing idempotency key to public CapturePayment endpoint
- fix: implement pagination in reconciliation worker to prevent OOM
- fix: convert COD fee total calculation to use shopspring/decimal
- feat: implement auto-healing for status mismatches during reconciliation

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| No Double Charges | Public Capture passes an idempotency key to gateway | 🔴 TODO |
| Reconciliation Scales | Nightly job can process 50k records without OOM via pagination | 🔴 TODO |
| COD Math is Exact | Total amount uses `decimal.Add` to prevent fractional truncation | 🔴 TODO |
| Mismatches Healed | Pending transactions missing webhooks sync to Succeeded automatically | 🔴 TODO |
