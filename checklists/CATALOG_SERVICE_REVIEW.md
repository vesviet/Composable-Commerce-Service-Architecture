# 📦 CATALOG SERVICE REVIEW

**Review Date**: January 17, 2026  
**Reviewer**: Principal Developer (Cascade)  
**Service**: Catalog (Product Catalog + CMS)  
**Score**: 9.0/10  
**Issues**: 3 (P1: 1, P2: 2)  
**Est. Fix Time**: ~4-8 hours

---

## 📋 Executive Summary

Catalog service nhìn chung **đã production-ready** và là **reference implementation tốt** cho:
- Transactional Outbox (DB + event atomic)
- Cache invalidation theo event
- OpenAPI exposure (`/docs/`, `/docs/openapi.yaml`)

Tuy nhiên tài liệu review hiện tại đang **outdated ở một số điểm**, đặc biệt:
- P1-1 (missing metrics/tracing middleware) thực tế đã **được implement** trong `internal/server/http.go`.
- P1-2 (worker concurrency patterns) cần **update lại theo implementation thật** (worker đã có tracing + metrics nhưng còn điểm cần chỉnh).

---

## ✅ What’s Excellent

### 1) Transactional Outbox Pattern - IMPLEMENTED ✅
**Status**: Production-ready | **Impact**: Event atomic, không mất event khi crash

**Location**: `internal/biz/product/product_write.go`
- `CreateProduct`, `UpdateProduct`, `DeleteProduct` đều wrap trong `uc.tm.InTx(...)` và tạo outbox event `PENDING` trong cùng transaction.

**Rubric**: ✅ Data Layer & Persistence (transaction boundaries)

### 2) HTTP Observability Middleware - PRESENT ✅
**Location**: `catalog/internal/server/http.go`
- `metrics.Server()` và `tracing.Server()` đã có trong middleware stack.

**Rubric**: ✅ Observability

### 3) Health endpoints + dependency checks ✅
**Location**: `catalog/internal/server/http.go`
- `/health`, `/health/ready`, `/health/live`, `/health/detailed`
- readiness check có DB + Redis hooks

### 4) OpenAPI + Swagger UI ✅
**Location**: `catalog/internal/server/http.go`
- Swagger UI: `/docs/`
- OpenAPI spec: `/docs/openapi.yaml` (được expose để gateway aggregate)

### 5) Product event pipeline tương đối đầy đủ ✅
**Location**: `internal/biz/product/product_write.go` + `internal/worker/outbox_worker.go`
- Worker xử lý các event `product.created|updated|deleted`, trigger:
  - refresh materialized views (async)
  - cache invalidation (best effort)
  - publish events (topic có `catalog.product.updated`)
  - indexing ES (nếu bật)

---

## 🚨 Issues Found

### P1-1: gRPC server missing standard metrics/tracing middleware (P1)
**Severity**: 🟡 HIGH  
**Location**: `catalog/internal/server/grpc.go`

**Current state**:
- gRPC middleware chỉ có:
  - `recovery.Recovery()`
  - `metadata.Server()`

**Impact**:
- HTTP có metrics/tracing nhưng gRPC **không có** → trace/metrics bị đứt đoạn nếu internal traffic dùng gRPC.

**Fix**:
- Add:
  - `metrics.Server()`
  - `tracing.Server()`

**Success criteria**:
- [ ] Jaeger có span cho gRPC calls
- [ ] Prometheus có metrics cho gRPC handlers (nếu collector đang scrape)

---

### P2-1: `/metrics` endpoint handler không expose real Prometheus handler (P2)
**Severity**: 🟠 MEDIUM  
**Location**: `catalog/internal/server/http.go`

**Current state**:
- `/metrics` handler trả về `200 text/plain` nhưng body rỗng.
- Middleware `metrics.Server()` **thu metrics** nhưng endpoint này không render metrics theo Prometheus exposition format.

**Impact**:
- Prometheus scrape `/metrics` sẽ không thu được dữ liệu như kỳ vọng (trừ khi hệ thống scrape theo cách khác).

**Recommendation**:
- Dùng `promhttp.Handler()` (client_golang) hoặc endpoint chuẩn từ stack observability chung.

**Success criteria**:
- [ ] `curl /metrics` trả về metrics lines có `http_`/`kratos_`/custom metrics

---

### P2-2: Outbox worker concurrency + backoff chưa đạt best practice (P2)
**Severity**: 🟠 MEDIUM  
**Location**: `catalog/internal/worker/outbox_worker.go`

**Findings**:
- Có:
  - graceful stop theo `ctx.Done()` ✅
  - tracing span per event ✅
  - prometheus counters (processed/failed) ✅
  - retry counter theo DB (`RetryCount`) ✅
- Thiếu/Chưa rõ:
  - backoff theo `RetryCount` (hiện poll interval fixed 1s)
  - bounded concurrency (hiện xử lý tuần tự; không xấu, nhưng throughput hạn chế)
  - DLQ rõ ràng: hiện dùng `FAILED` status như DLQ đơn giản (OK), nhưng thiếu mô tả/cleanup/alerting

**Recommendation**:
- Nếu muốn throughput cao hơn:
  - dùng `errgroup.WithContext` + `SetLimit(N)` để bounded parallel processing
  - implement backoff per event khi retry (vd exponential) hoặc tăng interval khi lỗi hệ thống

**Success criteria**:
- [ ] Không goroutine leak
- [ ] Retry/backoff predictable
- [ ] FAILED events có dashboard/alert

---

## 📊 Rubric Compliance Matrix (Updated)

| Rubric Item | Score | Status | Notes |
|-------------|-------|--------|-------|
| 1️⃣ Architecture & Clean Code | 9/10 | ✅ | Layers rõ ràng, outbox + worker hợp lý |
| 2️⃣ API & Contract | 9/10 | ✅ | Kratos HTTP + gRPC registration chuẩn |
| 3️⃣ Business Logic & Concurrency | 8/10 | 🟡 | Worker còn thiếu backoff/concurrency best practice |
| 4️⃣ Data Layer & Persistence | 10/10 | ✅ | Transactional outbox chuẩn |
| 5️⃣ Security | 8/10 | 🟡 | Cần rà thêm input validation/PII logging theo endpoint (ngoài scope đọc nhanh) |
| 6️⃣ Performance & Scalability | 9/10 | ✅ | ES indexing + views refresh hooks |
| 7️⃣ Observability | 8/10 | 🟡 | HTTP ok, gRPC missing tracing/metrics; /metrics endpoint handler rỗng |
| 8️⃣ Testing & Quality | 8/10 | 🟡 | Có unit test `product_write_test.go`, cần thêm integration e2e |
| 9️⃣ Configuration & Resilience | 8/10 | 🟡 | Worker retry/backoff + DLQ policy cần doc |
| 🔟 Documentation & Maintenance | 9/10 | ✅ | OpenAPI + health docs tốt |

---

## ✅ Updated Implementation Roadmap

### Phase 1 (P1): Add gRPC metrics + tracing middleware (1-2h)
- [ ] Update `catalog/internal/server/grpc.go`
- [ ] Verify traces in Jaeger

### Phase 2 (P2): Fix `/metrics` endpoint to actually expose metrics (1-2h)
- [ ] Replace placeholder handler with Prometheus handler
- [ ] Verify Prometheus scrape

### Phase 3 (P2): Improve outbox worker retry/backoff (2-4h)
- [ ] Add backoff strategy and/or bounded concurrency
- [ ] Document FAILED/DLQ semantics

---

## 🔍 Code Locations

- `catalog/internal/server/http.go` (HTTP server, swagger, health, metrics/tracing middleware)
- `catalog/internal/server/grpc.go` (gRPC server)
- `catalog/internal/biz/product/product_write.go` (transactional outbox + product side effects)
- `catalog/internal/worker/outbox_worker.go` (outbox processing)
- `catalog/cmd/worker/main.go` (worker bootstrap)

---

## 📝 Checklist

**Review complete when**:
- [x] HTTP middleware verified (metrics + tracing)
- [x] Outbox TX verified
- [x] Worker implementation checked vs doc
- [ ] gRPC middleware updated (P1)
- [ ] /metrics endpoint fixed (P2)

---

**Document Version**: 1.1  
**Last Updated**: January 17, 2026  
wp-blog-header.php