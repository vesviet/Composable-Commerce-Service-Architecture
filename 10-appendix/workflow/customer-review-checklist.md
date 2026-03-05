# Customer Service Review Checklist

**Date**: 2026-03-05
**Reviewer**: Automated Review (Antigravity Agent)
**Version**: v1.2.6

---

## 🔧 Action Plan for customer

### P0 Fixes (implement now)
| # | Issue | File:Line | Root Cause | Fix Description | Status |
|---|-------|-----------|------------|-----------------|--------|
| 1 | Transaction bypass in customerRepo | `data/postgres/customer.go:72-110` | `BaseRepository.GetDB()` uses `ctx.Value("tx")` string key, but customer's `NewTransaction` stores TX via `transactionKey{}` struct key — key mismatch causes all CRUD to run outside transaction | Replaced all 5 baseRepo CRUD methods with direct `getDB(ctx)` calls that correctly participate in transaction context via `ExtractTx` | ✅ Done |

### P1 Fixes (implement now if time allows)
_None found._

### P2 Notes (document only)
| # | Issue | File:Line | Description |
|---|-------|-----------|-------------|
| 1 | Unused baseRepo field | `data/postgres/customer.go:22` | Removed after P0 fix — dead field and import |
| 2 | Service layer tests | `internal/service/` | 0% coverage — 12 handler files with no tests |
| 3 | Data layer tests | `internal/data/postgres/` | 0% coverage — 14 repo files with no tests |

---

## Pre-Review
- [x] Pulled latest code (service, common, gitops)
- [x] Identified service name and structure (dual-binary: customer + worker)

## Code Review
- [x] Indexed codebase (cmd/, internal/, api/, migrations/)
- [x] Reviewed against coding standards
- [x] Listed P0/P1/P2 issues with file:line references
- [x] Checked cross-service impact (proto: 10 consumers, events: 0 consumers)
- [x] Verified config/GitOps alignment (ports 8003/9003)

## Action & Testing
- [x] Created action plan for P0/P1 issues
- [x] Implemented bug fixes (P0 transaction bypass)
- [x] Ran test coverage check
- [x] Updated TEST_COVERAGE_CHECKLIST.md

## Dependencies
- [x] Checked common — no uncommitted changes
- [x] No replace directives found
- [x] Updated common v1.23.0 → v1.23.1

## Build & Quality
- [ ] Generated proto (make api) — N/A, no proto changes
- [ ] Regenerated Wire — N/A, no DI changes
- [x] golangci-lint run (0 warnings)
- [x] go build ./... (clean)
- [x] go test ./... (8/8 packages pass)

## Deployment
- [x] Verified port allocation matches standard (8003/9003)
- [x] Health probes configured via common-deployment-v2 component
- [x] Resource limits set (128Mi-512Mi / 100m-500m)
- [x] HPA configured
- [x] Migration job configured (24 migrations)

## Documentation
- [x] README.md updated (v1.2.6)
- [x] CHANGELOG.md updated (v1.2.6 entry)
- [x] bin/ directory clean

## Release
- [ ] Committed with conventional format — awaiting user approval
- [ ] Tagged version — awaiting user approval
- [ ] Pushed to remote — awaiting user approval
