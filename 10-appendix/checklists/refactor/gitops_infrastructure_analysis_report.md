# 📋 Architectural Analysis & Refactoring Report: GitOps Infrastructure & CI/CD Pipeline

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Continuous Deployment (ArgoCD), Cluster Configuration (Kustomize) & Secret Management  

---

## 🎯 Executive Summary
A world-class microservices platform requires a resilient, declarative deployment strategy. The architecture effectively utilizes ArgoCD via the App-of-Apps pattern to map repository states to Kubernetes clusters. Furthermore, Kustomize components (`common-deployment`) successfully enforce DRY deployment principles. However, a glaring discrepancy exists within the documentation regarding how cryptographic secrets are handled—a discrepancy that must be resolved to protect engineering credibility.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

### 1. [🟡 P1] Architectural Documentation Drift: Secrets Management Fabrication
* **Context**: The primary GitOps documentation (`gitops/README.md`) explicitly claims the architecture leverages *"External Secrets integration fetching from Hashicorp Vault"*.
* **Risk (Shopee standard)**: In reality, an audit of the `gitops/infrastructure/security/` directory reveals the deployment of **Bitnami Sealed Secrets** (RSA-2048 keys encrypting payloads directly into the Git repository). Lying in architectural documentation is a severe offense. It severely confuses onboarding DevOps engineers who will waste hours searching for a non-existent Vault cluster, and it misrepresents the actual audit logging capabilities of the platform (Sealed Secrets lack the dynamic rotation and audit trails of Vault).
* **Action Required**: 
  - **Decision Gate**: The CTO/Technical Lead must decide the path forward:
    - *Option A*: Rip out Bitnami Sealed Secrets and actually stand up the Hashicorp Vault External integration.
    - *Option B (Immediate)*: Rewrite the `README.md` to truthfully reflect the usage of Sealed Secrets. Integrity in documentation is non-negotiable.

## ✅ RESOLVED / FIXED

- **[FIXED ✅] Kustomize DRY Refactoring (Order Service)**: Previous audits highlighted that the `order` service maintained a localized, rogue `deployment.yaml` file, bypassing the centralized templates. This has been purged. The `order` service now correctly inherits from the powerful `components/common-deployment` base.
- **[FIXED ✅] Catastrophic ArgoCD Sync Errors Remedied**: The legacy `common-deployment` template contained un-evaluated syntax loopholes (e.g., `PLACEHOLDER_SERVICE_NAME` or HTTP port declarations). The Kubernetes API server rejected these strings, causing ArgoCD to report persistent `Degraded/SyncFailed` statuses. The DevOps team has successfully executed Kustomize JSON patches across all `apps/*/base` directories to interpolate these values correctly. The CI/CD pipeline is green.
- **[FIXED ✅] Pod CrashLoopBackOff Prevented (ConfigMaps)**: Developers failed to map ConfigMap volumes to the newly streamlined `order` deployment, resulting in immediate pod crashes upon launch. The `gitops/apps/order/base/kustomization.yaml` has been successfully patched with `volumeMounts`, achieving a stable deployment.

---

## 📋 Architectural Guidelines & Playbook

### 1. The App-of-Apps GitOps Topology (The Good)
The platform infrastructure adheres to the industry gold standard for declarative deployments:
- **Topology**: ArgoCD orchestrates clusters from `gitops/bootstrap/`, dynamically observing hierarchical branches: `apps/` (Service Bases), `environments/` (Production vs Dev overwrites), and `components/` (DRY templates).
- **Auto-Scaling**: Production overlays correctly enforce Horizontal Pod Autoscaler (HPA) policies (e.g., scaling up when CPU > 70% or RAM > 80%) augmented with `stabilizationWindowSeconds` to counter metric thrashing during ephemeral load spikes.

### 2. InitContainers as Synchronization Primitives
Microservices must natively handle infrastructure dependency boot sequences.
- **The Standard**: The architecture embeds smart `initContainers` (e.g., `wait-for-postgres` and `wait-for-redis`) directly onto the pods. This eliminates cascading CrashLoopBackOffs during total cluster rehydrations. The API pods will gracefully sleep until the underlying database accepts TCP connections.

### 3. Documentation Integrity
In a distributed matrix of 20+ services and infrastructure controllers, the `README` files are legally binding contracts between the platform teams and the application developers. Falsifying capabilities (e.g., claiming Vault integration when using Sealed Secrets) destroys team trust and is strictly prohibited under Senior Engineering guidelines.
