# 🔍 Common Utils Consolidation Analysis

**Date**: December 27, 2025  
**Scope**: Review overlapping functionality in common/utils modules  
**Goal**: Identify and consolidate duplicate logic, standardize patterns

---

## 📊 **CRITICAL OVERLAPS IDENTIFIED**

### 🚨 **MAJOR DUPLICATION: Pagination Logic (3 modules)**

#### **Affected Modules:**
1. `common/utils/pagination/` - Modern pagination (clean, simple)
2. `common/utils/filter/pagination_filter.go` - Complex pagination with ordering
3. `common/utils/filter/paging.go` - Simple response struct

#### **Overlap Analysis:**

| Feature | utils/pagination | filter/pagination_filter | filter/paging |
|---------|------------------|---------------------------|---------------|
| **Page Calculation** | ✅ `GetPage()` | ✅ `GetPage()` | ❌ No logic |
| **Offset Calculation** | ✅ `GetOffset()` (missing) | ✅ `GetOffset()` | ❌ No logic |
| **Limit/PageSize** | ✅ `GetPageSize()` | ✅ `GetPerPage()` | ✅ `PerPage` field |
| **Total Pages** | ✅ `SetTotal()` | ❌ No calculation | ✅ `LastPage` field |
| **Has Next/Prev** | ✅ `HasNext/HasPrev` | ❌ No logic | ❌ No logic |
| **Order By Support** | ✅ `GetSort/GetOrder` | ✅ Complex ordering | ❌ None |
| **Validation** | ✅ Built-in | ✅ Built-in | ❌ None |
| **From/To Calculation** | ❌ Missing | ❌ Missing | ✅ `From/To` fields |

#### **Code Duplication Examples:**

```go
// utils/pagination/pagination.go - MISSING GetOffset()
func (p *Paginator) GetPage() int {
    return p.request.Page
}

// utils/filter/pagination_filter.go - HAS GetOffset()
func (f *PaginationFilter) GetOffset() int {
    return (f.GetPage() - 1) * f.GetPerPage()
}

// filter/paging.go - HAS From/To calculation
type Paging struct {
    From        int `json:"from"`
    To          int `json:"to"`
}
```

**🎯 RECOMMENDATION**: Enhance `utils/pagination/` with missing features, then consolidate

---

### 🚨 **MAJOR DUPLICATION: Validation Logic (2 modules)**

#### **Affected Modules:**
1. `common/validation/` - Fluent validation API (NEW, comprehensive)
2. `common/utils/validation/` - go-playground wrapper + standalone functions (LEGACY)

#### **Overlap Analysis:**

| Feature | validation/ (NEW) | utils/validation/ (LEGACY) |
|---------|-------------------|----------------------------|
| **Email Validation** | ✅ `Email()` method | ✅ `IsValidEmail()` function |
| **Phone Validation** | ✅ `Phone()` method | ✅ `IsValidPhone()` function |
| **URL Validation** | ✅ `URL()` method | ✅ `IsValidURL()` function |
| **Password Validation** | ❌ Not implemented | ✅ `IsValidPassword()` function |
| **Required Validation** | ✅ `Required()` method | ✅ `ValidateRequired()` function |
| **Slug Generation** | ❌ Not implemented | ✅ `GenerateSlug()` function |
| **Fluent API** | ✅ Chainable methods | ❌ Individual functions |
| **Error Handling** | ✅ Structured errors | ✅ go-playground errors |
| **Business Validators** | ✅ 8 predefined validators | ❌ None |
| **go-playground Integration** | ❌ None | ✅ Full wrapper |

#### **Code Duplication Examples:**

```go
// validation/validator.go (NEW) - Fluent API
func (v *Validator) Email(field string, value string) *Validator {
    if value != "" {
        if _, err := mail.ParseAddress(value); err != nil {
            v.addError(field, "INVALID_EMAIL", 
                fmt.Sprintf("%s must be a valid email address", field), value)
        }
    }
    return v
}

// utils/validation/validators.go (LEGACY) - Standalone function
func IsValidEmail(email string) bool {
    if email == "" {
        return false
    }
    return emailRegex.MatchString(email)
}
```

**🎯 RECOMMENDATION**: Migrate missing functions to `validation/`, keep go-playground bridge

---

### 🚨 **MODERATE DUPLICATION: Query Building Logic**

#### **Affected Modules:**
1. `common/utils/query/` - JSONB query helpers
2. `common/utils/filter/` - Complex filter building
3. `common/repository/` - Generic repository with Filter support

#### **Overlap Analysis:**

| Feature | utils/query | utils/filter | repository |
|---------|-------------|--------------|------------|
| **JSONB Queries** | ✅ Specialized | ❌ None | ❌ None |
| **WHERE Conditions** | ❌ None | ✅ `Where` map | ✅ `Condition` struct |
| **JOIN Support** | ❌ None | ✅ `Joins` struct | ❌ None |
| **ORDER BY** | ❌ None | ✅ `BasicOrder` | ✅ Sort/Order fields |
| **Filtering** | ❌ None | ✅ Complex filters | ✅ `Filter` struct |

**🎯 RECOMMENDATION**: Keep specialized, but standardize interfaces

---

## 📋 **DETAILED CONSOLIDATION PLAN**

### **Phase 1: Pagination Consolidation (High Priority)**

#### **Target Architecture:**
```go
// utils/pagination/ - ENHANCED SINGLE SOURCE OF TRUTH
package pagination

// Unified pagination request
type Request struct {
    Page     int    `json:"page"`
    PageSize int    `json:"page_size"`
    Sort     string `json:"sort"`
    Order    string `json:"order"`
}

// Unified pagination response  
type Response struct {
    Page       int   `json:"page"`
    PageSize   int   `json:"page_size"`
    Total      int64 `json:"total"`
    TotalPages int   `json:"total_pages"`
    HasNext    bool  `json:"has_next"`
    HasPrev    bool  `json:"has_prev"`
    From       int   `json:"from"`        // ADD: Missing from current
    To         int   `json:"to"`          // ADD: Missing from current
}

// Enhanced paginator with all missing methods
type Paginator struct {
    request *Request
    total   int64    // ADD: Store total for calculations
}

// EXISTING methods (keep as-is)
func (p *Paginator) GetPage() int
func (p *Paginator) GetPageSize() int  
func (p *Paginator) GetSort() string
func (p *Paginator) GetOrder() string
func (p *Paginator) SetTotal(total int64) *Response

// ADD: Missing methods from filter/pagination_filter.go
func (p *Paginator) GetOffset() int {
    return (p.GetPage() - 1) * p.GetPageSize()
}

func (p *Paginator) GetLimit() int {
    return p.GetPageSize()
}

func (p *Paginator) GetPerPage() int {  // Alias for compatibility
    return p.GetPageSize()
}

func (p *Paginator) GetCurrentPage() int {  // Alias for compatibility
    return p.GetPage()
}

// ADD: From/To calculation from filter/paging.go
func (p *Paginator) GetFrom() int {
    if p.total == 0 { return 0 }
    return p.GetOffset() + 1
}

func (p *Paginator) GetTo() int {
    from := p.GetFrom()
    if from == 0 { return 0 }
    to := from + p.GetPageSize() - 1
    if int64(to) > p.total { to = int(p.total) }
    return to
}

// ADD: Enhanced SetTotal with From/To
func (p *Paginator) SetTotal(total int64) *Response {
    p.total = total  // Store for From/To calculations
    
    page := p.GetPage()
    pageSize := p.GetPageSize()
    totalPages := int(math.Ceil(float64(total) / float64(pageSize)))
    
    return &Response{
        Page:       page,
        PageSize:   pageSize,
        Total:      total,
        TotalPages: totalPages,
        HasNext:    page < totalPages,
        HasPrev:    page > 1,
        From:       p.GetFrom(),  // ADD
        To:         p.GetTo(),    // ADD
    }
}
```

#### **Migration Steps:**
1. **Enhance utils/pagination/** with missing features from filter/
2. **Create migration helpers** for existing code
3. **Deprecate filter/pagination_filter.go** and filter/paging.go
4. **Update all services** to use unified pagination

#### **Breaking Changes:**
```go
// BEFORE (filter/pagination_filter.go)
filter := NewPaginationFilter(page, perPage, orderBy)
limit := filter.GetLimit()
offset := filter.GetOffset()

// AFTER (utils/pagination/)
paginator := pagination.NewPaginator(&pagination.Request{
    Page: page, PageSize: perPage, Sort: sort, Order: order,
})
limit := paginator.GetPageSize()
offset := paginator.GetOffset()
```

### **Phase 2: Validation Consolidation (High Priority)**

#### **Target Architecture:**
```go
// validation/ - PRIMARY VALIDATION SYSTEM (Enhanced)
package validation

// Keep existing fluent API as primary
type Validator struct {
    errors []ValidationError
}

// EXISTING methods (keep as-is)
func (v *Validator) Required(field string, value interface{}) *Validator
func (v *Validator) Email(field string, value string) *Validator
func (v *Validator) Phone(field string, value string) *Validator
func (v *Validator) URL(field string, value string) *Validator
// ... all existing methods

// ADD: Missing methods from utils/validation/validators.go
func (v *Validator) Password(field string, value string) *Validator {
    if value != "" {
        if valid, message := isValidPassword(value); !valid {
            v.addError(field, "INVALID_PASSWORD", message, value)
        }
    }
    return v
}

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

// ADD: Standalone functions for backward compatibility
func IsValidEmail(email string) bool {
    _, err := mail.ParseAddress(email)
    return err == nil && email != ""
}

func IsValidPhone(phone string) bool {
    if phone == "" { return false }
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

func IsValidURL(url string) bool {
    return url != "" && (strings.HasPrefix(url, "http://") || strings.HasPrefix(url, "https://"))
}

func IsValidPassword(password string) (bool, string) {
    return isValidPassword(password)
}

func GenerateSlug(text string) string {
    return generateSlug(text)
}

func ValidateRequired(fields map[string]string) (bool, string) {
    for name, value := range fields {
        if strings.TrimSpace(value) == "" {
            return false, name + " is required"
        }
    }
    return true, ""
}

// ADD: go-playground bridge functions
func NewGoPlaygroundValidator() *validator.Validate {
    return utils_validation.NewValidator()
}

func ParseGoPlaygroundError(err error) []ValidationError {
    return utils_validation.ParseValidationError(err)
}

// Internal helper functions (moved from utils/validation/)
func isValidPassword(password string) (bool, string) {
    if len(password) < 8 {
        return false, "password must be at least 8 characters"
    }
    if len(password) > 128 {
        return false, "password must be at most 128 characters"
    }
    // ... rest of validation logic from utils/validation/validators.go
}

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

#### **Migration Steps:**
1. **Move missing functions** from utils/validation/ to validation/
2. **Create bridge functions** for go-playground integration
3. **Deprecate utils/validation/** package
4. **Update all services** to use primary validation/

#### **Backward Compatibility:**
```go
// utils/validation/ - DEPRECATED BRIDGE
package validation

import "gitlab.com/ta-microservices/common/validation"

// Deprecated: Use validation.IsValidEmail instead
func IsValidEmail(email string) bool {
    return validation.IsValidEmail(email)
}
```

### **Phase 3: Query/Filter Standardization (Medium Priority)**

#### **Target Architecture:**
```go
// utils/query/ - JSONB SPECIALISTS (Keep as-is)
package query

// Keep existing JSONB functions
func GetConditionsJsonB(strs []string) string
func QueryArrayJsonB(filed string, strs []string) string
func QueryJsonB(filed string, str string) string

// utils/filter/ - COMPLEX FILTERING (Enhance)
package filter

// Standardize filter interface
type Filter interface {
    GetWhere() map[string][]interface{}
    GetJoins() []Join
    GetOrderBy() []string
    GetLimit() int32
    GetOffset() int32
    GetSelect() string
    GetGroupBy() string
}

// Unified filter builder
type Builder struct {
    where    map[string][]interface{}
    joins    []Join
    orderBy  []string
    groupBy  []string
    limit    int32
    offset   int32
    selectFields string
}

// repository/ - CONSUMER (Update interface)
package repository

// Use standardized Filter interface
type Filter struct {
    Pagination *pagination.Request
    Where      map[string][]interface{}
    Joins      []filter.Join
    OrderBy    []string
    Search     string
    Preloads   []string
}
```

---

## 🎯 **CONSOLIDATION CHECKLIST**

### **Week 1: Pagination Consolidation**

#### **Day 1: Analysis & Design**
- [ ] **Map all pagination usage** across services
  ```bash
  grep -r "PaginationFilter\|Paging\|GetPage\|GetOffset" --include="*.go" .
  ```
- [ ] **Design unified pagination interface**
- [ ] **Create migration plan** for each service
- [ ] **Design backward compatibility layer**

#### **Day 2: Implementation**
- [ ] **Enhance utils/pagination/ with missing features**
  ```go
  // Add missing methods to pagination.go
  
  // GetOffset calculates the offset for database queries
  func (p *Paginator) GetOffset() int {
      return (p.GetPage() - 1) * p.GetPageSize()
  }
  
  // GetLimit returns the limit (same as page size)
  func (p *Paginator) GetLimit() int {
      return p.GetPageSize()
  }
  
  // Compatibility aliases for existing code
  func (p *Paginator) GetPerPage() int {
      return p.GetPageSize()
  }
  
  func (p *Paginator) GetCurrentPage() int {
      return p.GetPage()
  }
  
  // Store total for From/To calculations
  type Paginator struct {
      request *PaginationRequest
      total   int64
  }
  
  // Enhanced SetTotal with From/To calculation
  func (p *Paginator) SetTotal(total int64) *PaginationResponse {
      p.total = total
      
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
      
      // Add From/To calculation
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
  
  // Add From/To fields to PaginationResponse
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

- [ ] **Add protobuf conversion helpers**
  ```go
  func FromProtoRequest(req *commonV1.PaginationRequest) *Request {
      return &Request{
          Page:     req.Page,
          PageSize: req.Limit,
          Sort:     req.Sort,
          Order:    req.Order,
      }
  }
  
  func (r *Response) ToProto() *commonV1.Pagination {
      return &commonV1.Pagination{
          Page:       r.Page,
          Limit:      r.PageSize,
          Total:      r.Total,
          TotalPages: r.TotalPages,
          HasNext:    r.HasNext,
          HasPrev:    r.HasPrev,
      }
  }
  ```

#### **Day 3: Migration & Testing**
- [ ] **Create migration helpers**
  ```go
  // migration/pagination.go
  package migration
  
  import (
      "gitlab.com/ta-microservices/common/utils/filter"
      "gitlab.com/ta-microservices/common/utils/pagination"
  )
  
  // MigratePaginationFilter converts old filter to new paginator
  func MigratePaginationFilter(oldFilter *filter.PaginationFilter) *pagination.Paginator {
      req := &pagination.Request{
          Page:     int32(oldFilter.GetPage()),
          PageSize: int32(oldFilter.GetPerPage()),
      }
      return pagination.NewPaginator(req)
  }
  ```

- [ ] **Add comprehensive tests**
- [ ] **Update documentation**

#### **Day 4-5: Service Updates**
- [ ] **Update repository/ to use unified pagination**
- [ ] **Update all services one by one**
- [ ] **Test backward compatibility**

### **Week 2: Validation Consolidation**

#### **Day 6: Validation Enhancement**
- [ ] **Move missing functions to validation/**
  ```go
  // validation/password.go - NEW FILE
  func (v *Validator) Password(field string, value string) *Validator {
      if value != "" {
          if valid, message := isValidPassword(value); !valid {
              v.addError(field, "INVALID_PASSWORD", message, value)
          }
      }
      return v
  }
  
  // Move complete logic from utils/validation/validators.go
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
  
  // validation/slug.go - NEW FILE
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
  
  // validation/standalone.go - NEW FILE for backward compatibility
  func IsValidEmail(email string) bool {
      _, err := mail.ParseAddress(email)
      return err == nil && email != ""
  }
  
  func IsValidPhone(phone string) bool {
      if phone == "" { return false }
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
  
  func IsValidURL(url string) bool {
      return url != "" && (strings.HasPrefix(url, "http://") || strings.HasPrefix(url, "https://"))
  }
  
  func IsValidPassword(password string) (bool, string) {
      return isValidPassword(password)
  }
  
  func GenerateSlug(text string) string {
      return generateSlug(text)
  }
  
  func ValidateRequired(fields map[string]string) (bool, string) {
      for name, value := range fields {
          if strings.TrimSpace(value) == "" {
              return false, name + " is required"
          }
      }
      return true, ""
  }
  ```

#### **Day 7: Bridge Layer**
- [ ] **Create deprecation bridge in utils/validation/**
  ```go
  // utils/validation/deprecated.go
  package validation
  
  import (
      "gitlab.com/ta-microservices/common/validation"
  )
  
  // Deprecated: Use validation.IsValidEmail instead.
  // This function will be removed in v2.0.0.
  func IsValidEmail(email string) bool {
      return validation.IsValidEmail(email)
  }
  
  // Deprecated: Use validation.IsValidPhone instead.
  func IsValidPhone(phone string) bool {
      return validation.IsValidPhone(phone)
  }
  ```

#### **Day 8: go-playground Integration**
- [ ] **Add go-playground bridge functions**
  ```go
  // validation/playground.go
  func NewGoPlaygroundValidator() *validator.Validate {
      return utils_validation.NewValidator()
  }
  
  func ParseGoPlaygroundError(err error) []ValidationError {
      return utils_validation.ParseValidationError(err)
  }
  ```

### **Week 3: Query/Filter Standardization**

#### **Day 9: Filter Interface Standardization**
- [ ] **Standardize filter interfaces**
- [ ] **Update repository/ Filter struct**
- [ ] **Create filter builders**

#### **Day 10: Documentation & Testing**
- [ ] **Complete comprehensive testing**
- [ ] **Update all documentation**
- [ ] **Create migration guides**

---

## 🚨 **BREAKING CHANGES SUMMARY**

### **High Impact Changes:**
1. **PaginationFilter → Paginator**: Method name changes, struct changes
2. **utils/validation → validation**: Package import changes
3. **Filter interfaces**: Method signature changes

### **Migration Timeline:**
- **v1.5.0**: Add new unified APIs, deprecate old ones
- **v1.6.0**: Remove deprecated APIs (6 months later)

### **Backward Compatibility:**
- **Bridge functions** for 6 months
- **Deprecation warnings** in logs
- **Migration helpers** provided
- **Comprehensive documentation**

---

## 📊 **SUCCESS METRICS**

### **Code Reduction:**
- **Remove 3 duplicate pagination implementations** → 1 unified
- **Remove 1 duplicate validation package** → 1 primary
- **Reduce utils/ modules from 25 → 22**

### **API Consistency:**
- **Standardized pagination** across all services
- **Unified validation** patterns
- **Consistent error handling**

### **Developer Experience:**
- **Single source of truth** for each functionality
- **Clear migration path** for existing code
- **Comprehensive documentation**

---

**Analysis Created**: December 27, 2025  
**Priority**: High (should be done before v1.5.0 release)  
**Estimated Effort**: 3 weeks (120 hours)  
**Impact**: Reduces code duplication by ~40% in utils/