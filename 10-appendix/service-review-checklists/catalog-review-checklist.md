# Catalog Service Review Checklist

**Date**: 2026-03-01
**Reviewer**: Service Review Process
**Service**: catalog
**Status**: ✅ Ready

## 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | — |
| P1 (High) | 1 | Fixed |
| P2 (Normal) | 3 | 1 Fixed / 2 Low-priority |

---

## 🔴 P0 Issues (Blocking)

None identified.

---

## 🟡 P1 Issues (High)

### P1-001: ~~Missing HPA Configuration~~ ✅ FIXED
- **File**: `gitops/apps/catalog/base/hpa.yaml`
- **Fix**: Created HPA with 2-5 replicas, CPU 75% / Memory 80% targets, sync-wave=5 (above deployment wave=3), conservative scale-down.
- **Status**: ✅ Created and added to kustomization.

### P1-002: Missing Deployment & Service YAML (using component pattern)
- **File**: `gitops/apps/catalog/base/kustomization.yaml`
- **Issue**: No standalone `deployment.yaml` or `service.yaml` — using `common-deployment-v2` and `common-worker-deployment-v2` components with inline patches. This is actually the **correct** pattern for this project (component-based Kustomize). Ports verified: HTTP=8015, gRPC=9015 match PORT_ALLOCATION_STANDARD.md.
- **Status**: ✅ Verified correct. Not an issue.

---

## 🔵 P2 Issues (Normal)

### P2-001: ~~`/metrics` endpoint returns empty response~~ ✅ FIXED
- **File**: `internal/server/http.go`
- **Fix**: Replaced empty placeholder handler with `promhttp.Handler().ServeHTTP` to properly serve Prometheus metrics. Vendored the `promhttp` package.
- **Status**: ✅ Fixed and verified.

### P2-002: `GetHealthStatus` returns hardcoded "healthy"
- **File**: `internal/biz/biz.go:74-83`
- **Issue**: `GetHealthStatus()` returns hardcoded `"healthy"` for database and redis dependencies instead of performing actual health checks. However, this is mitigated by the proper common health endpoints registered at `/health/*` in `http.go` (lines 147-163) which do real DB/Redis checks. The biz-level method is unused in production serving.
- **Status**: Low priority — real health checks exist at transport layer.

### P2-003: `NewEventHandler` duplicate handler construction
- **File**: `internal/service/events.go:71-74`
- **Issue**: `NewEventHandler` creates new `WarehouseStockUpdateHandler` and `PricingPriceUpdateHandler` instances directly, even though these are already created via Wire DI in `data/provider.go`. The EventHandler in the main binary gets separately-constructed handlers, while the worker binary uses Wire-injected ones. No functional issue, but inconsistent.
- **Status**: Low priority — handlers are stateless, dual construction is harmless.

---

## ✅ Architecture & Design Strengths

1. **Clean Architecture**: Proper separation — `biz/` (domain), `data/` (repository), `service/` (API), `server/` (transport)
2. **Dual-Binary Architecture**: `cmd/catalog/` (API server) + `cmd/worker/` (outbox, cron, event consumers) — correct separation of concerns
3. **Outbox Pattern**: Transactional outbox with `FetchAndMarkProcessing` (atomic claim), `ResetStuckProcessing` (recovery), and publish-then-mark-complete pattern prevents duplicate events
4. **Optimistic Locking**: Products use version-based optimistic locking for concurrent updates
5. **SKU Collision Lock**: Distributed lock via idempotency service prevents concurrent creation of same SKU
6. **Cache Strategy**: Multi-layer cache (L1→L2→DB) with event-driven invalidation via Dapr
7. **Elasticsearch Fallback**: ES search with circuit breaker and DB fallback
8. **Resilient gRPC Clients**: Circuit breaker + retry + exponential backoff for warehouse/pricing clients
9. **RBAC**: Uses `commonMiddleware.RequireRoleKratos("admin")` for write operations via selector middleware
10. **Cursor Pagination**: Uses `common/utils/pagination.CursorRequest` for scalable pagination
11. **EAV Attributes**: Tiered attribute system (Hot Attributes in flat columns + EAV for dynamic attributes)
12. **Audit Logging**: Async audit logging middleware for admin operations
13. **Rate Limiting**: Configurable rate limiting using common middleware
14. **Observability**: OpenTelemetry tracing, Prometheus metrics, structured logging

---

## 🌐 Cross-Service Impact

### Services that import catalog proto:
- checkout, fulfillment, gateway, order, pricing, promotion, review, search, shipping, warehouse (10 services)

### Services that consume catalog events:
- **search**: Consumes `catalog.product.created`, `catalog.product.updated`, `catalog.product.deleted`, `catalog.category.*`, `catalog.cms.*`

### Backward compatibility: ✅ Preserved
- No proto field removals detected
- Event schemas are additive-only
- No `replace` directives in go.mod

---

## 🚀 Deployment Readiness

| Check | Status |
|-------|--------|
| Ports match PORT_ALLOCATION_STANDARD.md (8015/9015) | ✅ |
| Config/GitOps aligned | ✅ |
| Health probes configured (common health package) | ✅ |
| Resource limits (via component template) | ✅ |
| Dapr annotations (via component template) | ✅ |
| NetworkPolicy | ✅ Present |
| PDB (API + Worker) | ✅ Present |
| ServiceMonitor | ✅ Present |
| Migration job | ✅ Present |
| HPA | ✅ Created |
| HPA sync-wave | N/A (no HPA) |

---

## Build Status

| Check | Status |
|-------|--------|
| `golangci-lint` | ✅ 0 warnings |
| `go build ./...` | ✅ |
| `go test ./...` | ✅ All pass |
| `wire` | ✅ Generated |
| No `replace` directives | ✅ |
| `common` version | ✅ v1.22.0 (latest) |
| Other deps (customer v1.2.3, pricing v1.2.0, promotion v1.2.0, warehouse v1.2.3) | ✅ |
| `bin/` directory | ✅ Not present |
| Generated files not modified manually | ✅ |

---

## Documentation

| Check | Status |
|-------|--------|
| Service doc (`docs/03-services/core-services/catalog-service.md`) | ✅ Present |
| `README.md` | ✅ Present (14.6KB) |
| `CHANGELOG.md` | ✅ Present (8.3KB) |
