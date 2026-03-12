# AGENT TASK - GITOPS CONFIG (AGENT-14)

## STATUS
**State:** [x] Done

## ASSIGNMENT
**Focus Area:** Dapr Namespace Parameterization, Redis Security, Alerting Enhancements, Pod Scheduling
**Primary Repo:** `gitops/`
**Priority:** Critical (P0 → Blocks Production Deployment)

---

## 📌 P0: Dapr Components Hardcoded to `common-operations-dev` Namespace ✅ IMPLEMENTED

**Risk:** `infrastructure/dapr/pubsub-redis.yaml` and `statestore-redis.yaml` both have `namespace: common-operations-dev` hardcoded. When deploying to Production, these components will be created in the wrong namespace, causing Dapr sidecars in production pods to fail connecting to PubSub/Statestore (NetworkPolicy blocks cross-namespace traffic). Result: **ALL outbox workers and event consumers will silently stop publishing/consuming**, causing order processing, refund, and notification failures.

**Files Modified:**
- `gitops/infrastructure/dapr/pubsub-redis.yaml` — removed `namespace: common-operations-dev`, updated `managed-by` label to `argocd`
- `gitops/infrastructure/dapr/statestore-redis.yaml` — removed `namespace: common-operations-dev`, updated `managed-by` label to `argocd`

**Solution Applied:**
Removed hardcoded `namespace` from both Dapr Component manifests. The namespace will now be set by the kustomize overlay for each environment (dev/production). Also updated `managed-by` label from `kustomize` to `argocd` to match the NetworkPolicy `namespaceSelector` requirements.

```yaml
# Before (both files)
metadata:
  name: pubsub-redis
  namespace: common-operations-dev  # ← REMOVED
  labels:
    app.kubernetes.io/managed-by: kustomize  # ← Changed to argocd

# After
metadata:
  name: pubsub-redis
  labels:
    app.kubernetes.io/managed-by: argocd
```

**Validation:**
- `kustomization.yaml` in `infrastructure/dapr/` already has `resources: []` (components managed per-service namespace)
- Both files are now namespace-agnostic

---

## 📌 P1: Redis Without Authentication or Encryption ✅ IMPLEMENTED

**Risk:** Both Dapr Redis components have `redisPassword: ""` and `enableTLS: "false"`. In a production cluster, any compromised pod can freely read/write to Redis PubSub and Statestore without authentication, enabling data exfiltration and message injection attacks.

**Files Modified:**
- `gitops/environments/production/resources/dapr/pubsub-redis.yaml` — NEW (production-specific with `secretKeyRef` + TLS)
- `gitops/environments/production/resources/dapr/statestore-redis.yaml` — NEW (production-specific with `secretKeyRef` + TLS)
- `gitops/environments/production/kustomization.yaml` — Fixed `commonLabels` → `labels` transformer

**Solution Applied:**
Created production-specific Dapr component manifests that use `secretKeyRef` for Redis password (referencing `redis-credentials` Secret) and enable TLS. Dev environment retains empty password + no TLS (acceptable for local K3d).

```yaml
# Production pubsub-redis.yaml
- name: redisPassword
  secretKeyRef:
    name: redis-credentials
    key: redis-password
- name: enableTLS
  value: "true"
```

Also fixed production `kustomization.yaml` to use `labels` transformer (same fix as dev) preventing immutable selector errors.

---

## 📌 P2: Missing Saga/Compensation Alerts ✅ IMPLEMENTED

**Risk:** Alertmanager rules cover DLQ, Outbox Lag, Order, Payment, Return, and Service Health — but there are no rules for Saga timeout monitoring or compensation job backlog.

**Files Modified:**
- `gitops/infrastructure/monitoring/alertmanager-rules.yaml` — Added `saga_alerts` rule group (lines 249-277)

**Solution Applied:**
Added new `saga_alerts` group with two rules:

```yaml
- name: saga_alerts
  rules:
    - alert: SagaTimeoutCritical
      expr: saga_active_duration_seconds > 300
      for: 5m
      labels:
        severity: critical
      # Fires when any saga has been active >5 min

    - alert: CompensationBacklogHigh
      expr: compensation_pending_total > 10
      for: 10m
      labels:
        severity: warning
      # Fires when compensation queue exceeds 10 pending jobs
```

---

## 📌 P2: Missing `topologySpreadConstraints` in Deployment Template ✅ IMPLEMENTED

**Risk:** Without zone-aware pod scheduling, all replicas of a critical service (e.g., Payment, Gateway) can land on a single node or availability zone. If that zone goes down, the service becomes fully unavailable despite having multiple replicas.

**Files Modified:**
- `gitops/components/common-deployment-v2/deployment.yaml` — Added `topologySpreadConstraints` (lines 34-40)

**Solution Applied:**
Added `topologySpreadConstraints` to the common deployment template spec. Uses `ScheduleAnyway` (soft constraint) to support dev clusters that may lack multiple zones:

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: placeholder
```

The `placeholder` name/label is replaced by kustomize `namePrefix`/`nameSuffix` or per-service overlays.

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
cd gitops

git add infrastructure/dapr/
git add infrastructure/monitoring/
git add components/common-deployment-v2/
git add environments/production/

git commit -m "fix(gitops): parameterize dapr namespace, secure redis, add saga alerts

# Agent-14 Fixes based on 250-Round Meeting Review
# P0: Dapr components no longer hardcoded to common-operations-dev
# P1: Production Redis requires password via secretKeyRef + TLS enabled
# P2: Added Saga timeout and compensation backlog alerts
# P2: Added topologySpreadConstraints for multi-AZ resilience"
```

## ✅ Acceptance Criteria

| # | Criteria | Status |
|---|---------|--------|
| 1 | Dapr components have no hardcoded namespace | ✅ |
| 2 | Production Dapr uses secretKeyRef for Redis password | ✅ |
| 3 | Production Dapr has enableTLS: true | ✅ |
| 4 | Saga timeout alert configured (>300s for 5m) | ✅ |
| 5 | Compensation backlog alert configured (>10 for 10m) | ✅ |
| 6 | topologySpreadConstraints in common deployment template | ✅ |
