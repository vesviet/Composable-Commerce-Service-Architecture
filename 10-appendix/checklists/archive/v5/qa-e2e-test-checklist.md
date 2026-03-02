# 🚀 QA End-to-End Test Checklist — Customer Journeys
> **Version**: v5.3 | **Date**: 2026-02-15
> **Scope**: Full customer-facing flows spanning multiple services
> **Method**: API-level testing through Gateway + browser testing for Frontend/Admin
> **Environment**: Dev (k3d) with all 19 services + Dapr + Redis + PostgreSQL + ES

---

## 🔴 P0 — Critical Customer Journeys

### 1. Browse → Search → Purchase (Happy Path)

> **Services involved**: Gateway → Search → Catalog → Pricing → Promotion → Checkout → Order → Payment → Warehouse → Fulfillment → Shipping → Notification
> **Ref**: [browse-to-purchase.md](../../../05-workflows/customer-journey/browse-to-purchase.md)

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 1.1 | **Search products** — `GET /api/search?q=laptop` | Returns products from Elasticsearch with price + availability | `[ ]` |
| 1.2 | **View product detail** — `GET /api/catalog/products/{id}` | Returns product with EAV attributes, price, stock status | `[ ]` |
| 1.3 | **Add to cart** — `POST /api/checkout/cart/items` | Cart item created, stock validated | `[ ]` |
| 1.4 | **Apply coupon** — `POST /api/checkout/cart/coupons` | Discount applied, cart total updated | `[ ]` |
| 1.5 | **Get shipping rates** — `GET /api/shipping/rates` | Returns available shipping methods + costs | `[ ]` |
| 1.6 | **Confirm checkout** — `POST /api/checkout/confirm` | Order created + payment authorized + stock reserved | `[ ]` |
| 1.7 | **Saga Compensation** — Simulate Order creation fail | Payment voided + Stock released (Compensating transactions) | `[ ]` |
| 1.8 | **Idempotency** — Replay `confirm` request | Returns same Order ID, no side effects | `[ ]` |
| 1.9 | **Verify order** — `GET /api/orders/{id}` | Order status = `confirmed`, items match cart | `[ ]` |
| 1.10 | **Payment captured** — wait for `CaptureRetryJob` (1m) | Order status → `paid`, payment → `captured` | `[ ]` |
| 1.11 | **Fulfillment created** — wait for `order.paid` event | Fulfillment record created in fulfillment service | `[ ]` |
| 1.12 | **Shipping created** — wait for `fulfillment.completed` event | Shipment created with tracking number | `[ ]` |
| 1.13 | **Order delivered** — simulate `shipping.delivered` event | Order status → `delivered`, loyalty points awarded | `[ ]` |
| 1.14 | **Email notifications** — verify throughout flow | Confirmation + shipped + delivered emails sent | `[ ]` |

---

### 2. Fraud Detection Journey (Data-Driven)

> **Services**: Gateway → Payment (Fraud) → Checkout
> **Logic**: Rules (Velocity, Amount, Location) + ML + Blacklist

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 2.1 | **Low Risk (Happy Path)** — Regular purchase < $500 | Fraud Score < 30, Payment Authorized | `[ ]` |
| 2.2 | **High Amount** — Purchase > $100,000 | Fraud Score > 80, Payment Declined (Action: BLOCK) | `[ ]` |
| 2.3 | **High Velocity** — 6th transaction in 1 hour | Fraud Score increases (Velocity Rule), Review/Block triggered | `[ ]` |
| 2.4 | **Blacklisted IP** — `X-Forwarded-For: <Blacklisted-IP>` | Immediate Block (Critical Risk) | `[ ]` |
| 2.5 | **New Account + Large Amount** — Account age < 24h + $5k | High Risk score (Behavior Rule), Manual Review triggered | `[ ]` |
| 2.6 | **Bypass Attempt** — Invalid Device Fingerprint | Fraud Context captures anomaly, score increased | `[ ]` |

---

### 3. Order Cancellation Journey

> **Services**: Gateway → Order → Payment → Warehouse → Loyalty → Promotion → Fulfillment → Notification

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 3.1 | **Create order** (prerequisite) | Order in `confirmed` status | `[ ]` |
| 3.2 | **Cancel order** — `POST /api/orders/{id}/cancel` | Status → `cancelled` | `[ ]` |
| 3.3 | **Stock released** — verify warehouse | Available stock increased by reserved qty | `[ ]` |
| 3.4 | **Refund initiated** — verify payment | Refund transaction created | `[ ]` |
| 3.5 | **Loyalty reversed** — verify loyalty | Points deducted (exact amount earned) | `[ ]` |
| 3.6 | **Promo reversed** — verify promotion | Coupon usage count decremented | `[ ]` |
| 3.7 | **Fulfillment stopped** — verify fulfillment | Picking/packing halted | `[ ]` |
| 3.8 | **Notification sent** — verify email | Cancellation email sent to customer | `[ ]` |

---

### 4. Return & Refund Journey

> **Services**: Gateway → Return → Order → Payment → Warehouse → Shipping → Notification
> **Ref**: [returns-exchanges.md](../../../05-workflows/customer-journey/returns-exchanges.md)

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 4.1 | **Create return request** — `POST /api/returns` | Return created with real product data (not "stub-product") | `[ ]` |
| 4.2 | **Verify eligibility** — within 30-day window | Return eligible based on `CompletedAt` (or `UpdatedAt` fallback) | `[ ]` |
| 4.3 | **Approve return** — `POST /api/returns/{id}/approve` | Status → `approved`, `return.approved` event published | `[ ]` |
| 4.4 | **Shipping label generated** — verify shipping call | Return shipping label available for download | `[ ]` |
| 4.5 | **Items received** — `POST /api/returns/{id}/receive` | Items marked received, inspection pending | `[ ]` |
| 4.6 | **Refund processed** — `POST /api/returns/{id}/complete` | Payment refund initiated, order updated | `[ ]` |
| 4.7 | **Inventory restocked** — verify warehouse | Stock increased by returned qty | `[ ]` |
| 4.8 | **Notifications sent** — verify throughout | Approved + shipped + refunded emails sent | `[ ]` |

---

### 5. Exchange Journey

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 5.1 | **Create exchange request** — `POST /api/returns` (type=exchange) | Exchange return created | `[ ]` |
| 5.2 | **Approve exchange** | `return.exchange_approved` event published | `[ ]` |
| 5.3 | **Replacement order created** — verify order service | New order created with replacement items | `[ ]` |
| 5.4 | **Original items refund / adjustment** | Price difference handled (up-charge or partial refund) | `[ ]` |

---

## 🟡 P1 — Important Customer Journeys

### 6. Customer Registration & Authentication

> **Services**: Gateway → Auth → Customer → Loyalty → Notification
> **Ref**: [account-management.md](../../../05-workflows/customer-journey/account-management.md)

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 6.1 | **Register** — `POST /api/auth/register` | User + customer profile created, welcome email sent | `[ ]` |
| 6.2 | **Login** — `POST /api/auth/login` | JWT access + refresh tokens returned | `[ ]` |
| 6.3 | **MFA setup** — `POST /api/auth/mfa/setup` | TOTP secret generated, QR code returned | `[ ]` |
| 6.4 | **MFA login** — `POST /api/auth/login` + `POST /api/auth/mfa/verify` | MFA challenge → valid TOTP → login complete | `[ ]` |
| 6.5 | **OAuth2 Google** — `GET /api/auth/oauth2/google` | OAuth flow → JWT returned (new or existing user) | `[ ]` |
| 6.6 | **Profile update** — `PUT /api/customers/profile` | Profile updated, audit log entry created | `[ ]` |
| 6.7 | **Address management** — CRUD `/api/customers/addresses` | Add, update, delete addresses | `[ ]` |
| 6.8 | **Customer auto-enrolled in loyalty** — verify loyalty | `customer.created` → loyalty account created | `[ ]` |

---

### 7. Loyalty & Rewards Journey

> **Services**: Gateway → Loyalty → Customer → Order → Notification
> **Ref**: [loyalty-rewards.md](../../../05-workflows/customer-journey/loyalty-rewards.md)

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 7.1 | **View points balance** — `GET /api/loyalty/balance` | Current points + tier displayed | `[ ]` |
| 7.2 | **Earn points on purchase** — complete an order | Points credited after `order.completed` event | `[ ]` |
| 7.3 | **Points reversed on cancel** — cancel the order | Points deducted, idempotent on replay | `[ ]` |
| 7.4 | **Redeem points** — `POST /api/loyalty/redeem` | Points deducted, reward issued | `[ ]` |
| 7.5 | **Tier upgrade** — earn enough points | Tier auto-upgraded, notification sent | `[ ]` |

---

### 8. Product Review Journey

> **Services**: Gateway → Review → Order → Catalog
> **Ref**: [product-reviews.md](../../../05-workflows/customer-journey/product-reviews.md)

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 8.1 | **Submit review** — `POST /api/reviews` | Review created (purchase verified) | `[ ]` |
| 8.2 | **Moderation** — auto-moderate content | Clean content → auto-approved, flagged → pending | `[ ]` |
| 8.3 | **View product reviews** — `GET /api/reviews?product_id=X` | Approved reviews returned with aggregated rating | `[ ]` |

---

### 9. Search & Product Discovery

> **Services**: Gateway → Search → Catalog → Pricing → Warehouse

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 9.1 | **Full-text search** — `GET /api/search?q=samsung phone` | Relevant products, ranked by relevance | `[ ]` |
| 9.2 | **Filtered search** — category + price range + in-stock | Results respect all filters | `[ ]` |
| 9.3 | **Real-time price update** — update price in Pricing service | Search results reflect new price within seconds | `[ ]` |
| 9.4 | **Real-time stock update** — stock changes in Warehouse | Search results show updated availability | `[ ]` |

---

## 🟢 P2 — Admin & Operational E2E

### 10. Admin Panel Operations

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 10.1 | **Admin login** — admin panel auth flow | Admin JWT with RBAC permissions | `[ ]` |
| 10.2 | **Create product** — admin product creation | Product + variants + attributes created, indexed in search | `[ ]` |
| 10.3 | **Update pricing** — admin price update | Price event → search index updated | `[ ]` |
| 10.4 | **Manage inventory** — admin stock adjustment | Stock adjusted, movement logged | `[ ]` |
| 10.5 | **View analytics dashboard** — admin analytics | Real metrics (not placeholder values) | `[ ]` |
| 10.6 | **Process return** — admin approves return | Return approved → refund + restock triggered | `[ ]` |

### 11. Operational Monitoring

| Step | Test Case | Expected Result | Status |
|------|-----------|-----------------|--------|
| 11.1 | **Health check endpoints** — all services `/health` | All return 200 OK | `[ ]` |
| 11.2 | **Prometheus metrics exposed** — all services `/metrics` | Metrics scraped by Prometheus | `[ ]` |
| 11.3 | **DLQ monitoring** — FailedCompensation table check | DLQ entries visible in Grafana | `[ ]` |
| 11.4 | **Outbox lag** — outbox_events pending count | Outbox processed within 30s | `[ ]` |
| 11.5 | **Fraud Alerting** — Monitor `fraud_detected` metrics | High fraud rate triggers PagerDuty/Alert | `[ ]` |
---

## 📊 E2E Test Summary

| Journey | Steps | Priority | Est. Time |
|---------|-------|----------|-----------|
| Browse → Purchase | 14 | 🔴 P0 | 35 min |
| Fraud Detection | 6 | 🔴 P0 | 15 min |
| Order Cancellation | 8 | 🔴 P0 | 15 min |
| Return & Refund | 8 | 🔴 P0 | 20 min |
| Exchange | 4 | 🔴 P0 | 10 min |
| Registration & Auth | 8 | 🟡 P1 | 15 min |
| Loyalty & Rewards | 5 | 🟡 P1 | 10 min |
| Product Reviews | 3 | 🟡 P1 | 5 min |
| Search & Discovery | 4 | 🟡 P1 | 10 min |
| Admin Operations | 6 | 🟢 P2 | 15 min |
| Operational Monitoring | 5 | 🟢 P2 | 12 min |
| **Total** | **~71** | | **~162 min** |

### SLA Verification

| Metric | Target | How to Verify |
|--------|--------|---------------|
| Order creation (p95) | < 200ms | Measure Checkout → Order response time |
| Product search (p95) | < 100ms | Measure Search API response time |
| Payment processing (p95) | < 2s | Measure PaymentAuth → response time |
| Stock sync (real-time) | < 5s | Time from warehouse update → search reflects |
| Price sync (real-time) | < 5s | Time from pricing update → search reflects |
