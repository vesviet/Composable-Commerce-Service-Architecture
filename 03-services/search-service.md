# 🔍 Search Service Documentation

**Service Name**: Search Service  
**Version**: v4.0  
**Repository**: `gitlab.com/ta-microservices/search`  
**Status**: ✅ Active (Updated February 2, 2026)

---

## 📋 **Service Overview**

### **Purpose**
The Search Service provides comprehensive product search, indexing, and analytics capabilities for the e-commerce platform. It handles full-text search, autocomplete, faceted search, and real-time product data synchronization.

### **Key Features**
- 🔍 **Full-text Search**: Elasticsearch-powered product search
- 🚀 **Autocomplete**: Real-time search suggestions
- 📊 **Faceted Search**: Multi-dimensional filtering and navigation
- 🔄 **Real-time Sync**: Event-driven product data synchronization
- 📈 **Analytics**: Search behavior tracking and insights
- ⚡ **High Performance**: Sub-second search response times
- 🎯 **Relevance Scoring**: ML-enhanced search ranking

---

## 🏗️ **Architecture**

### **Clean Architecture Layers**

```
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   HTTP/gRPC     │  │   Event         │  │   Admin       │ │
│  │   Handlers      │  │   Consumers     │  │   Endpoints   │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Search        │  │   Analytics     │  │   Sync        │ │
│  │   Usecases      │  │   Usecases      │  │   Usecases    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Elasticsearch │  │   PostgreSQL    │  │   Redis       │ │
│  │   (Search)      │  │   (Metadata)    │  │   (Cache)     │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### **Component Overview**

#### **Service Layer (`internal/service/`)**
- **Search Handlers**: HTTP/gRPC search endpoints
- **Event Consumers**: Product, pricing, and inventory event processing
- **Admin Endpoints**: DLQ management and monitoring
- **Health Checks**: Service health and readiness

#### **Business Logic (`internal/biz/`)**
- **Search Usecases**: Core search functionality and caching
- **Analytics Usecases**: Search behavior tracking
- **Sync Usecases**: Data synchronization logic
- **Domain Models**: Search entities and validation

#### **Data Layer (`internal/data/`)**
- **Elasticsearch**: Search index management and queries
- **PostgreSQL**: Metadata and sync status storage
- **Redis**: Caching and session management

---

## 📡 **API Documentation**

### **gRPC Endpoints**

#### **Search Service**
```protobuf
service SearchService {
  rpc Search(SearchRequest) returns (SearchResponse);
  rpc Autocomplete(AutocompleteRequest) returns (AutocompleteResponse);
  rpc Suggest(SuggestRequest) returns (SuggestResponse);
  rpc GetTrending(TrendingRequest) returns (TrendingResponse);
}
```

#### **CMS Search Service**
```protobuf
service CMSSearchService {
  rpc SearchCMS(CMSSearchRequest) returns (CMSSearchResponse);
  rpc AutocompleteCMS(CMSAutocompleteRequest) returns (CMSAutocompleteResponse);
}
```

### **HTTP Endpoints**

#### **Search APIs**
- `GET /api/v1/search` - Product search
- `GET /api/v1/autocomplete` - Search suggestions
- `GET /api/v1/suggest` - Search recommendations
- `GET /api/v1/trending` - Trending searches

#### **Admin APIs**
- `GET /api/v1/admin/dlq/stats` - DLQ statistics
- `GET /api/v1/admin/dlq/failed-events` - Failed events
- `POST /api/v1/admin/dlq/retry` - Retry failed events
- `GET /api/v1/admin/sync/status` - Sync status

#### **Health Endpoints**
- `GET /health/live` - Liveness probe
- `GET /health/ready` - Readiness probe

---

## 🔄 **Event Processing**

### **Consumed Events**

#### **Product Events**
- `catalog.product.created` - New product creation
- `catalog.product.updated` - Product updates
- `catalog.product.deleted` - Product deletion
- `catalog.product.status_changed` - Status changes

#### **Pricing Events**
- `pricing.price.updated` - Price changes
- `pricing.price.deleted` - Price removal

#### **Inventory Events**
- `warehouse.inventory.stock_changed` - Stock updates
- `warehouse.inventory.reserved` - Stock reservations

#### **CMS Events**
- `cms.page.created` - Content page creation
- `cms.page.updated` - Content page updates
- `cms.page.deleted` - Content page deletion

### **Event Processing Flow**

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Event     │───▶│   Consumer  │───▶│ Validation  │───▶│   Indexing  │
│   Source    │    │   Service   │    │   Layer     │    │   Service   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                     │                   │
                           ▼                     ▼                   ▼
                   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                   │   DLQ       │    │   Cache     │    │Elasticsearch │
                   │   Handler   │    │   Update    │    │   Index      │
                   └─────────────┘    └─────────────┘    └─────────────┘
```

---

## 🗄️ **Data Models**

### **Search Request**
```go
type SearchQuery struct {
    Query       string                 // Search query
    Filters     map[string]interface{} // Search filters
    Page        int                    // Page number
    PageSize    int                    // Page size
    SortBy      string                 // Sort field
    SortOrder   string                 // Sort direction
    WarehouseID string                 // Warehouse filter
    InStock     *bool                  // Stock filter
    CustomerCtx *CustomerContext      // Customer context
    Cursor      string                 // Pagination cursor
}
```

### **Search Result**
```go
type SearchResult struct {
    TotalHits    int64         // Total results
    Hits         []SearchHit   // Search hits
    Facets       []Facet       // Search facets
    Aggregations map[string]interface{} // Aggregations
    ScrollID     string        // Scroll identifier
    QueryID      string        // Query tracking ID
}
```

### **Search Hit**
```go
type SearchHit struct {
    ID           string                 // Product ID
    Score        float64                // Relevance score
    Source       map[string]interface{} // Product data
    Highlights   map[string][]string   // Search highlights
    Sort         []interface{}          // Sort values
}
```

---

## ⚡ **Performance Features**

### **Caching Strategy**
- **Redis Cache**: Search results and metadata
- **Cache Keys**: Deterministic cache key generation
- **TTL Management**: Configurable cache expiration
- **Cache Invalidation**: Event-driven cache updates

### **Search Optimization**
- **Index Optimization**: Optimized Elasticsearch mappings
- **Query Optimization**: Efficient query construction
- **Pagination**: Cursor-based pagination for large datasets
- **Parallel Processing**: Concurrent search operations

### **Performance Metrics**
- **Response Time**: < 500ms for 95% of queries
- **Throughput**: 1000+ queries/second
- **Index Size**: Optimized for storage efficiency
- **Cache Hit Rate**: > 80% for popular queries

---

## 🛡️ **Security Features**

### **Authentication & Authorization**
- **JWT Authentication**: Token-based API security
- **Role-based Access**: Permission-based access control
- **API Rate Limiting**: Request throttling
- **Input Validation**: Comprehensive input sanitization

### **Data Protection**
- **PII Filtering**: Personal data protection
- **Audit Logging**: Comprehensive audit trail
- **Error Handling**: Secure error responses
- **CORS Configuration**: Cross-origin request security

---

## 👁️ **Observability**

### **Monitoring & Metrics**
- **Prometheus Metrics**: RED metrics implementation
- **Custom Metrics**: Search-specific KPIs
- **Health Checks**: Service health monitoring
- **Performance Metrics**: Query performance tracking

### **Logging**
- **Structured Logging**: JSON format with trace IDs
- **Log Levels**: Configurable logging verbosity
- **Request Tracing**: End-to-end request tracking
- **Error Logging**: Comprehensive error reporting

### **Key Metrics**
```go
// Search Metrics
search_duration_seconds
search_requests_total
search_cache_hits_total
search_cache_misses_total

// Event Processing Metrics
event_processing_duration_seconds
event_processing_errors_total
dlq_size
sync_status

// Service Health Metrics
service_up
service_ready
elasticsearch_health
redis_health
```

---

## 🚀 **Deployment**

### **Container Configuration**
```dockerfile
# Multi-stage build
FROM golang:1.25.3-alpine AS builder
# Build stage with Go modules and protobuf generation

FROM alpine:latest
# Runtime stage with minimal footprint
```

### **Docker Compose**
```yaml
services:
  search-service:
    build: .
    ports:
      - "50051:50051"  # gRPC
      - "8080:8080"    # HTTP
    environment:
      - ELASTICSEARCH_URL=http://elasticsearch:9200
      - REDIS_URL=redis://redis:6379
      - DATABASE_URL=postgres://user:pass@postgres:5432/search
    depends_on:
      - elasticsearch
      - redis
      - postgres
```

### **Health Checks**
- **Liveness**: `/health/live` - Service is running
- **Readiness**: `/health/ready` - Service is ready to accept traffic
- **Dependencies**: Elasticsearch, Redis, PostgreSQL connectivity

---

## 🧪 **Testing**

### **Test Coverage**
- **Unit Tests**: Business logic validation
- **Integration Tests**: Database and external service integration
- **End-to-End Tests**: Full search workflow testing
- **Performance Tests**: Load and stress testing

### **Test Structure**
```
test/
├── unit/                    # Unit tests
│   ├── search_test.go
│   └── analytics_test.go
├── integration/             # Integration tests
│   ├── search_integration_test.go
│   └── event_integration_test.go
└── e2e/                    # End-to-end tests
    └── search_workflow_test.go
```

---

## 📊 **Business Value**

### **Customer Experience**
- **Fast Search**: Sub-second response times
- **Relevant Results**: ML-enhanced relevance scoring
- **Easy Navigation**: Intuitive faceted search
- **Mobile Optimized**: Responsive search interface

### **Business Intelligence**
- **Search Analytics**: Customer behavior insights
- **Popular Products**: Trending search analysis
- **Conversion Tracking**: Search-to-purchase metrics
- **A/B Testing**: Search algorithm optimization

### **Operational Efficiency**
- **Automated Syncing**: Real-time product data updates
- **Scalable Architecture**: Horizontal scaling support
- **High Availability**: Fault-tolerant design
- **Cost Optimization**: Efficient resource utilization

---

## 🔧 **Configuration**

### **Environment Variables**
```bash
# Database Configuration
DATABASE_URL=postgres://user:pass@localhost:5432/search
ELASTICSEARCH_URL=http://localhost:9200
REDIS_URL=redis://localhost:6379

# Service Configuration
SERVICE_PORT=8080
GRPC_PORT=50051
LOG_LEVEL=info

# Search Configuration
DEFAULT_PAGE_SIZE=20
MAX_PAGE_SIZE=100
CACHE_TTL=300s
```

### **Feature Flags**
```bash
# Feature Toggles
ENABLE_ANALYTICS=true
ENABLE_CACHING=true
ENABLE_FACETED_SEARCH=true
ENABLE_AUTOCOMPLETE=true
```

---

## 🚨 **Troubleshooting**

### **Common Issues**

#### **Search Performance**
- **Symptom**: Slow search responses
- **Causes**: Large index size, inefficient queries
- **Solutions**: Optimize queries, add caching, scale horizontally

#### **Sync Issues**
- **Symptom**: Stale product data
- **Causes**: Event processing failures, DLQ buildup
- **Solutions**: Check DLQ, restart consumers, verify event flow

#### **High Memory Usage**
- **Symptom**: Out of memory errors
- **Causes**: Large result sets, memory leaks
- **Solutions**: Implement pagination, optimize caching, profile memory

### **Debugging Commands**
```bash
# Check service health
curl http://localhost:8080/health/live

# Check Elasticsearch health
curl http://localhost:9200/_cluster/health

# Check Redis connectivity
redis-cli ping

# View service logs
docker logs search-service
```

---

## 📈 **Roadmap**

### **Q1 2026**
- ✅ **Completed**: Service review and optimization
- ✅ **Completed**: Linting fixes and code quality improvements
- 🔄 **In Progress**: Enhanced analytics and reporting
- 📋 **Planned**: ML-based search ranking improvements

### **Q2 2026**
- 🎯 **Goal**: Advanced search features
- 📋 **Planned**: Semantic search capabilities
- 📋 **Planned**: Personalized search results
- 📋 **Planned**: Voice search integration

### **Q3 2026**
- 🎯 **Goal**: Performance optimization
- 📋 **Planned**: Query optimization engine
- 📋 **Planned**: Advanced caching strategies
- 📋 **Planned**: Real-time search suggestions

---

## 📞 **Support & Contact**

### **Development Team**
- **Service Owner**: Search Service Team
- **Technical Lead**: Senior Software Engineer
- **DevOps**: Platform Engineering Team

### **Support Channels**
- **Documentation**: This service documentation
- **Monitoring**: Prometheus + Grafana dashboards
- **Alerting**: PagerDuty integration
- **Issues**: GitLab issue tracker

---

**Last Updated**: February 2, 2026  
**Next Review**: March 2, 2026  
**Version**: v4.0  
**Status**: ✅ Production Ready
