# Search Service - Product Visibility Filtering Implementation

**Service:** Search Service  
**Feature:** Filter products by visibility rules in ListProducts/SearchProducts  
**Created:** 2025-01-17  
**Last Updated:** 2026-01-18  
**Status:** 🟡 Verified core ES visibility_rules indexing + pre-filter; post-filter integration claims should be re-checked per endpoint  
**Priority:** High

---

## 📋 Overview

Implement product visibility filtering in Search Service for ListProducts and SearchProducts endpoints. This follows the architecture pattern where Search Service handles read model and filtering logic.

### Why Search Service?

- ✅ Search Service uses Elasticsearch read model (optimized for filtering)
- ✅ Search Service already handles filtering (warehouse, price, stock, etc.)
- ✅ Catalog Service should only handle GetProduct (single product detail)
- ✅ Better separation of concerns (read vs write model)

---

## 🏗️ Architecture

### Current Flow
```
Frontend → Catalog Service → ListProducts/SearchProducts
                              ↓
                         Filter by visibility rules
```

### Proposed Flow
```
Frontend → Search Service → SearchProducts (Elasticsearch)
                              ↓
                         Post-filter by visibility rules (Catalog Service)
```

**Note**: Visibility rules evaluation requires customer context (age, groups, location, verifications), so we need to:
1. Search in Elasticsearch (fast, optimized)
2. Post-filter results using Catalog Service visibility rule engine (evaluate rules with customer context)

---

## 📝 Implementation Plan

### Phase 1: Integration Setup ✅ COMPLETED

- [x] **Catalog Service Client in Search Service** ✅
  - [x] Create `search/internal/client/catalog_visibility_client.go`
  - [x] Add method: `BatchCheckProductVisibility(ctx, productIDs, customerCtx)`
  - [x] Handle errors gracefully (fail open)
  - **Files**: `search/internal/client/catalog_visibility_client.go`, `search/internal/client/visibility_provider.go`

- [x] **Customer Context Builder** ✅
  - [x] Create customer context builder in Search Service
  - [x] Extract customer context from headers
  - **Files**: `search/internal/service/visibility_helper.go`

### Phase 2: Post-Filtering Implementation ✅ COMPLETED

- [x] **Search Service Integration** ✅
  - [x] Add visibility filtering to `SearchProducts` endpoint
  - [x] Post-filter results after Elasticsearch query
  - [x] Batch visibility checks for performance
  - **Files**: `search/internal/service/search.go` - Updated SearchProducts method

- [ ] **Performance Optimization** ⚠️ OPTIONAL
  - [ ] Cache visibility results per customer/product (can be added later)
  - [x] Batch evaluate multiple products ✅
  - [ ] Use goroutines for parallel evaluation (can be added later)

### Phase 3: Elasticsearch Enhancement ✅ COMPLETED

- [x] **Index Visibility Rules Metadata** ✅
  - [x] Add `visibility_rules` field to Elasticsearch mapping
  - [x] Index rule types and basic info (not full evaluation)
  - [x] Use for pre-filtering (e.g., filter out products with hard age restrictions if customer age < min_age)
  - **Files**: 
    - `search/internal/data/elasticsearch/mapping.go` - Added visibility_rules nested mapping
    - `search/internal/data/elasticsearch/product_index.go` - Added visibility rules indexing
    - `search/internal/biz/product_index.go` - Added VisibilityRuleMetadata struct

- [x] **Smart Pre-filtering** ✅
  - [x] Pre-filter products with simple rules (e.g., customer_group restrictions)
  - [x] Post-filter products with complex rules (e.g., custom rules, verification requirements)
  - **Files**: 
    - `search/internal/data/elasticsearch/visibility_filter.go` - Pre-filtering logic
    - `search/internal/data/elasticsearch/search.go` - Integrated pre-filtering into buildQuery
    - `search/internal/service/search.go` - Extract customer context for pre-filtering
    - `search/internal/biz/search.go` - Added CustomerContext to SearchQuery

**Note**: Visibility rules metadata needs to be populated from Catalog Service events. See `search/docs/VISIBILITY_RULES_INDEXING.md` for integration details.

---

## 🔧 Implementation Details

### Option 1: Post-Filtering (Recommended)

**Approach**: Search in Elasticsearch first, then filter results using Catalog Service visibility rule engine.

**Pros**:
- ✅ Simple to implement
- ✅ Full rule evaluation with customer context
- ✅ No need to index complex rules in Elasticsearch

**Cons**:
- ⚠️ Requires additional API call to Catalog Service
- ⚠️ May filter out products after search (less efficient)

**Implementation**:
```go
// In Search Service
func (s *SearchService) SearchProducts(ctx context.Context, req *pb.SearchProductsRequest) (*pb.SearchProductsResponse, error) {
    // 1. Search in Elasticsearch
    results, err := s.searchUsecase.SearchProducts(ctx, bizReq)
    
    // 2. Extract customer context from headers
    customerCtx := ExtractCustomerContextFromHeaders(ctx, s.customerClient)
    
    // 3. Post-filter by visibility rules
    visibleProducts := []*pb.ProductResult{}
    for _, product := range results.Hits {
        // Check visibility using Catalog Service
        visible, err := s.catalogClient.CheckProductVisibility(ctx, product.ID, customerCtx)
        if err == nil && visible {
            visibleProducts = append(visibleProducts, product)
        }
    }
    
    return &pb.SearchProductsResponse{
        Products: visibleProducts,
        Total: int32(len(visibleProducts)),
    }, nil
}
```

### Option 2: Hybrid (Pre-filter + Post-filter)

**Approach**: Pre-filter simple rules in Elasticsearch, post-filter complex rules using Catalog Service.

**Pros**:
- ✅ Better performance (fewer products to post-filter)
- ✅ Leverages Elasticsearch filtering capabilities

**Cons**:
- ⚠️ More complex implementation
- ⚠️ Need to index visibility rules metadata

**Implementation**:
1. Index visibility rules metadata in Elasticsearch (rule types, basic conditions)
2. Pre-filter in Elasticsearch query (e.g., customer_group restrictions)
3. Post-filter complex rules using Catalog Service

---

## 📊 Performance Considerations

### Batch Visibility Checks

Instead of checking visibility one-by-one:
```go
// Batch check visibility for multiple products
visibleMap, err := s.catalogClient.BatchCheckProductVisibility(ctx, productIDs, customerCtx)
```

### Caching Strategy

- Cache visibility results per customer/product combination
- TTL: 5 minutes (rules don't change frequently)
- Cache key: `visibility:{productID}:{customerID}`

### Performance Targets

- Post-filtering overhead: < 50ms for 20 products
- Batch evaluation: < 100ms for 100 products
- Cache hit rate: > 80%

---

## 🔗 Integration Points

### Catalog Service API

**New Endpoint** (to be added):
```http
POST /api/v1/catalog/products/visibility/check-batch
Content-Type: application/json

{
  "product_ids": ["product-1", "product-2", "product-3"],
  "customer_context": {
    "customer_id": "customer-123",
    "age": 25,
    "groups": ["VIP"],
    "location": {
      "country": "US",
      "region": "CA"
    },
    "verifications": {
      "age": "verified"
    }
  }
}

Response:
{
  "results": {
    "product-1": {"visible": true},
    "product-2": {"visible": false, "reason": "age_restriction"},
    "product-3": {"visible": true}
  }
}
```

---

## ✅ Implementation Checklist

### Phase 1: Integration Setup ✅ COMPLETED
- [x] Create Catalog Service client in Search Service ✅
  - **File**: `search/internal/client/catalog_visibility_client.go`
  - **Provider**: `search/internal/client/visibility_provider.go`
- [x] Add customer context builder ✅
  - **File**: `search/internal/service/visibility_helper.go`
- [x] Add header extraction helper ✅
  - **File**: `search/internal/service/visibility_helper.go` - `ExtractCustomerContextFromHeaders`

### Phase 2: Post-Filtering ✅ COMPLETED
- [x] Integrate visibility check in SearchProducts endpoint ✅
  - **File**: `search/internal/service/search.go` - Updated SearchProducts method
  - **Implementation**: Post-filter results after Elasticsearch query
- [x] Implement batch visibility checking ✅
  - **File**: `search/internal/client/catalog_visibility_client.go` - `BatchCheckProductVisibility`
  - **Integration**: Used in SearchProducts endpoint
- [x] Handle errors gracefully (fail open) ✅
  - **Implementation**: Fail open strategy - all products visible on error
- [ ] Add caching for visibility results ⚠️ OPTIONAL
  - **Status**: Can be added later for performance optimization
  - **Note**: Not critical for initial implementation

### Phase 3: Elasticsearch Enhancement ✅ COMPLETED
- [x] Add visibility_rules field to Elasticsearch mapping ✅
  - **File**: `search/internal/data/elasticsearch/mapping.go`
- [x] Index visibility rules metadata ✅
  - **File**: `search/internal/data/elasticsearch/product_index.go`
  - **Data Model**: `search/internal/biz/product_index.go` - `VisibilityRuleMetadata`
- [x] Implement pre-filtering for simple rules ✅
  - **File**: `search/internal/data/elasticsearch/visibility_filter.go`
  - **Integration**: `search/internal/data/elasticsearch/search.go` - buildQuery
- [x] Pre-filter products with hard enforcement rules ✅
  - Age restrictions (if customer age < min_age)
  - Customer group restrictions (if group denied)
  - Geographic restrictions (if location restricted)

### Phase 4: Performance Optimization ⚠️ OPTIONAL
- [x] Optimize batch evaluation ✅
  - **Implementation**: Batch API used for multiple products
- [ ] Add caching for visibility results (optional)
- [ ] Add metrics for visibility filtering performance (optional)
- [ ] Monitor cache hit rates (optional)

---

## 📝 Notes

- **Fail Open Strategy**: If visibility check fails, allow product to be visible (better UX than hiding products on error)
- **Caching**: Cache visibility results to reduce Catalog Service calls
- **Batch Processing**: Always use batch API for multiple products
- **Customer Context**: Extract from headers (X-User-ID, X-Customer-Age, etc.)

---

**Last Updated**: 2025-01-17  
**Status**: ✅ COMPLETED - All phases implemented

## Summary

✅ **Phase 1**: Integration Setup - COMPLETED
✅ **Phase 2**: Post-Filtering Implementation - COMPLETED  
✅ **Phase 3**: Elasticsearch Enhancement - COMPLETED

### Implementation Complete

- ✅ Catalog visibility client with batch check API
- ✅ Customer context builder
- ✅ Post-filtering in SearchProducts endpoint
- ✅ Elasticsearch mapping for visibility rules
- ✅ Pre-filtering logic for simple rules
- ✅ Hybrid filtering (pre-filter + post-filter)

### Next Steps (Optional)

1. **Catalog Service Event Integration**: Include visibility rules metadata in product events
2. **Visibility Rule Event Handler**: Handle visibility rule change events
3. **Sync Worker Enhancement**: Fetch visibility rules when indexing products
4. **Caching**: Add caching layer for visibility results (optional performance optimization)

See `search/docs/VISIBILITY_RULES_INDEXING.md` for detailed integration guide.

