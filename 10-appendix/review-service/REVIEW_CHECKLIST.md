# 🔍 Service Review Checklist — All Services

**Date**: 2026-03-07
**Total Services**: 22 (21 Go backend + gateway)
**Review Strategy**: 5 parallel agents, grouped by deploy wave order

---

## 🚀 Agent Task Assignments

### 🟢 Agent 1 — Leaf & Foundation (Wave 0–1) — 4 services

> **Scope**: Shared library + leaf services with zero upstream dependencies.
> **Priority**: Must complete `common` review & tagging FIRST — all other agents depend on it.

| # | Service | Dir | Wave | Dependencies | Review Status |
|---|---------|-----|------|--------------|:---:|
| 1 | **common** | `common/` | 0 | _(base library)_ | ✅ Done — [review](common-review-checklist.md) |
| 2 | **notification** | `notification/` | 1 | common | ⬜ TODO |
| 3 | **analytics** | `analytics/` | 1 | common | ⬜ TODO |
| 4 | **user** | `user/` | 1 | common | ⬜ TODO |

**Agent 1 Steps**:
1. `git pull` for common, notification, analytics, user, gitops
2. Review `common` → fix P0/P1 → lint/build/test → tag `common` new version
3. Review `notification` → fix P0/P1 → update deps → lint/build/test → docs
4. Review `analytics` → fix P0/P1 → update deps → lint/build/test → docs
5. Review `user` → fix P0/P1 → update deps → lint/build/test → docs
6. Update `TEST_COVERAGE_CHECKLIST.md` for all 4 services
7. Commit & push all changes

---

### 🟡 Agent 2 — Core Domain (Wave 2–3) — 5 services

> **Scope**: Authentication, customer management, payment, and commerce routing.
> **Cross-dep note**: `auth ↔ customer` have mutual dependencies — review impact together.

| # | Service | Dir | Wave | Dependencies | Review Status |
|---|---------|-----|------|--------------|:---:|
| 5 | **auth** | `auth/` | 2 | common, customer, user | ⬜ TODO |
| 6 | **customer** | `customer/` | 2 | common, auth, notification, order, payment | ⬜ TODO |
| 7 | **payment** | `payment/` | 2 | common, customer, order | ⬜ TODO |
| 8 | **shipping** | `shipping/` | 3 | common, catalog, fulfillment | ⬜ TODO |
| 9 | **location** | `location/` | 3 | common, shipping, user, warehouse | ⬜ TODO |

**Agent 2 Steps**:
1. `git pull` for auth, customer, payment, shipping, location, gitops
2. Review `auth` → fix P0/P1 → update deps → lint/build/test → docs
3. Review `customer` → fix P0/P1 → update deps → lint/build/test → docs
4. Review `payment` → fix P0/P1 (idempotency race condition!) → update deps → lint/build/test → docs
5. Review `shipping` → fix P0/P1 → update deps → lint/build/test → docs
6. Review `location` → fix P0/P1 → update deps → lint/build/test → docs
7. Cross-service impact: auth ↔ customer proto compatibility
8. Update `TEST_COVERAGE_CHECKLIST.md` for all 5 services
9. Commit & push all changes

---

### 🟠 Agent 3 — Commerce & Catalog (Wave 3–5) — 4 services

> **Scope**: Product catalog, inventory, pricing, and reviews — the commerce backbone.
> **Cross-dep note**: `catalog ↔ warehouse` have circular dependency — review together.

| # | Service | Dir | Wave | Dependencies | Review Status |
|---|---------|-----|------|--------------|:---:|
| 10 | **pricing** | `pricing/` | 3 | common, catalog, customer, warehouse | ⬜ TODO |
| 11 | **catalog** | `catalog/` | 4 | common, customer, pricing, promotion, warehouse | ⬜ TODO |
| 12 | **warehouse** | `warehouse/` | 4 | common, catalog, common-operations, location, notification, user | ⬜ TODO |
| 13 | **review** | `review/` | 5 | common, catalog, order, user | ⬜ TODO |

**Agent 3 Steps**:
1. `git pull` for pricing, catalog, warehouse, review, gitops
2. Review `pricing` → fix P0/P1 (financial calculations!) → update deps → lint/build/test → docs
3. Review `catalog` → fix P0/P1 → update deps → lint/build/test → docs
4. Review `warehouse` → fix P0/P1 → update deps → lint/build/test → docs
5. Review `review` → fix P0/P1 → update deps → lint/build/test → docs
6. Cross-service impact: catalog ↔ warehouse ↔ pricing circular deps
7. Update `TEST_COVERAGE_CHECKLIST.md` for all 4 services
8. Commit & push all changes

---

### 🔴 Agent 4 — Order & Fulfillment (Wave 5–6) — 4 services

> **Scope**: Order processing pipeline — order lifecycle, promotions, fulfillment, returns.
> **Critical note**: `order` is the most complex service (10 dependencies). Pay extra attention.

| # | Service | Dir | Wave | Dependencies | Review Status |
|---|---------|-----|------|--------------|:---:|
| 14 | **order** | `order/` | 5 | common, catalog, customer, notification, payment, pricing, promotion, shipping, user, warehouse | ⬜ TODO |
| 15 | **promotion** | `promotion/` | 5 | common, catalog, customer, pricing, review, shipping | ⬜ TODO |
| 16 | **fulfillment** | `fulfillment/` | 6 | common, catalog, shipping, warehouse | ⬜ TODO |
| 17 | **return** | `return/` | 6 | common, order, payment, shipping, warehouse | ⬜ TODO |

**Agent 4 Steps**:
1. `git pull` for order, promotion, fulfillment, return, gitops
2. Review `order` → fix P0/P1 (double reservation, test failures!) → update deps → lint/build/test → docs
3. Review `promotion` → fix P0/P1 (compile failures!) → update deps → lint/build/test → docs
4. Review `fulfillment` → fix P0/P1 → update deps → lint/build/test → docs
5. Review `return` → fix P0/P1 → update deps → lint/build/test → docs
6. Cross-service impact: order ↔ customer ↔ promotion circular deps
7. Update `TEST_COVERAGE_CHECKLIST.md` for all 4 services
8. Commit & push all changes

---

### 🟣 Agent 5 — Growth, Ops & Edge (Wave 6–8) — 5 services

> **Scope**: Search, loyalty, operations, checkout orchestrator, and API gateway.
> **Critical note**: `gateway` depends on ALL upstream services — review last.

| # | Service | Dir | Wave | Dependencies | Review Status |
|---|---------|-----|------|--------------|:---:|
| 18 | **search** | `search/` | 6 | common, catalog, pricing, warehouse | ⬜ TODO |
| 19 | **loyalty-rewards** | `loyalty-rewards/` | 6 | common, customer, notification, order | ⬜ TODO |
| 20 | **common-operations** | `common-operations/` | 6 | common, customer, notification, order, user, warehouse | ⬜ TODO |
| 21 | **checkout** | `checkout/` | 7 | common, catalog, customer, order, payment, pricing, promotion, shipping, warehouse | ⬜ TODO |
| 22 | **gateway** | `gateway/` | 8 | common + all upstream services | ⬜ TODO |

**Agent 5 Steps**:
1. `git pull` for search, loyalty-rewards, common-operations, checkout, gateway, gitops
2. Review `search` → fix P0/P1 → update deps → lint/build/test → docs
3. Review `loyalty-rewards` → fix P0/P1 (financial liability!) → update deps → lint/build/test → docs
4. Review `common-operations` → fix P0/P1 → update deps → lint/build/test → docs
5. Review `checkout` → fix P0/P1 → update deps → lint/build/test → docs
6. Review `gateway` → fix P0/P1 → verify all routing → update deps → lint/build/test → docs
7. Update `TEST_COVERAGE_CHECKLIST.md` for all 5 services
8. Commit & push all changes

---

## 📋 Per-Agent Review Process (follow review-service skill)

Each agent MUST follow the **full review-service skill** (Steps 0–10):

```
Step 0:  git pull (service, common, gitops)
Step 1:  Index & Review codebase → list P0/P1/P2 issues
Step 2:  Cross-Service Impact Analysis (proto, events, go.mod)
Step 3:  Create review checklist → docs/10-appendix/review-service/<serviceName>-review-checklist.md
Step 4:  Action Plan → fix P0/P1 bugs immediately
Step 5:  Test Coverage → run coverage, update TEST_COVERAGE_CHECKLIST.md
Step 6:  Dependencies → update go.mod, remove replace, go mod tidy
Step 7:  Lint & Build → make api, wire, golangci-lint, go build, go test
Step 8:  Deployment Readiness → verify ports, config, GitOps alignment
Step 9:  Documentation → update service doc, README.md, CHANGELOG.md
Step 10: Commit & Release → commit with conventional format, tag if releasing
```

**Standards to read first**:
- `docs/07-development/standards/coding-standards.md`
- `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md`
- `docs/07-development/standards/development-review-checklist.md`

---

## 📊 Previous Review Findings (Baseline)

### 🔴 Known P0 Issues

| Issue | Services | Status |
|-------|----------|--------|
| Low test coverage (<60% biz) | All 17 reviewed | ⬜ Fix during review |
| Payment idempotency race condition | payment | ✅ Fixed |
| Customer domain leakage (model→proto) | customer | ✅ Fixed |

### 🟡 Known P1 Issues

| Issue | Services | Status |
|-------|----------|--------|
| N+1 Preload queries | customer, warehouse | ✅ Fixed (Joins) |
| Offset-based pagination | 12 services | ✅ Cursor methods added (repo layer) |
| Missing traceparent in outbox | order/common | ✅ Fixed |

### ✅ Previously Completed

| Action | Scope |
|--------|-------|
| Vendor sync `common@v1.19.0` | All 17 services |
| `go mod tidy && go mod vendor` | All 17 services |
| `golangci-lint run` clean | 16/17 (catalog: 2 minor) |
| `go build ./...` pass | All 17 services |
| Fixed `TransactionFunc` mock type | shipping (3 files), order (7+ files) |
| GitOps/port alignment verified | All 17 services |
| Preload→Joins (customer, warehouse) | 2 services |
| Cursor pagination (repo layer) | 10 services |
| Outbox traceparent propagation | common/outbox |
| README verification | All target services |

---

## 🔄 Services Not Previously Reviewed

The following services were not in the original 17-service review and need **full first-time review**:

| Service | Wave | Notes |
|---------|------|-------|
| **common** | 0 | Shared library — review for API stability, breaking changes |
| **common-operations** | 6 | Operations tooling service |
| **checkout** | 7 | High-complexity orchestrator (9 deps) |
| **return** | 6 | Order return lifecycle |
| **gateway** | 8 | API gateway — routing, security, rate limiting |

---

*Last Updated: 2026-03-07*
*Strategy: 5 parallel agents × review-service skill (Steps 0–10)*
