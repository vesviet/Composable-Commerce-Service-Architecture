# 🎯 ArgoCD Configuration Standardization - Implementation Checklist

## 📋 Overview

**Target**: Standardize ArgoCD configurations across all 21 services  
**Priority**: High - Critical for maintainability and consistency  
**Timeline**: 2-3 weeks  
**Status**: 🔄 **Ready to Implement**

## 🎯 Goals

1. **✅ Standardize health check paths** across all services
2. **✅ Unify probe configurations** for consistency
3. **✅ Add missing PodDisruptionBudgets** for reliability
4. **✅ Standardize worker configurations** where applicable
5. **✅ Add advanced feature templates** for future use

---

## 📊 Current Status Analysis

### **Services Requiring Updates:**
| Service | Health Path Issue | Probe Config | PDB Missing | Worker Config | Priority |
|---------|-------------------|--------------|-------------|---------------|----------|
| **auth-service** | ❌ `/api/v1/auth/health` | ❌ Non-standard | ✅ Has PDB | ❌ No worker | 🔴 High |
| **shipping-service** | ❌ `/v1/shipping/health` | ❌ Non-standard | ❓ Unknown | ✅ Has worker | 🔴 High |
| **location-service** | ❌ `/v1/location/health` | ❌ Non-standard | ❓ Unknown | ❌ No worker | 🔴 High |
| **All other services** | ✅ `/health` | ❌ Variations | ❓ Need check | ❓ Need check | 🟡 Medium |

---

## 🎯 Phase 1: Critical Health Check Standardization

### Step 1.1: Update Non-Standard Health Paths

**Target Services**: auth-service, shipping-service, location-service

#### **auth-service** - Update Health Path
```bash
# File: argocd/applications/auth-service/values.yaml
# Current: /api/v1/auth/health
# Target:  /health
```

**Changes Required:**
```yaml
# OLD
livenessProbe:
  httpGet:
    path: /api/v1/auth/health
    port: 80

readinessProbe:
  httpGet:
    path: /api/v1/auth/health
    port: 80

# NEW
livenessProbe:
  httpGet:
    path: /health
    port: 80

readinessProbe:
  httpGet:
    path: /health
    port: 80
```

#### **shipping-service** - Update Health Path
```bash
# File: argocd/applications/shipping-service/values.yaml
# Current: /v1/shipping/health
# Target:  /health
```

**Changes Required:**
```yaml
# OLD
livenessProbe:
  httpGet:
    path: /v1/shipping/health
    port: 80

readinessProbe:
  httpGet:
    path: /v1/shipping/health
    port: 80

# NEW
livenessProbe:
  httpGet:
    path: /health
    port: 80

readinessProbe:
  httpGet:
    path: /health
    port: 80
```

#### **location-service** - Update Health Path
```bash
# File: argocd/applications/location-service/values.yaml
# Current: /v1/location/health
# Target:  /health
```

**Changes Required:**
```yaml
# OLD
livenessProbe:
  httpGet:
    path: /v1/location/health
    port: 80

readinessProbe:
  httpGet:
    path: /v1/location/health
    port: 80

# NEW
livenessProbe:
  httpGet:
    path: /health
    port: 80

readinessProbe:
  httpGet:
    path: /health
    port: 80
```

### Step 1.2: Update Gateway Service Configuration

**File**: `argocd/applications/gateway/values.yaml`

**Update service health paths in routing config:**
```yaml
# OLD
services:
  shipping:
    health_path: /v1/shipping/health
  location:
    health_path: /v1/location/health

# NEW
services:
  shipping:
    health_path: /health
  location:
    health_path: /health
```

### ✅ Step 1 Completion Checklist
- [ ] Update auth-service health path to `/health`
- [ ] Update shipping-service health path to `/health`
- [ ] Update location-service health path to `/health`
- [ ] Update gateway routing configuration
- [ ] Test health checks work correctly
- [ ] Verify ArgoCD sync successful

---

## 🎯 Phase 2: Standardize Probe Configurations

### Step 2.1: Create Standard Probe Template

**Standard Configuration for All Services:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 60    # Allow service to start
  periodSeconds: 10          # Check every 10 seconds
  timeoutSeconds: 5          # 5 second timeout
  failureThreshold: 5        # 5 failures before restart

readinessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 30    # Faster than liveness
  periodSeconds: 5           # Check every 5 seconds
  timeoutSeconds: 3          # 3 second timeout
  failureThreshold: 3        # 3 failures before unready

# Optional: Add startup probe for slow-starting services
startupProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 20
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 24       # 2 minutes total startup time
```

### Step 2.2: Apply Standard Probes to All Services

**Services to Update** (apply standard probe config):
- [ ] auth-service
- [ ] user-service
- [ ] catalog-service
- [ ] order-service
- [ ] payment-service
- [ ] warehouse-service
- [ ] shipping-service
- [ ] customer-service
- [ ] pricing-service
- [ ] promotion-service
- [ ] fulfillment-service
- [ ] notification-service
- [ ] search-service
- [ ] review-service
- [ ] location-service
- [ ] common-operations-service

**Exception**: Gateway already has good probe config, keep as-is.

### ✅ Step 2 Completion Checklist
- [ ] Apply standard probe config to all 16 services
- [ ] Verify probe settings are consistent
- [ ] Test probe functionality
- [ ] Monitor for any startup issues

---

## 🎯 Phase 3: Add PodDisruptionBudgets

### Step 3.1: Create PDB Template

**Standard PDB Configuration:**
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1  # Staging: 1, Production: 2 (set in env-specific values)
  # Alternative: maxUnavailable: 1
```

**Template File**: `templates/pdb.yaml`
```yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "service.fullname" . }}
  labels:
    {{- include "service.labels" . | nindent 4 }}
spec:
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "service.selectorLabels" . | nindent 6 }}
{{- end }}
```

### Step 3.2: Add PDB to Services Missing It

**Services Confirmed Need PDB** (verify and add if missing):
- [ ] user-service
- [ ] catalog-service
- [ ] order-service
- [ ] payment-service
- [ ] warehouse-service
- [ ] shipping-service
- [ ] customer-service
- [ ] pricing-service
- [ ] promotion-service
- [ ] fulfillment-service
- [ ] notification-service
- [ ] search-service
- [ ] review-service
- [ ] location-service
- [ ] common-operations-service

**Services Already Have PDB:**
- ✅ gateway (confirmed)
- ✅ auth-service (confirmed)

### Step 3.3: Configure Environment-Specific PDB Values

**Staging Configuration** (`staging/values.yaml`):
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

**Production Configuration** (`production/values.yaml`):
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

### ✅ Step 3 Completion Checklist
- [ ] Create `templates/pdb.yaml` for services missing it
- [ ] Add PDB config to `values.yaml` for all services
- [ ] Configure staging values (minAvailable: 1)
- [ ] Configure production values (minAvailable: 2)
- [ ] Test PDB functionality

---

## 🎯 Phase 4: Standardize Worker Configurations

### Step 4.1: Create Standard Worker Template

**Standard Worker Configuration:**
```yaml
worker:
  enabled: true
  replicaCount: 1
  image:
    repository: registry-api.tanhdev.com/{service-name}
    pullPolicy: IfNotPresent
    tag: ""  # Uses same tag as main service
  
  podAnnotations:
    dapr.io/enabled: "true"
    dapr.io/app-id: "{service-name}-worker"
    dapr.io/app-port: "5005"        # Standard gRPC port for Dapr
    dapr.io/app-protocol: "grpc"    # Workers use gRPC protocol
  
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 65532
    fsGroup: 65532
  
  securityContext: {}
  
  resources:
    limits:
      cpu: 300m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
  
  # No health checks for workers (they're background processes)
  # Workers should implement Dapr health checks instead
```

### Step 4.2: Update Services with Workers

**Services with Workers** (standardize configuration):
- [ ] catalog-service
- [ ] order-service
- [ ] payment-service
- [ ] warehouse-service
- [ ] shipping-service
- [ ] customer-service
- [ ] fulfillment-service
- [ ] notification-service
- [ ] search-service
- [ ] common-operations-service

**Key Changes to Apply:**
1. **Dapr Port**: Ensure `dapr.io/app-port: "5005"`
2. **Dapr Protocol**: Ensure `dapr.io/app-protocol: "grpc"`
3. **Resources**: Apply standard worker resource limits
4. **Security Context**: Ensure non-root user

### ✅ Step 4 Completion Checklist
- [ ] Update worker config for all 10 services with workers
- [ ] Verify Dapr annotations are correct
- [ ] Verify resource allocations are appropriate
- [ ] Test worker deployments

---

## 🎯 Phase 5: Add Advanced Feature Templates

### Step 5.1: Add ServiceMonitor Template

**ServiceMonitor Configuration:**
```yaml
serviceMonitor:
  enabled: false  # Disabled by default, enable when Prometheus Operator available
  interval: 30s
  scrapeTimeout: 10s
  additionalLabels: {}
  relabelings: []
  metricRelabelings: []
```

**Template File**: `templates/servicemonitor.yaml`
```yaml
{{- if .Values.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "service.fullname" . }}
  labels:
    {{- include "service.labels" . | nindent 4 }}
    {{- with .Values.serviceMonitor.additionalLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "service.selectorLabels" . | nindent 6 }}
  endpoints:
  - port: http
    interval: {{ .Values.serviceMonitor.interval }}
    scrapeTimeout: {{ .Values.serviceMonitor.scrapeTimeout }}
    path: /metrics
    {{- with .Values.serviceMonitor.relabelings }}
    relabelings:
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with .Values.serviceMonitor.metricRelabelings }}
    metricRelabelings:
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
```

### Step 5.2: Add NetworkPolicy Template

**NetworkPolicy Configuration:**
```yaml
networkPolicy:
  enabled: false  # Disabled by default, enable when cluster supports NetworkPolicy
  ingress:
    enabled: true
    allowedNamespaces: []
    allowedPods: []
  egress:
    enabled: true
    allowHTTPS: false
    allowedServices: []
```

**Template File**: `templates/networkpolicy.yaml`
```yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "service.fullname" . }}
  labels:
    {{- include "service.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "service.selectorLabels" . | nindent 6 }}
  policyTypes:
  {{- if .Values.networkPolicy.ingress.enabled }}
  - Ingress
  {{- end }}
  {{- if .Values.networkPolicy.egress.enabled }}
  - Egress
  {{- end }}
  {{- if .Values.networkPolicy.ingress.enabled }}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: {{ .Release.Namespace }}
    {{- with .Values.networkPolicy.ingress.allowedNamespaces }}
    {{- range . }}
    - namespaceSelector:
        matchLabels:
          name: {{ . }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- if .Values.networkPolicy.egress.enabled }}
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
  {{- if .Values.networkPolicy.egress.allowHTTPS }}
  - to: []
    ports:
    - protocol: TCP
      port: 443
  {{- end }}
  {{- with .Values.networkPolicy.egress.allowedServices }}
  {{- range . }}
  - to:
    - namespaceSelector:
        matchLabels:
          name: {{ .namespace }}
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: {{ .service }}
    ports:
    - protocol: TCP
      port: {{ .port }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
```

### Step 5.3: Add Templates to All Services

**Services to Add Templates** (add ServiceMonitor and NetworkPolicy):
- [ ] auth-service
- [ ] user-service
- [ ] catalog-service
- [ ] order-service
- [ ] payment-service
- [ ] warehouse-service
- [ ] shipping-service
- [ ] customer-service
- [ ] pricing-service
- [ ] promotion-service
- [ ] fulfillment-service
- [ ] notification-service
- [ ] search-service
- [ ] review-service
- [ ] location-service
- [ ] common-operations-service

**Exception**: Gateway already has these templates.

### ✅ Step 5 Completion Checklist
- [ ] Add ServiceMonitor config to all services (disabled by default)
- [ ] Add NetworkPolicy config to all services (disabled by default)
- [ ] Create templates for services missing them
- [ ] Verify templates render correctly with `helm template`

---

## 🎯 Phase 6: Resource Optimization

### Step 6.1: Standardize Resource Allocations

**Service Categories and Resource Standards:**

#### **High-Traffic Services** (2 services):
```yaml
# gateway, frontend
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

#### **Standard Services** (14 services):
```yaml
# All other backend services
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 512Mi
```

#### **Worker Services**:
```yaml
# All workers
worker:
  resources:
    limits:
      cpu: 300m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

### Step 6.2: Update Autoscaling Configuration

**High-Traffic Services** (enable autoscaling):
```yaml
# gateway, frontend (production only)
autoscaling:
  enabled: true   # Production: true, Staging: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```

**Standard Services** (disable autoscaling):
```yaml
# All other services
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
```

### ✅ Step 6 Completion Checklist
- [ ] Verify resource allocations match service categories
- [ ] Enable autoscaling for high-traffic services (production)
- [ ] Disable autoscaling for standard services
- [ ] Update production values for autoscaling

---

## 📋 Implementation Process

### **Pre-Implementation Checklist**
- [ ] Backup current ArgoCD configurations
- [ ] Create feature branch for changes
- [ ] Set up testing environment
- [ ] Notify team of upcoming changes

### **Implementation Order**
1. **Phase 1**: Health check standardization (Day 1-2)
2. **Phase 2**: Probe configuration (Day 3-4)
3. **Phase 3**: PodDisruptionBudgets (Day 5-6)
4. **Phase 4**: Worker standardization (Day 7-8)
5. **Phase 5**: Advanced templates (Day 9-10)
6. **Phase 6**: Resource optimization (Day 11-12)

### **Testing Strategy**
- [ ] Test each service individually after changes
- [ ] Verify health checks work correctly
- [ ] Monitor ArgoCD sync status
- [ ] Check pod startup times
- [ ] Verify worker functionality (if applicable)

### **Rollback Plan**
- [ ] Keep backup of original configurations
- [ ] Use ArgoCD rollback feature if needed
- [ ] Monitor service health during rollout
- [ ] Have team available for quick fixes

---

## 📊 Success Metrics

### **Completion Criteria**
- [ ] All services use `/health` endpoint
- [ ] All services have consistent probe configurations
- [ ] All services have PodDisruptionBudgets
- [ ] All workers use standard configuration
- [ ] All services have advanced feature templates (disabled)
- [ ] Resource allocations match service categories

### **Quality Metrics**
- [ ] Zero failed deployments during migration
- [ ] No increase in service startup times
- [ ] All health checks passing
- [ ] ArgoCD sync successful for all services
- [ ] No production incidents during rollout

### **Documentation Updates**
- [ ] Update ArgoCD README with new standards
- [ ] Document standard configurations
- [ ] Update troubleshooting guides
- [ ] Create configuration templates for new services

---

## 🎯 Final Checklist

### **Phase 1: Health Check Standardization**
- [ ] auth-service: `/api/v1/auth/health` → `/health`
- [ ] shipping-service: `/v1/shipping/health` → `/health`
- [ ] location-service: `/v1/location/health` → `/health`
- [ ] gateway: Update routing configuration
- [ ] Test all health checks

### **Phase 2: Probe Standardization**
- [ ] Apply standard probe config to 16 services
- [ ] Verify consistent settings across all services
- [ ] Test probe functionality

### **Phase 3: PodDisruptionBudgets**
- [ ] Add PDB to 14 services missing it
- [ ] Configure staging (minAvailable: 1)
- [ ] Configure production (minAvailable: 2)
- [ ] Test PDB functionality

### **Phase 4: Worker Standardization**
- [ ] Update worker config for 10 services
- [ ] Standardize Dapr annotations
- [ ] Apply standard resource limits
- [ ] Test worker deployments

### **Phase 5: Advanced Templates**
- [ ] Add ServiceMonitor to 16 services (disabled)
- [ ] Add NetworkPolicy to 16 services (disabled)
- [ ] Verify templates render correctly

### **Phase 6: Resource Optimization**
- [ ] Verify resource allocations
- [ ] Configure autoscaling appropriately
- [ ] Update production configurations

---

## 🚀 Ready to Implement!

**All phases are documented with specific steps, code examples, and checklists. You can now proceed with implementation following this comprehensive guide.**

**Estimated Timeline**: 10-12 days  
**Risk Level**: Low (non-breaking changes with rollback plan)  
**Expected Impact**: Significantly improved consistency and maintainability

**Good luck with the implementation! 🎯**