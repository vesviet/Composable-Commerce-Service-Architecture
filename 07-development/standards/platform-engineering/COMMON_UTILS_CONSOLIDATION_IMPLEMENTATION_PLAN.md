# 🚀 Common Utils Consolidation - Implementation Plan

**Date**: December 27, 2025  
**Priority**: High (Critical for v1.5.0 release)  
**Timeline**: 2 weeks (80 hours)  
**Goal**: Eliminate duplicate functionality, standardize APIs

---

## 📋 **IMMEDIATE ACTION ITEMS**

### **Week 1: Core Consolidation (40 hours)**

#### **Day 1: Pagination Enhancement (8 hours)**

**Morning: Enhance utils/pagination/pagination.go**
```bash
# Current status: Missing GetOffset(), From/To calculation
# Target: Add all missing methods from filter/pagination_filter.go
```

- [ ] **Add missing methods to Paginator struct**
  ```go
  // Add to common/utils/pagination/pagination.go
  
  // GetOffset calculates database offset
  func (p *Paginator) GetOffset() int {
      return (p.GetPage() - 1) * p.GetPageSize()
  }
  
  // GetLimit returns limit (alias for GetPageSize)
  func (p *Paginator) GetLimit() int {
      return p.GetPageSize()
  }
  
  // Compatibility aliases for existing services
  func (p *Paginator) GetPerPage() int {
      return p.GetPageSize()
  }
  
  func (p *Paginator) GetCurrentPage() int {
      return p.GetPage()
  }
  ```

- [ ] **Enhance PaginationResponse with From/To**
  ```go
  // Update PaginationResponse struct
  type PaginationResponse struct {
      Page       int   `json:"page"`
      PageSize   int   `json:"page_size"`
      Total      int64 `json:"total"`
      TotalPages int   `json:"total_pages"`
      HasNext    bool  `json:"has_next"`
      HasPrev    bool  `json:"has_prev"`
      From       int   `json:"from"`        // NEW
      To         int   `json:"to"`          // NEW
  }
  ```

- [ ] **Update SetTotal method with From/To calculation**
  ```go
  // Enhanced SetTotal method
  func (p *Paginator) SetTotal(total int64) *PaginationResponse {
      page := p.request.Page
      pageSize := p.request.PageSize
      totalPages := int(math.Ceil(float64(total) / float64(pageSize)))
      
      response := &PaginationResponse{
          Page:       page,
          PageSize:   pageSize,
          Total:      total,
          TotalPages: totalPages,
          HasNext:    page < totalPages,
          HasPrev:    page > 1,
      }
      
      // Calculate From/To
      if total > 0 {
          from := p.GetOffset() + 1
          to := from + pageSize - 1
          if int64(to) > total {
              to = int(total)
          }
          response.From = from
          response.To = to
      }
      
      return response
  }
  ```

**Afternoon: Create Migration Helpers**
- [ ] **Create pagination migration utilities**
  ```go
  // common/utils/pagination/migration.go - NEW FILE
  package pagination
  
  import "gitlab.com/ta-microservices/common/utils/filter"
  
  // MigratePaginationFilter converts old filter to new paginator
  func MigratePaginationFilter(oldFilter *filter.PaginationFilter) *Paginator {
      req := &PaginationRequest{
          Page:     oldFilter.GetPage(),
          PageSize: oldFilter.GetPerPage(),
          Sort:     "", // Extract from orderBy if needed
          Order:    "", // Extract from orderBy if needed
      }
      return NewPaginator(req)
  }
  
  // MigratePaging converts old paging struct to new response
  func MigratePaging(oldPaging *filter.Paging) *PaginationResponse {
      return &PaginationResponse{
          Page:       oldPaging.CurrentPage,
          PageSize:   oldPaging.PerPage,
          Total:      int64(oldPaging.Total),
          TotalPages: oldPaging.LastPage,
          From:       oldPaging.From,
          To:         oldPaging.To,
          HasNext:    oldPaging.CurrentPage < oldPaging.LastPage,
          HasPrev:    oldPaging.CurrentPage > 1,
      }
  }
  ```

#### **Day 2: Validation Enhancement (8 hours)**

**Morning: Add Missing Validation Functions**
- [ ] **Create validation/password.go**
  ```go
  // common/validation/password.go - NEW FILE
  package validation
  
  import (
      "fmt"
      "regexp"
  )
  
  // Password validates password strength using fluent API
  func (v *Validator) Password(field string, value string) *Validator {
      if value != "" {
          if valid, message := isValidPassword(value); !valid {
              v.addError(field, "INVALID_PASSWORD", message, value)
          }
      }
      return v
  }
  
  // isValidPassword implements password validation logic
  func isValidPassword(password string) (bool, string) {
      if len(password) < 8 {
          return false, "password must be at least 8 characters"
      }
      if len(password) > 128 {
          return false, "password must be at most 128 characters"
      }
      
      // Check for at least one uppercase letter
      if matched, _ := regexp.MatchString(`[A-Z]`, password); !matched {
          return false, "password must contain at least one uppercase letter"
      }
      
      // Check for at least one lowercase letter
      if matched, _ := regexp.MatchString(`[a-z]`, password); !matched {
          return false, "password must contain at least one lowercase letter"
      }
      
      // Check for at least one digit
      if matched, _ := regexp.MatchString(`\d`, password); !matched {
          return false, "password must contain at least one digit"
      }
      
      return true, ""
  }
  ```

- [ ] **Create validation/slug.go**
  ```go
  // common/validation/slug.go - NEW FILE
  package validation
  
  import (
      "fmt"
      "regexp"
      "strings"
  )
  
  // Slug validates slug format using fluent API
  func (v *Validator) Slug(field string, value string) *Validator {
      if value != "" {
          slug := generateSlug(value)
          if slug != value {
              v.addError(field, "INVALID_SLUG", 
                  fmt.Sprintf("%s must be a valid slug format", field), value)
          }
      }
      return v
  }
  
  // generateSlug creates URL-friendly slug from text
  func generateSlug(text string) string {
      slug := strings.ToLower(text)
      slug = strings.TrimSpace(slug)
      slug = strings.ReplaceAll(slug, " ", "-")
      slug = strings.ReplaceAll(slug, "_", "-")
      slug = regexp.MustCompile(`[^a-z0-9-]+`).ReplaceAllString(slug, "")
      slug = regexp.MustCompile(`-+`).ReplaceAllString(slug, "-")
      slug = strings.Trim(slug, "-")
      return slug
  }
  ```

**Afternoon: Create Standalone Functions**
- [ ] **Create validation/standalone.go**
  ```go
  // common/validation/standalone.go - NEW FILE
  package validation
  
  import (
      "net/mail"
      "regexp"
      "strings"
  )
  
  // Standalone functions for backward compatibility
  
  // IsValidEmail validates email format
  func IsValidEmail(email string) bool {
      if email == "" {
          return false
      }
      _, err := mail.ParseAddress(email)
      return err == nil
  }
  
  // IsValidPhone validates phone format
  func IsValidPhone(phone string) bool {
      if phone == "" {
          return false
      }
      
      phoneRegex := regexp.MustCompile(`[\s\-\(\)]`)
      cleaned := phoneRegex.ReplaceAllString(phone, "")
      
      // International format: + followed by 1-15 digits
      if matched, _ := regexp.MatchString(`^\+[1-9]\d{1,14}$`, cleaned); matched {
          return true
      }
      
      // Local format: 8-15 digits
      if matched, _ := regexp.MatchString(`^\d{8,15}$`, cleaned); matched {
          return true
      }
      
      return false
  }
  
  // IsValidURL validates URL format
  func IsValidURL(url string) bool {
      if url == "" {
          return false
      }
      return strings.HasPrefix(url, "http://") || strings.HasPrefix(url, "https://")
  }
  
  // IsValidPassword validates password strength
  func IsValidPassword(password string) (bool, string) {
      return isValidPassword(password)
  }
  
  // GenerateSlug generates URL-friendly slug from text
  func GenerateSlug(text string) string {
      return generateSlug(text)
  }
  
  // ValidateRequired checks if required fields are not empty
  func ValidateRequired(fields map[string]string) (bool, string) {
      for name, value := range fields {
          if strings.TrimSpace(value) == "" {
              return false, name + " is required"
          }
      }
      return true, ""
  }
  ```

#### **Day 3: Create Deprecation Bridge (8 hours)**

**Morning: Create Bridge Package**
- [ ] **Create utils/validation/deprecated.go**
  ```go
  // common/utils/validation/deprecated.go - NEW FILE
  package validation
  
  import (
      "gitlab.com/ta-microservices/common/validation"
  )
  
  // Deprecated: Use validation.IsValidEmail instead.
  // This function will be removed in v2.0.0.
  // Migration: Replace utils_validation.IsValidEmail(email) with validation.IsValidEmail(email)
  func IsValidEmail(email string) bool {
      return validation.IsValidEmail(email)
  }
  
  // Deprecated: Use validation.IsValidPhone instead.
  func IsValidPhone(phone string) bool {
      return validation.IsValidPhone(phone)
  }
  
  // Deprecated: Use validation.IsValidURL instead.
  func IsValidURL(url string) bool {
      return validation.IsValidURL(url)
  }
  
  // Deprecated: Use validation.IsValidPassword instead.
  func IsValidPassword(password string) (bool, string) {
      return validation.IsValidPassword(password)
  }
  
  // Deprecated: Use validation.GenerateSlug instead.
  func GenerateSlug(text string) string {
      return validation.GenerateSlug(text)
  }
  
  // Deprecated: Use validation.ValidateRequired instead.
  func ValidateRequired(fields map[string]string) (bool, string) {
      return validation.ValidateRequired(fields)
  }
  ```

**Afternoon: Add go-playground Bridge**
- [ ] **Create validation/playground.go**
  ```go
  // common/validation/playground.go - NEW FILE
  package validation
  
  import (
      "github.com/go-playground/validator/v10"
      utils_validation "gitlab.com/ta-microservices/common/utils/validation"
  )
  
  // NewGoPlaygroundValidator creates a new go-playground validator
  // This bridges the gap between fluent API and go-playground validation
  func NewGoPlaygroundValidator() *validator.Validate {
      return utils_validation.NewValidator()
  }
  
  // ParseGoPlaygroundError converts go-playground errors to ValidationError
  func ParseGoPlaygroundError(err error) []ValidationError {
      return utils_validation.ParseValidationError(err)
  }
  
  // ValidateStruct validates a struct using go-playground validator
  func ValidateStruct(s interface{}) error {
      validator := NewGoPlaygroundValidator()
      return validator.Struct(s)
  }
  ```

#### **Day 4: Testing & Documentation (8 hours)**

**Morning: Create Comprehensive Tests**
- [ ] **Create utils/pagination/pagination_test.go**
  ```go
  // Test all new methods
  func TestPaginator_GetOffset(t *testing.T) {
      paginator := NewPaginator(&PaginationRequest{Page: 3, PageSize: 10})
      assert.Equal(t, 20, paginator.GetOffset())
  }
  
  func TestPaginator_SetTotal_WithFromTo(t *testing.T) {
      paginator := NewPaginator(&PaginationRequest{Page: 2, PageSize: 10})
      response := paginator.SetTotal(25)
      
      assert.Equal(t, 11, response.From)
      assert.Equal(t, 20, response.To)
      assert.True(t, response.HasNext)
      assert.True(t, response.HasPrev)
  }
  ```

- [ ] **Create validation/password_test.go**
- [ ] **Create validation/standalone_test.go**

**Afternoon: Update Documentation**
- [ ] **Update utils/pagination/README.md**
- [ ] **Update validation/README.md**
- [ ] **Create migration guides**

#### **Day 5: Service Migration (8 hours)**

**Morning: Update Repository Package**
- [ ] **Update common/repository/ to use unified pagination**
  ```go
  // Update Filter struct to use utils/pagination
  type Filter struct {
      Pagination *pagination.PaginationRequest `json:"pagination"`
      Where      map[string][]interface{}      `json:"where"`
      Joins      []string                      `json:"joins"`
      OrderBy    []string                      `json:"order_by"`
      Search     string                        `json:"search"`
      Preloads   []string                      `json:"preloads"`
  }
  ```

**Afternoon: Test Integration**
- [ ] **Test with existing services**
- [ ] **Verify backward compatibility**
- [ ] **Update service examples**

---

### **Week 2: Service Updates & Finalization (40 hours)**

#### **Day 6-8: Service-by-Service Updates (24 hours)**

**Target Services for Pagination Updates:**
- [ ] **User Service**: Update pagination usage
- [ ] **Order Service**: Update pagination usage  
- [ ] **Product Service**: Update pagination usage
- [ ] **Customer Service**: Update pagination usage

**Target Services for Validation Updates:**
- [ ] **Auth Service**: Update validation usage
- [ ] **User Service**: Update validation usage
- [ ] **Payment Service**: Update validation usage

#### **Day 9: Deprecation Warnings (8 hours)**

**Morning: Add Deprecation Logging**
- [ ] **Add deprecation warnings to bridge functions**
  ```go
  func IsValidEmail(email string) bool {
      log.Warn("utils/validation.IsValidEmail is deprecated, use validation.IsValidEmail instead")
      return validation.IsValidEmail(email)
  }
  ```

**Afternoon: Create Migration Scripts**
- [ ] **Create automated migration scripts**
- [ ] **Create migration documentation**

#### **Day 10: Final Testing & Documentation (8 hours)**

**Morning: Comprehensive Testing**
- [ ] **Run full test suite**
- [ ] **Test all services with new APIs**
- [ ] **Performance testing**

**Afternoon: Documentation Finalization**
- [ ] **Complete migration guides**
- [ ] **Update CHANGELOG.md**
- [ ] **Create deprecation timeline**

---

## 🎯 **SUCCESS CRITERIA**

### **Code Reduction**
- [ ] **Remove 2 duplicate pagination implementations** (filter/pagination_filter.go, filter/paging.go)
- [ ] **Consolidate validation into single package** (deprecate utils/validation/)
- [ ] **Reduce utils/ modules by 15%**

### **API Consistency**
- [ ] **Single pagination API** across all services
- [ ] **Unified validation patterns** with backward compatibility
- [ ] **Consistent error handling** in all consolidated modules

### **Backward Compatibility**
- [ ] **Bridge functions** work for 6 months
- [ ] **Deprecation warnings** in logs
- [ ] **Migration helpers** available
- [ ] **Zero breaking changes** in v1.5.0

### **Performance**
- [ ] **No performance regressions**
- [ ] **Reduced memory usage** (fewer duplicate implementations)
- [ ] **Faster compilation** (fewer packages)

---

## 📊 **TRACKING METRICS**

### **Daily Progress**
```bash
# Check consolidation progress
find common/utils -name "*.go" | wc -l  # Track file count reduction
grep -r "Deprecated:" common/utils/      # Track deprecation markers
go test ./common/utils/... -cover        # Track test coverage
```

### **Quality Gates**
- [ ] **All tests pass** with new consolidated APIs
- [ ] **80%+ test coverage** on new code
- [ ] **Zero linting errors** in consolidated modules
- [ ] **All services compile** with bridge functions

### **Migration Tracking**
- [ ] **Services using old pagination**: Track and update
- [ ] **Services using old validation**: Track and update  
- [ ] **Deprecation warnings**: Monitor and reduce

---

## 🚨 **RISK MITIGATION**

### **Breaking Changes**
- **Risk**: Services break during migration
- **Mitigation**: Bridge functions + gradual migration

### **Performance Impact**
- **Risk**: Bridge functions add overhead
- **Mitigation**: Benchmark tests + optimization

### **Timeline Pressure**
- **Risk**: 2-week timeline too aggressive
- **Mitigation**: Focus on high-impact consolidations first

---

**Implementation Plan Created**: December 27, 2025  
**Target Completion**: January 10, 2026 (2 weeks)  
**Priority**: High (blocks v1.5.0 release)  
**Impact**: 40% reduction in duplicate code