# AGENT-02: Flash Sale 500% Bottleneck — Infrastructure & Application Tuning

> **Created**: 2026-03-25
> **Priority**: P0 (3 Critical), P1 (2 High), P2 (2 Nice-to-Have)
> **Sprint**: Performance Hardening Sprint
> **Services**: `gitops`, `catalog`, `checkout`, `search`, `common`, `gateway`
> **Estimated Effort**: 1-2 days
> **Source**: [Meeting Review Round 1](file:///home/user/.gemini/antigravity/brain/cae05ec1-a81f-4199-a06d-b4091876fc12/bottleneck_investigation_review.md) + [Meeting Review Round 2](file:///home/user/.gemini/antigravity/brain/cae05ec1-a81f-4199-a06d-b4091876fc12/bottleneck_review_round2.md)

---

## 📋 Overview

Hệ thống E-commerce bị sụp ở 500% traffic (300 RPS) Flash Sale, tỷ lệ lỗi 21% dẫn tới K6 auto-abort trong 30 giây. Qua 6 đợt Sweep và 2 buổi Meeting Review đa chuyên gia, đã xác định được 3 tầng nghẽn cổ chai:

1. **PgBouncer Pool** — `default_pool_size=40` quá nhỏ → ✅ **ĐÃ FIX** (nâng lên 120)
2. **CPU Throttling** — Catalog/Search/Checkout chỉ có `500m` CPU limit → Pod bị K8s CGroup bóp nghẹt
3. **GORM Connection Overflow** — 3 pods × 100 conns = 300, vượt PostgreSQL max_connections

### Load Test Timeline

| Sweep | PgBouncer Pool | Gateway RPM | Error Rate | Status |
|-------|---------------|-------------|------------|--------|
| 1-3 | 40 | 10,000 | 28.76% | Abort @ 31s (Rate Limit) |
| 4 | 40 | 50,000 | 20.95% | Abort @ 2m05s (DB Wait Queue) |
| 5 | 40 | 50,000 | — | Cooldown |
| 6 | **120** | 50,000 | 21.27% | Abort @ 2m07s (CPU Throttling) |

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Nâng CPU Limits cho Catalog Service (HOT PATH)

**File**: `gitops/apps/catalog/base/patch-api.yaml`
**Lines**: 25-31
**Risk**: Catalog P95 latency = 11.81s, product-list trả về timeout cho 17% users. Revenue mất trực tiếp khi khách không browse được sản phẩm.
**Problem**: CPU limit chỉ `500m` (0.5 core) phải gánh 120-300 RPS serialize 25k+ SKU Protobuf responses.

```yaml
# BEFORE:
        resources:
          requests:
            memory: "256Mi"
            cpu: "150m"
          limits:
            memory: "768Mi"
            cpu: "500m"

# AFTER:
        resources:
          requests:
            memory: "384Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1500m"
```

**Validation**:
```bash
# After ArgoCD sync, verify pod resource allocation
kubectl get pods -n catalog-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources}{"\n"}{end}'
# Run K6 Sweep 7 and check product-list P95 < 3s
```

---

### [ ] Task 2: Nâng CPU Limits cho Search Service (HOT PATH)

**File**: `gitops/apps/search/base/patch-api.yaml`
**Lines**: 29-35
**Risk**: Search P95 = 5.31s, 19% search requests timeout. Khách không tìm được sản phẩm trong Flash Sale.
**Problem**: CPU limit `500m` không đủ cho Elasticsearch query parsing + Protobuf serialization đồng thời.

```yaml
# BEFORE:
        resources:
          requests:
            memory: "256Mi"
            cpu: "150m"
          limits:
            memory: "768Mi"
            cpu: "500m"

# AFTER:
        resources:
          requests:
            memory: "384Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1500m"
```

**Validation**:
```bash
kubectl get pods -n search-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources}{"\n"}{end}'
# K6 Sweep 7: product-search P95 < 2s
```

---

### [ ] Task 3: Nâng CPU Limits cho Checkout Service (HOT PATH)

**File**: `gitops/apps/checkout/base/patch-api.yaml`
**Lines**: 21-27
**Risk**: cart-add transport failure 66%. Khách nhấn "Add to Cart" 3 lần, chỉ 1 lần thành công.
**Problem**: CPU limit `500m` chưa đủ headroom cho concurrent cart operations.

```yaml
# BEFORE:
        resources:
          requests:
            memory: "256Mi"
            cpu: "150m"
          limits:
            memory: "768Mi"
            cpu: "500m"

# AFTER:
        resources:
          requests:
            memory: "384Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

**Validation**:
```bash
kubectl get pods -n checkout-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources}{"\n"}{end}'
# K6 Sweep 7: cart-add P95 < 500ms, cart_reserve_success_rate > 80%
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 4: Giảm GORM MaxOpenConns cho Catalog (Connection Overflow)

**File**: `gitops/apps/catalog/base/configmap.yaml`
**Line**: 31
**Risk**: 3 pods × 100 conns = 300 total connections. PostgreSQL max_connections mặc định = 100, PgBouncer chỉ pool 120/DB. Overflow gây connection refused dưới high concurrency.
**Problem**: `max_open_conns: 100` per pod quá cao khi HPA scale 3+ pods.

```yaml
# BEFORE:
        max_open_conns: 100

# AFTER:
        max_open_conns: 40
```

**Giải thích**: 3 pods × 40 = 120 connections, vừa khít `default_pool_size=120` của PgBouncer.

**Validation**:
```bash
grep "max_open_conns" gitops/apps/catalog/base/configmap.yaml
# Expected: max_open_conns: 40
# After deploy, check GORM log output: "Database connected (max_open=40, ...)"
```

---

### [ ] Task 5: Giảm GORM MaxOpenConns cho Search (Connection Overflow)

**File**: `gitops/apps/search/base/configmap.yaml`
**Line**: 24
**Risk**: Tương tự Task 4, Search cũng set `max_open_conns: 100`.
**Problem**: 3 pods × 100 = 300 conns cho search_db, vượt PgBouncer pool.

```yaml
# BEFORE:
        max_open_conns: 100

# AFTER:
        max_open_conns: 40
```

**Validation**:
```bash
grep "max_open_conns" gitops/apps/search/base/configmap.yaml
# Expected: max_open_conns: 40
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 6: Tăng Redis Pool Size mặc định trong Common Library

**File**: `common/config/config.go`
**Line**: 174
**Risk**: Dưới high concurrency, Redis pool 10 connections bị cạn, gây thêm latency chờ Redis connection.
**Problem**: Default `PoolSize: 10` quá nhỏ cho services có 100+ RPS.

```go
// BEFORE (line 174):
PoolSize:     GetIntEnv("REDIS_POOL_SIZE", 10),

// AFTER:
PoolSize:     GetIntEnv("REDIS_POOL_SIZE", 30),
```

**Validation**:
```bash
cd common && grep "REDIS_POOL_SIZE" config/config.go
# Expected: default = 30
cd common && go build ./...
```

---

### [ ] Task 7: Giám sát Dapr Sidecar CPU Overhead trên HOT PATH

**File**: `gitops/apps/gateway/base/patch-api.yaml` (Lines 10-13)
**Risk**: 9 HOT PATH pods × 50m CPU sidecar = 450m CPU overhead. Trên cluster nhỏ là đáng kể.
**Problem**: Dapr sidecar annotations `dapr.io/sidecar-cpu-request: "50m"` cộng dồn lên.

**Action**: Không cần sửa code. Theo dõi trên Grafana dashboard, nếu sau khi fix P0 tasks mà vẫn còn bottleneck, thì xem xét:
- Tăng sidecar CPU limit từ 300m → 500m cho Catalog/Search
- Hoặc offload non-critical sidecars

**Validation**:
```bash
# Monitor Dapr sidecar CPU on Grafana
# Panel: "Dapr Sidecar gRPC RPCs" on E-commerce Platform Overview dashboard
```

---

## ✅ Đã hoàn thành (Reference)

### [x] Task 0: PgBouncer Pool Size (ĐÃ FIX ✅)

**File**: `gitops/infrastructure/databases/pgbouncer.yaml`
**Lines**: 46-51
**Fix Applied**:
```ini
# 40 → 120
default_pool_size = 120
min_pool_size = 15
reserve_pool_size = 30
max_client_conn = 5000
max_db_connections = 500
```
**Result**: Cart operations cải thiện 43% (cart-add P95: 260ms → 149ms) ✅

### [x] Task 0b: Gateway Rate Limit (ĐÃ FIX ✅)

**File**: `gitops/apps/gateway/base/gateway.yaml`
**Lines**: 69-88
**Fix Applied**: Global RPM: 20,000 → 50,000; Burst: 1,500 → 5,000 ✅

---

## 🔧 Pre-Commit Checklist

```bash
# GitOps changes only (no Go code changes for P0)
cd gitops
git diff --stat
# Verify only patch-api.yaml and configmap.yaml files changed

# For P2 Task 6 (common library):
cd common && go build ./...
cd common && go test ./config/... -v
```

---

## 📝 Commit Format

```
perf(gitops): scale CPU limits for flash sale hot path services

- perf: catalog CPU 500m → 1500m limit for 300 RPS product browsing
- perf: search CPU 500m → 1500m limit for Elasticsearch queries
- perf: checkout CPU 500m → 1000m limit for cart operations
- fix: reduce GORM MaxOpenConns 100 → 40/pod to match PgBouncer pool

Closes: AGENT-02
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Catalog P95 latency < 3s at 300 RPS | K6 Sweep 7: `http_req_duration{route:product-list} p(95) < 3000` | |
| Search P95 latency < 2s at 300 RPS | K6 Sweep 7: `http_req_duration{route:product-search} p(95) < 2000` | |
| Cart-add success rate > 80% | K6 Sweep 7: `cart_reserve_success_rate > 0.80` | |
| Overall error rate < 15% at 500% scale | K6 Sweep 7: `http_req_failed rate < 0.15` | |
| No connection refused errors in PgBouncer logs | `kubectl logs -n infrastructure pgbouncer-xxx` | |
| GORM MaxOpenConns × pods ≤ PgBouncer pool | 3 × 40 = 120 ≤ `default_pool_size=120` | |
| PgBouncer pool nâng lên 120 | ✅ Already deployed | ✅ |
| Gateway rate limit nâng lên 50k RPM | ✅ Already deployed | ✅ |
