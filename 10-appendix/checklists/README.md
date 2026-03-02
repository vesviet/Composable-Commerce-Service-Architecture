# Checklists & Review Documentation

Central directory for all review checklists, analysis reports, and issue trackers for the e-commerce microservices platform.

**Last reorganized**: 2026-03-02

---

## Directory Guide

### ✅ Active Directories

| Directory | Purpose | Files | Status |
|-----------|---------|-------|--------|
| [**workflow/**](workflow/README.md) | **Canonical workflow reviews** — data consistency, saga/outbox, events, edge cases, GitOps per business flow | 20 | ✅ Current (Feb-Mar 2026) |
| [**refactor/**](refactor/README.md) | Per-dimension technical analysis reports (DB, caching, security, GitOps, etc.) | 22 | ✅ Current (Mar 2026) |
| [**active/**](active/INDEX.md) | Legacy issue tracker (per-service `_issues.md` files) | 27 | ⚠️ Legacy (Jan 2026) — see deprecation notice |
| [**event-architecture/**](event-architecture/) | Event architecture reviews | 2 | ℹ️ Reference |
| [**test-case/**](test-case/README.md) | Test coverage matrix & quality reviews | 3 | ℹ️ Reference |
| [**gitops/**](gitops/) | GitOps review checklist | 1 | ℹ️ Reference |
| [**ops/**](ops/) | ArgoCD config audit | 1 | ℹ️ Reference |
| [**test/**](test/) | Test coverage checklist | 1 | ℹ️ Reference |

### 🗃️ Archive

| Directory | Contents | Reason |
|-----------|----------|--------|
| [archive/v5/](archive/v5/) | 35 files — earlier review generation (Jan 2026) | Superseded by `workflow/` |
| [archive/lastphase/](archive/lastphase/) | 11 files — deep business logic reviews (Feb 2026) | Superseded by `workflow/` |
| [archive/todo/](archive/todo/) | 5 files — implementation guides | Tasks completed |
| [archive/root-loose/](archive/root-loose/) | 3 files — orphan files | No directory assignment |
| [archive/](archive/) | 12 files — older workflow review versions | Superseded by renamed canonical files |

---

## How to Navigate

### "I want to review a business flow" → [`workflow/`](workflow/README.md)

Canonical reviews covering: Cart & Checkout, Order Lifecycle, Payment, Fulfillment & Shipping, Inventory, Catalog, Customer, Pricing, Promotion, Analytics, Notification, Search, Returns, Admin, Seller.

### "I want to audit a technical dimension across all services" → [`refactor/`](refactor/README.md)

Analysis reports on: DB transactions, pagination, caching, Dapr PubSub, workers, resilience, security, GitOps deployments, Kubernetes policies, observability.

### "I want to see historical issue lists" → [`active/`](active/INDEX.md)

Legacy per-service issue files from January 2026. Many issues have since been fixed. Check `workflow/` for current status.

---

## Review Workflow

1. **For a specific flow**: Read the canonical file in `workflow/` (see [workflow/README.md](workflow/README.md))
2. **Run cross-cutting checks**: Use [workflow/cross-cutting-concerns-template.md](workflow/cross-cutting-concerns-template.md)
3. **After fixing issues**: Update the canonical file in-place — mark items `✅ FIXED` with date
4. **Do NOT create `-v2`/`-v3` files**: Use git history for versioning
5. **For new analysis**: Add reports to appropriate existing directory, not new directories
