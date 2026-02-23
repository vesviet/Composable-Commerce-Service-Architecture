# 🚚 SHIPPING & SEARCH SERVICE REFACTOR PLAN

**Date**: 2026-01-25
**Status**: Analysis Complete
**Ref**: `docs/TEAM_LEAD_CODE_REVIEW_GUIDE.md`

## 📊 EXECUTIVE SUMMARY

### Shipping Service
The Shipping service has **successfully addressed its critical P0 security and atomicity issues**. The code now consistently encrypts credentials and uses transactions for shipment creation. The next major phase is **Testing** (currently near 0% coverage) and implementing **Real Carrier Integrations**.

### Search Service
The Search service is performant and well-structured with **async analytics** and **batch visibility checks**. Key improvements needed are mostly architectural refinements (moving logic from Service to Usecase) and reliability assurance (shutdown hooks, tests).

---

## 🏗️ SHIPPING SERVICE STATUS

### ✅ RESOLVED / VERIFIED FIXED
- **[SECURITY] Credential Encryption**: `EncryptedJSONB` implemented with `crypto.EncryptPBKDF2GCM`.
- **[ATOMICTY] Transaction Management**: `CreateShipment` uses `uc.tx.WithTransaction` to atomicize DB insert and Outbox event.

### 🚩 PENDING ACTIONS (from Review)

#### 1. 🚨 **[P0] Testing Gap**
- **Current**: ~0% coverage.
- **Action**: Implement Unit/Integration tests for `ShipmentUseCase`.
    - `TestCreateShipment_Success`
    - `TestCreateShipment_InvalidInput`
    - `TestUpdateStatus_ValidTransition`

#### 2. 🟡 **[P1] Service Layer Implementation**
- **Current**: Many endpoints return "Not implemented yet".
- **Action**: systematic implementation of stubbed endpoints in `internal/service/shipment.go`.

#### 3. 🟡 **[P1] Real Carrier Integration**
- **Current**: No actual calls to UPS/FedEx/DHL.
- **Action**: Create adapters in `internal/biz/carrier/adapter` for at least one provider (e.g., Mock or Shippo/EasyPost wrapper).

---

## 🔍 SEARCH SERVICE ANALYSIS & PLAN

### 🚨 P1 - ARCHITECTURAL ISSUES

#### 1. [ARCH] Business Logic in Service Layer (`filterByVisibility`)
- **Location**: `search/internal/service/search_handlers.go`
- **Issue**: `filterByVisibility` performs business logic (calling catalog service, filtering results) inside the gRPC handler.
- **Fix**: Move this logic to `SearchUseCase.SearchProducts` and `SearchUseCase.AdvancedProductSearch`. The Usecase should return fully filtered/visible results.

#### 2. [MAINT] Complex Sorting Logic in Handler
- **Location**: `search/internal/service/search_handlers.go`
- **Issue**: ~50 lines of code just to parse `sort_by` from query strings vs enums.
- **Fix**: Extract to a `RequestParser` or `Binder` helper, or move inside Usecase validation.

### 🔵 P2 - RELIABILITY & CLEANUP

#### 3. [RELIABILITY] Graceful Shutdown Verification
- **Location**: `search/internal/biz/search_usecase.go`
- **Issue**: `SearchUseCase` spawns background workers (`startAnalyticsWorkers`).
- **Action**: Ensure `cmd/main.go` correctly calls `uc.Shutdown()` on service exit to drain the analytics channel.

#### 4. [UX] Autocomplete Interface Unification
- **Issue**: Separate `Autocomplete` (simple strings) and `AutocompleteAdvanced` (complex objects).
- **Action**: Deprecate simple `Autocomplete` in favor of `AutocompleteAdvanced` (with a simplified response option) to reduce maintenance surface.

---

## 📅 COMBINED IMPLEMENTATION ROADMAP

### Week 1: Shipping Tests & Search Refactor
- [x] **[Search]** Move `filterByVisibility` to Usecase.
- [x] **[Search]** Extract param parsing logic.
- [ ] **[Shipping]** Add Integration Tests for `CreateShipment`.

### Week 2: Shipping Features
- [ ] **[Shipping]** Implement real Carrier Adapter (Mock first).
- [ ] **[Shipping]** Complete Service Layer stubs.

### Week 3: Reliability
- [x] **[Search]** Verify/Add Shutdown hooks.
- [ ] **[All]** Add Prometheus metrics for key business methods.
