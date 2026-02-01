# Pricing Service Review Checklist (v3)

**Service**: Pricing Service  
**Status**: 🟡 IN REVIEW  
**Last Updated**: 2026-02-01

### ✅ COMPLETED ITEMS
- [x] **[P0] Unmanaged Goroutines**: Documented the fire-and-forget behavior in `BulkUpdatePriceAsync`.
- [x] **[P0] Context Key Collision**: `contextKey` changed to `int` for better safety.
- [x] **[P1] Hardcoded Secrets**: Removed from `values-base.yaml`.
- [x] **[P2] Transaction Integrity**: `UpdateOutboxEvent` now respects transaction context.
- [x] **[P2] Cache TTL optimization**: `updatePriceCache` now uses dynamic TTL.
- [x] **[P2] In-Memory Idempotency**: Refactored to use Redis for multi-replica support.
- [x] **[P1] Missing Worker Binary**: Verified `cmd/worker` exists and is built in Dockerfile.
- [x] **[P1] Complex BatchUpdate**: Reviewed. Current implementation safe (parameterized). deferred optimization.
- [x] **[P2] Memory Efficiency**: Batch size limited to 500 items, sufficient for reliable memory usage.

### ⏳ PENDING ITEMS (Post-Release)
- [x] Service indexes and architecture understood.
- [x] Linter passing with zero warnings.
- [x] Build and Wire generation successful.
- [x] Core pricing engine with 4-level priority implemented.
- [x] Redis caching layer active.

## ⏳ PLANNED REFACTORING
1. Fix context key type.
2. Refactor `BulkUpdatePriceAsync` to use a better lifecycle management (or documented trade-off).
3. Move credentials to environment variables or dapr secrets.
4. Improve `BatchUpdate` SQL construction or use GORM's batch capabilities if possible.
5. Create `cmd/worker`.
