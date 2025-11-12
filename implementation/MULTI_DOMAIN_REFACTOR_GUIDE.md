# 🏗️ MULTI-DOMAIN ARCHITECTURE REFACTOR GUIDE

**Purpose**: Update all service implementation checklists to follow Catalog's multi-domain pattern  
**Date**: November 12, 2025  
**Status**: In Progress

---

## 📋 SERVICES TO UPDATE

### ✅ Already Multi-Domain
1. **Catalog** - Reference implementation ✅
2. **Loyalty-Rewards** - Updated ✅

### 🔄 Need Update to Multi-Domain
1. **Review** - Currently monolithic
2. **Notification** - Currently monolithic
3. **Shipping** - Currently monolithic
4. **Payment** - Currently monolithic
5. **Search** - Currently monolithic
6. **Order** - Need to verify structure

---

## 🎯 MULTI-DOMAIN PATTERN (from Catalog)

### Standard Directory Structure

```
service/
├── cmd/
│   └── service/
│       ├── main.go
│       └── wire.go
├── internal/
│   ├── biz/                      # Business Logic Layer (MULTI-DOMAIN)
│   │   ├── domain1/              # Domain 1
│   │   │   ├── domain1.go        # Usecase implementation
│   │   │   ├── dto.go            # Data Transfer Objects
│   │   │   ├── errors.go         # Domain-specific errors
│   │   │   └── provider.go       # Wire provider
│   │   ├── domain2/              # Domain 2
│   │   │   ├── domain2.go
│   │   │   ├── dto.go
│   │   │   ├── errors.go
│   │   │   └── provider.go
│   │   ├── events/               # Event Publishing
│   │   │   ├── publisher.go
│   │   │   └── events.go
│   │   └── biz.go                # Biz layer provider
│   ├── repository/               # Data Access Layer
│   │   ├── domain1/
│   │   │   ├── domain1.go        # Repository interface & impl
│   │   │   └── provider.go
│   │   ├── domain2/
│   │   │   ├── domain2.go
│   │   │   └── provider.go
│   │   └── repository.go
│   ├── client/                   # External Service Clients
│   │   ├── service1_client.go
│   │   ├── service2_client.go
│   │   └── client.go
│   ├── cache/                    # Cache Service
│   │   └── cache.go
│   ├── model/                    # Database Models (GORM)
│   │   ├── entity1.go
│   │   ├── entity2.go
│   │   └── entity3.go
│   ├── constants/                # Constants & Enums
│   │   └── constants.go
│   ├── observability/            # Metrics & Tracing
│   │   ├── metrics.go
│   │   └── tracing.go
│   ├── service/                  # gRPC Service Layer
│   │   ├── domain1_service.go
│   │   ├── domain2_service.go
│   │   └── service.go
│   ├── server/                   # HTTP/gRPC Servers
│   │   ├── http.go
│   │   ├── grpc.go
│   │   └── consul.go
│   ├── conf/                     # Configuration
│   │   ├── conf.proto
│   │   └── conf.pb.go
│   └── data/                     # Data initialization (optional)
│       └── data.go
├── api/                          # Proto definitions
├── configs/                      # Config files
├── migrations/                   # Database migrations
├── scripts/                      # Utility scripts
└── README.md
```

---

## 🔧 DOMAIN STRUCTURE TEMPLATE

### Domain Usecase File (`internal/biz/domain/domain.go`)

```go
package domain

import (
    "context"
    
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/service/internal/biz/events"
    "gitlab.com/ta-microservices/service/internal/model"
    repoDomain "gitlab.com/ta-microservices/service/internal/repository/domain"
)

// DomainRepo interface - use from repository package
type DomainRepo = repoDomain.DomainRepo

// DomainUsecase handles domain business logic
type DomainUsecase struct {
    repo           DomainRepo
    eventPublisher events.EventPublisher
    log            *log.Helper
}

func NewDomainUsecase(
    repo DomainRepo,
    eventPublisher events.EventPublisher,
    logger log.Logger,
) *DomainUsecase {
    return &DomainUsecase{
        repo:           repo,
        eventPublisher: eventPublisher,
        log:            log.NewHelper(logger),
    }
}

// Business logic methods...
```

### DTO File (`internal/biz/domain/dto.go`)

```go
package domain

type CreateRequest struct {
    Field1 string
    Field2 int
}

type UpdateRequest struct {
    ID     string
    Field1 string
}

type ListFilter struct {
    Status   string
    Page     int
    PageSize int
}
```

### Errors File (`internal/biz/domain/errors.go`)

```go
package domain

import "errors"

var (
    ErrNotFound      = errors.New("domain entity not found")
    ErrAlreadyExists = errors.New("domain entity already exists")
    ErrInvalidInput  = errors.New("invalid input")
)
```

### Provider File (`internal/biz/domain/provider.go`)

```go
package domain

import "github.com/google/wire"

// ProviderSet is domain providers.
var ProviderSet = wire.NewSet(NewDomainUsecase)
```

---

## 📦 REPOSITORY STRUCTURE TEMPLATE

### Repository File (`internal/repository/domain/domain.go`)

```go
package domain

import (
    "context"
    
    "gitlab.com/ta-microservices/service/internal/model"
    "gorm.io/gorm"
)

type DomainRepo interface {
    Create(ctx context.Context, entity *model.Entity) error
    Update(ctx context.Context, entity *model.Entity) error
    Delete(ctx context.Context, id string) error
    GetByID(ctx context.Context, id string) (*model.Entity, error)
    List(ctx context.Context, filter *Filter) ([]*model.Entity, int64, error)
}

type domainRepo struct {
    db *gorm.DB
}

func NewDomainRepo(db *gorm.DB) DomainRepo {
    return &domainRepo{db: db}
}

func (r *domainRepo) Create(ctx context.Context, entity *model.Entity) error {
    return r.db.WithContext(ctx).Create(entity).Error
}

// Other methods...
```

### Repository Provider (`internal/repository/domain/provider.go`)

```go
package domain

import "github.com/google/wire"

// ProviderSet is domain repository providers.
var ProviderSet = wire.NewSet(NewDomainRepo)
```

---

## 🔄 SERVICE-SPECIFIC DOMAIN BREAKDOWN

### 1. REVIEW SERVICE (4 Domains)

**Domains**:
- `review/` - Review CRUD, validation, image upload
- `rating/` - Product rating aggregation, distribution calculation
- `moderation/` - Auto-moderation, manual approval, spam detection
- `helpful/` - Helpful votes, vote tracking

**Repository Layer**:
- `repository/review/` - Review data access
- `repository/rating/` - Rating data access
- `repository/moderation/` - Moderation & reports
- `repository/helpful/` - Helpful votes

**External Clients**:
- `client/catalog_client.go` - Product verification
- `client/order_client.go` - Purchase verification
- `client/user_client.go` - User information

---

### 2. NOTIFICATION SERVICE (4 Domains)

**Domains**:
- `notification/` - Notification creation, sending
- `template/` - Template management, rendering
- `delivery/` - Delivery tracking, retry logic
- `preference/` - User notification preferences

**Repository Layer**:
- `repository/notification/`
- `repository/template/`
- `repository/delivery/`
- `repository/preference/`

**Provider Integrations** (in `internal/provider/`):
- `email/` - SendGrid, SES
- `sms/` - Twilio, SNS
- `push/` - Firebase

---

### 3. SHIPPING SERVICE (4 Domains)

**Domains**:
- `fulfillment/` - Fulfillment order management
- `shipment/` - Shipment creation, tracking
- `carrier/` - Carrier integration, rate calculation
- `tracking/` - Tracking updates, webhook handling

**Repository Layer**:
- `repository/fulfillment/`
- `repository/shipment/`
- `repository/carrier/`
- `repository/tracking/`

**Carrier Integrations** (in `internal/carrier/`):
- `ups/` - UPS integration
- `fedex/` - FedEx integration
- `dhl/` - DHL integration

---

### 4. PAYMENT SERVICE (5 Domains)

**Domains**:
- `payment/` - Payment processing
- `transaction/` - Transaction management
- `refund/` - Refund processing
- `method/` - Payment method management
- `webhook/` - Payment gateway webhooks

**Repository Layer**:
- `repository/payment/`
- `repository/transaction/`
- `repository/refund/`
- `repository/method/`

**Gateway Integrations** (in `internal/gateway/`):
- `stripe/` - Stripe integration
- `paypal/` - PayPal integration
- `vnpay/` - VNPay integration

---

### 5. SEARCH SERVICE (4 Domains)

**Domains**:
- `search/` - Search query processing
- `indexing/` - Document indexing
- `analytics/` - Search analytics
- `suggestion/` - Autocomplete, suggestions

**Repository Layer**:
- `repository/search/` - Search history
- `repository/analytics/` - Analytics data

**Search Engine** (in `internal/elasticsearch/`):
- `client.go` - ES client
- `index.go` - Index management
- `query.go` - Query builder

---

### 6. ORDER SERVICE (5 Domains)

**Domains**:
- `order/` - Order creation, management
- `item/` - Order items management
- `status/` - Order status tracking
- `cancellation/` - Order cancellation
- `validation/` - Order validation

**Repository Layer**:
- `repository/order/`
- `repository/item/`
- `repository/status/`

---

## 🎯 REFACTOR CHECKLIST FOR EACH SERVICE

### Phase 1: Structure Setup
- [ ] Create multi-domain directory structure
- [ ] Move existing code to appropriate domains
- [ ] Create repository layer
- [ ] Create model layer
- [ ] Create constants layer

### Phase 2: Domain Implementation
- [ ] Implement each domain usecase
- [ ] Create DTOs for each domain
- [ ] Define domain-specific errors
- [ ] Create wire providers

### Phase 3: Repository Layer
- [ ] Implement repository interfaces
- [ ] Implement repository methods
- [ ] Add transaction support
- [ ] Create repository providers

### Phase 4: Integration
- [ ] Create external service clients
- [ ] Implement event publishing
- [ ] Add cache layer
- [ ] Setup observability

### Phase 5: Service Layer
- [ ] Update gRPC services
- [ ] Update HTTP handlers
- [ ] Wire all dependencies
- [ ] Test integration

---

## 📝 WIRE DEPENDENCY INJECTION TEMPLATE

```go
//go:build wireinject
// +build wireinject

package main

import (
    "gitlab.com/ta-microservices/service/internal/biz/domain1"
    "gitlab.com/ta-microservices/service/internal/biz/domain2"
    "gitlab.com/ta-microservices/service/internal/biz/events"
    "gitlab.com/ta-microservices/service/internal/cache"
    "gitlab.com/ta-microservices/service/internal/client"
    "gitlab.com/ta-microservices/service/internal/conf"
    "gitlab.com/ta-microservices/service/internal/repository"
    "gitlab.com/ta-microservices/service/internal/server"
    "gitlab.com/ta-microservices/service/internal/service"
    
    "github.com/go-kratos/kratos/v2"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/google/wire"
)

func wireApp(*conf.Server, *conf.Data, log.Logger) (*kratos.App, func(), error) {
    panic(wire.Build(
        // Repository layer
        repository.ProviderSet,
        
        // Business logic layer (domains)
        domain1.ProviderSet,
        domain2.ProviderSet,
        events.ProviderSet,
        
        // Client layer
        client.ProviderSet,
        
        // Cache layer
        cache.ProviderSet,
        
        // Service layer
        service.ProviderSet,
        
        // Server layer
        server.ProviderSet,
        
        newApp,
    ))
}
```

---

## 🚀 BENEFITS OF MULTI-DOMAIN ARCHITECTURE

### 1. Separation of Concerns
- Each domain has clear, focused responsibilities
- Easier to understand and reason about code
- Reduced coupling between different features

### 2. Scalability
- Can scale individual domains independently
- Easy to add new domains without affecting existing ones
- Better resource allocation

### 3. Maintainability
- Smaller, focused files are easier to maintain
- Clear boundaries between domains
- Easier to locate and fix bugs

### 4. Testability
- Each domain can be tested independently
- Easier to mock dependencies
- Better test coverage

### 5. Team Collaboration
- Multiple developers can work on different domains
- Reduced merge conflicts
- Clear ownership of domains

### 6. Reusability
- Domains can be reused across services
- Shared patterns and structures
- Consistent codebase

---

## 📊 MIGRATION PRIORITY

### High Priority (Week 1-2)
1. **Review** - Simple structure, good starting point
2. **Payment** - Critical service, needs clean architecture

### Medium Priority (Week 3-4)
3. **Notification** - Multiple providers, benefits from separation
4. **Shipping** - Multiple carriers, similar to notification

### Low Priority (Week 5-6)
5. **Search** - Complex, can wait
6. **Order** - May already be structured, verify first

---

## 📚 REFERENCE IMPLEMENTATION

**Catalog Service** is the reference implementation:
- Location: `catalog/internal/biz/`
- Domains: `product/`, `category/`, `brand/`, `manufacturer/`, `cms/`
- Study this structure for best practices

---

*Generated: November 12, 2025*
*Status: Guide for refactoring all services to multi-domain architecture*
