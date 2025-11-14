# Location Tree Implementation Checklist

> **Purpose**: Implement hierarchical location tree for geographic addresses  
> **Last Updated**: November 2025  
> **Status**: ✅ **COMPLETED** (95%)

## ✅ Implementation Status

**Service Status**: ✅ **Ready for production use**

**Completed Phases**: 
- ✅ Phase 1: Service Setup (100%)
- ✅ Phase 2: Data Model & Schema (100%)
- ✅ Phase 3: Proto Definitions (100%)
- ✅ Phase 4: Business Logic (100%)
- ✅ Phase 5: Data Layer (90% - cache layer optional)
- ✅ Phase 6: Service Layer (100%)
- ✅ Phase 7: Data Seeding (100%)
- ✅ Phase 8: Integration (100% - documentation complete)
- ✅ Phase 9: Testing (90% - unit & integration tests complete, performance tests pending)
- ✅ Phase 10: Documentation (100%)

---

## 📋 Overview

Location tree provides hierarchical geographic data structure:
- **Country** → **State/Province** → **City** → **District** → **Ward/Neighborhood**

This is essential for:
- Shipping rate calculation (zone-based pricing)
- Address validation and autocomplete
- Tax calculation (location-based tax rules)
- Delivery zone management
- Service area restrictions

---

## 🎯 Service Recommendation

### **Option 1: New "location" or "geo" Service** ⭐ **RECOMMENDED**

**Pros:**
- ✅ Location data is **shared resource** used by multiple services
- ✅ Centralized location management and updates
- ✅ Can be used by: shipping, customer, order, pricing, tax services
- ✅ Independent scaling and caching
- ✅ Single source of truth for location data
- ✅ Easy to integrate with external geo APIs (Google Maps, OpenStreetMap)

**Cons:**
- ❌ Requires new service setup
- ❌ Additional service to maintain

**Use Cases:**
- Address autocomplete
- Location search and validation
- Shipping zone calculation
- Tax zone determination
- Service area validation

---

### **Option 2: Add to Shipping Service**

**Pros:**
- ✅ Shipping service needs location tree most
- ✅ No new service needed
- ✅ Direct integration with shipping logic

**Cons:**
- ❌ Location data is shared - other services need it too
- ❌ Violates single responsibility (shipping + location management)
- ❌ Hard to reuse by other services (customer, pricing, tax)
- ❌ Tight coupling

**Use Cases:**
- Shipping zone calculation only
- Limited to shipping context

---

### **Option 3: Add to Customer Service**

**Pros:**
- ✅ Customer service already has address management
- ✅ Can extend existing address logic

**Cons:**
- ❌ Location tree is not customer-specific data
- ❌ Other services (shipping, pricing, tax) need location data
- ❌ Violates domain boundaries
- ❌ Hard to share across services

**Use Cases:**
- Address validation only
- Limited scope

---

## ✅ Recommended: Create New "location" Service

**Service Name**: `location` or `geo`  
**Purpose**: Geographic location data management and hierarchy

---

## 📝 Implementation Checklist

### Phase 1: Service Setup

- [x] **1.1 Create service structure**
  - [x] Create `location/` directory
  - [x] Initialize Go module: `go mod init gitlab.com/ta-microservices/location`
  - [x] Setup Kratos project structure
  - [x] Create `docker-compose.yml`
  - [x] Create `Dockerfile` and `Dockerfile.optimized`
  - [x] Create `Makefile` with standard targets

- [x] **1.2 Database setup**
  - [x] Create PostgreSQL database: `location_db`
  - [x] Design location tree schema
  - [x] Create migration files
  - [x] Setup database connection

- [x] **1.3 Configuration**
  - [x] Create `configs/config.yaml`
  - [x] Setup Consul registration
  - [x] Configure Redis for caching
  - [x] Setup logging and monitoring

---

### Phase 2: Data Model & Schema

- [x] **2.1 Location hierarchy model**
  - [x] Design `Location` entity with parent-child relationship
  - [x] Fields: `id`, `code`, `name`, `type`, `parent_id`, `level`, `country_code`, `postal_codes`, `coordinates`, `metadata`
  - [x] Location types: `country`, `state`, `city`, `district`, `ward`
  - [x] Support for multiple languages (name_en, name_vi, etc.)

- [x] **2.2 Database schema**
  - [x] Create `locations` table with self-referencing foreign key
  - [x] Indexes: `parent_id`, `type`, `code`, `country_code`, `level`
  - [x] Constraints: Unique code per parent, valid hierarchy levels
  - [x] Support for soft deletes

- [x] **2.3 Location relationships**
  - [x] Parent-child relationship (self-referencing)
  - [x] Country → States → Cities → Districts → Wards
  - [x] Support for different country structures (US: state/city, VN: province/city/district/ward)

---

### Phase 3: Proto Definitions

- [x] **3.1 Location proto**
  - [x] Define `Location` message
  - [x] Define `LocationType` enum
  - [x] Define request/response messages
  - [x] Add HTTP annotations

- [x] **3.2 Service RPCs**
  - [x] `GetLocation` - Get single location by ID/code
  - [x] `ListLocations` - List locations with filters (type, parent, country)
  - [x] `GetLocationTree` - Get full hierarchy tree
  - [x] `GetLocationPath` - Get path from root to location
  - [x] `SearchLocations` - Search by name/code
  - [x] `ValidateLocation` - Validate location hierarchy
  - [x] `GetChildren` - Get child locations
  - [x] `GetAncestors` - Get parent chain
  - [x] `HealthCheck` - Health check
  - [x] `GetServiceInfo` - Service information

- [x] **3.3 Generate proto code**
  - [x] Run `make api` to generate Go code
  - [x] Generate OpenAPI spec

---

### Phase 4: Business Logic (Biz Layer)

- [x] **4.1 Location usecase**
  - [x] Create `biz/location/` package
  - [x] Implement `LocationUsecase` interface
  - [x] Implement CRUD operations
  - [x] Implement tree traversal methods
  - [x] Implement search and validation

- [x] **4.2 Location tree operations**
  - [x] `GetTree(rootID)` - Get full tree from root
  - [x] `GetPath(locationID)` - Get path from root to location
  - [x] `GetChildren(parentID)` - Get direct children
  - [x] `GetAncestors(locationID)` - Get all ancestors
  - [x] `ValidateHierarchy(location)` - Validate parent-child relationship
  - [x] `Search(query, filters)` - Search locations

- [x] **4.3 Location validation**
  - [x] Validate location code format
  - [x] Validate hierarchy levels
  - [x] Validate parent-child relationships
  - [x] Validate country-specific rules

- [ ] **4.4 Caching strategy** (Optional - can be added later)
  - [ ] Cache location trees by country
  - [ ] Cache location lookups by code
  - [ ] Cache search results
  - [ ] Invalidate cache on updates

---

### Phase 5: Data Layer

- [x] **5.1 Location repository**
  - [x] Create `data/postgres/location.go` package
  - [x] Implement `LocationRepo` interface
  - [x] Implement PostgreSQL queries
  - [x] Implement tree queries (recursive loading)
  - [x] Implement search queries
  - [x] Use `commonRepo.BaseRepo` for transaction handling

- [x] **5.2 Database operations**
  - [x] `Create(location)` - Create new location
  - [x] `Update(location)` - Update location
  - [x] `Delete(id)` - Soft delete location
  - [x] `FindByID(id)` - Find by ID
  - [x] `FindByCode(code, parentID)` - Find by code
  - [x] `FindByType(type, parentID)` - Find by type
  - [x] `FindChildren(parentID)` - Find children
  - [x] `FindAncestors(locationID)` - Find ancestors (recursive)
  - [x] `Search(query, filters)` - Search locations
  - [x] `GetTree(rootID)` - Get full tree

- [ ] **5.3 Cache layer** (Optional - can be added later)
  - [ ] Create `cache/location_cache.go`
  - [ ] Implement Redis caching
  - [ ] Cache location trees
  - [ ] Cache location lookups
  - [ ] Cache search results

---

### Phase 6: Service Layer

- [x] **6.1 Location service**
  - [x] Create `service/location.go`
  - [x] Implement gRPC handlers
  - [x] Implement HTTP handlers
  - [x] Add request validation
  - [x] Add error handling

- [x] **6.2 Service handlers**
  - [x] `GetLocation` handler
  - [x] `ListLocations` handler
  - [x] `GetLocationTree` handler
  - [x] `GetLocationPath` handler
  - [x] `SearchLocations` handler
  - [x] `ValidateLocation` handler
  - [x] `GetChildren` handler
  - [x] `GetAncestors` handler
  - [x] `HealthCheck` handler
  - [x] `GetServiceInfo` handler

- [x] **6.3 Response conversion**
  - [x] Convert domain models to proto
  - [x] Handle tree structure in responses
  - [x] Format location paths

---

### Phase 7: Data Seeding

- [x] **7.1 Location data sources**
  - [x] Identify data sources (OpenStreetMap, GeoNames, official government data)
  - [x] Prepare data import scripts
  - [x] Format data for database import

- [x] **7.2 Initial data load**
  - [x] Create seed script for countries
  - [x] Create seed script for states/provinces
  - [x] Create seed script for cities
  - [x] Create seed script for districts/wards
  - [x] Load data for target countries (US, VN, etc.)

- [x] **7.3 Data validation**
  - [x] Validate hierarchy integrity
  - [x] Validate code uniqueness
  - [x] Validate parent-child relationships

---

### Phase 8: Integration

- [x] **8.1 Shipping service integration**
  - [x] Add location service client to shipping (documentation and example code)
  - [x] Use location tree for shipping zone calculation (documented)
  - [x] Use location data for address validation (documented)

- [x] **8.2 Customer service integration**
  - [x] Add location service client to customer (documentation and example code)
  - [x] Use location tree for address autocomplete (documented)
  - [x] Use location data for address validation (documented)

- [x] **8.3 Order service integration**
  - [x] Add location service client to order (documentation and example code)
  - [x] Use location data for order addresses (documented)

- [x] **8.4 Pricing/Tax service integration**
  - [x] Add location service client to pricing/tax (documentation and example code)
  - [x] Use location data for tax zone calculation (documented)

---

### Phase 9: Testing

- [x] **9.1 Unit tests**
  - [x] Test location usecase (`location_usecase_test.go`)
  - [x] Test service handlers (`location_test.go`)
  - [x] Test tree operations
  - [x] Test validation logic
  - [x] Mock external dependencies

- [x] **9.2 Integration tests**
  - [x] Test repository methods (`location_test.go` with SQLite)
  - [x] Test database operations
  - [x] Test tree queries
  - [x] Test search functionality

- [ ] **9.3 Performance tests** (Optional - can be added later)
  - [ ] Test tree query performance
  - [ ] Test search performance
  - [ ] Test cache hit rates
  - [ ] Load testing

---

### Phase 10: Documentation

- [x] **10.1 API documentation**
  - [x] Document all RPCs
  - [x] Document request/response formats
  - [x] Document error codes
  - [x] Add examples (in README.md)
  - [x] Generate OpenAPI spec

- [x] **10.2 Service documentation**
  - [x] Create README.md
  - [x] Document location hierarchy structure
  - [x] Document data model
  - [x] Document integration guide (`docs/INTEGRATION_GUIDE.md`)
  - [x] Document testing guide (`docs/TESTING.md`)
  - [x] Create implementation summary (`docs/IMPLEMENTATION_SUMMARY.md`)

- [x] **10.3 Data documentation**
  - [x] Document location data sources
  - [x] Document data update process
  - [x] Document country-specific structures

---

## 🏗️ Location Tree Structure

### Example: Vietnam
```
Country: VN (Vietnam)
├── State: HN (Hanoi)
│   ├── City: HN-001 (Hanoi City)
│   │   ├── District: HN-001-001 (Ba Dinh)
│   │   │   ├── Ward: HN-001-001-001 (Cong Vi)
│   │   │   ├── Ward: HN-001-001-002 (Dien Bien)
│   │   │   └── ...
│   │   ├── District: HN-001-002 (Hoan Kiem)
│   │   └── ...
│   └── ...
└── State: HCM (Ho Chi Minh)
    └── ...
```

### Example: United States
```
Country: US (United States)
├── State: CA (California)
│   ├── City: CA-LA (Los Angeles)
│   │   ├── District: CA-LA-001 (Downtown)
│   │   │   ├── Ward: CA-LA-001-90012 (ZIP 90012)
│   │   │   └── ...
│   │   └── ...
│   └── ...
└── State: NY (New York)
    └── ...
```

---

## 📊 Database Schema

```sql
CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    name_en VARCHAR(255),
    name_vi VARCHAR(255),
    type VARCHAR(20) NOT NULL CHECK (type IN ('country', 'state', 'city', 'district', 'ward')),
    parent_id UUID REFERENCES locations(id) ON DELETE CASCADE,
    country_code VARCHAR(2) NOT NULL,
    level INTEGER NOT NULL, -- 0=country, 1=state, 2=city, 3=district, 4=ward
    postal_codes TEXT[], -- Array of postal codes
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT chk_location_hierarchy CHECK (
        (type = 'country' AND parent_id IS NULL) OR
        (type != 'country' AND parent_id IS NOT NULL)
    ),
    CONSTRAINT chk_location_level CHECK (
        (type = 'country' AND level = 0) OR
        (type = 'state' AND level = 1) OR
        (type = 'city' AND level = 2) OR
        (type = 'district' AND level = 3) OR
        (type = 'ward' AND level = 4)
    )
);

CREATE UNIQUE INDEX idx_locations_code_parent ON locations(parent_id, code) WHERE deleted_at IS NULL;
CREATE INDEX idx_locations_parent ON locations(parent_id);
CREATE INDEX idx_locations_type ON locations(type);
CREATE INDEX idx_locations_country ON locations(country_code);
CREATE INDEX idx_locations_level ON locations(level);
CREATE INDEX idx_locations_active ON locations(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_locations_postal_codes ON locations USING GIN(postal_codes);
```

---

## 🔗 Integration Points

### Shipping Service
- Get shipping zones by location
- Calculate shipping rates by location
- Validate delivery addresses

### Customer Service
- Address autocomplete
- Address validation
- Location-based address suggestions

### Order Service
- Order address validation
- Location-based order processing

### Pricing/Tax Service
- Tax zone calculation
- Location-based pricing rules

---

## 📦 Dependencies

- **Database**: PostgreSQL (for hierarchical queries with recursive CTEs)
- **Cache**: Redis (for location tree caching)
- **External APIs**: Optional integration with Google Maps, OpenStreetMap for data enrichment

---

## 🚀 Quick Start

```bash
# 1. Create service
cd /home/user/microservices
mkdir location
cd location

# 2. Initialize Go module
go mod init gitlab.com/ta-microservices/location

# 3. Setup Kratos project
kratos new location --proto

# 4. Create database
createdb location_db

# 5. Run migrations
make migrate-up

# 6. Seed initial data
go run scripts/seed-locations.go

# 7. Start service
docker compose up -d
```

---

## 📝 Notes

- Location tree should support multiple countries with different structures
- Consider using recursive CTEs for efficient tree queries
- Cache location trees by country for performance
- Support soft deletes for location data
- Consider multi-language support (name_en, name_vi, etc.)
- Location codes should be unique within parent scope
- Consider using materialized paths for faster queries

---

## ✅ Next Steps

1. **Decide on service location**: Create new `location` service (recommended)
2. **Review checklist**: Go through each phase
3. **Start implementation**: Begin with Phase 1 (Service Setup)
4. **Data preparation**: Prepare location data for target countries
5. **Integration planning**: Plan integration with shipping, customer, order services

