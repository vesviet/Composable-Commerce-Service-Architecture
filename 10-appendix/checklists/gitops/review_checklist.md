# GitOps Review Checklist

**Last Reviewed**: 2026-03-19  
**Reviewer Lens**: Senior DevOps / ArgoCD / Kustomize / Kubernetes operability  
**Current Deployment Scope**: `dev` only  
**Review Mode**: Static repo audit + `kubectl kustomize` root/app overlay render verification

## Review Scope

This checklist has been refreshed for the current state of the `gitops/` repo.

The previous version of this file was stale:
- It marked major areas as "resolved" without matching the current manifests.
- It mixed historical fixes with current deployable risk.
- It did not distinguish `dev` issues from `production-only` issues.

This version is intended to support current `dev` environment testing with production-grade expectations.

## Verification Performed

- Reviewed `gitops/bootstrap/`, `gitops/environments/dev/`, `gitops/environments/production/`, `gitops/infrastructure/`, and representative service overlays.
- Rendered `dev` with `kubectl kustomize gitops/environments/dev`.
- Rendered `production` with `kubectl kustomize gitops/environments/production`.
- Rendered representative service overlays in `dev`, including `customer`, `payment`, `review`, `order`, `location`, and `loyalty-rewards`.
- Cross-checked current docs against actual manifests.

## Live Cluster Validation Snapshot (2026-03-19)

- Remote cluster context: `k3d-microservices`
- Current high-level health:
  - All `*-dev` ArgoCD Applications were `Synced` / `Healthy` at review time.
  - All observed `*-dev` pods were `Running` or `Completed`.
- Confirmed open paths from inside running pods:
  - `checkout-dev` -> `order-dev:81`, `payment-dev:81`, `pricing-dev:81`, `shipping-dev:81`
  - `search-dev` -> `catalog-dev:81`, `warehouse-dev:81`, `pricing-dev:81`
  - `gateway-dev` -> `auth-dev:81`
  - `kube-system/traefik` -> `admin-dev:80`, `frontend-dev:80`
- Confirmed broken paths from inside running pods:
  - `payment-dev` -> `customer-dev:80` and `customer-dev:81`
  - `shipping-dev` -> `customer-dev:80`, `order-dev:80`, `fulfillment-dev:80`, `notification-dev:80`
  - `shipping-dev` -> `order-dev:81`, `fulfillment-dev:81`, `notification-dev:81`
- Service backends exist for the failing destinations:
  - `customer`, `notification`, `fulfillment`, and `order` Services all had live Endpoints at review time.
- Dapr runtime note:
  - `kubectl get components.dapr.io -A` showed `pubsub-redis` present across dev business namespaces.
  - `customer` `daprd` logs confirmed `Component loaded: pubsub-redis`.

## Current Status Summary

| Area | Status | Notes |
|------|--------|-------|
| Dev renderability | `PASS` | `kubectl kustomize gitops/environments/dev` renders successfully |
| Dev operability | `RISK` | Live validation confirms broken downstream traffic on `payment -> customer` and `shipping -> order/fulfillment/notification`, while bootstrap/drift issues remain |
| Secret hygiene | `FAIL` | Plaintext secrets are still committed in Git |
| Project guardrails | `WEAK` | ArgoCD AppProject permissions are too broad |
| Documentation accuracy | `DRIFT` | `gitops/README.md` does not match the repo's actual implementation |
| Production renderability | `FAIL` | Production tree does not currently build |

## Priority 1: Active Dev Issues

### 1. Secret Bootstrap Order Is Backwards

- Severity: `P1`
- Status: `Open`
- Impact: App-of-Apps sync can race business apps ahead of secret backend/bootstrap resources, creating intermittent `SecretStore` or secret materialization failures during test deploys.
- Evidence:
  - `externalsecrets-store` app is sync wave `1`: `gitops/environments/dev/apps/externalsecrets-store-app.yaml`
  - Business apps such as `auth` default to wave `0`: `gitops/environments/dev/apps/auth-app.yaml`
  - App-level `ExternalSecret` objects expect `vault-backend` up front: `gitops/apps/auth/overlays/dev/secret.yaml`
- Recommended Action:
  - Move secret backend/bootstrap app earlier than all service apps.
  - Standardize sync waves across app-of-apps: namespace/bootstrap `<` secrets `<` migrations `<` deployments.

### 2. Namespace Convention Drift (`auth` vs `auth-dev`)

- Severity: `P1`
- Status: `Open`
- Impact: Debugging, policy targeting, metrics discovery, and RBAC become harder because root resources and child apps do not agree on namespace naming.
- Evidence:
  - Root resources create namespaces like `auth`, `catalog`, `frontend`: `gitops/environments/dev/resources/namespaces-with-env.yaml`
  - Child apps deploy into suffixed namespaces like `auth-dev`, `frontend-dev`: `gitops/environments/dev/apps/auth-app.yaml`, `gitops/environments/dev/apps/frontend-app.yaml`
- Recommended Action:
  - Choose one convention for `dev` and enforce it everywhere.
  - Prefer environment-suffixed namespaces if the long-term plan includes multiple clusters or side-by-side environments.

### 3. Plaintext Secrets Still Live In Git

- Severity: `P1`
- Status: `Open`
- Impact: This breaks basic GitOps secret hygiene, weakens audit posture, and makes `dev` drift from a production-like secret flow.
- Evidence:
  - Bootstrap secrets under `gitops/infrastructure/externalsecrets-store/*.yaml` are committed as native `Secret` objects with `stringData`
  - Example: `gitops/infrastructure/externalsecrets-store/auth-backend-secret.yaml`
  - Grafana admin password is committed in `gitops/environments/dev/resources/monitoring/grafana-secret.yaml`
- Recommended Action:
  - Remove committed plaintext secrets from Git.
  - For `dev`, use either Sealed Secrets or a real External Secrets bootstrap path with out-of-band source population.
  - Document bootstrap exceptions explicitly if any are intentionally temporary.

### 4. ArgoCD AppProject Permissions Are Too Broad

- Severity: `P2`
- Status: `Open`
- Impact: A bad manifest or mistaken sync can affect cluster-scoped resources beyond intended app boundaries.
- Evidence:
  - `gitops/environments/dev/projects/dev-project.yaml` uses `clusterResourceWhitelist: * / *`
  - `gitops/environments/production/projects/production-project.yaml` does the same
- Recommended Action:
  - Restrict cluster-scoped resources to the exact set required.
  - Split infra-level privileges from service-level privileges if needed.

### 5. NetworkPolicy Namespace Selectors Depend On Labels That Do Not Exist

- Severity: `P1`
- Status: `Open`
- Impact: Service-to-service and gateway-to-service traffic can be silently blocked if the cluster actually enforces the declared policies.
- Evidence:
  - Root namespaces only carry `name` and `app.kubernetes.io/managed-by`: `gitops/environments/dev/resources/namespaces-with-env.yaml`
  - Many service policies select namespaces by `app.kubernetes.io/name`, for example:
    - `gitops/apps/auth/base/networkpolicy.yaml`
    - `gitops/apps/customer/base/networkpolicy.yaml`
    - `gitops/apps/common-operations/base/networkpolicy.yaml`
    - `gitops/apps/frontend/base/networkpolicy.yaml`
- Recommended Action:
  - Standardize on `kubernetes.io/metadata.name` for namespace selectors.
  - Add a repo-wide audit so all service policies use the same namespace-label convention.

### 6. Several Dev NetworkPolicies Open The Wrong Ports

- Severity: `P1`
- Status: `Open`
- Impact: Requests are already failing in the live dev cluster even though pods are healthy and Services have endpoints, which strongly suggests source-specific traffic is being blocked or mis-targeted.
- Evidence:
  - `payment` egress to `order` / `notification` / `customer` uses `8005/9005` instead of downstream service ports: `gitops/apps/payment/base/networkpolicy.yaml`
  - `shipping` egress to `catalog` / `order` / `fulfillment` / `notification` uses `8012/9012` instead of downstream ports: `gitops/apps/shipping/base/networkpolicy.yaml`
  - `analytics` dev ingress patch opens `8018/9018` even though analytics listens on `8019/9019`: `gitops/apps/analytics/overlays/dev/patch-networkpolicy.yaml`, `gitops/apps/analytics/overlays/dev/configmap.yaml`
  - `common-operations` dev ingress patch opens `8020/9020` even though service config is `8018/9018`: `gitops/apps/common-operations/overlays/dev/patch-networkpolicy.yaml`, `gitops/apps/common-operations/base/configmap.yaml`
  - Live validation showed `payment-dev -> customer-dev:80/81` closed, while `payment-dev -> order-dev:81` was open
  - Live validation showed `shipping-dev -> customer-dev:80`, `order-dev:80/81`, `fulfillment-dev:80/81`, and `notification-dev:80/81` closed, while `shipping-dev -> catalog-dev:80/81` was open
  - `payment` config actively expects `CUSTOMER_SERVICE_ADDR=customer.customer-dev.svc.cluster.local:81`: `gitops/apps/payment/overlays/dev/configmap.yaml`
  - `shipping` config actively expects HTTP endpoints for `customer`, `order`, `fulfillment`, `notification`, and `warehouse`: `gitops/apps/shipping/overlays/dev/configmap.yaml`
  - Live policy inspection showed:
    - `customer` ingress currently allows `auth-dev`, `order-dev`, `checkout-dev`, `loyalty-rewards-dev`, and `notification-dev`, but not `payment-dev` or `shipping-dev`
    - `order` ingress currently does not allow `shipping-dev`
    - `fulfillment` ingress currently does not allow `shipping-dev`
    - `notification` ingress currently only allows `gateway-dev`
- Recommended Action:
  - Validate every NetworkPolicy port against the target Service port, not the caller's port.
  - Add CI or policy tests that compare network policy ports with rendered Service definitions.
  - Fix both sides of the policy contract where needed:
    - source egress rules
    - destination ingress allow-lists
  - Treat `payment -> customer` and `shipping -> order/fulfillment/notification` as active runtime blockers, not theoretical drift.

### 7. Frontend/Admin Dev NetworkPolicy Patches Conflict With Actual Ingress Path

- Severity: `P2`
- Status: `Watch`
- Impact: The manifests still encode a confusing source/path contract, but this did not reproduce as a runtime outage in the current cluster.
- Evidence:
  - Dev `IngressRoute` sends external traffic directly to `admin` and `frontend`: `gitops/environments/dev/resources/ingress/ingressroute.yaml`
  - `frontend` dev patch only allows ingress from `gateway-dev` on port `3000`: `gitops/apps/frontend/overlays/dev/patch-networkpolicy.yaml`
  - `admin` dev patch only allows ingress from `gateway-dev` on port `3001`: `gitops/apps/admin/overlays/dev/patch-networkpolicy.yaml`
  - Base `admin` deployment listens on port `80`, not `3001`: `gitops/apps/admin/base/deployment.yaml`
  - Live validation from the running `traefik` pod to `admin-dev:80` and `frontend-dev:80` succeeded
- Recommended Action:
  - Decide whether UI traffic should come from Traefik directly or be proxied through gateway.
  - Align IngressRoute, Service, Deployment port, and NetworkPolicy source namespace accordingly.

### 8. Dev Bootstrap Still Assumes Out-Of-Band Cluster Dependencies

- Severity: `P2`
- Status: `Open`
- Impact: A fresh cluster or rebuilt dev environment can fail hard because key control-plane dependencies are assumed rather than fully bootstrapped by the active GitOps tree.
- Evidence:
  - Active dev app-of-apps list does not include a Dapr bootstrap app: `gitops/environments/dev/apps/kustomization.yaml`
  - The only Dapr install manifest found is `gitops/infrastructure/dapr/dapr-helmrelease.yaml`, which is not referenced by the active dev tree
  - Active dev tree contains `ExternalSecret` resources, for example `gitops/environments/dev/resources/environment-configmaps.yaml`, but no External Secrets operator installation manifest was found in the active dev paths
- Recommended Action:
  - Explicitly encode all mandatory cluster dependencies in the active dev app-of-apps tree, or document them as pre-baked cluster requirements with a reproducible bootstrap script.

### 9. Docs Claim One Architecture, Repo Implements Another

- Severity: `P2`
- Status: `Open`
- Impact: Onboarding and incident response slow down because the declared GitOps model does not match the repo that ArgoCD actually syncs.
- Evidence:
  - `gitops/README.md` claims Sealed Secrets and ApplicationSet-driven behavior
  - Current repo mixes:
    - raw environment manifests in `environments/dev/resources/`
    - app-of-apps in `environments/*/apps/`
    - newer infra modules in `infrastructure/`
    - ExternalSecret objects backed by a Kubernetes provider store named `vault-backend`
- Recommended Action:
  - Rewrite `gitops/README.md` to describe the actual current topology.
  - Explicitly mark legacy vs active paths.
  - Rename misleading secret-store references if Vault is not really the backing source.

### 10. Kustomize Config Uses Deprecated `commonLabels`

- Severity: `P3`
- Status: `Open`
- Impact: Not a current runtime blocker, but it creates noisy renders and avoidable maintenance drag.
- Evidence:
  - `kubectl kustomize` emits deprecation warnings for `commonLabels`
  - Current usage appears in:
    - `gitops/environments/dev/apps/kustomization.yaml`
    - `gitops/environments/dev/projects/kustomization.yaml`
    - `gitops/environments/dev/resources/kustomization.yaml`
    - `gitops/environments/production/apps/kustomization.yaml`
    - `gitops/environments/production/projects/kustomization.yaml`
    - `gitops/environments/production/resources/kustomization.yaml`
    - `gitops/infrastructure/security/kustomization.yaml`
- Recommended Action:
  - Replace `commonLabels` with `labels` consistently.

### 11. Dapr PubSub Ownership Is Drifted From Current Working Cluster State

- Severity: `P2`
- Status: `Watch`
- Impact: Current runtime eventing appears to work, but the repo does not clearly explain how a fresh cluster reproduces the `pubsub-redis` components now present across dev namespaces.
- Evidence:
  - Shared dev service-discovery resources are not active in the current root resource tree: `gitops/environments/dev/resources/kustomization.yaml`
  - Only `order` and `location` bases include a local `dapr-pubsub.yaml`: `gitops/apps/order/base/kustomization.yaml`, `gitops/apps/location/base/kustomization.yaml`
  - `customer`, `payment`, `review`, and `loyalty-rewards` bases include `dapr-subscription.yaml`: `gitops/apps/customer/base/kustomization.yaml`, `gitops/apps/payment/base/kustomization.yaml`, `gitops/apps/review/base/kustomization.yaml`, `gitops/apps/loyalty-rewards/base/kustomization.yaml`
  - Live cluster validation showed `pubsub-redis` Components present across dev business namespaces
  - `customer` `daprd` logs confirmed `Component loaded: pubsub-redis`
- Recommended Action:
  - Reconcile repo-to-cluster source of truth for Dapr components before the next clean rebuild.
  - Choose one ownership model for Dapr pubsub in `dev` and document how it is bootstrapped.
  - Keep this as a bootstrap/drift risk unless live event failures are reproduced.

### 12. Search Sync Hook Can Race Cross-App Dependencies

- Severity: `P2`
- Status: `Open`
- Impact: Search traffic is currently healthy, but first-sync indexing can still fail or flap because the hook depends on other child Applications without explicit app-level ordering.
- Evidence:
  - `search` child Application has no app-level sync-wave or dependency guard: `gitops/environments/dev/apps/search-app.yaml`
  - Root dev app-of-apps syncs many business apps together: `gitops/environments/dev/apps/kustomization.yaml`
  - `search-sync` is a `Sync` hook at wave `1`: `gitops/apps/search/base/sync-job.yaml`
  - The job waits for PostgreSQL, Elasticsearch, and `catalog`, but not `warehouse` or `pricing`: `gitops/apps/search/base/sync-job.yaml`
  - The same job consumes `CATALOG_SERVICE_GRPC_ADDR`, `WAREHOUSE_SERVICE_GRPC_ADDR`, and `PRICING_SERVICE_GRPC_ADDR`: `gitops/apps/search/overlays/dev/configmap.yaml`
  - Live validation from `search-dev` to `catalog-dev:81`, `warehouse-dev:81`, and `pricing-dev:81` succeeded
- Recommended Action:
  - Add explicit cross-app ordering for `search` relative to `catalog`, `warehouse`, and `pricing`, or move initial indexing out of the first-sync critical path.
  - If the sync job stays, make it wait for all required upstreams and give it a clear hook cleanup policy.
  - Treat search indexing as a workflow with dependencies, not just a local app resource wave.

## Reviewed Fix Direction For Dev

This section reviews the proposed fix direction only. No manifest changes have been applied in this document update.

### A. Normalize NetworkPolicy To `*-dev` Namespaces And Real Service Ports

- Review Verdict: `Directionally correct, but must be applied with guardrails`
- Why this is the right direction:
  - Current policies mix invalid namespace selectors, stale assumptions, and wrong downstream ports.
  - Converging service-to-service rules on explicit dev namespaces is the cleanest way to make runtime behavior deterministic.
- Guardrails:
  - Only use `*-dev` for business service namespaces.
  - Do **not** bulk-convert system namespaces such as:
    - `infrastructure`
    - `monitoring`
    - `dapr-system`
    - `minio-system`
    - `argocd`
    - the actual ingress controller namespace
  - Standardize namespace selectors on `kubernetes.io/metadata.name`, not `app.kubernetes.io/name`, unless namespace labels are explicitly added repo-wide.
  - For `frontend` and `admin`, do not assume the source is `gateway-dev`.
    - Current dev ingress routes send traffic through Traefik/IngressRoute, so the allowed source namespace must match the real controller path.
  - For ports, validate against the real calling convention before bulk replacement.
    - Some services are reached through service ports (`80` / `81`).
    - Some manifests document target ports (`800x` / `900x`).
    - NetworkPolicy behavior around Service DNAT can be CNI-sensitive, so this must be verified against the actual cluster path, not guessed from naming alone.
  - Preserve shared infra egress rules for DNS, PostgreSQL, Redis, Dapr control plane, tracing, and external APIs.
- Recommended rollout:
  - Fix namespace selector convention first.
  - Fix gateway/UI ingress paths second.
  - Fix egress ports service-by-service, grouped by workflow:
    - gateway/auth/customer
    - catalog/pricing/search
    - checkout/order/payment
    - warehouse/fulfillment/shipping/return
    - frontend/admin
- Validation checklist:
  - `gateway-dev` can reach all backend APIs it fronts.
  - `checkout-dev` can call `order-dev`, `payment-dev`, `pricing-dev`, `shipping-dev`.
  - `order-dev` can call `payment-dev`, `warehouse-dev`, `fulfillment-dev`, `shipping-dev`, `customer-dev`.
  - `shipping-dev` and `payment-dev` still retain outbound `443` access for external providers.
  - `frontend-dev` and `admin-dev` are reachable from the actual ingress controller path.

### B. Make Dev Bootstrap And Sync Order Deterministic

- Review Verdict: `Strongly recommended`
- Why this is the right direction:
  - Current dev deployment depends on timing and pre-existing cluster state.
  - A deterministic sync model will reduce flaky first-sync failures and make cluster rebuilds repeatable.
- Preferred ordering model:
  - Wave `-20`: namespaces and cluster prerequisites
  - Wave `-15`: operators / CRDs if GitOps-managed
    - Dapr control plane
    - External Secrets operator
    - CloudNativePG operator
    - Prometheus operator
  - Wave `-10`: secret backend bootstrap
    - source secrets
    - `ClusterSecretStore`
    - cluster-wide secret distribution objects
  - Wave `-5`: app prerequisites
    - `ExternalSecret`
    - shared `ConfigMap`
    - `ServiceAccount`
    - Dapr `Component` / `Configuration`
  - Wave `0`: migration jobs / schema prep
  - Wave `5`: core backend services
  - Wave `10`: gateway
  - Wave `15`: frontend / admin / ingress-facing resources
- Guardrails:
  - Do not keep half of the prerequisites implicit and half GitOps-managed.
    - Either manage operators/bootstrap in the active dev tree, or document them as mandatory pre-baked cluster dependencies.
  - Do not let `PreSync` hooks depend on resources created in later app waves.
  - Keep root app ordering and child resource ordering conceptually aligned.
  - Treat cluster-scoped operators separately from app-level resources to reduce blast radius.
- Validation checklist:
  - Fresh dev cluster sync completes without needing a second manual sync.
  - `ExternalSecret` resources reconcile before pods reference their secrets.
  - Dapr `Component` / `Subscription` resources are accepted only after Dapr CRDs exist.
  - Migration jobs complete before dependent deployments become Ready.
  - Gateway and UI only roll after backends and shared config are in place.

### C. Normalize Dapr Component Ownership For Eventing

- Review Verdict: `Mandatory before trusting event-driven tests`
- Why this is the right direction:
  - Current manifests mix local per-app pubsub components with subscriber-only apps that assume `pubsub-redis` exists somewhere else.
  - This can leave some namespaces able to publish/subscribe and others broken in ways that look like business logic bugs.
- Guardrails:
  - Decide whether Dapr components are:
    - environment-owned and injected centrally
    - or app-owned and rendered per namespace
  - Keep the same model for all event-producing and event-consuming services in `dev`.
  - Do not rely on commented-out service-discovery resources as an implicit contract.
  - Avoid embedding Redis credentials directly in Dapr component specs where a secret reference should exist.
- Validation checklist:
  - Every namespace that renders a `Subscription` also has access to the referenced `pubsub-redis` component.
  - A known event path, such as `order -> payment` or `auth -> customer`, succeeds in a fresh dev sync.
  - Dapr sidecars report the component as loaded without manual cluster patching.

### D. Gate Cross-App Hooks And Initialization Jobs

- Review Verdict: `Strongly recommended`
- Why this is the right direction:
  - Hook jobs are currently treated as local app concerns, but some of them depend on services managed by other child Applications.
  - Without app-level ordering, a clean first sync still depends on timing luck.
- Guardrails:
  - Any hook or init job that calls another service must declare that dependency at the app-of-apps layer or wait for all required upstreams itself.
  - Do not assume that resource wave ordering inside one child Application will serialize other child Applications.
  - Add hook cleanup policies so repeated syncs do not leave stale or confusing job history.
- Validation checklist:
  - `search-sync` only runs after `catalog`, `warehouse`, and `pricing` are reachable.
  - A full dev resync does not fail because a hook re-ran against half-updated dependencies.
  - ArgoCD history stays readable after repeated syncs.

## Priority 2: Production-Only Risks

These do not block current `dev` testing, but they should not be forgotten.

### 13. Production Tree Does Not Render

- Severity: `P1`
- Status: `Open`
- Impact: `root-app-production` cannot be trusted to bootstrap a production cluster in its current state.
- Evidence:
  - `kubectl kustomize gitops/environments/production` fails
  - `gitops/environments/production/resources/kustomization.yaml` includes `infrastructure.yaml` as a resource even though it is itself a `Kustomization`
  - That file references missing paths under `gitops/infrastructure/databases/`, `gitops/infrastructure/monitoring/`, and `gitops/infrastructure/ingress/`
- Recommended Action:
  - Rebuild the production resource tree around real directories, not nested kustomization files masquerading as manifests.
  - Add CI render validation for both `dev` and `production`.

### 14. Production Secret Backend Bootstrap Looks Incomplete

- Severity: `P1`
- Status: `Open`
- Impact: Even after production render is fixed, apps may still fail at runtime if `ClusterSecretStore` and source secrets are not provisioned before app sync.
- Evidence:
  - Production apps use `ExternalSecret`, for example:
    - `gitops/apps/pricing/overlays/production/secret.yaml`
    - `gitops/apps/warehouse/overlays/production/secrets.yaml`
  - Production app-of-apps does not currently deploy an `externalsecrets-store` bootstrap app: `gitops/environments/production/apps/kustomization.yaml`
- Recommended Action:
  - Decide whether production secret bootstrap is GitOps-managed or external.
  - If GitOps-managed, add explicit bootstrap ordering and health dependencies.

### 15. Duplicate YAML Key In `pricing` Production Secret

- Severity: `P2`
- Status: `Open`
- Impact: Duplicate `metadata.annotations` likely drops the intended `PreSync` hook and makes deploy behavior inconsistent with reviewer expectations.
- Evidence:
  - `gitops/apps/pricing/overlays/production/secret.yaml`
- Recommended Action:
  - Collapse duplicate annotations into a single block.

## Previously Verified / Historical Items

The old version of this checklist listed many items as complete, but without a date, scope, or current re-verification trail.

Those items are no longer treated as the primary source of truth in this file.

If needed, historical findings should be moved into:
- dated audit notes
- service-specific review documents
- go-live review documents

## Recommended Next Actions

- [ ] Lock the target dev namespace model before changing any NetworkPolicy.
- [ ] Fix dev sync ordering for secret bootstrap before continuing broad test cycles.
- [ ] Fix live broken service paths first: `payment -> customer` and `shipping -> order/fulfillment/notification`.
- [ ] Normalize NetworkPolicy namespace selectors to `kubernetes.io/metadata.name`.
- [ ] Review every NetworkPolicy port against the real runtime call path, not naming conventions alone.
- [ ] Choose one Dapr pubsub/component ownership model for `dev` and apply it consistently.
- [ ] Gate cross-app hooks and indexing jobs behind explicit dependency rules.
- [ ] Unify namespace naming across root resources and child apps.
- [ ] Remove plaintext secrets from Git and document the real bootstrap model.
- [ ] Add CI checks:
  - [ ] `kubectl kustomize gitops/environments/dev`
  - [ ] `kubectl kustomize gitops/environments/production`
- [ ] Rewrite `gitops/README.md` to match the repo that exists today.

## Exit Criteria For "Dev Is Safe Enough To Test Like Prod"

- [ ] Dev renders cleanly without deprecation noise or missing-resource errors.
- [ ] Secret backend and app sync order are deterministic.
- [ ] `payment` and `shipping` can reach every downstream endpoint defined in their current dev config.
- [ ] Event-driven namespaces receive the Dapr components they reference.
- [ ] Namespace layout is consistent and documented.
- [ ] No active plaintext application secrets remain in Git.
- [ ] ArgoCD project permissions are narrowed to intended resource classes.
- [ ] Documentation matches actual deployment topology.
