# GitOps Meeting Review 50000 Round

**Date**: 2026-03-19  
**Scope**: `gitops/` repo, current focus on `dev` operability  
**Review Style**: Static audit + targeted `kubectl kustomize` verification  
**Primary Tracker**: `docs/10-appendix/checklists/gitops/review_checklist.md`

## Purpose

This note is for a deep review meeting before manifest changes begin.

The goal is not to debate every YAML file. The goal is to force a few high-impact architecture and operability decisions so the next patch round does not create new drift.

## Current Verdict

`dev` is renderable, but not deterministic enough to be treated like a production-grade test environment.

The main failure mode is not "manifest does not build". The main failure mode is "system looks green, but runtime dependencies are missing, misordered, or blocked by policy".

## Live Validation Summary

- Confirmed runtime blockers:
  - `payment-dev` could not reach `customer-dev` on `80` or `81`
  - `shipping-dev` could not reach `customer-dev:80`, `order-dev:80/81`, `fulfillment-dev:80/81`, or `notification-dev:80/81`
- Live policy inspection explains part of the failure pattern:
  - `customer` ingress currently excludes `payment-dev` and `shipping-dev`
  - `order` ingress currently excludes `shipping-dev`
  - `fulfillment` ingress currently excludes `shipping-dev`
  - `notification` ingress currently only allows `gateway-dev`
- Confirmed healthy paths:
  - `checkout-dev` could reach `order-dev`, `payment-dev`, `pricing-dev`, and `shipping-dev` on `81`
  - `search-dev` could reach `catalog-dev`, `warehouse-dev`, and `pricing-dev` on `81`
  - `gateway-dev` could reach `auth-dev` on `81`
  - Traefik in `kube-system` could reach `admin-dev:80` and `frontend-dev:80`
- Confirmed cluster/runtime state that softens some static findings:
  - `pubsub-redis` Dapr Components currently exist across dev business namespaces
  - `customer` `daprd` logs show `pubsub-redis` loaded successfully

This means the meeting should separate:

- active runtime blockers
- bootstrap drift / clean rebuild risks
- documentation drift

## Top Risks Confirmed In This Round

### 1. Secret bootstrap order is still timing-dependent

- `externalsecrets-store` is ordered after child apps that already expect `vault-backend` and app secrets.
- First sync can fail and only recover on later syncs.

### 2. Namespace and NetworkPolicy drift are already blocking selected runtime paths

- Root resources and child apps do not agree on the namespace model.
- Several policies still rely on labels that namespaces do not have.
- Live validation already shows blocked traffic on selected downstream edges.

### 3. Dapr pubsub ownership is still unclear at the GitOps source-of-truth level

- Runtime currently has working `pubsub-redis` components in dev namespaces.
- The repo still does not make it obvious how a clean bootstrap recreates that working state.

### 4. Search initialization has cross-app race conditions, even though current paths are reachable

- `search-sync` is a `Sync` hook.
- It depends on services owned by other child Applications.
- It only waits for part of its upstream graph.
- Current runtime connectivity does not remove the first-sync ordering risk.

### 5. Plaintext secrets remain in Git

- This is still a design debt even for `dev`.
- It weakens rotation, auditability, and production-like testing.

## Decisions The Meeting Should Force

### A. Namespace model

Pick one and stop mixing:

- `service-dev`
- or `service`

Recommendation: use `service-dev` consistently for business namespaces, keep shared namespaces unchanged (`infrastructure`, `monitoring`, `argocd`, ingress controller namespace).

### B. NetworkPolicy selector contract

Pick one and enforce repo-wide:

- `kubernetes.io/metadata.name`
- or explicit namespace labels added by GitOps

Recommendation: use `kubernetes.io/metadata.name` because it is simpler and less fragile.

### C. Dapr component ownership model

Pick one and stop mixing:

- env-owned shared Dapr components
- or app-owned per-namespace components

Recommendation: prefer one explicit model for all eventing services in `dev`. Do not rely on commented-out resources or tribal knowledge.

### D. Bootstrap ownership

Decide whether these are actively GitOps-managed or pre-baked cluster prerequisites:

- Dapr control plane
- External Secrets operator
- secret store bootstrap
- monitoring operators

Recommendation: either manage them in the active dev tree or document them as mandatory bootstrap with one reproducible procedure.

### E. Cross-app sync ordering

Decide whether dependency-heavy apps stay in the default wave or get explicit app-of-apps ordering.

Recommendation: apps with initialization jobs that call other services should not be left in implicit concurrent sync.

## Suggested Meeting Agenda

1. Confirm the `dev` namespace contract.
2. Confirm the NetworkPolicy selector standard.
3. Confirm the fix order for live broken traffic:
   - `payment -> customer`
   - `shipping -> customer/order/fulfillment/notification`
4. Confirm who owns Dapr components and where they are rendered.
5. Confirm whether operators/bootstrap are in-scope for active GitOps.
6. Confirm app-of-apps sync ordering for:
   - secret backend bootstrap
   - search vs catalog/warehouse/pricing
   - gateway and UI after backends
7. Confirm whether plaintext secrets in `dev` are accepted as temporary debt or must be removed now.

## Evidence Pack To Open During Meeting

- `gitops/environments/dev/apps/kustomization.yaml`
- `gitops/environments/dev/resources/kustomization.yaml`
- `gitops/environments/dev/resources/namespaces-with-env.yaml`
- `gitops/environments/dev/apps/externalsecrets-store-app.yaml`
- `gitops/apps/auth/overlays/dev/secret.yaml`
- `gitops/apps/payment/base/networkpolicy.yaml`
- `gitops/apps/shipping/base/networkpolicy.yaml`
- `gitops/apps/customer/base/kustomization.yaml`
- `gitops/apps/payment/base/kustomization.yaml`
- `gitops/apps/review/base/kustomization.yaml`
- `gitops/apps/loyalty-rewards/base/kustomization.yaml`
- `gitops/apps/order/base/kustomization.yaml`
- `gitops/apps/location/base/kustomization.yaml`
- `gitops/apps/search/base/sync-job.yaml`
- `gitops/apps/search/overlays/dev/configmap.yaml`

## Recommended Fix Order After The Meeting

1. Lock namespace and selector conventions.
2. Fix the live broken downstream paths in `payment` and `shipping`.
3. Fix secret bootstrap and app-of-apps ordering.
4. Normalize Dapr component ownership for eventing namespaces.
5. Repair remaining NetworkPolicy ports and ingress paths.
6. Gate cross-app initialization jobs, starting with `search-sync`.
7. Remove or replace plaintext secrets.

## Exit Condition For This Review Round

The round is complete when the team can answer these five questions without ambiguity:

- Which namespaces are canonical in `dev`?
- Which label key do NetworkPolicies target?
- Why can `payment` not reach `customer`, and why can `shipping` not reach `order/fulfillment/notification` right now?
- Where does `pubsub-redis` come from for every event-driven namespace?
- Which dependencies are GitOps-managed vs pre-baked?
- Which child Applications must be ordered explicitly?
