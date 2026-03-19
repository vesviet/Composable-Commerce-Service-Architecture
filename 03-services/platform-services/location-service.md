# 🗺️ Location Service - Geographic Data & Delivery Zones

> **Owner**: Platform Team  
> **Last Updated**: 2026-02-15  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: 8007/9007

**Service Name**: Location Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-29  
**Production Ready**: 90%  
**Code Review**: [Location Service Code Review Checklist](../../10-appendix/checklists/v2/location_service_code_review.md)  

---

## 🎯 Overview

Location Service manages geographic data and delivery-zone logic for the e-commerce platform. It provides location validation, geocoding, distance calculations, and delivery-zone management.

### Core Capabilities
- **🌍 Geographic Data**: Vietnam location hierarchy (province → district → ward)
- **📍 Address Validation**: Real-time address validation and geocoding
- **🚚 Delivery Zones**: Warehouse coverage areas and delivery-zone management
- **📏 Distance Calculation**: Geographic distance and delivery-time estimation
- **🏷️ Location Metadata**: Postal codes, time zones, shipping restrictions
- **🔍 Location Search**: Autocomplete and location-search functionality
- **📊 Coverage Analytics**: Delivery coverage analysis and optimization

### Business Value
- **Accurate Delivery**: Precise address validation prevents delivery failures
- **Cost Optimization**: Geographic optimization of delivery routes
- **Customer Experience**: Accurate delivery time estimates
- **Operational Efficiency**: Automated location-based decision making

---

## 🏗️ Architecture

### Service Architecture
```
location/
├── cmd/location/                # Main service entry point
├── internal/
│   ├── biz/
│   │   ├── location/           # Core location logic
│   │   ├── validation/         # Address validation
│   │   ├── geocoding/          # Geocoding operations
│   │   └── zones/              # Delivery zones
│   ├── data/
│   │   ├── postgres/           # PostgreSQL repositories
│   │   └── redis/              # Redis caching
│   ├── service/                 # gRPC/HTTP API layer
│   ├── server/                  # Server setup
│   ├── middleware/              # HTTP middleware
│   ├── config/                  # Configuration
│   └── constants/               # Location constants
├── api/location/v1/             # Protocol buffers
├── migrations/                  # Database schema
└── configs/                     # Configuration files
```

### Ports & Dependencies
- **HTTP API**: `:8017` - REST endpoints
- **gRPC API**: `:9017` - Internal communication
- **Database**: PostgreSQL (`location_db`)
- **Cache**: Redis (db: 7) for location data caching
- **Common Package**: `gitlab.com/ta-microservices/common@v1.8.3`

---

## 🔄 Business Flow

### Address Validation & Geocoding Workflow

```mermaid
graph TD
    A[Address Input] --> B[Parse Address]
    B --> C[Validate Components]
    C --> D[Geocode Address]
    D --> E[Verify Coordinates]
    E --> F[Check Delivery Coverage]
    F --> G[Return Validated Address]
```

### Detailed Location Process

#### 1. Address Validation
```
Raw Address → Validation
├── Parse address into components (street, ward, district, province)
├── Validate against Vietnam location database
├── Check postal code validity
├── Verify address format and completeness
└── Return validation results with suggestions
```

#### 2. Geocoding & Coordinate Resolution
```
Validated Address → Geocoding
├── Convert address to latitude/longitude coordinates
├── Use local geocoding database for Vietnam addresses
├── Fallback to external geocoding services if needed
├── Store coordinates for future use
└── Return geocoded address with confidence score
```

#### 3. Delivery Zone Analysis
```
Geocoded Address → Zone Analysis
├── Determine nearest warehouses by distance
├── Check warehouse delivery coverage areas
├── Calculate delivery time estimates
├── Apply zone-specific rules (restrictions, surcharges)
└── Return delivery options with costs and times
```

#### 4. Location-Based Decision Making
```
Zone Analysis → Business Decisions
├── Warehouse assignment for orders
├── Shipping cost calculation
├── Delivery time estimation
├── Tax jurisdiction determination
└── Service availability checking
```

---

## 🔌 Key APIs

### Address Validation
```protobuf
// Validate address
rpc ValidateAddress(ValidateAddressRequest) returns (ValidateAddressResponse) {
  option (google.api.http) = {
    post: "/api/v1/location/validate-address"
    body: "*"
  };
}

// Geocode address
rpc GeocodeAddress(GeocodeAddressRequest) returns (GeocodeAddressResponse) {
  option (google.api.http) = {
    post: "/api/v1/location/geocode"
    body: "*"
  };
}
```

**Validate Address Request:**
```json
{
  "address": {
    "street": "123 Nguyen Trai",
    "ward": "Phuong 1",
    "district": "Quan 1",
    "province": "Ho Chi Minh City",
    "postal_code": "700000",
    "country": "VN"
  },
  "validate_coordinates": true,
  "check_delivery_coverage": true
}
```

### Location Search & Discovery
```protobuf
// Search locations
rpc SearchLocations(SearchLocationsRequest) returns (SearchLocationsResponse) {
  option (google.api.http) = {
    get: "/api/v1/location/search"
  };
}

// Get location hierarchy
rpc GetLocationHierarchy(GetLocationHierarchyRequest) returns (LocationHierarchy) {
  option (google.api.http) = {
    get: "/api/v1/location/hierarchy/{country_code}"
  };
}

// Get location details
rpc GetLocationDetails(GetLocationDetailsRequest) returns (LocationDetails) {
  option (google.api.http) = {
    get: "/api/v1/location/{location_id}"
  };
}
```

### Delivery Zone Management
```protobuf
// Get delivery zones for warehouse
rpc GetDeliveryZones(GetDeliveryZonesRequest) returns (DeliveryZonesResponse) {
  option (google.api.http) = {
    get: "/api/v1/location/zones/warehouse/{warehouse_id}"
  };
}

// Check address coverage
rpc CheckAddressCoverage(CheckAddressCoverageRequest) returns (CoverageCheckResponse) {
  option (google.api.http) = {
    post: "/api/v1/location/coverage/check"
    body: "*"
  };
}
```

### Geographic Calculations
```protobuf
// Calculate distance
rpc CalculateDistance(CalculateDistanceRequest) returns (DistanceResponse) {
  option (google.api.http) = {
    post: "/api/v1/location/distance"
    body: "*"
  };
}

// Estimate delivery time
rpc EstimateDeliveryTime(EstimateDeliveryTimeRequest) returns (DeliveryTimeResponse) {
  option (google.api.http) = {
    post: "/api/v1/location/delivery-time"
    body: "*"
  };
}
```

---

## 🌍 Geographic Data Model

### Vietnam Location Hierarchy
```
Country (VN)
├── Province/State (64 provinces)
│   ├── District/City (705 districts)
│   │   ├── Ward/Commune (11,000+ wards)
│   │   │   └── Postal Codes
```

### Location Data Structure
```json
{
  "location_id": "VN.HCM.Q1.P1",
  "type": "ward",
  "name": "Phuong 1",
  "local_name": "Ward 1",
  "parent_id": "VN.HCM.Q1",
  "coordinates": {
    "latitude": 10.7745,
    "longitude": 106.7028
  },
  "metadata": {
    "population": 18000,
    "area_km2": 0.5,
    "postal_codes": ["700000", "700001"],
    "timezone": "Asia/Ho_Chi_Minh"
  },
  "delivery_info": {
    "warehouse_coverage": ["hcm-warehouse-1", "hcm-warehouse-2"],
    "estimated_delivery_days": 1,
    "shipping_restrictions": []
  }
}
```

---

## 🔗 Integration Points

### Warehouse Service Integration
- **Provides**: Location data and delivery-zone validation
- **Consumes**: Warehouse coverage area updates
- **Data Flow**: Warehouse coverage → Location zones → Delivery validation

### Order Service Integration
- **Provides**: Address validation and delivery-zone checking
- **Consumes**: Order addresses for validation
- **Data Flow**: Order address → Validation → Delivery zone assignment

### Shipping Service Integration
- **Provides**: Geographic distance calculations and zone data
- **Consumes**: Shipping origin/destination coordinates
- **Data Flow**: Shipping calculation → Distance lookup → Cost estimation

### Fulfillment Service Integration
- **Provides**: Warehouse-to-address distance and delivery-time estimates
- **Consumes**: Fulfillment center assignments
- **Data Flow**: Fulfillment center + delivery address → Distance/time calculation

---

## 🎯 Business Logic

### Address Validation Algorithm
```go
func validateAddress(address Address) ValidationResult {
    result := ValidationResult{}

    // 1. Parse address components
    components := parseAddressComponents(address.RawAddress)

    // 2. Validate hierarchy (ward -> district -> province)
    hierarchyValid := validateLocationHierarchy(components)

    // 3. Check against official location database
    officialMatch := findOfficialLocationMatch(components)

    // 4. Calculate confidence score
    confidenceScore := calculateConfidenceScore(components, officialMatch)

    // 5. Generate suggestions if low confidence
    suggestions := generateAddressSuggestions(components, confidenceScore)

    // 6. Geocode if validation passes
    coordinates := geocodeAddress(components)

    return ValidationResult{
        IsValid: hierarchyValid && confidenceScore > 0.8,
        ConfidenceScore: confidenceScore,
        StandardizedAddress: officialMatch,
        Suggestions: suggestions,
        Coordinates: coordinates,
    }
}
```

### Delivery Zone Analysis
```go
func analyzeDeliveryCoverage(address Address, productCategory string) CoverageAnalysis {
    // 1. Find nearby warehouses within delivery radius
    nearbyWarehouses := findNearbyWarehouses(address.Coordinates, maxDeliveryRadius)

    // 2. Check specific coverage areas for each warehouse
    coverageOptions := []CoverageOption{}
    for _, warehouse := range nearbyWarehouses {
        coverage := checkWarehouseCoverage(warehouse, address, productCategory)
        if coverage.IsCovered {
            coverageOptions = append(coverageOptions, coverage)
        }
    }

    // 3. Rank options by delivery time and cost
    rankedOptions := rankCoverageOptions(coverageOptions)

    // 4. Apply business rules (preferred warehouses, capacity, etc.)
    finalOptions := applyBusinessRules(rankedOptions)

    return CoverageAnalysis{
        Address: address,
        IsCovered: len(finalOptions) > 0,
        CoverageOptions: finalOptions,
        RecommendedOption: selectBestOption(finalOptions),
    }
}
```

### Distance & Time Calculation
```go
func calculateDeliveryMetrics(origin, destination Coordinates) DeliveryMetrics {
    // 1. Calculate straight-line distance
    straightDistance := calculateHaversineDistance(origin, destination)

    // 2. Apply road network factor (actual distance is ~1.3x straight-line)
    roadDistance := straightDistance * roadNetworkFactor

    // 3. Estimate travel time based on distance and speed
    travelTime := estimateTravelTime(roadDistance, averageSpeed)

    // 4. Add processing and handling time
    totalTime := travelTime + processingTime + handlingTime

    // 5. Determine delivery day based on cutoff times
    deliveryDay := calculateDeliveryDay(totalTime, cutoffTimes)

    // 6. Calculate delivery window
    deliveryWindow := calculateDeliveryWindow(deliveryDay, timeVariance)

    return DeliveryMetrics{
        DistanceKm: roadDistance,
        TravelTimeHours: travelTime,
        TotalTimeHours: totalTime,
        DeliveryDay: deliveryDay,
        DeliveryWindow: deliveryWindow,
        ConfidenceLevel: calculateConfidenceLevel(roadDistance),
    }
}
```

### Location Search & Autocomplete
```go
func searchLocations(query string, filters LocationFilters) []LocationResult {
    // 1. Parse search query
    searchTerms := parseSearchQuery(query)

    // 2. Build search query with fuzzy matching
    searchQuery := buildLocationSearchQuery(searchTerms, filters)

    // 3. Execute search against location database
    rawResults := executeLocationSearch(searchQuery)

    // 4. Apply ranking and scoring
    scoredResults := scoreLocationResults(rawResults, searchTerms)

    // 5. Apply geographic filtering if specified
    filteredResults := applyGeographicFilters(scoredResults, filters)

    // 6. Return top results with metadata
    return formatLocationResults(filteredResults)
}
```

---

## 📊 Event-Driven Architecture

### Published Events
- `location.address.validated` - Address validation completed
- `location.zone.updated` - Delivery zone configuration changed
- `location.coverage.analyzed` - Coverage analysis performed

### Consumed Events
- `warehouse.coverage.updated` - Warehouse coverage area changes
- `order.address.submitted` - Order address for validation
- `shipping.address.updated` - Shipping address changes

---

## 🚀 Development Guide

### Quick Start
```bash
# Setup
cd location
go mod download
make migrate-up
make api
make wire

# Run
make run
```

### Vietnam Location Data Setup
```bash
# Import Vietnam administrative divisions
# Provinces (64), Districts (705), Wards (11,000+)
make import-vietnam-data

# Verify data integrity
make validate-location-data
```

### Configuration
```yaml
# configs/config.yaml
database:
  dsn: postgres://location_user:location_pass@postgres:5432/location_db

redis:
  addr: redis:6379
  db: 5

server:
  http:
    addr: 0.0.0.0:8015
  grpc:
    addr: 0.0.0.0:9015

location:
  country: VN
  default_language: vi
  geocoding_cache_ttl: 7200

delivery:
  max_delivery_radius_km: 100
  default_processing_hours: 2
  cutoff_time: "17:00"
  working_days_only: true
```

---

- **Service Status**: Production Ready (90%)
- **Critical Path**: Location tree management and address validation
- **Performance Target**: <50ms location lookup (with cache), <200ms tree queries
- **Data Coverage**: Vietnam complete (64 provinces, 705 districts, 11,000+ wards)

## Recent Updates (2026-01-29)

- ✅ Updated dependencies: `common@v1.8.3`, `kratos@v2.9.2`
- ✅ Code review completed: [Location Service Code Review Checklist](../../10-appendix/checklists/v2/location_service_code_review.md)
- ⚠️ P1 Issues Identified:
  - Health check implementation needs actual connectivity checks
  - Error mapping to gRPC status codes needs verification
- 📝 P2 Improvements:
  - Search performance optimization with PostgreSQL trigram
  - Test coverage improvements needed
