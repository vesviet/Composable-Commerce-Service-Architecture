# AGENT-26: Search & Discovery Flow Hardening

> **Created**: 2026-03-09
> **Status**: COMPLETED
> **Services**: `search`
> **Primary Objective**: Optimize orphan cleanup and implement search feature stubs.

---

## 📋 Task Context
Following a deep-dive audit, it was discovered that several P0/P1 issues (Sync fail-fast, ES bulk metrics) were already resolved. This task now focuses on the remaining performance bottlenecks and unimplemented feature stubs.

---

## ✅ Checklist — P1 Issues (High Priority)

### [x] Task 1: Fix N+1 gRPC in Orphan Cleanup
**Files**: 
- `search/internal/client/interfaces.go`
- `search/internal/client/catalog_grpc_client.go`
- `search/internal/worker/orphan_cleanup_worker.go`

**Problem**: `orphan_cleanup_worker.go` scans ES IDs and calls `catalogClient.GetProduct` for each ID individually.
**Fix**:
1. Add `GetProductsBulk(ctx context.Context, ids []string) (map[string]*Product, error)` to `CatalogClient` interface.
2. Implement it in `grpcCatalogClient`.
3. Update `OrphanCleanupWorker` to check existence in batches of 100.

### [x] Task 2: Enable Dev Environment Caching
**File**: `gitops/apps/search/base/configmap.yaml`
**Action**: Set `enabled: "true"` for search cache to allow integration testing of cache invalidation logic.

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 3: Implement Trending Suggestions
**File**: `search/internal/data/elasticsearch/suggestions.go`
**Action**: Implement `GetTrending` logic (e.g., fetching top queries from ES or Redis).

### [x] Task 4: Dynamic Synonym Management
**File**: `search/internal/data/elasticsearch/synonyms.go`
**Action**: Investigate and implement a reloadable synonym file pattern to avoid full index recreation on synonym updates.

---

## 🔧 Verification Plan

### Automated Tests
```bash
# Verify Catalog Client changes
go test -v ./internal/client/catalog_grpc_client_test.go

# Verify Orphan Cleanup logic
go test -v ./internal/worker/orphan_cleanup_worker_test.go
```

---

## 📝 Commit Format
```
perf(search): resolve N+1 gRPC in orphan cleanup worker

- feat: add GetProductsBulk to CatalogClient interface
- fix: refactor orphan cleanup to use batch lookup
- chore(gitops): enable search cache in dev environment
```
