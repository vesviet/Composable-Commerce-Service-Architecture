# Code Refactoring Checklist - Large Files (>500 Lines)

**Created**: 2026-01-22  
**Priority**: P1 - Maintainability & Code Quality  
**Scope**: All internal service code >500 lines

---

## 📊 Summary

**Total Large Files Found**: 50+ files >500 lines  
**Critical (>1000 lines)**: 11 files requiring immediate attention  
**High Priority (700-1000 lines)**: 15 files  
**Medium Priority (500-700 lines)**: 24+ files

---

## 🚨 CRITICAL - Files >1000 Lines (Immediate Action Required)

### 1. **Pricing Service** - 1743 lines 🔥
- **File**: `pricing/internal/service/pricing.go`
- **Impact**: God object anti-pattern, difficult testing
- **Refactor Plan**:
  - Extract `PricingRulesService` (rule evaluation logic)
  - Extract `PriceCacheService` (caching logic)
  - Extract `CurrencyConverterService` (multi-currency)
  - Keep core orchestration in `pricing.go`
- **Effort**: 16 hours
- **Priority**: **P0** - Blocks pricing enhancements

### 2. **Order Return** - 1576 lines
- **File**: `order/internal/biz/return/return.go`
- **Refactor Plan**:
  - Split into: `validation.go`, `refund.go`, `restock.go`, `workflow.go`
  - Extract state machine to `state_machine.go`
- **Effort**: 12 hours
- **Priority**: P1

### 3. **Promotion** - 1426 lines
- **File**: `promotion/internal/biz/promotion.go`
- **Refactor Plan**:
  - Extract to: `validation.go`, `eligibility.go`, `discount_rules.go`, `usage_tracking.go`
  - Keep core orchestration
- **Effort**: 14 hours
- **Priority**: **P0** - Hard to add new promotion types

### 4. **Warehouse Inventory** - 1302 lines
- **File**: `warehouse/internal/biz/inventory/inventory.go`
- **Refactor Plan**:
  - Split into: `stock_operations.go`, `reservation.go`, `allocation.go`, `alerts.go`
  - Extract FIFO logic to `fifo_handler.go`
- **Effort**: 12 hours
- **Priority**: P1

### 5. **Fulfillment** - 1302 lines
- **File**: `fulfillment/internal/biz/fulfillment/fulfillment.go`
- **Refactor Plan**:
  - Split by state: `picking.go`, `packing.go`, `shipping.go`, `completion.go`
  - Extract warehouse selection to `warehouse_selector.go`
- **Effort**: 12 hours
- **Priority**: P1

### 6. **Warehouse Service** - 1232 lines
- **File**: `warehouse/internal/service/inventory_service.go`
- **Refactor Plan**:
  - Extract gRPC handlers to separate files by domain
  - Create `stock_handlers.go`, `reservation_handlers.go`, `alert_handlers.go`
- **Effort**: 8 hours
- **Priority**: P1

### 7. **Promotion Service** - 1174 lines
- **File**: `promotion/internal/service/promotion.go`
- **Refactor Plan**:
  - Split handlers: `coupon_handlers.go`, `validation_handlers.go`, `campaign_handlers.go`
- **Effort**: 8 hours
- **Priority**: P1

### 8. **Customer** - 1069 lines
- **File**: `customer/internal/biz/customer/customer.go`
- **Refactor Plan**:
  - Extract: `profile.go`, `segmentation.go`, `loyalty.go`, `preferences.go`
- **Effort**: 10 hours
- **Priority**: P1

### 9. **Catalog Product Attribute** - 1031 lines
- **File**: `catalog/internal/data/postgres/product_attribute.go`
- **Refactor Plan**:
  - Split by operation: `attribute_crud.go`, `attribute_search.go`, `attribute_validation.go`
- **Effort**: 8 hours
- **Priority**: P2

### 10. **User** - 972 lines
- **File**: `user/internal/biz/user/user.go`
- **Refactor Plan**:
  - Extract: `authentication.go`, `authorization.go`, `profile.go`, `admin.go`
- **Effort**: 10 hours
- **Priority**: P1

### 11. **Fulfillment Picklist** - 954 lines
- **File**: `fulfillment/internal/biz/picklist/picklist.go`
- **Refactor Plan**:
  - Split: `creation.go`, `optimization.go`, `assignment.go`, `completion.go`
- **Effort**: 10 hours
- **Priority**: P2

---

## 🟡 HIGH PRIORITY - Files 700-1000 Lines

| Lines | Service | File | Suggested Split | Effort |
|-------|---------|------|-----------------|--------|
| 948 | Order | `service/order.go` | Split by flow (create, edit, cancel, query) | 8h |
| 867 | Pricing | `biz/price/price.go` | Extract calculation, validation, persistence | 8h |
| 857 | Pricing | `data/postgres/price.go` | Split by operation type | 6h |
| 828 | Order | `data/client_adapters.go` | One adapter per service | 8h |
| 827 | User | `service/user.go` | Split handlers by domain | 6h |
| 813 | Catalog | `biz/product_attribute/product_attribute.go` | CRUD + validation + search | 8h |
| 808 | Order | `biz/order_edit/order_edit.go` | Split by edit type | 8h |
| 791 | Payment | `biz/gateway/stripe/client.go` | Split by operation (auth, capture, refund) | 8h |
| 790 | Order | `service/cart.go` | Split cart operations | 6h |
| 779 | Fulfillment | `biz/package_biz/package.go` | Split packaging workflow | 6h |
| 771 | Promotion | `biz/discount_calculator.go` | One file per discount type (BOGO, tiered, etc) | 8h |
| 756 | Payment | `biz/gateway/paypal/client.go` | Split operations | 6h |
| 752 | Order | `biz/biz.go` | Extract services to dedicated files | 6h |
| 748 | Search | `service/product_consumer.go` | Split handlers | 6h |
| 741 | Order | `data/postgres/cart.go` | CRUD + queries + helpers | 6h |

---

## 🔵 NORMAL PRIORITY - Files 500-700 Lines

**24 files identified** - Lower priority but should be monitored

Most common patterns:
- Service layer god objects (combine all handlers)
- Biz layer with all operations in one file
- Data layer with CRUD + complex queries mixed

**General recommendation**: Split when adding new features to avoid further bloat

---

## 🛠️ Refactoring Strategy

### Phase-by-Phase Approach

**Phase 1 (Sprint 1-2): Critical P0 Files**
1. `pricing/service/pricing.go` (1743 lines) - Blocks enhancements
2. `promotion/biz/promotion.go` (1426 lines) - Blocks new promo types
3. `order/biz/return/return.go` (1576 lines) - Complex return workflows

**Effort**: ~40 hours  
**Impact**: Unlocks feature development in Pricing & Promotion

**Phase 2 (Sprint 3-4): High Impact Files**
4-8. Warehouse, Fulfillment, Customer, User (5 files, 1000-1300 lines each)

**Effort**: ~50 hours  
**Impact**: Improves maintainability across core domains

**Phase 3 (Sprint 5-6): Service Layer**
9-15. Large service files (700-1000 lines each)

**Effort**: ~50 hours  
**Impact**: Better testability, clearer API boundaries

### Refactoring Principles

**DO**:
✅ Split by **responsibility** (single concern per file)  
✅ Use **feature folders** when appropriate  
✅ Keep **orchestration** in main file, extract **implementation**  
✅ Add **interfaces** for new extracted services  
✅ Write **tests for each extracted file**  

**DON'T**:
❌ Split arbitrarily by line count  
❌ Create circular dependencies  
❌ Break existing public APIs  
❌ Refactor without tests  

---

## 📏 File Size Guidelines (Going Forward)

**Target Limits**:
- **Biz layer**: Max 500 lines per file
- **Service layer**: Max 400 lines per file (handler collection)
- **Data layer**: Max 400 lines per file
- **Test files**: Max 600 lines (split by scenarios)

**When to split**:
- File >500 lines → Plan refactor
- File >700 lines → Refactor on next feature
- File >1000 lines → **Immediate refactor required**

---

## 🎯 Success Metrics

**Track Progress**:
```bash
# Weekly file size report
find . -name "*.go" -path "*/internal/*" ! -path "*/vendor/*" \
  -exec sh -c 'wc -l "$1" | awk "{if (\$1 > 500) print}"' _ {} \; | wc -l

# Goal: Reduce from 50+ to <20 files >500 lines
```

**Quality Improvements**:
- Cyclomatic complexity per function: <15
- Test coverage per file: >80%
- Code review time: Reduce by 30%

---

## 📖 Related Documentation

- **Team Lead Guide**: Clean Code principles
- **Refactoring Guide**: [Martin Fowler - Refactoring](https://refactoring.com/)
- **Go Style**: [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)

---

**Created**: 2026-01-22  
**Owner**: Engineering Team  
**Review Cycle**: Quarterly (track file size trends)
