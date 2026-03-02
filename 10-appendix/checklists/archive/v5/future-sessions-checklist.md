# 📋 Future Sessions Checklist
> **Created**: 2026-02-14  
> **Source**: Remaining items from `master-checklist.md` (Phases 3–6) + `session-handoff-checklist.md` (Common Library adoption)  
> **Priority**: Ordered by business impact

---

## 1. 🔄 Common Library Adoption (~20h)
> **Goal**: Migrate services từ local implementations sang `common/outbox` + `common/idempotency` (v1.10.0+)
> **Why**: Giảm ~900 dòng duplicate, unified patterns, dễ maintain

### 1.1 Adopt `common/outbox`
| # | Service | Current State | Action | Effort | Status |
|---|---------|--------------|--------|--------|--------|
| 1.1.1 | `loyalty-rewards` | Local `OutboxEvent` + `OutboxRepo` + `OutboxEventPublisher` | Migrate to `common/outbox.GormRepository` + `outbox.Worker` | 3h | `[ ]` |
| 1.1.2 | `return` | Local `OutboxEvent` + `OutboxRepo` + outbox worker | Migrate to `common/outbox.GormRepository` + `outbox.Worker` | 3h | `[ ]` |
| 1.1.3 | `fulfillment` | Local `events/outbox_publisher.go` | Verify existing impl matches common, migrate if needed | 2h | `[ ]` |
| 1.1.4 | `order` | No outbox for order state events | Consider adding `common/outbox` for high-volume order events | 4h | `[ ]` |
| 1.1.5 | `warehouse` | No outbox for inventory events | Consider adding `common/outbox` for stock update events | 3h | `[ ]` |
| 1.1.6 | `shipping` | No outbox for tracking events | Consider adding `common/outbox` for frequent tracking updates | 3h | `[ ]` |

### 1.2 Adopt `common/idempotency`
| # | Service | Current State | Action | Effort | Status |
|---|---------|--------------|--------|--------|--------|
| 1.2.1 | `warehouse` | Local `IdempotencyHelper` in `eventbus/idempotency.go` | Migrate to `common/idempotency.GormIdempotencyHelper` | 2h | `[ ]` |
| 1.2.2 | `loyalty-rewards` | No idempotency on consumers | Add `common/idempotency.GormIdempotencyHelper` | 2h | `[ ]` |
| 1.2.3 | `return` | No idempotency on consumers | Add `common/idempotency.GormIdempotencyHelper` | 2h | `[ ]` |
| 1.2.4 | `fulfillment` | Unknown | Verify + add `GormIdempotencyHelper` | 2h | `[ ]` |
| 1.2.5 | `shipping` | Has idempotency (local) | Verify or migrate to `common/idempotency` | 1h | `[ ]` |
| 1.2.6 | `search` | Has `EventIdempotencyRepo` (local) | Verify or migrate to `common/idempotency` | 1h | `[ ]` |

### 1.3 Extract to `common` (new packages)
| # | Pattern | Current Location | Reason | Effort | Status |
|---|---------|-----------------|--------|--------|--------|
| 1.3.1 | `GeoIPService` | `payment/biz/fraud/geoip_service.go` | Reusable: analytics geo segmentation, notification locale | 3h | `[ ]` |
| 1.3.2 | `OutboxSaver` interface pattern | `loyalty-rewards/biz/events/outbox_publisher.go` | Standardize interface across services | 2h | `[ ]` |
| 1.3.3 | Aggregation query builder | `analytics/service/aggregation_service.go` | Complex SQL patterns → helper | 4h | `[ ]` |

---

## 2. ⚡ CI/CD Pipeline (Phase 3.2, ~8h)
> **Goal**: Auto lint + test trên mỗi PR

| # | Task | Scope | Effort | Status |
|---|------|-------|--------|--------|
| 2.1 | Add `golangci-lint` to GitLab CI (auto lint trên mỗi PR) | All services | 2h | `[ ]` |
| 2.2 | Add auto test runner to GitLab CI (`go test ./...` on PR) | All services | 4h | `[ ]` |
| 2.3 | Create Makefile/Taskfile for proto generation (`task proto:gen service=X`) | All services | 2h | `[ ]` |

---

## 3. 🔧 Service Consolidation (Phase 4, ~36h)
> **Goal**: Giảm 19 → 14-15 services, giảm operational complexity ~40%

### 3.1 Merge Auth + User → Identity
| # | Task | Effort | Status |
|---|------|--------|--------|
| 3.1.1 | Merge User model + Auth logic vào Identity service | 8h | `[ ]` |
| 3.1.2 | Update all gRPC clients pointing to auth/user → identity | 4h | `[ ]` |
| 3.1.3 | Consolidate DB migrations | 2h | `[ ]` |
| 3.1.4 | Update GitOps (remove user deployment, rename auth → identity) | 2h | `[ ]` |

### 3.2 Merge Analytics + Review → Insights
| # | Task | Effort | Status |
|---|------|--------|--------|
| 3.2.1 | Merge Review biz + data layer vào Insights service | 6h | `[ ]` |
| 3.2.2 | Replace stub Review clients bằng internal function calls | 2h | `[ ]` |
| 3.2.3 | Consolidate DB + GitOps | 4h | `[ ]` |

### 3.3 Location → Common Lib
| # | Task | Effort | Status |
|---|------|--------|--------|
| 3.3.1 | Convert location data thành shared lookup table / embed trong Gateway | 4h | `[ ]` |
| 3.3.2 | Remove Location service deployment | 1h | `[ ]` |

### 3.4 Replace Remaining Stub Clients
| # | Task | Service | Effort | Status |
|---|------|---------|--------|--------|
| 3.4.1 | Replace `stubUserClient` + `stubCatalogClient` bằng real gRPC | Review | 3h | `[ ]` |

### 3.5 Optional Merges (evaluate later)
| Merge | Risk | Benefit |
|-------|------|---------|
| Catalog + Pricing | Medium | -1 service, pricing logic gần product |
| Fulfillment + Shipping | Medium | -1 service, eliminate event hop |
| Common-Operations → merge vào relevant services | Low | -1 service |

---

## 4. 📋 Remaining Backlog (Phase 6)

| # | Task | Service | Effort | Status |
|---|------|---------|--------|--------|
| 4.1 | Implement FedEx/UPS/DHL carriers for international shipping | Shipping | 16h/each | `[ ]` |

---

## 5. 🚀 Long-term Improvements

### 5.1 Event Registry + Code Gen
Tạo `event-registry.yaml` chứa all event definitions → auto-gen publisher/consumer/outbox/idempotency code + validate contract completeness.  
**Effort**: ~16h setup | **Benefit**: tiết kiệm ~4h/service cho mỗi event mới

### 5.2 Return Service — Consumer Idempotency
| Event | Publisher | Idempotent | TODO |
|-------|----------|------------|------|
| `return.requested` | Return | ❌ | Add idempotency |
| `return.approved` | Return | ❌ | Add idempotency |
| `return.completed` | Return | ❌ | Add idempotency |

---

## Summary

| Section | Items | Effort | Priority |
|---------|-------|--------|----------|
| **1. Common Adoption** | 15 tasks | ~20h | 🔴 High — reduces duplicate code |
| **2. CI/CD** | 3 tasks | ~8h | 🔴 High — catches issues early |
| **3. Consolidation** | 8 tasks | ~36h | 🟡 Medium — reduces ops complexity |
| **4. Backlog** | 1 task | ~48h | 🟢 Low — when international shipping needed |
| **5. Long-term** | 2 areas | ~20h | 🟢 Low — strategic |
| **Total** | **~29 tasks** | **~132h** | |
