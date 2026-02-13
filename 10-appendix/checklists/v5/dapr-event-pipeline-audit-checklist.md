# 🔍 Dapr Event Pipeline & GitOps Audit Checklist v5.0

**Purpose**: Comprehensive audit of Dapr event-driven infrastructure, GitOps configs, and Elasticsearch sync pipeline  
**Scope**: Pricing, Search, Warehouse services — Dapr sidecar injection, pubsub subscriptions, event flow, GitOps configs  
**Date**: February 13, 2026  
**Status**: 🔴 Critical Issues Found  
**Triggered By**: Products (BLK-009946) not appearing in search results

---

## 🔴 Critical: Dapr Sidecar Injection Failures

### Runtime Sidecar Audit

| Pod | Namespace | `daprd` Sidecar | Annotations OK | Impact |
|-----|-----------|-----------------|----------------|--------|
| `warehouse` | warehouse-dev | ✅ Present | ✅ | Can publish stock events |
| `warehouse-worker` | warehouse-dev | ✅ Present | ✅ | Can consume events |
| `search` (main) | search-dev | ✅ Present | ✅ | N/A (no event role) |
| `search-worker` | search-dev | ❌ **Missing** | ✅ | **Cannot receive ANY events** |
| `pricing` | pricing-dev | ❌ **Missing** | ✅ | **NoOp publisher fallback** |
| `pricing-worker` | pricing-dev | ❌ **Missing** | ✅ | **Outbox events dropped** |

> [!CAUTION]
> Dapr sidecar injector (mutating webhook) missed 3 pods during creation — likely due to 18 injector restarts. All 3 pods have correct `dapr.io/enabled: "true"` annotations. Rolling restart required.

### Checklist

- [x] `kubectl rollout restart deployment/pricing deployment/pricing-worker -n pricing-dev` ✅ Done
- [x] `kubectl rollout restart deployment/search-worker -n search-dev` ✅ Done
- [x] Verify: pricing pod → `pricing daprd` ✅ 2/2 Running
- [x] Verify: search-worker pod → `search-worker daprd` ✅ 2/2 Running
- [x] Check pricing logs for real Dapr publish → `Dapr gRPC client created successfully` ✅
- [x] Check search-worker logs for consumer registration → All 10 consumers registered ✅

---

## 🟡 GitOps Config Review: Pricing Service

### Files Reviewed

| File | Status | Issues |
|------|--------|--------|
| [deployment.yaml](file:///home/user/microservices/gitops/apps/pricing/base/deployment.yaml) | ⚠️ | Missing config volume mount |
| [worker-deployment.yaml](file:///home/user/microservices/gitops/apps/pricing/base/worker-deployment.yaml) | ⚠️ | No health probes, no config volume |
| [configmap.yaml](file:///home/user/microservices/gitops/apps/pricing/base/configmap.yaml) | 🔴 | **Minimal config — no eventbus/pubsub settings** |
| [kustomization.yaml](file:///home/user/microservices/gitops/apps/pricing/base/kustomization.yaml) | ✅ | OK |
| [networkpolicy.yaml](file:///home/user/microservices/gitops/apps/pricing/base/networkpolicy.yaml) | ⚠️ | Not reviewed for Dapr egress |

### Issues Found

- [x] **🔴 P0 — ConfigMap missing eventbus config**: Pricing `configmap.yaml` only has `database-url`, `redis-url`, `log-level`. No `eventbus.default_pubsub` or topic mappings. Compare with search configmap which has full eventbus block.
  - Pricing service reads eventbus config from env vars or hardcoded defaults
  - Should add explicit eventbus config for consistency

- [x] **🟡 P1 — No config volume on main deployment**: Pricing `deployment.yaml` does NOT mount a config volume. Uses only `envFrom: overlays-config`. Worker also uses `envFrom: overlays-config` only.
  - Compare: Search worker mounts `search-config` ConfigMap as `/app/configs/config.yaml`
  - Pricing relies on env vars → less structured than search's YAML config approach

- [x] **🟡 P1 — Worker has no health/readiness probes**: ✅ **FIXED** — Added TCP startup + liveness probes on port 5005

- [x] **🟢 P2 — Dapr annotations correct**: Both `deployment.yaml` and `worker-deployment.yaml` have correct Dapr annotations ✅
  - Main: `app-id: pricing`, `app-port: 8002`, `app-protocol: http`
  - Worker: `app-id: pricing-worker`, `app-port: 5005`, `app-protocol: grpc`

---

## 🟡 GitOps Config Review: Search Service

### Files Reviewed

| File | Status | Issues |
|------|--------|--------|
| [deployment.yaml](file:///home/user/microservices/gitops/apps/search/base/deployment.yaml) | ✅ | Good — has probes, config volume |
| [worker-deployment.yaml](file:///home/user/microservices/gitops/apps/search/base/worker-deployment.yaml) | ⚠️ | No health probes |
| [configmap.yaml](file:///home/user/microservices/gitops/apps/search/base/configmap.yaml) | ✅ | Full eventbus config with all topics |
| [kustomization.yaml](file:///home/user/microservices/gitops/apps/search/base/kustomization.yaml) | 🔴 | **Wrong namespace** |
| [networkpolicy.yaml](file:///home/user/microservices/gitops/apps/search/base/networkpolicy.yaml) | 🔴 | **Wrong ports + missing egress** |

### Issues Found

- [x] **🔴 P0 — Kustomization namespace mismatch**: ✅ **FIXED** — Changed `namespace: search` → `namespace: search-dev`

- [x] **🔴 P0 — NetworkPolicy port mismatch**: ✅ **FIXED** — Changed ports `8016/9016` → `8017/9017`

- [x] **🔴 P0 — NetworkPolicy missing pricing egress**: ✅ **FIXED** — Added egress rule to `pricing-dev` namespace on port `9002`

- [x] **🟡 P1 — No Dapr subscription YAML**: Search uses programmatic subscriptions in Go code — by design, no YAML needed.

- [x] **🟡 P1 — Worker has no health probes**: ✅ **FIXED** — Added TCP startup + liveness probes on port 5005

- [x] **🟢 P2 — Eventbus config complete**: ConfigMap has full topic mapping ✅
  - `pricing_price_updated: pricing.price.updated` ✅
  - `warehouse_stock_changed: warehouse.inventory.stock_changed` ✅
  - `default_pubsub: pubsub-redis` ✅

---

## 🔴 Dapr Event Subscription Audit

### Pubsub Component

- [ ] **Verify cross-namespace access**: `pubsub-redis` component only exists in `common-operations-dev` namespace. Need to ensure Dapr can access this component from `pricing-dev` and `search-dev` namespaces.
  ```
  kubectl get component -A
  # NAMESPACE               NAME               AGE
  # common-operations-dev   pubsub-redis       3d11h
  # common-operations-dev   statestore-redis   3d11h
  ```

### Subscription Registration Method

| Service | Method | Topics | Pubsub |
|---------|--------|--------|--------|
| Search Worker | **Programmatic** (Go code via `AddTopicEventHandler`) | `pricing.price.updated`, `pricing.price.deleted`, `warehouse.inventory.stock_changed` + catalog/CMS topics | `pubsub-redis` |
| Loyalty Rewards | **Declarative** (Kubernetes YAML) | `customer.created`, `order.completed`, `order.cancelled` | `pubsub-redis` |

### Checklist

- [x] After sidecar fix, verify search-worker startup logs show subscription registration ✅ All consumers registered
- [ ] Test price event flow: update price in pricing DB → verify event published → verify search-worker receives it
- [ ] Test stock event flow: update stock in warehouse → verify search-worker receives `warehouse.inventory.stock_changed`

---

## 🔴 Elasticsearch Index Issues

### Current State

| Index | Type | Documents | Used By |
|-------|------|-----------|---------|
| `products` | Standalone index | **0** | Event consumers (write) |
| `products_20260213_072609` | Timestamped index | **2** | — |
| `products_search` | Alias → `products_20260213_072609` | **2** | Search queries (read) |

### Checklist

- [x] **Fix write path**: ✅ **FIXED** — Event consumers + product CRUD in `price_view.go`, `stock_view.go`, `product_index.go` now write to `products_search` alias
- [ ] **Delete orphan index**: After confirming writes use alias, delete the empty `products` standalone index
- [ ] **Re-run sync job**: `kubectl create job --from=cronjob/search-sync search-sync-manual -n search-dev`
- [ ] **Verify**: `curl -s ES_URL/products_search/_count` → should show 8000+ documents

---

## 🟡 Code Bugs in Event Consumers

### Stock Consumer — Missing `product_id` ✅ FIXED

- [x] `StockChangedEvent` struct — Added `ProductID string` field with `json:"product_id"` tag
- [x] `ProcessStockChanged` — Uses `event.ProductID` (UUID) as ES document ID with SKU fallback
- [x] Build passes ✅

### Price View — Hardcoded Stock Defaults ✅ FIXED

- [x] Painless script no longer hardcodes `in_stock: false, quantity: 0` when creating warehouse_stock entries from price events

---

## 📋 Fix Priority Order

### Phase 1: Infrastructure (No code changes) ✅ DONE
1. [x] Rollout restart pricing + pricing-worker + search-worker ✅
2. [x] Verify `daprd` sidecar injected in all 3 pods ✅
3. [ ] Re-run search sync job (prices now exist)

### Phase 2: GitOps Config Fixes ✅ DONE
4. [x] Fix search NetworkPolicy ports (8016→8017, 9016→9017) ✅
5. [x] Add pricing egress to search NetworkPolicy ✅
6. [x] Fix search kustomization namespace (`search` → `search-dev`) ✅
7. [x] Add health probes to pricing-worker and search-worker deployments ✅

### Phase 3: Code Fixes ✅ DONE
8. [x] Fix ES index name mismatch — all writes now use `products_search` alias ✅
9. [x] Add `ProductID` to `StockChangedEvent` + use as ES doc ID ✅
10. [x] Fix Painless script hardcoded defaults ✅
11. [x] Build passes (`go build ./...`) ✅

### Phase 4: Verification
12. [ ] Verify search sync indexes all 8000+ products
13. [ ] Test real-time price update → search result update
14. [ ] Test real-time stock update → search result update
15. [ ] Verify BLK-009946 appears in search results
16. [ ] Build + deploy search service with code fixes

---

## 📊 Comparison: Working (Warehouse) vs Broken (Pricing/Search) GitOps

| Aspect | Warehouse (✅ Working) | Pricing (❌ Broken) | Search Worker (❌ Broken) |
|--------|------------------------|---------------------|--------------------------|
| Dapr annotations | ✅ `enabled: true` | ✅ `enabled: true` | ✅ `enabled: true` |
| `daprd` sidecar | ✅ Injected | ❌ Missing | ❌ Missing |
| Config approach | `envFrom: overlays-config` | `envFrom: overlays-config` | Volume mount `search-config` |
| Health probes | ❌ None (worker) | ❌ None (worker) | ❌ None (worker) |
| Eventbus config | In service config | ❌ Missing from ConfigMap | ✅ Full in ConfigMap |

**Conclusion**: The gitops configs are structurally identical — the sidecar injection failure is a Dapr injector timing issue, not a config issue. However, there are several gitops config bugs (NetworkPolicy ports, namespace, missing eventbus config) that need fixing.
