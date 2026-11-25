# GitOps Go-Live Readiness Review

**Review date**: 2026-03-14 (verified & synchronized: 2026-11-25)  
**Reviewer**: Platform / DevOps Engineering  
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

- [x] **PROD-01: Base NetworkPolicies hardcode `-dev` namespaces / missing production egress** ✅ **RESOLVED**
  - Cleaned all remaining `-dev` references from `auth`, `common-operations`, and `payment` `base/networkpolicy.yaml` (`0/22` base NetworkPolicies contain `-dev`).
  - Verified `22/22` service overlays have `patch-networkpolicy.yaml` (`gateway` intentionally exposes ingress without a service NetworkPolicy), including complete `egress:` + infrastructure rules in `auth/production`, `payment/production`, and `common-operations/{dev,production}`.

- [x] **PROD-02: Gateway config hardcodes `-dev` service hosts** ✅ **RESOLVED**
  - Verified `gitops/apps/gateway/overlays/production/patch-config.yaml` defines all `23` `*.{service}-production.svc.cluster.local` endpoints.

- [x] **PROD-03: Plaintext secrets committed in Git** ✅ **RESOLVED**
  - Migrated `pricing/overlays/production/secret.yaml`, `common-operations/base/secret.yaml`, and `warehouse/overlays/production/secrets.yaml` to `ExternalSecret` (`vault-backend`); `customer/base/secret.yaml` and `warehouse/base/secret.yaml` removed (`leaseinvietnam/base/secrets-{dev,template}.yaml` are template/dev files outside core go-live).

- [x] **PROD-04: 16 services missing production ConfigMap overlay** ✅ **RESOLVED**
  - Verified `23/23` production service overlays define ConfigMap/patch-config manifests (`frontend` production includes `patch-config.yaml`).

- [x] **PROD-05: Production sync policy too permissive — auto-deploy with prune** ✅ **RESOLVED**
  - Verified all `24/24` production ArgoCD Applications in `environments/production/apps/*.yaml` use manual sync (`automated:` and `prune: true` removed) with `PruneLast=true` and `ApplyOutOfSyncOnly=true`.

### P1 — HIGH (Should fix before go-live)

- [x] **PROD-06: Namespace naming inconsistent** ✅ **RESOLVED**
  - Verified all `23/23` production Application `destination.namespace` values follow `{service}-production`.

- [x] **PROD-07: Production Dapr components not deployed / plaintext Redis password in pubsub base** ✅ **RESOLVED**
  - Replaced hardcoded Redis password in `location/base/dapr-pubsub.yaml` and `order/base/dapr-pubsub.yaml` with `secretKeyRef` referencing `redis-credentials/redis-password`, and included `dapr/pubsub-redis.yaml` + `dapr/statestore-redis.yaml` in `environments/production/resources/kustomization.yaml`.

- [x] **PROD-08: Production project RBAC too open** ✅ **RESOLVED**
  - Verified `environments/production/projects/production-project.yaml` defines a curated `clusterResourceWhitelist` (`Namespace`, `ClusterRole`, `ClusterRoleBinding`, etc.).

- [x] **PROD-09: Resource limits insufficient for critical services** ✅ **RESOLVED**
  - Fixed container target names (`placeholder` -> service name) and added production `requests`/`limits` in `overlays/production/deployment-patch.yaml` for `catalog` (`250m/512Mi` -> `1000m/1Gi`), `search` (`300m/512Mi` -> `1500m/1536Mi`), `order` (`250m/512Mi` -> `1000m/1Gi`), and `payment` (`250m/512Mi` -> `1000m/1Gi`), matching `auth`/`common-operations` sizing.

- [x] **PROD-10: `search/base/sync-job.yaml` hardcodes `-dev` namespace** ✅ **RESOLVED**
  - Added `gitops/apps/search/overlays/production/sync-job-patch.yaml` (referenced in `kustomization.yaml`) overriding initContainer service checks to `.catalog-production`, `.warehouse-production`, `.pricing-production`.

- [x] **PROD-11: Missing production HPA for UI services** ✅ **RESOLVED**
  - Added `gitops/apps/admin/overlays/production/hpa.yaml` (`minReplicas: 2`, `maxReplicas: 5`) and `gitops/apps/frontend/overlays/production/hpa.yaml` (`minReplicas: 2`, `maxReplicas: 8`) referenced in their `kustomization.yaml`; `23/23` production apps now define HPA.

### P2 — MEDIUM (Fix soon after go-live)

- [x] **PROD-12: Production statestore `keyPrefix: "common-operations"` hardcoded** ✅ **RESOLVED**
  - Updated `environments/production/resources/dapr/statestore-redis.yaml` `keyPrefix` value to `"name"` (`app-id`-scoped keys).

- [ ] **PROD-13: Production cluster template is EKS placeholder**
  - `clusters/production/production-cluster.yaml` is an AWS EKS template, not yet applied (external infrastructure task).
  - **Action**: Verify actual cluster config and provision real provider/OAuth2/payment secrets in Vault before go-live.

- [ ] **PROD-14: Vault in standalone mode, manual unseal**
  - Production should use HA mode (Raft/Consul backend) and auto-unseal (AWS KMS/GCP KMS) (external infrastructure task).
  - **Action**: Plan migration to HA Vault with auto-unseal.

- [x] **PROD-15: `ingress-traefik` component defaults to `letsencrypt-staging`** ✅ **RESOLVED**
  - Updated `gitops/components/ingress-traefik/ingressroute-template.yaml` `issuerRef.name` to `letsencrypt-prod`.

---

## Dev Environment Issues

### P0 — CRITICAL (Causes runtime failures)

- [x] **DEV-01: Port mismatch between ConfigMap and NetworkPolicy** ✅ **RESOLVED** (`analytics` `8019/9019`, `common-operations` `8018/9018`)
- [x] **DEV-02: `promotion` and `return` external endpoints point to `localhost`** ✅ **RESOLVED** (FQDNs configured in base/overlays; `0` localhost hits)
- [x] **DEV-03: Dapr Redis password overwritten to empty string** ✅ **RESOLVED** (`service-discovery/{pubsub,statestore}-redis.yaml` use `secretKeyRef: redis-credentials/redis-password`)
- [x] **DEV-04: Auth service duplicate image entry with `https://` prefix** ✅ **RESOLVED** (`auth/overlays/dev/kustomization.yaml` cleaned)
- [x] **DEV-05: `review/base/migration-job.yaml` malformed YAML** ✅ **RESOLVED** (valid `resources.limits` and container spec)
- [x] **DEV-06: `fulfillment/base/configmap.yaml` — shell variable won't interpolate** ✅ **RESOLVED** (`${DB_PASSWORD}` removed)
- [x] **DEV-07: Search service — Elasticsearch namespace mismatch** ✅ **RESOLVED** (`search/base/networkpolicy.yaml` & dev patch allow `infrastructure:9200` + `monitoring`)
- [x] **DEV-08: `customer/base/networkpolicy.yaml` — wrong egress ports for Order** ✅ **RESOLVED** (`8004/9004` configured)

### P1 — HIGH (Affects functionality or security)

- [x] **DEV-09: Hardcoded credentials in ConfigMaps** ✅ **RESOLVED**
  - Cleaned plaintext DB/Redis/JWT credentials across all base/dev ConfigMaps (including `common-operations` base/dev and `promotion/overlays/dev/configmap.yaml`, which now relies on `promotion-secrets` `ExternalSecret`); enforced in CI via `gitops/scripts/validate-kustomize.sh`.

- [x] **DEV-10: `review/base/kustomization.yaml` missing `dapr-subscription.yaml`** ✅ **RESOLVED** (`- dapr-subscription.yaml` included)

- [x] **DEV-11: Base configs use short hostnames** ✅ **RESOLVED** (`warehouse`, `fulfillment`, `order`, `review` use `.infrastructure.svc.cluster.local`)

- [x] **DEV-12: Namespace definitions are dead code** ✅ **RESOLVED** (`environments/dev/resources/namespaces-with-env.yaml` uses `{service}-dev` names)

- [x] **DEV-13: `metrics-server.yaml` not in kustomization** ✅ **RESOLVED** (`monitoring/metrics-server.yaml` included in `environments/dev/resources/kustomization.yaml`)

- [x] **DEV-14: Services missing secrets** ✅ **RESOLVED**
  - All backend services use `ExternalSecret` (`vault-backend`); `admin` and `frontend` are static UI bundles (`automountServiceAccountToken: false`); hardened `minio/base/{external-secret,init-job}.yaml` (`sync-wave: "-5"`, `MINIO_ROOT_PASSWORD` via `secretKeyRef: minio-credentials/root-password`, `ttlSecondsAfterFinished: 300`, resource bounds).

- [x] **DEV-15: Redis has no persistence** ✅ **RESOLVED**
  - Added `--dir /data --appendonly yes --appendfsync everysec --save "900 1" --save "300 10"` to `environments/dev/resources/databases/redis-current.yaml`.

### P2 — MEDIUM (Quality & maintainability)

- [x] **DEV-16: Ingress has no TLS** ✅ **RESOLVED**
  - Switched all 5 `IngressRoute` resources in `environments/dev/resources/ingress/ingressroute.yaml` to `entryPoints: [websecure]` with `tls.secretName: microservices-tls-dev` and added `api.tanhdev.com` to `ingress-current.yaml` SAN list.

- [x] **DEV-17: Redis DB allocation collision** ✅ **RESOLVED** (`0` DB collisions across `gitops/apps/*/base/configmap.yaml`)

- [x] **DEV-18: Tracing endpoint inconsistency** ✅ **RESOLVED**
  - Updated remaining `catalog/base/configmap.yaml` and `pricing/base/configmap.yaml` tracing endpoints to `http://jaeger-collector.monitoring.svc.cluster.local:14268/api/traces`.

- [x] **DEV-19: ServiceMonitor port name mismatch** ✅ **RESOLVED** (`0` ServiceMonitors using `port: http-svc`; all standardized to `port: http`)

- [x] **DEV-20: Deprecated `patchesStrategicMerge:` in kustomizations** ✅ **RESOLVED** (`0` `patchesStrategicMerge:` remaining)

- [x] **DEV-21: Secret file naming inconsistent** ✅ **RESOLVED**
  - Standardized all `11` `secret.yaml` files under `gitops/apps/` to `secrets.yaml` and updated all referencing `kustomization.yaml` files (`0` `secret.yaml` remaining under `gitops/apps/`).

- [x] **DEV-22: Alertmanager uses `emptyDir` — state lost on restart** ✅ **RESOLVED**
  - Replaced `emptyDir: {}` in `environments/dev/resources/monitoring/alertmanager.yaml` with `alertmanager-pvc` (`PersistentVolumeClaim`, `1Gi`, `sync-wave: "-5"`).

- [x] **DEV-23: PDB blocks eviction on single-replica monitoring pods** ✅ **RESOLVED**
  - Updated Prometheus, Grafana, and Alertmanager PDBs in `environments/dev/resources/monitoring/pdbs.yaml` from `minAvailable: 1` to `maxUnavailable: 1`.

- [x] **DEV-24: Analytics PDB vs HPA conflict** ✅ **RESOLVED** (`analytics/base/pdb.yaml` uses `maxUnavailable: 1`)

- [x] **DEV-25: Orphaned/duplicate monitoring config files** ✅ **RESOLVED** (`environments/dev/resources/kustomization.yaml` uses `prometheus-alert-rules.yaml` and excludes `critical-services-alerts.yaml`)

- [x] **DEV-26: `postgresql.yaml` malformed** ✅ **RESOLVED**
  - Deleted unreferenced stale `environments/dev/resources/databases/postgresql.yaml` (active dev database uses `databases/postgresql-svc.yaml`).

- [x] **DEV-27: `auth-db.yaml` (CloudNativePG) has duplicate Cluster resource** ✅ **RESOLVED**
  - Merged `serviceAccountTemplate` into the primary `Cluster` spec and removed duplicate `Cluster` block in `environments/dev/resources/databases/postgresql-clusters/auth-db.yaml`.

- [x] **DEV-28: CloudNativePG cluster templates labeled `environment: production`** ✅ **RESOLVED**
  - Updated `18/18` cluster manifests in `environments/dev/resources/databases/postgresql-clusters/` and `databases/redis-sentinel.yaml` to `app.kubernetes.io/environment: dev`.

- [x] **DEV-29: Order service timeout too low (1s)** ✅ **RESOLVED** (`order/base/configmap.yaml` HTTP/gRPC timeouts set to `30s`)

- [x] **DEV-30: PVC size inconsistency for PostgreSQL** ✅ **RESOLVED**
  - Removed stale `environments/dev/resources/databases/postgresql.yaml` (`20Gi` mismatch resolved).

- [x] **DEV-31: Review ConfigMap label is `placeholder` instead of `review`** ✅ **RESOLVED** (`review/base/configmap.yaml` uses `review`)

- [x] **DEV-32: Dapr worker annotations inconsistent** ✅ **RESOLVED**
  - Set `dapr.io/app-port: "5005"` on `user/base/patch-worker.yaml` to match exposed `containerPort: 5005`.

- [x] **DEV-33: Pricing ConfigMap wrong catalog endpoint** ✅ **RESOLVED**
  - Updated `pricing/base/configmap.yaml` catalog endpoint to `catalog.catalog-dev.svc.cluster.local:81` (with production overlay overriding to `catalog.catalog-production.svc.cluster.local:81`).

- [x] **DEV-34: Checkout worker missing `dapr.io/enabled: "true"`** ✅ **RESOLVED** (inherited from `components/common-worker-deployment-v2`)

- [x] **DEV-35: Search sync-job missing `hook-delete-policy`** ✅ **RESOLVED**
  - Added `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded` and reduced `ttlSecondsAfterFinished` to `300` in `search/base/sync-job.yaml`.

---

## Cross-Environment Issues (Base Layer) — All Resolved ✅

| # | Issue | Severity | Status |
|---|---|---|---|
| BASE-01 | NetworkPolicies hardcode `-dev` namespaces in base files | P0 | ✅ Resolved (`0/22` base NPs contain `-dev`) |
| BASE-02 | Plaintext secrets in `customer`/`warehouse`/`common-operations` base configs | P0 | ✅ Resolved (moved to `ExternalSecret`) |
| BASE-03 | Short hostnames in warehouse, fulfillment, order, review base configs | P1 | ✅ Resolved (`.infrastructure.svc.cluster.local`) |
| BASE-04 | `review/base/migration-job.yaml` malformed YAML | P0 | ✅ Resolved |
| BASE-05 | `fulfillment/base/configmap.yaml` uses `${DB_PASSWORD}` shell variable | P0 | ✅ Resolved |
| BASE-06 | `review/base/kustomization.yaml` missing dapr-subscription | P1 | ✅ Resolved |
| BASE-07 | `customer/base/networkpolicy.yaml` wrong order service ports | P0 | ✅ Resolved (`8004/9004`) |
| BASE-08 | `search` ES namespace mismatch (configmap vs networkpolicy) | P0 | ✅ Resolved (`infrastructure:9200` + `monitoring`) |
| BASE-09 | `review/base/configmap.yaml` label still `placeholder` | P2 | ✅ Resolved |
| BASE-10 | `pricing/base/configmap.yaml` wrong catalog endpoint | P2 | ✅ Resolved |

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

## Summary (Updated 2026-11-25)

| Environment | Open P0 | Open P1 | Open P2 | Open Total |
|-------------|---------|---------|---------|------------|
| **Production** | 0 ✅ | 0 ✅ | 2 | **2** (`PROD-13`, `PROD-14` external cluster/Vault infra) |
| **Dev** | 0 ✅ | 0 ✅ | 0 ✅ | **0** |
| **Base (cross-env)** | 0 ✅ | 0 ✅ | 0 ✅ | **0** |
| **Total remaining** | **0** | **0** | **2** | **2** |

> **Verdict**: All GitOps manifest P0 and production P1 blockers are resolved and verified via `kubectl kustomize`. Remaining production go-live work is external infrastructure/secrets provisioning (apply `production-cluster.yaml`, Vault HA + KMS auto-unseal, and populate real OAuth2/Payment provider secrets in Vault).
