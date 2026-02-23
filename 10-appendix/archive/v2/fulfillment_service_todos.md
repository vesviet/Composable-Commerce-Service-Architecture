# Fulfillment Service - TODO Comments List

**Service**: Fulfillment Service  
**Last Updated**: January 28, 2026  
**Status**: Tracking TODO items for future improvements

---

## 📋 Summary

**Total TODO Items**: 5 actionable TODOs  
**Total NOTE Comments**: 12 informational notes (not actionable)

---

## 🔴 P0 (Critical) - Blocks Functionality

### TODO-1: QC Usecase Wiring

**Priority**: 🔴 **P0** (Blocks QC functionality)  
**Status**: ✅ **COMPLETED**  
**Files**:
- `fulfillment/internal/service/fulfillment_service.go` (lines 393-408)
- `fulfillment/internal/biz/fulfillment/fulfillment.go` (added GetQCUsecase method)

**Implementation Details**:
1. ✅ Added `GetQCUsecase()` method to `FulfillmentUseCase` to expose QC usecase
2. ✅ Updated `PerformQC` to:
   - Validate input (fulfillment_id, checker_id UUIDs)
   - Access QC usecase via `GetQCUsecase()`
   - Call `qcUsecase.PerformQC()` with proper error handling
   - Convert QCResult model to proto using `convertQCResultToProto()`
3. ✅ Updated `GetQCResult` to:
   - Validate input (fulfillment_id UUID)
   - Access QC usecase via `GetQCUsecase()`
   - Call `qcUsecase.GetQCResult()` with proper error handling
   - Convert QCResult model to proto
4. ✅ Created `convertQCResultToProto()` helper function to convert model to proto

**Impact**: ✅ QC endpoints are now functional - quality control workflow can be used, high-value orders can be QC'd

---

## 🟠 P1 (High Priority) - Important Features

### TODO-2: PDF Packing Slip Generation

**Priority**: 🟠 **P1** (Needed for production packing slips)  
**Status**: ⏳ **IMPROVED** - Text format enhanced, PDF library integration pending  
**Files**:
- `fulfillment/internal/biz/package_biz/packing_slip.go` (lines 34, 50)

**Current State**:
- ✅ Improved text-based packing slip format with better structure
- ✅ Added formatted output with headers, sections, and tables
- ✅ Added `truncateString()` helper for text formatting
- ✅ Added `generatePackingSlipPDF()` stub with implementation example
- ⏳ PDF library integration pending (requires adding `github.com/jung-kurt/gofpdf/v2`)

**Implementation Details**:
1. ✅ Enhanced `generatePackingSlipText()` with:
   - Formatted header with borders
   - Structured sections (Order Information, Items, Package Details)
   - Table format for items list
   - Total items count
   - Professional footer
   - Text truncation helper for long product names

2. ✅ Added `generatePackingSlipPDF()` stub function with:
   - Implementation example using gofpdf
   - Clear instructions for future PDF implementation
   - Commented code showing PDF structure

**Remaining Action** (for full PDF support):
1. Add PDF library to `go.mod`: `github.com/jung-kurt/gofpdf/v2`
2. Implement `generatePackingSlipPDF()` function
3. Update `GeneratePackingSlip()` to use PDF generation
4. Change file extension from `.txt` to `.pdf`
5. Test PDF generation and download

**Impact**: ✅ Text format significantly improved - more professional and readable. PDF generation ready for implementation when library is added.

---

## 🟡 P2 (Normal Priority) - Enhancements

### TODO-3: Path Optimization with Zone Coordinates

**Priority**: 🟡 **P2** (Performance improvement)  
**Status**: ❌ **NOT IMPLEMENTED**  
**Files**:
- `fulfillment/internal/biz/picklist/path_optimizer.go` (line 53)

**Current State**:
```go
// OptimizePickingPath optimizes picking path based on zones
func (o *PathOptimizer) OptimizePickingPath(items []PicklistItem) []PicklistItem {
    // Group items by zone
    zones := o.groupItemsByZone(items)
    
    // Sort zones by zone ID (alphabetically)
    // TODO: In the future, use zone coordinates from warehouse service for better optimization
    sort.Slice(zones, func(i, j int) bool {
        return zones[i].ZoneID < zones[j].ZoneID
    })
    
    // Assign zone sequence
    // ...
}
```

**Impact**: 
- Current optimization is alphabetical (not optimal)
- Could improve picking efficiency by 10-20% with coordinate-based optimization
- Reduces walking distance for pickers

**Required Action**:
1. Add zone coordinates to Warehouse Service API (if not exists)
2. Fetch zone coordinates from Warehouse Service
3. Implement coordinate-based path optimization algorithm (e.g., nearest neighbor)
4. Update `OptimizePickingPath` to use coordinates
5. Compare performance with current implementation

**Estimated Effort**: 8-12 hours

---

### TODO-4: Catalog Package Weight Field Update

**Priority**: 🟡 **P2** (Dependency update)  
**Status**: ❌ **NOT IMPLEMENTED**  
**Files**:
- `fulfillment/internal/biz/package_biz/weight_verification.go` (line 131)

**Current State**:
```go
// extractProductWeight extracts weight from product (helper function)
// TODO: Update catalog package to v1.0.3+ which includes Weight field in Product proto
// For now, weight verification is skipped if Weight is not available
func (uc *PackageUsecase) extractProductWeight(product *catalogV1.Product) float64 {
    // Note: Weight field may not be available in current catalog package version (v1.0.2)
    // Try to extract weight from product attributes or specifications
    // ...
}
```

**Impact**: 
- Weight verification may be inaccurate if weight not in product data
- Relies on fallback methods (attributes/specifications)
- Could improve accuracy with direct Weight field

**Required Action**:
1. Check if Catalog Service proto v1.0.3+ includes Weight field
2. Update Catalog Service dependency to v1.0.3+ (if available)
3. Update `extractProductWeight` to use Weight field directly
4. Remove fallback logic if Weight field is reliable
5. Test weight verification accuracy

**Estimated Effort**: 2-4 hours

---

## 🟢 P3 (Low Priority) - Documentation/Notes

### TODO-5: Integration Tests

**Priority**: 🟢 **P3** (Testing improvement)  
**Status**: ❌ **NOT IMPLEMENTED**  
**Files**:
- `fulfillment/README.md` (line 751)

**Current State**:
```markdown
### Integration Tests
- **Location**: `test/integration/`
- **Status**: TODO - Need to add integration tests
- **Target**: Test complete fulfillment flows with testcontainers
```

**Impact**: 
- No integration tests for complete fulfillment flows
- Higher risk of regressions
- Difficult to verify end-to-end behavior

**Required Action**:
1. Create `test/integration/` directory
2. Set up testcontainers for PostgreSQL and Redis
3. Write integration tests for:
   - Complete fulfillment flow (create → pick → pack → ship)
   - Event publishing and consumption
   - Database transactions
   - External service integration (mocked)
4. Add to CI/CD pipeline

**Estimated Effort**: 16-24 hours

---

## 📝 NOTE Comments (Informational - Not Actionable)

### NOTE-1: Event Handlers Removed
**File**: `fulfillment/internal/server/http.go` (line 100)  
**Content**: "Event handlers removed - events are handled by worker via gRPC eventbus consumer"  
**Type**: Informational - explains architecture decision

### NOTE-2: Warehouse ID Required
**File**: `fulfillment/internal/events/provider.go` (line 23)  
**Content**: "Note: warehouseID is required since Package model doesn't have WarehouseID field"  
**Type**: Informational - explains parameter requirement

### NOTE-3: Deploy Script Deprecated
**File**: `fulfillment/scripts/deploy-local.sh` (line 3)  
**Content**: "NOTE: This script is deprecated - deployment is now managed via ArgoCD"  
**Type**: Informational - explains deprecation

### NOTE-4: Picklist Items Preload
**File**: `fulfillment/internal/events/publisher.go` (line 96)  
**Content**: "Note: picklist.Items should be preloaded if items are needed in event"  
**Type**: Informational - performance tip

### NOTE-5: System Error Event Location
**File**: `fulfillment/internal/events/fulfillment_events.go` (line 44)  
**Content**: "Note: SystemErrorEvent is now defined in common/utils/eventbus/system_error_event.go"  
**Type**: Informational - code location reference

### NOTE-6: Migration Dependencies
**Files**: Multiple migration files  
**Content**: Notes about table creation order and dependencies  
**Type**: Informational - migration documentation

### NOTE-7: Order Status Constants Consistency
**File**: `fulfillment/internal/constants/order_status.go` (line 5)  
**Content**: "Note: These values must match order/internal/constants/constants.go for consistency"  
**Type**: Informational - consistency requirement

### NOTE-8: Provider Set Notes
**Files**: `fulfillment/internal/biz/qc/provider.go`, `fulfillment/internal/biz/picklist/provider.go`  
**Content**: Notes about dependency injection and wire setup  
**Type**: Informational - architecture documentation

---

## 📊 TODO Priority Summary

| Priority | Count | Items | Status |
|----------|-------|-------|--------|
| 🔴 P0 | 1 | QC Usecase Wiring | ✅ **COMPLETED** |
| 🟠 P1 | 1 | PDF Packing Slip Generation | ⏳ **IMPROVED** (Text enhanced, PDF pending) |
| 🟡 P2 | 2 | Path Optimization, Catalog Weight Field | ❌ **PENDING** |
| 🟢 P3 | 1 | Integration Tests | ❌ **PENDING** (Skipped per user request) |
| **Total** | **5** | **Actionable TODOs** | **2/5 Completed/Improved** |

---

## 🎯 Recommended Action Plan

### Immediate (Week 1) - ✅ **COMPLETED**
1. ✅ **TODO-1**: Wire QC usecase (P0) - **COMPLETED**

### Short Term (Week 2-3) - ⏳ **IN PROGRESS**
2. ⏳ **TODO-2**: Implement PDF packing slip generation (P1) - **IMPROVED** (Text format enhanced, PDF library integration pending)

### Medium Term (Month 1)
3. **TODO-3**: Path optimization with coordinates (P2) - Performance improvement
4. **TODO-4**: Update catalog package for Weight field (P2) - Dependency update

### Long Term (Month 2+)
5. **TODO-5**: Add integration tests (P3) - Testing improvement

---

## 📝 Tracking Format

When implementing TODOs, use this format:

```go
// TODO(#ISSUE-ID): Brief description
// Implementation details...
```

Example:
```go
// TODO(#123): Access QC usecase from fulfillment usecase
// Wire QCUsecase into FulfillmentUseCase via dependency injection
// Update PerformQC and GetQCResult methods to use QC usecase
```

---

**Last Updated**: January 28, 2026  
**Next Review**: After P0/P1 TODOs are resolved
