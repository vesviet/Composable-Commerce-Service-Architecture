# ArgoCD Configuration - Code Review & Issues Checklist

**Last Updated**: 2026-01-21  
**Review Type**: Senior Lead - Production Readiness Assessment  
**Overall Score**: 6.5/10 (NOT PRODUCTION READY - requires critical security fixes)

---

## 📊 EXECUTIVE SUMMARY

**Production-Readiness Assessment**: 6.5/10

| Category | Score | Status |
|----------|-------|--------|
| Code Quality (Helm/YAML) | 7.5/10 | ✅ Well-structured templates |
| Security | 4.0/10 | 🔴 **CRITICAL** - Hardcoded secrets, weak crypto |
| Reliability | 7.0/10 | ⚠️ Missing health checks, no PDB |
| Performance | 6.5/10 | ⚠️ Resource limits too high |
| Observability | 5.5/10 | 🔴 No metrics, limited logging |
| Resilience | 6.0/10 | ⚠️ Missing retry logic, no circuit breakers |

**Critical Findings**:
- 🔴 **5 P0 Issues**: Hardcoded secrets, weak encryption keys, privileged containers, no RBAC, exposed DB passwords
- 🟡 **6 P1 Issues**: Missing PDB, no resource quotas, weak probes, no monitoring
- 🟢 **4 P2 Issues**: Missing docs, no backup strategy, manual sync only

**Estimated Effort to Production**: 3-4 weeks (P0: 1-2 weeks, P1: 1 week, Hardening: 1 week)

---

## 🚩 PENDING ISSUES (Unfixed)

### 🔴 CRITICAL (P0 - Blocking Production)

#### **P0-1: Hardcoded Secrets in values-base.yaml (All Services)**
**Severity**: 🔴 **CRITICAL - Security Breach Risk**  
**Impact**: Secrets committed to Git, easily extractable, compliance violation  
**Effort**: 1-2 weeks

**Files Affected** (19 services):
- [argocd/applications/main/catalog/values-base.yaml:168-174](../../argocd/applications/main/catalog/values-base.yaml#L168) - Database passwords, encryption keys
- [argocd/applications/main/auth/values-base.yaml:206-212](../../argocd/applications/main/auth/values-base.yaml#L206) - JWT secrets, DB passwords
- [argocd/applications/main/order/values-base.yaml:192-197](../../argocd/applications/main/order/values-base.yaml#L192) - Encryption keys
- [argocd/applications/main/payment/values-base.yaml:221-228](../../argocd/applications/main/payment/values-base.yaml#L221) - Payment API keys
- **ALL 19 SERVICES AFFECTED**

**Issue Description**:
```yaml
# ❌ CRITICAL: Plaintext secrets in Git
secrets:
  databaseUrl: "postgresql://postgres:postgres@postgresql.infrastructure.svc.cluster.local:5432/catalog_db?sslmode=disable"
  databaseUser: "postgres"
  databasePassword: "postgres"  # ❌ Hardcoded password
  encryptionKey: "my-secret-key-32-characters-long"  # ❌ Weak, hardcoded
  redisPassword: ""
```

**Consequences**:
- ❌ **PCI-DSS violation**: Passwords in version control
- ❌ **SOC2 violation**: No secret rotation
- ❌ **GDPR risk**: Encryption keys exposed
- ❌ Git history permanently contains secrets
- ❌ Anyone with repo access has production credentials

**Recommended Fix - Option 1: Sealed Secrets (Recommended)**:
```yaml
# ✅ GOOD: Use Bitnami Sealed Secrets
# 1. Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# 2. Create secret and seal it
echo -n 'postgres' | kubectl create secret generic catalog-db \
  --dry-run=client \
  --from-file=password=/dev/stdin \
  -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# 3. Reference in values.yaml
secrets:
  # Create sealed secret separately, reference by name
  useExternalSecret: true
  existingSecret: "catalog-db-sealed"
```

**Recommended Fix - Option 2: External Secrets Operator**:
```yaml
# ✅ GOOD: Use External Secrets with AWS Secrets Manager/Vault
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: catalog-secrets
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: catalog-secrets
  data:
  - secretKey: database-password
    remoteRef:
      key: /prod/catalog/db-password
  - secretKey: encryption-key
    remoteRef:
      key: /prod/catalog/encryption-key
```

**Action Items**:
1. ✅ Install Sealed Secrets or External Secrets Operator
2. ✅ Migrate ALL 19 services to external secret management
3. ✅ Remove plaintext secrets from values-base.yaml
4. ✅ Rotate all exposed credentials immediately
5. ✅ Add pre-commit hook to prevent future commits with secrets
6. ✅ Audit Git history for exposed secrets (use `truffleHog` or `gitleaks`)

---

#### **P0-2: Weak/Default Encryption Keys (Security Risk)**
**Severity**: 🔴 **CRITICAL - Data Encryption Compromised**  
**Impact**: PII/PCI data easily decrypted, compliance violation  
**Effort**: 3 days

**Files Affected**:
- All services with `encryptionKey` fields (catalog, auth, order, payment, etc.)

**Issue**:
```yaml
# ❌ BAD: Weak, predictable encryption keys
secrets:
  encryptionKey: "my-secret-key-32-characters-long"  # ❌ Default value
  encryptionKey: "order-secret-key-32-chars-long!!!" # ❌ Weak entropy
  encryptionKey: "review-secret-key-32-chars-long!"  # ❌ Similar patterns
```

**Consequences**:
- ❌ Encrypted customer data (PII, payment info) easily decrypted
- ❌ Compliance failure (PCI-DSS requires strong keys)
- ❌ Keys guessable from pattern

**Recommended Fix**:
```bash
# ✅ GOOD: Generate cryptographically secure keys
openssl rand -base64 32

# ✅ Store in secret manager with rotation policy
aws secretsmanager create-secret \
  --name /prod/catalog/encryption-key \
  --secret-string "$(openssl rand -base64 32)" \
  --rotation-rules AutomaticallyAfterDays=90
```

---

#### **P0-3: Database Passwords Use Default/Weak Credentials**
**Severity**: 🔴 **CRITICAL - Database Breach Risk**  
**Impact**: Unauthorized DB access, data exfiltration  
**Effort**: 1 week

**Files Affected**:
- All service values-base.yaml files

**Issue**:
```yaml
# ❌ CRITICAL: Default PostgreSQL credentials
secrets:
  databaseUser: "postgres"  # ❌ Default superuser
  databasePassword: "postgres"  # ❌ Default password
  databaseUrl: "postgresql://postgres:postgres@..."  # ❌ Embedded credentials
```

**Consequences**:
- ❌ Anyone can connect to database with default creds
- ❌ No principle of least privilege (using superuser)
- ❌ Credentials exposed in connection strings

**Recommended Fix**:
```yaml
# ✅ GOOD: Use unique, strong passwords per service
secrets:
  databaseUser: "catalog_app_user"  # Dedicated user per service
  databasePassword:  # Reference external secret
    secretKeyRef:
      name: catalog-db-credentials
      key: password

# ✅ Create least-privilege DB users
CREATE USER catalog_app_user WITH PASSWORD '<strong-random-password>';
GRANT CONNECT ON DATABASE catalog_db TO catalog_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO catalog_app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO catalog_app_user;
```

---

#### **P0-4: Container Security Context Empty/Permissive**
**Severity**: 🔴 **CRITICAL - Container Escape Risk**  
**Impact**: Privilege escalation, node compromise  
**Effort**: 3 days

**Files Affected**:
- [argocd/applications/main/catalog/values-base.yaml:33](../../argocd/applications/main/catalog/values-base.yaml#L33)
- [argocd/applications/main/frontend/values-base.yaml:25](../../argocd/applications/main/frontend/values-base.yaml#L25)
- Multiple services with `securityContext: {}`

**Issue**:
```yaml
# ❌ BAD: Empty security context
podSecurityContext:
  runAsNonRoot: true  # ✅ Good
  runAsUser: 65532    # ✅ Good
  fsGroup: 65532      # ✅ Good

securityContext: {}   # ❌ MISSING container-level restrictions
```

**Consequences**:
- ❌ Container can write to filesystem (if volume mounted)
- ❌ No capability dropping (can escalate privileges)
- ❌ Root access possible inside container

**Recommended Fix**:
```yaml
# ✅ GOOD: Restrictive container security context
securityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 65532
  readOnlyRootFilesystem: true  # Prevent filesystem writes
  capabilities:
    drop:
      - ALL  # Drop all capabilities
    add:
      - NET_BIND_SERVICE  # Only if needed for port <1024
  seccompProfile:
    type: RuntimeDefault
```

**Required Changes**:
```yaml
# Add writable volumes only where needed
volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /app/cache

volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
```

---

#### **P0-5: No Network Policies (Unrestricted Service Communication)**
**Severity**: 🔴 **CRITICAL - Lateral Movement Risk**  
**Impact**: Compromised pod can access all services  
**Effort**: 5 days

**Files Affected**:
- [argocd/applications/main/catalog/values-base.yaml:201](../../argocd/applications/main/catalog/values-base.yaml#L201)
- All services: `networkPolicy.enabled: false`

**Issue**:
```yaml
# ❌ BAD: Network policy disabled
networkPolicy:
  enabled: false  # ❌ No network segmentation
```

**Consequences**:
- ❌ Any pod can connect to any service (no zero-trust)
- ❌ Compromised frontend can access database directly
- ❌ No defense in depth

**Recommended Fix**:
```yaml
# ✅ GOOD: Enable network policies with least privilege
networkPolicy:
  enabled: true
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: core-business-prod
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: gateway  # Only gateway can call catalog
      ports:
      - protocol: TCP
        port: 8000
      - protocol: TCP
        port: 9000
  
  egress:
    - to:
      - namespaceSelector:
          matchLabels:
            name: infrastructure
      - podSelector:
          matchLabels:
            app: postgresql
      ports:
      - protocol: TCP
        port: 5432
    - to:  # Allow DNS
      - namespaceSelector:
          matchLabels:
            name: kube-system
      ports:
      - protocol: UDP
        port: 53
```

---

### 🟡 HIGH PRIORITY (P1 - Required for Launch)

#### **P1-1: No Pod Disruption Budget (Availability Risk)**
**Severity**: 🟡 **HIGH - Service Downtime During Updates**  
**Impact**: Zero replicas during deployments, service outages  
**Effort**: 2 days

**Files Affected**:
- [argocd/applications/main/catalog/values-base.yaml:198-200](../../argocd/applications/main/catalog/values-base.yaml#L198)
- All services: `podDisruptionBudget.enabled: false`

**Issue**:
```yaml
# ❌ BAD: PDB disabled
podDisruptionBudget:
  enabled: false  # ❌ No availability guarantee during disruptions
  minAvailable: 1
```

**Consequences**:
- ❌ Node drain can terminate all pods simultaneously
- ❌ Deployments can cause zero-downtime violations
- ❌ Cluster upgrades cause service outages

**Recommended Fix**:
```yaml
# ✅ GOOD: Enable PDB for high availability
podDisruptionBudget:
  enabled: true
  minAvailable: 1  # At least 1 pod always available

# ✅ For production with 3+ replicas
replicaCount: 3
podDisruptionBudget:
  enabled: true
  maxUnavailable: 1  # Allow only 1 pod down at a time
```

---

#### **P1-2: Missing Service Monitor (No Prometheus Metrics)**
**Severity**: 🟡 **HIGH - No Observability**  
**Impact**: Cannot detect issues, no SLO tracking  
**Effort**: 3 days

**Files Affected**:
- All services: `serviceMonitor.enabled: false`

**Issue**:
```yaml
# ❌ BAD: Metrics scraping disabled
serviceMonitor:
  enabled: false  # ❌ No Prometheus integration
```

**Fix**:
```yaml
# ✅ GOOD: Enable Prometheus metrics
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
  path: /metrics
  labels:
    prometheus: kube-prometheus
```

---

#### **P1-3: Resource Limits Too High (Cost & OOM Risk)**
**Severity**: 🟡 **MEDIUM - Resource Waste**  
**Impact**: Expensive, OOM kills during spikes  
**Effort**: 1 week (requires load testing)

**Issue**:
```yaml
# ❌ BAD: Overly generous limits
resources:
  limits:
    cpu: 500m      # ❌ Too high for most services
    memory: 1Gi    # ❌ Can cause OOM during spikes
  requests:
    cpu: 200m
    memory: 512Mi
```

**Fix**:
```yaml
# ✅ GOOD: Right-sized based on load testing
resources:
  limits:
    cpu: 200m      # 2x request
    memory: 512Mi  # Tight limit to prevent OOM
  requests:
    cpu: 100m      # Baseline from monitoring
    memory: 256Mi  # p95 from metrics
```

---

#### **P1-4: Liveness Probe Too Aggressive (Restart Loops)**
**Severity**: 🟡 **MEDIUM - Service Instability**  
**Impact**: Premature pod restarts, cascading failures  
**Effort**: 2 days

**Issue**:
```yaml
# ⚠️ RISKY: Aggressive failure threshold
livenessProbe:
  initialDelaySeconds: 90   # ✅ Good
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 5       # ⚠️ 50s to kill = too aggressive
```

**Fix**:
```yaml
# ✅ BETTER: More conservative liveness probe
livenessProbe:
  initialDelaySeconds: 120  # Longer startup time
  periodSeconds: 30         # Check every 30s (not 10s)
  timeoutSeconds: 10
  failureThreshold: 3       # 90s grace period
```

---

#### **P1-5: Migration Job Has No Failure Handling**
**Severity**: 🟡 **MEDIUM - Migration Failures Block Deployments**  
**Impact**: Stuck deployments, manual intervention required  
**Effort**: 2 days

**Files Affected**:
- [argocd/applications/main/catalog/templates/migration-job.yaml:14](../../argocd/applications/main/catalog/templates/migration-job.yaml#L14)

**Issue**:
```yaml
# ❌ BAD: Job fails permanently after 3 retries
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 3  # ❌ Only 3 retries
```

**Fix**:
```yaml
# ✅ GOOD: More resilient migration job
spec:
  ttlSecondsAfterFinished: 600  # Keep logs longer
  backoffLimit: 5  # More retries for transient DB issues
  activeDeadlineSeconds: 600  # Kill if stuck for 10min
```

---

#### **P1-6: No Resource Quotas per Namespace**
**Severity**: 🟡 **MEDIUM - Noisy Neighbor Risk**  
**Impact**: One service can starve others  
**Effort**: 1 day

**Fix**:
```yaml
# ✅ ADD: ResourceQuota per namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: core-business-prod
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    pods: "100"
```

---

### 🟢 MEDIUM PRIORITY (P2 - Post-Launch)

#### **P2-1: No Horizontal Pod Autoscaler Configured**
**File**: All services: `autoscaling.enabled: false`  
**Fix**: Enable HPA for production workloads

#### **P2-2: Sync Policy Too Aggressive (Auto-Prune)**
**File**: [argocd/applications/main/catalog/catalog-appSet.yaml:38-42](../../argocd/applications/main/catalog/catalog-appSet.yaml#L38)  
**Issue**: `prune: true` can delete resources unexpectedly  
**Fix**: Use `prune: false` for production, manual approval

#### **P2-3: No Backup Strategy Documented**
**Impact**: No disaster recovery plan  
**Fix**: Add Velero backup annotations

#### **P2-4: Production AppProject Has No Sync Windows**
**File**: [argocd/applications/argocd-projects/production.yaml:43-48](../../argocd/applications/argocd-projects/production.yaml#L43)  
**Issue**: Can deploy anytime (commented out)  
**Fix**: Enforce sync windows for production safety

---

## 🆕 NEWLY DISCOVERED ISSUES

### ⚠️ Missing Observability

#### **Logs**
- ❌ No centralized logging (Loki/ELK)
- ❌ No log retention policy
- ❌ No structured logging format enforced

#### **Metrics**
- ❌ ServiceMonitor disabled (no Prometheus scraping)
- ❌ No custom metrics (latency, error rate)
- ❌ No alerting rules defined
- ❌ No Grafana dashboards

#### **Traces**
- ❌ No OpenTelemetry/Jaeger integration
- ❌ No distributed tracing headers
- ❌ Cannot debug cross-service issues

---

### ⚠️ Missing Resilience Features

#### **Retries**
- ❌ Migration job only retries 3 times
- ❌ No exponential backoff
- ❌ No jitter to prevent thundering herd

#### **Circuit Breakers**
- ❌ No service mesh (Istio/Linkerd)
- ❌ Application-level circuit breakers only
- ❌ No automatic failover

#### **Rate Limiting**
- ❌ No ingress rate limiting
- ❌ No per-user rate limiting
- ❌ No DDoS protection

---

### 📋 Configuration Quality Issues

#### **Helm Best Practices: 7/10**
- ✅ Clean template structure
- ✅ Proper label selectors
- ✅ Sync waves for ordering
- ⚠️ Inconsistent naming (some use fullname, some override)
- ⚠️ Secrets in values (should be external)

#### **YAML Quality: 7.5/10**
- ✅ Proper indentation
- ✅ Comments where needed
- ⚠️ Hardcoded values (should use variables)
- ⚠️ No linting (yamllint config exists but not enforced)

---

## 🎯 ACTION PLAN

### **Week 1 (P0 - Security Critical)**
1. ✅ **Day 1-2**: Install Sealed Secrets or External Secrets Operator
2. ✅ **Day 3-5**: Migrate all 19 services to external secret management
3. ✅ **Day 5**: Rotate ALL exposed credentials (DB, Redis, encryption keys)
4. ✅ **Day 5**: Add pre-commit hooks to prevent future secret leaks

### **Week 2 (P0 - Security Hardening)**
5. ✅ **Day 1-2**: Add container security contexts to all services
6. ✅ **Day 3-4**: Implement network policies (whitelist approach)
7. ✅ **Day 5**: Create least-privilege DB users per service

### **Week 3 (P1 - Reliability & Observability)**
8. ✅ **Day 1**: Enable Pod Disruption Budgets for all services
9. ✅ **Day 2**: Enable ServiceMonitors + create Grafana dashboards
10. ✅ **Day 3-4**: Right-size resource limits based on load testing
11. ✅ **Day 5**: Tune probes + add failure handling to migration jobs

### **Week 4 (P1 - Operational Excellence)**
12. ✅ **Day 1**: Add ResourceQuotas per namespace
13. ✅ **Day 2**: Configure HPA for production services
14. ✅ **Day 3**: Implement backup strategy (Velero)
15. ✅ **Day 4**: Add alerting rules (Prometheus AlertManager)
16. ✅ **Day 5**: Production sync windows + runbook documentation

---

## 📈 POSITIVE HIGHLIGHTS

**What This ArgoCD Config Does Well:**
- ✅ Clean, consistent Helm chart structure across all services
- ✅ Proper use of sync waves for deployment ordering
- ✅ ApplicationSet pattern for multi-environment management
- ✅ Separate AppProjects per environment (dev/staging/production)
- ✅ Proper health checks (liveness/readiness) configured
- ✅ Pod security context enforces non-root (good start)
- ✅ Dapr sidecar integration well-configured
- ✅ Resource requests/limits defined (though need tuning)

**Architecture Wins:**
- ✅ GitOps-native (declarative, version controlled)
- ✅ Environment-specific overrides (values-base.yaml + env/values.yaml)
- ✅ Modular structure (19 services independently deployable)
- ✅ Migration jobs as pre-sync hooks (good pattern)
- ✅ Worker deployments separate from API pods

---

## 📋 FINAL VERDICT

**Current State**: **6.5/10 - NOT PRODUCTION READY**  
**After P0 Fixes**: **8.5/10 - PRODUCTION READY WITH MONITORING**

**Risk Assessment**:
- 🔴 **Critical Risk**: Hardcoded secrets (P0-1, P0-2, P0-3) - IMMEDIATE ACTION REQUIRED
- 🔴 **High Risk**: Missing security contexts (P0-4), no network policies (P0-5)
- 🟡 **Medium Risk**: No observability, weak resilience
- 🟢 **Low Risk**: Architecture, structure, deployment patterns

**Deployment Recommendation**: **BLOCK PRODUCTION until P0 issues fixed**

**Estimated Timeline**:
- P0 fixes (security): **2 weeks** (critical, cannot skip)
- P1 fixes (reliability): **1 week** (required for stability)
- P2 fixes (operational): **1 week** (nice to have)
- **Total: ~4 weeks to production-ready**

The ArgoCD configuration is **well-structured architecturally** but suffers from **critical security vulnerabilities** that must be addressed before production deployment. The P0 secret management issue alone is a showstopper.

---

## 📚 REFERENCES

**Security Tools**:
- Sealed Secrets: https://github.com/bitnami-labs/sealed-secrets
- External Secrets: https://external-secrets.io/
- Trivy (vulnerability scanning): https://github.com/aquasecurity/trivy
- gitleaks (secret detection): https://github.com/gitleaks/gitleaks

**Best Practices**:
- Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- Network Policies: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- ArgoCD Best Practices: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/

---

## ✅ RESOLVED / FIXED
None

---

## Notes
- ALL services (19 total) share same issues - fixes must be applied consistently
- Post-deployment: Conduct security audit with penetration testing
- Implement secret rotation policy (90 days max)
- Add disaster recovery drills (backup restore testing)
- Monitor ArgoCD sync status daily until stable

---
