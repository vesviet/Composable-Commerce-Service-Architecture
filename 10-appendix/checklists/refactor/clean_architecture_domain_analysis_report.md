# 📋 Architectural Analysis & Refactoring Report: Clean Architecture & Domain-Driven Design (DDD)

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Microservice Core Layers, Data Entities vs Core Domain Entities Isolated Mapping  

---

## 🎯 Executive Summary
Strict adherence to Clean Architecture is the bedrock of maintainable e-commerce platforms. The core Domain logic (`internal/biz`) must remain framework-agnostic and entirely isolated from underlying database definitions (`gorm`) or transport mechanics (`protobuf`).  
All domain leakage issues in the `customer` service have been fully resolved.

## ✅ ALL ISSUES RESOLVED

### Track I: Core Customer Entity (DONE)
- `model.Customer` completely eliminated from `biz/customer/` and `biz/segment/`
- All repo interfaces and usecases return `*domain.Customer`
- Data layer maps via `mapper.CustomerToDomain()` / `mapper.DomainToCustomerModel()`

### Track I Step 5c: Sub-Aggregate Types (DONE)
- `CustomerProfile`, `CustomerPreferences`, `OutboxEvent`, `VerificationToken` — all migrated to domain types
- `CustomerSegment`, `CustomerSegmentMembership` — all migrated to domain types
- **0 model imports remain** in `internal/biz/`

### Track I-B: Repository Interface Cleanup (DONE)
- Deleted stale `repository/address/` — biz-layer defines own `AddressRepo` using domain types
- Deleted stale `repository/audit/` — biz-layer defines own `AuditRepo` using domain types
- Deleted stale `repository/wishlist/` — biz-layer defines own `WishlistRepo`/`WishlistItemRepo` using domain types
- Moved `repository/customer_group/` → `data/postgres/customer_group.go` (was misplaced data impl)
- `repository/processed_event/` — kept as infrastructure concern (only used within `data/` layer)

### Previously Fixed
- **Segment Package Domain Leak**: `rules_engine.go` and `segment.go` now operate on `*domain.Customer` instead of `*model.Customer`. Three bridge mappers deleted (~82 lines).
- **View/API Layer Leakage Plugged**: The severe violations where `ToCustomerReply()` and `ToStableCustomerGroupReply()` embedded Protobuf mapping code directly inside the GORM `internal/model/customer.go` file have been completely eradicated.
- **Pure Query Isolation**: Across all surveyed `internal/biz` directories, there are zero instances of `gorm.DB` references or raw SQL query logic.

---

## 📊 Current State

| Layer | `model.*` Imports | Status |
|-------|-------------------|--------|
| `internal/biz/` | **0** | ✅ Clean |
| `internal/service/` | **0** | ✅ Clean |
| `internal/repository/` | **1** (`processed_event` — infrastructure only) | ✅ Acceptable |
| `internal/data/` | Model used correctly for GORM operations | ✅ Correct per Clean Architecture |

---

## 📋 Architectural Guidelines & Playbook

### The Reference Implementation (Isolation via Mapping)

**Layer 1. Business Domain (`internal/biz`):**
Defines pure Go structs. No framework tags.
```go
type Customer struct {
    ID           string
    Email        string
    CustomerType int
}
```

**Layer 2. Data Persistence (`internal/data`):**
Retrieves the tagged schema models and maps them to pure Domain structs.
```go
func (r *customerRepo) Get(ctx context.Context) (*domain.Customer, error) {
    var m model.Customer
    // ... GORM query ...
    return mapper.CustomerToDomain(&m), nil
}
```
