# 🚀 AI-OPTIMIZED CODE REVIEW GUIDE

**Version**: 1.0.1 (Optimized for AI Agents)
**Target**: Team Leads & AI Assistants
**Purpose**: Standardized production-grade code review criteria

---

## 🏗️ 1. ARCHITECTURE & CLEAN CODE
- **Layout**: Follow Clean Architecture: `internal/biz` (logic), `internal/data` (repo), `internal/service` (api).
- **Separation**: 
    - Biz MUST NOT call DB directly (gorm.DB).
    - Service layer ONLY acts as an adapter.
- **DI**: Use Constructor Injection. Avoid global variables/state.
- **Linter**: Zero warnings on `golangci-lint`.

## 🔌 2. API & CONTRACT
- **Naming**: Proto RPCs use `Verb + Noun` (e.g., `CreateOrder`).
- **Error Mapping**: Map business errors to gRPC codes (NotFound, InvalidArgument, etc.).
- **Validation**: Comprehensive input validation at the Service layer.
- **Compatibility**: No breaking changes in Proto field numbers.

## 🧠 3. BUSINESS LOGIC & CONCURRENCY
- **Context**: Propagate `context.Context` through all layers.
- **Goroutines**: NO unmanaged `go func()`. Use `errgroup` or Event Bus.
- **Safety**: Protect shared mutable state with `sync.Mutex` or `sync.Map`.
- **Idempotency**: Critical operations MUST handle retries via Idempotency Keys.

## 💽 4. DATA LAYER & PERSISTENCE
- **Transactions**: Multi-write operations MUST use atomic transactions.
- **Optimization**: NO N+1 queries (Use `Preload`/`Joins`). Use parameterized queries for SQL safety.
- **Migrations**: Required Up/Down scripts. NO `AutoMigrate` in production.
- **Isolation**: DB implementation hidden behind interfaces.

## 🛡️ 5. SECURITY
- **Auth**: Enforce Authentication & Authorization checks in every handler.
- **Secrets**: NO hardcoded credentials. Load from ENV/Config.
- **Logging**: Mask sensitive data (passwords, tokens). Use structured JSON logs.

## ⚡ 6. PERFORMANCE & RESILIENCE
- **Caching**: Cache-aside for read-heavy data.
- **Scaling**: Implement Pagination (Offset/Cursor) for all list APIs.
- **Resources**: Configure DB/Redis connection pooling (`MaxOpenConns`, etc.).
- **Stability**: Implement Timeouts, Retries (Backoff), and Circuit Breakers for external calls.

## 👁️ 7. OBSERVABILITY
- **Logging**: Structured JSON with `trace_id`.
- **Metrics**: Prometheus RED metrics (Rate, Error, Duration).
- **Tracing**: OpenTelemetry spans for critical paths.
- **Health**: Provide `/health/live` and `/health/ready` probes.

## 🧪 8. TESTING & QUALITY
- **Coverage**: Business logic coverage > 80%.
- **Integration**: Test Repo flows with real DB (Testcontainers).
- **Mocks**: Use `mockgen` for all dependency interfaces.

## 📚 9. MAINTENANCE
- **README**: Complete setup, run, and troubleshooting guides.
- **Comments**: Explain "Why", not "What" for complex logic.
- **Tech Debt**: Track via `TODO(#issue_id)` with priority (P0/P1/P2).

## 🚀 10. DEVOPS & GITOPS
- **Ports**: Align with `PORT_ALLOCATION_STANDARD.md`.
- **Scaling**: HPA configuration is MANDATORY for all services.
- **Sync-Wave**: HPA MUST have a `sync-wave` set to at least **X+1** (where X is the Deployment wave).
- **Hooks**: Use ArgoCD `PreSync` hooks for database migrations.

---

## 📊 SEVERITY DEFINITIONS
- **P0 (Blocking)**: Security, Data Inconsistency, SQL Injection, Missing Transactions.
- **P1 (High)**: Performance (N+1), Missing Observability, No Timeouts/Retries.
- **P2 (Normal)**: Documentation, Code Style, Low Test Coverage.