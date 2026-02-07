# GitOps Codebase Review Checklist

## 🛑 Priority 1: Critical Infrastructure (Runtime Blockers)
- [ ] **Split Brain Routing**
  - [ ] **Issue**: Runtime `gateway-config` lacks Admin Routes (currently hardcoded in Go binary).
  - [ ] **Action**: Consolidate routing into `gateway.yaml` (~30 admin routes).
- [ ] **Secrets Management (Committed Secrets)**
  - [ ] **Issue**: `postgres-secret.yaml` contains base64 encoded passwords in Git.
  - [ ] **Action**: Replace with **ExternalSecrets** operator fetching from Vault.

## 🔐 Priority 2: Secrets Management & Vault Architecture
- [ ] **Vault Architecture Flaw (Critical)**
  - [ ] **Issue**: Vault StatefulSet uses a **Shared PVC** (`claimName: vault-data`) instead of `volumeClaimTemplates`.
  - [ ] **Issue**: Using `file` backend (Legacy) instead of **Raft** for HA.
  - [ ] **Action**: Refactor `statefulset.yaml` to use Raft backend and `volumeClaimTemplates`.
- [ ] **Unseal Security Risk**
  - [ ] **Issue**: `init.sh` stores Unseal Keys inside the same PVC as the data.
  - [ ] **Action**: Integrate with KMS or use Auto-Unseal transit.

## 🔸 Priority 3: Reliability & Scalability
- [ ] **Missing Auto-Scaling (HPA)**
  - [ ] **Issue**: Services (like `auth`) have `replicas: 1` and no HPA in GitOps.
  - [ ] **Action**: Define `hpa.yaml` explicitly in `overlays/production`.
- [ ] **Single Point of Failure (Databases)**
  - [ ] **Issue**: Postgres/Redis are single-replica.
  - [ ] **Action**: Use Operators for HA.

## 🟢 Priority 4: Completed / Verified Items
- [x] **Broken DNS Resolution**
  - [x] **Verified**: `gateway.yaml` now uses FQDNs (e.g., `redis.infrastructure.svc.cluster.local`).
- [x] **Gateway Security Hardening**
  - [x] **Verified**: `StripUntrustedHeaders` implemented in `kratos_middleware.go` (prevents header injection).
  - [x] **Verified**: `CORSMiddleware` refactored to use `corsHandler` with optimized origin checking.
- [x] **Environment Variables**
  - [x] **Verified**: `jwt_secret` uses `${JWT_SECRET}` env var.

## ♻️ Priority 5: Infrastructure Maturity Gap (Tech Lead Assessment)
- [ ] **Observability (Monitoring)**
  - [ ] **Issue**: ServiceMonitors are generated via script `generate-servicemonitors.sh`.
  - [ ] **Action**: Convert to declarative `ServiceMonitor` YAMLs.
- [ ] **Ingress Fragmentation**
  - [ ] **Issue**: Mixed usage of Nginx/Traefik. No Cert-Manager.
  - [ ] **Action**: Standardize Ingress and install Cert-Manager.
- [ ] **Database Tuning**
  - [ ] **Issue**: Postgres uses default config.
  - [ ] **Action**: Inject `postgresql.conf` via ConfigMap.

## 🧹 Priority 6: Housekeeping & Standardization
- [ ] **Deployment Boilerplate**: Refactor using Kustomize Components.
- [ ] **Script to Declarative**: Migrate `deploy.sh` logic to ArgoCD.
- [ ] **Namespace Isolation**: Audit `NetworkPolicy` for correct namespaces.
