# AGENT-10 Task 33 Decision: Kustomization DRY Strategy

Date: 2026-03-21
Owner: DevOps
Scope: `gitops/apps/*/overlays/dev/kustomization.yaml`

## Context

- Current repo has 24 app overlays for `dev` and 24 `base` kustomizations.
- Overlay files are highly repetitive in structure (service-specific name/path changes only).
- Existing GitOps workflow is already centered on Kustomize + ArgoCD app-of-apps.

## Options Considered

1. Migrate to Helm chart per service family.
2. Migrate to ArgoCD ApplicationSet for app generation + keep Kustomize manifests.
3. Keep Kustomize as primary manifest system and reduce duplication incrementally.

## Decision

Choose option 3 now:

- Keep Kustomize as the deployment source of truth.
- Do not migrate service manifests to Helm in this sprint.
- Defer ApplicationSet migration to a dedicated iteration after template contract is stabilized.

## Rationale

- Lowest rollout risk for current production/dev GitOps pipeline.
- Avoid mixing two abstraction systems (Helm + Kustomize) during active hardening sprint.
- Most current duplication can be reduced with existing Kustomize patterns (shared components, patches, replacements) without large migration cost.

## Follow-up Actions

1. Create a single reusable overlay pattern for common annotations/labels and rollout options.
2. Standardize per-service overlay delta to only service-unique values.
3. Re-evaluate ApplicationSet once service metadata is normalized (name, namespace, image, sync-wave, resources).

## Implementation (post-decision)

Shared label components in `gitops/components/`:

- `dev-env-labels` — `app.kubernetes.io/environment: dev` wired from all `apps/*/overlays/dev/kustomization.yaml`
- `production-env-labels` — `app.kubernetes.io/environment: production` wired from all `apps/*/overlays/production/kustomization.yaml` (listed before `canary-rollout` where both apply)

Follow-up items 2–3 (patch naming, ApplicationSet) remain optional.

## Outcome for Task 33

Task status: COMPLETED (evaluation + decision documented).
