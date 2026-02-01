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

### ⏳ PENDING ITEMS (Post-Release)
- [ ] **[P1] Complex BatchUpdate**: Improve implementation if SQL performance becomes an issue.
- [ ] **[P2] In-Memory Idempotency**: Migrate to Redis for multi-replica support.
- [ ] **[P2] Memory Efficiency**: Consider streaming for extremely large bulk updates.
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
