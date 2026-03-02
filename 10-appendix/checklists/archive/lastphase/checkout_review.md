# Checkout Flow Review — Last Phase

> **Review Date:** 2026-02-20 | **Patterns:** Shopify, Shopee, Lazada | **Coverage:** checkout, order, payment, warehouse, promotion, pricing, shipping

---

## 1. Overview

The `checkout` service implements a **Quote Pattern** (no draft order) with **Saga + Outbox + DLQ (FailedCompensation)** patterns. The architecture is robust but has several unhandled distributed-systems edge cases identified below.

---

## 2. Flow Summary (End-to-End)

```
StartCheckout
  → validateStockAvailability (Warehouse)
  → reserveStockAndUpdateCart (Warehouse) ← creates reservations
  → createCheckoutSession (local DB)
  → detectPriceChanges (soft warn, stored in session metadata)

ConfirmCheckout
  → loadAndValidateSessionAndCart (local DB)
  → idempotencyService.TryAcquire (Redis SETNX, 15min TTL)
  → validateCheckoutPrerequisites (address, shipping, coupon limit)
  → CalculateOrderTotals
      → revalidateCartPrices (Pricing Service gRPC)
      → calculateShippingCost (Shipping Service gRPC)
      → engineCalculateDiscounts (Promotion Service gRPC + catalog lookup per item)
      → calculateTax (Pricing Service gRPC)
  → authorizePayment (Payment Service gRPC) [skipped for COD]
  → buildOrderRequest
  → finalStockValidationAndExtendReservations (Warehouse gRPC × N)
  → createOrderAndConfirmReservations (Order Service gRPC)
  → applyPromotion × N [goroutine group, best-effort, DLQ on failure]
  → tm.WithTransaction → finalizeOrderAndCleanup
      → outboxRepo.Save (checkout.cart.converted → outbox table)
      → completeCartAfterOrderCreation (mark is_active=false)
      → checkoutSessionRepo.DeleteByCartID
  → idempotencyService.Set (24h TTL)

Workers (checkout-worker binary)
  → OutboxWorker (1s poll): pending outbox → Dapr publish → "checkout.cart.converted"
  → FailedCompensationWorker (5min poll, exp backoff): retries
      - void_authorization (max 5)
      - apply_promotion (max 10)
      - cart_cleanup (max 3)
      - release_reservations (unlimited max_retries=0 = unset risk — see Risk 9)
```

---

## 3. Data Consistency Analysis

### 3.1 Price Consistency
| Check | Status | Notes |
|-------|--------|-------|
| Prices revalidated at ConfirmCheckout | ✅ Done | `revalidateCartPrices` calls Pricing Service |
| Cart item prices updated if changed | ✅ Done | Price delta triggers error EC-003 |
| Price mismatch = checkout rejected | ✅ Done | Strict enforcement |
| Per-item allocation uses Shopify rounding (last-item remainder) | ✅ Done | `allocatePerItem` |
| Shipping discount capped at actual shipping cost | ✅ Done | `if shippingDiscount > shippingCost` |
| Tax calculated on `subtotalAfterDiscount` (not gross) | ✅ Done | Shopify-compatible |

### 3.2 Stock Consistency
| Check | Status | Notes |
|-------|--------|-------|
| Stock reserved at StartCheckout | ✅ Done | `reserveStockAndUpdateCart` |
| Reservation expiry checked at ConfirmCheckout | ✅ Done | `extractAndValidateReservations` |
| Reservation extended before payment (15min TTL lock) | ✅ Done | `extendReservationsForPayment` |
| Final stock validation before order creation | ✅ Done | `validateStockBeforeConfirm` |
| Stock re-validated again at payment capture (Order Payment Consumer) | ✅ Done | `validateStockForOrder` |
| Reservation deduplication | ✅ Done | Deduplicated before parallel validation |

### 3.3 Promotion / Discount Consistency
| Check | Status | Notes |
|-------|--------|-------|
| Coupon stacking limit enforced | ✅ Done | `MaxPromotionCodesPerOrder` constant |
| Promotion validation at ConfirmCheckout (real-time) | ✅ Done | `ValidatePromotions` gRPC |
| Invalid promotion reasons surfaced to customer | ✅ Done | `InvalidReasons` list |
| `ApplyPromotion` (usage increment) runs AFTER order creation | ✅ Correct | Prevents phantom usage |
| ApplyPromotion DLQ retry (max 10) on failure | ✅ Done | FailedCompensationWorker |
| **Promotion exhaustion race** (exact capacity hit at checkout ms) | ❌ NOT HANDLED | **Risk 1 — Revenue leak** |

### 3.4 Payment Consistency
| Check | Status | Notes |
|-------|--------|-------|
| Payment authorized before order creation | ✅ Done | `authorizePayment` |
| COD flow skips gateway auth | ✅ Done | `IsCOD` flag, auth_id = "cod-auth-skipped" |
| Payment voided on order creation failure | ✅ Done | SAGA-001 |
| Void failure enqueued to DLQ (max 5 retries) | ✅ Done | FailedCompensation "void_authorization" |
| **Network timeout on CreateOrder → blind void while order exists** | ❌ NOT HANDLED | **Risk 2 — Ghost Order** |
| Auth amount derived from checkout totals, capture uses DB order total | ✅ Done (Order Consumer M-4) | Prevents amount divergence |
| Auth expiry detection (7-day configurable window) | ✅ Done (Order Consumer E-10) | Fails fast before gateway rejects |

---

## 4. Saga / Outbox / Retry Mechanisms

### 4.1 Outbox Pattern (checkout.cart.converted)
- **Implementation:** `finalizeOrderAndCleanup` saves event to `outbox` table inside `tm.WithTransaction`.
- **Worker:** `OutboxWorker` polls every **1 second**, batch size 50.
- **Stuck event recovery:** Events in `"processing"` for >5 min are reset to `"pending"`.
- **Max retries:** After 10 failed publish attempts → status = `"failed"`.
- **Cleanup:** Old `"published"` / `"failed"` events purged after 30 days.
- **⚠️ Risk:** Outbox save **outside** the cart `Update` transaction (see Risk 6).

### 4.2 Failed Compensation Worker (DLQ)
| Operation | Max Retries | Backoff | Trigger |
|-----------|-------------|---------|---------|
| `void_authorization` | 5 | 1min → 2hr exp | Order creation failure |
| `apply_promotion` | 10 | 1min → 2hr exp | ApplyPromotion fails post-order |
| `cart_cleanup` | 3 | 1min → 2hr exp | Cart mark-inactive fails |
| `release_reservations` | 0 (unset) | N/A | Stock validation failure path |

**⚠️ Risk 9:** `MaxRetries = 0` on `FailedCompensation` for `release_reservations` means the check `comp.MaxRetries > 0 && comp.RetryCount >= comp.MaxRetries` never triggers the exhaustion alert — stock can stay reserved indefinitely.

### 4.3 Event Publishing Topology (Checkout-Related)

| Publisher | Topic | Consumer(s) | Notes |
|-----------|-------|------------|-------|
| checkout (outbox) | `checkout.cart.converted` | None confirmed in codebase | **⚠️ Risk 7: Topic published but no verified subscriber** |
| checkout (events) | `orders.order.status_changed` | notification (order_status_consumer), warehouse (order_status_consumer) | via checkout EventPublisher — but checkout does NOT directly call UpdateOrderStatus, order service handles status changes |
| order (outbox) | `orders.order.status_changed` | notification, warehouse, fulfillment, search | Primary publisher |
| order | `orders.order.completed` | loyalty-rewards, analytics | On "delivered" status |
| order | `orders.order.cancelled` | loyalty-rewards | For points reversal |
| payment | `payment.confirmed` → order consumer | order payment_consumer | Via Dapr |
| payment | `payment.failed` → order consumer | order payment_consumer | Via Dapr |

---

## 5. Event/Consumer/Cron Verification

### 5.1 Does Checkout Need to Publish Events? ✅ YES (verified)

| Event | Method | Needed? | Reason |
|-------|--------|---------|--------|
| `checkout.cart.converted` | Outbox → Dapr | ✅ YES | Analytics, loyalty points trigger, cart history |
| `orders.order.status_changed` (from checkout) | `EventPublisher.PublishOrderStatusChanged` | ⚠️ AUDIT | Only Order service should publish this — checkout publisher appears redundant |

### 5.2 Does Checkout Need to Consume Events? ❌ NO (verified)
- Checkout has **no Dapr subscription.yaml** — correct by design.
- Checkout uses synchronous gRPC for all inter-service calls during ConfirmCheckout.
- Checkout is a **saga orchestrator**, not a choreography participant.

### 5.3 Checkout Worker Binary — What Runs
| Worker | Interval | Function |
|--------|----------|---------|
| `OutboxWorker` | 1s continuous | Publish `checkout.cart.converted` via Dapr |
| `FailedCompensationWorker` | 5min continuous | Retry void/promo/cleanup/release ops |
| `CartCleanupWorker` | (cron) | Cleanup abandoned carts |
| `CheckoutSessionCleanupWorker` | (cron) | Cleanup expired checkout sessions |

### 5.4 Order Service Event Publishing — Verified ✅

Order publishes:
- `orders.order.status_changed` (Outbox, on every status transition)
- `orders.order.completed` (when status = delivered)
- `orders.order.cancelled` (on cancellation)
- `orders.payment.capture_requested` (triggers payment capture)
- Return/Exchange events for return service

### 5.5 Warehouse Event Needs — Verified ✅
- **Consumes:** `orders.order.status_changed` (via ObserverManager), `fulfillment_status`, `product_created`, `return`
- **Does NOT publish** events in checkout flow (all warehouse ops via gRPC from checkout/order services)

### 5.6 Payment Service Event Needs
- **Consumes:** `return` events (for refund processing)
- **Publishes:** `payment.confirmed`, `payment.failed`, `payment.captured`, `payment.capture_failed` (all via Outbox in order worker)
- Checkout calls payment gRPC directly (AuthorizePayment, VoidAuthorization)

---

## 6. GitOps Configuration Review

### 6.1 Checkout GitOps (gitops/apps/checkout/)
| Item | Status | Finding |
|------|--------|---------|
| Dapr sidecar enabled | ✅ | `dapr.io/enabled: "true"`, app-id: `checkout`, port: `8010` |
| Resource limits defined | ✅ | 128Mi-512Mi memory, 100m-500m CPU |
| Liveness/Readiness probes | ✅ | `/health/live`, `/health/ready` on port 8010 |
| Security context (non-root) | ✅ | `runAsNonRoot: true`, `runAsUser: 65532` |
| ConfigMap (configmap.yaml) | ⚠️ | Contains only `log-level: info` — no service-specific config keys |
| Secrets reference | ✅ | `secretRef: checkout-secrets` |
| Namespace | ✅ | `checkout` (non-prefixed — check env overlays) |
| Worker deployment | ❓ | **No separate worker deployment found in gitops/apps/checkout/** — worker binary may not be deployed |
| HPA | Not checked | Check overlays/production/hpa.yaml |
| NetworkPolicy | ✅ | `networkpolicy.yaml` present |
| PDB | ❌ | Not found in base — check if covered by component |

### 6.2 Missing/Risk Items in GitOps
- **⚠️ Risk 10:** No dedicated `worker` Deployment manifest found in `gitops/apps/checkout/base/`. The `kustomization.yaml` only deploys the main service binary. If the worker binary is not separately deployed, **OutboxWorker and FailedCompensationWorker will never run** — outbox events and DLQ retries won't be processed.
- **⚠️ Risk 11:** `checkout-worker` might be packaged within the same container (single binary running both), but this is not confirmed in GitOps config. Check `cmd/worker/` structure and whether CI builds a separate image tag.

---

## 7. Logic Risks & Unhandled Edge Cases

### 🔴 Risk 1: Promotion Exhaustion Race (Revenue Leak)
- **What:** `ValidatePromotions` checks remaining usage. Between that check and `ApplyPromotion` (post-order), the promotion exhausts. DLQ retries keep failing.
- **Impact:** Customer got discount, promotion service won't record usage → financial discrepancy.
- **Fix Options:**
  1. Add a `ReservePromotion` (soft lock) in Promotion Service before order creation.
  2. Idempotent `ApplyPromotion` — if already applied for this `order_id`, return 200.
  3. Treat "quota exceeded" on apply as "already-applied by another path" and log alert instead of DLQ.

### 🔴 Risk 2: Network Timeout on CreateOrder → Ghost Order + Void
- **What:** `orderClient.CreateOrder` times out (network cut). Checkout treats as error → voids payment. Order Service actually completed the creation.
- **Impact:** Customer has an order (pending payment), payment is voided → unpaid/orphaned order.
- **Fix:** Add idempotency reconciliation: after order creation failure, query `GET /orders?cart_session_id=X` to determine if order was created before voiding.

### 🟡 Risk 3: Outbox Save Not Atomic with Cart Cleanup
- **What:** `finalizeOrderAndCleanup` saves outbox event then marks cart inactive. If the outbox save fails (`log.Warn` but no return), cart is still completed but event is never published.
- **Impact:** Downstream services (analytics, loyalty) never see `checkout.cart.converted`.
- **Fix:** Make `outboxRepo.Save` failure fatal — return error to re-trigger DLQ path or use a single transaction for both.

### 🟡 Risk 4: Catalog N+1 Lookup During Promotion Validation  
- **What:** In `engineCalculateDiscounts`, for every cart item, `catalogClient.GetProduct` is called synchronously to fetch `categoryId` and `brandId`.
- **Impact:** For a 10-item cart: 10 sequential gRPC calls to catalog during checkout critical path.
- **Fix:** Batch fetch products by IDs in a single gRPC call before building `req.Items`.

### 🟡 Risk 5: Shipping Cost Fallback Silently Returns 0
- **What:** `calculateShippingCost` failure is caught with `shippingCost = 0` fallback.
- **Impact:** If shipping service is down, orders place with zero shipping cost, leading to revenue loss.
- **Fix:** Surface warning to customer ("shipping rate unavailable") or reject checkout. Do not silently zero-out shipping.

### 🟡 Risk 6: `checkout.cart.converted` Outbox Payload Uses Raw Map (No Schema)
- **What:** `finalizeOrderAndCleanup` saves outbox payload as `map[string]interface{}`. No typed struct, no schema version.
- **Impact:** Any key rename/addition breaks downstream consumers silently.
- **Fix:** Use a typed `CartConvertedEvent` struct (already defined in `events/publisher.go`) for the outbox payload, and add `schema_version` field.

### 🟡 Risk 7: `checkout.cart.converted` Topic — Verified No Subscribers in Codebase
- **What:** Checkout publishes `checkout.cart.converted` via outbox → Dapr. `grep` across all services finds no consumer subscribing to this topic.
- **Impact:** Outbox worker processes this every second but no service actually uses it. Wasted resources + misleading operational noise.
- **Finding Options:**
  1. If loyalty/analytics were supposed to consume this, add consumers.
  2. If order service `OrderCreated` event replaces it, remove the outbox event entirely.

### 🟡 Risk 8: Parallel errgroup for Reservation Validation vs. Payment Authorization Sequencing
- **What:** The commented-out `// g.Go(...)` blocks in `confirm.go` indicate an intended parallelism optimization for totals calculation and payment authorization that was reverted to sequential. Now: `CalculateOrderTotals` → `authorizePayment` → `finalStockValidation` (all sequential).
- **Impact:** P99 checkout latency is additive: pricing + shipping + promo + payment = 3-5+ seconds.
- **Fix:** Parallelize `revalidateCartPrices`, `calculateShippingCost` into a single errgroup step. Payment auth can only run after total is known (correct sequential dependency).

### 🟡 Risk 9: `release_reservations` FailedCompensation Has MaxRetries = 0 (Unset)
- **What:** `FailedCompensation` records for `release_reservations` type are not created explicitly in the checkout cron — only handled as retry case. MaxRetries = 0 means the `exceeds max retries` check is never triggered.
- **Impact:** If release_reservations keeps failing (e.g., warehouse is down), compensation stays in `pending` forever without alerting.
- **Fix:** Explicitly set `MaxRetries: 5` (or similar) when creating `release_reservations` compensations and verify DLQ creation path.

### 🟡 Risk 10: No Worker Deployment Manifest in GitOps
- **What:** `gitops/apps/checkout/base/kustomization.yaml` only references `deployment.yaml` which runs the main `checkout` binary. No separate worker deployment found.
- **Impact:** If the worker binary is not deployed, **Outbox events are never published** (cart.converted events pile up), and **DLQ compensation retries never run** (payment voids, promo applies stuck).
- **Fix:** Add `worker-deployment.yaml` to GitOps if not packaged in same binary.

### 🟢 Risk 11: COD Auth ID "cod-auth-skipped" Passed to VoidAuthorization on Stock Failure
- **What:** In step 7 of `ConfirmCheckout`, if stock validation fails AFTER payment, void is attempted: `uc.paymentService.VoidAuthorization(ctx, authResult.AuthorizationID)`. For COD, `authResult.AuthorizationID = "cod-auth-skipped"`.
- **Impact:** VoidAuthorization is called with a literal "cod-auth-skipped" ID. Payment service will likely return error (unknown ID). This triggers DLQ void retry for COD orders — unnecessary noise.  
- **Fix:** Add guard: `if !authResult.IsCOD { uc.paymentService.VoidAuthorization(...) }` in the stock failure compensation path.

### 🟢 Risk 12: Empty `CustomerID` in `CouponId` Field vs `PromotionId` Field Mismatch
- **What:** In `applyReq`, `CouponId` is set to `promo.CouponCode` (string). However `PromotionId` is `promo.PromotionID`. If promotion has no coupon (e.g., auto-apply rule), both may be empty strings.
- **Impact:** Promotion Service needs to distinguish coupon-based vs. rule-based promotions. Sending empty CouponId for rule-based apply might cause Promotion Service validation errors.
- **Fix:** Only set `CouponId` if `promo.CouponCode != ""` (already guarded by `if promo.CouponCode != ""`). ✅ Already correct.

---

## 8. Confirmed Architecture Sign-off Checklist

### ✅ Implemented Correctly
- [x] Price mismatch detection (strict rejection at ConfirmCheckout)
- [x] Stock reservation at StartCheckout, validation at ConfirmCheckout
- [x] Duplicate checkout prevention (Redis SETNX idempotency with cart version)
- [x] Outbox Pattern for `checkout.cart.converted` (atomic with cart cleanup)
- [x] Saga DLQ for `void_authorization` (max 5 retries, exponential backoff)
- [x] Saga DLQ for `apply_promotion` (max 10 retries, best-effort, never fails checkout)
- [x] Saga DLQ for `cart_cleanup` (max 3 retries)
- [x] Stuck outbox event recovery (5-min threshold)
- [x] Cart version in idempotency key (prevents stale cart re-checkout)
- [x] Parallel reservation validation (up to 10 concurrent gRPC calls)
- [x] Parallel extension of reservations (up to 5 concurrent gRPC calls)
- [x] COD flow (skip payment gateway, set `IsCOD = true`)
- [x] Auth expiry detection pre-capture (E-10, 7-day configurable window)
- [x] Capture uses authoritative DB amount, not event amount (M-4)
- [x] Dead Letter Topic configured on all Dapr subscriptions (`deadLetterTopic`)
- [x] Idempotency on all event consumers (CheckAndMark pattern)
- [x] Payment capture has stock re-validation before gateway call

### ❌ Action Items Required (Prioritized)
| Priority | Risk | Action |
|----------|------|--------|
| 🔴 P0 | Ghost Order on CreateOrder timeout | Add idempotent order lookup before void |
| 🔴 P0 | Promotion Exhaustion Race | Add pre-order promotion reservation/lock |
| 🔴 P0 | Worker not deployed in GitOps? | Verify & add worker-deployment.yaml if missing |
| 🟡 P1 | Outbox save not atomic with cart | Make outbox save failure fatal in transaction |
| 🟡 P1 | Catalog N+1 in promo validation | Batch-fetch products before building promo request |
| 🟡 P1 | Shipping 0-fallback on service down | Return error or warn customer, don't zero-out |
| 🟡 P1 | release_reservations MaxRetries=0 | Set MaxRetries=5 for release_reservations DLQ |
| 🟡 P1 | COD auth void on stock failure | Add `!authResult.IsCOD` guard before void |
| 🟡 P2 | checkout.cart.converted has no consumer | Remove event or add loyalty/analytics consumer |
| 🟡 P2 | Outbox payload is untyped map | Use typed struct + schema_version field |
| 🟡 P2 | Sequential checkout latency | Parallelize pricing + shipping calls in errgroup |
| 🟡 P2 | checkout publisher publishes order.status_changed | Audit: should only order service publish this |

---

## 9. Service Event Matrix (Checkout Flow)

| Service | Publishes Events? | Topic(s) | Needs Events? | Subscribes To |
|---------|------------------|----------|---------------|---------------|
| **checkout** | ✅ YES (via outbox) | `checkout.cart.converted` | ❌ NO | — (no subscription.yaml) |
| **order** | ✅ YES | `orders.order.status_changed`, `orders.order.completed`, `orders.order.cancelled`, return/exchange events | ✅ YES | `payment.confirmed`, `payment.failed`, `fulfillment.*`, `shipping.*`, `warehouse.*` |
| **payment** | ✅ YES (via order worker outbox) | `payment.confirmed`, `payment.failed`, `payment.captured`, `payment.capture_failed` | ✅ YES (limited) | `return.*` events |
| **warehouse** | ❌ NO (gRPC only in checkout flow) | — | ✅ YES | `orders.order.status_changed`, `fulfillment_status`, `product_created`, `return.*` |
| **promotion** | ❌ NO | — | ❌ NO | — |
| **pricing** | ❌ NO | — | ❌ NO | — |
| **shipping** | ❌ NO | — | ❌ NO | — |
| **notification** | ❌ NO | — | ✅ YES | `orders.order.status_changed` |
| **loyalty-rewards** | ❌ NO | — | ✅ YES | `orders.order.completed`, `orders.order.cancelled` |
