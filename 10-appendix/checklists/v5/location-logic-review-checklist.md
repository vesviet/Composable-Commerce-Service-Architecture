# Location Service Business Logic Review Checklist

> **Service**: `location/` — Hierarchical location tree management (Country → State → City → District → Ward)  
> **Reviewed**: 2026-02-18 | **Reviewer**: AI Senior Architect  
> **Benchmark**: Shopify (address validation), Shopee (region tree), Lazada (logistics zone management)

---

## 1 — Data Consistency Between Services

### 1.1 Outbox Pattern — Write Side ✅ (Implemented Correctly)

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| DC-01 | `CreateLocation` wraps repo + outbox in single DB transaction | ✅ Pass | [location_usecase.go:74-95](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L74-L95) — `uc.tm()` wraps both calls |
| DC-02 | `UpdateLocation` wraps repo + outbox in single DB transaction | ✅ Pass | [location_usecase.go:133-156](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L133-L156) |
| DC-03 | Outbox repo respects transaction context via `ExtractTx()` | ✅ Pass | [outbox.go:34-37](file:///d:/microservices/location/internal/data/postgres/outbox.go#L34-L37) |
| DC-04 | Outbox table has proper schema with retry fields | ✅ Pass | [003_create_outbox_table.sql](file:///d:/microservices/location/migrations/003_create_outbox_table.sql) — `retries`, `max_retries`, `next_retry_at`, `last_error` |
| DC-05 | DB-level CHECK constraints enforce hierarchy rules | ✅ Pass | [001_create_locations_table.sql:26-36](file:///d:/microservices/location/migrations/001_create_locations_table.sql#L26-L36) |

### 1.2 Outbox Pattern — Publish Side ❌ (Missing)

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| DC-06 | **No outbox worker/publisher exists** — events are written to `outbox_events` table but **never polled or published** to any message bus | 🔴 P0 | No cron job, no worker binary, no Dapr publisher found anywhere in the codebase. The entire outbox pipeline is write-only — a dead-letter table |
| DC-07 | **No `location.deleted` event emitted** — `Delete` is not wrapped in a transaction and does not write to the outbox | 🟡 P1 | [location_usecase.go](file:///d:/microservices/location/internal/biz/location/location_usecase.go) — no `DeleteLocation` method with outbox; the repo `Delete` is called directly from the service layer |
| DC-08 | `ServiceClients` (user, warehouse, shipping) are wired but **never used** in any business logic | 🟢 P2 | [service_clients.go](file:///d:/microservices/location/internal/client/service_clients.go) — clients created but no consumer code references them |

> [!CAUTION]
> **Critical gap**: The outbox table exists and events are written transactionally (good architecture), but without a worker to poll and publish, **no downstream service ever receives location change events**. Shopify, Shopee, and Lazada all pair outbox writes with a dedicated outbox relay worker. This is the highest-priority fix for this service.

### 1.3 Cache Consistency

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| DC-09 | `CreateLocation` does **not invalidate** tree cache or individual location cache. If a new child is added under a cached parent, the parent's cached `Children` array is stale for up to 24 hours | 🟡 P1 | [location_usecase.go:45-102](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L45-L102) | 96-101 |
| DC-10 | `UpdateLocation` invalidates individual cache + tree cache, but does **not invalidate parent's cache** — parent's cached `Children` array still shows old child data | 🟡 P1 | [location_usecase.go:162-164](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L162-L164) | 163-164 |
| DC-11 | `invalidateTreeCache` uses `SCAN` with pattern `location:tree:*` limit 100. If >100 tree cache keys exist, **only first 100 are invalidated** — remaining serve stale data | 🟡 P1 | [location_usecase.go:212-223](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L212-L223) | 216 |
| DC-12 | Cache TTL is 24 hours. Location data is mostly static, but during bulk imports (seed scripts), stale cache can cause significant inconsistency | 🟢 P2 | [location_usecase.go:197](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L197) | 197 |

---

## 2 — Data Mismatch Cases

### 2.1 Dual Validation — Validator vs UseCase

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| MM-01 | `CreateLocation` uses `LocationValidator.ValidateCreateLocation()` which checks structure only (required fields, type, hierarchy rules, coordinates, postal codes, metadata) — but does **not verify parent exists in DB** | 🔴 P0 | [validator.go:20-46](file:///d:/microservices/location/internal/biz/location/validator.go#L20-L46) — hierarchy check validates *structure* (country has no parent, others have parent) but never calls `repo.GetByID(parentID)` to confirm parent actually exists |
| MM-02 | `ValidateLocation` (the public API endpoint) **does** verify parent exists in DB and checks parent level + country code — but this is a **separate code path** not called during create/update | 🟡 P1 | [location_usecase.go:319-394](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L319-L394) — two different validation implementations with different rigor |
| MM-03 | `ValidateUpdateLocation` simply calls `ValidateCreateLocation` after checking ID — no check for **immutable fields** (type, level, country_code should not change for existing locations) | 🟡 P1 | [validator.go:49-55](file:///d:/microservices/location/internal/biz/location/validator.go#L49-L55) |

### 2.2 Proto Conversion Edge Cases

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| MM-04 | `toBizLocation` treats `Latitude == 0` as "not set" — locations at the equator (latitude 0°) are silently dropped | 🟡 P1 | [service/location.go:370-374](file:///d:/microservices/location/internal/service/location.go#L370-L374) — `if l.Latitude != 0 { loc.Latitude = &l.Latitude }` |
| MM-05 | `toBizLocation` treats `Longitude == 0` the same way — the prime meridian (0° longitude) locations cannot be represented | 🟡 P1 | Same file, line 373 |
| MM-06 | `fromProtoLocationType` returns empty string `""` for `UNSPECIFIED` — this empty string can bypass type validation if not caught | 🟢 P2 | [service/location.go:415-417](file:///d:/microservices/location/internal/service/location.go#L415-L417) |

### 2.3 Model Layer Mismatch

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| MM-07 | `model.Location.PostalCodes` is `datatypes.JSON` but domain `Location.PostalCodes` is `[]string` — JSON marshal/unmarshal errors in `toBizLocation` are **silently swallowed** with `_ = json.Unmarshal()` | 🟢 P2 | [data/postgres/location.go:315](file:///d:/microservices/location/internal/data/postgres/location.go#L315) |
| MM-08 | Same pattern for `Metadata` — unmarshal errors silently ignored | 🟢 P2 | [data/postgres/location.go:320](file:///d:/microservices/location/internal/data/postgres/location.go#L320) |

---

## 3 — Retry / Rollback / Saga / Outbox

### 3.1 Transaction Management ✅ (Well-Implemented)

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| RR-01 | Transaction manager uses GORM `Transaction()` with context propagation | ✅ Pass | [transaction.go:13-19](file:///d:/microservices/location/internal/data/postgres/transaction.go#L13-L19) |
| RR-02 | Transaction key stored in context, extracted by repos | ✅ Pass | [transaction.go:22-28](file:///d:/microservices/location/internal/data/postgres/transaction.go#L22-L28) |
| RR-03 | Outbox events rolled back if location creation fails | ✅ Pass | Both writes inside `uc.tm()` closure |

### 3.2 Outbox Retry Infrastructure

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| RR-04 | Outbox table has `retries`, `max_retries`, `next_retry_at` columns — but **no code reads these fields**. The `OutboxRepository` interface has only `Create()` — no `GetUnpublished()`, `MarkPublished()`, `IncrementRetry()` methods | 🔴 P0 | [outbox.go:23-25](file:///d:/microservices/location/internal/biz/location/outbox.go#L23-L25) — interface too narrow |
| RR-05 | No **dead-letter handling** — if max_retries is exceeded, events are stuck in the table forever with no cleanup or alerting | 🟡 P1 | Schema supports it but no code implements it |
| RR-06 | No **outbox cleanup** — old published events accumulate indefinitely. No retention policy or archival | 🟡 P1 | No cron job for cleanup |

### 3.3 Delete Rollback

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| RR-07 | DB schema uses `ON DELETE CASCADE` — deleting a country **cascade-deletes all children** (states, cities, districts, wards). This is intentional but **extremely dangerous** with no soft-delete guard at the API level | 🔴 P0 | [001_create_locations_table.sql:13](file:///d:/microservices/location/migrations/001_create_locations_table.sql#L13) |
| RR-08 | GORM `Delete()` uses soft-delete (`deleted_at`), but the FK CASCADE operates on the actual row — **soft-deleted children are NOT cascade-affected**. This creates inconsistency: parent soft-deleted but children still active | 🟡 P1 | [data/postgres/location.go:271-273](file:///d:/microservices/location/internal/data/postgres/location.go#L271-L273) — `db.Delete()` sets `deleted_at`, but CASCADE only fires on hard DELETE |
| RR-09 | `DeleteLocation` does not check if location has children before allowing deletion — no confirmation or warning | 🟡 P1 | UseCase has no `Delete` method — repo `Delete` called directly |

> [!WARNING]
> **Soft-delete + ON DELETE CASCADE mismatch**: GORM soft-delete sets `deleted_at` timestamp (no actual row deletion occurs), so the `ON DELETE CASCADE` FK constraint **never fires**. This means soft-deleting a parent leaves all children as active records pointing to a soft-deleted parent → **orphaned children**. Either remove CASCADE (since soft-delete is primary) or add application-level cascade soft-delete.

---

## 4 — Edge Cases & Risk Points

### 4.1 SQL Injection Vulnerabilities

| # | Issue | Severity | File | Line |
|---|-------|----------|------|------|
| EC-01 | **ORDER BY injection**: `filter.SortBy` is directly concatenated into SQL — `Order(sortBy + " " + sortOrder)`. Attacker can inject: `"name; DROP TABLE locations--"` | 🔴 P0 | [data/postgres/location.go:108](file:///d:/microservices/location/internal/data/postgres/location.go#L108) | 108 |
| EC-02 | **LIKE wildcard injection**: Search query uses `"%"+query+"%"` without escaping `%` and `_` characters. Attacker can craft patterns that cause expensive full-table scans | 🟡 P1 | [data/postgres/location.go:242](file:///d:/microservices/location/internal/data/postgres/location.go#L242) | 242 |
| EC-03 | `filter.SortOrder` is also unvalidated — should be restricted to `"asc"` or `"desc"` only | 🟡 P1 | [data/postgres/location.go:101-104](file:///d:/microservices/location/internal/data/postgres/location.go#L101-L104) | 101-104 |

> [!CAUTION]
> **Shopify/Shopee pattern**: Both platforms whitelist allowed sort columns (`name`, `code`, `created_at`) and validate sort direction. They **never** concatenate user input into ORDER BY. This is a critical security fix.

### 4.2 Performance Issues

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-04 | `GetAncestors` uses **N+1 recursive queries** — for a ward (level 4), it makes 5 DB round-trips (ward → district → city → state → country). Should use a single recursive CTE like `GetTree` does | 🟡 P1 | [data/postgres/location.go:144-165](file:///d:/microservices/location/internal/data/postgres/location.go#L144-L165) |
| EC-05 | `GetByID` always `Preload("Parent").Preload("Children")` — fetches parent + all children even when only the location itself is needed. For a country with 63 states, this loads 64 records for a single lookup | 🟡 P1 | [data/postgres/location.go:44](file:///d:/microservices/location/internal/data/postgres/location.go#L44) |
| EC-06 | `List` also `Preload("Parent").Preload("Children")` for every result — listing 20 locations loads 20 parents + 20×N children. For a page of states this is O(n²) | 🟡 P1 | [data/postgres/location.go:106](file:///d:/microservices/location/internal/data/postgres/location.go#L106) |
| EC-07 | `GetChildren` has **no LIMIT** — a country with thousands of children returns them all in one query | 🟡 P1 | [data/postgres/location.go:121-142](file:///d:/microservices/location/internal/data/postgres/location.go#L121-L142) |
| EC-08 | `SearchLocations` has no max limit enforcement — usecase caps to 20 default but never rejects excessively large limits | 🟢 P2 | [location_usecase.go:312-313](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L312-L313) |
| EC-09 | Recursive CTE in `GetTree` has safety limit of 100 depth — but trees are max 5 levels. The real concern is **width** (thousands of children at each level). No result set size limit | 🟢 P2 | [data/postgres/location.go:193](file:///d:/microservices/location/internal/data/postgres/location.go#L193) |

### 4.3 Hierarchy Integrity

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-10 | `CreateLocation` validator checks hierarchy structure but **does not verify parent exists in DB** — can create a child pointing to non-existent parent UUID (DB FK will catch this but returns raw error instead of friendly message) | 🔴 P0 | [validator.go:120-153](file:///d:/microservices/location/internal/biz/location/validator.go#L120-L153) — checks level/type rules but not parent existence |
| EC-11 | No **circular reference prevention** — if parent_id is corrupted to point to self or a descendant, `GetAncestors` enters an infinite loop | 🟡 P1 | [data/postgres/location.go:154-162](file:///d:/microservices/location/internal/data/postgres/location.go#L154-L162) — `for current.ParentID != nil` has no depth guard |
| EC-12 | `UpdateLocation` allows changing `ParentID` — can **move** a location to a different branch without validating the new parent's level/type compatibility | 🟡 P1 | [location_usecase.go:104-167](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L104-L167) — validator doesn't check parent-new compatibility |
| EC-13 | No check preventing **moving a parent under its own children** (creating a cycle in the tree) | 🟡 P1 | Need to verify path from new parent to root doesn't include the node being moved |

### 4.4 Concurrency & Edge Cases

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-14 | `UpdateLocation` does `Get` → validate → `Update` without row-level locking. Concurrent updates can overwrite each other (last-write-wins) | 🟡 P1 | [location_usecase.go:106-137](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L106-L137) |
| EC-15 | `UpdateLocation` re-reads location inside transaction (`GetByID` on line 154) — this read is inside the tx but the first read (line 106) is **outside** the transaction. Stale data may be used for validation | 🟡 P1 | [location_usecase.go:106 vs 154](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L106) |
| EC-16 | Cache invalidation happens **after** transaction commits (lines 163-164) — if Redis fails, cache serves stale data but operation succeeds. This is acceptable (eventual consistency) but should be documented | 🟢 P2 | [location_usecase.go:162-164](file:///d:/microservices/location/internal/biz/location/location_usecase.go#L162-L164) |

### 4.5 Error Handling & Defined Errors Usage

| # | Issue | Severity | Description |
|---|-------|----------|-------------|
| EC-17 | Eight sentinel errors defined in `errors.go` but only `ErrLocationNotFound` is actually used in code. `ErrDuplicateCode`, `ErrInvalidHierarchy`, `ErrLocationNotEditable` etc. are **never returned** | 🟢 P2 | [errors.go:6-16](file:///d:/microservices/location/internal/biz/location/errors.go#L6-L16) |
| EC-18 | Validator returns `fmt.Errorf()` raw strings instead of using sentinel errors — prevents `errors.Is()` matching in error handlers | 🟡 P1 | [validator.go](file:///d:/microservices/location/internal/biz/location/validator.go) — all validation errors are raw `fmt.Errorf` |
| EC-19 | `mapError` in service layer handles all 8 sentinel errors correctly — but since validators never return them, only `ErrLocationNotFound` actually triggers. All other validation errors fall through to `INTERNAL_ERROR` | 🟡 P1 | [service/location.go:421-456](file:///d:/microservices/location/internal/service/location.go#L421-L456) |

---

## 5 — Summary of Findings by Severity

### 🔴 P0 — Critical (Must Fix)

| # | Finding | Root Cause |
|---|---------|-----------|
| DC-06 | Outbox events written but never published | No outbox worker exists |
| RR-04 | OutboxRepository too narrow — no read/publish methods | Incomplete interface |
| RR-07 | CASCADE DELETE on parent can wipe entire subtree | Dangerous FK constraint |
| EC-01 | SQL injection via ORDER BY concatenation | Unsanitized user input |
| EC-10 | Parent existence not verified during create | Validator checks structure only |
| MM-01 | Validator doesn't check if parent exists in DB | Missing DB lookup in validation |

### 🟡 P1 — High (Should Fix)

| # | Finding | Root Cause |
|---|---------|-----------|
| DC-07 | No `location.deleted` event emitted | Delete bypasses outbox |
| DC-09/10 | Cache not invalidated on create; parent cache stale on update | Missing invalidation calls |
| DC-11 | SCAN limit 100 may miss cache keys | Hardcoded cursor limit |
| MM-02/03 | Dual validation paths with different rigor; immutable field changes allowed | DRY violation |
| MM-04/05 | Lat/Long 0° treated as "not set" | Proto3 zero-value confusion |
| RR-05/06 | No dead-letter handling or outbox cleanup | Missing worker logic |
| RR-08/09 | Soft-delete + CASCADE mismatch; no children check | Architecture conflict |
| EC-02/03 | LIKE wildcard + sort order injection | Unsanitized input |
| EC-04/05/06/07 | N+1 ancestors, eager Preload everywhere, no LIMIT on GetChildren | Performance anti-patterns |
| EC-11/12/13 | Infinite loop risk, parent move without validation, cycle creation | Missing hierarchy guards |
| EC-14/15 | Read-then-write race condition, stale validation data | No row-level locking |
| EC-18/19 | Raw fmt.Errorf instead of sentinel errors → wrong HTTP codes | Error type mismatch |

### 🟢 P2 — Medium (Nice to Have)

| # | Finding |
|---|---------|
| DC-08 | ServiceClients wired but unused |
| DC-12 | 24h cache TTL may cause stale data during bulk imports |
| EC-08/09 | Search limit not capped, tree result set unbounded |
| EC-16 | Cache invalidation after tx — acceptable eventual consistency |
| EC-17 | 7 of 8 sentinel errors unused |
| MM-06 | `UNSPECIFIED` maps to empty string |
| MM-07/08 | JSON unmarshal errors silently swallowed |

---

## 6 — Recommended Fixes (Prioritized)

### Phase 1: Security & Data Integrity (P0)

```diff
// 1. Fix SQL injection in ORDER BY
func (r *locationRepo) List(ctx context.Context, filter *bizLocation.Filter) ([]*bizLocation.Location, int64, error) {
+   // Whitelist allowed sort columns
+   allowedSorts := map[string]bool{"name": true, "code": true, "level": true, "sort_order": true, "created_at": true}
+   sortBy := "sort_order"
+   if filter.SortBy != "" && allowedSorts[filter.SortBy] {
+       sortBy = filter.SortBy
+   }
+   sortOrder := "asc"
+   if filter.SortOrder == "desc" {
+       sortOrder = "desc"
+   }

// 2. Verify parent exists during CreateLocation
func (v *LocationValidator) ValidateCreateLocation(ctx context.Context, l *Location, repo Repository) error {
+   if l.ParentID != nil && *l.ParentID != "" {
+       parent, err := repo.GetByID(ctx, *l.ParentID)
+       if err != nil { return ErrInvalidParent }
+       if parent.Level != l.Level-1 { return ErrInvalidHierarchy }
+       if parent.CountryCode != l.CountryCode { return ErrInvalidHierarchy }
+   }

// 3. Add depth guard to GetAncestors
func (r *locationRepo) GetAncestors(ctx context.Context, id string) ([]*bizLocation.Location, error) {
+   const maxDepth = 10  // Safety: location tree is max 5 levels
    current := location
-   for current.ParentID != nil {
+   for current.ParentID != nil && len(ancestors) < maxDepth {
```

### Phase 2: Outbox Worker

```
// Add to OutboxRepository interface:
+ GetUnpublished(ctx context.Context, limit int) ([]*OutboxEvent, error)
+ MarkPublished(ctx context.Context, id string) error
+ IncrementRetry(ctx context.Context, id string, lastError string) error
+ CleanPublished(ctx context.Context, olderThan time.Duration) error

// Create worker/cron/outbox_publisher.go:
// - Poll outbox_events WHERE published_at IS NULL AND (next_retry_at IS NULL OR next_retry_at <= NOW())
// - Publish to Dapr PubSub topic "location-events"
// - Mark as published on success
// - Increment retry + set next_retry_at with exponential backoff on failure
// - Skip events where retries >= max_retries (dead letter)
```

### Phase 3: Cache & Hierarchy Fixes

- Invalidate tree cache + parent cache on `CreateLocation`
- Add cycle detection on `UpdateLocation` when `ParentID` changes
- Fix SCAN cursor to iterate all keys (not just first 100)
- Replace eager `Preload` with lazy loading or explicit opt-in
- Use recursive CTE for `GetAncestors` (matching `GetTree` pattern)

---

## 7 — Comparison with Industry Patterns

| Pattern | Shopify | Shopee | Lazada | Location |
|---------|---------|--------|--------|----------|
| Transactional outbox writes | ✅ | ✅ | ✅ | ✅ **Correct** |
| Outbox worker/relay | ✅ Polling | ✅ CDC | ✅ Debezium | ❌ **Missing** |
| Sort column whitelist | ✅ | ✅ | ✅ | ❌ Raw concat |
| Parent existence check | ✅ | ✅ FK + app | ✅ | ❌ Structure only |
| Cycle detection | ✅ Path check | ✅ | ✅ CTE | ❌ None |
| Optimistic concurrency | ✅ Version col | ✅ | ✅ | ❌ Last-write-wins |
| Eager vs lazy loading | ✅ Configurable | ✅ | ✅ | ❌ Always eager |
| Cache invalidation on writes | ✅ All mutations | ✅ | ✅ | ⚠️ Partial (no create) |
| Soft-delete cascade | ✅ App-level | ✅ | ✅ | ❌ FK CASCADE conflict |
| Sentinel error usage | ✅ Typed errors | ✅ | ✅ | ⚠️ Defined but unused |
| Search input sanitization | ✅ | ✅ Escaped | ✅ | ❌ Raw LIKE |

---

## 8 — Test Coverage Assessment

| Layer | File | Tests | Coverage Notes |
|-------|------|-------|---------------|
| Usecase | `location_usecase_test.go` | 565 lines, 8 test functions | ✅ Good: covers create, get, list, tree, path, search, validate, children, ancestors. ⚠️ Missing: update, delete, error cases, cache behavior |
| Data | `location_test.go` | 399 lines, 9 test functions | ✅ Good: SQLite-based integration tests covering CRUD, list, search, tree, ancestors. ⚠️ Missing: outbox repo tests, concurrent access tests |
| Service | `location_test.go` | 557 lines, 12 test functions | ✅ Good: all API endpoints tested with mocks, proto conversion tests. ⚠️ Missing: error mapping edge cases, input validation |

> **Overall**: Test coverage is well-structured with table-driven tests and proper mock patterns. Key gap: no tests for concurrent updates, cache invalidation, or outbox publishing.

---

**Status**: ⏳ Review complete — awaiting implementation of fixes
