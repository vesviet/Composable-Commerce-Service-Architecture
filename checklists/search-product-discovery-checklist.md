# 🔍 Search & Product Discovery Checklist

**Service:** Search Service  
**Created:** 2025-11-19  
**Priority:** 🟡 **Medium**

---

## 🎯 Overview

Search drives 30-60% of e-commerce revenue. Good search = higher conversions.

**Key Technologies:**
- Elasticsearch for full-text search
- Redis for autocomplete
- ML for personalized recommendations

---

## 1. Search Functionality

### Requirements

- [ ] **R1.1** Keyword search
- [ ] **R1.2** Auto-complete suggestions (min 3 chars)
- [ ] **R1.3** Spell correction ("iphone" → "iPhone")
- [ ] **R1.4** Synonym handling ("sneakers" = "shoes")
- [ ] **R1.5** Partial word matching ("lapt" → "laptop")
- [ ] **R1.6** Multi-language support
- [ ] **R1.7** Voice search support
- [ ] **R1.8** Search within results

### Implementation

```go
type SearchRequest struct {
    Query       string
    Filters     map[string][]string
    Sort        string
    Page        int
    PageSize    int
    UserID      string
}

type SearchResponse struct {
    Products        []Product
    Facets          map[string][]Facet
    Total           int
    Page            int
    PageSize        int
    SpellCorrection *string
    SearchTime      int  // ms
}

func (ss *SearchService) Search(ctx context.Context, req *SearchRequest) (*SearchResponse, error) {
    // Build Elasticsearch query
    esQuery := elastic.NewBoolQuery()
    
    // 1. Main search query
    if req.Query != "" {
        matchQuery := elastic.NewMultiMatchQuery(req.Query).
            Fields("name^3", "description^2", "brand", "category", "tags").
            Fuzziness("AUTO").
            Operator("and")
        
        esQuery = esQuery.Must(matchQuery)
    }
    
    // 2. Apply filters
    for field, values := range req.Filters {
        termsQuery := elastic.NewTermsQuery(field, toInterfaceSlice(values)...)
        esQuery = esQuery.Filter(termsQuery)
    }
    
    // 3. Only active products
    esQuery = esQuery.Filter(elastic.NewTermQuery("is_active", true))
    
    // 4. Build search service
    searchService := ss.esClient.Search().
        Index("products").
        Query(esQuery).
        From(req.Page * req.PageSize).
        Size(req.PageSize)
    
    // 5. Apply sorting
    switch req.Sort {
    case "price_asc":
        searchService = searchService.Sort("price", true)
    case "price_desc":
        searchService = searchService.Sort("price", false)
    case "newest":
        searchService = searchService.Sort("created_at", false)
    case "popular":
        searchService = searchService.Sort("sales_count", false)
    default:
        // Relevance scoring (default)
    }
    
    // 6. Add facets/aggregations
    searchService = searchService.
        Aggregation("brands", elastic.NewTermsAggregation().Field("brand")).
        Aggregation("categories", elastic.NewTermsAggregation().Field("category")).
        Aggregation("price_ranges", elastic.NewRangeAggregation().Field("price").
            AddRange(0, 50).
            AddRange(50, 100).
            AddRange(100, 200).
            AddRange(200, nil))
    
    // 7. Execute search
    result, err := searchService.Do(ctx)
    if err != nil {
        return nil, err
    }
    
    // 8. Parse results
    products := []Product{}
    for _, hit := range result.Hits.Hits {
        var product Product
        json.Unmarshal(hit.Source, &product)
        products = append(products, product)
    }
    
    // 9. Extract facets
    facets := ss.extractFacets(result.Aggregations)
    
    // 10. Spell correction
    var spellCorrection *string
    if result.Suggest != nil {
        spellCorrection = ss.getSpellCorrection(result.Suggest)
    }
    
    // 11. Log search
    ss.logSearch(ctx, req, len(products))
    
    return &SearchResponse{
        Products:        products,
        Facets:          facets,
        Total:           int(result.Hits.TotalHits.Value),
        Page:            req.Page,
        PageSize:        req.PageSize,
        SpellCorrection: spellCorrection,
        SearchTime:      int(result.TookInMillis),
    }, nil
}
```

---

## 2. Auto-Complete

### Requirements

- [ ] **R2.1** Product name suggestions
- [ ] **R2.2** Category suggestions
- [ ] **R2.3** Brand suggestions
- [ ] **R2.4** Popular searches
- [ ] **R2.5** Personalized suggestions
- [ ] **R2.6** Response time <100ms

### Implementation

```go
func (ss *SearchService) Autocomplete(ctx context.Context, query string, userID string) (*AutocompleteResponse, error) {
    if len(query) < 3 {
        return &AutocompleteResponse{Suggestions: []Suggestion{}}, nil
    }
    
    suggestions := []Suggestion{}
    
    // 1. Product suggestions (from Elasticsearch)
    productSuggestions, _ := ss.getProductSuggestions(ctx, query, 5)
    suggestions = append(suggestions, productSuggestions...)
    
    // 2. Category suggestions
    categorySuggestions, _ := ss.getCategorySuggestions(ctx, query, 3)
    suggestions = append(suggestions, categorySuggestions...)
    
    // 3. Popular searches (from Redis)
    popularSearches, _ := ss.getPopularSearches(ctx, query, 2)
    suggestions = append(suggestions, popularSearches...)
    
    // 4. Personalized suggestions (if logged in)
    if userID != "" {
        personalSuggestions, _ := ss.getPersonalizedSuggestions(ctx, userID, query, 2)
        suggestions = append(suggestions, personalSuggestions...)
    }
    
    return &AutocompleteResponse{
        Suggestions: suggestions,
    }, nil
}

func (ss *SearchService) getProductSuggestions(ctx context.Context, query string, limit int) ([]Suggestion, error) {
    searchService := ss.esClient.Search().
        Index("products").
        Query(elastic.NewPrefixQuery("name", query)).
        Size(limit)
    
    result, _ := searchService.Do(ctx)
    
    suggestions := []Suggestion{}
    for _, hit := range result.Hits.Hits {
        var product Product
        json.Unmarshal(hit.Source, &product)
        
        suggestions = append(suggestions, Suggestion{
            Type:  "product",
            Text:  product.Name,
            Image: product.MainImage,
            URL:   fmt.Sprintf("/products/%s", product.ID),
        })
    }
    
    return suggestions, nil
}
```

---

## 3. Search Filters

### Requirements

- [ ] **R3.1** Category filter
- [ ] **R3.2** Price range filter
- [ ] **R3.3** Brand filter
- [ ] **R3.4** Color filter
- [ ] **R3.5** Size filter
- [ ] **R3.6** Rating filter (4+ stars)
- [ ] **R3.7** Availability filter (in stock)
- [ ] **R3.8** Custom attributes
- [ ] **R3.9** Multiple filter combination

### Implementation

```go
type Filter struct {
    Field       string
    Label       string
    Type        string  // "terms", "range", "bool"
    Options     []FilterOption
    Selected    []string
}

type FilterOption struct {
    Value       string
    Label       string
    Count       int
    Selected    bool
}

func (ss *SearchService) GetFilters(ctx context.Context, query string) ([]Filter, error) {
    // Execute search with aggregations
    result, _ := ss.esClient.Search().
        Index("products").
        Query(elastic.NewQueryStringQuery(query)).
        Size(0).  // No products, just facets
        Aggregation("brands", elastic.NewTermsAggregation().Field("brand")).
        Aggregation("categories", elastic.NewTermsAggregation().Field("category")).
        Aggregation("colors", elastic.NewTermsAggregation().Field("color")).
        Aggregation("sizes", elastic.NewTermsAggregation().Field("size")).
        Aggregation("price_stats", elastic.NewStatsAggregation().Field("price")).
        Do(ctx)
    
    filters := []Filter{}
    
    // Brand filter
    if brands, found := result.Aggregations.Terms("brands"); found {
        brandFilter := Filter{
            Field: "brand",
            Label: "Brand",
            Type:  "terms",
            Options: []FilterOption{},
        }
        
        for _, bucket := range brands.Buckets {
            brandFilter.Options = append(brandFilter.Options, FilterOption{
                Value: bucket.Key.(string),
                Label: bucket.Key.(string),
                Count: int(bucket.DocCount),
            })
        }
        
        filters = append(filters, brandFilter)
    }
    
    // Price range filter
    if priceStats, found := result.Aggregations.Stats("price_stats"); found {
        priceFilter := Filter{
            Field: "price",
            Label: "Price",
            Type:  "range",
            Options: []FilterOption{
                {Value: "0-50", Label: "Under $50"},
                {Value: "50-100", Label: "$50 - $100"},
                {Value: "100-200", Label: "$100 - $200"},
                {Value: "200+", Label: "Over $200"},
            },
        }
        
        filters = append(filters, priceFilter)
    }
    
    return filters, nil
}
```

---

## 4. Product Recommendations

### Requirements

- [ ] **R4.1** Similar products (content-based)
- [ ] **R4.2** Frequently bought together (collaborative filtering)
- [ ] **R4.3** Customers also viewed
- [ ] **R4.4** You may also like (personalized)
- [ ] **R4.5** Recently viewed
- [ ] **R4.6** Trending products
- [ ] **R4.7** New arrivals
- [ ] **R4.8** Best sellers

### Implementation

```go
func (ss *SearchService) GetSimilarProducts(ctx context.Context, productID string, limit int) ([]Product, error) {
    // Get source product
    product, _ := ss.catalogClient.GetProduct(ctx, productID)
    
    // Build "More Like This" query
    mltQuery := elastic.NewMoreLikeThisQuery().
        Fields("name", "description", "category", "tags").
        LikeItems(elastic.NewMoreLikeThisQueryItem().
            Index("products").
            Id(productID)).
        MinTermFreq(1).
        MaxQueryTerms(12)
    
    // Execute search
    result, _ := ss.esClient.Search().
        Index("products").
        Query(mltQuery).
        Size(limit).
        Do(ctx)
    
    products := ss.parseProducts(result)
    
    return products, nil
}

func (ss *SearchService) GetFrequentlyBoughtTogether(ctx context.Context, productID string) ([]Product, error) {
    // Query analytics database for frequently co-purchased products
    relatedIDs, _ := ss.analyticsClient.GetCoOccurrence(ctx, productID, 5)
    
    products := []Product{}
    for _, id := range relatedIDs {
        product, err := ss.catalogClient.GetProduct(ctx, id)
        if err == nil {
            products = append(products, product)
        }
    }
    
    return products, nil
}

func (ss *SearchService) GetPersonalizedRecommendations(ctx context.Context, userID string, limit int) ([]Product, error) {
    // Get user's browsing history
    history, _ := ss.getUserBrowsingHistory(ctx, userID)
    
    // Get user's purchase history
    purchases, _ := ss.orderClient.GetCustomerOrders(ctx, userID)
    
    // Build user profile
    profile := ss.buildUserProfile(history, purchases)
    
    // Use collaborative filtering or ML model
    recommendations, _ := ss.mlClient.GetRecommendations(ctx, profile, limit)
    
    return recommendations, nil
}
```

---

## 5. Search Analytics

### Requirements

- [ ] **R5.1** Track search queries
- [ ] **R5.2** Track zero-result searches
- [ ] **R5.3** Track click-through rate
- [ ] **R5.4** Track conversion rate per query
- [ ] **R5.5** Popular searches dashboard
- [ ] **R5.6** Search trends
- [ ] **R5.7** A/B testing for relevance

### Implementation

```go
type SearchAnalytics struct {
    Query           string
    UserID          string
    ResultsCount    int
    ClickedProduct  *string
    Converted       bool
    SearchTime      int
    Timestamp       time.Time
}

func (ss *SearchService) logSearch(ctx context.Context, req *SearchRequest, resultsCount int) {
    analytics := &SearchAnalytics{
        Query:        req.Query,
        UserID:       req.UserID,
        ResultsCount: resultsCount,
        SearchTime:   0,  // Set by middleware
        Timestamp:    time.Now(),
    }
    
    ss.analyticsRepo.LogSearch(ctx, analytics)
    
    // Track zero results
    if resultsCount == 0 {
        ss.alertZeroResults(req.Query)
    }
}

func (ss *SearchService) TrackProductClick(ctx context.Context, searchID, productID string) error {
    return ss.analyticsRepo.RecordClick(ctx, searchID, productID)
}

func (ss *SearchService) GetPopularSearches(ctx context.Context, timeRange string, limit int) ([]SearchTerm, error) {
    return ss.analyticsRepo.GetTopSearches(ctx, timeRange, limit)
}

func (ss *SearchService) GetZeroResultSearches(ctx context.Context, limit int) ([]string, error) {
    return ss.analyticsRepo.GetZeroResultQueries(ctx, limit)
}
```

---

## 6. Elasticsearch Optimization

### Requirements

- [ ] **R6.1** Proper index mapping
- [ ] **R6.2** Analyzer configuration
- [ ] **R6.3** Synonyms configuration
- [ ] **R6.4** Stop words removal
- [ ] **R6.5** Index refresh strategy
- [ ] **R6.6** Shard configuration
- [ ] **R6.7** Query performance monitoring

### Implementation

```json
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "product_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "stop", "synonym", "asciifolding"]
        }
      },
      "filter": {
        "synonym": {
          "type": "synonym",
          "synonyms": [
            "sneakers, shoes, kicks",
            "laptop, notebook, computer",
            "phone, mobile, smartphone"
          ]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "name": {
        "type": "text",
        "analyzer": "product_analyzer",
        "fields": {
          "keyword": {"type": "keyword"},
          "suggest": {"type": "completion"}
        }
      },
      "description": {
        "type": "text",
        "analyzer": "product_analyzer"
      },
      "price": {"type": "double"},
      "brand": {"type": "keyword"},
      "category": {"type": "keyword"},
      "tags": {"type": "keyword"},
      "is_active": {"type": "boolean"},
      "stock_count": {"type": "integer"},
      "sales_count": {"type": "integer"},
      "rating": {"type": "float"},
      "created_at": {"type": "date"}
    }
  }
}
```

---

## 📊 Success Criteria

- [ ] ✅ Search response time <200ms (p95)
- [ ] ✅ Autocomplete <100ms
- [ ] ✅ Zero-result rate <10%
- [ ] ✅ Search-to-purchase conversion >5%
- [ ] ✅ Click-through rate >15%

---

**Status:** Ready for Implementation
