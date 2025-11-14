# Location Tree Implementation Checklist

> **Purpose**: Implement hierarchical location tree for geographic addresses  
> **Last Updated**: January 2025  
> **Status**: Planning

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

- [ ] **1.1 Create service structure**
  - [ ] Create `location/` directory
  - [ ] Initialize Go module: `go mod init gitlab.com/ta-microservices/location`
  - [ ] Setup Kratos project structure
  - [ ] Create `docker-compose.yml`
  - [ ] Create `Dockerfile` and `Dockerfile.optimized`
  - [ ] Create `Makefile` with standard targets

- [ ] **1.2 Database setup**
  - [ ] Create PostgreSQL database: `location_db`
  - [ ] Design location tree schema
  - [ ] Create migration files
  - [ ] Setup database connection

- [ ] **1.3 Configuration**
  - [ ] Create `configs/config.yaml`
  - [ ] Setup Consul registration
  - [ ] Configure Redis for caching
  - [ ] Setup logging and monitoring

---

### Phase 2: Data Model & Schema

- [ ] **2.1 Location hierarchy model**
  - [ ] Design `Location` entity with parent-child relationship
  - [ ] Fields: `id`, `code`, `name`, `type`, `parent_id`, `level`, `country_code`, `postal_codes`, `coordinates`, `metadata`
  - [ ] Location types: `country`, `state`, `city`, `district`, `ward`
  - [ ] Support for multiple languages (name_en, name_vi, etc.)

- [ ] **2.2 Database schema**
  - [ ] Create `locations` table with self-referencing foreign key
  - [ ] Indexes: `parent_id`, `type`, `code`, `country_code`, `level`
  - [ ] Constraints: Unique code per parent, valid hierarchy levels
  - [ ] Support for soft deletes

- [ ] **2.3 Location relationships**
  - [ ] Parent-child relationship (self-referencing)
  - [ ] Country → States → Cities → Districts → Wards
  - [ ] Support for different country structures (US: state/city, VN: province/city/district/ward)

---

### Phase 3: Proto Definitions

- [ ] **3.1 Location proto**
  - [ ] Define `Location` message
  - [ ] Define `LocationType` enum
  - [ ] Define request/response messages
  - [ ] Add HTTP annotations

- [ ] **3.2 Service RPCs**
  - [ ] `GetLocation` - Get single location by ID/code
  - [ ] `ListLocations` - List locations with filters (type, parent, country)
  - [ ] `GetLocationTree` - Get full hierarchy tree
  - [ ] `GetLocationPath` - Get path from root to location
  - [ ] `SearchLocations` - Search by name/code
  - [ ] `ValidateLocation` - Validate location hierarchy
  - [ ] `GetChildren` - Get child locations
  - [ ] `GetAncestors` - Get parent chain
  - [ ] `HealthCheck` - Health check
  - [ ] `GetServiceInfo` - Service information

- [ ] **3.3 Generate proto code**
  - [ ] Run `make api` to generate Go code
  - [ ] Generate OpenAPI spec

---

### Phase 4: Business Logic (Biz Layer)

- [ ] **4.1 Location usecase**
  - [ ] Create `biz/location/` package
  - [ ] Implement `LocationUsecase` interface
  - [ ] Implement CRUD operations
  - [ ] Implement tree traversal methods
  - [ ] Implement search and validation

- [ ] **4.2 Location tree operations**
  - [ ] `GetTree(rootID)` - Get full tree from root
  - [ ] `GetPath(locationID)` - Get path from root to location
  - [ ] `GetChildren(parentID)` - Get direct children
  - [ ] `GetAncestors(locationID)` - Get all ancestors
  - [ ] `ValidateHierarchy(location)` - Validate parent-child relationship
  - [ ] `Search(query, filters)` - Search locations

- [ ] **4.3 Location validation**
  - [ ] Validate location code format
  - [ ] Validate hierarchy levels
  - [ ] Validate parent-child relationships
  - [ ] Validate country-specific rules

- [ ] **4.4 Caching strategy**
  - [ ] Cache location trees by country
  - [ ] Cache location lookups by code
  - [ ] Cache search results
  - [ ] Invalidate cache on updates

---

### Phase 5: Data Layer

- [ ] **5.1 Location repository**
  - [ ] Create `repository/location/` package
  - [ ] Implement `LocationRepo` interface
  - [ ] Implement PostgreSQL queries
  - [ ] Implement tree queries (recursive CTEs)
  - [ ] Implement search queries

- [ ] **5.2 Database operations**
  - [ ] `Create(location)` - Create new location
  - [ ] `Update(location)` - Update location
  - [ ] `Delete(id)` - Soft delete location
  - [ ] `FindByID(id)` - Find by ID
  - [ ] `FindByCode(code, parentID)` - Find by code
  - [ ] `FindByType(type, parentID)` - Find by type
  - [ ] `FindChildren(parentID)` - Find children
  - [ ] `FindAncestors(locationID)` - Find ancestors (recursive)
  - [ ] `Search(query, filters)` - Search locations
  - [ ] `GetTree(rootID)` - Get full tree

- [ ] **5.3 Cache layer**
  - [ ] Create `cache/location_cache.go`
  - [ ] Implement Redis caching
  - [ ] Cache location trees
  - [ ] Cache location lookups
  - [ ] Cache search results

---

### Phase 6: Service Layer

- [ ] **6.1 Location service**
  - [ ] Create `service/location.go`
  - [ ] Implement gRPC handlers
  - [ ] Implement HTTP handlers
  - [ ] Add request validation
  - [ ] Add error handling

- [ ] **6.2 Service handlers**
  - [ ] `GetLocation` handler
  - [ ] `ListLocations` handler
  - [ ] `GetLocationTree` handler
  - [ ] `GetLocationPath` handler
  - [ ] `SearchLocations` handler
  - [ ] `ValidateLocation` handler
  - [ ] `GetChildren` handler
  - [ ] `GetAncestors` handler
  - [ ] `HealthCheck` handler
  - [ ] `GetServiceInfo` handler

- [ ] **6.3 Response conversion**
  - [ ] Convert domain models to proto
  - [ ] Handle tree structure in responses
  - [ ] Format location paths

---

### Phase 7: Data Seeding

- [ ] **7.1 Location data sources**
  - [ ] Identify data sources (OpenStreetMap, GeoNames, official government data)
  - [ ] Prepare data import scripts
  - [ ] Format data for database import

- [ ] **7.2 Initial data load**
  - [ ] Create seed script for countries
  - [ ] Create seed script for states/provinces
  - [ ] Create seed script for cities
  - [ ] Create seed script for districts/wards
  - [ ] Load data for target countries (US, VN, etc.)

- [ ] **7.3 Data validation**
  - [ ] Validate hierarchy integrity
  - [ ] Validate code uniqueness
  - [ ] Validate parent-child relationships

---

### Phase 8: Integration

- [ ] **8.1 Shipping service integration**
  - [ ] Add location service client to shipping
  - [ ] Use location tree for shipping zone calculation
  - [ ] Use location data for address validation

- [ ] **8.2 Customer service integration**
  - [ ] Add location service client to customer
  - [ ] Use location tree for address autocomplete
  - [ ] Use location data for address validation

- [ ] **8.3 Order service integration**
  - [ ] Add location service client to order
  - [ ] Use location data for order addresses

- [ ] **8.4 Pricing/Tax service integration**
  - [ ] Add location service client to pricing/tax
  - [ ] Use location data for tax zone calculation

---

### Phase 9: Testing

- [ ] **9.1 Unit tests**
  - [ ] Test location usecase
  - [ ] Test repository methods
  - [ ] Test tree operations
  - [ ] Test validation logic

- [ ] **9.2 Integration tests**
  - [ ] Test API endpoints
  - [ ] Test database operations
  - [ ] Test cache operations
  - [ ] Test tree queries

- [ ] **9.3 Performance tests**
  - [ ] Test tree query performance
  - [ ] Test search performance
  - [ ] Test cache hit rates
  - [ ] Load testing

---

### Phase 10: Documentation

- [ ] **10.1 API documentation**
  - [ ] Document all RPCs
  - [ ] Document request/response formats
  - [ ] Document error codes
  - [ ] Add examples

- [ ] **10.2 Service documentation**
  - [ ] Create README.md
  - [ ] Document location hierarchy structure
  - [ ] Document data model
  - [ ] Document integration guide

- [ ] **10.3 Data documentation**
  - [ ] Document location data sources
  - [ ] Document data update process
  - [ ] Document country-specific structures

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

