# Microservices Agent Skills Index

> Last Updated: 2026-03-27 (filesystem snapshot)
> Source folder: [`microservices-agent-skills/`](../microservices-agent-skills/)

This file indexes the `microservices-agent-skills` pack used for development, review, and operations workflows in this repository.

## Snapshot

- Skills: `22`
- Workflows: `7` executable workflow docs (`workflows/*.md`, excluding `workflows/README.md`)
- Rule packs: `1` (`rules/microservices.md`)
- Environment config: `1` (`config/environment.sh`)

## Skill Groups

### Development Skills

- `add-api-endpoint`: Add REST/gRPC endpoints using project patterns
- `add-cron-job`: Add scheduled jobs to worker binaries
- `add-event-handler`: Add event publishers/consumers via Dapr PubSub
- `add-service-client`: Add service-to-service gRPC clients
- `create-migration`: Create SQL migrations (Goose format)
- `upgrade-common-lib`: Upgrade `common` library usage across services

### Navigation And Understanding Skills

- `navigate-service`: Explore service structure and key files
- `service-structure`: Understand dual-binary architecture
- `trace-event-flow`: Trace event-driven flows across services
- `use-common-lib`: Reuse existing utilities from `common`

### Quality And Review Skills

- `review-code`: Code review criteria and severity model (P0/P1/P2)
- `review-service`: Full service review and release flow
- `write-tests`: Unit/integration testing patterns and coverage flow
- `commit-code`: Validation and commit workflow
- `meeting-review`: Multi-perspective technical review format
- `create-agent-task`: Create actionable AGENT task files
- `process-agent-task`: Execute AGENT tasks end-to-end

### Operations And Reliability Skills

- `setup-gitops`: Configure/update GitOps manifests
- `debug-k8s`: Investigate Kubernetes deployment/runtime issues
- `troubleshoot-service`: Debug service runtime failures
- `rollback-deployment`: Safe rollback process for bad releases
- `performance-profiling`: Profile and optimize service performance

## Full Skill List

- `add-api-endpoint`
- `add-cron-job`
- `add-event-handler`
- `add-service-client`
- `commit-code`
- `create-agent-task`
- `create-migration`
- `debug-k8s`
- `meeting-review`
- `navigate-service`
- `performance-profiling`
- `process-agent-task`
- `review-code`
- `review-service`
- `rollback-deployment`
- `service-structure`
- `setup-gitops`
- `trace-event-flow`
- `troubleshoot-service`
- `upgrade-common-lib`
- `use-common-lib`
- `write-tests`

## Workflow Index

- `add-new-feature.md`
- `build-deploy.md`
- `hotfix-production.md`
- `refactoring.md`
- `service-review-release.md`
- `setup-new-service.md`
- `troubleshooting.md`

## Supporting Files

- Rule: [`microservices-agent-skills/rules/microservices.md`](../microservices-agent-skills/rules/microservices.md)
- Workflow reference: [`microservices-agent-skills/workflows/README.md`](../microservices-agent-skills/workflows/README.md)
- Environment helper: [`microservices-agent-skills/config/environment.sh`](../microservices-agent-skills/config/environment.sh)

## Quick Links

- Main codebase index: [CODEBASE_INDEX.md](CODEBASE_INDEX.md)
- Skill pack overview: [`microservices-agent-skills/README.md`](../microservices-agent-skills/README.md)
