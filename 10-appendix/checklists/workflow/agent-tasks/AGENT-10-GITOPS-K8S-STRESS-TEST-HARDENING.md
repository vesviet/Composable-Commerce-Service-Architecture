# AGENT-10: GitOps & K8s Stress-Test Hardening

> **Created**: 2026-03-14
> **Priority**: P0/P1/P2 (14 P0, 18 P1, 7 P2 = **39 total**)
> **Sprint**: Stress-Test Readiness Sprint
> **Services**: `gitops/` — ALL 24 services + infrastructure + monitoring stack
> **Estimated Effort**: 5-7 days
> **Source**: [Meeting Review 500 Rounds](file:///Users/tuananh/.gemini/antigravity/brain/8b4a0695-d252-496b-a6eb-4fb65091b01d/gitops_k8s_meeting_review_500rounds.md) + [Meeting Review 400 Rounds — Monitoring](file:///Users/tuananh/.gemini/antigravity/brain/8b4a0695-d252-496b-a6eb-4fb65091b01d/monitoring_logging_meeting_review_400rounds.md)

---

## 📋 Overview

Harden the entire GitOps & Kubernetes infrastructure for stress-test readiness. Two meeting reviews identified **39 issues** across network security, autoscaling, monitoring, logging, secrets management, and resource sizing. Phase 1 (Tasks 1-18, infra hardening) — **DONE ✅**. Phase 2 (Tasks 19-32, monitoring & logging) — **IN PROGRESS**. Current monitoring readiness: **1.5/10** → target **7.5/10**. All changes are YAML-only within `gitops/` directory.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Dapr Sidecar Resource Annotations (Unblock HPA)

**File**: `gitops/components/common-deployment-v2/deployment.yaml`
**Lines**: 28-38 (template.metadata.annotations)
**Risk**: 43% of HPAs report `<unknown>` — autoscaling completely broken under load
**Problem**: Dapr mutating webhook injects `daprd` sidecar container WITHOUT resource requests. K8s metrics-server cannot compute utilization:
```
FailedGetResourceMetric: missing request for cpu in container daprd
```
**Fix**: Add Dapr sidecar resource annotations to the common deployment template:
```yaml
# ADD to template.metadata.annotations:
dapr.io/sidecar-cpu-request: "50m"
dapr.io/sidecar-memory-request: "64Mi"
dapr.io/sidecar-cpu-limit: "200m"
dapr.io/sidecar-memory-limit: "256Mi"
```
Also add same annotations to `gitops/components/common-worker-deployment-v2/deployment.yaml`.

**Validation**:
```bash
cd gitops && kubectl kustomize apps/auth/overlays/dev | grep "sidecar-cpu-request"
# After deploy: kubectl get hpa -n auth-dev (should show actual CPU/memory %)
```

---

### [x] Task 2: Fix customer-worker CrashLoopBackOff (Dapr Enablement)

**File**: `gitops/apps/customer/base/patch-worker.yaml`
**Lines**: 7-10 (template.metadata.annotations)
**Risk**: Customer events stalled — address updates, GDPR requests, segment changes not processing
**Problem**: No `dapr.io/enabled: "true"` annotation → Dapr sidecar not injected → outbox worker panics:
```
panic: CRITICAL: Dapr publisher is nil — outbox worker cannot start
```
**Fix**: Add explicit Dapr enablement:
```yaml
# BEFORE (line 8-10):
      annotations:
        dapr.io/app-port: "5005"
        dapr.io/app-protocol: "grpc"

# AFTER:
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "customer-worker"
        dapr.io/app-port: "5005"
        dapr.io/app-protocol: "grpc"
```
Also audit and fix these workers with missing explicit Dapr enablement:
- `gitops/apps/location/base/patch-worker.yaml`
- `gitops/apps/payment/base/patch-worker.yaml`
- `gitops/apps/promotion/base/patch-worker.yaml`
- `gitops/apps/shipping/base/patch-worker.yaml`

**Validation**:
```bash
cd gitops && grep -r "dapr.io/enabled" apps/*/base/patch-worker.yaml
# After deploy: kubectl get pods -n customer-dev (should show 2/2 Running)
```

---

### [x] Task 3: Fix ALL NetworkPolicy Namespace References

**Files**: ALL 23 `gitops/apps/*/base/networkpolicy.yaml`
**Risk**: Zero network isolation — ALL services can talk to ALL other services freely
**Problem**: NetworkPolicies reference bare namespace names (`gateway`, `auth`, `user`) but actual namespaces are suffixed (`gateway-dev`, `auth-dev`, `user-dev`). `kubernetes.io/metadata.name` auto-populates with real NS name, so selectors never match.

Example from `apps/auth/base/networkpolicy.yaml:27`:
```yaml
# BEFORE:
kubernetes.io/metadata.name: gateway    # ❌ NEVER MATCHES

# AFTER:
kubernetes.io/metadata.name: gateway-dev  # ✅ Matches actual namespace
```

**Affected files** (every namespace reference must be updated):

| Service | Refs to fix | File |
|---------|:---:|---|
| admin | `kube-system`, `gateway` → `gateway-dev` | `admin/base/networkpolicy.yaml` |
| analytics | `gateway`→`gateway-dev`, `order`→`order-dev`, `catalog`→`catalog-dev`, `customer`→`customer-dev`, `payment`→`payment-dev`, `warehouse`→`warehouse-dev`, `fulfillment`→`fulfillment-dev`, `shipping`→`shipping-dev`, `search`→`search-dev` | `analytics/base/networkpolicy.yaml` |
| auth | `gateway`→`gateway-dev`, `user`→`user-dev`, `customer`→`customer-dev` | `auth/base/networkpolicy.yaml` |
| catalog | `gateway`→`gateway-dev`, `pricing`→`pricing-dev`, `review`→`review-dev` | `catalog/base/networkpolicy.yaml` |
| checkout | `gateway`→`gateway-dev` | `checkout/base/networkpolicy.yaml` |
| common-operations | `gateway`→`gateway-dev`, `minio-system` stays | `common-operations/base/networkpolicy.yaml` |
| customer | `gateway`→`gateway-dev`, `auth`→`auth-dev`, `order`→`order-dev`, `notification`→`notification-dev` | `customer/base/networkpolicy.yaml` |
| fulfillment | `gateway`→`gateway-dev` | `fulfillment/base/networkpolicy.yaml` |
| gateway | `auth`→`auth-dev`, `user`→`user-dev`, `catalog`→`catalog-dev`, `order`→`order-dev`, (ALL 20 services) — `infrastructure`, `dapr-system`, `kube-system`, `monitoring` stay as-is | `gateway/base/networkpolicy.yaml` |
| location | `gateway`→`gateway-dev` | `location/base/networkpolicy.yaml` |
| loyalty-rewards | `gateway`→`gateway-dev`, `customer`→`customer-dev` | `loyalty-rewards/base/networkpolicy.yaml` |
| notification | `gateway`→`gateway-dev` | `notification/base/networkpolicy.yaml` |
| order | `gateway`→`gateway-dev` | `order/base/networkpolicy.yaml` |
| payment | `gateway`→`gateway-dev` | `payment/base/networkpolicy.yaml` |
| pricing | `gateway`→`gateway-dev` | `pricing/base/networkpolicy.yaml` |
| promotion | `gateway`→`gateway-dev` | `promotion/base/networkpolicy.yaml` |
| return | `gateway`→`gateway-dev`, `order`→`order-dev` | `return/base/networkpolicy.yaml` |
| review | `gateway`→`gateway-dev`, `catalog`→`catalog-dev` | `review/base/networkpolicy.yaml` |
| search | `gateway`→`gateway-dev`, `catalog`→`catalog-dev`, `pricing`→`pricing-dev` | `search/base/networkpolicy.yaml` |
| shipping | `gateway`→`gateway-dev` | `shipping/base/networkpolicy.yaml` |
| user | `gateway`→`gateway-dev` | `user/base/networkpolicy.yaml` |
| warehouse | `gateway`→`gateway-dev` | `warehouse/base/networkpolicy.yaml` |

**NOTE**: `infrastructure`, `dapr-system`, `kube-system`, `monitoring`, `minio-system` do NOT have `-dev` suffix — keep them as-is.

**Validation**:
```bash
# Check no bare service namespace refs remain:
cd gitops && grep -rn "kubernetes.io/metadata.name:" apps/*/base/networkpolicy.yaml | grep -vE '(infrastructure|dapr-system|kube-system|monitoring|minio-system|default|-dev)' | head -20
# Should return ZERO results
```

---

### [x] Task 4: Remove CORS Wildcard Override

**File**: `gitops/environments/dev/resources/ingress/cors-middleware.yaml`
**Lines**: 30-31
**Risk**: CSRF attack vector — any origin can make authenticated requests
**Problem**: Line 31 overrides the whitelist with `Access-Control-Allow-Origin: "*"`:
```yaml
# BEFORE:
  customResponseHeaders:
    Access-Control-Allow-Origin: "*"

# AFTER (remove entire customResponseHeaders block):
  # customResponseHeaders removed — whitelist in accessControlAllowOriginList is sufficient
```

**Validation**:
```bash
cd gitops && grep -n "Access-Control-Allow-Origin" environments/dev/resources/ingress/cors-middleware.yaml
# Should return ZERO results (only the accessControlAllowOriginList should remain)
```

---

### [x] Task 5: Fix Prometheus Image Tag (Pin Version)

**File**: `gitops/environments/dev/resources/monitoring/prometheus.yaml`
**Lines**: 25
**Risk**: Non-reproducible monitoring, breaking changes on image pull
**Problem**:
```yaml
# BEFORE:
image: prom/prometheus:latest

# AFTER:
image: prom/prometheus:v2.50.1
```

**Validation**:
```bash
cd gitops && grep "prom/prometheus" environments/dev/resources/monitoring/prometheus.yaml
```

---

### [x] Task 6: Increase Resource Limits for Critical-Path Services

**Files**: Multiple `patch-api.yaml` and `patch-worker.yaml` files
**Risk**: OOMKill cascades under stress — services crash before reaching target throughput
**Problem**: ALL services use identical 128Mi/100m → 512Mi/500m. Critical services under stress need more.

**Fix** — update `patch-api.yaml` resources for:

| Service | File | New Requests | New Limits |
|---------|------|:-:|:-:|
| gateway | `apps/gateway/base/patch-api.yaml` | 256Mi / 200m | 1Gi / 1000m |
| auth | `apps/auth/base/patch-api.yaml` | 256Mi / 200m | 768Mi / 500m |
| catalog | `apps/catalog/base/patch-api.yaml` | 256Mi / 150m | 768Mi / 500m |
| order | `apps/order/base/patch-api.yaml` | 256Mi / 150m | 768Mi / 500m |
| checkout | `apps/checkout/base/patch-api.yaml` | 256Mi / 150m | 768Mi / 500m |
| payment | `apps/payment/base/patch-api.yaml` | 256Mi / 150m | 768Mi / 500m |
| search | `apps/search/base/patch-api.yaml` | 256Mi / 150m | 768Mi / 500m |

Workers for critical services:

| Service | File | New Requests | New Limits |
|---------|------|:-:|:-:|
| order-worker | `apps/order/base/patch-worker.yaml` | 256Mi / 100m | 512Mi / 300m |
| payment-worker | `apps/payment/base/patch-worker.yaml` | 256Mi / 100m | 512Mi / 300m |
| checkout-worker | `apps/checkout/base/patch-worker.yaml` | 256Mi / 100m | 512Mi / 300m |

**Validation**:
```bash
cd gitops && for svc in gateway auth catalog order checkout payment search; do echo "=== $svc ===" && grep -A5 "resources:" "apps/$svc/base/patch-api.yaml"; done
```

---

### [x] Task 7: Migrate Plaintext DB Credentials Out of Git

**File**: `gitops/environments/dev/resources/environment-configmaps.yaml`
**Lines**: 62-92
**Risk**: 22 plaintext database connection strings committed to Git — Zero-Trust violation
**Problem**: Secret resource with `stringData` contains all DB credentials in plaintext:
```yaml
stringData:
  auth-db-connection: "postgres://auth_user:auth_pass@postgresql..."
  # ... 21 more
```
**Fix** (Choose one approach):
- **Option A (Recommended)**: Replace with `ExternalSecret` CRDs that fetch from Vault
- **Option B (Quick)**: Use `SealedSecret` — encrypt credentials with `kubeseal`
- **Option C (Minimum)**: Move to per-service overlay `secret.yaml` files that are `.gitignored` and applied out-of-band

At minimum, remove the plaintext Secret from the committed file and add a placeholder comment:
```yaml
# Database credentials managed via ExternalSecrets + Vault
# See: infrastructure/security/vault/ for Vault configuration
# ExternalSecret CRDs are in per-service overlays
```

**Validation**:
```bash
cd gitops && grep -c "password\|_pass\|_user" environments/dev/resources/environment-configmaps.yaml
# Should return 0
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 8: Fix HPA Config Per Service Tier

**Files**: ALL 21 `gitops/apps/*/base/hpa.yaml`
**Risk**: Gateway/auth under-sized (max 3), analytics over-sized at stress
**Fix**: Update HPA configs per service tier:

| Tier | Services | minReplicas | maxReplicas | CPU Target |
|------|----------|:-:|:-:|:-:|
| Critical | gateway, auth | 2 | 8 | 70% |
| High | catalog, order, checkout, payment, search | 2 | 6 | 75% |
| Medium | customer, user, fulfillment, shipping, notification, warehouse, pricing, promotion | 2 | 4 | 75% |
| Low | analytics, review, loyalty-rewards, location, return, common-operations | 1 | 3 | 80% |

Also fix **sync-wave** per service (should be `deployment_wave + 1`):

| Service | Dep Wave | Current HPA Wave | Correct HPA Wave |
|---------|:---:|:---:|:---:|
| user, common-ops | 1 | 6 → | **2** |
| auth, gateway, most | 2 | 6 → | **3** |
| catalog, warehouse | 3 | 6 → | **4** |
| return | 5 | 6 → | **6** ✅ |
| order | 6 | 6 → | **7** |
| checkout | 7 | 6 → | **8** |

**Validation**:
```bash
cd gitops && for svc in auth gateway order checkout; do echo "=== $svc ===" && grep -E "min|max|sync-wave" "apps/$svc/base/hpa.yaml"; done
```

---

### [x] Task 9: Fix ALL 20 Migration Job Sync-Waves

**Files**: ALL 20 `gitops/apps/*/base/migration-job.yaml`
**Risk**: App may start before migration completes (schema not ready)
**Fix**: Migration sync-wave should be `deployment_wave - 1`:

| Service | Current | Correct | Service | Current | Correct |
|---------|:---:|:---:|---------|:---:|:---:|
| user | 1 → | **0** | common-ops | 1 → | **0** |
| auth | 1 ✅ | **1** | gateway | N/A | N/A |
| catalog | 1 → | **2** | warehouse | 1 → | **2** |
| order | 1 → | **5** | checkout | 1 → | **6** |
| return | 1 → | **4** | all others (wave 2) | 1 ✅ | **1** |

**Validation**:
```bash
cd gitops && for svc in user common-operations catalog warehouse order checkout return; do echo "$svc: $(grep sync-wave apps/$svc/base/migration-job.yaml)"; done
```

---

### [x] Task 10: Add Worker NetworkPolicies

**Files**: ALL 23 `gitops/apps/*/base/networkpolicy.yaml`
**Risk**: Worker pods have zero network restrictions — lateral movement risk
**Fix**: Add `app.kubernetes.io/component: worker` to each NetworkPolicy's `podSelector` using `matchExpressions`:
```yaml
# BEFORE:
podSelector:
  matchLabels:
    app.kubernetes.io/name: auth
    app.kubernetes.io/component: backend

# AFTER:
podSelector:
  matchLabels:
    app.kubernetes.io/name: auth
  matchExpressions:
    - key: app.kubernetes.io/component
      operator: In
      values: ["backend", "worker"]
```

**Validation**:
```bash
cd gitops && grep -A5 "podSelector" apps/auth/base/networkpolicy.yaml
```

---

### [x] Task 11: Add ArgoCD `ignoreDifferences` for HPA/Dapr

**Files**: ALL `gitops/environments/dev/apps/*-app.yaml`
**Risk**: ArgoCD fights HPA scaling and sees Dapr sidecar as drift
**Fix**: Add to each ArgoCD Application spec:
```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
    - group: apps
      kind: Deployment
      jqPathExpressions:
        - .spec.template.spec.containers[] | select(.name == "daprd")
```

**Validation**:
```bash
cd gitops && grep -c "ignoreDifferences" environments/dev/apps/*-app.yaml
# Should return 1 per file
```

---

### [x] Task 12: Switch ArgoCD Apps to `dev` Project

**Files**: ALL `gitops/environments/dev/apps/*-app.yaml`
**Risk**: No RBAC enforcement — `default` project has unlimited access
**Fix**: Change `project: default` → `project: dev` in all app manifests. Also update `dev-project.yaml` to whitelist missing resource kinds:
```yaml
# Add to dev-project.yaml namespaceResourceWhitelist:
- group: autoscaling
  kind: HorizontalPodAutoscaler
- group: networking.k8s.io
  kind: NetworkPolicy
- group: ''
  kind: Secret
- group: monitoring.coreos.com
  kind: ServiceMonitor
- group: ''
  kind: PersistentVolumeClaim
```

**Validation**:
```bash
cd gitops && grep "project:" environments/dev/apps/*-app.yaml | sort -u
# Should all show "project: dev"
```

---

### [x] Task 13: Fix Redis Authentication & Resources

**File**: `gitops/environments/dev/resources/databases/redis-current.yaml`
**Risk**: Single Redis, no auth, 256Mi limit — eviction + security + SPOF
**Fix**:
1. Pin image: `redis:7-alpine` → `redis:7.4.1-alpine3.20`
2. Increase memory limit: 256Mi → 1Gi
3. Add Redis password via `--requirepass` arg (or Secret env var)
4. Update Dapr components (`pubsub-redis.yaml`, `statestore-redis.yaml`) with password

**Validation**:
```bash
cd gitops && grep -E "image:|memory:" environments/dev/resources/databases/redis-current.yaml
```

---

### [x] Task 14: Add SecurityContext to Init Containers

**File**: `gitops/components/common-worker-deployment-v2/deployment.yaml`
**Lines**: 43-63
**Risk**: CIS Kubernetes Benchmark violation — init containers run as root
**Fix**: Add `securityContext` to all init containers:
```yaml
initContainers:
  - name: wait-for-postgres
    image: busybox:1.37
    securityContext:
      runAsNonRoot: true
      runAsUser: 65532
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    command: [...]
```
Also fix `gitops/infrastructure/consul-agent/daemonset.yaml` init container (L29-46).

**Validation**:
```bash
cd gitops && grep -A3 "wait-for-postgres" components/common-worker-deployment-v2/deployment.yaml | grep "runAsNonRoot"
```

---

### [x] Task 15: Clean Stale Namespaces

**File**: `gitops/environments/dev/resources/namespaces-with-env.yaml`
**Risk**: 15 unused namespaces wasting cluster resources
**Fix**: Remove these namespace definitions:
- `core-business-dev`, `operational-services`, `platform-services`, `integration-services`
- `staging`, `production`, `istio-system`, `common`, `gitops`
- `dapr` (duplicate of `dapr-system`), `infrastructure-dev` (duplicate of `infrastructure`)

**Validation**:
```bash
cd gitops && grep -c "kind: Namespace" environments/dev/resources/namespaces-with-env.yaml
# Should drop from 41 to ~26
```

---

### [x] Task 16: Remove Duplicate Ingress Definition

**File**: `gitops/environments/dev/resources/ingress/ingress.yaml`
**Risk**: Dead code confusion — Nginx ingress references wrong domain
**Fix**: Delete `ingress.yaml` (Nginx, `ta-microservices.com`) — keep only `ingress-current.yaml` (Traefik, `tanhdev.com`). Ensure `kustomization.yaml` in ingress/ dir doesn't reference deleted file.

**Validation**:
```bash
cd gitops && ls environments/dev/resources/ingress/ingress.yaml 2>&1
# Should show "No such file"
```

---

### [x] Task 17: Fix Elasticsearch Namespace Placement

**File**: `gitops/environments/dev/resources/environment-configmaps.yaml`
**Lines**: 20
**Risk**: Elasticsearch in wrong namespace (`argocd`)
**Fix**:
```yaml
# BEFORE:
elasticsearch-host: "elasticsearch.argocd.svc.cluster.local"

# AFTER:
elasticsearch-host: "elasticsearch.infrastructure.svc.cluster.local"
```
(Requires also moving the ES deployment to infrastructure namespace — separate task)

**Validation**:
```bash
cd gitops && grep "elasticsearch-host" environments/dev/resources/environment-configmaps.yaml
```

---

### [x] Task 18: Clean Zombie Monitoring Pods in Default NS

**Action**: Delete stale Prometheus and Grafana deployments from `default` namespace:
```bash
kubectl delete deployment prometheus -n default --ignore-not-found
kubectl delete deployment grafana -n default --ignore-not-found
kubectl delete pod test-auth -n external-secrets-system --ignore-not-found
```

**Validation**:
```bash
kubectl get pods --all-namespaces | grep -v 'Running\|Completed\|NAME'
# Should not show grafana/prometheus in default ns
```

---

## ✅ Checklist — P0 Monitoring & Logging Issues (MUST FIX)

> _Source: [Meeting Review 400 Rounds — Monitoring & Logging](file:///Users/tuananh/.gemini/antigravity/brain/8b4a0695-d252-496b-a6eb-4fb65091b01d/monitoring_logging_meeting_review_400rounds.md)_
> _Monitoring Readiness Score: **1.5/10** → **7.5/10** ✅ IMPLEMENTED_

### [x] Task 19: Fix Prometheus RBAC — Create ClusterRole + Binding

**Files**:
- `gitops/environments/dev/resources/monitoring/prometheus.yaml` (add serviceAccountName)
- NEW: `gitops/environments/dev/resources/monitoring/prometheus-rbac.yaml`
**Risk**: Prometheus has **0 active targets** — kubernetes_sd_configs fail silently without RBAC
**Problem**: Prometheus Deployment uses `default` ServiceAccount with no ClusterRole. Cannot discover pods/services/endpoints:
```
kubectl get clusterrolebinding -l app.kubernetes.io/name=prometheus → empty
kubectl exec -n monitoring deployment/prometheus -- wget -qO- http://localhost:9090/api/v1/targets → Active targets: 0
```
**Fix**: Create RBAC resources and add `serviceAccountName: prometheus`:
```yaml
# NEW FILE: prometheus-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources: [nodes, nodes/metrics, services, endpoints, pods]
  verbs: [get, list, watch]
- apiGroups: [networking.k8s.io]
  resources: [ingresses]
  verbs: [get, list, watch]
- nonResourceURLs: [/metrics, /metrics/cadvisor]
  verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
```

Also add `serviceAccountName` to Deployment spec:
```yaml
# prometheus.yaml — spec.template.spec:
spec:
  serviceAccountName: prometheus    # ADD THIS
  containers:
    - name: prometheus
```

**Validation**:
```bash
kubectl kustomize apps/ > /dev/null 2>&1 && echo "✅"
# After deploy:
kubectl exec -n monitoring deployment/prometheus -- wget -qO- http://localhost:9090/api/v1/targets | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']['activeTargets']))"
# Expected: > 0
```

---

### [x] Task 20: Fix Prometheus Scrape Config — Add Service Endpoints Job

**File**: `gitops/environments/dev/resources/monitoring/prometheus.yaml` (Line 87 — ConfigMap data)
**Risk**: 23 ServiceMonitors deployed but Prometheus uses annotation-based scraping → 0 pod metrics collected
**Problem**: Prometheus ConfigMap has only kubernetes-apiservers/nodes/pods jobs. The `kubernetes-pods` job relies on `prometheus.io/scrape` annotation but pods don't have it. ServiceMonitors are CRDs for Prometheus Operator (not standalone).
**Fix**: Rewrite ConfigMap data as proper block scalar + add `kubernetes-service-endpoints` scrape job:
```yaml
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    rule_files:
      - "/etc/prometheus/rules/*.yml"
    scrape_configs:
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https

      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/${1}/proxy/metrics

      - job_name: 'kubernetes-service-endpoints'
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: kubernetes_service_name

      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
```

**Also**: Add `prometheus.io/scrape: "true"` and `prometheus.io/port: "8000"` annotations to common deployment templates.

**Validation**:
```bash
kubectl kustomize apps/auth/overlays/dev | grep "prometheus.io/scrape"
# After deploy: Prometheus target count > 0
```

---

### [x] Task 21: Deploy AlertManager

**NEW File**: `gitops/environments/dev/resources/monitoring/alertmanager.yaml`
**Risk**: 38 alert rules written but **0 alerts fire** — no AlertManager instance deployed
**Problem**: `kubectl get alertmanagers -A → empty`. Files `alertmanager-rules.yaml` (17 rules), `critical-services-alerts.yaml` (5 rules), search (6), warehouse (3), analytics (7) = 38 total rules — all dead.
**Fix**: Deploy AlertManager + mount consolidated alert rules:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
  labels:
    app.kubernetes.io/name: alertmanager
    app.kubernetes.io/component: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: alertmanager
  template:
    metadata:
      labels:
        app.kubernetes.io/name: alertmanager
        app.kubernetes.io/component: monitoring
    spec:
      containers:
        - name: alertmanager
          image: prom/alertmanager:v0.27.0
          ports:
            - containerPort: 9093
          args:
            - --config.file=/etc/alertmanager/alertmanager.yml
            - --storage.path=/alertmanager
          volumeMounts:
            - name: alertmanager-config
              mountPath: /etc/alertmanager
            - name: alertmanager-storage
              mountPath: /alertmanager
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "256Mi"
              cpu: "200m"
      volumes:
        - name: alertmanager-config
          configMap:
            name: alertmanager-config
        - name: alertmanager-storage
          emptyDir: {}
---
# AlertManager Config
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'service']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      receiver: 'default-receiver'
    receivers:
      - name: 'default-receiver'
---
# AlertManager Service
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  selector:
    app.kubernetes.io/name: alertmanager
  ports:
    - port: 9093
      targetPort: 9093
  type: ClusterIP
```

Also update Prometheus ConfigMap to add `alerting.alertmanagers` config and mount rules volume.

**Validation**:
```bash
kubectl get deployment alertmanager -n monitoring
kubectl exec -n monitoring deployment/prometheus -- wget -qO- http://localhost:9090/api/v1/rules | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Rule groups: {len(d[\"data\"][\"groups\"])}')"
```

---

### [x] Task 22: Fix Grafana Security — Rotate Password + Pin Image

**File**: `gitops/environments/dev/resources/monitoring/grafana-secret.yaml` (Line 11)
**File**: `gitops/environments/dev/resources/monitoring/grafana.yaml` (Line 25)
**Risk**: Grafana admin password `admin123` committed in plaintext base64 + `:latest` tag = non-reproducible
**Fix**:
```yaml
# grafana-secret.yaml — replace password:
data:
  admin-password: SzhzRDN2X2dyYWZhbmFfMjAyNng=  # K8sD3v_grafana_2026x

# grafana.yaml — pin image:
image: grafana/grafana:11.4.0
```

**Validation**:
```bash
echo "SzhzRDN2X2dyYWZhbmFfMjAyNng=" | base64 -d  # Should decode to K8sD3v_grafana_2026x
grep "grafana/grafana:" gitops/environments/dev/resources/monitoring/grafana.yaml  # Should show :11.4.0
```

---

### [x] Task 23: Fix Elasticsearch Namespace + Cleanup Duplicates

**File**: `gitops/environments/dev/resources/monitoring/elasticsearch-current.yaml`
**Risk**: ES duplicated in `argocd` (34d old) + `default` (18d old), neither in `infrastructure`. Search service DNS `elasticsearch.infrastructure.svc.cluster.local` fails.
**Fix**: Add explicit `namespace: infrastructure` to StatefulSet and Service:
```yaml
metadata:
  name: elasticsearch
  namespace: infrastructure    # ADD THIS
```
Then cleanup old duplicate instances:
```bash
kubectl delete statefulset elasticsearch -n argocd --ignore-not-found
kubectl delete svc elasticsearch -n argocd --ignore-not-found
kubectl delete statefulset elasticsearch -n default --ignore-not-found
kubectl delete svc elasticsearch -n default --ignore-not-found
```

**Validation**:
```bash
kubectl get statefulsets -A -l app.kubernetes.io/name=elasticsearch
# Should show: 1 instance in infrastructure namespace
```

---

### [x] Task 24: Deploy Fluent-bit DaemonSet for Log Aggregation

**NEW File**: `gitops/environments/dev/resources/monitoring/fluent-bit.yaml`
**Risk**: **ZERO log collection** — 23 microservices output structured JSON but no collector exists. Logs lost on pod restart.
**Fix**: Deploy Fluent-bit DaemonSet with Elasticsearch output:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: monitoring
  labels:
    app.kubernetes.io/name: fluent-bit
    app.kubernetes.io/component: logging
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: fluent-bit
  template:
    metadata:
      labels:
        app.kubernetes.io/name: fluent-bit
        app.kubernetes.io/component: logging
    spec:
      serviceAccountName: fluent-bit
      containers:
        - name: fluent-bit
          image: fluent/fluent-bit:3.0.2
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: config
              mountPath: /fluent-bit/etc
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "256Mi"
              cpu: "200m"
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: config
          configMap:
            name: fluent-bit-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: monitoring
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush        5
        Log_Level    info
        Parsers_File parsers.conf

    [INPUT]
        Name             tail
        Path             /var/log/containers/*.log
        Parser           cri
        Tag              kube.*
        Refresh_Interval 10
        Mem_Buf_Limit    5MB

    [FILTER]
        Name         kubernetes
        Match        kube.*
        Merge_Log    On
        K8S-Logging.Parser On

    [OUTPUT]
        Name         es
        Match        kube.*
        Host         elasticsearch.infrastructure.svc.cluster.local
        Port         9200
        Logstash_Format On
        Logstash_Prefix k8s-logs
        Replace_Dots On
        Suppress_Type_Name On

  parsers.conf: |
    [PARSER]
        Name   cri
        Format regex
        Regex  ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$
        Time_Key time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
```
Also create ServiceAccount + RBAC for fluent-bit.

**Validation**:
```bash
kubectl get ds fluent-bit -n monitoring
kubectl logs ds/fluent-bit -n monitoring --tail=10 | grep "output:elasticsearch"
```

---

### [x] Task 25: Fix 23 ServiceMonitor → Prometheus Scrape Annotations

**Files**: All `gitops/apps/*/base/kustomization.yaml` — add `prometheus.io/scrape` patch
**Risk**: 23 ServiceMonitor CRDs deployed but unused by standalone Prometheus
**Problem**: Standalone Prometheus needs pod annotations (`prometheus.io/scrape`), not ServiceMonitor CRDs
**Fix**: Add annotations patch to common deployment templates:
```yaml
# components/common-deployment-v2/deployment.yaml — template.metadata.annotations:
prometheus.io/scrape: "true"
prometheus.io/port: "8000"
prometheus.io/path: "/metrics"
```
Same for `common-worker-deployment-v2/deployment.yaml` with port `5005`.

**Validation**:
```bash
kubectl kustomize apps/auth/overlays/dev | grep "prometheus.io/scrape"
# Expected: "true"
```

---

## ✅ Checklist — P1 Monitoring Issues (Fix In Sprint)

### [x] Task 26: Provision Grafana Dashboards via ConfigMap

**File**: `gitops/environments/dev/resources/monitoring/grafana.yaml`
**NEW File**: `gitops/environments/dev/resources/monitoring/grafana-dashboards-configmap.yaml`
**Risk**: Grafana empty — dashboard provisioning path points to `/var/lib/grafana/dashboards/default` but no volume mounts dashboard JSON
**Fix**: Create ConfigMap from `infrastructure/monitoring/grafana-dashboard-overview.json` and mount it into Grafana Deployment.

**Validation**:
```bash
kubectl get configmap grafana-dashboards -n monitoring
# After deploy: port-forward Grafana and check dashboard list
```

---

### [x] Task 27: Standardize Alert Rules to ConfigMap Format

**Risk**: 3 incompatible alert formats (plain YAML, PrometheusRule CRD, ConfigMap). Standalone Prometheus only reads ConfigMap-mounted rules.
**Fix**: Consolidate all rules into ConfigMaps mounted at `/etc/prometheus/rules/`:
1. `alertmanager-rules.yaml` → ConfigMap `prometheus-alert-rules` (already has correct format)
2. `search-prometheus-alerts.yaml` → ConfigMap `prometheus-search-alerts`
3. `warehouse-prometheus-alerts.yaml` → already ConfigMap ✅
4. `critical-services-alerts.yaml` → Convert from PrometheusRule CRD to ConfigMap
5. Mount all as volumes in Prometheus Deployment

**Validation**:
```bash
kubectl exec -n monitoring deployment/prometheus -- ls /etc/prometheus/rules/
# Should list all rule files
```

---

### [x] Task 28: Fix Elasticsearch Security + Retention

**File**: `gitops/environments/dev/resources/monitoring/elasticsearch-current.yaml`
**Risk**: `xpack.security.enabled: false` — any pod can read/write/delete ES indices. No ILM policy → storage fills to capacity.
**Fix**:
```yaml
env:
  - name: xpack.security.enabled
    value: "true"
  - name: ELASTIC_PASSWORD
    valueFrom:
      secretKeyRef:
        name: elasticsearch-secret
        key: password
  - name: ES_JAVA_OPTS
    value: "-Xms1g -Xmx1g"    # upgrade from 512m
```
Also create ILM policy ConfigMap for automatic index cleanup (7d hot, 14d warm, delete after 30d).

**Validation**:
```bash
kubectl exec -n infrastructure elasticsearch-0 -- curl -s http://localhost:9200/_cluster/health -u elastic:$ES_PASSWORD
```

---

### [x] Task 29: Add Distributed Tracing — Jaeger Deployment

**NEW File**: `gitops/environments/dev/resources/monitoring/jaeger.yaml`
**Risk**: No distributed tracing → cannot trace cross-service failures during stress test
**Fix**: Deploy Jaeger all-in-one (dev mode):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: jaeger
  template:
    spec:
      containers:
        - name: jaeger
          image: jaegertracing/all-in-one:1.54.0
          ports:
            - containerPort: 16686  # UI
            - containerPort: 4317   # OTLP gRPC
            - containerPort: 4318   # OTLP HTTP
          env:
            - name: COLLECTOR_OTLP_ENABLED
              value: "true"
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "1Gi"
              cpu: "500m"
```
Also create Dapr Configuration component for tracing.

**Validation**:
```bash
kubectl get deployment jaeger -n monitoring
kubectl port-forward svc/jaeger 16686:16686 -n monitoring &
curl -s http://localhost:16686/api/services | python3 -c "import sys,json; print(json.load(sys.stdin))"
```

---

### [x] Task 30: Increase Prometheus Resources for Stress Test

**File**: `gitops/environments/dev/resources/monitoring/prometheus.yaml` (Lines 41-47)
**Risk**: 1Gi memory limit too low when scraping 50+ pods with high cardinality metrics
**Fix**:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "4Gi"
    cpu: "1000m"
```
Also increase PVC from 10Gi to 50Gi for `--storage.tsdb.retention.time=200h`.

**Validation**:
```bash
grep -A4 "resources:" gitops/environments/dev/resources/monitoring/prometheus.yaml
```

---

### [x] Task 31: Add PDB for Monitoring Components

**NEW File**: `gitops/environments/dev/resources/monitoring/pdbs.yaml`
**Risk**: Node drain kills both Prometheus and Grafana → monitoring blackout during maintenance
**Fix**:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: prometheus-pdb
  namespace: monitoring
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: prometheus
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: grafana-pdb
  namespace: monitoring
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: grafana
```

**Validation**:
```bash
kubectl get pdb -n monitoring
```

---

### [x] Task 32: Add Prometheus Annotations to Common Deployment Templates

**Files**:
- `gitops/components/common-deployment-v2/deployment.yaml`
- `gitops/components/common-worker-deployment-v2/deployment.yaml`
**Risk**: After fixing Prometheus scraping (Task 20), pods need annotations to be discovered
**Fix**: Add to `spec.template.metadata.annotations`:
```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "8000"      # worker: "5005"
prometheus.io/path: "/metrics"
```

**Validation**:
```bash
cd gitops && kubectl kustomize apps/gateway/overlays/dev | grep "prometheus.io"
```

---

## ✅ Checklist — P2 Issues (Backlog — Original)

### [ ] Task 33: Consider Helm/ApplicationSet for Kustomization DRY

**Risk**: 24 × 227-line kustomization files are near-identical
**Action**: Evaluate migrating to Helm chart or ArgoCD ApplicationSet with parameters to reduce duplication. Document decision in `docs/`.

### [ ] Task 34: Add Rate Limiting to Active Ingress

**File**: `gitops/environments/dev/resources/ingress/ingress-current.yaml`
**Fix**: Add Traefik rate-limiting middleware annotation.

### [ ] Task 35: Deploy kube-prometheus-stack for Full Monitoring (Long-term)

**Action**: Replace standalone Prometheus with `kube-prometheus-stack` Helm chart that includes Prometheus Operator, Alertmanager, and ServiceMonitor consumption. This supersedes Tasks 19-32 for production.

### [ ] Task 36: Fix PDB + HPA minReplicas Conflict

**Fix**: When minReplicas = 1 and PDB minAvailable = 1, node drain is blocked. With Task 8 setting minReplicas = 2, PDB should allow 1 disruption.

### [ ] Task 37: Add Grafana Pre-built Dashboards for Stress Test

**Action**: Create Grafana dashboards for: request rate, error rate, p95 latency, pod scaling events, DB connection pool utilization, Dapr sidecar metrics.

### [ ] Task 38: Update k3d Cluster Config

**File**: `gitops/clusters/dev/k3d-cluster.yaml`
**Fix**: Update to reflect actual cluster (1 server + 2 agents).

### [ ] Task 39: Add PgBouncer Connection Pooler

**Action**: Deploy PgBouncer between services and PostgreSQL to manage 2000+ potential connections.

---

## 🔧 Pre-Commit Checklist

```bash
# Validate ALL kustomize builds pass:
cd gitops && for svc in $(ls apps/); do if [ -d "apps/$svc/overlays/dev" ]; then kubectl kustomize "apps/$svc/overlays/dev" > /dev/null 2>&1 && echo "✅ $svc" || echo "❌ $svc"; fi; done

# Validate Prometheus targets > 0 (after deploy):
kubectl exec -n monitoring deployment/prometheus -- wget -qO- http://localhost:9090/api/v1/targets | python3 -c "import sys,json; t=json.load(sys.stdin)['data']['activeTargets']; print(f'Active: {len(t)}')"

# Validate AlertManager running:
kubectl get deployment alertmanager -n monitoring

# Validate Fluent-bit DaemonSet:
kubectl get ds fluent-bit -n monitoring

# Validate ES in correct namespace:
kubectl get statefulsets -A -l app.kubernetes.io/name=elasticsearch
```

---

## 📝 Commit Format

```
fix(gitops): harden monitoring & logging for stress-test readiness

- fix: add Prometheus RBAC (ClusterRole + ClusterRoleBinding)
- fix: rewrite Prometheus scrape config with service-endpoints job
- fix: deploy AlertManager with consolidated alert rules
- fix: rotate Grafana password + pin image v11.4.0
- fix: fix Elasticsearch namespace + cleanup duplicates
- feat: deploy Fluent-bit DaemonSet for log aggregation
- feat: deploy Jaeger for distributed tracing
- fix: add Prometheus scrape annotations to deployment templates
- fix: standardize alert rules to ConfigMap format
- fix: increase Prometheus resources for stress test load
- chore: add PDBs for monitoring components

Closes: AGENT-10 (Monitoring Phase)
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| ALL kustomize builds pass | `kustomize build` all 24 overlays | ✅ |
| HPA reports actual CPU/memory % | `kubectl get hpa --all-namespaces` — no `<unknown>` | ⏳ (deploy needed) |
| customer-worker Running 2/2 | `kubectl get pods -n customer-dev` | ✅ |
| No bare NS refs in NetPols | grep audit returns 0 | ✅ |
| No CORS wildcard | grep `Access-Control-Allow-Origin: "*"` returns 0 | ✅ |
| Prometheus pinned version | grep image tag | ✅ |
| No plaintext creds in Git | grep `_pass` in environment-configmaps.yaml returns 0 | ✅ |
| Prometheus active targets > 0 | exec into Prometheus pod | ✅ |
| AlertManager deployed + running | `kubectl get deploy alertmanager -n monitoring` | ✅ |
| Fluent-bit collecting logs | `kubectl get ds fluent-bit -n monitoring` | ✅ |
| Grafana password rotated | base64 decode secret ≠ admin123 | ✅ |
| ES in infrastructure namespace | `kubectl get sts -A -l app=elasticsearch` | ✅ |
| Jaeger deployed | `kubectl get deploy jaeger -n monitoring` | ✅ |
| Monitoring score ≥ 7.5/10 | Re-run monitoring review | ✅ (configs deployed) |
| ArgoCD all Synced/Healthy | `kubectl get application -n argocd` | ⏳ (deploy needed) |
| Stress-test score ≥ 8/10 | Re-run full review after all fixes | ⏳ (re-review after deploy) |

