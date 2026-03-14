# AGENT-01: Location Service Hardening & Hierarchy Refactoring

> **Created**: 2026-03-14
> **Priority**: P0/P1/P2
> **Sprint**: Tech Debt Sprint
> **Services**: `location`
> **Estimated Effort**: 1-2 days
> **Source**: [Location Service Meeting Review](../../../../../.gemini/antigravity/brain/0c8b26af-f7f5-4879-9223-be0f13786d8f/location_service_review.md)

---

## 📋 Overview

Refactoring the Location Service based on the deep multi-agent review. The key improvements include removing the strictly hardcoded Vietnam-centric geographical hierarchy, fixing a critical synchronous cache invalidation blocker that affects create/update/delete performance, and tuning CTE query limits to prevent memory exhaustion on extremely large geographic tree data.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Decouple Geographical Hierarchy Validation ✅ IMPLEMENTED

**File**: `location/internal/biz/location/location_usecase.go`
**Lines**: 357-399
**Risk**: Global expansion requires flexible regional levels (e.g. omitting state/province level or adding completely novel types). A strict rule that `typeLevelMap[l.Type] == l.Level` and `parent.Level == child.Level - 1` breaks location creation for countries like Singapore.
**Problem**: The validation maps fixed location types to hardcoded integer levels and restricts the parent-child relationship to precisely one step apart.
**Fix**: Relax the validation. Check parent/child levels with a `>=` or `<` comparison rather than forcing exactly `- 1`.

```go
// BEFORE:
	validTypes := map[string]bool{
		"country":  true,
		"state":    true,
		"city":     true,
		"district": true,
		"ward":     true,
	}
	if !validTypes[l.Type] {
		errors = append(errors, fmt.Sprintf("invalid type: %s", l.Type))
	}

	// Validate level matches type
	typeLevelMap := map[string]int{
		"country":  0,
		"state":    1,
		"city":     2,
		"district": 3,
		"ward":     4,
	}
	expectedLevel := typeLevelMap[l.Type]
	if l.Level != expectedLevel {
		errors = append(errors, fmt.Sprintf("level %d does not match type %s (expected %d)", l.Level, l.Type, expectedLevel))
	}
// ...
				if parent.Level != l.Level-1 {
					errors = append(errors, fmt.Sprintf("parent level %d does not match expected level %d", parent.Level, l.Level-1))
				}

// AFTER:
	// Let types be more flexible. For a generic global system, we just ensure level logic holds.
	// We can still warn on unknown types, but won't strictly fail unless level rules are fundamentally broken.
	validTypes := map[string]bool{"country": true, "state": true, "city": true, "district": true, "ward": true}
	if !validTypes[l.Type] {
		warnings = append(warnings, fmt.Sprintf("unrecognized type: %s, proceed with caution", l.Type))
	}

	// For country, level must be 0
	if l.Type == "country" && l.Level != 0 {
	    errors = append(errors, "country level must be 0")
	} else if l.Type != "country" && l.Level <= 0 {
	    errors = append(errors, "non-country level must be greater than 0")
	}

	// Validate parent relationship
	if l.Type == "country" {
		if l.ParentID != nil {
			errors = append(errors, "country cannot have a parent")
		}
	} else {
		if l.ParentID == nil {
			errors = append(errors, "non-country location must have a parent")
		} else {
			// Validate parent exists and has lower level (e.g., country(0) can be parent of city(2))
			parent, err := uc.repo.GetByID(ctx, *l.ParentID)
			if err != nil {
				errors = append(errors, fmt.Sprintf("parent location not found: %s", *l.ParentID))
			} else {
				if parent.Level >= l.Level {
					errors = append(errors, fmt.Sprintf("parent level %d must be strictly less than child level %d", parent.Level, l.Level))
				}
				if parent.CountryCode != l.CountryCode {
					warnings = append(warnings, "parent country_code does not match location country_code")
				}
			}
		}
	}
```

**Validation**:
```bash
cd location && go test ./internal/biz/location -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Async Tree Cache Invalidation (Prevent Connection Block) ✅ IMPLEMENTED

**File**: `location/internal/biz/location/location_usecase.go`
**Function**: `invalidateTreeCache` (approx lines 224-235)
**Risk**: Redis `SCAN` combined with synchronous `Del` in a for loop blocks the API response. Running this loop inside the main HTTP/gRPC handler causes severe latency spikes and potential context timeouts.
**Problem**: Main application thread is forced to wait for all Redis tree keys to be discovered and deleted.
**Fix**: Break out the execution into an asynchronous Goroutine using `context.WithoutCancel`.

```go
// BEFORE:
func (uc *locationUsecase) invalidateTreeCache(ctx context.Context) {
	if uc.rdb == nil {
		return
	}
	iter := uc.rdb.Scan(ctx, 0, "location:tree:*", 100).Iterator()
	for iter.Next(ctx) {
		uc.rdb.Del(ctx, iter.Val())
	}
	if err := iter.Err(); err != nil {
		uc.log.WithContext(ctx).Warnf("failed to scan location tree cache keys: %v", err)
	}
}

// AFTER:
func (uc *locationUsecase) invalidateTreeCache(ctx context.Context) {
	if uc.rdb == nil {
		return
	}
	
	// Create a detached context so background task outlives request context
	bgCtx := context.WithoutCancel(ctx)
	
	go func() {
		// Use SCAN and batch pipeline or plain async delete for tree invalidation
		iter := uc.rdb.Scan(bgCtx, 0, "location:tree:*", 100).Iterator()
		for iter.Next(bgCtx) {
			uc.rdb.Del(bgCtx, iter.Val())
		}
		if err := iter.Err(); err != nil {
			uc.log.WithContext(bgCtx).Warnf("failed to scan location tree cache keys async: %v", err)
		}
	}()
}
```

**Validation**:
```bash
cd location && go build ./...
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 3: Restrict CTE Tree Fetch To Avoid Massive Payload Rams (OOM) ✅ IMPLEMENTED

**File**: `location/internal/data/postgres/location.go`
**Function**: `GetTree` (approx lines 186-215)
**Risk**: A database limit of `LIMIT 5000` could still load a massive JSON structural tree for large nations (e.g., India or US zipcodes), spiking the gRPC response byte-size and causing Out of Memory errors on edge containers.
**Problem**: Hardcoded `LIMIT 5000` within the recursive CTE.
**Fix**: Reduce limit to a safer `LIMIT 1500` or configure it via the request arguments realistically. Document frontend to switch to `GetChildren()` API for Lazy Loading instead of full Tree dump.

```go
// BEFORE:
		SELECT * FROM location_tree ORDER BY path LIMIT 5000;

// AFTER:
		SELECT * FROM location_tree ORDER BY path LIMIT 1500;
```

**Validation**:
```bash
cd location && go test ./internal/data/postgres/... -v
```

---

## 🔧 Pre-Commit Checklist

```bash
cd location && wire gen ./cmd/server/ ./cmd/worker/
cd location && go build ./...
cd location && go test -race ./...
cd location && golangci-lint run ./...
```

---

## 📝 Commit Format

```
refactor(location): harden tree structures and cache optimization

- refactor: allow flexible geographic tree validation (remove hardcoded levels)
- perf: switch redis tree cache invalidation to an asynchronous goroutine
- fix: lower cte tree limit to 1500 to prevent OOM killed

Closes: AGENT-01
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Level constraint relaxed | Creating a Singapore region `Level=1, Type=city` child beneath `Level=0, Type=country` works | ✅ |
| Invalidate cache is async | `invalidateTreeCache` does not block `CreateLocation` responses | ✅ |
| Query memory reduced | CTE returns up to max 1500 items, preserving Pod memory thresholds | ✅ |
