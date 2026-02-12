# Analytics Service Review Checklist V3

**Service**: `analytics`
**Review Date**: 2026-02-12
**Reviewer**: AI Assistant

## 1. Codebase Index & Review
- [x] **Index Codebase**: Understand directory structure (`biz`, `data`, `service`, `api`).
- [x] **Architecture Check**: Verify strict layer separation (Service -> Biz -> Data).
- [ ] **Code Quality**: Check for hardcoded values, magic numbers, and long functions.
- [ ] **Error Handling**: storage errors masked, business errors returned with proper codes.
- [ ] **Observability**: Context propagation, logging with trace IDs.

## 2. Dependency Management
- [x] **Replace Directives**: No `replace` directives in `go.mod`.
- [ ] **Update Dependencies**: `go get gitlab.com/ta-microservices/common@latest` and others.
- [ ] **Tidy Modules**: `go mod tidy`.

## 3. Build & Lint
- [ ] **Linters**: Run `golangci-lint run` and fix all issues.
- [ ] **API Generation**: Run `make api`.
- [ ] **Build**: Run `go build ./...` (clean build).
- [ ] **Wire Injection**: Run `make wire`.

## 4. Documentation
- [ ] **Service Docs**: Update `docs/03-services/operational-services/analytics-service.md`.
- [ ] **README**: Update `analytics/README.md`.

## 5. Security & Persistence (Team Lead Standards)
- [ ] **SQL Injection**: Use parameterized queries (GORM/raw).
- [ ] **Secrets**: No hardcoded secrets.
- [ ] **Transactions**: Use `InTx` for multi-step writes.
- [ ] **N+1 Queries**: Check for loops with database calls.

## 6. Release
- [ ] **Commit**: Conventional commits.
- [ ] **Tag**: Create tag if release (skip if just update).
- [ ] **Push**: Push to repository.