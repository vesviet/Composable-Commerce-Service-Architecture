# Return & Refund Flow - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review of the Return & Refund Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- [High] RET-P1-01 Refund/restock best-effort leads to inconsistent states. Required: granular statuses + DLQ. See `order/internal/biz/return/return.go`.
- [High] RET-P1-02 Payment refund calls lack idempotency. Required: generate/pass idempotency key. See `order/internal/biz/return/return.go`.
- [High] RET-P1-03 Hardcoded fallback values in shipping label generation. Required: fail fast on missing data. See `order/internal/biz/return/return.go`.

## 🆕 NEWLY DISCOVERED ISSUES
- None

## ✅ RESOLVED / FIXED
- None

---

## P1 - Resilience / Data Integrity

- **Issue**: Refund and restock operations are "best-effort" and can lead to inconsistent states.
  - **Service**: `order`
  - **Location**: `order/internal/biz/return/return.go` (`UpdateReturnRequestStatus` function, `completed` case)
  - **Impact**: When a return is marked `completed`, the system calls `processReturnRefund` and `restockReturnedItems`. If either of these critical operations fails, the error is only logged, and the return request remains `completed`. This can result in a customer not receiving their refund or inventory not being updated, while the system incorrectly reports the process as finished.
  - **Recommendation**: Introduce more granular statuses for the return flow (e.g., `pending_refund`, `refund_failed`, `pending_restock`). A failure in a critical step should move the request to a corresponding failed state and be pushed to a Dead-Letter Queue (DLQ) for automated retry or manual intervention.

---

## P1 - Idempotency

- **Issue**: Calls to the payment service for refunds are not idempotent.
  - **Service**: `order`
  - **Location**: `order/internal/biz/return/return.go` (`processReturnRefund` function)
  - **Impact**: The call to `paymentService.ProcessRefund` does not include an idempotency key. If the logic that triggers the refund is retried (e.g., due to a temporary network error after the refund was already processed), it could result in the customer being refunded multiple times for the same return.
  - **Recommendation**: The `order` service must generate and pass a unique idempotency key for each refund attempt (e.g., using the `ReturnRequest` ID). The `payment` service's `ProcessRefund` endpoint must be updated to honor this key to prevent duplicate transactions.

---

## P1 - Correctness

- **Issue**: The logic for generating a return shipping label contains hardcoded fallback values.
  - **Service**: `order`
  - **Location**: `order/internal/biz/return/return.go` (`generateReturnShippingLabel` function)
  - **Impact**: If the system fails to retrieve the correct warehouse address, it falls back to a hardcoded address in "San Francisco, US". It also uses a hardcoded default weight of 0.5 kg for all items. This will lead to incorrect shipping labels, inaccurate shipping costs, and logistical failures.
  - **Recommendation**: Remove all hardcoded fallbacks. The function should fail fast and return an error if it cannot determine a reliable origin address or item weight. This prevents incorrect data from propagating through the system.
