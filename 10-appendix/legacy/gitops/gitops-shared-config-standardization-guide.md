# GitOps Shared Configuration Standardization Guide

**Repository**: `/home/user/microservices/gitops`  
**Purpose**: Comprehensive guide for standardizing shared configurations across all services  
**Owner**: DevOps Platform Team  
**Created**: February 6, 2026  
**Status**: 🔴 **Action Required** - Implementation Needed

---

## 📊 Executive Summary

**Codebase Audit Completed**: February 6, 2026

### Current State
- **Total Services**: 24 (21 Go microservices + 2 Node.js apps + 1 vault)
- **Total YAML Files**: 410
- **Total Workloads**: 50 (deployments, workers, migration jobs)
- **Environments**: 2 (dev, production)

### Key Findings

#### ✅ Strengths
1. **Consistent Structure**: All services follow standardized Kustomize base/overlay pattern
2. **Security Context**: All workloads use non-root user (65532)
3. **Monitoring**: ServiceMonitor implemented across all backend services
4. **Network Policies**: Comprehensive egress/ingress rules per service
5. **ArgoCD Sync Waves**: Properly orchestrated deployment sequence

#### 🔴 Critical Issues
1. **No Centralized Secret Management**: `registry-api-tanhdev` referenced 50+ times but never defined in infrastructure
2. **Config Duplication**: Same patterns repeated in 24 services (ServiceAccount, PDB, NetworkPolicy egress rules)
3. **No Shared Patches**: All services duplicate identical YAML blocks
4. **Missing Infrastructure**: `gitops/infrastructure/` exists but contains no manifests
5. **No Automation**: Manual updates required for common changes across all services

---

## 🎯 Shared Configuration Patterns Identified

### 1. **ImagePullSecrets** (CRITICAL - Priority P0)

**Current Status**: 🔴 **Not Standardized**

**Pattern Found**:
```yaml
# Repeated in ALL 50 workload files
spec:
  template:
    spec:
      imagePullSecrets:
      - name: registry-api-tanhdev  # ❌ Never defined in gitops/infrastructure/
```

**Files Affected**: 50
- 24 deployments
- 13 worker-deployments  
- 13 migration-jobs

**Problem**:
- Secret referenced everywhere but never created via GitOps
- Must be manually created in each namespace: `auth-dev`, `catalog-dev`, `warehouse-dev`, etc. (48+ namespaces)
- No version control or audit trail for secret updates
- Credential rotation requires manual updates in 48+ namespaces

**Solution**: See [Shared ImagePullSecret Rollout Checklist](./shared-imagepullsecret-rollout-checklist.md)

---

### 2. **ServiceAccount** (Priority P1)

**Current Status**: ⚠️ **Partially Standardized**

**Pattern Found**:
```yaml
# Identical structure in all services, only name differs
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {service}  # Only variable
  labels:
    app.kubernetes.io/name: {service}
    app.kubernetes.io/component: backend
    app.kubernetes.io/managed-by: kustomize
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:  # Empty spec
```

**Files Affected**: 23+ services

**Problem**:
- 100% code duplication across 23 files
- No centralized RBAC policy
- Adding annotations/labels requires 23 file updates

**Recommendation**: 
- Create Kustomize component: `gitops/components/serviceaccount/`
- Services reference via `components` in kustomization.yaml
- Name automatically substituted via `namePrefix`

---

### 3. **PodDisruptionBudget (PDB)** (Priority P1)

**Current Status**: ⚠️ **Partially Standardized**

**Pattern Found**:
```yaml
# Identical in all services
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {service}
  labels:
    app.kubernetes.io/name: {service}
    app.kubernetes.io/component: backend
    app.kubernetes.io/managed-by: kustomize
spec:
  minAvailable: 1  # Always 1
  selector:
    matchLabels:
      app.kubernetes.io/name: {service}
      app.kubernetes.io/component: backend
```

**Files Affected**: 23+ services

**Problem**:
- Same issue as ServiceAccount
- No environment-specific PDB policies (dev should have minAvailable: 0, prod: 2)
- Changing `minAvailable` requires 23 updates

**Recommendation**:
- Create Kustomize component with environment-specific overlays
- Dev: `minAvailable: 0` (allow full downtime)
- Production: `minAvailable: 2` (high availability)

---

### 4. **ServiceMonitor (Prometheus)** (Priority P1)

**Current Status**: ⚠️ **Partially Standardized**

**Pattern Found**:
```yaml
# Identical across all backend services
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {service}
  labels:
    app.kubernetes.io/name: {service}
    app.kubernetes.io/component: backend
    app.kubernetes.io/managed-by: kustomize
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: {service}
      app.kubernetes.io/component: backend
  endpoints:
    - port: http-svc
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
```

**Files Affected**: 23 backend services

**Problem**:
- Changing scrape interval requires 23 updates
- No differentiation between critical vs non-critical services
- Frontend apps (admin, frontend) missing ServiceMonitor

**Recommendation**:
- Create tiered components:
  - `components/servicemonitor/critical/` (interval: 15s)
  - `components/servicemonitor/standard/` (interval: 30s)
  - `components/servicemonitor/low-priority/` (interval: 60s)

---

### 5. **NetworkPolicy Egress Rules** (Priority P2)

**Current Status**: ⚠️ **Partially Standardized**

**Pattern Found**:
```yaml
# Common egress rules in ALL services
egress:
  # DNS Resolution (required for all)
  - to:
      - namespaceSelector: {}
    ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
  
  # PostgreSQL (all backend services)
  - to:
      - namespaceSelector:
          matchLabels:
            name: infrastructure
        podSelector:
          matchLabels:
            app: postgresql
    ports:
      - protocol: TCP
        port: 5432
  
  # Redis (all backend services)
  - to:
      - namespaceSelector:
          matchLabels:
            name: infrastructure
        podSelector:
          matchLabels:
            app: redis
    ports:
      - protocol: TCP
        port: 6379
  
  # Consul (all backend services)
  - to:
      - namespaceSelector:
          matchLabels:
            name: infrastructure
        podSelector:
          matchLabels:
            app: consul
    ports:
      - protocol: TCP
        port: 8500
```

**Files Affected**: 23+ services

**Problem**:
- ~80% of egress rules are identical (DNS, PostgreSQL, Redis, Consul)
- Changing infrastructure label requires 23 updates
- No easy way to add new shared infrastructure (e.g., Vault, new Redis instance)

**Recommendation**:
- Create `components/networkpolicy/common-egress/`
- Services extend with service-specific rules via `patchesStrategicMerge`

---

### 6. **ConfigMap Patterns** (Priority P2)

**Current Status**: ⚠️ **Partially Standardized**

**Common Keys Found**:
```yaml
data:
  database-url: "postgres://..."     # All backend services
  redis-url: "redis://..."           # All backend services
  log-level: "info"                  # All services
  database-host: "..."               # Services with migrations
  database-port: "5432"              # Services with migrations
  database-name: "{service}_db"      # Services with migrations
```

**Files Affected**: 23+ services

**Problem**:
- Infrastructure endpoints hardcoded 23 times
- Different formats:
  - Auth: `postgresql.infrastructure.svc.cluster.local:5432`
  - Warehouse: `postgresql:5432` (missing FQDN)
- Changing Redis/PostgreSQL endpoint requires 23 updates

**Recommendation**:
- Create `gitops/infrastructure/config/common-infrastructure-config.yaml`
- Services reference via ConfigMapGenerator with merge
- Environment-specific overrides in overlays

---

### 7. **Security Context** (Priority P2)

**Current Status**: ✅ **Well Standardized** (but duplicated)

**Pattern Found**:
```yaml
# Pod-level security context (all services)
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        fsGroup: 65532
      
      containers:
      - name: {service}
        securityContext:
          runAsNonRoot: true
          runAsUser: 65532
```

**Files Affected**: 50 workloads

**Status**: 
- ✅ Excellent security posture
- ⚠️ Could be centralized for easier updates (e.g., migrating to user 1000)

**Recommendation**:
- Create `components/security-context/nonroot-65532/`
- Apply via Kustomize strategic merge patch

---

### 8. **ArgoCD Sync Wave Annotations** (Priority P3)

**Current Status**: ✅ **Well Defined** (but could be templated)

**Standard Pattern**:
```yaml
# ServiceAccount
argocd.argoproj.io/sync-wave: "-1"

# ConfigMap, NetworkPolicy, ServiceMonitor
argocd.argoproj.io/sync-wave: "0"

# Migration Jobs
argocd.argoproj.io/sync-wave: "1"

# Deployments
argocd.argoproj.io/sync-wave: "3" to "5"

# Workers
argocd.argoproj.io/sync-wave: "8"
```

**Files Affected**: 200+ resources

**Status**: Good orchestration, no action needed unless standardizing further

---

## 📋 Implementation Roadmap

### Phase 1: Critical Infrastructure (Week 1)

**Goal**: Eliminate manual cluster operations

- [ ] **Task 1.1**: Create centralized ImagePullSecret management
  - File: `gitops/infrastructure/security/registry-secret.yaml`
  - Follow: [Shared ImagePullSecret Rollout Checklist](./shared-imagepullsecret-rollout-checklist.md)
  
- [ ] **Task 1.2**: Create infrastructure ConfigMap
  - File: `gitops/infrastructure/config/infrastructure-endpoints.yaml`
  - Contents: PostgreSQL, Redis, Consul, Elasticsearch endpoints
  
- [ ] **Task 1.3**: Setup Sealed Secrets or External Secrets Operator
  - Decision: Choose Sealed Secrets (simpler) or ESO (Vault integration)
  - Implementation: Deploy controller + sample sealed secrets

**Success Criteria**:
- ✅ Zero manual `kubectl create secret` commands required
- ✅ All infrastructure endpoints centralized in one file
- ✅ Secrets managed via GitOps with audit trail

---

### Phase 2: Kustomize Components (Week 2-3)

**Goal**: Reduce YAML duplication by 70%+

- [ ] **Task 2.1**: Create reusable components
  ```bash
  gitops/components/
  ├── security-context/
  │   └── nonroot-65532/
  │       ├── kustomization.yaml
  │       └── security-context-patch.yaml
  ├── imagepullsecret/
  │   └── registry-api-tanhdev/
  │       ├── kustomization.yaml
  │       └── imagepullsecret-patch.yaml
  ├── serviceaccount/
  │   └── backend/
  │       ├── kustomization.yaml
  │       └── serviceaccount.yaml
  ├── pdb/
  │   ├── dev/
  │   │   └── kustomization.yaml (minAvailable: 0)
  │   └── production/
  │       └── kustomization.yaml (minAvailable: 2)
  ├── servicemonitor/
  │   ├── critical/
  │   ├── standard/
  │   └── low-priority/
  └── networkpolicy/
      └── common-egress/
          ├── kustomization.yaml
          └── egress-rules.yaml
  ```

- [ ] **Task 2.2**: Update service kustomization.yaml to use components
  ```yaml
  # Example: gitops/apps/auth/base/kustomization.yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  
  components:
  - ../../../components/security-context/nonroot-65532
  - ../../../components/imagepullsecret/registry-api-tanhdev
  - ../../../components/serviceaccount/backend
  - ../../../components/servicemonitor/critical
  
  resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  # Remove: serviceaccount.yaml, servicemonitor.yaml, pdb.yaml
  ```

- [ ] **Task 2.3**: Remove duplicated files from service base directories
  - Delete 23 × serviceaccount.yaml
  - Delete 23 × servicemonitor.yaml
  - Delete 23 × pdb.yaml

**Success Criteria**:
- ✅ Reduce base manifest files by ~60 files
- ✅ Updating shared config requires editing 1 file instead of 23
- ✅ All services build successfully with `kustomize build`

---

### Phase 3: Automation & Validation (Week 4)

**Goal**: Prevent regression and automate common tasks

- [ ] **Task 3.1**: Create validation scripts
  ```bash
  gitops/scripts/
  ├── validate-imagepullsecret.sh    # Ensure all workloads use standard secret
  ├── validate-security-context.sh   # Verify runAsUser: 65532
  ├── validate-kustomize.sh          # Test kustomize build for all apps
  └── validate-argocd-apps.sh        # Check ArgoCD app health
  ```

- [ ] **Task 3.2**: Add pre-commit hooks
  ```yaml
  # .pre-commit-config.yaml
  - repo: local
    hooks:
    - id: validate-kustomize
      name: Validate Kustomize
      entry: scripts/validate-kustomize.sh
      language: script
      pass_filenames: false
  ```

- [ ] **Task 3.3**: Add CI/CD pipeline validation
  ```yaml
  # .gitlab-ci.yml
  validate:gitops:
    stage: test
    script:
      - cd gitops
      - ./scripts/validate-kustomize.sh
      - ./scripts/validate-imagepullsecret.sh
      - ./scripts/validate-security-context.sh
  ```

**Success Criteria**:
- ✅ Pull requests fail if validation scripts fail
- ✅ 100% of apps build successfully before merge
- ✅ No workload can be deployed without standard ImagePullSecret

---

### Phase 4: Documentation & Training (Week 5)

**Goal**: Team adoption and knowledge transfer

- [ ] **Task 4.1**: Update documentation
  - [ ] Create `gitops/docs/components-guide.md` explaining each component
  - [ ] Update `gitops/README.md` with new structure
  - [ ] Create `gitops/docs/adding-new-service.md` template
  
- [ ] **Task 4.2**: Create runbooks
  - [ ] `docs/runbooks/rotate-registry-credentials.md`
  - [ ] `docs/runbooks/update-infrastructure-endpoints.md`
  - [ ] `docs/runbooks/add-new-shared-component.md`

- [ ] **Task 4.3**: Team training
  - [ ] Present new structure in team meeting
  - [ ] Pair programming session for 2-3 services
  - [ ] Update onboarding documentation

**Success Criteria**:
- ✅ All team members can add new service using components
- ✅ Runbooks tested and validated
- ✅ Documentation reviewed and approved

---

## 🛠️ Technical Implementation Examples

### Example 1: Centralized ImagePullSecret Component

**File**: `gitops/components/imagepullsecret/registry-api-tanhdev/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    - op: add
      path: /spec/template/spec/imagePullSecrets
      value:
      - name: registry-api-tanhdev
  target:
    kind: Deployment
- patch: |-
    - op: add
      path: /spec/template/spec/imagePullSecrets
      value:
      - name: registry-api-tanhdev
  target:
    kind: Job
```

**Usage in Service**:
```yaml
# gitops/apps/auth/base/kustomization.yaml
components:
- ../../../components/imagepullsecret/registry-api-tanhdev

resources:
- deployment.yaml  # No need to specify imagePullSecrets!
```

---

### Example 2: Environment-Specific PDB Component

**File**: `gitops/components/pdb/production/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
- pdb.yaml

replacements:
- source:
    kind: Kustomization
    fieldPath: metadata.name
  targets:
  - select:
      kind: PodDisruptionBudget
    fieldPaths:
    - metadata.name
    - spec.selector.matchLabels.[app.kubernetes.io/name]
```

**File**: `gitops/components/pdb/production/pdb.yaml`
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: placeholder  # Replaced by kustomization
spec:
  minAvailable: 2  # Production: high availability
  selector:
    matchLabels:
      app.kubernetes.io/name: placeholder
```

---

### Example 3: Common Network Egress Component

**File**: `gitops/components/networkpolicy/common-egress/egress-rules.yaml`
```yaml
# This will be merged with service-specific NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: common-egress
spec:
  egress:
  # DNS
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  
  # PostgreSQL
  - to:
    - namespaceSelector:
        matchLabels:
          name: infrastructure
      podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  
  # Redis
  - to:
    - namespaceSelector:
        matchLabels:
          name: infrastructure
      podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  
  # Consul
  - to:
    - namespaceSelector:
        matchLabels:
          name: infrastructure
      podSelector:
        matchLabels:
          app: consul
    ports:
    - protocol: TCP
      port: 8500
```

---

## 📊 Expected Benefits

### Before Standardization
- **YAML Files**: 410
- **Duplicated Config Blocks**: ~200
- **Manual Secret Management**: 48+ namespaces
- **Update Overhead**: Change 1 setting = edit 23 files
- **Maintenance Time**: ~4 hours per infrastructure change

### After Standardization
- **YAML Files**: ~250 (39% reduction)
- **Duplicated Config Blocks**: ~20 (90% reduction)
- **Manual Secret Management**: 0 namespaces
- **Update Overhead**: Change 1 setting = edit 1 file
- **Maintenance Time**: ~30 minutes per infrastructure change

### ROI Calculation
- **Time Saved per Month**: ~16 engineer hours
- **Error Reduction**: ~85% (fewer manual edits)
- **Onboarding Time**: 2 days → 4 hours (faster ramp-up)
- **Audit Compliance**: 100% (all changes in Git)

---

## ✅ Validation Checklist

Use this checklist after completing each phase:

### Phase 1 Complete
- [ ] `kubectl get secret registry-api-tanhdev -n auth-dev` returns secret (not manual)
- [ ] All infrastructure endpoints defined in `gitops/infrastructure/config/`
- [ ] Sealed Secrets controller deployed and functional
- [ ] Test: Rotate registry password via GitOps, verify pods pull images

### Phase 2 Complete
- [ ] `kustomize build gitops/apps/auth/overlays/dev` succeeds without errors
- [ ] Generated manifest includes imagePullSecrets from component
- [ ] `find gitops/apps -name "serviceaccount.yaml" | wc -l` returns 0
- [ ] Deploy one service to dev cluster, verify no functionality regression

### Phase 3 Complete
- [ ] Pre-commit hook blocks commits with missing ImagePullSecret
- [ ] CI pipeline validates all 24 services build successfully
- [ ] `./scripts/validate-security-context.sh` passes for all services

### Phase 4 Complete
- [ ] New team member adds a service using components without assistance
- [ ] Runbook tested: Rotate registry credentials in <10 minutes
- [ ] Documentation reviewed by 3+ team members

---

## 🚨 Risks & Mitigation

### Risk 1: Breaking Changes During Rollout
**Likelihood**: Medium  
**Impact**: High  
**Mitigation**:
- Deploy to dev environment first, validate for 48 hours
- Use ArgoCD sync waves to roll out gradually (1 service/hour)
- Keep rollback plan: Git revert + ArgoCD sync

### Risk 2: Component Incompatibility with Existing Manifests
**Likelihood**: Low  
**Impact**: Medium  
**Mitigation**:
- Test components with `kustomize build` before removing old files
- Use `kubectl diff` to compare old vs new manifests
- Validate in non-production cluster first

### Risk 3: Team Adoption Resistance
**Likelihood**: Low  
**Impact**: Medium  
**Mitigation**:
- Involve team in design phase
- Show time savings with metrics
- Provide comprehensive training

---

## 📞 Support & Escalation

### Implementation Support
- **Primary Contact**: DevOps Platform Team Lead
- **Technical SME**: Senior DevOps Engineer (GitOps specialist)
- **Slack Channel**: `#platform-gitops`

### Escalation Path
1. Component build errors → DevOps Platform Team
2. ArgoCD sync failures → SRE Team
3. Production deployment issues → Incident Commander

---

**Document Version**: 1.0  
**Author**: DevOps Platform Team  
**Last Updated**: February 6, 2026  
**Next Review**: March 6, 2026 (post Phase 1 completion)
