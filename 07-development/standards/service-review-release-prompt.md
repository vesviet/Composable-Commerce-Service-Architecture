# Service Review & Release Prompt

**Version**: 1.0  
**Last Updated**: 2026-01-30  
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
2. **[Team Lead Code Review Guide](./TEAM_LEAD_CODE_REVIEW_GUIDE.md)** — Architecture, API, biz logic, data, security, performance, observability, testing.
3. **[Development Review Checklist](./development-review-checklist.md)** — Pre-review, issue levels, Go/security/testing/DevOps criteria.

---

## Process for `serviceName`

Use this process for the service identified by **`serviceName`** (e.g. warehouse → `warehouse`, pricing → `pricing`).  
Paths and commands below use `serviceName`; replace it with the real service name.

### 1. Index & review codebase

- Index and understand the **`serviceName`** service: directory `{serviceName}/`, layout (biz/data/service/client/events), proto under `api/`, `internal/constants`, `go.mod`.
- Review code against the three standards above (architecture, layers, context, errors, validation, security, no N+1, transactions, observability).
- List any **P0 / P1 / P2** issues (use severity from TEAM_LEAD_CODE_REVIEW_GUIDE).

### 2. Checklist & todo for `serviceName`

- Open or create the checklist: **`docs/10-appendix/checklists/v3/{serviceName}_service_checklist_v3.md`**.
- Align items with TEAM_LEAD_CODE_REVIEW_GUIDE and development-review-checklist (P0/P1/P2).
- Mark completed items; add items for remaining work. **Skip adding or requiring test-case tasks** (per user request).
- Save/update the file under `docs/10-appendix/checklists/v3/`.

### 3. Dependencies (Go modules)

#### 3.1 Convert replace to import (if needed)
- **Check for `replace` directives**: Search for any `replace gitlab.com/ta-microservices/...` lines in go.mod.
- **Remove replace directives**: Delete all `replace gitlab.com/ta-microservices/... => ../...` lines.
- **Get latest versions**: For each removed replace, run `go get gitlab.com/ta-microservices/<service>@latest` to get the newest version.

#### 3.2 Update dependencies
- Update dependencies from **gitlab.com/ta-microservices**: use **`go get`** with the latest tag, e.g.  
  `go get gitlab.com/ta-microservices/common@latest`
- **Do not use `replace`** in go.mod for gitlab.com/ta-microservices; use normal **import** and version via `go get`.
- Run **`go mod tidy`** in the service directory.

#### 3.3 Example conversion
```bash
# Before: go.mod contains
# replace gitlab.com/ta-microservices/common => ../common

# After: Remove replace line and run
go get gitlab.com/ta-microservices/common@latest
go get gitlab.com/ta-microservices/catalog@latest
go mod tidy
```

### 4. Lint & build

- In **`{serviceName}/`**: run **`golangci-lint run`** and fix reported issues.
- Run **`make api`** (if proto changed), then **`go build ./...`**, then **`make wire`** (if DI changed).
- Target: zero golangci-lint warnings and a clean build.

### 5. Docs

#### 5.1 Service Documentation Structure

Update or create service docs under **`docs/03-services`** with the following structure:

**Main service doc**: **`docs/03-services/<group>/{serviceName}-service.md`**

Where `<group>` is one of:
- **core-services**: Essential business services (order, catalog, customer, payment, etc.)
- **operational-services**: Supporting services (notification, analytics, etc.)  
- **platform-services**: Infrastructure services (gateway, auth, common-operations, etc.)

#### 5.2 Service Doc Template

Use this template for **`docs/03-services/<group>/{serviceName}-service.md`**:

```markdown
# {ServiceName} Service

**Version**: 1.0  
**Last Updated**: YYYY-MM-DD  
**Service Type**: [Core/Operational/Platform]  
**Status**: [Active/Development/Deprecated]

## Overview

Brief description of what this service does and its role in the system.

## Architecture

### Responsibilities
- Primary responsibility 1
- Primary responsibility 2
- Primary responsibility 3

### Dependencies
- **Upstream services**: Services this service calls
- **Downstream services**: Services that call this service
- **External dependencies**: Databases, message queues, etc.

## API Contract

### gRPC Services
- **Service**: `api.{servicename}.v1.{ServiceName}Service`
- **Proto location**: `{serviceName}/api/{servicename}/v1/`
- **Key methods**:
  - `Method1(Request) → Response` - Description
  - `Method2(Request) → Response` - Description

### HTTP Endpoints (if any)
- `GET /api/v1/{resource}` - Description
- `POST /api/v1/{resource}` - Description

## Data Model

### Database Tables
- **Table 1**: Purpose and key fields
- **Table 2**: Purpose and key fields

### Key Entities
- **Entity1**: Description and relationships
- **Entity2**: Description and relationships

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VAR_NAME` | Yes | - | Purpose |
| `VAR_NAME2` | No | `default` | Purpose |

### Config Files
- **Location**: `{serviceName}/configs/`
- **Key settings**: Brief description

## Deployment

### Docker
- **Image**: `registry/ta-microservices/{servicename}`
- **Ports**: List exposed ports
- **Health check**: Endpoint and expected response

### Kubernetes
- **Namespace**: `ta-microservices`
- **Resources**: CPU/Memory requirements
- **Scaling**: Min/max replicas

## Monitoring & Observability

### Metrics
- Key business metrics exposed
- Performance metrics
- Health indicators

### Logging
- Log levels and key log messages
- Structured logging format

### Tracing
- Key spans and trace points

## Development

### Local Setup
1. Prerequisites
2. Configuration steps
3. Running the service

### Testing
- Unit test coverage
- Integration test approach
- Key test scenarios

## Troubleshooting

### Common Issues
- **Issue 1**: Symptoms and resolution
- **Issue 2**: Symptoms and resolution

### Debug Commands
```bash
# Useful commands for debugging
kubectl logs -f deployment/{servicename}
```

## Changelog

Link to CHANGELOG.md or recent changes summary.

## References

- [API Documentation](../04-apis/{servicename}-api.md)
- [Related Services](./related-service.md)
```

#### 5.3 README.md Structure

Update **`{serviceName}/README.md`** with this structure:

```markdown
# {ServiceName} Service

Brief service description.

## Quick Start

### Prerequisites
- Go 1.25+
- Docker & Docker Compose
- PostgreSQL (or required database)

### Local Development
```bash
# Clone and setup
git clone <repo>
cd {serviceName}
cp .env.example .env

# Install dependencies
go mod download

# Run database migrations
make migrate-up

# Start service
make run
```

### Docker Development
```bash
# Build and run with docker-compose
docker-compose up --build
```

## Configuration

### Environment Variables
Key environment variables (link to full list in service docs).

### Database Setup
Database connection and migration instructions.

## API

### gRPC
- **Port**: 9000 (or service-specific port)
- **Proto**: `api/{servicename}/v1/`
- **Health check**: `grpc_health_probe -addr=:9000`

### HTTP (if applicable)
- **Port**: 8000 (or service-specific port)
- **Health check**: `GET /health`

## Testing

```bash
# Run unit tests
make test

# Run integration tests
make test-integration

# Generate coverage report
make coverage
```

## Build & Deploy

```bash
# Build binary
make build

# Build Docker image
make docker-build

# Deploy to staging
make deploy-staging
```

## Troubleshooting

### Common Issues
- Connection issues
- Configuration problems
- Performance issues

### Debug Commands
Useful commands for local debugging.

## Documentation

- [Service Documentation](../docs/03-services/<group>/{servicename}-service.md)
- [API Reference](../docs/04-apis/{servicename}-api.md)
```

#### 5.4 Documentation Checklist

Ensure both documents include:
- [ ] **Current and accurate** information
- [ ] **Working commands** (test all bash commands)
- [ ] **Correct ports and endpoints**
- [ ] **Up-to-date dependencies**
- [ ] **Valid configuration examples**
- [ ] **Troubleshooting section** with real issues
- [ ] **Links to related documentation**

### 6. Commit & release

- Commit with conventional commits: `feat({serviceName}): …`, `fix({serviceName}): …`, `docs({serviceName}): …`.
- If this is a **release**: create a new Git tag (semver, e.g. `v1.0.7`) and push:
  - `git tag -a v1.0.7 -m "v1.0.7: description"`
  - `git push origin main && git push origin v1.0.7`
- If **not** a release: push branch only: `git push origin <branch>`.

---

## Summary

- **Prompt**: “Follow docs/07-development/standards/service-review-release-prompt.md and run the process for service name **`<serviceName>`**.”
- **Process**: Index → review (3 standards) → checklist v3 for `serviceName` (skip test-case) → **convert replace to import @latest** → go get @latest (no replace) → golangci-lint → make api / go build / wire → update docs (03-services + README) → commit → tag (if release) → push.
