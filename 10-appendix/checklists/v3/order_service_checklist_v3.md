# Order Service Code Review Checklist v3

**Service**: order
**Version**: (see go.mod)
**Review Date**: 2026-01-30
**Last Updated**: 2026-01-30
**Reviewer**: AI Code Review Agent
**Status**: Review Complete – Build Issues Documented (P1)

---

## Executive Summary

The order service implements order lifecycle management (cart, checkout, order, cancellation, status, validation, order edit) following Clean Architecture with biz/data/service/client/events layers. Constants are centralized in `internal/constants`. The codebase was reviewed against Coding Standards, Team Lead Code Review Guide, and Development Review Checklist. **Build currently fails** due to type alignment with the common package; go.mod uses `replace` directives (per standard should use `go get`). Test-case tasks skipped per review requirements.

**Overall Assessment:** 🟡 NEEDS ATTENTION
- **Strengths:** Clean Architecture, centralized constants, event-driven (Dapr), outbox pattern, multi-domain biz layer
- **P1 Issues:** Build failures (struct field/type mismatches with common), go.mod replace directives
- **Priority:** Fix build and remove replace before release

---

## 1. Index & Review (Standards Applied)

### 1.1 Codebase Index

- **Directory:** `order/`
- **Layout:** `internal/biz` (cancellation, order_edit, status, validation), `internal/data` (postgres, eventbus, grpc_client), `internal/service`, `internal/client`, `internal/events`, `internal/constants`, `internal/repository`, `internal/model`, `internal/server`, `internal/middleware`, `internal/security`, `internal/observability`
- **Proto:** No `api/*.proto` in repo (API_PROTO_FILES empty); references in CODEBASE_INDEX point to `api/order/v1/*.proto` (not present in tree)
- **Constants:** `internal/constants/constants.go` – event topics, cache keys, status strings, TTLs, saga state
- **go.mod:** `gitlab.com/ta-microservices/order`, requires `common v1.8.5`, **replace** for `common` and `payment`

### 1.2 Review vs Standards

- **Coding Standards:** Context first param, error wrapping, constants used (no magic strings in constants), interfaces in biz implemented in data, layers respected. ✅
- **Team Lead Guide:** Biz does not call DB directly; service layer thin; DI (Wire). **Build broken** – see P1. ✅/⚠️
- **Development Checklist:** Error handling, context propagation, validation, security (input sanitization, PII masker present). ✅

### 1.3 P0 / P1 / P2 Issues

| Severity | ID / Location | Description |
|----------|----------------|-------------|
| **P1** | Build | `go build ./...` fails: struct field/type mismatches with `common/services` types (PaymentRequest, PaymentVoidRequest, PaymentCaptureRequest, PaymentRefundRequest, ShippingRateRequest, ShippingRate, Address). Code uses fields that may not exist in the resolved common version (e.g. `biz.Address` undefined, `Reason`/`OrderID`/`Metadata` unknown on request types, `Origin`/`Destination`/`Item.Price` in shipping client). |
| **P1** | go.mod | ~~Replace directives removed.~~ After `go mod tidy` and `go mod vendor`, build fails in **common** package: `EventPublisherFactory` / `NewEventPublisherFactory` redeclared in `common/events`. Resolve by fixing common or using a common tag that builds. |
| **P2** | Docs | Ensure `docs/03-services/core-services/order-service.md` and `order/README.md` match current setup and checklist. |

---

## 2. Checklist & Todo for Order Service

- [x] Architecture: Clean layers (biz / data / service / client / events)
- [x] Constants: Centralized in `internal/constants`
- [x] Context & errors: Propagated and wrapped
- [ ] **Build:** Fix compile errors (align with common package types or pin common version that matches)
- [ ] **Dependencies:** Remove `replace` in go.mod; use `go get gitlab.com/ta-microservices/common@<tag>`, `go mod tidy`
- [ ] **Lint:** Run `golangci-lint run` in `order/` and fix issues (blocked by build)
- [ ] **API:** Run `make api` if proto present; `go build ./...`; `make wire` if DI changed
- [x] Docs: Update checklist (this file); update service doc and README (see step 5)

*Test-case tasks omitted per review requirements.*

---

## 3. Dependencies (Go Modules)

- **Current:** `common v1.8.5`; **replace directives removed**; `go mod tidy` and `go mod vendor` run.
- **Required:** Do not use `replace` for gitlab.com/ta-microservices; use `go get ...@<tag>`.
- **Status:** Replace removed. Build currently fails in **common** (events package redeclaration). Once common builds, order may still need type alignment (PaymentRequest, ShippingRateRequest, biz.Address, etc.).

---

## 4. Lint & Build

- **Lint:** Run `golangci-lint run` in `order/` – deferred until build succeeds.
- **Build:** `go build ./...` – **currently fails** (see P1).
- **Commands:** `make api` (if proto changed), `go build ./...`, `make wire` (if DI changed). Target: zero lint warnings, clean build.

---

## 5. Docs

- **Service doc:** `docs/03-services/core-services/order-service.md` – update to match code and this checklist (e.g. build status, dependency note).
- **README:** `order/README.md` – update setup, run, config, troubleshooting to match code and checklist.

---

## 6. Commit & Release

- **Commit:** Use conventional commits: `feat(order): …`, `fix(order): …`, `docs(order): …`.
- **Release:** If releasing, create semver tag (e.g. `v1.0.7`) and push: `git tag -a v1.0.7 -m "v1.0.7: description"`, then `git push origin main && git push origin v1.0.7`. If not release, push branch only.

---

## Summary

- **Process:** Index → review (3 standards) → checklist v3 for order (test-case skipped) → dependencies (remove replace, go get) → lint/build (blocked by build) → docs (03-services + README) → commit → tag if release → push.
- **Blockers:** Build failures (P1) and go.mod replace (P1). Resolve type alignment with common and remove replace before considering release.
