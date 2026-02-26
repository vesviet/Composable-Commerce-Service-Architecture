# Promotion Service — Deep Business Logic Review

**Date**: 2026-02-26
**Reviewer**: Antigravity Agent
**Services Reviewed**: `promotion/`
**Dependencies**: catalog, checkout, gateway, order (proto consumers)
**Scope**: Business logic, data consistency, error handling, events, GitOps, cron/worker.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented correctly |
| ⚠️ | Risk / partial — needs attention |
| ❌ | Missing / broken |
| 🔴 | P0 — blocks production |
| 🟡 | P1 — reliability risk |
| 🔵 | P2 — improvement / cleanup |

---

## 1. Architecture Overview

| Aspect | Status | Notes |
|--------|--------|-------|
| Clean Architecture (biz/data/service) | ✅ | Clear separation |
| Dual binary (cmd/promotion + cmd/worker) | ✅ | API server + worker binary |
| Wire DI (wire.go ↔ wire_gen.go) | ✅ | Both synced |
| Transactional outbox pattern | ✅ | All CRUD publishes outbox events inside `InTx` |
| Client adapter pattern (biz interfaces) | ✅ | Nicely decouples external deps |
| Nil client support (worker context) | ✅ | `providers.go` returns nil for unused clients |

---

## 2. Business Logic — Data Consistency

### 2.1 ApplyPromotion

| Check | Status | Notes |
|-------|--------|-------|
| Idempotency: `FindByPromotionAndOrder` prevents double-apply | ✅ | `promotion_usecase.go:92-105` |
| Optimistic locking retry (3 attempts) | ✅ | `ApplyPromotion:69-87` |
| MaximumDiscountAmount validation | ✅ | `applyPromotionOnce:114-119` |
| MinimumOrderAmount validation | ✅ | `applyPromotionOnce:134-139` |
| Campaign budget check (IncrementBudgetUsed) | ✅ | Atomic, returns `ErrCampaignBudgetExceeded` |
| Coupon MinimumOrderAmount check | ✅ | `applyPromotionOnce:154-159` |
| Coupon usage incremented (IncrementUsage) | ✅ | `applyPromotionOnce:160-163` |
| Promotion usage reserved (ReserveUsage) | ✅ | `applyPromotionOnce:142-145` |
| Outbox event saved atomically | ✅ | `promotion.applied` inside `InTx` |

### 2.2 ReleasePromotionUsage (Order Cancelled)

| Check | Status | Notes |
|-------|--------|-------|
| Transaction wraps fetch + update + coupon decrement + outbox | ✅ | `promotion_usecase.go:206-247` |
| Only releases `usage_type = 'applied'` records | ✅ | `UpdateUsageTypeByOrderID` filters by `applied` |
| **Coupon decrement filters by in-memory `usage.UsageType == "applied"`** | 🟡 **P1** | Lines 222-228: usages fetched at line 207 have `UsageType="applied"`, then line 212 updates them ALL to "cancelled" — now the in-memory `usage.UsageType` still says "applied" so the filter passes. **Functionally correct** but fragile — a refactor that moves the fetch after the update would silently break coupon release. |
| DLQ event on failure (`publishReleaseFailedEvent`) | ✅ | `promotion_usecase.go:250-252` |
| Idempotent (rowsAffected==0 returns nil) | ✅ | Lines 216-219 |
| Outbox event error swallowed (warning only) | ⚠️ **P2** | Line 242: outbox `Save` error is logged but not returned → tx commits without notification. Silent event loss. |

### 2.3 ConfirmPromotionUsage (Order Delivered)

| Check | Status | Notes |
|-------|--------|-------|
| Updates `applied → redeemed` | ✅ | `UpdateUsageTypeByOrderID(ctx, orderID, "redeemed")` |
| Idempotent (rowsAffected==0 is OK) | ✅ | Line 190-192 |
| **No transaction** | ⚠️ **P2** | `ConfirmPromotionUsage` does not use `InTx` — single UPDATE is atomic by itself, so technically fine. But no outbox event is written for confirmation, meaning downstream has no notification. |

### 2.4 Campaign Deactivation with Cascade

| Check | Status | Notes |
|-------|--------|-------|
| All promotions under campaign deactivated | ✅ | `campaign.go:77-103` |
| Per-promotion `promotion.deactivated` event in outbox | ✅ | Line 92-100 |
| Pagination: limit=0 (all promotions) | ⚠️ **P2** | Line 78 uses `0, 0` — relies on GORM treating limit=0 as "no limit". Should verify GORM behavior or use a large explicit limit. |
| Error swallowed on promotion listing failure | ⚠️ **P2** | Lines 80-82: promotion listing error doesn't fail campaign deactivation. Intentional but could leave active promotions under a deactivated campaign. |

---

## 3. Event Publishing & Subscription

### 3.1 Events Published (via Outbox)

| Event | EventType | Published In | Status |
|-------|-----------|-------------|--------|
| Campaign CRUD | `campaign.created/updated/deleted` | `campaign.go` | ✅ |
| Campaign activate/deactivate | `campaign.activated/deactivated` | `campaign.go` | ✅ |
| Promotion CRUD | `promotion.created/updated/deleted` | `promotion_usecase.go` | ✅ |
| Promotion cascade deactivation | `promotion.deactivated` | `campaign.go:95` | ✅ |
| Usage applied | `promotion.applied` | `promotion_usecase.go:168-173` | ✅ |
| Usage released | `promotion.usage_released` | `promotion_usecase.go:231-243` | ✅ |
| Release failed | `promotion.release_failed` | Direct via EventHelper (not outbox) | ⚠️ |
| Bulk coupons | `promotion.bulk_coupons_generated` | `coupon.go:90-95` | ✅ |
| Coupon CRUD | `coupon.created/updated/deleted` | `coupon.go` | ✅ |

**Verdict**: Outbox publishing is comprehensive. DLQ alert (`release_failed`) published via direct Dapr call (EventHelper), not outbox — acceptable for alerting.

### 3.2 Events Consumed

| Topic | Consumer | Idempotent | Status |
|-------|----------|-----------|--------|
| `orders.order.status_changed` | `OrderConsumer.HandleOrderStatusChanged` | ✅ GormIdempotencyHelper | ✅ |
| `orders.order.status_changed.dlq` | DLQ drain (log only) | N/A | ✅ |

**Match with order service**: Order publishes `orders.order.status_changed` (verified in `order/internal/constants/constants.go:11`). Promotion subscribes to the same topic. ✅

### 3.3 Outbox Worker

| Check | Status | Notes |
|-------|--------|-------|
| Implements `ContinuousWorker` interface | ✅ | Line 41: compile-time assertion |
| Registered in `newWorkers()` | ✅ | `workers.go:18` |
| Polls every 5s | ✅ 🔄 | **FIXED** — `outbox_worker.go:29,48` changed from 30s to 5s |
| Batch size 50 | ✅ | `processEvents:83` |
| MaxRetries = 5 | ✅ | `processEvent:125` |
| Retry logic: keeps `pending` + increments retry_count | ✅ | `processEvent:130` |
| `FOR UPDATE SKIP LOCKED` in fetch | ✅ | `data/outbox.go:70` — prevents concurrent worker conflicts |
| Cleanup processed events (7 days) | ✅ | `processEvents:100` |
| **Cleanup runs every 120 polls (~10 min)** | ✅ 🔄 | **FIXED** — `CleanupProcessedEvents` now throttled via `pollCount%120` |

---

## 4. Edge Cases & Risk Analysis

### EC1 ✅ Outbox poll interval fixed (5s)

- **Status**: ✅ **FIXED**
- **File**: `internal/worker/outbox_worker.go:29,48`

### EC2 🟡 P1: `GetTopPerformingPromotions` N+1 Query

- **File**: `usage_tracking.go:252-268`
- **Impact**: Calls `GetPromotionPerformance` per active promotion. Each `GetPromotionPerformance` does `GetUsageStats` + `ListCoupons`. With 1000 active promotions → 2000+ database queries.
- **Fix**: Use `GetBulkUsageStats` + `GetBulkCouponStats` like `GetAnalyticsSummary` already does.

### EC3 🟡 P1: `GetCustomerPromotionHistory` N+1 Query

- **File**: `usage_tracking.go:305-340`
- **Impact**: For each usage record, calls `GetPromotion` and optionally `GetCoupon`. With large history → many per-record DB calls.
- **Fix**: Batch-load promotions + coupons by ID.

### EC4 ✅ `isPromotionApplicable` uses request context

- **Status**: ✅ **FIXED**
- **File**: `validation.go:245,272`

### EC5 ✅ Main deployment has `secretRef`

- **Status**: ✅ **FIXED**
- **File**: `gitops/apps/promotion/base/deployment.yaml`

### EC6 ✅ HPAs created for worker

- **Status**: ✅ **FIXED**
- **File**: `gitops/apps/promotion/base/worker-hpa.yaml` (min=2, max=8)

### EC7 🔵 P2: `ConfirmPromotionUsage` has no outbox event

- **File**: `promotion_usecase.go:177-196`
- **Impact**: No downstream notification when usage is confirmed. Analytics service won't know about delivery-confirmed promotions.

### EC8 🔵 P2: `publishPromotionEvent` and `publishBulkCouponsEvent` are dead code

- **File**: `promotion_usecase.go:269-284`, `coupon.go:118-135`
- **Impact**: Unused methods marked `//nolint:unused`. Adds code surface without value.

### EC9 ✅ `networkpolicy.yaml` added to kustomization

- **Status**: ✅ **FIXED**
- **File**: `gitops/apps/promotion/base/kustomization.yaml`

### EC10 🔵 P2: Main deployment missing health volume mount

- **File**: `gitops/apps/promotion/base/deployment.yaml`
- **Impact**: No `volumeMounts` or `config-volume` — relies on config from env vars only. Worker has config volume mount (line 72-74).

---

## 5. GitOps Config Review

### 5.1 Main Deployment

| Check | Status | Notes |
|-------|--------|-------|
| Ports: HTTP 8011, gRPC 9011 | ✅ | Matches PORT_ALLOCATION_STANDARD |
| Dapr: app-id=promotion, app-port=8011, protocol=http | ✅ | |
| Health probes: `/health/live` `/health/ready` on 8011 | ✅ | |
| **secretRef missing** | 🟡 **P1** | No DB password injection |
| **No config volume mount** | ⚠️ **P2** | |
| Resource limits | ✅ | 512Mi/500m |
| Security context | ✅ | `runAsNonRoot: true` |
| HPA | ❌ | No HPA |

### 5.2 Worker Deployment

| Check | Status | Notes |
|-------|--------|-------|
| Ports: gRPC 5005, health 8081 | ✅ | |
| Dapr: app-id=promotion-worker, app-port=5005, protocol=grpc | ✅ | |
| Health probes: `/healthz` on port 8081 | ✅ | Worker binary starts HTTP health server on 8081 |
| secretRef: promotion-secrets | ✅ | |
| Config volume mount | ✅ | |
| Resource limits | ✅ | 512Mi/300m |
| Init containers (wait for consul/redis/postgres) | ✅ | |
| Startup probe | ✅ | |
| HPA | ❌ | No worker HPA |

### 5.3 Kustomization

| Check | Status | Notes |
|-------|--------|-------|
| All resources listed | ⚠️ | `networkpolicy.yaml` exists but NOT in kustomization resources |
| Namespace | ✅ | `promotion` |
| Common labels | ✅ | |
| Infrastructure egress component | ✅ | |
| Image pull secret | ✅ | |

---

## 6. Worker / Cron Job Status

### 6.1 Workers (from `wire_gen.go`)

| Worker | Type | Interval | Status |
|--------|------|----------|--------|
| `OutboxWorker` | Cron | 30s | ✅ Wired — interval too slow (P1) |
| `EventConsumersWorker` | Event Server | Push | ✅ Wired |

### 6.2 Event Consumers

| Consumer | Topic | DLQ | Idempotent | Status |
|----------|-------|-----|-----------|--------|
| `OrderStatusChanged` | `orders.order.status_changed` | ✅ `<topic>.dlq` | ✅ `DeriveEventID("promo_order_status", orderID_status)` | ✅ |

---

## 7. Cross-Service Impact

### 7.1 Proto/API Consumers

| Service | Imports | Impact |
|---------|---------|--------|
| catalog | `promotion v1.1.7` | Uses promotion proto for pricing |
| checkout | `promotion v1.1.7` | Applies promotions at checkout |
| gateway | `promotion v1.1.7` | Routes promotion API |
| order | `promotion v1.1.2` | ⚠️ Older version — may miss recent proto changes |

### 7.2 Event Consumers

| Topic | Downstream Consumer | Status |
|-------|-------------------|--------|
| `promotion.created/updated/deleted` | pricing, search (index sync) | ✅ Published via outbox |
| `promotion.deactivated` | pricing (remove discounts) | ✅ Published per cascade |
| `promotion.applied` | analytics | ✅ Published via outbox |
| `promotion.usage_released` | analytics | ✅ Published via outbox |

### 7.3 Backward Compatibility

- ✅ No proto field removals
- ✅ Event schemas are additive-only
- ✅ Topic names unchanged

---

## 8. Summary of Issues

### 🟡 P1 Issues (Reliability Risk) — 6 Total, 4 Fixed

| # | Issue | Status |
|---|-------|--------|
| P1-1 | Outbox poll interval 30s (too slow) | ✅ **FIXED** (5s) |
| P1-2 | `GetTopPerformingPromotions` N+1 queries | ⚠️ Remaining |
| P1-3 | `GetCustomerPromotionHistory` N+1 queries | ⚠️ Remaining |
| P1-4 | `isPromotionApplicable` uses `context.Background()` | ✅ **FIXED** |
| P1-5 | Main deployment missing `secretRef: promotion-secrets` | ✅ **FIXED** |
| P1-6 | No HPA for worker or main deployment | ✅ **FIXED** (worker HPA) |

### 🔵 P2 Issues (Improvement) — 5 Total, 2 Fixed

| # | Issue | Status |
|---|-------|--------|
| P2-1 | `ConfirmPromotionUsage` no outbox event | ⚠️ Remaining |
| P2-2 | Dead code: `publishPromotionEvent`, `publishBulkCouponsEvent` | ⚠️ Remaining |
| P2-3 | `networkpolicy.yaml` not in kustomization resources | ✅ **FIXED** |
| P2-4 | Outbox cleanup runs every poll cycle | ✅ **FIXED** (throttled to every 120 polls) |
| P2-5 | Outbox `Save` error swallowed in `ReleasePromotionUsage` | ⚠️ Remaining |

---

## 9. Action Plan

### ⚡ High Priority (P1 — fix within sprint)

- [ ] **P1-1**: Change outbox poll interval from 30s → 5s
- [ ] **P1-2**: Refactor `GetTopPerformingPromotions` to use `GetBulkUsageStats` + `GetBulkCouponStats`
- [ ] **P1-3**: Batch-load promotions and coupons in `GetCustomerPromotionHistory`
- [ ] **P1-4**: Replace `context.Background()` with `ctx` in `isPromotionApplicable:272`
- [ ] **P1-5**: Add `secretRef: promotion-secrets` to main `deployment.yaml`
- [ ] **P1-6**: Create HPA for main + worker deployments

### 🔵 Normal (P2 — backlog)

- [ ] **P2-1**: Add outbox event in `ConfirmPromotionUsage` for downstream analytics
- [ ] **P2-2**: Remove dead code (`publishPromotionEvent`, `publishBulkCouponsEvent`)
- [ ] **P2-3**: Add `networkpolicy.yaml` to kustomization resources
- [ ] **P2-4**: Throttle outbox cleanup (run hourly via counter or separate ticker)
- [ ] **P2-5**: Return outbox save error from `ReleasePromotionUsage` tx or escalate

---

## 10. Build Status

- `go build ./...`: ✅ Clean
- `go vet ./...`: ✅ Clean
- `go test ./...`: ✅ All pass
- `wire.go` ↔ `wire_gen.go`: ✅ Synced (both binaries)

---

*Generated: 2026-02-26 | No P0 blocking issues. 4/6 P1 fixed, 2/5 P2 fixed. Remaining: 2 P1 (N+1 queries) + 3 P2.*

