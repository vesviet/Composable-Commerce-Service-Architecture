# Location Service - Logic Review Checklist

## 📋 Overview

This checklist documents findings from reviewing the Location Service, focusing on address validation, hierarchical queries, search performance, caching, and observability.

**Service Location**: `location/` (root level)

**Review Date**: 2026-01-14

---

## ✅ Implemented Features

1. **CRUD & Validation**:
   - ✅ Create, Update, Delete endpoints present and validated.
   - ✅ Strong validation rules for type/level/parent relationships.
   - ✅ Unique code checks within parent scope in the validator.

2. **Hierarchy & Tree Operations**:
   - ✅ `GetTree`, `GetChildren`, `GetAncestors` implemented.
   - ✅ Recursive loader for hierarchical traversal.

3. **Search**:
   - ✅ Basic `Search` endpoint implemented (`ILIKE` on `name` and `code`).

4. **Testing**:
   - ✅ Unit tests for usecases and repository functions are present and comprehensive.

5. **Health & Metrics**:
   - ✅ `/health` and `/metrics` endpoints present.

---

## 🔴 Critical & High Priority Issues

### 1. **Observability - Missing Tracing Middleware** (P1)
- **File**: `location/internal/server/http.go`
- **Issue**: No `tracing.Server()` middleware; OpenTelemetry tracing spans are missing for end-to-end correlation.
- **Impact**: Hard to trace slow `GetTree` calls across services and diagnose production issues.
- **Fix**: Inject `tracing.Server()` into HTTP server middleware and add spans in the usecase where appropriate (2-4h).

### 2. **GetLocationTree Performance** (P1)
- **File**: `location/internal/data/postgres/location.go: GetTree`
- **Issue**: Recursive DB calls (depth-first) per node cause multiple round-trips; this is O(N) DB queries for N nodes and will not scale for large trees.
- **Impact**: High latency and DB load for deep hierarchies.
- **Fix**: Implement a single-query hierarchical load via CTE, or iterative prefetch with batched child queries; add `maxDepth` safeguards and benchmarking (4-8h).

### 3. **Read Cache for Static Data** (P1)
- **File**: `location/internal/biz/location/location_usecase.go`
- **Issue**: Static data (country/state/city trees) is not cached; read-heavy endpoints should be cached with invalidation on writes.
- **Impact**: Increased DB load and latency under heavy read patterns (e.g., shipping page loads).
- **Fix**: Add Redis cache for `GetTree` and popular `List` queries; ensure writes (create/update/delete) invalidate TTL or update cache atomically (4-8h).

### 4. **Search Scalability** (P1)
- **File**: `location/internal/data/postgres/location.go: Search`
- **Issue**: `ILIKE '%query%'` causes sequential scans; no trigram or full-text index in place.
- **Impact**: Poor search performance at production scale.
- **Fix**: Add `pg_trgm` GIN indexes or leverage Postgres full-text search and switch query accordingly. Add benchmarks and integration tests (4-8h).

---

## 🟡 Medium & Low Priority Issues

### 5. **Metadata & Postal Codes Validation** (P2)
- **Issue**: `postal_codes` and `metadata` JSONB fields are not validated for structure or size. This can cause unbounded storage of noisy data.
- **Fix**: Add validator rules enforcing expected shapes and max sizes; constrain DB column length where reasonable (2-4h).

### 6. **Potential Event Publishing (Future Work)** (P2)
- **Issue**: Service currently does not publish domain events. If the product roadmap requires emitting `location.created/updated` events, implement Transactional Outbox as per `catalog`.
- **Fix**: Plan and implement `outbox_events` migration, `OutboxRepo`, and outbox worker (4-8h) when needed.

### 7. **Documentation & Examples** (P2)
- **Issue**: `docs/INTEGRATION_GUIDE.md` is present but could include caching recommendations and sample queries for common patterns.
- **Fix**: Expand docs with caching, index recommendations, and sample CTE query (2-4h).

---

## 🔧 Prioritized Action Items

- `[P1]` **Add Tracing & Metrics** (2-4h): Add `tracing.Server()` and instrument `GetTree` and `Search` with OpenTelemetry spans and Prometheus counters for hits/errors/latency.
- `[P1]` **Optimize Hierarchy Loading** (4-8h): Implement CTE or batched loader and add `maxDepth` guard and benchmarks.
- `[P1]` **Add Read Cache with Invalidation** (4-8h): Redis cache for `GetTree` and `List` (TTL, cache warming, invalidation on writes).
- `[P1]` **Upgrade Search to Use Indexes** (4-8h): Add trigram/full-text indexes and update search logic.
- `[P2]` **Metadata & Postal Code Validation** (2-4h): Enforce shapes and size limits.
- `[P2]` **Plan Outbox (If Events Needed)** (4-8h): Add outbox pattern when publishing becomes necessary.
- `[P2]` **Docs & Implementation Notes** (2-4h): Add integration docs and sample queries.

---

## ✅ Acceptance Criteria

- Tracing is enabled and spans are visible for `GetTree` and `Search`.
- `GetTree` is implemented with reduced DB queries; benchmark shows improved latency for deep trees.
- Read cache is implemented for `GetTree` and `List` with invalidation on writes and cache metrics published.
- Search uses indexed strategy and passes performance benchmarks.
- Metadata and postal codes are validated; tests enforce size limits.

---

## 🔄 Next Steps

1. Implement `tracing.Server()` and add span instrumentation (P1).
2. Prototype and benchmark hierarchical query improvements (P1).
3. Add Redis caching and invalidation for read-heavy endpoints (P1).
4. Replace `ILIKE` search with indexed strategy and add benchmarks (P1).
5. Add metadata/postal validation and expand integration docs (P2).

---

**References**:
- Service code: `location/internal/biz/location/*`, `location/internal/data/postgres/*`, `location/internal/server/http.go`
- Follow `catalog` for outbox pattern: see `docs/checklists/CATALOG_SERVICE_REVIEW.md` for reference implementation and tests.
