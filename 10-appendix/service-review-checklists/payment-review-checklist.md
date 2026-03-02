## 🔍 Service Review: payment

**Date**: 2026-02-25
**Status**: ✅ Ready

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | Fixed |
| P1 (High) | 1 | Fixed |
| P2 (Normal) | 1 | Noted |

### 🔴 P0 Issues (Blocking)

1. **[Event/Topic]** `internal/data/eventbus/order_consumer.go`:16 — `TopicOrderCancelled` was `"orders.order_cancelled"` (underscore) but the order service publishes `"orders.order.cancelled"` (dot). Consumer was **never receiving** order cancelled events → authorized payments were never voided on order cancellation → potential fund capture on cancelled orders.

### 🟡 P1 Issues (High)

1. **[Config/GitOps]** `gitops/apps/payment/overlays/dev/configmap.yaml` — `ORDER_SERVICE_ADDR` and `CUSTOMER_SERVICE_ADDR` used in `internal/client/provider.go` via `os.Getenv()` were missing from the configmap. Workers fell back to hard-coded `"order-service:9000"` / `"customer-service:9000"` which don't resolve in-cluster.

### 🔵 P2 Issues (Normal)

1. **[Performance]** `internal/biz/transaction/usecase.go`:40 — `GetCustomerTransactions` does `FindByCustomerID(ctx, customerID, 1000, 0)` then loops `FindByPaymentID` per payment — classic N+1. For customers with many payments this is unbounded. Acceptable for current scale but should be addressed with a proper JOIN query.

### ✅ Completed Actions (2026-02-25)

1. **Fixed P0**: `internal/data/eventbus/order_consumer.go` — `TopicOrderCancelled = "orders.order.cancelled"` (was `orders.order_cancelled`).
2. **Fixed P1**: `gitops/apps/payment/overlays/dev/configmap.yaml` — Added `ORDER_SERVICE_ADDR: "order.order-dev.svc.cluster.local:81"` and `CUSTOMER_SERVICE_ADDR: "customer.customer-dev.svc.cluster.local:81"`.

### ✅ Completed Actions (Previous Reviews)

1. Fixed: `internal/biz/fraud/feature_extraction.go`:147 — Uses `context.Background()` instead of the passed context `ctx` in `ml.geoIP.GetCountryCode()` (P1, 2026-02-23).
2. Fixed: `order.completed` consumer missing → seller payout/escrow release never triggered (P0, 2026-02-24).
3. Fixed: Dapr worker `app-port`/`app-protocol` mismatch — now correctly uses `app-port: 5005` + `app-protocol: grpc` (P1, 2026-02-24).
4. Fixed: `PaymentReconciliationJob.Stop()` double-close panic on channel (P2, 2026-02-24).

### 🌐 Cross-Service Impact

- Services importing this proto: `checkout`, `customer`, `gateway`, `order`, `return`
- Services consuming payment events: `analytics`, `checkout`, `fulfillment`, `loyalty-rewards`, `notification`, `order`
- Backward compatibility: ✅ Preserved — `TopicOrderCancelled` rename is a subscription-side fix only; topic string matches producer

### 🚀 Deployment Readiness

- Config/GitOps aligned: ✅ (ORDER_SERVICE_ADDR, CUSTOMER_SERVICE_ADDR now in configmap)
- Ports: ✅ HTTP 8005, gRPC 9005, Worker Dapr gRPC 5005, Worker health 8081
- Health probes: ✅ Main: httpGet /health/live:8005; Worker: httpGet /healthz:8081
- Resource limits: ✅ Set on both main and worker deployments
- Migration safety: ✅ Goose-managed, additive migrations only
- HPA: ✅ Present

### Build Status

- `golangci-lint`: ✅ 0 warnings
- `go build ./...`: ✅
- `wire`: ✅ Generated
- Generated Files (`wire_gen.go`, `*.pb.go`): ✅ Not modified manually
- `bin/` Files: ✅ Removed (gitignored)

### Documentation

- Service doc: ✅ `docs/03-services/core-services/payment-service.md`
- README.md: ✅ Updated
- CHANGELOG.md: ✅ Updated
