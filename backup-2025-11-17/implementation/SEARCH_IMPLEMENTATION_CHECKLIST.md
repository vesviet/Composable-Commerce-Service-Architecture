# 📋 SEARCH SERVICE IMPLEMENTATION CHECKLIST

**Service**: Search & Discovery Service  
**Current Status**: 5% (Basic structure only)  
**Target**: Production-ready search service with Elasticsearch  
**Estimated Time**: 5-6 weeks (200-240 hours)  
**Team Size**: 2-3 developers  
**Last Updated**: November 12, 2025

---

## 📊 OVERALL STATUS: 5% COMPLETE

### ✅ COMPLETED (5%)
- Basic project structure
- Database migrations (5 tables)
- Proto file definition
- README documentation
- Elasticsearch setup in docker-compose

### 🔴 MISSING (95%)
- Core business logic (0%)
- Elasticsearch integration (0%)
- Data sync from Catalog (0%)
- Service layer (0%)
- Testing (0%)
- Monitoring (0%)

---

## 🎯 PHASE 1: PROJECT SETUP & ELASTICSEARCH (Week 1)

### 1.1. Project Structure Verification (Day 1 - 4 hours)

**Status**: 🟡 Partial (20%)

- [x] Verify existing project structure
- [x] Database migrations exist
- [x] Proto file exists
- [x] Elasticsearch in docker-compose
- [ ] Create missing directories
- [ ] Setup Go modules dependencies
- [ ] Configure Makefile
- [ ] Setup Docker and docker-compose

**Directory Structure to Create**:
```
search/
├── cmd/
│   ├── search/              # ❌ Missing
│   │   ├── main.go
│   │   └── wire.go
│   └── worker/              # ❌ Missing (NEW)
│       ├── main.go
│       └── wire.go
├── internal/
│   ├── biz/                 # ❌ Missing
│   │   ├── search.go
│   │   ├── indexing.go
│   │   ├── analytics.go
│   │   └── biz.go
│   ├── data/                # ❌ Missing
│   │   ├── search.go
│   │   ├── elasticsearch.go
│   │   ├── analytics.go
│   │   └── data.go
│   ├── service/             # ❌ Missing
│   │   ├── search.go
│   │   ├── indexing.go
│   │   └── service.go
│   ├── server/              # ❌ Missing
│   │   ├── http.go
│   │   ├── grpc.go
│   │   └── consul.go
│   ├── worker/              # ❌ Missing (NEW)
│   │   ├── sync.go
│   │   ├── reindex.go
│   │   └── scheduler.go
│   └── conf/                # ❌ Missing
│       ├── conf.proto
│       └── conf.pb.go
```

**Estimated Effort**: 4 hours


### 1.2. Configuration Setup (Day 1 - 2 hours)

**Status**: 🟡 Partial (30%)

- [x] Basic config.yaml exists
- [ ] Add Elasticsearch configurations
- [ ] Add search settings
- [ ] Add indexing settings
- [ ] Add worker settings
- [ ] Create config-dev.yaml
- [ ] Generate conf.proto and conf.pb.go

**Configuration Sections to Add**:
```yaml
# Elasticsearch configuration
elasticsearch:
  addresses:
    - http://localhost:9200
  username: ${ELASTICSEARCH_USERNAME}
  password: ${ELASTICSEARCH_PASSWORD}
  index_prefix: "ecommerce"
  max_retries: 3
  timeout: 30s
  sniff: false

# Search settings
search:
  default_page_size: 20
  max_page_size: 100
  min_query_length: 2
  max_query_length: 200
  fuzzy_enabled: true
  autocomplete_enabled: true
  spell_check_enabled: true
  highlight_enabled: true
  
# Indexing settings
indexing:
  batch_size: 1000
  bulk_timeout: 30s
  refresh_interval: "1s"
  number_of_shards: 1
  number_of_replicas: 1
  
# Worker settings
worker:
  incremental_sync_interval: "5m"
  full_reindex_schedule: "0 2 * * *"  # Daily at 2 AM
  max_concurrent_jobs: 5
  
# Cache settings
cache:
  search_results_ttl: 300  # 5 minutes
  autocomplete_ttl: 3600   # 1 hour
  trending_ttl: 1800       # 30 minutes
```

**Estimated Effort**: 2 hours


### 1.3. Elasticsearch Client Setup (Day 2 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Initialize Elasticsearch client
- [ ] Create index management
- [ ] Define product index mapping
- [ ] Define content index mapping
- [ ] Create index templates
- [ ] Add health check
- [ ] Test connection

**Files to Create**:
```
internal/data/elasticsearch/
  ├── client.go
  ├── index.go
  ├── mapping.go
  └── health.go
```

**Elasticsearch Client**:
```go
type ElasticsearchClient struct {
    client *elasticsearch.Client
    config *conf.Elasticsearch
    log    *log.Helper
}

func NewElasticsearchClient(config *conf.Elasticsearch, logger log.Logger) (*ElasticsearchClient, error) {
    cfg := elasticsearch.Config{
        Addresses: config.Addresses,
        Username:  config.Username,
        Password:  config.Password,
        MaxRetries: int(config.MaxRetries),
    }
    
    client, err := elasticsearch.NewClient(cfg)
    if err != nil {
        return nil, err
    }
    
    return &ElasticsearchClient{
        client: client,
        config: config,
        log:    log.NewHelper(logger),
    }, nil
}

func (c *ElasticsearchClient) HealthCheck(ctx context.Context) error {
    res, err := c.client.Cluster.Health()
    if err != nil {
        return err
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return fmt.Errorf("elasticsearch unhealthy: %s", res.Status())
    }
    
    return nil
}
```

**Product Index Mapping**:
```json
{
  "mappings": {
    "properties": {
      "id": {"type": "keyword"},
      "name": {
        "type": "text",
        "analyzer": "standard",
        "fields": {
          "keyword": {"type": "keyword"},
          "suggest": {"type": "completion"}
        }
      },
      "description": {"type": "text"},
      "sku": {"type": "keyword"},
      "category_id": {"type": "keyword"},
      "brand": {"type": "keyword"},
      "price": {"type": "double"},
      "stock": {"type": "integer"},
      "is_active": {"type": "boolean"},
      "tags": {"type": "keyword"},
      "created_at": {"type": "date"},
      "updated_at": {"type": "date"}
    }
  }
}
```

**Estimated Effort**: 6 hours


### 1.4. Wire DI & Server Setup (Day 2-3 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create wire.go
- [ ] Define ProviderSets
- [ ] Generate wire_gen.go
- [ ] Implement HTTP server
- [ ] Implement gRPC server
- [ ] Implement Consul registration
- [ ] Add health check endpoint
- [ ] Test service startup

**Files to Create**:
```
cmd/search/wire.go
cmd/search/main.go
internal/server/http.go
internal/server/grpc.go
internal/server/consul.go
```

**Estimated Effort**: 8 hours

---

### 1.5. Data Layer Foundation (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create data.go with connections
- [ ] Setup GORM connection
- [ ] Setup Redis connection
- [ ] Setup Elasticsearch connection
- [ ] Create base repository interfaces
- [ ] Add connection pooling

**Files to Create**:
```
internal/data/data.go
internal/data/postgres/db.go
internal/data/redis/cache.go
```

**Estimated Effort**: 8 hours

---

### 1.6. Basic Service Startup Test (Day 4 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Build service binary
- [ ] Run migrations
- [ ] Start Elasticsearch
- [ ] Start service locally
- [ ] Test health endpoint
- [ ] Test Elasticsearch connection
- [ ] Verify logs

**Test Commands**:
```bash
# Start Elasticsearch
docker-compose up -d elasticsearch

# Build
make build

# Run migrations
make migrate-up

# Start service
./bin/search -conf ./configs

# Test health
curl http://localhost:8010/health

# Test Elasticsearch
curl http://localhost:9200/_cluster/health
```

**Estimated Effort**: 4 hours

**PHASE 1 TOTAL**: 32 hours (Week 1)

---

## 🎯 PHASE 2: SEARCH BUSINESS LOGIC (Week 2)

### 2.1. Domain Entities (Day 1 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Define SearchQuery entity
- [ ] Define SearchResult entity
- [ ] Define SearchFilter entity
- [ ] Define SearchAnalytics entity
- [ ] Add validation logic

**Files to Create**:
```
internal/biz/search.go
internal/biz/indexing.go
internal/biz/analytics.go
```

**Domain Entities**:
```go
type SearchQuery struct {
    Query      string
    Filters    map[string]interface{}
    Page       int
    PageSize   int
    SortBy     string
    SortOrder  string
}

type SearchResult struct {
    TotalHits int64
    MaxScore  float64
    Hits      []SearchHit
    Facets    map[string][]Facet
    Took      int64  // milliseconds
}

type SearchHit struct {
    ID          string
    Score       float64
    Source      map[string]interface{}
    Highlights  map[string][]string
}
```

**Estimated Effort**: 4 hours


### 2.2. Search Repository Interface (Day 1 - 2 hours)

**Status**: ❌ Not Started (0%)

- [ ] Define SearchRepo interface
- [ ] Define IndexRepo interface
- [ ] Define AnalyticsRepo interface
- [ ] Add method signatures

**Interface Example**:
```go
// internal/biz/search.go
type SearchRepo interface {
    Search(ctx context.Context, query *SearchQuery) (*SearchResult, error)
    Autocomplete(ctx context.Context, query string, limit int) ([]string, error)
    Suggest(ctx context.Context, query string) ([]string, error)
    GetTrending(ctx context.Context, limit int) ([]string, error)
}

type IndexRepo interface {
    IndexDocument(ctx context.Context, index, id string, doc interface{}) error
    BulkIndex(ctx context.Context, index string, docs []interface{}) error
    UpdateDocument(ctx context.Context, index, id string, doc interface{}) error
    DeleteDocument(ctx context.Context, index, id string) error
    CreateIndex(ctx context.Context, index string, mapping map[string]interface{}) error
    DeleteIndex(ctx context.Context, index string) error
}
```

**Estimated Effort**: 2 hours

---

### 2.3. Search Repository Implementation (Day 2 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement SearchRepo with Elasticsearch
- [ ] Implement multi-field search
- [ ] Implement fuzzy matching
- [ ] Implement faceted search
- [ ] Implement autocomplete
- [ ] Implement spell suggestions
- [ ] Add result highlighting
- [ ] Add error handling

**Files to Create**:
```
internal/data/search.go
internal/data/elasticsearch/search.go
internal/data/elasticsearch/query_builder.go
```

**Search Implementation**:
```go
func (r *searchRepo) Search(ctx context.Context, query *SearchQuery) (*SearchResult, error) {
    // Build Elasticsearch query
    esQuery := r.buildQuery(query)
    
    // Execute search
    res, err := r.es.Search(
        r.es.Search.WithContext(ctx),
        r.es.Search.WithIndex("products"),
        r.es.Search.WithBody(esQuery),
        r.es.Search.WithTrackTotalHits(true),
    )
    if err != nil {
        return nil, err
    }
    defer res.Body.Close()
    
    // Parse response
    result, err := r.parseSearchResponse(res)
    if err != nil {
        return nil, err
    }
    
    return result, nil
}

func (r *searchRepo) buildQuery(query *SearchQuery) *strings.Reader {
    // Build multi-field search query
    must := []map[string]interface{}{
        {
            "multi_match": map[string]interface{}{
                "query": query.Query,
                "fields": []string{"name^3", "description", "sku^2", "brand"},
                "fuzziness": "AUTO",
                "operator": "and",
            },
        },
    }
    
    // Add filters
    filter := r.buildFilters(query.Filters)
    
    // Build final query
    esQuery := map[string]interface{}{
        "query": map[string]interface{}{
            "bool": map[string]interface{}{
                "must": must,
                "filter": filter,
            },
        },
        "from": (query.Page - 1) * query.PageSize,
        "size": query.PageSize,
        "highlight": map[string]interface{}{
            "fields": map[string]interface{}{
                "name": map[string]interface{}{},
                "description": map[string]interface{}{},
            },
        },
        "aggs": r.buildAggregations(),
    }
    
    // Convert to JSON
    jsonQuery, _ := json.Marshal(esQuery)
    return strings.NewReader(string(jsonQuery))
}
```

**Estimated Effort**: 8 hours


### 2.4. Search Usecase Implementation (Day 3 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement SearchProducts usecase
- [ ] Implement Autocomplete usecase
- [ ] Implement GetSuggestions usecase
- [ ] Implement GetTrending usecase
- [ ] Add search result caching
- [ ] Add search analytics tracking
- [ ] Add error handling

**Files to Create**:
```
internal/biz/search_usecase.go
```

**Search Usecase**:
```go
func (uc *SearchUsecase) SearchProducts(ctx context.Context, req *SearchRequest) (*SearchResult, error) {
    // 1. Validate query
    if len(req.Query) < uc.config.MinQueryLength {
        return nil, ErrQueryTooShort
    }
    
    // 2. Check cache
    cacheKey := uc.buildCacheKey(req)
    if cached, err := uc.cache.Get(ctx, cacheKey); err == nil {
        return cached.(*SearchResult), nil
    }
    
    // 3. Build search query
    query := &SearchQuery{
        Query: req.Query,
        Filters: req.Filters,
        Page: req.Page,
        PageSize: req.PageSize,
        SortBy: req.SortBy,
    }
    
    // 4. Execute search
    result, err := uc.searchRepo.Search(ctx, query)
    if err != nil {
        return nil, err
    }
    
    // 5. Cache result
    uc.cache.Set(ctx, cacheKey, result, uc.config.CacheTTL)
    
    // 6. Track analytics
    uc.trackSearch(ctx, req, result)
    
    return result, nil
}
```

**Estimated Effort**: 6 hours

---

### 2.5. Indexing Repository Implementation (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement IndexDocument
- [ ] Implement BulkIndex
- [ ] Implement UpdateDocument
- [ ] Implement DeleteDocument
- [ ] Implement CreateIndex
- [ ] Add bulk indexing optimization
- [ ] Add error handling

**Files to Create**:
```
internal/data/elasticsearch/indexing.go
```

**Bulk Indexing**:
```go
func (r *indexRepo) BulkIndex(ctx context.Context, index string, docs []interface{}) error {
    var buf bytes.Buffer
    
    for _, doc := range docs {
        // Add action
        meta := map[string]interface{}{
            "index": map[string]interface{}{
                "_index": index,
                "_id": doc.ID,
            },
        }
        metaJSON, _ := json.Marshal(meta)
        buf.Write(metaJSON)
        buf.WriteByte('\n')
        
        // Add document
        docJSON, _ := json.Marshal(doc)
        buf.Write(docJSON)
        buf.WriteByte('\n')
    }
    
    // Execute bulk request
    res, err := r.es.Bulk(
        bytes.NewReader(buf.Bytes()),
        r.es.Bulk.WithContext(ctx),
        r.es.Bulk.WithIndex(index),
    )
    if err != nil {
        return err
    }
    defer res.Body.Close()
    
    if res.IsError() {
        return fmt.Errorf("bulk index failed: %s", res.Status())
    }
    
    return nil
}
```

**Estimated Effort**: 8 hours

**PHASE 2 TOTAL**: 28 hours (Week 2)


## 🎯 PHASE 3: DATA SYNC FROM CATALOG (Week 3)

### 3.1. Event Handler Setup (Day 1 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create event handler structure
- [ ] Subscribe to catalog.product.created
- [ ] Subscribe to catalog.product.updated
- [ ] Subscribe to catalog.product.deleted
- [ ] Add event processing logic
- [ ] Add error handling
- [ ] Add idempotency

**Files to Create**:
```
internal/service/event_handler.go
internal/biz/sync.go
```

**Event Handlers**:
```go
// HandleProductCreated - Index new product
func (h *EventHandler) HandleProductCreated(ctx context.Context, event *ProductCreatedEvent) error {
    // 1. Get product details from Catalog Service
    product, err := h.catalogClient.GetProduct(ctx, event.ProductID)
    if err != nil {
        return err
    }
    
    // 2. Transform to search document
    doc := h.transformProductToSearchDoc(product)
    
    // 3. Index to Elasticsearch
    if err := h.indexRepo.IndexDocument(ctx, "products", product.ID, doc); err != nil {
        return err
    }
    
    h.log.Infof("Indexed product %s", product.ID)
    return nil
}

// HandleProductUpdated - Update indexed product
func (h *EventHandler) HandleProductUpdated(ctx context.Context, event *ProductUpdatedEvent) error {
    product, err := h.catalogClient.GetProduct(ctx, event.ProductID)
    if err != nil {
        return err
    }
    
    doc := h.transformProductToSearchDoc(product)
    return h.indexRepo.UpdateDocument(ctx, "products", product.ID, doc)
}

// HandleProductDeleted - Remove from index
func (h *EventHandler) HandleProductDeleted(ctx context.Context, event *ProductDeletedEvent) error {
    return h.indexRepo.DeleteDocument(ctx, "products", event.ProductID)
}
```

**Estimated Effort**: 6 hours

---

### 3.2. Catalog Service Client (Day 1-2 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create Catalog Service client
- [ ] Implement GetProduct method
- [ ] Implement ListProducts method
- [ ] Add service discovery via Consul
- [ ] Add retry logic
- [ ] Add circuit breaker
- [ ] Add timeout handling

**Files to Create**:
```
internal/client/catalog_client.go
```

**Catalog Client**:
```go
type CatalogClient interface {
    GetProduct(ctx context.Context, productID string) (*Product, error)
    ListProducts(ctx context.Context, req *ListProductsRequest) ([]*Product, int64, error)
}

type catalogClient struct {
    conn   *grpc.ClientConn
    client catalogpb.CatalogServiceClient
}

func NewCatalogClient(consul *consul.Client, logger log.Logger) (CatalogClient, error) {
    // Discover catalog service via Consul
    services, _, err := consul.Health().Service("catalog-service", "", true, nil)
    if err != nil {
        return nil, err
    }
    
    // Create gRPC connection
    conn, err := grpc.Dial(services[0].Service.Address, grpc.WithInsecure())
    if err != nil {
        return nil, err
    }
    
    return &catalogClient{
        conn:   conn,
        client: catalogpb.NewCatalogServiceClient(conn),
    }, nil
}
```

**Estimated Effort**: 6 hours


### 3.3. Initial Data Indexing (Day 2-3 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement bulk indexing from Catalog
- [ ] Fetch all products from Catalog Service
- [ ] Transform products to search documents
- [ ] Bulk index to Elasticsearch
- [ ] Add progress tracking
- [ ] Add error recovery
- [ ] Verify index completeness

**Initial Indexing Flow**:
```go
func (uc *IndexingUsecase) InitialIndex(ctx context.Context) error {
    // 1. Get total product count
    total, err := uc.catalogClient.GetProductCount(ctx)
    if err != nil {
        return err
    }
    
    // 2. Fetch products in batches
    batchSize := 1000
    for offset := 0; offset < int(total); offset += batchSize {
        products, _, err := uc.catalogClient.ListProducts(ctx, &ListProductsRequest{
            Page: offset/batchSize + 1,
            PageSize: batchSize,
        })
        if err != nil {
            return err
        }
        
        // 3. Transform to search documents
        docs := make([]interface{}, len(products))
        for i, product := range products {
            docs[i] = uc.transformProduct(product)
        }
        
        // 4. Bulk index
        if err := uc.indexRepo.BulkIndex(ctx, "products", docs); err != nil {
            return err
        }
        
        uc.log.Infof("Indexed %d/%d products", offset+len(products), total)
    }
    
    return nil
}
```

**Estimated Effort**: 8 hours

---

### 3.4. Data Transformation (Day 3 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement product to search document transformation
- [ ] Add field mapping
- [ ] Add data enrichment
- [ ] Add validation
- [ ] Handle missing fields

**Transformation Logic**:
```go
func (uc *IndexingUsecase) transformProduct(product *Product) map[string]interface{} {
    return map[string]interface{}{
        "id":          product.ID,
        "name":        product.Name,
        "description": product.Description,
        "sku":         product.SKU,
        "category_id": product.CategoryID,
        "category_name": product.CategoryName,
        "brand":       product.Brand,
        "price":       product.Price,
        "stock":       product.Stock,
        "is_active":   product.IsActive,
        "tags":        product.Tags,
        "attributes":  product.Attributes,
        "created_at":  product.CreatedAt,
        "updated_at":  product.UpdatedAt,
    }
}
```

**Estimated Effort**: 4 hours

**PHASE 3 TOTAL**: 24 hours (Week 3)

---

## 🎯 PHASE 4: SYNC WORKERS (Week 3-4)

### 4.1. Incremental Sync Worker (Day 4, Week 3 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create worker structure
- [ ] Implement incremental sync logic
- [ ] Fetch updated products (last 5 minutes)
- [ ] Index updated products
- [ ] Schedule every 5 minutes
- [ ] Add error handling
- [ ] Add monitoring

**Files to Create**:
```
cmd/worker/main.go
internal/worker/sync.go
internal/worker/scheduler.go
```

**Incremental Sync**:
```go
func (w *SyncWorker) IncrementalSync(ctx context.Context) error {
    // 1. Get products updated in last 5 minutes
    since := time.Now().Add(-5 * time.Minute)
    products, err := w.catalogClient.ListProducts(ctx, &ListProductsRequest{
        UpdatedSince: since,
    })
    if err != nil {
        return err
    }
    
    // 2. Transform and index
    for _, product := range products {
        doc := w.transformProduct(product)
        if err := w.indexRepo.IndexDocument(ctx, "products", product.ID, doc); err != nil {
            w.log.Errorf("Failed to index product %s: %v", product.ID, err)
        }
    }
    
    w.log.Infof("Incremental sync completed: %d products", len(products))
    return nil
}
```

**Estimated Effort**: 6 hours



### 4.2. Full Reindex Worker (Day 4-5, Week 3 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement full reindex logic
- [ ] Create new index with timestamp
- [ ] Index all products to new index
- [ ] Verify index completeness
- [ ] Switch alias to new index
- [ ] Delete old index
- [ ] Schedule daily at 2 AM

**Full Reindex Flow**:
```go
func (w *ReindexWorker) FullReindex(ctx context.Context) error {
    // 1. Create new index with timestamp
    newIndex := fmt.Sprintf("products_%s", time.Now().Format("20060102_150405"))
    if err := w.indexRepo.CreateIndex(ctx, newIndex, w.productMapping); err != nil {
        return err
    }
    
    // 2. Index all products
    if err := w.indexAllProducts(ctx, newIndex); err != nil {
        return err
    }
    
    // 3. Verify index
    count, err := w.verifyIndex(ctx, newIndex)
    if err != nil {
        return err
    }
    
    // 4. Switch alias
    if err := w.switchAlias(ctx, "products", newIndex); err != nil {
        return err
    }
    
    // 5. Delete old index
    if err := w.deleteOldIndices(ctx); err != nil {
        w.log.Warnf("Failed to delete old indices: %v", err)
    }
    
    w.log.Infof("Full reindex completed: %d products", count)
    return nil
}
```

**Estimated Effort**: 8 hours

---

### 4.3. Worker Scheduler (Day 5, Week 3 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement cron scheduler
- [ ] Schedule incremental sync (every 5 min)
- [ ] Schedule full reindex (daily 2 AM)
- [ ] Add job monitoring
- [ ] Add job history
- [ ] Add manual trigger endpoint

**Scheduler Implementation**:
```go
func (s *Scheduler) Start(ctx context.Context) error {
    c := cron.New()
    
    // Incremental sync every 5 minutes
    c.AddFunc("*/5 * * * *", func() {
        if err := s.syncWorker.IncrementalSync(ctx); err != nil {
            s.log.Errorf("Incremental sync failed: %v", err)
        }
    })
    
    // Full reindex daily at 2 AM
    c.AddFunc("0 2 * * *", func() {
        if err := s.reindexWorker.FullReindex(ctx); err != nil {
            s.log.Errorf("Full reindex failed: %v", err)
        }
    })
    
    c.Start()
    return nil
}
```

**Estimated Effort**: 4 hours

---

### 4.4. Worker Monitoring (Day 5, Week 3 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Add worker metrics
- [ ] Track sync duration
- [ ] Track indexed documents count
- [ ] Track errors
- [ ] Add Prometheus metrics
- [ ] Add health check endpoint

**Metrics**:
```go
var (
    syncDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "search_sync_duration_seconds",
            Help: "Duration of sync operations",
        },
        []string{"type"},
    )
    
    indexedDocuments = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "search_indexed_documents_total",
            Help: "Total number of indexed documents",
        },
        []string{"type"},
    )
    
    syncErrors = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "search_sync_errors_total",
            Help: "Total number of sync errors",
        },
        []string{"type"},
    )
)
```

**Estimated Effort**: 4 hours

**PHASE 4 TOTAL**: 22 hours (Week 3-4)

---

## 🎯 PHASE 5: SERVICE LAYER & API (Week 4)

### 5.1. gRPC Service Implementation (Day 1-2 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement SearchProducts RPC
- [ ] Implement Autocomplete RPC
- [ ] Implement GetSuggestions RPC
- [ ] Implement GetTrending RPC
- [ ] Implement IndexProduct RPC (admin)
- [ ] Implement ReindexAll RPC (admin)
- [ ] Add request validation
- [ ] Add error handling

**Files to Create**:
```
internal/service/search.go
internal/service/indexing.go
```

**gRPC Service**:
```go
func (s *SearchService) SearchProducts(ctx context.Context, req *pb.SearchProductsRequest) (*pb.SearchProductsResponse, error) {
    // 1. Validate request
    if err := s.validateSearchRequest(req); err != nil {
        return nil, status.Error(codes.InvalidArgument, err.Error())
    }
    
    // 2. Call usecase
    result, err := s.searchUC.SearchProducts(ctx, &biz.SearchRequest{
        Query: req.Query,
        Filters: req.Filters,
        Page: int(req.Page),
        PageSize: int(req.PageSize),
        SortBy: req.SortBy,
    })
    if err != nil {
        return nil, status.Error(codes.Internal, err.Error())
    }
    
    // 3. Transform response
    return &pb.SearchProductsResponse{
        TotalHits: result.TotalHits,
        Products: s.transformProducts(result.Hits),
        Facets: s.transformFacets(result.Facets),
        Took: result.Took,
    }, nil
}
```

**Estimated Effort**: 8 hours

---

### 5.2. HTTP API Implementation (Day 2-3 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement GET /api/v1/search
- [ ] Implement GET /api/v1/autocomplete
- [ ] Implement GET /api/v1/suggestions
- [ ] Implement GET /api/v1/trending
- [ ] Add request validation
- [ ] Add response formatting
- [ ] Add error handling

**HTTP Handlers**:
```go
func (h *SearchHandler) Search(c *gin.Context) {
    var req SearchRequest
    if err := c.ShouldBindQuery(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
    
    result, err := h.searchUC.SearchProducts(c.Request.Context(), &req)
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }
    
    c.JSON(200, gin.H{
        "total": result.TotalHits,
        "products": result.Hits,
        "facets": result.Facets,
        "took": result.Took,
    })
}
```

**Estimated Effort**: 6 hours

---

### 5.3. Analytics Tracking (Day 3 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Track search queries
- [ ] Track search results
- [ ] Track click-through rate
- [ ] Track zero-result searches
- [ ] Store analytics in database
- [ ] Add analytics API endpoints

**Files to Create**:
```
internal/biz/analytics.go
internal/data/analytics.go
```

**Analytics Tracking**:
```go
type SearchAnalytics struct {
    ID            string
    Query         string
    TotalResults  int64
    ClickedResult string
    UserID        string
    SessionID     string
    Timestamp     time.Time
}

func (uc *SearchUsecase) trackSearch(ctx context.Context, req *SearchRequest, result *SearchResult) {
    analytics := &SearchAnalytics{
        ID:           uuid.New().String(),
        Query:        req.Query,
        TotalResults: result.TotalHits,
        UserID:       getUserID(ctx),
        SessionID:    getSessionID(ctx),
        Timestamp:    time.Now(),
    }
    
    go func() {
        if err := uc.analyticsRepo.Save(context.Background(), analytics); err != nil {
            uc.log.Errorf("Failed to save analytics: %v", err)
        }
    }()
}
```

**Estimated Effort**: 6 hours

---

### 5.4. Caching Layer (Day 4 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Implement search result caching
- [ ] Implement autocomplete caching
- [ ] Implement trending caching
- [ ] Add cache invalidation
- [ ] Add cache warming
- [ ] Configure TTL per cache type

**Cache Implementation**:
```go
func (uc *SearchUsecase) SearchProducts(ctx context.Context, req *SearchRequest) (*SearchResult, error) {
    // Build cache key
    cacheKey := fmt.Sprintf("search:%s:%v:%d:%d", 
        req.Query, req.Filters, req.Page, req.PageSize)
    
    // Try cache first
    var result SearchResult
    if err := uc.cache.Get(ctx, cacheKey, &result); err == nil {
        return &result, nil
    }
    
    // Execute search
    result, err := uc.searchRepo.Search(ctx, req)
    if err != nil {
        return nil, err
    }
    
    // Cache result (5 minutes)
    uc.cache.Set(ctx, cacheKey, result, 5*time.Minute)
    
    return result, nil
}
```

**Estimated Effort**: 6 hours

**PHASE 5 TOTAL**: 26 hours (Week 4)

---

## 🎯 PHASE 6: TESTING & OPTIMIZATION (Week 5)

### 6.1. Unit Tests (Day 1-2 - 12 hours)

**Status**: ❌ Not Started (0%)

- [ ] Test search usecase
- [ ] Test indexing usecase
- [ ] Test analytics usecase
- [ ] Test search repository
- [ ] Test indexing repository
- [ ] Test event handlers
- [ ] Test workers
- [ ] Achieve 80%+ coverage

**Test Files to Create**:
```
internal/biz/search_test.go
internal/biz/indexing_test.go
internal/data/search_test.go
internal/data/elasticsearch_test.go
internal/service/search_test.go
internal/worker/sync_test.go
```

**Example Test**:
```go
func TestSearchProducts(t *testing.T) {
    // Setup
    mockRepo := &MockSearchRepo{}
    mockCache := &MockCache{}
    uc := NewSearchUsecase(mockRepo, mockCache, nil)
    
    // Mock data
    mockRepo.On("Search", mock.Anything, mock.Anything).Return(&SearchResult{
        TotalHits: 10,
        Hits: []SearchHit{
            {ID: "1", Score: 1.5},
        },
    }, nil)
    
    // Execute
    result, err := uc.SearchProducts(context.Background(), &SearchRequest{
        Query: "laptop",
        Page: 1,
        PageSize: 20,
    })
    
    // Assert
    assert.NoError(t, err)
    assert.Equal(t, int64(10), result.TotalHits)
    assert.Len(t, result.Hits, 1)
}
```

**Estimated Effort**: 12 hours

---

### 6.2. Integration Tests (Day 2-3 - 10 hours)

**Status**: ❌ Not Started (0%)

- [ ] Test with real Elasticsearch
- [ ] Test search flow end-to-end
- [ ] Test indexing flow
- [ ] Test sync workers
- [ ] Test API endpoints
- [ ] Test error scenarios

**Integration Test**:
```go
func TestSearchIntegration(t *testing.T) {
    // Setup Elasticsearch testcontainer
    ctx := context.Background()
    esContainer, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: testcontainers.ContainerRequest{
            Image: "elasticsearch:8.11.0",
            ExposedPorts: []string{"9200/tcp"},
            Env: map[string]string{
                "discovery.type": "single-node",
            },
        },
        Started: true,
    })
    require.NoError(t, err)
    defer esContainer.Terminate(ctx)
    
    // Get Elasticsearch URL
    host, _ := esContainer.Host(ctx)
    port, _ := esContainer.MappedPort(ctx, "9200")
    esURL := fmt.Sprintf("http://%s:%s", host, port.Port())
    
    // Create client and test
    client := createESClient(esURL)
    // ... test search operations
}
```

**Estimated Effort**: 10 hours

---

### 6.3. Performance Testing (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Load test search endpoint
- [ ] Load test indexing
- [ ] Measure response times
- [ ] Measure throughput
- [ ] Identify bottlenecks
- [ ] Optimize slow queries

**Load Test Script**:
```bash
# Using k6 for load testing
k6 run - <<EOF
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  let res = http.get('http://localhost:8010/api/v1/search?q=laptop');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
  sleep(1);
}
EOF
```

**Estimated Effort**: 8 hours

---

### 6.4. Query Optimization (Day 4-5 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] Optimize Elasticsearch queries
- [ ] Add query caching
- [ ] Optimize index settings
- [ ] Add search templates
- [ ] Tune relevance scoring
- [ ] Add query profiling

**Query Optimization**:
```go
// Use search templates for common queries
func (r *searchRepo) createSearchTemplate() error {
    template := map[string]interface{}{
        "script": map[string]interface{}{
            "lang": "mustache",
            "source": map[string]interface{}{
                "query": map[string]interface{}{
                    "bool": map[string]interface{}{
                        "must": []map[string]interface{}{
                            {
                                "multi_match": map[string]interface{}{
                                    "query": "{{query}}",
                                    "fields": []string{"name^3", "description"},
                                },
                            },
                        },
                    },
                },
            },
        },
    }
    
    return r.es.PutScript("product_search", template)
}
```

**Estimated Effort**: 8 hours

**PHASE 6 TOTAL**: 38 hours (Week 5)

---

## 🎯 PHASE 7: MONITORING & DEPLOYMENT (Week 6)

### 7.1. Prometheus Metrics (Day 1 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Add search request metrics
- [ ] Add search latency metrics
- [ ] Add indexing metrics
- [ ] Add Elasticsearch health metrics
- [ ] Add cache hit/miss metrics
- [ ] Add worker metrics
- [ ] Configure Prometheus scraping

**Metrics Implementation**:
```go
var (
    searchRequests = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "search_requests_total",
            Help: "Total number of search requests",
        },
        []string{"status"},
    )
    
    searchLatency = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "search_latency_seconds",
            Help: "Search request latency",
            Buckets: []float64{.005, .01, .025, .05, .1, .25, .5, 1},
        },
        []string{"endpoint"},
    )
    
    esHealth = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "elasticsearch_health",
            Help: "Elasticsearch cluster health (0=red, 1=yellow, 2=green)",
        },
        []string{"cluster"},
    )
)
```

**Estimated Effort**: 6 hours

---

### 7.2. Logging & Tracing (Day 1-2 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Add structured logging
- [ ] Add request tracing
- [ ] Add Jaeger integration
- [ ] Add correlation IDs
- [ ] Add error logging
- [ ] Configure log levels

**Tracing Setup**:
```go
func (s *SearchService) SearchProducts(ctx context.Context, req *pb.SearchProductsRequest) (*pb.SearchProductsResponse, error) {
    span, ctx := opentracing.StartSpanFromContext(ctx, "SearchProducts")
    defer span.Finish()
    
    span.SetTag("query", req.Query)
    span.SetTag("page", req.Page)
    
    result, err := s.searchUC.SearchProducts(ctx, req)
    if err != nil {
        span.SetTag("error", true)
        span.LogKV("error", err.Error())
        return nil, err
    }
    
    span.SetTag("total_hits", result.TotalHits)
    return result, nil
}
```

**Estimated Effort**: 6 hours

---

### 7.3. Health Checks (Day 2 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Add service health endpoint
- [ ] Check Elasticsearch connection
- [ ] Check database connection
- [ ] Check Redis connection
- [ ] Check Catalog service connection
- [ ] Add readiness probe
- [ ] Add liveness probe

**Health Check**:
```go
func (h *HealthHandler) Check(c *gin.Context) {
    health := map[string]interface{}{
        "status": "healthy",
        "checks": map[string]interface{}{},
    }
    
    // Check Elasticsearch
    if err := h.es.HealthCheck(c.Request.Context()); err != nil {
        health["checks"]["elasticsearch"] = "unhealthy"
        health["status"] = "unhealthy"
    } else {
        health["checks"]["elasticsearch"] = "healthy"
    }
    
    // Check database
    if err := h.db.Ping(); err != nil {
        health["checks"]["database"] = "unhealthy"
        health["status"] = "unhealthy"
    } else {
        health["checks"]["database"] = "healthy"
    }
    
    // Check Redis
    if err := h.redis.Ping(c.Request.Context()).Err(); err != nil {
        health["checks"]["redis"] = "unhealthy"
        health["status"] = "unhealthy"
    } else {
        health["checks"]["redis"] = "healthy"
    }
    
    statusCode := 200
    if health["status"] == "unhealthy" {
        statusCode = 503
    }
    
    c.JSON(statusCode, health)
}
```

**Estimated Effort**: 4 hours

---

### 7.4. Docker & Deployment (Day 3 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Create Dockerfile
- [ ] Create docker-compose.yml
- [ ] Add to root docker-compose
- [ ] Configure environment variables
- [ ] Test local deployment
- [ ] Document deployment steps

**Dockerfile**:
```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /search ./cmd/search
RUN CGO_ENABLED=0 GOOS=linux go build -o /worker ./cmd/worker

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/

COPY --from=builder /search .
COPY --from=builder /worker .
COPY --from=builder /app/configs ./configs

EXPOSE 8010 9010

CMD ["./search", "-conf", "./configs"]
```

**Estimated Effort**: 6 hours

---

### 7.5. Documentation (Day 3-4 - 6 hours)

**Status**: ❌ Not Started (0%)

- [ ] Update README.md
- [ ] Document API endpoints
- [ ] Document configuration
- [ ] Document deployment
- [ ] Add architecture diagram
- [ ] Add usage examples

**API Documentation**:
```markdown
## Search API

### Search Products
GET /api/v1/search

Query Parameters:
- q: Search query (required)
- page: Page number (default: 1)
- page_size: Results per page (default: 20, max: 100)
- category: Filter by category ID
- min_price: Minimum price
- max_price: Maximum price
- sort_by: Sort field (price, name, created_at)
- sort_order: Sort order (asc, desc)

Example:
```bash
curl "http://localhost:8010/api/v1/search?q=laptop&category=electronics&min_price=500&max_price=2000"
```

Response:
```json
{
  "total": 42,
  "products": [...],
  "facets": {...},
  "took": 15
}
```
```

**Estimated Effort**: 6 hours

---

### 7.6. Final Testing & Verification (Day 4-5 - 8 hours)

**Status**: ❌ Not Started (0%)

- [ ] End-to-end testing
- [ ] Performance verification
- [ ] Load testing
- [ ] Security testing
- [ ] Documentation review
- [ ] Code review
- [ ] Deployment verification

**Verification Checklist**:
- [ ] Service starts successfully
- [ ] All health checks pass
- [ ] Search returns correct results
- [ ] Indexing works correctly
- [ ] Workers run on schedule
- [ ] Metrics are collected
- [ ] Logs are structured
- [ ] Tracing works
- [ ] API documentation is accurate
- [ ] Performance meets requirements

**Estimated Effort**: 8 hours

**PHASE 7 TOTAL**: 36 hours (Week 6)

---

## 📊 SUMMARY

### Time Estimation
- **Phase 1**: Project Setup & Elasticsearch - 32 hours (Week 1)
- **Phase 2**: Search Business Logic - 28 hours (Week 2)
- **Phase 3**: Data Sync from Catalog - 24 hours (Week 3)
- **Phase 4**: Sync Workers - 22 hours (Week 3-4)
- **Phase 5**: Service Layer & API - 26 hours (Week 4)
- **Phase 6**: Testing & Optimization - 38 hours (Week 5)
- **Phase 7**: Monitoring & Deployment - 36 hours (Week 6)

**TOTAL**: 206 hours (~5-6 weeks with 2-3 developers)

### Key Features
✅ Full-text search with Elasticsearch  
✅ Autocomplete & suggestions  
✅ Faceted search & filters  
✅ Real-time data sync from Catalog  
✅ Incremental & full reindex workers  
✅ Search analytics tracking  
✅ Result caching with Redis  
✅ Comprehensive monitoring  
✅ Production-ready deployment  

### Dependencies
- Catalog Service (for product data)
- Elasticsearch 8.x
- PostgreSQL 15
- Redis 7
- Consul (service discovery)
- Prometheus & Jaeger

### Success Criteria
- [ ] Search response time < 200ms (p95)
- [ ] Support 1000+ concurrent searches
- [ ] 99.9% uptime
- [ ] Data sync latency < 5 minutes
- [ ] 80%+ test coverage
- [ ] Zero-downtime deployments

---

**Next Steps**:
1. Start with Phase 1: Setup Elasticsearch and project structure
2. Implement core search functionality in Phase 2
3. Setup data sync from Catalog in Phase 3
4. Build sync workers in Phase 4
5. Complete API layer in Phase 5
6. Comprehensive testing in Phase 6
7. Production deployment in Phase 7

**Priority**: Medium (after Order, Payment, Shipping, Notification)

---

*Generated: November 12, 2025*
*Status: Ready for implementation*
