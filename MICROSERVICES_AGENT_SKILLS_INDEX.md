# Microservices Agent Skills Index

> **Last Updated**: 2026-11-23 (synchronized with `microservices-agent-skills` `v5.10.0` & workspace `.agent/`)  
> **Global Engineering Pack**: [`microservices-agent-skills/`](../microservices-agent-skills/) (`v5.10.0`)  
> **Workspace Microservices Skills**: [`.agent/`](../.agent/)

This workspace uses a two-layer agent skill setup: the portable **Global Engineering Pack** (`microservices-agent-skills v5.10.0`) paired with the **Workspace Microservices Skills** (`.agent/`) for day-to-day Go/Kratos/Dapr/GitOps development.

---

## Layer 1: Global Engineering Pack (`microservices-agent-skills` `v5.10.0`)

- **Pack Root**: [`microservices-agent-skills/`](../microservices-agent-skills/) ([`INDEX.md`](../microservices-agent-skills/INDEX.md))
- **Catalog Scale**: `39` roles · `184` skills (`170` core + `14` overlay) · `25` workflows · `63` contracts · `17` packs · `21` overlays
- **Microservices Pack & Overlays**:
  - Team Pack: [`packs/ecommerce-team/manifest.yaml`](../microservices-agent-skills/packs/ecommerce-team/manifest.yaml)
  - Go Stack Overlay: [`overlays/go-microservices/README.md`](../microservices-agent-skills/overlays/go-microservices/README.md) ([`go-conventions.md`](../microservices-agent-skills/overlays/go-microservices/rules/go-conventions.md))
  - Platform Overlay (Rule-Only): [`overlays/ecommerce-microservices/README.md`](../microservices-agent-skills/overlays/ecommerce-microservices/README.md) ([`microservices-conventions.md`](../microservices-agent-skills/overlays/ecommerce-microservices/rules/microservices-conventions.md))

---

## Layer 2: Workspace Microservices Skills (`.agent/`)

- **Skills**: `23` (Go 1.27.4 / Kratos v2.9.2 / `common v1.37.1` / Dapr / GitOps)
- **Workflows**: `7` executable workflow docs ([`.agent/workflows/`](../.agent/workflows/))
- **Rule Pack**: [`.agent/rules/microservices.md`](../.agent/rules/microservices.md)
- **Environment Helper**: [`.agent/config/environment.sh`](../.agent/config/environment.sh)

### Skill Groups

#### Development Skills (`6`)

- [`add-api-endpoint`](../.agent/skills/add-api-endpoint/SKILL.md): Add REST/gRPC endpoints using project patterns and OpenAPI exposure
- [`add-cron-job`](../.agent/skills/add-cron-job/SKILL.md): Add scheduled jobs to worker binaries
- [`add-event-handler`](../.agent/skills/add-event-handler/SKILL.md): Add event publishers/consumers via Dapr PubSub with idempotency
- [`add-service-client`](../.agent/skills/add-service-client/SKILL.md): Add service-to-service gRPC clients
- [`create-migration`](../.agent/skills/create-migration/SKILL.md): Create SQL migrations (Goose format)
- [`upgrade-common-lib`](../.agent/skills/upgrade-common-lib/SKILL.md): Upgrade `common` library usage across services

#### Navigation And Understanding Skills (`4`)

- [`navigate-service`](../.agent/skills/navigate-service/SKILL.md): Explore service structure and key files
- [`service-structure`](../.agent/skills/service-structure/SKILL.md): Understand tri-binary architecture (`cmd/<service>`, `cmd/worker`, `cmd/migrate`)
- [`trace-event-flow`](../.agent/skills/trace-event-flow/SKILL.md): Trace event-driven flows across services
- [`use-common-lib`](../.agent/skills/use-common-lib/SKILL.md): Reuse existing utilities from `common`

#### Quality And Review Skills (`7`)

- [`review-code`](../.agent/skills/review-code/SKILL.md): Code review criteria and severity model
- [`review-service`](../.agent/skills/review-service/SKILL.md): Full service review and release flow
- [`write-tests`](../.agent/skills/write-tests/SKILL.md): Unit/integration testing patterns and coverage flow
- [`commit-code`](../.agent/skills/commit-code/SKILL.md): Validation and commit workflow
- [`meeting-review`](../.agent/skills/meeting-review/SKILL.md): Multi-perspective technical review format
- [`create-agent-task`](../.agent/skills/create-agent-task/SKILL.md): Create actionable AGENT task files
- [`process-agent-task`](../.agent/skills/process-agent-task/SKILL.md): Execute AGENT tasks end-to-end

#### Operations And Reliability Skills (`6`)

- [`setup-gitops`](../.agent/skills/setup-gitops/SKILL.md): Configure/update GitOps manifests
- [`debug-k8s`](../.agent/skills/debug-k8s/SKILL.md): Investigate Kubernetes deployment/runtime issues
- [`debug-openclaw-telegram`](../.agent/skills/debug-openclaw-telegram/SKILL.md): Debug OpenClaw Telegram bot health, gateway/auth errors, and safe dev server cleanup
- [`troubleshoot-service`](../.agent/skills/troubleshoot-service/SKILL.md): Debug service runtime failures
- [`rollback-deployment`](../.agent/skills/rollback-deployment/SKILL.md): Safe rollback process for bad releases
- [`performance-profiling`](../.agent/skills/performance-profiling/SKILL.md): Profile and optimize service performance

### Workflow Index (`7`)

- [`add-new-feature.md`](../.agent/workflows/add-new-feature.md)
- [`build-deploy.md`](../.agent/workflows/build-deploy.md)
- [`hotfix-production.md`](../.agent/workflows/hotfix-production.md)
- [`refactoring.md`](../.agent/workflows/refactoring.md)
- [`service-review-release.md`](../.agent/workflows/service-review-release.md)
- [`setup-new-service.md`](../.agent/workflows/setup-new-service.md)
- [`troubleshooting.md`](../.agent/workflows/troubleshooting.md)

## Quick Links

- Main codebase index: [CODEBASE_INDEX.md](CODEBASE_INDEX.md)
- Service catalog: [SERVICE_INDEX.md](SERVICE_INDEX.md)
- Global pack overview: [`microservices-agent-skills/README.md`](../microservices-agent-skills/README.md)
