# 📋 Architectural Analysis & Refactoring Report: GitOps Worker Deployment Configurations

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Kubernetes Worker Manifests, Async Deployment Drift & Initialization Pipelines  

---

## 🎯 Executive Summary
While API deployments handle synchronous ingress, Worker deployments form the asynchronous backbone (Cronjobs, Outbox Processors, Event Consumers). Because workers operate statelessly and on independent scaling metrics, their Kubernetes configurations must be impeccable to prevent silent data-processing halts. Similar to the API deployments, this report uncovers a severe architectural violation: the widespread, unauthorized copy-pasting of boilerplate `worker-deployment.yaml` files, leading to configuration drift and initialization irregularities.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

*No P0/P1/P2 issues remain. Worker deployment manifests have been standardized.*

## ✅ RESOLVED / FIXED

- **[FIXED ✅] Critical Telemetry Omission (Analytics Worker)**: A past audit revealed that the `analytics` worker pod was deployed entirely missing the mandatory `dapr.io/app-port` and `app-protocol` annotations. This completely severed its telemetry and pub/sub routing. The `analytics` worker YAML has been properly patched; Dapr communication is fully restored.
- **[FIXED ✅] Health Check CrashLoop (Loyalty-Rewards)**: The `loyalty-rewards` worker was experiencing false-positive Kubernetes kills due to a misaligned liveness probe. The configuration has been successfully corrected to poll the `/healthz` endpoint, neutralizing the CrashLoopBackOff.
- **[RESOLVED ✅] DRY Violation — Worker Deployment Manifests (2026-03-02)**: Codebase audit confirms `analytics`, `customer`, `search` workers now use standardized component inheritance. Original P0 reclassified as resolved.
- **[RESOLVED ✅] InitContainer Inconsistencies (2026-03-02)**: InitContainer configurations have been standardized across worker deployments. Original P2 reclassified as resolved.

---

## 📋 Architectural Guidelines & Playbook

### 1. Security & Orchestration Baselines (The Good)
The isolated worker deployment topology accurately adheres to GitOps best practices in a few key areas:
- **ArgoCD Sync Waves:** All workers correctly declare `argocd.argoproj.io/sync-wave: "8"`. This ensures databases and core infrastructure (Wave 1-5) are fully provisioned before consumers boot up.
- **Security Context:** Manifests correctly mandate `runAsNonRoot: true`, significantly shrinking the attack surface area of the container runtime.

### 2. The Kustomize Component Mandate (DRY Execution)
The era of copy-pasting worker manifests is over.

**The Base Component (`gitops/components/common-worker-deployment/deployment.yaml`):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: PLACEHOLDER_WORKER_NAME
spec:
  template:
    metadata:
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-port: "8081"
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
        - name: worker
          ports:
            - containerPort: 8081
              name: metrics
          livenessProbe:
            httpGet:
              path: /healthz
              port: metrics
```

**The Service Inheritance (`gitops/apps/search/base/kustomization.yaml`):**
```yaml
resources:
  - ../../../components/common-worker-deployment

patches:
  - path: patch-worker-deployment.yaml # Used exlusively to inject the `-mode=worker` arg and set resources.
```
