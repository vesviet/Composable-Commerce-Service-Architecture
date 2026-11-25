# Workflow Review Checklists

Comprehensive business logic review checklists for every major e-commerce flow. Each checklist covers: data consistency, saga/outbox patterns, event publish/subscribe, edge cases, GitOps config, and worker/cron jobs.

**Last reorganized**: 2026-11-25  
**Consolidated Issue Ledger**: **[UNFIXED-ISSUES-CONSOLIDATED.md](UNFIXED-ISSUES-CONSOLIDATED.md)** (`0` open P0 · `0` open P1 · `64/77` P2 fixed · `13` deferred)

---

## Canonical Review Files

Each business flow has **one canonical review file**. Always use the file listed here.

### Core Commerce

| Flow | Canonical File | Services Covered |
|------|---------------|------------------|
| Cart & Checkout | [cart-checkout-deep-review.md](cart-checkout-deep-review.md) | checkout, order |
| Order Lifecycle | [order-lifecycle-deep-review.md](order-lifecycle-deep-review.md) | order |
| Payment | [payment-review.md](payment-review.md) | payment |

### Catalog & Discovery

| Flow | Canonical File | Services Covered |
|------|---------------|------------------|
| Catalog & Product | [catalog-product-review.md](catalog-product-review.md) | catalog, review, search |
| Search & Discovery | [search-discovery-review.md](search-discovery-review.md) | search |

### Pricing & Promotions

| Flow | Canonical File | Services Covered |
|------|---------------|------------------|
| Pricing, Promotion & Tax | [pricing-promotion-tax-review.md](pricing-promotion-tax-review.md) | pricing, promotion |
| Promotion Service (detailed) | [promotion-service-review.md](promotion-service-review.md) | promotion |

### Fulfillment & Logistics

| Flow | Canonical File | Services Covered |
|------|---------------|------------------|
| Fulfillment & Shipping | [fulfillment-shipping-review.md](fulfillment-shipping-review.md) | fulfillment, shipping |
| Inventory & Warehouse | [inventory-warehouse-review.md](inventory-warehouse-review.md) | warehouse |

### Customer & Identity

| Flow | Canonical File | Services Covered |
|------|---------------|------------------|
| Customer & Identity | [customer-identity-review-2026-03-07.md](customer-identity-review-2026-03-07.md) | auth, user, customer, loyalty-rewards |
| Seller & Merchant | [seller-merchant-review.md](seller-merchant-review.md) | catalog (seller) |

### Returns & Refunds

| Flow | Canonical File | Services Covered |
|------|---------------|------------------|
| Return & Refund | [return-refund-review.md](return-refund-review.md) | return, payment |

### Operations & Intelligence

| Flow | Canonical File | Services Covered |
|------|---------------|------------------|
| Admin & Operations | [admin-operations-review.md](admin-operations-review.md) | admin, common-operations, analytics |
| Analytics & Reporting | [analytics-reporting-review.md](analytics-reporting-review.md) | analytics |
| Notification | [notification-flow-review.md](notification-flow-review.md) | notification |

### Cross-Cutting & Reference Trackers

| Flow | Canonical File | Purpose |
|------|---------------|---------|
| Consolidated Issue Ledger | [UNFIXED-ISSUES-CONSOLIDATED.md](UNFIXED-ISSUES-CONSOLIDATED.md) | **Canonical tracker** for all P0/P1/P2 status & fixes |
| Cross-Cutting Concerns | [cross-cutting-concerns-review.md](cross-cutting-concerns-review.md) | Latest cross-cutting findings across services |
| Cross-Cutting Template | [cross-cutting-concerns-template.md](cross-cutting-concerns-template.md) | **Reusable template** — copy for each new service audit |
| Common Package Architecture Review | [COMMON_PACKAGE_MEETING_REVIEW_2026-03-27.md](COMMON_PACKAGE_MEETING_REVIEW_2026-03-27.md) | Shared `common` library contract & hardening review |
| System Meeting Review (50000 Round) | [SYSTEM_MEETING_REVIEW_50000_ROUND_2026-03-21.md](SYSTEM_MEETING_REVIEW_50000_ROUND_2026-03-21.md) | System-wide deep-dive agenda, risk queue, and execution gates |
| Legacy Consolidated Redirect | [remaining-issues-consolidated.md](remaining-issues-consolidated.md) | Superseded pointer redirecting to `UNFIXED-ISSUES-CONSOLIDATED.md` |

---

## How to Use

1. **Before reviewing a flow**: Read the canonical file listed above
2. **Run cross-cutting checks**: Use [cross-cutting-concerns-template.md](cross-cutting-concerns-template.md) alongside each flow review
3. **After fixing issues**: Update the canonical file — mark items `✅ FIXED` with date, and keep [UNFIXED-ISSUES-CONSOLIDATED.md](UNFIXED-ISSUES-CONSOLIDATED.md) synchronized
4. **Do NOT create `-v2`/`-v3` files**: Update the canonical file in-place. Use git history for versioning.

---

## Archive

Superseded review files, completed `archive/agent-tasks/`, and historical service snapshots (`archive/service-snapshots-2026-03-22/`) are in [`archive/`](archive/). These are kept for historical reference only. **Do not use archived files as source of truth** — they may contain stale status data.
