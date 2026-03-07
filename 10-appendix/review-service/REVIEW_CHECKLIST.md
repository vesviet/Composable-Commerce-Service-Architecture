# 🔍 Service Review Checklist — All Services

**Date**: 2026-03-07
**Total Services**: 22 (21 Go backend + gateway)
**Review Strategy**: 5 parallel agents, grouped by deploy wave order
**Common Status**: ✅ `v1.23.2` — committed, tagged, pushed (2026-03-07)
**Execution Mode**: All 5 agents run **in parallel** — common is done, no blocker

---

## 🚀 Agent Task Assignments

### 🟢 Agent 1 — Leaf & Foundation (Wave 0–1) — 3 services

> **Scope**: Leaf services with zero upstream dependencies.
> **Prereq**: ✅ `common@v1.23.2` is already tagged & pushed — proceed directly.

| # | Service | Dir | Wave | Dependencies | Review Status |
|---|---------|-----|------|--------------|:---:|
| 0 | **common** | `common/` | 0 | _(base library)_ | ✅ Done `v1.23.2` — [review](common-review-checklist.md) |
| 1 | **notification** | `notification/` | 1 | common | ⬜ TODO |
| 2 | **analytics** | `analytics/` | 1 | common | ⬜ TODO |
| 3 | **user** | `user/` | 1 | common | ⬜ TODO |

**Agent 1 Steps**:
1. `git pull` for notification, analytics, user
2. For each service: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
3. Review `notification` → follow review-service skill (Steps 0–10)
4. Review `analytics` → follow review-service skill (Steps 0–10)
5. Review `user` → follow review-service skill (Steps 0–10)
6. Update `TEST_COVERAGE_CHECKLIST.md` for all 3 services
7. Commit & push all changes (conventional commit format)

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
1. `git pull` for auth, customer, payment, shipping, location
2. For each service: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
3. Review `auth` → follow review-service skill (Steps 0–10)
4. Review `customer` → follow review-service skill (Steps 0–10)
5. Review `payment` → follow review-service skill (Steps 0–10) ⚠️ idempotency race condition!
6. Review `shipping` → follow review-service skill (Steps 0–10)
7. Review `location` → follow review-service skill (Steps 0–10)
8. Cross-service impact: auth ↔ customer proto compatibility
9. Update `TEST_COVERAGE_CHECKLIST.md` for all 5 services
10. Commit & push all changes (conventional commit format)

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
1. `git pull` for pricing, catalog, warehouse, review
2. For each service: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
3. Review `pricing` → follow review-service skill (Steps 0–10) ⚠️ financial calculations!
4. Review `catalog` → follow review-service skill (Steps 0–10)
5. Review `warehouse` → follow review-service skill (Steps 0–10)
6. Review `review` → follow review-service skill (Steps 0–10)
7. Cross-service impact: catalog ↔ warehouse ↔ pricing circular deps
8. Update `TEST_COVERAGE_CHECKLIST.md` for all 4 services
9. Commit & push all changes (conventional commit format)

---

### 🔴 Agent 4 — Order & Fulfillment (Wave 5–6) — 4 services

> **Scope**: Order processing pipeline — order lifecycle, promotions, fulfillment, returns.
> **Critical note**: `order` is the most complex service (10 dependencies). Pay extra attention.

| # | Service | Dir | Wave | Dependencies | Review Status |
|---|---------|-----|------|--------------|:---:|
| 14 | **order** | `order/` | 5 | common, catalog, customer, notification, payment, pricing, promotion, shipping, user, warehouse | ✅ Done — [review](order-review-checklist.md) |
| 15 | **promotion** | `promotion/` | 5 | common, catalog, customer, pricing, review, shipping | ✅ Done — [review](promotion-review-checklist.md) |
| 16 | **fulfillment** | `fulfillment/` | 6 | common, catalog, shipping, warehouse | ✅ Done — [review](fulfillment-review-checklist.md) |
| 17 | **return** | `return/` | 6 | common, order, payment, shipping, warehouse | ✅ Done — [review](return-review-checklist.md) |

**Agent 4 Steps**:
1. `git pull` for order, promotion, fulfillment, return
2. For each service: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
3. Review `order` → follow review-service skill (Steps 0–10) ⚠️ double reservation, test failures!
4. Review `promotion` → follow review-service skill (Steps 0–10) ⚠️ compile failures!
5. Review `fulfillment` → follow review-service skill (Steps 0–10)
6. Review `return` → follow review-service skill (Steps 0–10)
7. Cross-service impact: order ↔ customer ↔ promotion circular deps
8. Update `TEST_COVERAGE_CHECKLIST.md` for all 4 services
9. Commit & push all changes (conventional commit format)

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
1. `git pull` for search, loyalty-rewards, common-operations, checkout, gateway
2. For each service: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
3. Review `search` → follow review-service skill (Steps 0–10)
4. Review `loyalty-rewards` → follow review-service skill (Steps 0–10) ⚠️ financial liability!
5. Review `common-operations` → follow review-service skill (Steps 0–10)
6. Review `checkout` → follow review-service skill (Steps 0–10)
7. Review `gateway` → follow review-service skill (Steps 0–10) ⚠️ verify all routing!
8. Update `TEST_COVERAGE_CHECKLIST.md` for all 5 services
9. Commit & push all changes (conventional commit format)

---

## 📋 Per-Agent Review Process (follow review-service skill)

> **⚠️ IMPORTANT**: All 5 agents run **in parallel**. `common@v1.23.2` is already tagged & pushed.
> Each agent must update deps to `common@v1.23.2` as the **first step** for every service.

Each agent MUST follow the **full review-service skill** (Steps 0–10):

```
Step 0:  git pull (service repos assigned to this agent)
Step 1:  Update deps: go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy
Step 2:  Index & Review codebase → list P0/P1/P2 issues
Step 3:  Cross-Service Impact Analysis (proto, events, go.mod)
Step 4:  Create review checklist → docs/10-appendix/review-service/<serviceName>-review-checklist.md
Step 5:  Action Plan → fix P0/P1 bugs immediately
Step 6:  Test Coverage → run coverage, target >80% biz layer, update TEST_COVERAGE_CHECKLIST.md
Step 7:  Dependencies → verify no replace directives, go mod tidy
Step 8:  Lint & Build → make api, wire, golangci-lint run, go build ./..., go test ./...
Step 9:  Deployment Readiness → verify ports, config, GitOps alignment
Step 10: Documentation → update CHANGELOG.md, README.md
Step 11: Commit & Push → conventional commit format, follow commit-code skill
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

| Service | Wave | Agent | Notes |
|---------|------|-------|-------|
| ~~**common**~~ | 0 | — | ✅ Done `v1.23.2` |
| **common-operations** | 6 | Agent 5 | Operations tooling service |
| **checkout** | 7 | Agent 5 | High-complexity orchestrator (9 deps) |
| **return** | 6 | Agent 4 | Order return lifecycle |
| **gateway** | 8 | Agent 5 | API gateway — routing, security, rate limiting |

---

## 🔑 Common Package Summary (`v1.23.2`)

Completed before parallel agent execution:

| Item | Status |
|------|--------|
| P1: Transaction context key inconsistency | ✅ Fixed |
| P2: Regex compilation performance | ✅ Fixed |
| P2: Stale go.mod comments | ✅ Cleaned |
| Test coverage: 11 packages at 80%+ | ✅ Done |
| Lint: 0 warnings | ✅ Clean |
| Tag: `v1.23.2` | ✅ Pushed |
| Detailed review: [common-review-checklist.md](common-review-checklist.md) | ✅ Done |

---

*Last Updated: 2026-03-07 11:45*
*Strategy: 5 parallel agents × review-service skill — common@v1.23.2 unblocks all*
