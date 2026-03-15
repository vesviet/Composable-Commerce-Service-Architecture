# AGENT-05: Consul Config Standardization & Service Registration Hardening

> **Created**: 2026-03-15
> **Completed**: 2026-03-15
> **Priority**: P0/P1/P2
> **Sprint**: Infrastructure Hardening Sprint
> **Services**: `common`, `auth`, `user`, `customer`, `catalog`, `order`, `payment`, `warehouse`, `fulfillment`, `shipping`, `location`, `checkout`, `search`, `review`, `notification`, `promotion`, `loyalty-rewards`, `return`, `common-operations`, `gateway`, `analytics`, `gitops`
> **Estimated Effort**: 8-12 days
> **Status**: ✅ **COMPLETED** (25/26 tasks, Task 16 deferred)
> **Phase 2 moved to**: [AGENT-06-CONSUL-GITOPS-INFRASTRUCTURE-HARDENING.md](AGENT-06-CONSUL-GITOPS-INFRASTRUCTURE-HARDENING.md)

---

## 📋 Overview

Code-level Consul config standardization and service registration hardening. Covers 22 services, common library, and GitOps configmaps. Key changes:
- Removed dead `HealthCheck`/`HealthCheckTimeout` fields from `ConsulConfig`
- Enabled gossip encryption, ACL default-deny, TLS, 3-node HA for Consul server
- Added circuit breaker + backoff to `DynamicRouteLoader`
- Cached `MergedPatterns()`, added `ConsulConfigAccessor` interface
- Deployed Stakater Reloader for config hot-reload
- Added in-memory cache for user Consul permissions
- Added service metadata tags for canary routing

---

## ✅ Completed Tasks (25/26)

### P0 (8/8 ✅)
- [x] Task 1: Create GitOps Overlay ConfigMaps for 5 Services Missing Consul Address ✅
- [x] Task 2: Fix Location Service Wrong Consul Namespace ✅
- [x] Task 3: Fix User Service `newApp()` Missing Nil-Check on Registrar ✅
- [x] Task 4: Fix Location `ProvideConsulConfig` Missing Nil-Check ✅
- [x] Task 5: Fix `REVIEW_REGISTRY_CONSUL_ADDRESS` Pointing to `localhost` ✅
- [x] Task 6: Enable Consul Gossip Encryption ✅
- [x] Task 7: Migrate Consul to 3-Node HA with PVC ✅
- [x] Task 8: Migrate Analytics Service to BaseAppConfig + Consul Registration ✅

### P1 (11/12 — Task 16 deferred)
- [x] Task 9: Remove Dead `HealthCheck`/`HealthCheckTimeout` Fields from `ConsulConfig` ✅
- [x] Task 10: Fix `DefaultConsulConfig()` and Update `NewConsulRegistrar()` Field References ✅
- [x] Task 11: Update Test Expectations in `consul_test.go` ✅
- [x] Task 12: Clean 25 GitOps ConfigMaps — Remove `health_check: true` and `health_check_timeout` ✅
- [x] Task 13: Add `newApp` Nil-Check to Remaining 7 Services ✅
- [x] Task 14: Remove Dead Proto `Registry.Consul` from Review & Search ✅
- [x] Task 15: Standardize `ProvideConsulConfig` — Move to Common Lib via Interface ✅
- [ ] Task 16: Standardize GitOps to Env-Var Only Overlay Style — **DEFERRED**
- [x] Task 17: Add Missing Consul Defaults to Config Loader ✅
- [x] Task 18: Add In-Memory Cache to User Consul Permission Repo ✅
- [x] Task 19: Enable Consul ACL with Default-Deny Policy ✅
- [x] Task 20: Add Service Metadata Tags for Canary Routing ✅

### P2 (6/6 ✅)
- [x] Task 21: Add DynamicRouteLoader Retry + Circuit Breaker ✅
- [x] Task 22: Consul TLS for HTTP API ✅
- [x] Task 23: Evaluate Consul Dataplane (Agentless) ✅
- [x] Task 24: Implement Config Hot-Reload via Stakater Reloader ✅
- [x] Task 25: Pre-allocate `MergedPatterns()` Slice in DynamicRouteLoader ✅
- [x] Task 26: Gateway `ProvideConsulConfig` Add Nil-Check ✅

---

## 📊 Acceptance Criteria

| # | Criteria | Status |
|---|----------|--------|
| 1 | All 19 services have GitOps Consul overlay | ✅ |
| 2 | Location uses correct namespace (localhost for dev) | ✅ |
| 3 | All `newApp` functions have nil-check | ✅ |
| 4 | No dead `REGISTRY_CONSUL_*` env vars | ✅ |
| 5 | Consul has gossip encryption config | ✅ |
| 6 | Consul runs 3 nodes with PVC | ✅ |
| 7 | Analytics has Consul config | ✅ |
| 8 | `ConsulConfig` has NO `HealthCheck` or `HealthCheckTimeout` field | ✅ |
| 9 | `DefaultConsulConfig()` does NOT set `HealthCheck: true` | ✅ |
| 10 | No `health_check: true` in GitOps | ✅ |
| 11 | No `health_check_timeout` in GitOps | ✅ |
| 12 | `health_check_interval` still present (TTL freq) | ✅ |
| 13 | `ConsulConfigAccessor` interface in common | ✅ |
| 14 | Config loader has 6 defaults | ✅ |
| 15 | User permission calls cached | ✅ |
| 16 | DynamicRouteLoader has circuit breaker + backoff | ✅ |
| 17 | Consul TLS enabled (HTTPS 8501) | ✅ |
| 18 | Consul Dataplane evaluation documented | ✅ |
| 19 | Stakater Reloader deployed | ✅ |
| 20 | `MergedPatterns()` cached with dirty flag | ✅ |
