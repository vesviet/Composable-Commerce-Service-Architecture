# Search Service — Review Checklist
**Date**: 2026-02-25
**Reviewer**: AI Agent

---

## P1 Issues (High)

- [x] **[BUG]** `biz/sync_usecase.go:484` — `Refresh()` called after `performSync`
  targeted the alias `products_search` which does not exist yet during an initial sync
  (alias is wired only after `performSync` returns in `startNewSync`). This caused
  `index_not_found_exception [404]` on every initial sync.
  **Fix**: Added `RefreshIndex(ctx, indexName string)` to interface; `performSync` now
  calls `RefreshIndex(ctx, targetIndex)` on the concrete timestamped index.

## P2 Issues (Normal)

- [x] **[COMMENTS]** `biz/sync_usecase.go:424-429` — Six lines of stream-of-consciousness
  development notes ("Wait, I should…") left in production code, violating the 3-line
  comment rule. Removed and replaced with a concise 3-line rationale comment.

- [x] **[CONFIG DRIFT]** `configs/config.yaml` missing 4 event topics present in the
  authoritative gitops configmap: `catalog_category_deleted`, `promotions_promotion_created`,
  `promotions_promotion_updated`, `promotions_promotion_deleted`. Workers would silently
  not subscribe to these events in a local dev run.
  **Fix**: Added missing topics to `config.yaml`.

- [x] **[CONFIG DRIFT]** `configs/config.yaml` used flat `consul:` key structure but
  gitops configmap uses `registry.consul` nesting. Local dev would fail Consul registration.
  **Fix**: Changed to `registry.consul` to match configmap.

- [x] **[HYGIENE]** `bin/` directory (binaries `migrate`, `search`, `worker`) present in
  the repo—removed before commit.

## Architecture Notes

- Duplicate `IndexRepo` implementations exist: `internal/data/elasticsearch/product_index.go`
  (old) and `internal/data/elasticsearch/product/index.go` (new, canonical). Both are kept
  in sync as they satisfy the same interface. Consider consolidating in a future PR.

- The `SKIPPED - No applicable price` / `SKIPPED - No valid warehouse stock` debug/warn
  messages in the original logs are **expected behaviour** — products missing a price+inventory
  pair for a warehouse are intentionally excluded from the search index (un-sellable). These
  are not bugs.

## Cross-Service Impact

- Only `gateway` imports `search` proto (`v1.0.18`). Interface not changed.
- No event schema changes — additive only.

## Deployment Readiness

- [x] Ports match PORT_ALLOCATION_STANDARD.md (HTTP 8017, gRPC 9017)
- [x] ConfigMap `search-config` aligned with code — no new env vars added
- [x] Resource limits set (128Mi–512Mi, 100m–500m)
- [x] Health probes configured (liveness + readiness on port 8017)
- [x] Dapr annotations correct (`app-id: search`, `app-port: 8017`, `app-protocol: http`)
- [x] `bin/` removed before commit

## Build Status

- `golangci-lint`: ✅ 0 warnings
- `go build ./...`: ✅
- `bin/` Files: ✅ Removed
