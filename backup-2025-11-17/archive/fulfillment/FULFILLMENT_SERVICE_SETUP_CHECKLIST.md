# Fulfillment Service Setup Checklist

> **Goal:** Create new Fulfillment Service and remove fulfillment logic from Shipping Service  
> **Estimated Time:** 4-6 hours  
> **Status:** 🔴 Not Started

---

## 📋 Table of Contents

1. [Phase 1: Cleanup Shipping Service](#phase-1-cleanup-shipping-service)
2. [Phase 2: Create Fulfillment Service Structure](#phase-2-create-fulfillment-service-structure)
3. [Phase 3: Database Setup](#phase-3-database-setup)
4. [Phase 4: Core Implementation](#phase-4-core-implementation)
5. [Phase 5: Event Integration](#phase-5-event-integration)
6. [Phase 6: Docker & Deployment](#phase-6-docker--deployment)
7. [Phase 7: Testing & Validation](#phase-7-testing--validation)

---

## Phase 1: Cleanup Shipping Service

**Goal:** Remove fulfillment-related code from shipping service

### 1.1 Delete Fulfillment Folders
```bash
□ cd shipping/
□ rm -rf internal/biz/fulfillment/
□ rm -rf internal/repository/fulfillment/
□ rm -f internal/service/fulfillment.go
□ rm -f internal/model/fulfillment.go
```

### 1.2 Check for References
```bash
□ grep -r "fulfillment" internal/ --exclude-dir=vendor
□ grep -r "Fulfillment" internal/ --exclude-dir=vendor
□ Check api/shipping/v1/shipping.proto for fulfillment RPCs
```

### 1.3 Update Proto Files (if needed)
```bash
□ Open api/shipping/v1/shipping.proto
□ Comment or remove fulfillment-related RPCs:
  - CreateFulfillment
  - GetFulfillment
  - UpdateFulfillmentStatus
□ Run: make api
```

### 1.4 Update Service Provider
```bash
□ Open internal/service/provider.go
□ Remove fulfillment-related dependencies
□ Update wire.go if needed
□ Run: make wire
```

### 1.5 Rebuild Shipping Service
```bash
□ make build
□ Verify no compilation errors
□ Test: docker-compose up shipping
□ Check logs for errors
```

**✅ Phase 1 Complete:** Shipping service cleaned up

---

## Phase 2: Create Fulfillment Service Structure

**Goal:** Setup basic service structure

### 2.1 Copy Base Structure
```bash
□ cd /path/to/microservices/
□ cp -r warehouse/ fulfillment/
□ cd fulfillment/
```

### 2.2 Clean Up Copied Files
```bash
□ rm -rf bin/
□ rm -rf vendor/
□ rm -rf .git/
□ rm -f warehouse
□ rm -f worker
□ rm -f *.md (keep only README.md)
```

### 2.3 Update Module Name
```bash
□ Open go.mod
□ Change: module gitlab.com/ta-microservices/fulfillment
□ Run: go mod tidy
```

### 2.4 Update Package Imports
```bash
□ Find and replace in all .go files:
  - gitlab.com/ta-microservices/warehouse → gitlab.com/ta-microservices/fulfillment
□ Use: find . -name "*.go" -exec sed -i 's/warehouse/fulfillment/g' {} \;
```

### 2.5 Rename Main Binary
```bash
□ Open cmd/warehouse/main.go
□ Rename folder: mv cmd/warehouse cmd/fulfillment
□ Update Makefile binary name
```

**✅ Phase 2 Complete:** Basic structure created

---

## Phase 3: Database Setup

**Goal:** Create database schema for fulfillment service

See: [FULFILLMENT_SERVICE_DATABASE.md](./FULFILLMENT_SERVICE_DATABASE.md)

### 3.1 Create Migration Files
```bash
□ Create migrations/001_create_fulfillments_table.sql
□ Create migrations/002_create_picklists_table.sql
□ Create migrations/003_create_packages_table.sql
□ Create migrations/004_create_fulfillment_items_table.sql
□ Create migrations/005_create_indexes.sql
```

### 3.2 Update Database Config
```bash
□ Open configs/config.yaml
□ Update database name: fulfillment_db
□ Update service name: fulfillment
□ Update ports: 8010 (HTTP), 9010 (gRPC)
```

### 3.3 Add Database to init-db.sql
```bash
□ Open source/scripts/init-db.sql
□ Add: CREATE DATABASE fulfillment_db;
□ Add: GRANT ALL PRIVILEGES ON DATABASE fulfillment_db TO ecommerce_user;
```

**✅ Phase 3 Complete:** Database schema ready

---

## Phase 4: Core Implementation

**Goal:** Implement core business logic

See: [FULFILLMENT_SERVICE_IMPLEMENTATION.md](./FULFILLMENT_SERVICE_IMPLEMENTATION.md)

### 4.1 Define Models
```bash
□ Create internal/model/fulfillment.go
□ Create internal/model/picklist.go
□ Create internal/model/package.go
□ Create internal/model/fulfillment_item.go
```

### 4.2 Define Business Logic Interfaces
```bash
□ Create internal/biz/fulfillment/fulfillment.go
□ Create internal/biz/fulfillment/picklist.go
□ Create internal/biz/fulfillment/package.go
□ Define UseCase interfaces
```

### 4.3 Implement Repositories
```bash
□ Create internal/repository/fulfillment/fulfillment_repo.go
□ Create internal/repository/picklist/picklist_repo.go
□ Create internal/repository/package/package_repo.go
□ Implement CRUD operations
```

### 4.4 Implement Use Cases
```bash
□ Implement CreateFromOrder()
□ Implement StartPlanning()
□ Implement GeneratePicklist()
□ Implement ConfirmPicked()
□ Implement ConfirmPacked()
□ Implement MarkReadyToShip()
```

### 4.5 Create Service Layer
```bash
□ Create internal/service/fulfillment_service.go
□ Implement gRPC/HTTP handlers
□ Add validation logic
```

**✅ Phase 4 Complete:** Core logic implemented

---

## Phase 5: Event Integration

**Goal:** Setup event-driven communication

See: [FULFILLMENT_SERVICE_EVENTS.md](./FULFILLMENT_SERVICE_EVENTS.md)

### 5.1 Define Events
```bash
□ Create internal/events/fulfillment_events.go
□ Define event structures:
  - FulfillmentCreatedEvent
  - FulfillmentPlannedEvent
  - PicklistGeneratedEvent
  - FulfillmentPickedEvent
  - FulfillmentPackedEvent
  - FulfillmentReadyEvent
```

### 5.2 Implement Event Publisher
```bash
□ Create internal/events/publisher.go
□ Implement Dapr pub/sub integration
□ Add retry logic
```

### 5.3 Implement Event Handlers
```bash
□ Create internal/service/event_handler.go
□ Subscribe to: orders.order.confirmed
□ Handle order confirmed event
□ Create fulfillment on order confirmation
```

### 5.4 Configure Dapr Subscriptions
```bash
□ Update configs/config.yaml
□ Add Dapr pubsub configuration
□ Define subscription topics
```

**✅ Phase 5 Complete:** Event integration ready

---

## Phase 6: Docker & Deployment

**Goal:** Setup containerization and deployment

See: [FULFILLMENT_SERVICE_DEPLOYMENT.md](./FULFILLMENT_SERVICE_DEPLOYMENT.md)

### 6.1 Create Dockerfile
```bash
□ Create Dockerfile
□ Use multi-stage build
□ Optimize image size
```

### 6.2 Create docker-compose.yml
```bash
□ Create fulfillment/docker-compose.yml
□ Define fulfillment service
□ Define fulfillment-dapr sidecar
□ Add health checks
```

### 6.3 Update Root docker-compose.yml
```bash
□ Open root docker-compose.yml
□ Add: - fulfillment/docker-compose.yml to include section
```

### 6.4 Create Dapr Component
```bash
□ Create dapr/components/fulfillment-pubsub.yaml
□ Configure Redis pub/sub
```

### 6.5 Update Makefile
```bash
□ Add build targets
□ Add migration targets
□ Add docker targets
```

**✅ Phase 6 Complete:** Deployment ready

---

## Phase 7: Testing & Validation

**Goal:** Verify service works correctly

### 7.1 Run Migrations
```bash
□ docker-compose up postgres
□ cd fulfillment/
□ make migrate-up
□ Verify tables created
```

### 7.2 Start Service
```bash
□ docker-compose up fulfillment
□ Check logs for errors
□ Verify Consul registration
```

### 7.3 Health Check
```bash
□ curl http://localhost:8010/health
□ Verify response: {"status": "ok"}
```

### 7.4 Test Event Flow
```bash
□ Create test order in Order Service
□ Verify fulfillment created
□ Check fulfillment status transitions
□ Verify events published
```

### 7.5 Integration Testing
```bash
□ Test Order → Fulfillment flow
□ Test Fulfillment → Warehouse integration
□ Test Fulfillment → Shipping integration
□ Verify COD orders work correctly
```

**✅ Phase 7 Complete:** Service validated

---

## 🎯 Final Checklist

```
CLEANUP:
□ Shipping service fulfillment code removed
□ Shipping service builds successfully
□ Shipping service runs without errors

NEW SERVICE:
□ Fulfillment service structure created
□ Database schema created
□ Core business logic implemented
□ Event integration working
□ Docker setup complete
□ Service starts successfully
□ Health checks passing

INTEGRATION:
□ Order → Fulfillment event flow working
□ Fulfillment → Warehouse integration working
□ Fulfillment → Shipping integration working
□ COD orders handled correctly

DOCUMENTATION:
□ README.md updated
□ API documentation created
□ Event documentation created
□ Deployment guide created
```

---

## 📝 Notes

- Keep shipping service running during development
- Test each phase before moving to next
- Backup database before running migrations
- Monitor logs for errors
- Update documentation as you go

---

**Next Steps:** Start with Phase 1 - Cleanup Shipping Service
