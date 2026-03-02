# Checklists & Review Documentation

Central directory for all review checklists, analysis reports, and issue trackers.

**Last reorganized**: 2026-03-02

---

## Directory Guide

### ✅ Active Directories

| Directory | Purpose | Files | Status |
|-----------|---------|-------|--------|
| [**workflow/**](workflow/README.md) | **Canonical workflow reviews** — data consistency, saga/outbox, events, edge cases per business flow | 20 | ✅ Current (Feb-Mar 2026) |
| [**refactor/**](refactor/README.md) | Per-dimension technical analysis reports (DB, caching, security, GitOps, etc.) | 22 | ✅ Current (Mar 2026) |
| [**active/**](active/INDEX.md) | Active issue trackers — security reviews, refactoring reviews, maturity audits | 10 | ✅ Current |
| [**event-architecture/**](event-architecture/) | Event architecture reviews | 2 | ℹ️ Reference |
| [**test-case/**](test-case/README.md) | Test coverage matrix & quality reviews | 3 | ℹ️ Reference |
| [**gitops/**](gitops/) | GitOps review checklist | 1 | ℹ️ Reference |
| [**ops/**](ops/) | ArgoCD config audit | 1 | ℹ️ Reference |
| [**test/**](test/) | Test coverage checklist | 1 | ℹ️ Reference |

---

## How to Navigate

### "I want to review a business flow" → [`workflow/`](workflow/README.md)

Canonical reviews covering: Cart & Checkout, Order Lifecycle, Payment, Fulfillment & Shipping, Inventory, Catalog, Customer, Pricing, Promotion, Analytics, Notification, Search, Returns, Admin, Seller.

### "I want to audit a technical dimension across all services" → [`refactor/`](refactor/README.md)

Analysis reports on: DB transactions, pagination, caching, Dapr PubSub, workers, resilience, security, GitOps deployments, Kubernetes policies, observability.

### "I want to see active issues and audits" → [`active/`](active/INDEX.md)

Current security reviews, maturity audits, and high-priority issue trackers.

---

## Review Workflow

1. **For a specific flow**: Read the canonical file in `workflow/`
2. **Run cross-cutting checks**: Use [workflow/cross-cutting-concerns-template.md](workflow/cross-cutting-concerns-template.md)
3. **After fixing issues**: Update the canonical file in-place — mark items `✅ FIXED` with date
4. **Do NOT create `-v2`/`-v3` files**: Use git history for versioning
5. **For new analysis**: Add reports to appropriate existing directory
