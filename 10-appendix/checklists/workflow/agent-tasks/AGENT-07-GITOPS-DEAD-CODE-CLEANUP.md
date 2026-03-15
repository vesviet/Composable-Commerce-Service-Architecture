# AGENT-07: GitOps Dead Code Cleanup

> **Created**: 2026-03-15
> **Completed/Merged**: 2026-03-15
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint / Infrastructure Hardening
> **Services**: `gitops` (cross-cutting)
> **Estimated Effort**: 1-2 days
> **Status**: ✅ **MERGED**
> **Merged into**: [AGENT-06-CONSUL-GITOPS-INFRASTRUCTURE-HARDENING.md](AGENT-06-CONSUL-GITOPS-INFRASTRUCTURE-HARDENING.md) (As Phase 4: GitOps Dead Code Cleanup)

---

## 📋 Overview

**This task has been merged into AGENT-06** to consolidate all infrastructure and GitOps hardening into a single epic task.

The original dead code cleanup identified 19 orphaned YAML files (including plaintext secrets, disconnected HPAs, and ghost deployments) which are now tracked under Phase 4 of AGENT-06.

The scan was performed by crawling all 90+ `kustomization.yaml` files and cross-referencing them against every `.yaml` file in the repository. Any file not listed in a `resources:`, `patches:`, or `components:` section is classified as dead code.

---

## ✅ Checklist — P0 Issues (MUST FIX — Security & Availability)

### [ ] Task 1: Delete Plaintext Secret — `warehouse/base/secret.yaml`

**File**: `gitops/apps/warehouse/base/secret.yaml`
**Lines**: 1-17
**Risk**: **CRITICAL SECURITY** — Plaintext database password (`microservices`) and connection string committed to Git. Even though this file is not referenced by `warehouse/base/kustomization.yaml` (which uses components + overlay secrets), the sensitive data persists in Git history.

**Problem**: File contains hardcoded credentials:
```yaml
# gitops/apps/warehouse/base/secret.yaml (Lines 11-16)
stringData:
  database-url: "postgres://postgres:microservices@postgresql.infrastructure.svc.cluster.local:5432/warehouse_db?sslmode=disable"
  database-user: "postgres"
  database-password: "microservices"
  redis-password: ""
```

The `warehouse/base/kustomization.yaml` does NOT reference `secret.yaml` in its `resources:` list. Secrets are instead injected via the production overlay's `secrets.yaml` (line 7 of `warehouse/overlays/production/kustomization.yaml`).

**Fix**: Delete the file entirely.
```bash
rm gitops/apps/warehouse/base/secret.yaml
```

**Validation**:
```bash
cd gitops && kustomize build apps/warehouse/overlays/dev/ > /dev/null 2>&1 && echo "OK" || echo "FAIL"
cd gitops && kustomize build apps/warehouse/overlays/production/ > /dev/null 2>&1 && echo "OK" || echo "FAIL"
# Verify no reference exists
grep -r "secret.yaml" gitops/apps/warehouse/base/kustomization.yaml  # Should return nothing
```

---

### [ ] Task 2: Delete Plaintext Secret — `customer/base/secret.yaml`

**File**: `gitops/apps/customer/base/secret.yaml`
**Lines**: 1-29
**Risk**: **CRITICAL SECURITY** — Contains plaintext DB password, JWT signing secret (`customer-service-jwt-secret-change-in-production`), and encryption key placeholder. Worse than Task 1 because it also leaks JWT/encryption key patterns.

**Problem**: File contains hardcoded credentials and cryptographic material:
```yaml
# gitops/apps/customer/base/secret.yaml (Lines 22-28)
stringData:
  database-url: "postgres://postgres:microservices@..."
  database-password: "microservices"
  CUSTOMER_SECURITY_JWT_SECRET: "customer-service-jwt-secret-change-in-production"
  CUSTOMER_SECURITY_ENCRYPTION_KEY: "32-character-encryption-key-here"
```

**Fix**: Delete the file entirely.
```bash
rm gitops/apps/customer/base/secret.yaml
```

**Validation**:
```bash
cd gitops && kustomize build apps/customer/overlays/dev/ > /dev/null 2>&1 && echo "OK" || echo "FAIL"
grep -r "secret.yaml" gitops/apps/customer/base/kustomization.yaml  # Should return nothing
```

---

### [ ] Task 3: Delete Orphaned Dapr Statestore Config — `infrastructure/dapr/statestore-redis.yaml`

**File**: `gitops/infrastructure/dapr/statestore-redis.yaml`
**Lines**: 1-25
**Risk**: **CRITICAL SECURITY** — Contains the Redis password in plaintext (`K8sD3v_redis_2026x`). The parent `infrastructure/dapr/kustomization.yaml` has `resources: []` (explicitly emptied with comment: "Disabled: Dapr components are now managed per-service namespace").

**Problem**: Password leak in orphaned file:
```yaml
# gitops/infrastructure/dapr/statestore-redis.yaml (Lines 14-15)
    - name: redisPassword
      value: "K8sD3v_redis_2026x"
```

**Fix**: Delete the file entirely.
```bash
rm gitops/infrastructure/dapr/statestore-redis.yaml
```

**Validation**:
```bash
# Confirm parent kustomization has resources: []
grep -A1 "resources:" gitops/infrastructure/dapr/kustomization.yaml  # Should show "resources: []"
```

---

### [ ] Task 4: Delete Orphaned Dapr PubSub Config — `infrastructure/dapr/pubsub-redis.yaml`

**File**: `gitops/infrastructure/dapr/pubsub-redis.yaml`
**Lines**: 1-30
**Risk**: **CRITICAL SECURITY** — Same Redis password leak as Task 3 (`K8sD3v_redis_2026x`). Same disabled parent `kustomization.yaml`.

**Fix**: Delete the file entirely.
```bash
rm gitops/infrastructure/dapr/pubsub-redis.yaml
```

**Validation**:
```bash
# Confirm the infra/dapr dir is now clean (only kustomization.yaml remains)
ls gitops/infrastructure/dapr/
```

---

### [ ] Task 5: Resolve Disconnected Production Worker HPAs

**Files**:
- `gitops/apps/order/overlays/production/worker-hpa.yaml` (42 lines)
- `gitops/apps/checkout/overlays/production/worker-hpa.yaml` (50 lines)
- `gitops/apps/warehouse/overlays/production/worker-hpa.yaml` (42 lines)

**Risk**: **AVAILABILITY** — These HPA definitions exist but are NOT listed in their respective `production/kustomization.yaml` files. This means production workers **cannot auto-scale**. During traffic spikes (flash sales), event queues will back up and order/checkout/warehouse processing will stall.

**Problem**: Each production overlay references `worker-scaled-object.yaml` (KEDA ScaledObject) and `keda-auth.yaml`, but NOT the worker-hpa. Both KEDA and native HPA coexist, creating confusion.

**Root Cause Analysis**:
- `order/overlays/production/kustomization.yaml` → has `worker-scaled-object.yaml` + `keda-auth.yaml` → KEDA is the intended scaler
- `checkout/overlays/production/kustomization.yaml` → same: KEDA
- `warehouse/overlays/production/kustomization.yaml` → same: KEDA

**Fix**: Since KEDA `ScaledObject` is the intended auto-scaler (it's referenced in kustomization), the native HPA files are redundant dead code. **Delete them** to avoid confusion:
```bash
rm gitops/apps/order/overlays/production/worker-hpa.yaml
rm gitops/apps/checkout/overlays/production/worker-hpa.yaml
rm gitops/apps/warehouse/overlays/production/worker-hpa.yaml
```

> ⚠️ **VERIFY FIRST**: Confirm KEDA ScaledObjects are actually deployed on cluster:
> ```bash
> kubectl get scaledobject -n order-prod
> kubectl get scaledobject -n checkout-prod
> kubectl get scaledobject -n warehouse-prod
> ```
> If KEDA is NOT deployed, add `worker-hpa.yaml` to kustomization instead.

**Validation**:
```bash
cd gitops && kustomize build apps/order/overlays/production/ > /dev/null 2>&1 && echo "OK"
cd gitops && kustomize build apps/checkout/overlays/production/ > /dev/null 2>&1 && echo "OK"
cd gitops && kustomize build apps/warehouse/overlays/production/ > /dev/null 2>&1 && echo "OK"
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 6: Delete Orphaned Gateway NetworkPolicy

**File**: `gitops/apps/gateway/base/networkpolicy.yaml`
**Lines**: 1-209
**Risk**: Network isolation rules for Gateway are NOT applied. The file defines comprehensive Ingress/Egress rules with per-service port whitelisting but is missing from `gateway/base/kustomization.yaml` resources list.

**Problem**: `gateway/base/kustomization.yaml` (line 4-11) does NOT list `networkpolicy.yaml`:
```yaml
resources:
  - pdb.yaml
  - worker-pdb.yaml
  - servicemonitor.yaml
  - configmap.yaml
  - ingress.yaml
  - serviceaccount.yaml
  - hpa.yaml
  # networkpolicy.yaml is MISSING
```

**Fix Options**:
- **Option A (Recommended — if NetworkPolicy is desired)**: Add to kustomization:
  ```yaml
  resources:
    - networkpolicy.yaml  # Add this line
  ```
- **Option B (if intentionally disabled)**: Delete the file to avoid confusion.

**Validation**:
```bash
cd gitops && kustomize build apps/gateway/overlays/dev/ > /dev/null 2>&1 && echo "OK"
```

---

### [ ] Task 7: Delete Ghost Files — `common-operations/base/`

**Files**:
- `gitops/apps/common-operations/base/deployment.yaml` (105 lines)
- `gitops/apps/common-operations/base/service.yaml` (23 lines)
- `gitops/apps/common-operations/base/worker-deployment.yaml` (118 lines)

**Risk**: Legacy files from before `common-deployment-v2` component migration. The `common-operations/base/kustomization.yaml` now uses Kustomize components (`common-deployment-v2`, `common-worker-deployment-v2`) which generate Deployment/Service resources. These files are never referenced.

**Problem**: The kustomization uses components to generate Service/Deployment:
```yaml
# common-operations/base/kustomization.yaml (Lines 14-18)
components:
  - ../../../components/common-deployment-v2       # generates Deployment + Service
  - ../../../components/common-worker-deployment-v2  # generates Worker Deployment
```
The standalone `deployment.yaml`, `service.yaml`, `worker-deployment.yaml` are leftover dead code from before the component migration.

**Fix**: Delete all three files.
```bash
rm gitops/apps/common-operations/base/deployment.yaml
rm gitops/apps/common-operations/base/service.yaml
rm gitops/apps/common-operations/base/worker-deployment.yaml
```

**Validation**:
```bash
cd gitops && kustomize build apps/common-operations/overlays/dev/ > /dev/null 2>&1 && echo "OK"
```

---

### [ ] Task 8: Delete Ghost Service — `return/base/service.yaml`

**File**: `gitops/apps/return/base/service.yaml`
**Lines**: 1-23
**Risk**: Same as Task 7. The `return/base/kustomization.yaml` uses `common-deployment-v2` component which generates the Service. This standalone file is never referenced.

**Fix**: Delete the file.
```bash
rm gitops/apps/return/base/service.yaml
```

**Validation**:
```bash
cd gitops && kustomize build apps/return/overlays/dev/ > /dev/null 2>&1 && echo "OK"
```

---

### [ ] Task 9: Delete Ghost Service — `review/base/service.yaml`

**File**: `gitops/apps/review/base/service.yaml`
**Lines**: 1-23
**Risk**: Same as Task 8. `review/base/kustomization.yaml` uses `common-deployment-v2` component.

**Fix**: Delete the file.
```bash
rm gitops/apps/review/base/service.yaml
```

**Validation**:
```bash
cd gitops && kustomize build apps/review/overlays/dev/ > /dev/null 2>&1 && echo "OK"
```

---

### [ ] Task 10: Delete Orphaned Admin ConfigMap

**File**: `gitops/apps/admin/base/configmap.yaml`
**Lines**: 1-12
**Risk**: Low — contains only `api-gateway-url: "https://api.tanhdev.com"`. Not referenced in `admin/base/kustomization.yaml` resources list. Admin config is likely injected via overlay.

**Fix**: Delete the file.
```bash
rm gitops/apps/admin/base/configmap.yaml
```

**Validation**:
```bash
cd gitops && kustomize build apps/admin/overlays/dev/ > /dev/null 2>&1 && echo "OK"
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 11: Delete Orphaned Consul Seed Job

**File**: `gitops/infrastructure/consul-agent/seed-job.yaml`
**Lines**: 1-68
**Risk**: Low — This K8s Job seeds Consul KV store but is not referenced in `consul-agent/kustomization.yaml`. Either the KV seeding was integrated into the Helm chart or done manually.

**Fix**: Delete the file.
```bash
rm gitops/infrastructure/consul-agent/seed-job.yaml
```

---

### [ ] Task 12: Delete Orphaned Consul PrometheusRule

**File**: `gitops/infrastructure/consul-agent/prometheusrule.yaml`
**Lines**: 1-36
**Risk**: Low — Consul alerting rules not applied. If Consul monitoring is managed elsewhere (Helm chart values), this is dead code.

**Fix**: Delete the file.
```bash
rm gitops/infrastructure/consul-agent/prometheusrule.yaml
```

---

### [ ] Task 13: Delete Orphaned Canary Rollout Patch

**File**: `gitops/components/canary-rollout/rollout-patch.yaml`
**Lines**: 1-34
**Risk**: Low — The `canary-rollout/kustomization.yaml` only references `analysis-template.yaml`. The `rollout-patch.yaml` is not used by any Kustomize component. Rollout patches are instead inlined in production overlays (e.g. `checkout/overlays/production/kustomization.yaml` line 27-53).

**Fix**: Delete the file.
```bash
rm gitops/components/canary-rollout/rollout-patch.yaml
```

---

### [ ] Task 14: Delete Orphaned Production Infrastructure Kustomization

**File**: `gitops/environments/production/resources/infrastructure-current.yaml`
**Lines**: 1-26
**Risk**: Low — The parent `environments/production/resources/kustomization.yaml` references `infrastructure.yaml`, NOT `infrastructure-current.yaml`. This file is an old draft/copy.

**Fix**: Delete the file.
```bash
rm gitops/environments/production/resources/infrastructure-current.yaml
```

---

### [ ] Task 15: Delete Stale `build_out.yaml` (Kustomize Build Artifact)

**File**: `gitops/build_out.yaml`
**Lines**: 1-704 (21KB)
**Risk**: Low maintenance noise — This is a `kustomize build` output that was accidentally committed. Contains full rendered manifests including **plaintext Secrets** (analytics DB password, JWT secret, SealedSecret encrypted data, Docker registry credentials at line 77-83, 581). Should NOT be in Git.

**Fix**: Delete the file and add to `.gitignore`.
```bash
rm gitops/build_out.yaml
echo "build_out.yaml" >> gitops/.gitignore
```

**Validation**:
```bash
grep "build_out" gitops/.gitignore  # Should show the entry
```

---

### [ ] Task 16: Add GitOps Linting to CI Pipeline

**Risk**: Without linting, dead code will re-accumulate over time.

**Fix**: Add a CI step that detects orphaned YAML files in Git:
```bash
#!/bin/bash
# Script: scripts/lint-kustomize-orphans.sh
# Finds YAML files that exist in kustomization directories but are not referenced.
exit_code=0
for kustomization in $(find gitops/apps gitops/infrastructure gitops/components -name 'kustomization.yaml'); do
  dir=$(dirname "$kustomization")
  for yaml in "$dir"/*.yaml; do
    basename=$(basename "$yaml")
    [[ "$basename" == "kustomization.yaml" ]] && continue
    if ! grep -q "$basename" "$kustomization"; then
      echo "ORPHAN: $yaml (not in $kustomization)"
      exit_code=1
    fi
  done
done
exit $exit_code
```

---

## 🔧 Pre-Commit Checklist

```bash
# Verify all kustomize builds still work after deletions
for dir in $(find gitops/apps -name 'kustomization.yaml' -path '*/overlays/dev/*' | xargs -I{} dirname {}); do
  echo "Building $dir..."
  cd /Users/tuananh/Desktop/myproject/microservice && kustomize build "$dir" > /dev/null 2>&1 && echo "  ✅ OK" || echo "  ❌ FAIL"
done

# Verify no remaining plaintext secrets
grep -rn "password\|secret\|token" gitops/apps/*/base/secret.yaml 2>/dev/null && echo "⚠️ SECRETS FOUND" || echo "✅ No secrets"
```

---

## 📝 Commit Format

```
chore(gitops): remove 19 orphaned dead code YAML files

- fix: delete plaintext secrets (warehouse, customer, dapr statestore/pubsub)
- fix: delete disconnected worker-hpa files (order, checkout, warehouse)
- chore: delete ghost deployments/services (common-operations, return, review)
- chore: delete stale build_out.yaml and add to .gitignore
- chore: delete orphaned consul seed-job, prometheusrule, canary rollout-patch
- chore: delete orphaned admin configmap, infrastructure-current

Closes: AGENT-07
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| No plaintext secrets in `gitops/` base dirs | `grep -rn password gitops/apps/*/base/secret.yaml` returns empty | |
| No orphaned Dapr config files with passwords | `ls gitops/infrastructure/dapr/` shows only `kustomization.yaml` | |
| Production worker scaling uses KEDA only | `kubectl get scaledobject -A` shows entries for order/checkout/warehouse | |
| All `kustomize build` pass after cleanup | Loop all overlays, zero failures | |
| `build_out.yaml` in `.gitignore` | `grep build_out gitops/.gitignore` matches | |
| Gateway NetworkPolicy decision documented | Either added to kustomization or deleted with reason in commit | |
| CI linting script blocks future orphans | `scripts/lint-kustomize-orphans.sh` exits 0 on clean repo | |
