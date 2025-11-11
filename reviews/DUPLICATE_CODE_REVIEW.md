# Duplicate Code Review - All Services

## Tổng quan
Review toàn bộ services để tìm duplicate code sau khi đã có `common/utils/pagination/helper.go`

---

## 🔴 CRITICAL - Cần fix ngay

### 1. PAGINATION LOGIC (Duplicate ở 2 services)

#### ❌ Customer Service (`customer/internal/service/customer.go`)
**Lines 253-259, 563-569, 710-716** - Duplicate 3 lần trong cùng 1 file!

```go
if page <= 0 {
    page = 1
}
if limit <= 0 {
    limit = 20
}
if limit > 100 {
    limit = 100
}
```

**Fix**:
```go
import "gitlab.com/ta-microservices/common/utils/pagination"

// Replace all 3 occurrences with:
page, limit, offset := pagination.GetOffsetLimit(req.Pagination.Page, req.Pagination.Limit)
```

---

#### ❌ Order Service (`order/internal/service/validation.go`)
**Lines 63-75, 79-87** - Có 2 functions duplicate!

```go
// ValidatePagination - duplicate logic
func ValidatePagination(page, pageSize *int32) (int32, int32, error) {
	if page == nil || *page <= 0 {
		defaultPage := int32(1)
		page = &defaultPage
	}
	if pageSize == nil || *pageSize <= 0 {
		defaultPageSize := int32(20)
		pageSize = &defaultPageSize
	}
	if *pageSize > 100 {
		*pageSize = 100
	}
	return *page, *pageSize, nil
}

// ValidatePaginationWithDefaults - duplicate logic
func ValidatePaginationWithDefaults(page, pageSize int32) (int32, int32) {
	if page <= 0 {
		page = 1
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}
	return page, pageSize
}
```

**Fix**: Delete both functions, use common helper
```go
import "gitlab.com/ta-microservices/common/utils/pagination"

// Replace ValidatePagination with:
page, limit, _ := pagination.GetOffsetLimit(*page, *pageSize)
return page, limit, nil

// Replace ValidatePaginationWithDefaults with:
page, limit, _ := pagination.GetOffsetLimit(page, pageSize)
return page, limit
```

---

### 2. EMAIL VALIDATION (Duplicate ở 3 places)

#### ❌ Customer Service (`customer/internal/biz/customer/customer.go:953`)
```go
func isValidEmail(email string) bool {
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return emailRegex.MatchString(email)
}
```

#### ✅ Common Utils (Already exists!)
- `common/utils/validation.go:20` - Has `IsValidEmail`
- `common/utils/validation/validators.go:14` - Has `IsValidEmail`

**Fix**: Delete local function, use common
```go
import "gitlab.com/ta-microservices/common/utils/validation"

// Replace isValidEmail with:
validation.IsValidEmail(email)
```

---

### 3. PHONE VALIDATION (Duplicate ở 2 places)

#### ❌ Customer Service (`customer/internal/biz/customer/customer.go:961`)
```go
func isValidPhone(phone string) bool {
	cleaned := regexp.MustCompile(`[\s\-\(\)]`).ReplaceAllString(phone, "")
	if matched, _ := regexp.MatchString(`^\+[1-9]\d{1,14}$`, cleaned); matched {
		return true
	}
	if matched, _ := regexp.MatchString(`^\d{8,15}$`, cleaned); matched {
		return true
	}
	return false
}
```

#### ✅ Common Utils (Already exists!)
- `common/utils/validation.go:26` - Has `IsValidPhone`
- `common/utils/validation/validators.go:23` - Has `IsValidPhone`

**Fix**: Delete local function, use common
```go
import "gitlab.com/ta-microservices/common/utils/validation"

// Replace isValidPhone with:
validation.IsValidPhone(phone)
```

---

### 4. SLUG GENERATION (Already in common!)

#### ✅ Common Utils (Already exists!)
- `common/utils/validation.go:101` - Has `GenerateSlug`
- `common/utils/validation/validators.go:53` - Has `GenerateSlug`

**Status**: ✅ Good! Services should use this instead of implementing their own.

---

## 🟡 MEDIUM - Có thể optimize

### 5. CACHE KEY BUILDING (Pattern lặp lại nhiều)

#### Pattern ở Customer Service:
```go
// customer/internal/biz/customer/cache.go
key := fmt.Sprintf("customer:%s", id.String())

// customer/internal/biz/address/cache.go
key := fmt.Sprintf("customer:address:%s", id.String())

// customer/internal/biz/preference/cache.go
key := fmt.Sprintf("customer:preferences:%s", customerID.String())
```

#### Pattern ở Catalog Service:
```go
// catalog/internal/biz/product/cache_warming.go
cacheKey := fmt.Sprintf("catalog:product:%s", productID)

// catalog/internal/biz/product/product.go
productCacheKey := constants.BuildCacheKey(constants.CacheKeyProduct, productID)
gatewayCacheKey := constants.BuildCacheKey(constants.CacheKeyGatewayProductDetail, productID)
```

**Observation**: 
- Catalog đã dùng `constants.BuildCacheKey()` - ✅ Good pattern!
- Customer vẫn dùng `fmt.Sprintf` trực tiếp - ❌ Should use helper

**Recommendation**: 
Tạo `common/utils/cache/key_builder.go`:
```go
package cache

import "fmt"

type KeyBuilder struct {
	prefix string
}

func NewKeyBuilder(prefix string) *KeyBuilder {
	return &KeyBuilder{prefix: prefix}
}

func (kb *KeyBuilder) Build(parts ...string) string {
	key := kb.prefix
	for _, part := range parts {
		key = fmt.Sprintf("%s:%s", key, part)
	}
	return key
}

// Convenience functions
func BuildKey(parts ...string) string {
	key := parts[0]
	for i := 1; i < len(parts); i++ {
		key = fmt.Sprintf("%s:%s", key, parts[i])
	}
	return key
}
```

**Usage**:
```go
// Instead of:
key := fmt.Sprintf("customer:%s", id.String())

// Use:
key := cache.BuildKey("customer", id.String())
```

---

### 6. PROTO CONVERSION PATTERNS (Nhiều convert functions tương tự)

#### Services có nhiều convert functions:
- **Pricing**: 7 convert functions (`convertPriceToProto`, `convertDiscountToProto`, etc.)
- **Promotion**: 11 convert functions (`convertCampaignToProto`, `convertPromotionToProto`, etc.)
- **Archive/Review**: 2 convert functions

**Pattern chung**:
```go
func convertXxxToProto(xxx *model.Xxx) *pb.Xxx {
	return &pb.Xxx{
		Id:   xxx.ID,
		Name: xxx.Name,
		// ... field mapping
	}
}

func convertXxxsToProto(xxxs []*model.Xxx) []*pb.Xxx {
	result := make([]*pb.Xxx, len(xxxs))
	for i, xxx := range xxxs {
		result[i] = convertXxxToProto(xxx)
	}
	return result
}
```

**Recommendation**: 
Tạo generic helper trong `common/proto/converter.go`:
```go
package proto

// ConvertSlice converts slice of models to slice of protos using converter function
func ConvertSlice[T any, P any](items []T, converter func(T) P) []P {
	result := make([]P, len(items))
	for i, item := range items {
		result[i] = converter(item)
	}
	return result
}

// ConvertPtrSlice converts slice of model pointers to slice of proto pointers
func ConvertPtrSlice[T any, P any](items []*T, converter func(*T) *P) []*P {
	result := make([]*P, len(items))
	for i, item := range items {
		result[i] = converter(item)
	}
	return result
}
```

**Usage**:
```go
// Instead of:
func convertDiscountsToProto(discounts []*model.Discount) []*v1.Discount {
	result := make([]*v1.Discount, len(discounts))
	for i, discount := range discounts {
		result[i] = convertDiscountToProto(discount)
	}
	return result
}

// Use:
discounts := proto.ConvertPtrSlice(discounts, convertDiscountToProto)
```

---

## 🟢 LOW - Nice to have

### 7. LOGGING PATTERNS (Consistent nhưng có thể improve)

**Current pattern** (Good!):
```go
uc.log.WithContext(ctx).Infof("Creating xxx: %s", req.Name)
uc.log.WithContext(ctx).Errorf("Failed to create xxx: %v", err)
```

**Recommendation**: Tạo structured logging helper
```go
// common/utils/logging/structured.go
package logging

import (
	"context"
	"github.com/go-kratos/kratos/v2/log"
)

type StructuredLogger struct {
	log *log.Helper
}

func NewStructuredLogger(logger log.Logger) *StructuredLogger {
	return &StructuredLogger{
		log: log.NewHelper(logger),
	}
}

func (l *StructuredLogger) LogOperation(ctx context.Context, operation, entity, id string) {
	l.log.WithContext(ctx).Infof("%s %s: %s", operation, entity, id)
}

func (l *StructuredLogger) LogError(ctx context.Context, operation, entity string, err error) {
	l.log.WithContext(ctx).Errorf("Failed to %s %s: %v", operation, entity, err)
}
```

---

## 📊 SUMMARY

### Duplicate Code Found:

| Category | Location | Status | Priority |
|----------|----------|--------|----------|
| **Pagination** | customer/internal/service/customer.go (3x) | ❌ Duplicate | 🔴 Critical |
| **Pagination** | order/internal/service/validation.go (2 funcs) | ❌ Duplicate | 🔴 Critical |
| **Email Validation** | customer/internal/biz/customer/customer.go | ❌ Duplicate | 🔴 Critical |
| **Phone Validation** | customer/internal/biz/customer/customer.go | ❌ Duplicate | 🔴 Critical |
| **Slug Generation** | - | ✅ Already in common | ✅ Good |
| **Cache Key Building** | customer/internal/biz/*/cache.go | 🟡 Can optimize | 🟡 Medium |
| **Proto Conversion** | pricing, promotion services | 🟡 Can optimize | 🟡 Medium |
| **Logging** | All services | ✅ Consistent | 🟢 Low |

---

## 🎯 ACTION ITEMS

### Immediate (This week):

1. **Customer Service** - Replace pagination logic (3 places)
   ```bash
   File: customer/internal/service/customer.go
   Lines: 253-259, 563-569, 710-716
   ```

2. **Order Service** - Delete validation functions, use common
   ```bash
   File: order/internal/service/validation.go
   Lines: 63-87 (both functions)
   ```

3. **Customer Service** - Replace email/phone validation
   ```bash
   File: customer/internal/biz/customer/customer.go
   Lines: 953-957 (isValidEmail)
   Lines: 961-976 (isValidPhone)
   ```

### Short-term (Next sprint):

4. **Cache Key Builder** - Create common helper
   - Create `common/utils/cache/key_builder.go`
   - Migrate customer service cache files
   - Update catalog service to use common helper

5. **Proto Converter** - Create generic helper
   - Create `common/proto/converter.go`
   - Migrate pricing service
   - Migrate promotion service

### Long-term (Future):

6. **Structured Logging** - Create helper (optional)
7. **Documentation** - Update migration guide
8. **Testing** - Add integration tests for common helpers

---

## 📝 MIGRATION CHECKLIST

### Customer Service:
- [ ] Import `common/utils/pagination`
- [ ] Replace pagination logic in ListCustomers (line 253-259)
- [ ] Replace pagination logic in ListCustomersByStatus (line 563-569)
- [ ] Replace pagination logic in ListCustomersByType (line 710-716)
- [ ] Import `common/utils/validation`
- [ ] Replace isValidEmail function (line 953-957)
- [ ] Replace isValidPhone function (line 961-976)
- [ ] Test all list endpoints
- [ ] Test customer creation with email/phone validation

### Order Service:
- [ ] Import `common/utils/pagination`
- [ ] Delete ValidatePagination function (line 63-75)
- [ ] Delete ValidatePaginationWithDefaults function (line 79-87)
- [ ] Update all usages to use common helper
- [ ] Test all list endpoints

---

## 🧪 TESTING PLAN

### Unit Tests:
```bash
# Test pagination helper
cd common/utils/pagination
go test -v

# Test validation helper
cd common/utils/validation
go test -v
```

### Integration Tests:
```bash
# Test customer service after migration
cd customer
go test ./internal/service/... -v

# Test order service after migration
cd order
go test ./internal/service/... -v
```

### Manual Testing:
- [ ] Test ListCustomers with various page/limit values
- [ ] Test customer creation with invalid email
- [ ] Test customer creation with invalid phone
- [ ] Test order list endpoints
- [ ] Verify pagination metadata (has_next, has_prev)

---

## 📈 EXPECTED IMPACT

### Code Reduction:
- **Customer Service**: ~60 lines removed
- **Order Service**: ~30 lines removed
- **Total**: ~90 lines of duplicate code eliminated

### Maintenance:
- ✅ Single source of truth for pagination logic
- ✅ Single source of truth for validation logic
- ✅ Easier to update business rules (e.g., change max limit from 100 to 200)
- ✅ Consistent behavior across all services

### Quality:
- ✅ Better test coverage (test once, use everywhere)
- ✅ Fewer bugs (no inconsistencies between services)
- ✅ Easier onboarding (developers learn common patterns once)

---

Generated: 2025-11-10
Reviewed services: catalog, customer, warehouse, user, auth, gateway, pricing, promotion, order
