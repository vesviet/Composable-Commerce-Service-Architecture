# Service Review & Release Prompt

**Version**: 2.0  
**Last Updated**: 2026-02-13  
**Purpose**: Single prompt/process for reviewing and releasing any microservice

---

## How to use this doc

**Prompt to give AI / yourself:**

> Follow **docs/07-development/standards/service-review-release-prompt.md** and run the process for service name **`<serviceName>`**.

Replace `<serviceName>` with the actual service (e.g. `warehouse`, `pricing`, `catalog`, `order`).

---

## Standards (read first)

Before any code change, apply these docs in order:

1. **[Coding Standards](./coding-standards.md)** — Go style, proto, layers, context, errors, constants.
2. **[Team Lead Code Review Guide](./TEAM_LEAD_CODE_REVIEW_GUIDE.md)** — Architecture, API, biz logic, data, security, performance, observability.
3. **[Development Review Checklist](./development-review-checklist.md)** — Pre-review, issue levels, Go/security/testing/DevOps criteria.

---

## Process for `serviceName`

Use this process for the service identified by **`serviceName`** (e.g. warehouse → `warehouse`, pricing → `pricing`).  
Paths and commands below use `serviceName`; replace it with the real service name.

> [!IMPORTANT]
> Many services use a **dual-binary architecture**: `cmd/<serviceName>/` (main API server) + `cmd/worker/` (event consumers, cron, outbox). Always review **both** entry points.

### 1. Index & review codebase

- Index and understand the **`serviceName`** service:
  - Directory `{serviceName}/` layout: `cmd/` (main + worker entry points), `internal/biz/`, `internal/data/`, `internal/service/`, `internal/client/`, `internal/events/`, `internal/worker/`, `internal/constants/`
  - Proto under `api/{serviceName}/v1/`
  - Migrations: `migrations/`
  - Config: `configs/`, `go.mod`
- Review code against the three standards above (architecture, layers, context, errors, validation, security, no N+1, transactions, observability).
- List any **P0 / P1 / P2** issues (use severity from TEAM_LEAD_CODE_REVIEW_GUIDE).

| Severity | Definition | Examples |
|----------|-----------|----------|
| **P0 (Blocking)** | Security, data inconsistency, breaking backward compat | No auth, raw SQL concat, biz calls DB directly, proto field removed without `reserved`, breaking event schema |
| **P1 (High)** | Performance, missing observability, config mismatch | N+1 queries, no circuit breaker, env var not in configmap |
| **P2 (Normal)** | Documentation, code style, naming | Missing comments, TODO without ticket |

### 2. Cross-service impact analysis

> [!WARNING]
> **This step is mandatory.** Skipping it risks deploying breaking changes that crash other services at runtime.

#### 2.1 Proto/API backward compatibility

```bash
# Who depends on this service's proto?
grep -r 'gitlab.com/ta-microservices/{serviceName}' --include='go.mod' /home/user/microservices/*/go.mod
```

- Proto field numbers preserved (use `reserved` for deleted fields)
- New fields are optional (adding required fields = MAJOR break)
- RPC signatures stable (no rename/remove without versioning `v1` → `v2`)
- All client services still compile after changes

#### 2.2 Event schema compatibility

```bash
# Who consumes this service's events?
grep -r 'Topic.*{serviceName}' /home/user/microservices/*/internal/ --include='*.go' -l
```

- Event struct changes are additive-only (removing/renaming fields = breaking)
- Consumers handle old + new format gracefully
- Topic names immutable (never rename existing topics)

#### 2.3 Go module dependency graph
- No circular imports between services
- Minimal import surface (don't import entire service module for one type)

### 3. Checklist & todo for `serviceName`

- Track review findings and TODOs in the service doc: **`docs/03-services/<group>/{serviceName}-service.md`**
- Align items with TEAM_LEAD_CODE_REVIEW_GUIDE and development-review-checklist (P0/P1/P2).
- Mark completed items; add items for remaining work. **Skip adding or requiring test-case tasks** (per user request).

### 4. Dependencies (Go modules)

> [!CAUTION]
> **NO `replace` directives for `gitlab.com/ta-microservices` are allowed.** This works locally but breaks CI/CD.

#### 4.1 Check if `common` changed

```bash
# If common has uncommitted changes, it MUST be committed + tagged FIRST
cd /home/user/microservices/common && git status
```

**If `common` changed → commit, tag, and push `common` BEFORE touching the service:**

```bash
cd /home/user/microservices/common
golangci-lint run && go build ./... && go test ./...
git add -A && git commit -m "<type>(common): <description>"
git tag --sort=-creatordate | head -5   # check current latest tag
git tag -a v1.x.y -m "v1.x.y: <summary>"
git push origin main && git push origin v1.x.y
```

> [!IMPORTANT]
> **Common must be tagged before any service commit.** Services import `common` via `go get @<tag>`. If the service is committed before common is tagged, `go.mod` references a non-existent version.

#### 4.2 Convert replace to import (if needed)

```bash
# Check for forbidden replace directives
grep 'replace gitlab.com/ta-microservices' {serviceName}/go.mod

# If found: remove replace lines, then get latest versions:
cd /home/user/microservices/{serviceName}
go get gitlab.com/ta-microservices/common@latest
go get gitlab.com/ta-microservices/<other-dep>@latest
go mod tidy
```

#### 4.3 Update dependencies

```bash
cd /home/user/microservices/{serviceName}
go get gitlab.com/ta-microservices/common@latest    # or @v1.x.y if just tagged
go mod tidy
```

### 5. Lint & build

```bash
cd /home/user/microservices/{serviceName}

# 1. Generate proto (if .proto files changed)
make api

# 2. Regenerate Wire (if DI providers changed) — BOTH binaries
cd cmd/{serviceName} && wire
cd ../worker && wire      # if worker binary exists

# 3. Lint (target: zero warnings)
cd /home/user/microservices/{serviceName}
golangci-lint run

# 4. Build
go build ./...

# 5. Run tests
go test ./...
```

> [!NOTE]
> **Never manually edit `wire_gen.go` or `*.pb.go`** — these files are auto-generated. Always use `wire` and `make api` to regenerate.

### 6. Deployment readiness (GitOps alignment)

Before release, verify config alignment between code and GitOps.

> [!IMPORTANT]
> **Port allocation MUST follow [PORT_ALLOCATION_STANDARD.md](../../../gitops/docs/PORT_ALLOCATION_STANDARD.md).** Look up the correct HTTP/gRPC ports for `{serviceName}` in the Port Allocation Table and verify all references match.

```bash
# 0. Look up correct ports from standard
grep '{serviceName}' /home/user/microservices/gitops/docs/PORT_ALLOCATION_STANDARD.md

# 1. Check env vars used in code
grep -rn 'os.Getenv\|viper.Get\|envconfig' {serviceName}/internal/ --include='*.go'

# 2. Compare with gitops configmap
cat gitops/apps/{serviceName}/base/configmap.yaml

# 3. Verify ports match (MUST align with PORT_ALLOCATION_STANDARD.md)
grep 'addr:' {serviceName}/configs/config.yaml
grep 'containerPort:' gitops/apps/{serviceName}/base/deployment.yaml
grep 'targetPort:' gitops/apps/{serviceName}/base/service.yaml
grep 'dapr.io/app-port:' gitops/apps/{serviceName}/base/deployment.yaml
grep -A2 'livenessProbe:\|readinessProbe:' gitops/apps/{serviceName}/base/deployment.yaml | grep port

# 4. Check resource limits are set
grep -A5 'resources:' gitops/apps/{serviceName}/base/deployment.yaml

# 5. Check HPA exists
ls gitops/apps/{serviceName}/base/hpa.yaml 2>/dev/null || echo "⚠️ No HPA configured"
```

Checklist:
- [ ] **Ports match PORT_ALLOCATION_STANDARD.md**: `config.yaml` addr ↔ `deployment.yaml` containerPort ↔ `service.yaml` targetPort ↔ `dapr.io/app-port` ↔ health probe ports
- [ ] New env vars in code → ConfigMap/Secret updated in `gitops/`
- [ ] Resource limits set (not unbounded)
- [ ] Health probes configured (liveness + readiness) on correct port
- [ ] Dapr annotations correct (`app-id`, `app-port`, `app-protocol`)
- [ ] NetworkPolicy allows required egress/ingress
- [ ] Migration strategy safe for zero-downtime deploy

### 7. Docs

#### 7.1 Service documentation

Update or create service docs under **`docs/03-services/<group>/`**:

| Group | Services |
|-------|----------|
| `core-services` | order, catalog, customer, payment, auth, user |
| `operational-services` | notification, analytics, search, review, warehouse, fulfillment, shipping, pricing, promotion, loyalty-rewards, location |
| `platform-services` | gateway, common-operations |

Use the template at **[docs/templates/service-doc-template.md](../../templates/service-doc-template.md)**.

#### 7.2 README.md

Update **`{serviceName}/README.md`** using the template at **[docs/templates/readme-template.md](../../templates/readme-template.md)**.

#### 7.3 CHANGELOG.md

Update **`{serviceName}/CHANGELOG.md`** (create if not exists):

```markdown
## [Unreleased]
### Added
- <describe new features>

### Changed
- <describe changes>

### Fixed
- <describe bug fixes>
```

#### 7.4 Documentation checklist

- [ ] Current and accurate information
- [ ] Working commands (tested)
- [ ] Correct ports and endpoints
- [ ] Up-to-date dependencies
- [ ] Valid configuration examples
- [ ] Troubleshooting section with real issues
- [ ] Links to related documentation

### 8. Commit & release

> [!IMPORTANT]
> **CI/CD builds Docker images and updates GitOps tags automatically.** Never build Docker images locally. Never manually update `newTag` in gitops kustomization.

#### 8.1 Commit order (when multiple components changed)

```
┌─────────────────────────────────────────────────────┐
│                 COMMIT ORDER MATTERS                 │
│                                                      │
│  1. common/  → commit + tag (v1.x.y) + push         │
│       ↓                                              │
│  2. service/ → go get common@v1.x.y + commit + push  │
│       ↓                                              │
│  3. CI/CD builds image + updates gitops tag auto     │
│                                                      │
│  ⚠️ common MUST be committed and tagged FIRST        │
└─────────────────────────────────────────────────────┘
```

#### 8.2 Commit

```bash
cd /home/user/microservices/{serviceName}
git add -A
git commit -m "<type>({serviceName}): <description>"
```

**Conventional commit types:**

| Type | When | Example |
|------|------|---------|
| `feat` | New feature | `feat(order): add order history API` |
| `fix` | Bug fix | `fix(payment): fix race condition in capture` |
| `refactor` | Code refactor | `refactor(catalog): extract pricing logic` |
| `docs` | Documentation | `docs(order): update API documentation` |
| `chore` | Maintenance | `chore(order): update dependencies` |
| `perf` | Performance | `perf(search): optimize query performance` |

#### 8.3 Push & release

```bash
# Push to remote (CI will build Docker image automatically)
git push origin main

# If this is a RELEASE (semver):
git tag -a v1.0.7 -m "v1.0.7: description

Added:
- New feature X

Fixed:
- Bug Y"
git push origin v1.0.7
```

**If NOT a release**: push branch only: `git push origin <branch>`.

**Verify deployment** (after CI builds and ArgoCD syncs, ~2-5 min):

```bash
# Check if CI updated gitops tag
cd /home/user/microservices/gitops && git pull origin main
# Verify newTag matches latest commit hash

# Check pod status
ssh tuananh@dev.tanhdev.com -p 8785 "kubectl get pods -n {serviceName}-dev -w"
```

---

## Review output format

Use this format to report review findings:

```markdown
## 🔍 Service Review: {serviceName}

**Date**: YYYY-MM-DD
**Status**: ✅ Ready / ⚠️ Needs Work / ❌ Not Ready

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | X | Fixed / Remaining |
| P1 (High) | X | Fixed / Remaining |
| P2 (Normal) | X | Fixed / Remaining |

### 🔴 P0 Issues (Blocking)
1. **[CATEGORY]** file:line — Description

### 🟡 P1 Issues (High)
1. **[CATEGORY]** file:line — Description

### 🔵 P2 Issues (Normal)
1. **[CATEGORY]** file:line — Description

### ✅ Completed Actions
1. Fixed: description

### 🌐 Cross-Service Impact
- Services that import this proto: [list]
- Services that consume events: [list]
- Backward compatibility: ✅ Preserved / ❌ Breaking

### 🚀 Deployment Readiness
- Config/GitOps aligned: ✅ / ❌
- Health probes: ✅ / ❌
- Resource limits: ✅ / ❌
- Migration safety: ✅ / ❌

### Build Status
- `golangci-lint`: ✅ 0 warnings / ❌ X warnings
- `go build ./...`: ✅ / ❌
- `wire`: ✅ Generated / ❌ Needs regen

### Documentation
- Service doc: ✅ / ❌
- README.md: ✅ / ❌
- CHANGELOG.md: ✅ / ❌
```

---

## Summary

- **Prompt**: "Follow docs/07-development/standards/service-review-release-prompt.md and run the process for service name **`<serviceName>`**."
- **Process**: Index (both main + worker) → review (3 standards) → cross-service impact → checklist → **common first (if changed, tag + push)** → convert replace → go get @latest → `make api` / `wire` (both binaries) / `golangci-lint` / `go build` / `go test` → deployment readiness (GitOps alignment) → update docs (service doc + README + CHANGELOG) → commit (conventional) → push → CI/CD builds + deploys.
