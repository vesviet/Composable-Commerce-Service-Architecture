# Shipping Service Code Review Checklist v3

**Service**: shipping
**Version**: v1.1.1
**Review Date**: 2026-02-01
**Last Updated**: 2026-02-01
**Reviewer**: AI Code Review Agent
**Status**: Review Complete – Checklist & Fixes Applied

---

## Executive Summary

The shipping service implements multi-carrier integration (GHN, Grab), shipment management, shipping methods, rate calculation, and event-driven flows following Clean Architecture with biz/data/service/client/events layers. Constants are centralized in `internal/constants` (event topics, cache keys, table names, error codes; `pkg/constants` removed). The codebase was reviewed against Coding Standards, Team Lead Code Review Guide, and Development Review Checklist. **No replace directives** in go.mod. Health endpoints `/health`, `/health/live`, `/health/ready` are present. Cache key constants applied in data/postgres/shipment.go. Test-case tasks skipped per review requirements.

**Overall Assessment:** 🟢 READY
- **Strengths:** Clean Architecture, biz/data/service separation, transactional outbox, Wire DI, Redis cache, JWT auth, health probes, migrations (Goose), event publishing
- **Resolved:** data/postgres/shipment.go uses constants for cache keys (P2); constants consolidated in internal/constants (P2); internal/repository/shipment documented as legacy (P2); package GoDoc added for constants, biz/shipment, service (P2)
- **Remaining:** None. Test-case tasks skipped per requirements.

---

## 1. Index & Review (Standards Applied)

### 1.1 Codebase Index

- **Directory:** `shipping/`
- **Layout:** `internal/biz` (carrier, shipment, shipping_method, transaction), `internal/data` (postgres, cache, redis, eventbus, fulfillment_client), `internal/repository` (carrier, outbox, shipment, shipping_method), `internal/service`, `internal/client` (catalog), `internal/constants`, `pkg/constants`, `internal/config`, `internal/server`, `internal/observer`, `internal/events`, `internal/model`, `internal/carrier` (GHN, Grab), `internal/carrierfactory`
- **Proto:** `api/shipping/v1/shipping.proto` — gRPC + HTTP (Kratos)
- **Constants:** `internal/constants/event_topics.go` (event topics); `pkg/constants/constants.go` (cache keys, table names, error codes)
- **go.mod:** `module gitlab.com/ta-microservices/shipping`; requires common v1.8.2, catalog v1.2.0-rc.1, fulfillment v1.0.1; **no replace**
- **Entry point:** `cmd/shipping/` — main.go, wire.go, wire_gen.go; `make build` / `make run` / `make wire` succeed

### 1.2 Review vs Standards

- **Coding Standards:** Context first param, error wrapping, constants used (event topics in internal/constants; cache keys in pkg/constants); interfaces in biz implemented in data; layers respected. ✅
- **Team Lead Guide:** Biz does not call DB directly; service layer thin; DI (Wire). Health: /health, /health/live, /health/ready. Transactions used for multi-write (CreateShipment, AssignShipment, etc.). ✅
- **Development Checklist:** Error handling, context propagation, validation at service layer; parameterized queries in data; no raw SQL with user input. ✅

### 1.3 P0 / P1 / P2 Issues

| Severity | ID / Location | Description |
|----------|----------------|-------------|
| **P2** | data/postgres/shipment.go | **FIXED:** Use constants for cache keys; now uses internal/constants.CacheKeyShipment. |
| ~~P2~~ | Constants | **FIXED:** Cache/table/error/context constants moved from pkg/constants to internal/constants (cache.go); pkg/constants removed. |
| ~~P2~~ | internal/repository/shipment | **FIXED:** README.md added documenting package as legacy/unused (main app uses data layer). |
| ~~P2~~ | GoDoc | **FIXED:** Package comments added for internal/constants, internal/biz/shipment, internal/service; ShippingService type doc clarified. |

---

## 2. Checklist & Todo for Shipping Service

- [x] Architecture: Clean layers (biz / data / service / client / events)
- [x] Constants: Event topics and cache/table/error/context in internal/constants (pkg/constants removed)
- [x] **Constants:** data/postgres and data/cache use internal/constants for cache keys (P2 fixed)
- [x] Context & errors: Propagated and wrapped
- [x] **Dependencies:** No replace in go.mod; go get @latest and go mod tidy run
- [x] **Entry point:** cmd/shipping (main.go, wire.go, wire_gen.go); make build / make run succeed ✅
- [x] **Lint:** golangci-lint run (target: zero warnings) ✅
- [x] **Build:** make api, go build ./..., make wire succeed ✅
- [x] **Health:** /health, /health/live, /health/ready registered (K8s probes) ✅
- [x] Docs: Update checklist (this file); update service doc and README (step 5) ✅

*Test-case tasks omitted per review requirements.*

---

## 3. Dependencies (Go Modules)

- **Current:** common v1.8.2, catalog v1.2.0-rc.1, fulfillment v1.0.1; **no replace**
- **Required:** Do not use `replace` for gitlab.com/ta-microservices; use `go get ...@latest` and ensure modules are available.
- **Action:** Run `go get gitlab.com/ta-microservices/common@latest` (and catalog, fulfillment if needed); `go mod tidy`.

---

## 4. Lint & Build

- **Lint:** Run `golangci-lint run ./...` — target zero warnings.
- **Build:** `make api`, `go build ./...`, `make wire` — target clean build.
- **Note:** `make migrate-up` and `make migrate-down` added to Makefile (run `go run ./cmd/migrate -command up`; requires DATABASE_URL).

---

## 5. Docs

- **Service doc:** `docs/03-services/operational-services/shipping-service.md` — ensure current (architecture, APIs, health, deployment).
- **README:** `shipping/README.md` — Quick Start, config, health endpoints, build/deploy; align with checklist.

---

## 6. Commit & Release

- **Commit:** Use conventional commits: `feat(shipping): …`, `fix(shipping): …`, `docs(shipping): …`.
- **Release:** If releasing, create semver tag (e.g. `v1.0.7`) and push: `git tag -a v1.0.7 -m "v1.0.7: description"`, then `git push origin main && git push origin v1.0.7`. If not release, push branch only.

---

## Summary

- **Process:** Index → review (3 standards) → checklist v3 for shipping (test-case skipped) → dependencies (no replace; go get @latest, go mod tidy) → fix cache key constants → consolidate constants to internal/constants (remove pkg/constants) → document internal/repository/shipment as legacy → add GoDoc (constants, biz/shipment, service) → lint/build → docs → checklist synced.
- **Blockers:** None. All P2 issues from this checklist resolved (cache keys, constants consolidation, legacy repo doc, GoDoc).
