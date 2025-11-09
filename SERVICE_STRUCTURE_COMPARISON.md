# 📊 Service Structure Comparison & Best Practices

> **Date:** November 9, 2024  
> **Purpose:** Compare internal structure of Pricing, Catalog, and Warehouse services  
> **Goal:** Determine best practices for scalable microservice architecture

---

## 🔍 Structure Overview

### 1. Pricing Service (Simple Structure)

```
pricing/internal/
├── biz/                    # Business logic (flat)
│   ├── biz.go
│   ├── pricing.go
│   └── dynamic_pricing.go
├── cache/                  # Caching layer
│   ├── price_cache.go
│   └── provider.go
├── client/                 # External service clients
│   ├── catalog_client.go
│   ├── warehouse_client.go
│   └── provider.go
├── conf/                   # Configuration
├── data/                   # Data access (flat)
│   ├── data.go
│   ├── pricing.go
│   ├── discount.go
│   ├── price_rule.go
│   └── tax_rule.go
├── events/                 # Event handling
│   ├── handler.go
│   ├── publisher.go
│   ├── price_events.go
│   └── provider.go
├── server/                 # HTTP/gRPC servers
├── service/                # Service layer (flat)
│   ├── pricing.go
│   └── service.go
└── worker/                 # Background workers
    └── sync/
        ├── incremental_sync.go
        └── full_sync.go
```

**Characteristics:**
- ✅ Simple, flat structure
- ✅ Easy to navigate
- ✅ Good for small-medium services
- ❌ All business logic in one place
- ❌ Hard to scale when adding more domains

---

### 2. Catalog Service (Domain-Driven Structure)

```
catalog/internal/
├── biz/                    # Business logic (by domain)
│   ├── brand/
│   │   ├── brand.go
│   │   ├── dto.go
│   │   └── provider.go
│   ├── category/
│   │   ├── category.go
│   │   ├── dto.go
│   │   └── provider.go
│   ├── product/
│   │   ├── product.go
│   │   ├── dto.go
│   │   ├── errors.go
│   │   └── provider.go
│   ├── manufacturer/
│   ├── cms/
│   └── events/
├── client/                 # External clients
│   ├── pricing_client.go
│   ├── warehouse_client.go
│   ├── circuitbreaker/
│   └── provider.go
├── conf/                   # Configuration
├── data/                   # Data access (by type)
│   ├── postgres/
│   │   ├── db.go
│   │   ├── product.go
│   │   ├── category.go
│   │   ├── brand.go
│   │   └── transaction.go
│   ├── eventbus/
│   │   ├── event_processor.go
│   │   ├── warehouse_stock_update.go
│   │   └── pricing_price_update.go
│   └── provider.go
├── model/                  # Domain models (separate)
│   ├── product.go
│   ├── category.go
│   ├── brand.go
│   └── manufacturer.go
├── repository/             # Repository pattern (by domain)
│   ├── product/
│   │   └── product.go
│   ├── category/
│   │   └── category.go
│   ├── brand/
│   │   └── brand.go
│   └── manufacturer/
├── observability/          # Monitoring
│   └── prometheus/
│       └── metrics.go
├── job/                    # One-time jobs
│   └── stock_sync.go
├── server/                 # HTTP/gRPC servers
├── service/                # Service layer (by domain)
│   ├── product_service.go
│   ├── category_service.go
│   ├── brand_service.go
│   ├── admin_service.go
│   ├── events.go
│   └── service.go
└── worker/                 # Background workers
    ├── base/
    │   └── worker.go
    └── cron/
        ├── stock_sync.go
        └── provider.go
```

**Characteristics:**
- ✅ Domain-driven design (DDD)
- ✅ Clear separation of concerns
- ✅ Easy to scale (add new domains)
- ✅ Repository pattern
- ✅ Separate models from business logic
- ✅ Observability built-in
- ✅ Circuit breaker pattern
- 🟡 More complex structure
- 🟡 More files to manage

---

### 3. Warehouse Service (Hybrid Structure)

```
warehouse/internal/
├── biz/                    # Business logic (by domain)
│   ├── warehouse/
│   │   ├── warehouse.go
│   │   └── provider.go
│   ├── inventory/
│   │   ├── inventory.go
│   │   └── provider.go
│   ├── reservation/
│   │   ├── reservation.go
│   │   └── provider.go
│   ├── transaction/
│   │   ├── transaction.go
│   │   └── provider.go
│   ├── distributor/
│   │   ├── distributor.go
│   │   └── provider.go
│   └── events/
│       ├── event_publisher.go
│       └── provider.go
├── client/                 # External clients
│   ├── catalog_client.go
│   ├── circuitbreaker/
│   └── provider.go
├── conf/                   # Configuration
├── data/                   # Data access (by type)
│   ├── postgres/
│   │   ├── db.go
│   │   ├── warehouse.go
│   │   ├── inventory.go
│   │   ├── reservation.go
│   │   ├── transaction.go
│   │   ├── distributor.go
│   │   └── transaction_util.go
│   ├── grpc_client/
│   │   └── catalog_client.go
│   └── provider.go
├── model/                  # Domain models (separate)
│   ├── warehouse.go
│   ├── inventory.go
│   └── distributor.go
├── repository/             # Repository pattern (by domain)
│   ├── warehouse/
│   │   └── warehouse.go
│   ├── inventory/
│   │   └── inventory.go
│   ├── reservation/
│   │   └── reservation.go
│   ├── transaction/
│   │   └── transaction.go
│   └── distributor/
│       └── distributor.go
├── observability/          # Monitoring
│   └── prometheus/
│       └── metrics.go
├── server/                 # HTTP/gRPC servers
├── service/                # Service layer (by domain)
│   ├── warehouse_service.go
│   ├── inventory_service.go
│   ├── product_service.go
│   ├── distributor_service.go
│   ├── event_handler.go
│   ├── health.go
│   └── service.go
└── worker/                 # Background workers
    ├── base/
    │   └── worker.go
    └── cron/
        ├── stock_change_detector.go
        └── provider.go
```

**Characteristics:**
- ✅ Domain-driven design (DDD)
- ✅ Clear separation of concerns
- ✅ Repository pattern
- ✅ Separate models
- ✅ Observability built-in
- ✅ Circuit breaker pattern
- ✅ Transaction utilities
- 🟡 Similar to Catalog but more organized

---

## 📊 Detailed Comparison

| Aspect | Pricing (Simple) | Catalog (DDD) | Warehouse (DDD) | Winner |
|--------|------------------|---------------|-----------------|--------|
| **Structure** | Flat | Domain-based | Domain-based | 🏆 Catalog/Warehouse |
| **Scalability** | Low | High | High | 🏆 Catalog/Warehouse |
| **Maintainability** | Medium | High | High | 🏆 Catalog/Warehouse |
| **Learning Curve** | Easy | Medium | Medium | 🏆 Pricing |
| **Code Organization** | Simple | Excellent | Excellent | 🏆 Catalog/Warehouse |
| **Separation of Concerns** | Basic | Excellent | Excellent | 🏆 Catalog/Warehouse |
| **Repository Pattern** | ❌ No | ✅ Yes | ✅ Yes | 🏆 Catalog/Warehouse |
| **Model Separation** | ❌ No | ✅ Yes | ✅ Yes | 🏆 Catalog/Warehouse |
| **Observability** | ❌ No | ✅ Yes | ✅ Yes | 🏆 Catalog/Warehouse |
| **Circuit Breaker** | ❌ No | ✅ Yes | ✅ Yes | 🏆 Catalog/Warehouse |
| **Event Handling** | ✅ Good | ✅ Excellent | ✅ Excellent | 🏆 Catalog/Warehouse |
| **Worker Organization** | Basic | Good | Good | 🏆 Catalog/Warehouse |
| **File Count** | Low | High | High | 🏆 Pricing (simplicity) |
| **Best For** | Small services | Medium-Large | Medium-Large | Depends on size |

---

## 🎯 Recommendations

### ⭐ **RECOMMENDED: Catalog/Warehouse Structure (Domain-Driven Design)**

**Why?**
1. **Scalability** - Easy to add new domains without affecting existing code
2. **Maintainability** - Clear boundaries between domains
3. **Team Collaboration** - Different teams can work on different domains
4. **Testing** - Easier to test individual domains
5. **Code Reusability** - Repository pattern promotes reuse
6. **Production-Ready** - Built-in observability and circuit breakers

**When to Use:**
- ✅ Medium to large services (3+ domains)
- ✅ Services expected to grow
- ✅ Multiple team members
- ✅ Complex business logic
- ✅ Production-critical services

---

### 🟡 **ACCEPTABLE: Pricing Structure (Simple/Flat)**

**Why?**
1. **Simplicity** - Easy to understand and navigate
2. **Quick Development** - Faster to implement initially
3. **Low Overhead** - Less boilerplate code

**When to Use:**
- ✅ Small services (1-2 domains)
- ✅ Proof of concept / MVP
- ✅ Services that won't grow much
- ✅ Single developer projects

**Problems:**
- ❌ Hard to scale when adding more features
- ❌ Business logic mixed with data access
- ❌ No clear domain boundaries
- ❌ Missing production features (observability, circuit breaker)

---

## 🏗️ Recommended Structure (Best Practices)

### Standard Microservice Structure

```
service/internal/
├── biz/                          # Business Logic Layer (Domain-Driven)
│   ├── domain1/
│   │   ├── domain1.go           # Business logic
│   │   ├── dto.go               # Data Transfer Objects
│   │   ├── errors.go            # Domain-specific errors
│   │   └── provider.go          # Wire provider
│   ├── domain2/
│   │   └── ...
│   └── events/                   # Event publishing
│       ├── event_publisher.go
│       └── provider.go
│
├── repository/                   # Repository Pattern (Data Access Interface)
│   ├── domain1/
│   │   └── domain1.go           # Repository interface + impl
│   └── domain2/
│       └── domain2.go
│
├── model/                        # Domain Models (Separate from business logic)
│   ├── domain1.go
│   └── domain2.go
│
├── data/                         # Data Layer (Infrastructure)
│   ├── postgres/                # Database implementations
│   │   ├── db.go
│   │   ├── domain1.go
│   │   ├── domain2.go
│   │   └── transaction.go
│   ├── eventbus/                # Event bus implementations
│   │   ├── event_processor.go
│   │   └── handlers.go
│   └── provider.go
│
├── client/                       # External Service Clients
│   ├── service1_client.go
│   ├── service2_client.go
│   ├── circuitbreaker/          # Circuit breaker pattern
│   │   └── circuit_breaker.go
│   └── provider.go
│
├── cache/                        # Caching Layer (if needed)
│   ├── cache.go
│   └── provider.go
│
├── observability/                # Monitoring & Metrics
│   └── prometheus/
│       └── metrics.go
│
├── service/                      # Service Layer (gRPC/HTTP handlers)
│   ├── domain1_service.go
│   ├── domain2_service.go
│   ├── health.go
│   └── service.go
│
├── server/                       # Server Configuration
│   ├── http.go
│   ├── grpc.go
│   ├── consul.go
│   └── server.go
│
├── worker/                       # Background Workers
│   ├── base/
│   │   └── worker.go            # Base worker interface
│   └── cron/
│       ├── job1.go
│       ├── job2.go
│       └── provider.go
│
├── job/                          # One-time Jobs (optional)
│   └── migration_job.go
│
└── conf/                         # Configuration
    ├── conf.proto
    └── conf.pb.go
```

---

## 📋 Layer Responsibilities

### 1. **biz/** - Business Logic Layer
- **Purpose:** Core business logic and use cases
- **Contains:** Domain entities, business rules, validation
- **Dependencies:** Can depend on repository interfaces, NOT on data implementations
- **Example:**
  ```go
  // biz/product/product.go
  type ProductUsecase struct {
      repo       repository.ProductRepo
      eventPub   events.EventPublisher
      cache      cache.Cache
  }
  
  func (uc *ProductUsecase) CreateProduct(ctx, req) (*Product, error) {
      // Business logic here
      // Validation, rules, calculations
  }
  ```

### 2. **repository/** - Repository Pattern
- **Purpose:** Abstract data access, define interfaces
- **Contains:** Repository interfaces and implementations
- **Benefits:** Easy to mock for testing, swap implementations
- **Example:**
  ```go
  // repository/product/product.go
  type ProductRepo interface {
      Create(ctx, product) error
      GetByID(ctx, id) (*Product, error)
      Update(ctx, product) error
      Delete(ctx, id) error
  }
  ```

### 3. **model/** - Domain Models
- **Purpose:** Define domain entities
- **Contains:** Structs representing business entities
- **Separate from:** Database models (GORM structs)
- **Example:**
  ```go
  // model/product.go
  type Product struct {
      ID          string
      Name        string
      Price       float64
      Stock       int
      CreatedAt   time.Time
  }
  ```

### 4. **data/** - Data Layer
- **Purpose:** Implement data access (database, cache, external APIs)
- **Contains:** Database implementations, migrations, transactions
- **Example:**
  ```go
  // data/postgres/product.go
  type ProductRepo struct {
      db *gorm.DB
  }
  
  func (r *ProductRepo) Create(ctx, product) error {
      // GORM implementation
  }
  ```

### 5. **client/** - External Service Clients
- **Purpose:** Communicate with other microservices
- **Contains:** HTTP/gRPC clients, circuit breakers, retry logic
- **Example:**
  ```go
  // client/warehouse_client.go
  type WarehouseClient interface {
      GetStock(ctx, sku) (int, error)
  }
  ```

### 6. **service/** - Service Layer
- **Purpose:** Handle HTTP/gRPC requests, map to business logic
- **Contains:** API handlers, request/response mapping
- **Example:**
  ```go
  // service/product_service.go
  func (s *ProductService) CreateProduct(ctx, req) (*pb.Product, error) {
      // Map request to domain
      // Call business logic
      // Map response
  }
  ```

### 7. **worker/** - Background Workers
- **Purpose:** Handle background jobs, cron tasks
- **Contains:** Scheduled jobs, event processors
- **Example:**
  ```go
  // worker/cron/stock_sync.go
  type StockSyncWorker struct {
      productUC *product.ProductUsecase
  }
  
  func (w *StockSyncWorker) Run(ctx) error {
      // Sync stock every 5 minutes
  }
  ```

---

## 🔄 Migration Path: Pricing → Domain-Driven

### Current Pricing Structure Issues

1. **Flat biz/ folder** - All business logic in 3 files
2. **No repository pattern** - Data access mixed with business logic
3. **No model separation** - Models defined in biz layer
4. **No observability** - Missing Prometheus metrics
5. **No circuit breaker** - External clients without protection

### Recommended Refactoring

#### Step 1: Separate Domains (2 hours)

```bash
# Current
biz/
├── pricing.go
├── dynamic_pricing.go
└── biz.go

# Refactor to
biz/
├── price/
│   ├── price.go              # Base pricing logic
│   ├── dto.go
│   ├── errors.go
│   └── provider.go
├── discount/
│   ├── discount.go           # Discount logic
│   ├── dto.go
│   └── provider.go
├── tax/
│   ├── tax.go                # Tax calculation
│   ├── dto.go
│   └── provider.go
├── dynamic/
│   ├── dynamic_pricing.go    # Dynamic pricing
│   ├── dto.go
│   └── provider.go
└── events/
    ├── event_publisher.go
    └── provider.go
```

#### Step 2: Add Repository Pattern (3 hours)

```bash
# Create repository layer
repository/
├── price/
│   └── price.go              # PriceRepo interface
├── discount/
│   └── discount.go           # DiscountRepo interface
├── tax/
│   └── tax.go                # TaxRepo interface
└── rule/
    └── rule.go               # RuleRepo interface

# Move implementations to data/postgres/
data/postgres/
├── db.go
├── price.go                  # Implements PriceRepo
├── discount.go               # Implements DiscountRepo
├── tax.go                    # Implements TaxRepo
└── rule.go                   # Implements RuleRepo
```

#### Step 3: Separate Models (1 hour)

```bash
# Create model layer
model/
├── price.go
├── discount.go
├── tax.go
└── rule.go
```

#### Step 4: Add Observability (2 hours)

```bash
# Add monitoring
observability/
└── prometheus/
    └── metrics.go

# Metrics to track:
- pricing_calculations_total
- pricing_calculation_duration_seconds
- pricing_cache_hits_total
- pricing_cache_misses_total
- pricing_external_calls_total
```

#### Step 5: Add Circuit Breaker (1 hour)

```bash
# Add circuit breaker
client/
├── circuitbreaker/
│   └── circuit_breaker.go
├── warehouse_client.go       # Use circuit breaker
└── catalog_client.go         # Use circuit breaker
```

**Total Refactoring Time:** ~9 hours

---

## ✅ Best Practices Summary

### DO ✅

1. **Use Domain-Driven Design** for services with 3+ domains
2. **Separate concerns** - biz, repository, model, data, service
3. **Repository pattern** - Abstract data access
4. **Separate models** - Domain models vs database models
5. **Add observability** - Prometheus metrics from day 1
6. **Circuit breakers** - Protect external service calls
7. **Provider pattern** - Use Wire for dependency injection
8. **Error handling** - Domain-specific errors
9. **DTOs** - Separate request/response from domain models
10. **Worker base** - Common interface for all workers

### DON'T ❌

1. **Don't mix layers** - Keep business logic out of data layer
2. **Don't skip repository** - Direct database access in business logic
3. **Don't ignore monitoring** - Add metrics from the start
4. **Don't hardcode** - Use configuration for all external dependencies
5. **Don't skip circuit breakers** - External calls can fail
6. **Don't use flat structure** - For services that will grow
7. **Don't mix models** - Domain models ≠ database models
8. **Don't skip tests** - Each layer should be testable
9. **Don't ignore errors** - Proper error handling and logging
10. **Don't skip documentation** - Document domain boundaries

---

## 🎯 Final Recommendation

### For New Services
**Use Catalog/Warehouse Structure (Domain-Driven Design)**

### For Existing Pricing Service
**Option 1:** Keep as-is if service won't grow much  
**Option 2:** Refactor to DDD structure (~9 hours investment)

### Decision Criteria

| Service Size | Domains | Team Size | Growth Expected | Recommendation |
|--------------|---------|-----------|-----------------|----------------|
| Small | 1-2 | 1 | Low | Simple (Pricing style) |
| Medium | 3-5 | 2-3 | Medium | DDD (Catalog style) |
| Large | 6+ | 4+ | High | DDD (Warehouse style) |

---

## 📚 References

### Internal Examples
- ✅ **Catalog Service** - Best example of DDD structure
- ✅ **Warehouse Service** - Best example of repository pattern
- 🟡 **Pricing Service** - Simple structure (needs refactoring)

### External Resources
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html)
- [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Go Project Layout](https://github.com/golang-standards/project-layout)

---

**Conclusion:** Catalog/Warehouse structure is **RECOMMENDED** for all new services and services expected to scale. Pricing service should be refactored when time permits.

**Created:** November 9, 2024  
**Status:** ✅ Complete

