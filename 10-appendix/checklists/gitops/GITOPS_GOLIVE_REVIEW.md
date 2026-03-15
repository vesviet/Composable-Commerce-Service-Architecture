# GitOps Go-Live Readiness Review

**Review date**: 2026-03-14  
**Reviewer**: Senior DevOps (AI-assisted)  
**Scope**: `gitops/` repository — Kustomize-based App-of-Apps pattern  
**Environments**: `dev` and `production`

---

## Architecture Summary

| Item | Detail |
|------|--------|
| **Pattern** | Kustomize base/overlays + App-of-Apps (root Application) |
| **Environments** | `dev` (26 apps) and `production` (21 apps) |
| **Secret management** | SealedSecrets + Vault + ExternalSecrets (partially adopted) |
| **Autoscaling** | HPA + KEDA (operators installed) |
| **Progressive delivery** | Argo Rollouts (operator installed, 1 service uses canary) |
| **Monitoring** | Prometheus (standalone) + Grafana + Alertmanager + Jaeger + Fluent-bit |
| **Ingress** | Traefik IngressRoute (dev), NGINX Ingress (production) |
| **Shared components** | `common-deployment-v2`, `common-worker-deployment-v2`, `imagepullsecret`, `infrastructure-egress`, etc. |

---

## Production Environment Issues

### P0 — CRITICAL (Must fix before go-live)

- [ ] **PROD-01: All 23 base NetworkPolicies hardcode `-dev` namespaces**
  - **Impact**: All inter-service traffic BLOCKED in production
  - **Details**: Every `base/networkpolicy.yaml` uses `kubernetes.io/metadata.name: gateway-dev`, `order-dev`, etc. Kustomize does NOT transform namespace selectors inside `spec`.
  - **No production overlay patches NetworkPolicy** (dev overlays have `patch-networkpolicy.yaml` but production does not).
  - **Fix**: Create `patch-networkpolicy.yaml` for every production overlay, replacing `-dev` with `-production`/`-prod`. Or refactor base to use Kustomize `nameReference` transformer.
  - **Affected**: All 23 microservices

- [ ] **PROD-02: Gateway config hardcodes 19 `-dev` service hosts**
  - **Impact**: Gateway CANNOT route traffic to any production service
  - **Details**: `apps/gateway/base/gateway.yaml` defines all service hosts as `{service}.{service}-dev.svc.cluster.local`. Production overlay `patch-config.yaml` only overrides Redis/Consul, NOT service hosts.
  - **Fix**: Add all 19 service host overrides to `gateway/overlays/production/patch-config.yaml`.
  - **File**: `apps/gateway/base/gateway.yaml` lines 213-408

- [ ] **PROD-03: Plaintext secrets committed in Git**
  - **Impact**: Credentials exposed in Git history, placeholder keys in production
  - **Files with issues**:
    - `pricing/overlays/production/secret.yaml` — DB password `"microservices"`, JWT `"your-jwt-secret-key-change-in-production"`, HMAC `"change-this-to-a-secure-random-key-in-production"`
    - `common-operations/base/secret.yaml` — DB password `"microservices"`, MinIO `"minioadmin"/"minioadmin123"`, encryption key placeholder
    - `customer/base/secret.yaml` — DB password `"microservices"`, JWT placeholder, encryption key placeholder
    - `warehouse/base/secret.yaml` — DB password `"microservices"`
    - `warehouse/overlays/production/secrets.yaml` — `"REPLACE_WITH_SEALED_SECRET"` but still `kind: Secret`
  - **Fix**: Remove all plaintext secrets. Use SealedSecrets or ExternalSecrets for production (Vault + ExternalSecrets operator already installed).

- [ ] **PROD-04: 16 services missing production ConfigMap overlay**
  - **Impact**: Services use base/dev configs (wrong endpoints, wrong settings) in production
  - **Missing**: admin, analytics, common-operations, customer, frontend, fulfillment, location, loyalty-rewards, notification, order, payment, pricing, promotion, return, review, shipping
  - **Critical**: `frontend` production will **crash** — references ConfigMap `overlays-config` which is never defined in production overlay.
  - **Fix**: Create production configmap overlay for each service with production endpoints (`*-production.svc.cluster.local`).

- [ ] **PROD-05: Production sync policy too permissive — auto-deploy with prune**
  - **Impact**: Any Git change auto-deploys to production with no human approval; `prune: true` can auto-delete resources
  - **Details**: All 21 production Applications have `syncPolicy.automated.prune: true, selfHeal: true`
  - **Fix**: Remove `automated` from production sync policy (use manual sync) or at minimum remove `prune: true` and add `ApplyOutOfSyncOnly=true`.

### P1 — HIGH (Should fix before go-live)

- [ ] **PROD-06: Namespace naming inconsistent**
  - `checkout` → `checkout-prod`, `order` → `order-prod`
  - All other services → `{service}-production`
  - **Fix**: Standardize to `{service}-production` or `{service}-prod` consistently.

- [ ] **PROD-07: Production Dapr components not deployed**
  - `environments/production/resources/kustomization.yaml` only includes `infrastructure.yaml`, not `dapr/` subdirectory
  - `location/base/dapr-pubsub.yaml` hardcodes dev Redis password `"K8sD3v_redis_2026x"` in base (leaks to production)
  - **Fix**: Add `dapr/` to production resources kustomization. Fix location Dapr component to use `secretKeyRef`.

- [ ] **PROD-08: Production project RBAC too open**
  - `clusterResourceWhitelist: [group: '*', kind: '*']` and `namespaceResourceWhitelist: [group: '*', kind: '*']`
  - Dev project has curated whitelist. Production should be more restrictive.
  - **Fix**: Restrict production project whitelist to only required resource types.

- [ ] **PROD-09: Resource limits insufficient for critical services**
  - Only auth and common-operations have production-specific resource bumps
  - High-traffic services (order, payment, catalog, search) still use base limits (500m/512Mi-768Mi)
  - **Fix**: Add production resource patches for critical services.

- [ ] **PROD-10: `search/base/sync-job.yaml` hardcodes `-dev` namespace**
  - `catalog.catalog-dev.svc.cluster.local` — sync job fails in production
  - **Fix**: Parameterize or patch in production overlay.

- [ ] **PROD-11: Missing production HPA for several services**
  - No production HPA override: customer, loyalty-rewards, notification, pricing, promotion (API), return, shipping (API)
  - **Fix**: Add production HPA configs with appropriate min/max replicas.

### P2 — MEDIUM (Fix soon after go-live)

- [ ] **PROD-12: Production statestore `keyPrefix: "common-operations"` hardcoded**
  - All services sharing this statestore write under same prefix — key collision risk
  - **Fix**: Use `{appID}` dynamic prefix or per-service statestore components.

- [ ] **PROD-13: Production cluster template is EKS placeholder**
  - `clusters/production/production-cluster.yaml` is an AWS EKS template, not yet applied
  - **Action**: Verify actual cluster config matches template before go-live.

- [ ] **PROD-14: Vault in standalone mode, manual unseal**
  - Production should use HA mode (Raft/Consul backend) and auto-unseal (AWS KMS/GCP KMS)
  - **Action**: Plan migration to HA Vault with auto-unseal.

- [ ] **PROD-15: `ingress-traefik` component defaults to `letsencrypt-staging`**
  - Not currently used by any service, but if adopted, will issue untrusted certificates
  - **Fix**: Update template to use `letsencrypt-prod` or document patch requirement.

---

## Dev Environment Issues

### P0 — CRITICAL (Causes runtime failures)

- [ ] **DEV-01: Port mismatch between ConfigMap and NetworkPolicy**
  - `analytics`: ConfigMap ports `8019/9019`, NetworkPolicy allows `8018/9018` → traffic blocked
  - `common-operations`: ConfigMap ports `8018/9018`, NetworkPolicy allows `8020/9020` → traffic blocked
  - **Fix**: Correct NetworkPolicy to match actual service ports.

- [ ] **DEV-02: `promotion` and `return` external endpoints point to `localhost`**
  - **promotion**: ALL external endpoints → `http://localhost:800X` (catalog, customer, pricing, review, shipping)
  - **return**: ALL external endpoints → `http://localhost:800X` (customer, notification, order, payment, shipping, warehouse)
  - **Fix**: Replace with FQDN `{service}.{service}-dev.svc.cluster.local:{port}`.

- [ ] **DEV-03: Dapr Redis password overwritten to empty string**
  - `pubsub-redis.yaml` and `statestore-redis.yaml` have duplicate `value:` keys:
    ```yaml
    - name: redisPassword
      value: "K8sD3v_redis_2026x"
      value: ""                      # YAML: last value wins
    ```
  - Redis requires password → all Dapr pub/sub connections fail
  - **Fix**: Remove the duplicate `value: ""` line.

- [ ] **DEV-04: Auth service duplicate image entry with `https://` prefix**
  - ```yaml
    images:
    - name: https://registry-api.tanhdev.com/auth  # INVALID
      newName: https://registry-api.tanhdev.com/auth
      newTag: 8e0e7aca
    - name: registry-api.tanhdev.com/auth
      newTag: c006bece
    ```
  - **Fix**: Remove the first entry with `https://` prefix.

- [ ] **DEV-05: `review/base/migration-job.yaml` malformed YAML**
  - `configMap:` block nested under `resources.limits:` instead of `volumes:`
  - Migration job has no resource limits and invalid field
  - **Fix**: Move `configMap` to correct `volumes` section, add proper resource limits.

- [ ] **DEV-06: `fulfillment/base/configmap.yaml` — shell variable won't interpolate**
  - `database-url: "postgres://fulfillment_user:${DB_PASSWORD}@postgresql:5432/..."`
  - `${DB_PASSWORD}` is passed as literal string in Kubernetes ConfigMaps
  - **Fix**: Move database URL to Secret with actual credentials, or use FQDN with real password.

- [ ] **DEV-07: Search service — Elasticsearch namespace mismatch (3-way conflict)**
  - ConfigMap: `elasticsearch.argocd.svc.cluster.local:9200`
  - NetworkPolicy egress: allows namespace `default` for port 9200
  - ES actually deployed: namespace `monitoring`
  - **Fix**: Unify to `elasticsearch.monitoring.svc.cluster.local`.

- [ ] **DEV-08: `customer/base/networkpolicy.yaml` — wrong egress ports for Order**
  - Allows ports `8008/9008` (fulfillment ports) instead of `8004/9004` (order ports)
  - **Fix**: Correct to `8004/9004`.

### P1 — HIGH (Affects functionality or security)

- [ ] **DEV-09: Hardcoded credentials in ConfigMaps (21 services)**
  - Redis password `K8sD3v_redis_2026x` in 21 service ConfigMaps
  - DB password `microservices` in 6 service ConfigMaps
  - JWT secrets/encryption keys as placeholders in 3 services
  - ES password, MinIO creds, Grafana password in plaintext
  - **Fix**: Move all credentials to Secrets (ExternalSecrets already set up for 20 services).

- [ ] **DEV-10: `review/base/kustomization.yaml` missing `dapr-subscription.yaml`**
  - File exists but not included in kustomization resources
  - Dapr subscription for `shipping.shipment.delivered` never created
  - **Fix**: Add `dapr-subscription.yaml` to kustomization resources.

- [ ] **DEV-11: Base configs use short hostnames (cross-namespace DNS failure)**
  - `warehouse`, `fulfillment`: `postgresql:5432` → needs `postgresql.infrastructure.svc.cluster.local:5432`
  - `order`, `review`: `redis:6379` → needs `redis.infrastructure.svc.cluster.local:6379`
  - **Fix**: Use FQDN for all infrastructure service references.

- [ ] **DEV-12: Namespace definitions are dead code**
  - `namespaces-with-env.yaml` defines `auth`, `catalog`, `user`... (bare names)
  - Apps deploy to `auth-dev`, `catalog-dev`, `user-dev` (with `-dev` suffix)
  - Apps use `CreateNamespace=true` → the 30 namespace definitions are never used
  - **Fix**: Either update namespace definitions to `{service}-dev` or remove dead code.

- [ ] **DEV-13: `metrics-server.yaml` not in kustomization**
  - File exists on disk but not referenced in `resources/kustomization.yaml`
  - Without metrics-server, HPA has no CPU/memory metrics to scale on → HPA broken
  - **Fix**: Add `metrics-server.yaml` to kustomization resources.

- [ ] **DEV-14: 4 services missing secrets entirely**
  - `admin` — no secrets at all
  - `common-operations` — no ExternalSecret (uses base plaintext secret)
  - `frontend` — no secrets at all
  - `minio` — credentials in ConfigMap, not Secret
  - **Fix**: Create ExternalSecret or Secret for each.

- [ ] **DEV-15: Redis has no persistence**
  - `redis-current.yaml`: no AOF/RDB configured → data lost on pod restart
  - **Fix**: Enable `appendonly yes` or use `redis-ha.yaml` alternative.

### P2 — MEDIUM (Quality & maintainability)

- [ ] **DEV-16: Ingress has no TLS**
  - All IngressRoutes use `entryPoints: web` (HTTP only), no `websecure`
  - CORS middleware allows wildcard headers (`*`)
  - **Fix**: Add TLS for dev domain (or accept risk for dev-only).

- [ ] **DEV-17: Redis DB allocation collision — 9 services on DB 0**
  - DB 0: auth, checkout, loyalty-rewards, notification, order, return, search, shipping, location
  - DB 4: catalog, fulfillment, payment, warehouse
  - DB 6: analytics, customer
  - **Fix**: Allocate dedicated Redis DB per service (16 available).

- [ ] **DEV-18: Tracing endpoint inconsistency**
  - `localhost:14268` — 8 services (broken in K8s)
  - `jaeger-collector.observability.svc.cluster.local` — 3 services
  - `jaeger-collector.monitoring.svc.cluster.local` — 3 services
  - Not configured — 10 services
  - **Fix**: Standardize to `jaeger-collector.monitoring.svc.cluster.local:14268`.

- [ ] **DEV-19: ServiceMonitor port name mismatch**
  - auth, fulfillment, promotion use `port: http-svc`; all others use `port: http`
  - Service defines port name `http` → Prometheus won't scrape these 3 services
  - **Fix**: Standardize to `port: http`.

- [ ] **DEV-20: Deprecated `patchesStrategicMerge:` in 9 service kustomizations**
  - Modern: `patches:` (13 services). Deprecated: `patchesStrategicMerge:` (9 services). Mixed: 2 services.
  - **Fix**: Migrate all to `patches:` format.

- [ ] **DEV-21: Secret file naming inconsistent**
  - `secret.yaml` (singular): 9 services
  - `secrets.yaml` (plural): 11 services
  - **Fix**: Standardize naming.

- [ ] **DEV-22: Alertmanager uses `emptyDir` — state lost on restart**
  - Alert state, silences, notification log lost on pod restart
  - **Fix**: Use small PVC (~1Gi).

- [ ] **DEV-23: PDB blocks eviction on single-replica monitoring pods**
  - Prometheus, Grafana, Alertmanager: `minAvailable: 1` PDB + 1 replica
  - Node drain hangs because pod cannot be evicted
  - **Fix**: Use `maxUnavailable: 1` instead, or increase replicas to 2.

- [ ] **DEV-24: Analytics PDB vs HPA conflict**
  - HPA `minReplicas: 1` + PDB `minAvailable: 1` → rolling update blocked
  - **Fix**: Set `minReplicas: 2` or use `maxUnavailable: 1` PDB.

- [ ] **DEV-25: Orphaned/duplicate monitoring config files**
  - `critical-services-alerts.yaml` (PrometheusRule CRD) not in kustomization
  - `search-prometheus-alerts.yaml`, `warehouse-prometheus-alerts.yaml` duplicate rules in `prometheus-alert-rules.yaml`
  - Prometheus Operator CRDs deployed but standalone Prometheus is used
  - **Fix**: Remove duplicates, decide on Operator vs standalone.

- [ ] **DEV-26: `postgresql.yaml` malformed**
  - Kustomization file with raw StatefulSet YAML pasted inline (invalid)
  - **Fix**: Clean up or remove (not actively used since `postgresql-svc.yaml` is used instead).

- [ ] **DEV-27: `auth-db.yaml` (CloudNativePG) has duplicate Cluster resource**
  - Lines 103-116 repeat the Cluster spec → apply error if CloudNativePG is enabled
  - **Fix**: Remove duplicate block.

- [ ] **DEV-28: CloudNativePG cluster templates labeled `environment: production`**
  - All 17 cluster files in `dev/resources/` labeled `production` instead of `dev`
  - **Fix**: Update labels to `environment: dev`.

- [ ] **DEV-29: Order service timeout too low (1s)**
  - HTTP and gRPC timeout set to 1 second — too aggressive for multi-service calls
  - **Fix**: Increase to 5-10s minimum.

- [ ] **DEV-30: PVC size inconsistency for PostgreSQL**
  - `postgresql-pvc.yaml`: 20Gi
  - `postgresql-svc.yaml` and `postgresql-current.yaml`: 50Gi
  - **Fix**: Standardize to one PVC config.

- [ ] **DEV-31: Review ConfigMap label is `placeholder` instead of `review`**
  - `review/base/configmap.yaml` → `app.kubernetes.io/name: placeholder`
  - **Fix**: Change to `review`.

- [ ] **DEV-32: Dapr worker annotations inconsistent**
  - auth, user workers: `dapr.io/app-port: "0"` but expose `containerPort: 5005`
  - If workers need Dapr event delivery, sidecar won't forward traffic
  - **Fix**: Set `dapr.io/app-port: "5005"` if workers listen for events.

- [ ] **DEV-33: Pricing ConfigMap wrong catalog endpoint**
  - `catalog.catalog.svc.cluster.local:9015` (double `catalog`) — likely should be `catalog.catalog-dev.svc.cluster.local:9015`
  - **Fix**: Use correct namespace FQDN.

- [ ] **DEV-34: Checkout worker missing `dapr.io/enabled: "true"`**
  - Other workers explicitly set it; checkout worker omits it
  - **Fix**: Add `dapr.io/enabled: "true"` annotation.

- [ ] **DEV-35: Search sync-job missing `hook-delete-policy`**
  - Has `argocd.argoproj.io/hook: Sync` but no `hook-delete-policy` → old jobs accumulate
  - **Fix**: Add `hook-delete-policy: BeforeHookCreation,HookSucceeded`.

---

## Cross-Environment Issues (Base Layer)

These issues exist in `base/` and affect BOTH dev and production:

| # | Issue | Severity |
|---|-------|----------|
| BASE-01 | NetworkPolicies hardcode `-dev` namespaces in all base files | P0 |
| BASE-02 | Plaintext secrets in `customer/base/secret.yaml` and `warehouse/base/secret.yaml` | P0 |
| BASE-03 | Short hostnames in warehouse, fulfillment, order, review base configs | P1 |
| BASE-04 | `review/base/migration-job.yaml` malformed YAML | P0 |
| BASE-05 | `fulfillment/base/configmap.yaml` uses `${DB_PASSWORD}` shell variable | P0 |
| BASE-06 | `review/base/kustomization.yaml` missing dapr-subscription | P1 |
| BASE-07 | `customer/base/networkpolicy.yaml` wrong order service ports | P0 |
| BASE-08 | `search` ES namespace mismatch (configmap vs networkpolicy) | P0 |
| BASE-09 | `review/base/configmap.yaml` label still `placeholder` | P2 |
| BASE-10 | `pricing/base/configmap.yaml` wrong catalog endpoint | P2 |

---

## Port Allocation Reference

| Service | HTTP | gRPC | Worker |
|---------|------|------|--------|
| auth | 8000 | 9000 | 5005 |
| user | 8001 | 9001 | 5005 |
| pricing | 8002 | 9002 | — |
| customer | 8003 | 9003 | 5005 |
| order | 8004 | 9004 | 8081 |
| payment | 8005 | 9005 | 5005 |
| warehouse | 8006 | 9006 | 8081 |
| fulfillment | 8008 | 9008 | 8081 |
| notification | 8009 | 9009 | 5005 |
| checkout | 8010 | 9010 | 8081 |
| promotion | 8011 | 9011 | 5005 |
| shipping | 8012 | 9012 | 5005 |
| catalog | 8015 | 9015 | 8081 |
| review | 8016 | 9016 | — |
| search | 8017 | 9017 | 8081 |
| analytics | 8019 | 9019 | 8081 |
| gateway | 80 | 81 | — |
| admin | 3000 | — | — |
| frontend | 3000 | — | — |
| location | 8007 | 9007 | — |
| loyalty-rewards | 8014 | 9014 | 5005 |
| common-operations | 8018 | 9018 | 8081 |
| return | 8013 | 9013 | 5005 |

---

## Priority Matrix & Recommended Fix Order

### Phase 1 — Unblock Dev (Day 1-2)

| # | Task | Est. |
|---|------|------|
| 1 | Fix DEV-03: Dapr Redis password duplicate → remove `value: ""` | 5m |
| 2 | Fix DEV-04: Auth image `https://` prefix → remove invalid entry | 5m |
| 3 | Fix DEV-01: analytics/common-ops NetworkPolicy ports | 15m |
| 4 | Fix DEV-02: promotion/return localhost endpoints → FQDN | 30m |
| 5 | Fix DEV-05: review migration-job YAML | 10m |
| 6 | Fix DEV-06: fulfillment configmap shell variable | 10m |
| 7 | Fix DEV-07: search ES namespace consistency | 15m |
| 8 | Fix DEV-08: customer networkpolicy wrong ports | 10m |
| 9 | Fix DEV-13: Add metrics-server to kustomization | 5m |

### Phase 2 — Production Readiness (Day 3-5)

| # | Task | Est. |
|---|------|------|
| 10 | Fix PROD-01: Create production NetworkPolicy patches (23 services) | 4h |
| 11 | Fix PROD-02: Gateway production config with all service hosts | 1h |
| 12 | Fix PROD-03: Replace all plaintext secrets with SealedSecrets/ExternalSecrets | 3h |
| 13 | Fix PROD-04: Create production ConfigMap overlays (16 services) | 4h |
| 14 | Fix PROD-05: Remove auto-sync from production apps | 30m |

### Phase 3 — Hardening (Day 6-10)

| # | Task | Est. |
|---|------|------|
| 15 | Fix PROD-06: Standardize namespace naming | 1h |
| 16 | Fix PROD-07: Deploy production Dapr components | 1h |
| 17 | Fix PROD-08: Restrict production RBAC | 30m |
| 18 | Fix PROD-09: Production resource limits for critical services | 2h |
| 19 | Fix DEV-17: Redis DB allocation | 1h |
| 20 | Fix DEV-18: Standardize tracing endpoints | 1h |
| 21 | Fix remaining P2 items | 2-3h |

**Total estimated effort**: ~3-4 days focused work

---

## Summary

| Environment | P0 | P1 | P2 | Total |
|-------------|----|----|----|----|
| **Production** | 5 | 6 | 4 | **15** |
| **Dev** | 8 | 7 | 20 | **35** |
| **Base (cross-env)** | 5 | 2 | 3 | **10** |
| **Total unique** | **13** | **12** | **24** | **49** |

> **Verdict**: If deployed to production today, gateway cannot route traffic, inter-service calls are blocked by NetworkPolicy, secrets use placeholder values, and multiple services crash from missing configs. Fix P0 Phase 1 + Phase 2 (est. ~5 days) before go-live.
