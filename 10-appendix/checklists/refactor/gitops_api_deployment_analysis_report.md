# 📋 Architectural Analysis & Refactoring Report: GitOps API Deployment Configuration

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Kubernetes Deployment Manifests, Health Probes (Liveness/Readiness), Resource Allocation & DRY Kustomize Components  

---

## 🎯 Executive Summary
Maintaining 20+ microservices necessitates a strictly DRY (Don't Repeat Yourself) approach to Kubernetes YAML generation. Manual replication of generic Deployment structures guarantees configuration drift, mismatched health probes, and OOM kills due to outdated memory limits. 
Despite the existence of a high-quality Kustomize scaffolding component (`components/common-deployment`), this report exposes severe discipline issues across multiple teams blindly copy-pasting raw Deployment manifests instead of inheriting from the established architectural baseline.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

### 1. [🟡 P1] Probe Misconfiguration: Instant Out-Of-Memory (OOM) / CrashLoop Risks
* **Context**: The `loyalty-rewards` and `search` deployments uniquely configure their `startupProbe` with an `initialDelaySeconds: 0`.
* **Risk (Shopify standard)**: Firing health checks at exact zero-time before the Go runtime and Kratos framework have successfully booted their HTTP listeners guarantees an immediate failed probe. Under load, Kubernetes will violently restart the pod, triggering an infinite CrashLoopBackOff cycle during a scaled rollout.
* **Action Required**: 
  - Standardize `startupProbe.initialDelaySeconds: 10` uniformly across all Go service deployments to grant the application sufficient buffer to acquire database connections and bootstrap gRPC pools.

## ✅ RESOLVED / FIXED

- **[FIXED ✅] Critical Pod Crashes Prevented (Missing ConfigMaps)**: Earlier audits caught fatal omissions where services (like `order` and `loyalty-rewards`) were deployed without their mandatory ConfigMap volume mounts (`volumeMounts` mapped to `/app/configs`). These configurations have been successfully patched into the deployment bases, preventing instantaneous panics upon pod launch.
- **[RESOLVED ✅] DRY Violation — Deployment Manifest Duplication (2026-03-02)**: Codebase audit confirms `search`, `customer`, and `pricing` services now all use `common-deployment` component inheritance. Only `common-operations` (a utility service) retains standalone manifests. Original P0 reclassified as resolved.

---

## 📋 Architectural Guidelines & Playbook

### 1. The Component Inheritance Mandate
Bespoke deployment configurations are hostile to scalable PaaS (Platform as a Service) environments. 

**The Mandated Shopee/Lazada Approach:**
Eradicate local deployments. Services must hook into the unified base.
```yaml
# gitops/apps/customer/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../components/common-deployment # Inherit 95% of the logic

patches:
  - path: patch-deployment.yaml # Only supply the 5% difference
```

**Permitted Patches (`patch-deployment.yaml`):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: PLACEHOLDER_SERVICE_NAME # Kustomize resolves this
spec:
  template:
    spec:
      containers:
        - name: app
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
```
*Note from the Senior TA: Any Pull Request containing a `kind: Deployment` declaration outside of the `components` or `patches` directory will be rejected immediately.*
