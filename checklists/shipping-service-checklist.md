# 🚚 SHIPPING SERVICE – END-TO-END CODE REVIEW (2026-01-17)

**Service Path**: `shipping/`

**Reviewer**: Senior Tech Lead (Cascade)

**Reference Standard**: [TEAM_LEAD_CODE_REVIEW_GUIDE.md](./TEAM_LEAD_CODE_REVIEW_GUIDE.md)

---

## 📊 EXECUTIVE SUMMARY

| Area | Score | Notes |
|------|-------|-------|
| Architecture & Design | **85 %** | Clean layering, DI via Wire. Minor repo/domain coupling. |
| API Design | **80 %** | gRPC + HTTP gateway, Swagger exposed; needs richer error mapping. |
| Business Logic | **75 %** | Core flows solid; race conditions & partial outbox usage. |
| Data Layer | **80 %** | Repo pattern, migrations OK, no optimistic-lock column. |
| Security | **78 %** | Validation OK; secret management & webhook sig need work. |
| Performance | **80 %** | Indexes present; no CB/timeouts for carrier. |
| Observability | **65 %** | Tracing + logging present, metrics middleware missing. |
| Testing | **60 %** | Unit tests sparse; no e2e against carrier sandboxes. |
| Configuration & Resilience | **80 %** | YAML + env overrides; no circuit breaker. |
| Documentation | **70 %** | README OK, ADRs & sequence diagrams missing. |
| **Overall** | **76 %** | Near-ready after P0/P1 fixes. |

---

## ✅ STRENGTHS
- **Clean Architecture** (biz/data/service) with Wire DI.
- **Transactional Outbox** implemented for *CreateShipment* flow; outbox table & worker present.
- **Comprehensive status enum & validation** prevents invalid transitions.
- **Label generation adapters** for UPS/FedEx/DHL already integrated.
- **Health, Swagger, Tracing middleware** enabled; Prometheus endpoint easy to add.
- **Migrations** cover outbox, tracking events, shipping methods.

---

## 🔴 P0 — CRITICAL ISSUES (must fix before prod)

| ID | Description | Impact | Fix Hint |
|----|-------------|--------|----------|
| C1 | **Duplicate shipment creation race**: `CreateShipment` checks existing then inserts; no DB unique constraint on `(fulfillment_id)` or `(order_id, carrier)`. | Multiple shipments for same fulfillment/order – inventory & billing errors. | Add UNIQUE index + handle `23505` conflict (return existing). |
| C2 | **Partial Outbox adoption**: status changes & delivery confirm publish directly via `eventBus` (best-effort). Broker outage ⇒ lost events. | Downstream services (tracking, analytics) inconsistent. | Replace direct publish with `outboxRepo.Save()` inside same transaction; worker pushes. |

---

## ⚠️ P1 — HIGH PRIORITY

| ID | Area | Description | Evidence |
|----|------|-------------|----------|
| H1 | Observability | HTTP server lacks `metrics.Server()` → no RED metrics. | `internal/server/http.go` middleware list |
| H2 | Concurrency | `UpdateShipment`, `UpdateShipmentStatus` read-modify-write with no optimistic lock ⇒ overwrite races. | `shipment_usecase.go` |
| H3 | Carrier Integration | Adapters call carrier APIs without `context.WithTimeout` or circuit breaker. | `internal/biz/carrier/*` |
| H4 | Secrets | `configs/config.yaml` contains sandbox API keys. | config file |
| H5 | Testing | Unit tests coverage ≈ 15 %; no integration tests with carrier sandbox. | `internal/biz/shipment` has *_test.go* none |

---

## 🟡 P2 — MEDIUM PRIORITY
- Missing Prometheus business counters (shipments_created, shipped, delivered).
- Tracking events stored in JSONB; consider separate table for query performance.
- `AssignShipment` logic could simplify & clarify allowed statuses.
- README lacks sequence diagrams (Package → Shipment → Carrier).

---

## 🔍 HIDDEN RISKS
| ID | Priority | Area | Description | Evidence |
|----|----------|------|-------------|----------|
| HR1 | P1 | Outbox Adoption | Status changes (`UpdateShipment`, `UpdateShipmentStatus`, `ConfirmDelivery`) vẫn publish event trực tiếp qua `eventBus` thay vì lưu **outbox** → mất event nếu broker down. | `shipment_usecase.go` publish after repo.Update |
| HR2 | P1 | Metrics | HTTP server thiếu `metrics.Server()` middleware, không expose Prometheus RED metrics. | `internal/server/http.go` middleware list |
| HR3 | P1 | Optimistic Lock | Repo không có `version` field; Update read-then-write ⇒ race conditions. | `shipment_usecase.go` & repo Update |
| HR4 | P2 | Carrier Timeout/Circuit Breaker | Carrier adapters (`internal/biz/carrier/*`) không wrap calls với `context.WithTimeout` hay circuit breaker. | grep `httpClient.Do` in carrier dirs |
| HR5 | P2 | Secrets | `configs/config.yaml` chứa sandbox carrier API keys, nên move to K8s Secrets / Vault. | `configs/config.yaml` |

---

## 🗺 ACTION PLAN

### Sprint 1 (Week 1) – P0 fixes  (≈ 10 h)
1. Add UNIQUE index on `shipments(fulfillment_id)`; handle duplicate on insert. (3 h)
2. Refactor `UpdateShipment*` publish flow to use outbox in-tx; update worker. (5 h)
3. Add Prometheus middleware + basic RED metrics. (2 h)

### Sprint 2 (Week 2) – Concurrency & Carrier hardening (≈ 12 h)
1. Add `version` column, GORM optimistic-lock tag; adjust updates. (4 h)
2. Wrap carrier HTTP calls with `context.WithTimeout` (30 s) & `gobreaker`. (4 h)
3. Move carrier secrets to Vault / K8s Secret, load via env. (4 h)

### Sprint 3 (Week 3) – Observability & Tests (≈ 14 h)
1. Implement business metrics counters/histograms + Grafana dashboard. (4 h)
2. Add unit tests to reach 60 %+ coverage of biz layer. (6 h)
3. Write e2e test with carrier sandbox via `testcontainers-go`. (4 h)

---

## 📈 METRICS & SLOs
- `shipments_created_total` counter
- `shipment_status_change_total{to="shipped"}`
- `shipment_processing_latency_seconds` histogram (create→shipped)

SLOs:
- 99.8 % of shipments moved to *shipped* within 30 min of package ready.
- Carrier API success rate > 99 % (5-min window).

---

## 📅 NEXT REVIEW
After Sprint 2 completion or P0 closure.  Reviewer: **Cascade**.
