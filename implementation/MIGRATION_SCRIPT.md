# Migration Script - Remove Duplicate Code

## Quick Reference - Copy & Paste Commands

---

## 1. CUSTOMER SERVICE MIGRATION

### Step 1: Update imports
```bash
# File: customer/internal/service/customer.go
# Add this import at the top:
```

```go
import (
	// ... existing imports
	"gitlab.com/ta-microservices/common/utils/pagination"
)
```

### Step 2: Fix ListCustomers (Line ~250-280)

**Before**:
```go
var page, limit int32 = 1, 20
if req.Pagination != nil {
	page = req.Pagination.Page
	limit = req.Pagination.Limit
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
}
offset := int32((page - 1) * limit)
```

**After**:
```go
var page, limit int32 = 1, 20
if req.Pagination != nil {
	page = req.Pagination.Page
	limit = req.Pagination.Limit
}
page, limit, offset := pagination.GetOffsetLimit(page, limit)
```

### Step 3: Fix ListCustomersByStatus (Line ~560-590)

**Before**:
```go
var page, limit int32 = 1, 20
if req.Pagination != nil {
	page = req.Pagination.Page
	limit = req.Pagination.Limit
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
}
offset := int32((page - 1) * limit)
```

**After**:
```go
var page, limit int32 = 1, 20
if req.Pagination != nil {
	page = req.Pagination.Page
	limit = req.Pagination.Limit
}
page, limit, offset := pagination.GetOffsetLimit(page, limit)
```

### Step 4: Fix ListCustomersByType (Line ~710-740)

**Same as above** - Replace with pagination helper

### Step 5: Update customer business logic

```bash
# File: customer/internal/biz/customer/customer.go
# Add this import:
```

```go
import (
	// ... existing imports
	"gitlab.com/ta-microservices/common/utils/validation"
)
```

**Delete these functions** (Lines ~953-976):
```go
// DELETE THIS:
func isValidEmail(email string) bool {
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return emailRegex.MatchString(email)
}

// DELETE THIS:
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

**Replace all usages**:
```bash
# Find and replace in customer/internal/biz/customer/customer.go:
isValidEmail  →  validation.IsValidEmail
isValidPhone  →  validation.IsValidPhone
```

### Step 6: Test
```bash
cd customer
go test ./internal/service/... -v
go test ./internal/biz/customer/... -v
```

---

## 2. ORDER SERVICE MIGRATION

### Step 1: Update validation.go

```bash
# File: order/internal/service/validation.go
# Add this import:
```

```go
import (
	// ... existing imports
	"gitlab.com/ta-microservices/common/utils/pagination"
)
```

### Step 2: Replace ValidatePagination function

**Before** (Lines 63-75):
```go
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
```

**After**:
```go
func ValidatePagination(page, pageSize *int32) (int32, int32, error) {
	p := int32(1)
	ps := int32(20)
	if page != nil {
		p = *page
	}
	if pageSize != nil {
		ps = *pageSize
	}
	normalizedPage, normalizedLimit, _ := pagination.GetOffsetLimit(p, ps)
	return normalizedPage, normalizedLimit, nil
}
```

### Step 3: Replace ValidatePaginationWithDefaults function

**Before** (Lines 79-87):
```go
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

**After**:
```go
func ValidatePaginationWithDefaults(page, pageSize int32) (int32, int32) {
	normalizedPage, normalizedLimit, _ := pagination.GetOffsetLimit(page, pageSize)
	return normalizedPage, normalizedLimit
}
```

### Step 4: Test
```bash
cd order
go test ./internal/service/... -v
```

---

## 3. VERIFICATION SCRIPT

Create a script to verify the changes:

```bash
#!/bin/bash
# File: verify-migration.sh

echo "🔍 Checking for duplicate pagination logic..."

# Check customer service
echo "Checking customer service..."
grep -n "if page <= 0" customer/internal/service/customer.go && echo "❌ Found duplicate in customer service" || echo "✅ Customer service clean"

# Check order service
echo "Checking order service..."
grep -n "if page <= 0" order/internal/service/validation.go && echo "❌ Found duplicate in order service" || echo "✅ Order service clean"

# Check for local validation functions
echo "Checking for local validation functions..."
grep -n "func isValidEmail" customer/internal/biz/customer/customer.go && echo "❌ Found isValidEmail" || echo "✅ No isValidEmail"
grep -n "func isValidPhone" customer/internal/biz/customer/customer.go && echo "❌ Found isValidPhone" || echo "✅ No isValidPhone"

echo ""
echo "🧪 Running tests..."

# Test customer service
cd customer && go test ./internal/service/... -v && cd ..

# Test order service
cd order && go test ./internal/service/... -v && cd ..

echo ""
echo "✅ Migration verification complete!"
```

---

## 4. ROLLBACK PLAN (If needed)

```bash
# If something goes wrong, rollback using git:
git checkout customer/internal/service/customer.go
git checkout customer/internal/biz/customer/customer.go
git checkout order/internal/service/validation.go
```

---

## 5. COMPLETE MIGRATION CHECKLIST

### Pre-migration:
- [ ] Backup current code (git commit)
- [ ] Verify common helpers exist and work
- [ ] Run existing tests to establish baseline

### Customer Service:
- [ ] Update imports in `customer/internal/service/customer.go`
- [ ] Fix ListCustomers pagination (line ~250-280)
- [ ] Fix ListCustomersByStatus pagination (line ~560-590)
- [ ] Fix ListCustomersByType pagination (line ~710-740)
- [ ] Update imports in `customer/internal/biz/customer/customer.go`
- [ ] Delete isValidEmail function (line ~953-957)
- [ ] Delete isValidPhone function (line ~961-976)
- [ ] Replace all isValidEmail calls with validation.IsValidEmail
- [ ] Replace all isValidPhone calls with validation.IsValidPhone
- [ ] Run tests: `cd customer && go test ./... -v`

### Order Service:
- [ ] Update imports in `order/internal/service/validation.go`
- [ ] Replace ValidatePagination function (line 63-75)
- [ ] Replace ValidatePaginationWithDefaults function (line 79-87)
- [ ] Run tests: `cd order && go test ./... -v`

### Post-migration:
- [ ] Run verification script
- [ ] Manual testing of list endpoints
- [ ] Manual testing of validation (email, phone)
- [ ] Check logs for any errors
- [ ] Update documentation
- [ ] Commit changes with descriptive message

---

## 6. GIT COMMIT MESSAGES

```bash
# After customer service migration:
git add customer/
git commit -m "refactor(customer): migrate to common pagination and validation helpers

- Replace duplicate pagination logic with common/utils/pagination
- Replace isValidEmail with common/utils/validation.IsValidEmail
- Replace isValidPhone with common/utils/validation.IsValidPhone
- Remove ~60 lines of duplicate code
- All tests passing"

# After order service migration:
git add order/
git commit -m "refactor(order): migrate to common pagination helper

- Replace ValidatePagination with common/utils/pagination
- Replace ValidatePaginationWithDefaults with common/utils/pagination
- Remove ~30 lines of duplicate code
- All tests passing"
```

---

## 7. TESTING COMMANDS

### Unit Tests:
```bash
# Test common helpers
cd common/utils/pagination && go test -v
cd common/utils/validation && go test -v

# Test customer service
cd customer
go test ./internal/service/... -v
go test ./internal/biz/customer/... -v

# Test order service
cd order
go test ./internal/service/... -v
```

### Integration Tests:
```bash
# Start services and test endpoints
docker-compose up -d customer order

# Test customer list with pagination
curl "http://localhost:8083/api/v1/customers?page=1&limit=10"
curl "http://localhost:8083/api/v1/customers?page=2&limit=20"
curl "http://localhost:8083/api/v1/customers?page=0&limit=0"  # Should use defaults

# Test customer creation with validation
curl -X POST "http://localhost:8083/api/v1/customers" \
  -H "Content-Type: application/json" \
  -d '{"email": "invalid-email", "firstName": "Test"}'  # Should fail

curl -X POST "http://localhost:8083/api/v1/customers" \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "phone": "123", "firstName": "Test"}'  # Should fail

# Test order list with pagination
curl "http://localhost:8084/api/v1/orders?page=1&pageSize=10"
```

---

## 8. ESTIMATED TIME

| Task | Time | Difficulty |
|------|------|------------|
| Customer Service - Pagination | 15 min | Easy |
| Customer Service - Validation | 10 min | Easy |
| Customer Service - Testing | 15 min | Easy |
| Order Service - Pagination | 10 min | Easy |
| Order Service - Testing | 10 min | Easy |
| Integration Testing | 20 min | Medium |
| Documentation | 10 min | Easy |
| **Total** | **90 min** | **Easy** |

---

## 9. TROUBLESHOOTING

### Issue: Import not found
```bash
# Solution: Update go.mod
cd customer
go mod tidy
go mod vendor  # if using vendor
```

### Issue: Tests failing
```bash
# Check if common helpers are working
cd common/utils/pagination
go test -v

# Check imports
go list -m gitlab.com/ta-microservices/common
```

### Issue: Compilation errors
```bash
# Make sure you've replaced ALL occurrences
grep -r "isValidEmail" customer/internal/
grep -r "isValidPhone" customer/internal/
```

---

## 10. SUCCESS CRITERIA

✅ Migration is successful when:
- [ ] No compilation errors
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] No duplicate pagination logic found
- [ ] No local validation functions found
- [ ] API endpoints return correct pagination metadata
- [ ] Email/phone validation works correctly
- [ ] Code is cleaner and more maintainable

---

Generated: 2025-11-10
Ready to execute!
