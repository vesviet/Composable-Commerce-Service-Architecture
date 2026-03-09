# AGENT-24 — GitOps & Amazon-Scale Infrastructure Hardening

> **Created**: 2026-03-09
> **Updated**: 2026-03-09
> **Priority**: P0 (Vault) → P1 (Zero-Downtime, KEDA, Canary)
> **Sprint**: Infrastructure Hardening Sprint
> **Scope**: `gitops/` directory — Vault, Kustomize components, KEDA, Argo Rollouts
> **Estimated Effort**: 5–6 days
> **Source**: AWS Well-Architected Review (Reliability & Operational Excellence pillars)

---

## 👑 REQUIRED ROLE: SENIOR DEVOPS ENGINEER & CLOUD ARCHITECT

For the Agent taking on this task, you MUST adopt the following persona and skillset:
- **Title**: Principal DevOps / Platform Engineer.
- **Expertise**: Kubernetes, ArgoCD, Argo Rollouts, KEDA, HashiCorp Vault, Kustomize, Helm.
- **Mindset**: "Zero-Downtime, Self-Healing, and Immutable Infrastructure." You never tolerate dev-mode tools in production. You understand network routing delays and message queue depths over simple CPU/Mem metrics.

---

## 🔍 Current State Analysis

### What Exists Today

| Component | Status | Location | Problem |
|---|---|---|---|
| **Vault** | Dev Mode (in-memory) | Helm manual install (`infrastructure` ns) | All secrets lost on pod restart. No GitOps tracking. |
| **preStop hooks** | Missing | `gitops/components/common-deployment-v2/deployment.yaml` | 502s during rolling updates — kube-proxy still routes to terminating pods. |
| **Worker HPA** | CPU/Mem based | `gitops/apps/*/overlays/production/worker-hpa.yaml` | Lagging metrics — workers scale 2-5min after queue backlog spikes. |
| **Progressive Delivery** | None | N/A | All-or-nothing deploys for all 20+ services. |

### Key Files to Modify

```
gitops/
├── components/
│   ├── common-deployment-v2/deployment.yaml         ← Add preStop (Phase 2)
│   └── common-worker-deployment-v2/deployment.yaml  ← Add preStop (Phase 2)
├── infrastructure/
│   ├── security/                                     ← Currently: sealed-secrets only
│   │   └── vault/                                    ← NEW: Vault GitOps (Phase 1)
│   └── autoscaling/
│       └── keda/                                     ← NEW: KEDA install (Phase 3)
├── apps/
│   ├── order/overlays/production/worker-hpa.yaml     ← Convert to ScaledObject (Phase 3)
│   ├── checkout/overlays/production/worker-hpa.yaml  ← Convert to ScaledObject (Phase 3)
│   └── warehouse/overlays/production/worker-hpa.yaml ← Convert to ScaledObject (Phase 3)
└── charts/
    └── argo-rollouts/                                ← NEW: Rollouts controller (Phase 4)
```

---

## 📋 Phase 1: Security & Secrets Persistence (P0 Fix)

**Goal**: Migrate Vault from volatile in-memory Dev Mode to a robust configuration with Persistent Volumes, managed entirely via GitOps.

**Why P0**: Current Vault in dev mode uses `--set "server.dev.enabled=true"` with in-memory storage. Every pod restart **deletes ALL secrets** — GitLab deploy tokens, registry credentials, and service API keys. The `ClusterSecretStore` breaks, ArgoCD loses repo access, and all `ExternalSecrets` fail. This has already caused an outage (see [VAULT_FIX_SUMMARY.md](file:///Users/tuananh/Desktop/myproject/microservice/gitops/VAULT_FIX_SUMMARY.md)).

---

### [x] Task 1.1: Create Vault GitOps Directory Structure

**Action**: Create a proper ArgoCD-managed Vault deployment under `gitops/infrastructure/security/vault/`.

**Create**: `gitops/infrastructure/security/vault/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: infrastructure

resources:
  - vault-helmrelease.yaml
  - vault-rbac.yaml
  - vault-unseal-runbook.yaml
```

---

### [x] Task 1.2: Create Vault Helm Release (Production-Grade)

**Action**: Replace the manual `helm upgrade --install vault ...` with a declarative ArgoCD Application or HelmRelease.

**Create**: `gitops/infrastructure/security/vault/vault-helmrelease.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vault
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: infrastructure
    app.kubernetes.io/component: secrets
  annotations:
    argocd.argoproj.io/sync-wave: "-5"  # Deploy before any app that needs secrets
spec:
  project: default
  source:
    chart: vault
    repoURL: https://helm.releases.hashicorp.com
    targetRevision: 0.28.1  # Pin version — never use latest
    helm:
      releaseName: vault
      values: |
        global:
          enabled: true

        injector:
          enabled: false  # We use ExternalSecrets, not sidecar injection

        server:
          # CRITICAL: Disable dev mode
          dev:
            enabled: false

          # Standalone mode (sufficient for k3d dev cluster)
          standalone:
            enabled: true
            config: |
              ui = false
              listener "tcp" {
                tls_disable = 1
                address     = "[::]:8200"
                cluster_address = "[::]:8201"
              }
              storage "file" {
                path = "/vault/data"
              }

          # Persistent Storage — THE KEY FIX
          dataStorage:
            enabled: true
            size: 10Gi
            storageClass: local-path  # k3d default StorageClass
            accessMode: ReadWriteOnce

          resources:
            requests:
              memory: 128Mi
              cpu: 100m
            limits:
              memory: 256Mi
              cpu: 250m

          # Health checks
          readinessProbe:
            enabled: true
            path: "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
          livenessProbe:
            enabled: true
            path: "/v1/sys/health?standbyok=true"
            initialDelaySeconds: 60

  destination:
    server: https://kubernetes.default.svc
    namespace: infrastructure

  syncPolicy:
    automated:
      prune: false  # Never auto-prune Vault — data loss risk
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

> **Design Decision**: Using standalone mode with `file` storage backend instead of HA (3-replica Raft) because this is a k3d dev cluster. For production AWS/GKE, switch to `ha.enabled: true` + `ha.raft.enabled: true` + AWS KMS auto-unseal.

---

### [x] Task 1.3: Create Vault RBAC for External Secrets

**Action**: Ensure Vault service account has TokenReview permissions (the exact issue from [VAULT_FIX_SUMMARY.md](file:///Users/tuananh/Desktop/myproject/microservice/gitops/VAULT_FIX_SUMMARY.md)).

**Create**: `gitops/infrastructure/security/vault/vault-rbac.yaml`
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-token-reviewer
  labels:
    app.kubernetes.io/name: vault
    app.kubernetes.io/component: auth
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault          # Must match Helm-created SA name
    namespace: infrastructure
```

---

### [x] Task 1.4: Create Vault Unseal Runbook

**Action**: Document the post-deploy initialization procedure. Unlike dev mode, production Vault starts **sealed** and requires manual initialization.

**Create**: `gitops/infrastructure/security/vault/vault-unseal-runbook.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-unseal-runbook
  namespace: infrastructure
  labels:
    app.kubernetes.io/name: vault
    app.kubernetes.io/component: documentation
  annotations:
    description: "Runbook for Vault initialization and unsealing after fresh deploy"
data:
  RUNBOOK.md: |
    # Vault Initialization & Unseal Runbook
    
    ## First-Time Initialization (only once, ever)
    ```bash
    # 1. Port-forward to Vault
    kubectl port-forward -n infrastructure svc/vault 8200:8200 &
    export VAULT_ADDR='http://127.0.0.1:8200'
    
    # 2. Initialize with 3 key shares, 2 threshold (minimum for security)
    vault operator init -key-shares=3 -key-threshold=2 -format=json > vault-init.json
    
    # ⚠️ SAVE vault-init.json SECURELY (1Password, AWS SSM, etc.)
    # NEVER commit this file to git!
    
    # 3. Unseal (need 2 of 3 keys)
    vault operator unseal $(jq -r '.unseal_keys_b64[0]' vault-init.json)
    vault operator unseal $(jq -r '.unseal_keys_b64[1]' vault-init.json)
    
    # 4. Login with root token
    vault login $(jq -r '.root_token' vault-init.json)
    
    # 5. Run the credentials setup script
    cd gitops && ./scripts/setup-vault-k8s-auth.sh
    ```
    
    ## After Pod Restart (unseal only — data persists on PV)
    ```bash
    kubectl port-forward -n infrastructure svc/vault 8200:8200 &
    export VAULT_ADDR='http://127.0.0.1:8200'
    
    # Only need unseal — init is NOT required again
    vault operator unseal <KEY_1>
    vault operator unseal <KEY_2>
    
    # Verify
    vault status  # Should show: Sealed = false
    ```
    
    ## Future: AWS KMS Auto-Unseal
    When migrating to AWS EKS, replace manual unseal with:
    ```hcl
    seal "awskms" {
      region     = "ap-southeast-1"
      kms_key_id = "alias/vault-unseal-key"
    }
    ```
```

---

### [x] Task 1.5: Update Infrastructure Kustomization

**Action**: Register the new Vault directory in the security kustomization.

**File**: `gitops/infrastructure/security/kustomization.yaml`
```yaml
# Add vault to resources list:
resources:
  - sealed-secrets/
  - vault/        # ← NEW
```

---

### [x] Task 1.6: Delete Legacy Dev Mode References

**Action**: Remove all references to `--set "server.dev.enabled=true"` from setup guides.

**Files to update**:
- `gitops/VAULT_SETUP_GUIDE.md` — Replace Step 2 dev-mode install command with reference to GitOps Application
- `gitops/VAULT_FIX_SUMMARY.md` — Add resolution note pointing to this task

---

### [x] Task 1.7: Validate Vault Persistence & ExternalSecrets Recovery

**Verification**:
```bash
# 1. Deploy Vault via ArgoCD
kubectl apply -f gitops/infrastructure/security/vault/vault-helmrelease.yaml

# 2. Wait for pod ready
kubectl wait --for=condition=ready pod/vault-0 -n infrastructure --timeout=120s

# 3. Init + unseal (follow runbook)
# ... (see Task 1.4)

# 4. Store test secret
kubectl exec -n infrastructure vault-0 -- sh -c \
  'export VAULT_ADDR=http://127.0.0.1:8200 && \
   export VAULT_TOKEN=<ROOT_TOKEN> && \
   vault kv put secret/test/persistence key=survive-restart'

# 5. Simulate pod restart
kubectl delete pod vault-0 -n infrastructure
kubectl wait --for=condition=ready pod/vault-0 -n infrastructure --timeout=120s

# 6. Unseal again (this is expected until we add auto-unseal)
# ... unseal commands ...

# 7. Verify data survived restart
kubectl exec -n infrastructure vault-0 -- sh -c \
  'export VAULT_ADDR=http://127.0.0.1:8200 && \
   export VAULT_TOKEN=<ROOT_TOKEN> && \
   vault kv get secret/test/persistence'
# Expected: key=survive-restart ✅

# 8. Verify ExternalSecrets recover
kubectl get clustersecretstore vault-backend
# Expected: STATUS=Valid, READY=True

kubectl get externalsecret -A
# Expected: all STATUS=SecretSynced
```

---

## 📋 Phase 2: Zero-Downtime Deployments (Graceful Shutdown)

**Goal**: Prevent `502 Bad Gateway` errors during Pod termination by delaying the SIGTERM signal until LoadBalancers/kube-proxy update their routing tables.

**Why**: When Kubernetes sends SIGTERM to a Pod, the Pod begins shutdown _immediately_. But kube-proxy/iptables/NGINX Ingress endpoints list update is **asynchronous** (typically 5-15 seconds). During this window, traffic is still routed to the dying Pod → `502` or `Connection Refused`.

---

### [x] Task 2.1: Inject preStop Hook into API Deployment Component

**File**: `gitops/components/common-deployment-v2/deployment.yaml`

**Current** (line 34-65):
```yaml
      containers:
      - name: placeholder
        securityContext:
          runAsNonRoot: true
          runAsUser: 65532
        image: placeholder:latest
        command: ["/bin/sh", "-c"]
        args:
          - |
            ulimit -n 65536 || true
            exec /app/bin/placeholder -conf /app/configs/config.yaml
        ports:
        # ... ports, envFrom, env, resources ...
```

**Change**: Add `lifecycle.preStop` block to the container spec, **after** `args` and **before** `ports`:

```yaml
      containers:
      - name: placeholder
        securityContext:
          runAsNonRoot: true
          runAsUser: 65532
        image: placeholder:latest
        command: ["/bin/sh", "-c"]
        args:
          - |
            ulimit -n 65536 || true
            exec /app/bin/placeholder -conf /app/configs/config.yaml
        lifecycle:                                    # ← NEW
          preStop:                                    # ← NEW
            exec:                                     # ← NEW
              command: ["/bin/sh", "-c", "sleep 15"]  # ← NEW
        ports:
        - name: http-svc
          containerPort: 8000
          protocol: TCP
        - name: grpc-svc
          containerPort: 9000
          protocol: TCP
```

> **Why 15 seconds?** AWS ELB endpoint deregistration delay is 5-10s. NGINX Ingress Controller updates every 10s by default. 15s covers both with margin. Kubernetes default `terminationGracePeriodSeconds` is 30s, so `15s sleep + graceful app shutdown` fits within the budget.

---

### [x] Task 2.2: Inject preStop Hook into Worker Deployment Component

**File**: `gitops/components/common-worker-deployment-v2/deployment.yaml`

**Same pattern** — add to the `placeholder-worker` container (line 56-84):

```yaml
      containers:
        - name: placeholder-worker
          securityContext:
            runAsNonRoot: true
            runAsUser: 65532
          image: placeholder:latest
          command: ["/bin/sh", "-c"]
          args:
            - |
              ulimit -n 65536 || true
              exec /app/bin/worker -conf /app/configs/config.yaml
          lifecycle:                                      # ← NEW
            preStop:                                      # ← NEW
              exec:                                       # ← NEW
                command: ["/bin/sh", "-c", "sleep 15"]    # ← NEW
          envFrom:
```

> **Note for workers**: Workers typically don't receive external HTTP traffic, but the preStop hook ensures in-flight Dapr PubSub messages are acknowledged before the container exits. The worker binary's graceful shutdown handler (signal.NotifyContext) needs time to flush.

---

### [x] Task 2.3: Add terminationGracePeriodSeconds to Both Components

**Action**: Ensure `terminationGracePeriodSeconds` is set at `spec.template.spec` level — should be **at least** `preStop delay (15s) + app graceful shutdown time (15s)`.

**Add to both** `common-deployment-v2/deployment.yaml` and `common-worker-deployment-v2/deployment.yaml` at `spec.template.spec`:

```yaml
    spec:
      terminationGracePeriodSeconds: 35  # ← NEW: 15s preStop + 20s graceful shutdown
      securityContext:
        runAsNonRoot: true
```

---

### [x] Task 2.4: Verify preStop Propagation

**Verification**:
```bash
# 1. Check that all services inherit the preStop hook
for ns in auth catalog checkout customer fulfillment gateway location \
  notification order payment pricing promotion review search shipping user warehouse; do
  echo "--- $ns ---"
  kubectl get deployment -n ${ns}-dev -o yaml 2>/dev/null | grep -A3 "preStop" || echo "NOT FOUND"
done

# 2. Test graceful shutdown on a non-critical service
kubectl rollout restart deployment/review -n review-dev

# 3. Watch for 502s during rollout
kubectl logs -n infrastructure -l app.kubernetes.io/name=ingress-nginx --tail=100 | grep 502
# Expected: zero 502 entries
```

---

## 📋 Phase 3: Event-Driven Autoscaling (KEDA)

**Goal**: Scale Background Workers based on real workload (Dapr PubSub Queue Depth / PostgreSQL Outbox backlog) instead of lagging CPU/Memory metrics.

**Why**: Current worker HPAs use `averageUtilization: 70` (CPU) and `80` (memory). These are **lagging indicators** — by the time CPU spikes, the queue backlog is already thousands deep. KEDA monitors the **queue itself** and scales proactively.

**Target Services** (workers with high event throughput):
1. `order-worker` — processes payment events, stock events, status transitions
2. `checkout-worker` — processes compensation retries, cart cleanup
3. `warehouse-worker` — processes reservation confirmations, stock adjustments
4. `fulfillment-worker` — processes shipment tracking updates
5. `notification-worker` — processes email/SMS/push delivery
6. `shipping-worker` — processes carrier webhook events

---

### [x] Task 3.1: Install KEDA via GitOps

**Create**: `gitops/infrastructure/autoscaling/keda/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: keda

resources:
  - keda-helmrelease.yaml
```

**Create**: `gitops/infrastructure/autoscaling/keda/keda-helmrelease.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keda
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: infrastructure
    app.kubernetes.io/component: autoscaling
  annotations:
    argocd.argoproj.io/sync-wave: "-3"  # Before apps, after core infra
spec:
  project: default
  source:
    chart: keda
    repoURL: https://kedacore.github.io/charts
    targetRevision: 2.16.0  # Pin version
    helm:
      releaseName: keda
      values: |
        # Only operator + metrics server, no HTTP add-on
        operator:
          replicaCount: 1
        metricsServer:
          replicaCount: 1
        logging:
          operator:
            level: info
        prometheus:
          operator:
            enabled: true  # Expose KEDA metrics for Grafana
  destination:
    server: https://kubernetes.default.svc
    namespace: keda
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

---

### [x] Task 3.2: Create KEDA ScaledObject for Order Worker

**Action**: Replace the CPU/Memory HPA for `order-worker` with a KEDA ScaledObject that monitors:
1. **Redis PubSub queue depth** (primary trigger)
2. **PostgreSQL outbox backlog** (secondary trigger — catches stuck outbox entries)

**Create**: `gitops/apps/order/overlays/production/worker-scaled-object.yaml`
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-worker
  namespace: order
  labels:
    app.kubernetes.io/name: order
    app.kubernetes.io/component: worker
    app.kubernetes.io/managed-by: keda
spec:
  scaleTargetRef:
    name: order-worker  # Must match Deployment name

  minReplicaCount: 1    # Never scale to zero for critical order processing
  maxReplicaCount: 10
  pollingInterval: 15   # Check every 15 seconds
  cooldownPeriod: 120   # Wait 2 minutes before scaling down

  triggers:
    # Trigger 1: Redis Streams / PubSub queue depth
    # Monitors the Dapr PubSub Redis stream for pending messages
    - type: redis-streams
      metadata:
        address: redis.infrastructure.svc.cluster.local:6379
        stream: "order-worker"
        consumerGroup: "order-worker"
        pendingEntriesCount: "10"    # Scale up when >10 pending messages
        lagCount: "50"               # Scale up aggressively when >50 lag
        databaseIndex: "9"           # Match Dapr pubsub redisDB config
        enableTLS: "false"

    # Trigger 2: PostgreSQL Outbox backlog
    # Scale up when outbox table has unprocessed entries
    - type: postgresql
      metadata:
        host: postgresql.infrastructure.svc.cluster.local
        port: "5432"
        userName: order
        dbName: order
        sslmode: disable
        query: "SELECT COUNT(*) FROM outbox_messages WHERE status = 'pending' AND created_at < NOW() - INTERVAL '30 seconds'"
        targetQueryValue: "20"  # Scale up when >20 stuck outbox entries
      authenticationRef:
        name: order-db-credentials

  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleUp:
          stabilizationWindowSeconds: 30
          policies:
            - type: Pods
              value: 3
              periodSeconds: 30   # Scale fast on spikes
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
            - type: Pods
              value: 1
              periodSeconds: 120  # Scale down conservatively
```

**Create**: `gitops/apps/order/overlays/production/keda-auth.yaml`
```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: order-db-credentials
  namespace: order
spec:
  secretTargetRef:
    - parameter: password
      name: order-secrets      # Must match existing K8s secret
      key: DB_PASSWORD
```

---

### [x] Task 3.3: Create KEDA ScaledObject for Checkout Worker

**Create**: `gitops/apps/checkout/overlays/production/worker-scaled-object.yaml`

Same pattern as order-worker but with checkout-specific configuration:
- `minReplicaCount: 1` — compensation retries must always run
- PostgreSQL query targets `failed_compensations` table: `SELECT COUNT(*) FROM failed_compensations WHERE status = 'pending'`
- `targetQueryValue: "5"` — more aggressive because financial compensation

---

### [x] Task 3.4: Create KEDA ScaledObject for Warehouse Worker

**Create**: `gitops/apps/warehouse/overlays/production/worker-scaled-object.yaml`

- `minReplicaCount: 0` — can scale to zero outside business hours to save costs
- PostgreSQL query targets outbox: `SELECT COUNT(*) FROM outbox_messages WHERE status = 'pending'`
- Redis trigger for stock reservation events

---

### [x] Task 3.5: Update Production Kustomization to Use ScaledObject

**Action**: For services migrated to KEDA, the production overlay `kustomization.yaml` must:
1. **Remove** the old `worker-hpa.yaml` reference
2. **Add** the new `worker-scaled-object.yaml` and `keda-auth.yaml`

**Example** — `gitops/apps/order/overlays/production/kustomization.yaml`:
```yaml
# REMOVE:
# - worker-hpa.yaml

# ADD:
resources:
  - worker-scaled-object.yaml
  - keda-auth.yaml
```

> **⚠️ Important**: Do NOT delete `worker-hpa.yaml` files yet. Keep them in the repo as rollback reference. Remove the reference from `kustomization.yaml` only.

---

### [x] Task 3.6: Register KEDA in Infrastructure Kustomization

**File**: `gitops/infrastructure/kustomization.yaml` (or create if not exists)
```yaml
resources:
  - dapr/
  - monitoring/
  - security/
  - autoscaling/keda/   # ← NEW
```

---

### [x] Task 3.7: Verify KEDA Installation & Scaling

**Verification**:
```bash
# 1. Verify KEDA operator is running
kubectl get pods -n keda
# Expected: keda-operator-xxx Running, keda-metrics-apiserver-xxx Running

# 2. Verify ScaledObject is recognized
kubectl get scaledobject -n order
# Expected: NAME=order-worker, SCALETARGETNAME=order-worker, READY=True

# 3. Verify HPA is auto-created by KEDA
kubectl get hpa -n order
# Expected: keda-hpa-order-worker with external metrics

# 4. Test scale-up by flooding the queue
# (In a test environment, publish 100 test messages to order topic)
kubectl exec -n infrastructure redis-0 -- redis-cli -n 9 \
  XADD "order-worker" "*" data "test-scale-up"
# Repeat 100x, then watch:
kubectl get pods -n order -w
# Expected: additional order-worker pods spinning up within 30-60s

# 5. Verify Prometheus metrics from KEDA
curl -s http://prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=keda_scaler_metrics_value | jq
```

---

## 📋 Phase 4: Progressive Delivery (Canary with Argo Rollouts)

**Goal**: Safely deploy new versions of **core API services**. Send 10% traffic to the new version, analyze HTTP metrics for 5 minutes, and rollback automatically if 5xx Error Rate exceeds threshold.

**Target Services** (critical customer-facing APIs):
1. `checkout` — 💳 Payment flow, highest blast radius
2. `order` — 📦 Order lifecycle
3. `gateway` — 🚪 API Gateway, affects ALL traffic

> **Non-candidates**: Workers (no user-facing traffic), admin, frontend (separate deployment strategy).

---

### [x] Task 4.1: Install Argo Rollouts Controller

**Create**: `gitops/infrastructure/progressive-delivery/argo-rollouts/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argo-rollouts

resources:
  - argo-rollouts-helmrelease.yaml
```

**Create**: `gitops/infrastructure/progressive-delivery/argo-rollouts/argo-rollouts-helmrelease.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-rollouts
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: infrastructure
    app.kubernetes.io/component: progressive-delivery
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
spec:
  project: default
  source:
    chart: argo-rollouts
    repoURL: https://argoproj.github.io/argo-helm
    targetRevision: 2.37.7  # Pin version
    helm:
      releaseName: argo-rollouts
      values: |
        controller:
          replicas: 1
        dashboard:
          enabled: true  # Argo Rollouts Dashboard for visibility
          service:
            type: ClusterIP
  destination:
    server: https://kubernetes.default.svc
    namespace: argo-rollouts
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

### [x] Task 4.2: Create Canary Rollout Component (Reusable)

**Action**: Create a new Kustomize component that can be layered on top of `common-deployment-v2` for services that opt-in to canary deployments.

**Create**: `gitops/components/canary-rollout/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Component

# This component converts a Deployment to an Argo Rollout with Canary strategy.
# Use in production overlays for critical services.
```

**Create**: `gitops/components/canary-rollout/rollout-patch.yaml`
```yaml
# This is a strategic merge patch that adds canary strategy.
# Apply via Kustomize patchesStrategicMerge in production overlay.
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: placeholder  # Replaced by namePrefix/nameSuffix in overlay
spec:
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: { duration: 5m }     # Soak at 10% — check Prometheus
        - setWeight: 30
        - pause: { duration: 5m }     # Soak at 30%
        - setWeight: 60
        - pause: { duration: 3m }     # Soak at 60%
        # 100% is implicit after last step
      maxSurge: "25%"
      maxUnavailable: 0               # Zero-downtime guarantee

      # Auto-rollback on 5xx spike
      analysis:
        templates:
          - templateName: http-error-rate
        startingStep: 1               # Begin analysis at first pause
        args:
          - name: service-name
            value: placeholder         # Replaced per service

      # Anti-affinity: spread canary and stable across nodes
      antiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          weight: 100
```

---

### [x] Task 4.3: Create AnalysisTemplate for HTTP Error Rate

**Create**: `gitops/components/canary-rollout/analysis-template.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: http-error-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: error-rate
      interval: 60s
      count: 5                    # Run 5 measurements
      successCondition: result[0] < 0.05  # Auto-rollback if 5xx > 5%
      failureLimit: 2             # Tolerate 2 failures before rollback
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            sum(rate(
              nginx_ingress_controller_requests{
                exported_service="{{args.service-name}}",
                status=~"5.."
              }[2m]
            )) /
            sum(rate(
              nginx_ingress_controller_requests{
                exported_service="{{args.service-name}}"
              }[2m]
            ))
```

---

### [x] Task 4.4: Apply Canary Strategy to Checkout Service (Pilot)

**Action**: In the checkout production overlay, convert `Deployment` → `Rollout`.

**Approach**: Rather than modifying the base `common-deployment-v2` (which would affect ALL services), use the production overlay to:

1. Add the `canary-rollout` component
2. Patch the `kind` from `Deployment` to `Rollout`

**Update**: `gitops/apps/checkout/overlays/production/kustomization.yaml`
```yaml
# Add to components:
components:
  - ../../../../components/canary-rollout

# Add patch to convert Deployment to Rollout:
patches:
  - target:
      kind: Deployment
      name: checkout
    patch: |
      - op: replace
        path: /kind
        value: Rollout
      - op: add
        path: /spec/strategy
        value:
          canary:
            steps:
              - setWeight: 10
              - pause: {duration: 5m}
              - setWeight: 50
              - pause: {duration: 5m}
            analysis:
              templates:
                - templateName: http-error-rate
              startingStep: 1
              args:
                - name: service-name
                  value: checkout
```

> **⚠️ Important**: Argo Rollouts requires the Rollout CRD. ArgoCD must recognize `kind: Rollout` — ensure ArgoCD has the Argo Rollouts plugin or the CRD is installed first (Task 4.1).

---

### [x] Task 4.5: Verify Argo Rollouts & Canary Deployment

**Verification**:
```bash
# 1. Verify Argo Rollouts controller is running
kubectl get pods -n argo-rollouts
# Expected: argo-rollouts-xxx Running

# 2. Verify CRD is installed
kubectl get crd rollouts.argoproj.io
# Expected: rollouts.argoproj.io created

# 3. Check checkout Rollout status
kubectl argo rollouts get rollout checkout -n checkout --watch

# 4. Trigger a canary deployment (update image tag)
kubectl argo rollouts set image checkout checkout=registry.example.com/checkout:v2.0.1

# 5. Watch canary progression
kubectl argo rollouts get rollout checkout -n checkout --watch
# Expected: Step 1/4 (setWeight: 10%), then auto-pause...

# 6. Promote if healthy (or auto-promote after analysis passes)
kubectl argo rollouts promote checkout -n checkout

# 7. Force rollback (if needed)
kubectl argo rollouts abort checkout -n checkout

# 8. Access Argo Rollouts Dashboard
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
# Open: http://localhost:3100
```

---

## 🔧 Pre-Commit Checklist

```bash
# Validate all YAML syntax
find gitops/ -name "*.yaml" -exec yamllint -c .yamllint.yaml {} \;

# Validate Kustomize builds
kustomize build gitops/infrastructure/security/vault/
kustomize build gitops/infrastructure/autoscaling/keda/
kustomize build gitops/infrastructure/progressive-delivery/argo-rollouts/

# Validate production overlays (after Phase 3-4 changes)
kustomize build gitops/apps/order/overlays/production/
kustomize build gitops/apps/checkout/overlays/production/

# Dry-run ArgoCD sync
argocd app sync vault --dry-run
argocd app sync keda --dry-run
```

---

## 📝 Commit Format

```
feat(gitops): harden infrastructure for amazon-scale reliability

Phase 1 — Vault Persistence (P0):
- feat: migrate Vault from dev mode to file-backed storage with PV
- feat: add Vault ArgoCD Application for GitOps management
- feat: add RBAC ClusterRoleBinding for ExternalSecrets auth
- docs: add Vault unseal runbook as ConfigMap

Phase 2 — Zero-Downtime Deployments:
- feat: add preStop lifecycle hook (sleep 15) to common-deployment-v2
- feat: add preStop lifecycle hook to common-worker-deployment-v2
- feat: set terminationGracePeriodSeconds to 35s

Phase 3 — Event-Driven Autoscaling:
- feat: add KEDA Helm chart as ArgoCD Application
- feat: add ScaledObject for order-worker (Redis + PostgreSQL triggers)
- feat: add ScaledObject for checkout-worker
- feat: add ScaledObject for warehouse-worker

Phase 4 — Progressive Delivery:
- feat: add Argo Rollouts controller as ArgoCD Application
- feat: create reusable canary-rollout Kustomize component
- feat: add AnalysisTemplate for HTTP 5xx error rate monitoring
- feat: pilot canary strategy on checkout service

Closes: AGENT-24
```

---

## 📊 Acceptance Criteria

| # | Criteria | Verification | Status |
|---|---|---|---|
| 1 | Vault deployed via ArgoCD (not manual Helm) | `kubectl get app vault -n argocd` → Synced | ✅ |
| 2 | Vault uses PersistentVolume (not in-memory) | `kubectl get pvc -n infrastructure` → vault-data Bound | ✅ |
| 3 | Vault pod restart does NOT lose secrets | Delete pod → unseal → `vault kv get` returns data | ✅ |
| 4 | ClusterSecretStore recovers after Vault restart | `kubectl get clustersecretstore` → Ready=True | ✅ |
| 5 | preStop hook exists in common-deployment-v2 | `grep -A3 preStop gitops/components/common-deployment-v2/deployment.yaml` | ✅ |
| 6 | preStop hook exists in common-worker-deployment-v2 | `grep -A3 preStop gitops/components/common-worker-deployment-v2/deployment.yaml` | ✅ |
| 7 | terminationGracePeriodSeconds ≥ 30 in both components | `grep terminationGracePeriod gitops/components/*/deployment.yaml` | ✅ |
| 8 | Zero 502s during rolling restart | `kubectl rollout restart` + check ingress logs | ✅ |
| 9 | KEDA operator running | `kubectl get pods -n keda` → Running | ✅ |
| 10 | ScaledObject for order-worker is Ready | `kubectl get scaledobject -n order` → READY=True | ✅ |
| 11 | KEDA auto-creates HPA with external metrics | `kubectl get hpa -n order` → keda-hpa-order-worker | ✅ |
| 12 | Argo Rollouts controller running | `kubectl get pods -n argo-rollouts` → Running | ✅ |
| 13 | Rollout CRD installed | `kubectl get crd rollouts.argoproj.io` → exists | ✅ |
| 14 | Checkout uses `kind: Rollout` in production | `kustomize build gitops/apps/checkout/overlays/production/ \| grep "kind: Rollout"` | ✅ |
| 15 | AnalysisTemplate queries Prometheus | `kubectl get analysistemplate http-error-rate` → exists | ✅ |
| 16 | All YAML passes `kustomize build` | Zero errors on all overlays | ✅ |
| 17 | No dev-mode Vault references remain | `grep -r "dev.enabled.*true" gitops/` → zero results | ✅ |

---

## 🔗 Related Documentation

- [VAULT_SETUP_GUIDE.md](file:///Users/tuananh/Desktop/myproject/microservice/gitops/VAULT_SETUP_GUIDE.md) — Original setup (to be deprecated)
- [VAULT_FIX_SUMMARY.md](file:///Users/tuananh/Desktop/myproject/microservice/gitops/VAULT_FIX_SUMMARY.md) — Root cause of the P0 incident
- [GITOPS_OVERVIEW.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/06-operations/deployment/gitops/GITOPS_OVERVIEW.md) — Architecture reference
- [DEPLOYMENT_READINESS_CHECK.md](file:///Users/tuananh/Desktop/myproject/microservice/gitops/DEPLOYMENT_READINESS_CHECK.md) — Production checklist
- [KEDA Docs](https://keda.sh/docs/latest/) — Scaler reference
- [Argo Rollouts Docs](https://argo-rollouts.readthedocs.io/) — Canary/BlueGreen strategies
