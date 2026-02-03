# Coding Standards — Developer & AI Agent Guide

**Version**: 1.0  
**Last Updated**: 2026-01-30  
**Domain**: Development Standards  
**Audience**: Developers, AI agents (Cursor, Copilot, etc.)

## Purpose

This document is the **single reference** to follow when writing or reviewing code in this microservices platform. Use it for:

- **Developers**: Day-to-day coding, PRs, and refactors.
- **AI agents**: When generating or modifying code, follow these rules so output matches project conventions.

**Canonical references**: [API Architecture](../../01-architecture/api-architecture.md) (proto & versioning), [Development Review Checklist](./development-review-checklist.md), [Common Package Usage](./common-package-usage.md).

**Common package**: The `common` package must stay **base-only** (utilities, helpers, repository base, events infra, validation, errors, config). Do not add domain interfaces, DTOs, or per-service definitions to common; types and contracts belong to the owning service. See [Common Package Cleanup Plan](../../10-appendix/checklists/v3/common-package-cleanup-plan.md) for the full principle and checklist.

---

## 1. Go Code Style

### 1.1 Package Naming

- Use **lowercase**, **single-word** package names.
- ✅ `package biz`, `package data`, `package service`
- ❌ `package business`, `package datalayer`

### 1.2 Error Handling

- **Always** return errors; never ignore them.
- Use `fmt.Errorf(..., %w, err)` for wrapping so callers can use `errors.Is` / `errors.As`.
- Use common/errors for structured errors where applicable.

```go
// ✅ Good
if err != nil {
    return nil, fmt.Errorf("failed to create user: %w", err)
}

// ❌ Bad
_ = repo.Create(user)
```

### 1.3 Context

- **First parameter** of functions that do I/O or call other services must be `context.Context`.
- Propagate context to downstream calls; respect cancellation (e.g. `ctx.Done()` in long-running logic).

```go
// ✅ Good
func (r *userRepo) FindByID(ctx context.Context, id string) (*User, error)

// ❌ Bad
func (r *userRepo) FindByID(id string) (*User, error)
```

### 1.4 Logging

- Use **Kratos** (or project) structured logging with **context**.
- Do not log sensitive data (passwords, tokens, PII) in plain text.

```go
logger.WithContext(ctx).Infof("Creating user: %s", user.Username)
logger.WithContext(ctx).Errorf("Failed to create user: %v", err)
```

### 1.5 Interfaces and Dependencies

- **Define interfaces in the biz layer**; implement them in the data layer.
- Prefer **small, focused interfaces** (e.g. `FindByID`, `Create`).
- Use **dependency injection** (e.g. Wire); accept interfaces, return structs.

```go
// biz/user.go
type UserRepo interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
}

// data/user.go
type userRepo struct {
    data *Data
    log  *log.Helper
}
```

### 1.6 Constants

- **Do not hardcode** magic strings or numbers in business logic.
- Centralize in `internal/constants` (e.g. event topics, cache key prefixes, status strings).

```go
// internal/constants/events.go
const (
    TopicOrderCreated = "order.created"
    TopicPriceUpdated = "pricing.price.updated"
)
```

### 1.7 Common Package (Base Only)

- **Developers and AI agents**: When adding or reviewing code in the **common** package, keep it **base-only**.
  - **Do** provide: repository base, event helpers, validation helpers, errors, config loader, middleware, observability (health, metrics, tracing), generic utils (pagination, retry, uuid, etc.).
  - **Do not** add: domain interfaces (e.g. `UserService`, `OrderService`), domain DTOs (e.g. `User`, `OrderInfo`), or per-service helpers (e.g. `CreateAuthClient()`, `CreateUserClient()`). Types and service contracts belong to the **owning service**; consumers import from that service (or define minimal interfaces in their own biz layer).
- Prefer **generic APIs** in common (e.g. `CreateClient(serviceName, target)` instead of one method per service). See [Common Package Cleanup Plan](../../10-appendix/checklists/v3/common-package-cleanup-plan.md).

---

## 2. Proto & gRPC (API Contract)

Follow [API Architecture — Proto Style Guide](../../01-architecture/api-architecture.md).

### 2.1 Naming

| Item         | Convention        | Example                          |
|-------------|-------------------|----------------------------------|
| File names  | `snake_case.proto`| `order_service.proto`           |
| Packages    | `versioned.snake_case` | `api.order.v1`             |
| Messages    | `PascalCase`      | `CreateOrderRequest`            |
| Fields      | **`snake_case`**  | `user_id`, `order_id`           |
| RPCs        | `PascalCase`      | `GetOrder`, `ListOrders`        |
| Enums       | `PascalCase`      | `OrderStatus`                   |
| Enum values | `UPPER_SNAKE_CASE`| `ORDER_STATUS_PENDING`          |

### 2.2 Directory Layout

```text
service-name/
├── api/
│   └── service-name/
│       └── v1/
│           ├── service.proto
│           └── messages.proto
├── internal/
└── go.mod
```

### 2.3 Breaking Changes

- **Breaking** (new major API version): remove/rename RPCs or fields, change types → new package e.g. `api.order.v2`.
- **Non-breaking**: add optional fields, add new RPCs → stay in same package (e.g. `v1`).
- Do **not** reuse field numbers of deleted fields; use `reserved`.

### 2.4 After Changing Proto

1. Edit `.proto` under `api/`.
2. Run **`make api`** in the service directory.
3. Fix compile errors in `internal/service/` and related code.
4. Run **`go build ./...`**.

---

## 3. Versioning & Git Tags (Microservice + gRPC)

### 3.1 Semantic Versioning Strategy

- **Format**: `MAJOR.MINOR.PATCH` (e.g. `1.2.3`).

#### When to increment versions:

| Version Type | When to Use | Examples |
|-------------|-------------|----------|
| **MAJOR** | Breaking changes that affect consumers | • Remove/rename gRPC methods<br>• Remove/rename proto fields<br>• Change field types<br>• Remove database columns<br>• Change API contracts |
| **MINOR** | New features, backward compatible | • Add new gRPC methods<br>• Add optional proto fields<br>• Add new database columns<br>• New endpoints<br>• Performance improvements |
| **PATCH** | Bug fixes, no new features | • Fix bugs<br>• Security patches<br>• Documentation updates<br>• Refactoring without behavior change |

#### Pre-release versions:
- **Alpha**: `v1.2.0-alpha.1` - Early development, unstable
- **Beta**: `v1.2.0-beta.1` - Feature complete, testing phase
- **RC**: `v1.2.0-rc.1` - Release candidate, final testing

### 3.2 When to Tag

| Repo type              | Tag? | When |
|------------------------|------|------|
| **Common** (shared pkg)| Yes  | Every stable release consumed by other services (e.g. after proto/utils change). Use semver (e.g. `v1.0.15`). |
| **Per-service**       | Optional | When you need a **release version** for rollback, changelog, or other services depending on this repo. Use semver (e.g. `v1.2.0`). |

- **Common**: Tag so consumers can pin: `go get .../common@v1.0.15`.
- **Services**: Deploy is usually by **image tag** (e.g. SHA). Git tags are for human-readable releases and dependency pinning if other repos depend on this service’s module.

### 3.3 Changelog Requirements

#### 3.3.1 Mandatory for all releases:
- **CHANGELOG.md** file in service root directory
- Follow [Keep a Changelog](https://keepachangelog.com/) format
- Update before creating git tag

#### 3.3.2 Changelog format:
```markdown
# Changelog

## [Unreleased]
### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security

## [1.2.0] - 2026-01-30
### Added
- New gRPC method GetOrderHistory
- Support for order filtering by date range

### Changed
- Improved order validation logic
- Updated dependencies to latest versions

### Fixed
- Fixed race condition in order processing
- Resolved memory leak in cache cleanup

## [1.1.0] - 2026-01-15
...
```

#### 3.3.3 Required sections:
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Now removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements

#### 3.3.4 Git tag message:
```bash
# Include changelog summary in tag message
git tag -a v1.2.0 -m "v1.2.0: Add order history API, improve validation

Added:
- New gRPC method GetOrderHistory
- Support for order filtering by date range

Fixed:
- Fixed race condition in order processing
- Resolved memory leak in cache cleanup"
```

### 3.4 Release Process

1. **Update CHANGELOG.md** with all changes since last release
2. **Move [Unreleased] items** to new version section
3. **Commit changelog**: `git commit -m "docs: update changelog for v1.2.0"`
4. **Create annotated tag**: `git tag -a v1.2.0 -m "v1.2.0: summary"`
5. **Push tag**: `git push origin v1.2.0`

---

## 4. Service Architecture (Layers)

- **biz/** — Business logic only; no direct DB/HTTP/gRPC. Depends on interfaces (repos, clients).
- **data/** — Repositories, DB, Redis; implements biz interfaces.
- **service/** — gRPC/HTTP handlers; thin layer calling biz.
- **client/** — Outbound calls to other services (gRPC clients, etc.).
- **events/** — Publishing/consuming domain events (e.g. Dapr).

When coding:

- Put **domain rules** in `biz/`.
- Put **queries and persistence** in `data/`.
- Keep **handlers** in `service/` thin (parse request → call biz → return response).

---

## 5. Security & Validation

- **Validate** all external input (HTTP/gRPC requests); use common/validation or project validators.
- **No hardcoded secrets**; use config/env.
- **Service-to-service**: Use auth (e.g. service tokens) as per [Security Architecture](../../01-architecture/security-architecture.md).
- Use **parameterized queries**; never concatenate user input into SQL.

---

## 6. Testing

- **Unit tests** for biz logic; use mocks for repos and clients.
- Prefer **table-driven tests** for multiple cases.
- **Integration tests** for critical flows (DB, gRPC) where applicable.
- Aim for **high coverage on business logic** (e.g. 80%+ where practical).

---

## 7. Quick Checklist (Follow When Coding)

Use this when writing or generating code:

- [ ] **Context**: First param is `context.Context` for I/O and external calls.
- [ ] **Errors**: Every error path returns an error; use `%w` when wrapping.
- [ ] **Constants**: No magic strings/numbers; use `internal/constants`.
- [ ] **Interfaces**: Defined in biz, implemented in data; keep interfaces small.
- [ ] **Proto**: `snake_case` fields, correct package/version; run `make api` after changes.
- [ ] **Layers**: Biz = domain logic; data = persistence; service = thin handlers.
- [ ] **Logging**: Structured, with context; no secrets in logs.
- [ ] **Validation**: All external input validated; no raw SQL with user input.
- [ ] **Common**: Prefer common package utilities over local duplicates (see [Common Package Usage](./common-package-usage.md)). Keep common **base-only**—no domain interfaces/DTOs or per-service definitions (see §1.7).

---

## 8. References

| Doc | Purpose |
|-----|--------|
| [API Architecture](../../01-architecture/api-architecture.md) | Proto style, versioning, `make api` |
| [Development Review Checklist](./development-review-checklist.md) | PR and review criteria |
| [Common Package Usage](./common-package-usage.md) | Shared libraries and patterns |
| [Common Package Cleanup Plan](../../10-appendix/checklists/v3/common-package-cleanup-plan.md) | Common = base-only; process and plan |
| [Team Lead Code Review Guide](./TEAM_LEAD_CODE_REVIEW_GUIDE.md) | Review process |

---

**Summary**: Use this doc as the default set of rules when coding or when an AI agent generates code. For proto and versioning details, always align with [API Architecture](../../01-architecture/api-architecture.md).
