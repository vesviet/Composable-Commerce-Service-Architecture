# 🏗️ Customer Service Architecture Analysis

## 📋 Overview

This document analyzes different architectural approaches for the Customer service, comparing Magento's multi-environment EAV model vs. Hybrid EAV + Flat Table approach vs. Pure Microservice architecture.

## 🔍 Current Magento Customer Architecture

### Magento Multi-Environment Structure
```
Magento Customer Architecture:
├── Global Level (All Websites)
│   ├── customer_entity (core customer data)
│   ├── customer_group (customer tiers)
│   └── eav_attribute (custom attributes definition)
├── Website Level (Multi-tenant)
│   ├── customer_entity.website_id
│   ├── website-specific attributes
│   └── website-specific customer groups
└── Store View Level (Localization)
    ├── customer_entity_varchar (localized attributes)
    ├── customer_entity_text (localized content)
    └── store-specific customer preferences
```

### Magento EAV Complexity
```sql
-- Customer data scattered across multiple tables
SELECT 
    ce.entity_id,
    ce.email,
    ce.firstname,
    ce.lastname,
    -- Custom attributes from EAV
    phone.value as phone,
    company.value as company,
    gender.value as gender,
    dob.value as date_of_birth,
    -- Website/Store context
    ce.website_id,
    ce.store_id
FROM customer_entity ce
LEFT JOIN customer_entity_varchar phone ON ce.entity_id = phone.entity_id 
    AND phone.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'phone')
LEFT JOIN customer_entity_varchar company ON ce.entity_id = company.entity_id 
    AND company.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'company')
LEFT JOIN customer_entity_int gender ON ce.entity_id = gender.entity_id 
    AND gender.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'gender')
LEFT JOIN customer_entity_datetime dob ON ce.entity_id = dob.entity_id 
    AND dob.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'dob')
WHERE ce.website_id = ? AND ce.store_id = ?;
```

## 🏛️ Architecture Options Analysis

### Option 1: Follow Magento Multi-Environment Pattern

#### Structure:
```
Customer Service with Multi-Environment:
├── Global Customer Registry
│   ├── customers (core identity)
│   ├── customer_attributes (EAV definitions)
│   └── customer_groups (global tiers)
├── Website-Level Data
│   ├── customer_website_profiles
│   ├── website_specific_attributes
│   └── website_customer_groups
└── Store-Level Data
    ├── customer_store_preferences
    ├── localized_attributes
    └── store_specific_settings
```

#### Database Schema:
```sql
-- Global customer identity
CREATE TABLE customers (
    id UUID PRIMARY KEY,
    legacy_id INTEGER UNIQUE,
    global_email VARCHAR(255) UNIQUE,
    status VARCHAR(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Website-specific customer profiles
CREATE TABLE customer_website_profiles (
    id UUID PRIMARY KEY,
    customer_id UUID REFERENCES customers(id),
    website_id INTEGER NOT NULL,
    email VARCHAR(255), -- Can be different per website
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    preferences JSONB,
    status VARCHAR(20),
    created_at TIMESTAMP,
    
    UNIQUE(customer_id, website_id)
);

-- Store-specific customer data
CREATE TABLE customer_store_data (
    id UUID PRIMARY KEY,
    customer_id UUID REFERENCES customers(id),
    website_id INTEGER NOT NULL,
    store_id INTEGER NOT NULL,
    locale VARCHAR(10),
    localized_attributes JSONB,
    communication_preferences JSONB,
    
    UNIQUE(customer_id, website_id, store_id)
);

-- EAV for custom attributes
CREATE TABLE customer_attributes (
    id UUID PRIMARY KEY,
    attribute_code VARCHAR(50) UNIQUE,
    attribute_type VARCHAR(20), -- varchar, int, datetime, text
    is_required BOOLEAN DEFAULT FALSE,
    is_system BOOLEAN DEFAULT FALSE,
    scope VARCHAR(20) DEFAULT 'global' -- global, website, store
);

CREATE TABLE customer_attribute_values (
    id UUID PRIMARY KEY,
    customer_id UUID REFERENCES customers(id),
    attribute_id UUID REFERENCES customer_attributes(id),
    website_id INTEGER,
    store_id INTEGER,
    value_varchar VARCHAR(255),
    value_int INTEGER,
    value_datetime TIMESTAMP,
    value_text TEXT,
    
    UNIQUE(customer_id, attribute_id, website_id, store_id)
);
```

#### Pros:
- ✅ **Perfect Magento Compatibility**: 1:1 mapping với Magento structure
- ✅ **Multi-tenant Support**: Native support cho multiple websites/stores
- ✅ **Flexible Attributes**: EAV cho unlimited custom attributes
- ✅ **Localization**: Store-level localized data
- ✅ **Easy Migration**: Minimal transformation từ Magento

#### Cons:
- ❌ **High Complexity**: Multiple tables, complex queries
- ❌ **Performance Issues**: EAV queries are slow
- ❌ **Maintenance Overhead**: Complex schema management
- ❌ **Microservice Anti-pattern**: Too much coupling với Magento concepts
- ❌ **Scalability Issues**: EAV doesn't scale well

### Option 2: Hybrid EAV + Flat Table (Like Catalog Service)

#### Structure:
```
Customer Service Hybrid Architecture:
├── Flat Tables (Performance)
│   ├── customers (core fields)
│   ├── customer_addresses (structured)
│   └── customer_segments (business logic)
├── EAV Extension (Flexibility)
│   ├── customer_attributes (definitions)
│   ├── customer_attribute_values (custom data)
│   └── attribute_scopes (website/store context)
└── Computed Views (Best of Both)
    ├── customer_flat_view (materialized)
    ├── customer_website_view (scoped)
    └── customer_search_index (optimized)
```

#### Database Schema:
```sql
-- Flat table for core customer data (performance)
CREATE TABLE customers (
    id UUID PRIMARY KEY,
    legacy_id INTEGER UNIQUE,
    email VARCHAR(255) UNIQUE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    date_of_birth DATE,
    gender VARCHAR(20),
    customer_type VARCHAR(20),
    status VARCHAR(20),
    email_verified BOOLEAN,
    phone_verified BOOLEAN,
    -- Core preferences as JSON (structured but flexible)
    preferences JSONB DEFAULT '{}',
    -- Metadata including website/store context
    metadata JSONB DEFAULT '{}',
    registration_source VARCHAR(50),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- EAV for truly custom attributes (flexibility)
CREATE TABLE customer_attributes (
    id UUID PRIMARY KEY,
    attribute_code VARCHAR(50) UNIQUE,
    attribute_label VARCHAR(100),
    attribute_type VARCHAR(20), -- varchar, int, datetime, text, json
    validation_rules JSONB,
    is_required BOOLEAN DEFAULT FALSE,
    is_searchable BOOLEAN DEFAULT FALSE,
    scope VARCHAR(20) DEFAULT 'global', -- global, website, store
    created_at TIMESTAMP
);

CREATE TABLE customer_attribute_values (
    id UUID PRIMARY KEY,
    customer_id UUID REFERENCES customers(id),
    attribute_id UUID REFERENCES customer_attributes(id),
    scope_context JSONB, -- {website_id: 1, store_id: 2}
    value JSONB, -- Unified value storage
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    
    UNIQUE(customer_id, attribute_id, scope_context)
);

-- Materialized view for performance (computed)
CREATE MATERIALIZED VIEW customer_flat_view AS
SELECT 
    c.*,
    -- Aggregate custom attributes as JSON
    COALESCE(
        json_object_agg(
            ca.attribute_code, 
            cav.value
        ) FILTER (WHERE ca.id IS NOT NULL),
        '{}'::json
    ) as custom_attributes
FROM customers c
LEFT JOIN customer_attribute_values cav ON c.id = cav.customer_id
LEFT JOIN customer_attributes ca ON cav.attribute_id = ca.id
GROUP BY c.id;

-- Indexes for performance
CREATE INDEX idx_customer_flat_view_email ON customer_flat_view(email);
CREATE INDEX idx_customer_flat_view_phone ON customer_flat_view(phone);
CREATE INDEX idx_customer_flat_view_status ON customer_flat_view(status);
CREATE INDEX idx_customer_flat_view_custom_attrs ON customer_flat_view USING GIN(custom_attributes);
```

#### Pros:
- ✅ **Performance**: Flat tables cho common queries
- ✅ **Flexibility**: EAV cho custom attributes
- ✅ **Best of Both**: Structured + flexible data
- ✅ **Scalable**: Materialized views cho performance
- ✅ **Migration Friendly**: Can handle Magento complexity
- ✅ **Query Optimization**: Different strategies cho different use cases

#### Cons:
- ⚠️ **Moderate Complexity**: More complex than pure flat
- ⚠️ **Maintenance**: Materialized views need refresh
- ⚠️ **Storage Overhead**: Data duplication in views

### Option 3A: Pure Microservice Architecture - Single Tenant (Recommended)

#### Structure:
```
Customer Service Pure Microservice (Single Tenant):
├── Core Customer Domain
│   ├── customers (essential fields only)
│   ├── customer_profiles (extended data)
│   └── customer_preferences (settings)
├── Address Domain
│   ├── customer_addresses (structured)
│   └── address_validation (business rules)
└── Segmentation Domain
    ├── customer_segments (business logic)
    └── segment_memberships (relationships)
```

#### Database Schema (Single Tenant):
```sql
-- Core customer entity (essential fields only)
CREATE TABLE customers (
    id UUID PRIMARY KEY,
    legacy_id INTEGER UNIQUE, -- For Magento migration
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    customer_type VARCHAR(20) DEFAULT 'individual' CHECK (customer_type IN ('individual', 'business')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'pending')),
    email_verified BOOLEAN DEFAULT FALSE,
    registration_source VARCHAR(50),
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Extended customer profile (flexible but structured)
CREATE TABLE customer_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID UNIQUE REFERENCES customers(id) ON DELETE CASCADE,
    phone VARCHAR(20),
    date_of_birth DATE,
    gender VARCHAR(20) CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
    phone_verified BOOLEAN DEFAULT FALSE,
    -- Profile data as structured JSON
    profile_data JSONB DEFAULT '{}',
    -- Business metadata (Magento legacy data, etc.)
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customer preferences (communication and privacy)
CREATE TABLE customer_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID UNIQUE REFERENCES customers(id) ON DELETE CASCADE,
    -- Communication preferences
    email_marketing BOOLEAN DEFAULT TRUE,
    sms_marketing BOOLEAN DEFAULT FALSE,
    push_notifications BOOLEAN DEFAULT TRUE,
    newsletter BOOLEAN DEFAULT TRUE,
    -- Privacy preferences
    data_sharing BOOLEAN DEFAULT FALSE,
    analytics_tracking BOOLEAN DEFAULT TRUE,
    cookie_consent BOOLEAN DEFAULT FALSE,
    -- Notification preferences
    order_updates BOOLEAN DEFAULT TRUE,
    promotional_emails BOOLEAN DEFAULT TRUE,
    -- Custom preferences as JSON
    custom_preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customer addresses (separate domain)
CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id INTEGER UNIQUE, -- For Magento migration
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    type VARCHAR(20) DEFAULT 'shipping' CHECK (type IN ('shipping', 'billing', 'both')),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    company VARCHAR(255),
    address_line_1 VARCHAR(255) NOT NULL,
    address_line_2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state_province VARCHAR(100),
    postal_code VARCHAR(20),
    country_code VARCHAR(2) NOT NULL,
    phone VARCHAR(20),
    is_default BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customer segments (business logic)
CREATE TABLE customer_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rules JSONB NOT NULL, -- Segment rules as JSON
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customer segment memberships (many-to-many)
CREATE TABLE customer_segment_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    segment_id UUID NOT NULL REFERENCES customer_segments(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by VARCHAR(50) DEFAULT 'system',
    
    UNIQUE(customer_id, segment_id)
);

-- Indexes for performance
CREATE INDEX idx_customers_email ON customers(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_legacy_id ON customers(legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX idx_customers_status ON customers(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_type ON customers(customer_type);
CREATE INDEX idx_customers_created_at ON customers(created_at);

CREATE INDEX idx_profiles_customer_id ON customer_profiles(customer_id);
CREATE INDEX idx_profiles_phone ON customer_profiles(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_profiles_data ON customer_profiles USING GIN(profile_data);

CREATE INDEX idx_preferences_customer_id ON customer_preferences(customer_id);
CREATE INDEX idx_preferences_marketing ON customer_preferences(email_marketing, sms_marketing);

CREATE INDEX idx_addresses_customer_id ON customer_addresses(customer_id);
CREATE INDEX idx_addresses_legacy_id ON customer_addresses(legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX idx_addresses_type ON customer_addresses(type);
CREATE INDEX idx_addresses_default ON customer_addresses(is_default) WHERE is_default = TRUE;
CREATE INDEX idx_addresses_country ON customer_addresses(country_code);

CREATE INDEX idx_segments_active ON customer_segments(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_segment_memberships_customer ON customer_segment_memberships(customer_id);
CREATE INDEX idx_segment_memberships_segment ON customer_segment_memberships(segment_id);
```

#### Simple Service Layer (Single Tenant):
```go
// Simple customer domain models
type Customer struct {
    ID                 string                 `json:"id"`
    LegacyID           *int                   `json:"legacy_id,omitempty"`
    Email              string                 `json:"email"`
    FirstName          string                 `json:"first_name"`
    LastName           string                 `json:"last_name"`
    CustomerType       string                 `json:"customer_type"`
    Status             string                 `json:"status"`
    EmailVerified      bool                   `json:"email_verified"`
    RegistrationSource string                 `json:"registration_source"`
    LastLoginAt        *time.Time             `json:"last_login_at,omitempty"`
    CreatedAt          time.Time              `json:"created_at"`
    UpdatedAt          time.Time              `json:"updated_at"`
    
    // Related data (loaded separately)
    Profile     *CustomerProfile     `json:"profile,omitempty"`
    Preferences *CustomerPreferences `json:"preferences,omitempty"`
    Addresses   []CustomerAddress    `json:"addresses,omitempty"`
    Segments    []string             `json:"segments,omitempty"`
}

type CustomerProfile struct {
    CustomerID   string                 `json:"customer_id"`
    Phone        *string                `json:"phone,omitempty"`
    DateOfBirth  *time.Time             `json:"date_of_birth,omitempty"`
    Gender       string                 `json:"gender"`
    PhoneVerified bool                  `json:"phone_verified"`
    ProfileData  map[string]interface{} `json:"profile_data"`
    Metadata     map[string]interface{} `json:"metadata"`
}

type CustomerPreferences struct {
    CustomerID         string                 `json:"customer_id"`
    EmailMarketing     bool                   `json:"email_marketing"`
    SmsMarketing       bool                   `json:"sms_marketing"`
    PushNotifications  bool                   `json:"push_notifications"`
    Newsletter         bool                   `json:"newsletter"`
    DataSharing        bool                   `json:"data_sharing"`
    AnalyticsTracking  bool                   `json:"analytics_tracking"`
    CustomPreferences  map[string]interface{} `json:"custom_preferences"`
}

// Simple service layer (no tenant complexity)
type CustomerService struct {
    customerRepo    CustomerRepository
    profileRepo     CustomerProfileRepository
    preferencesRepo CustomerPreferencesRepository
    addressRepo     CustomerAddressRepository
    segmentRepo     CustomerSegmentRepository
    logger          log.Logger
}

func NewCustomerService(
    customerRepo CustomerRepository,
    profileRepo CustomerProfileRepository,
    preferencesRepo CustomerPreferencesRepository,
    addressRepo CustomerAddressRepository,
    segmentRepo CustomerSegmentRepository,
    logger log.Logger,
) *CustomerService {
    return &CustomerService{
        customerRepo:    customerRepo,
        profileRepo:     profileRepo,
        preferencesRepo: preferencesRepo,
        addressRepo:     addressRepo,
        segmentRepo:     segmentRepo,
        logger:          logger,
    }
}

func (s *CustomerService) GetCustomer(ctx context.Context, customerID string) (*Customer, error) {
    // Get base customer data
    customer, err := s.customerRepo.GetByID(ctx, customerID)
    if err != nil {
        return nil, fmt.Errorf("failed to get customer: %w", err)
    }
    
    return customer, nil
}

func (s *CustomerService) GetCustomerWithDetails(ctx context.Context, customerID string) (*Customer, error) {
    // Get base customer
    customer, err := s.customerRepo.GetByID(ctx, customerID)
    if err != nil {
        return nil, fmt.Errorf("failed to get customer: %w", err)
    }
    
    // Load related data in parallel
    var profile *CustomerProfile
    var preferences *CustomerPreferences
    var addresses []CustomerAddress
    var segments []string
    
    g, ctx := errgroup.WithContext(ctx)
    
    // Load profile
    g.Go(func() error {
        var err error
        profile, err = s.profileRepo.GetByCustomerID(ctx, customerID)
        if err != nil && !errors.Is(err, ErrNotFound) {
            return err
        }
        return nil
    })
    
    // Load preferences
    g.Go(func() error {
        var err error
        preferences, err = s.preferencesRepo.GetByCustomerID(ctx, customerID)
        if err != nil && !errors.Is(err, ErrNotFound) {
            return err
        }
        return nil
    })
    
    // Load addresses
    g.Go(func() error {
        var err error
        addresses, err = s.addressRepo.GetByCustomerID(ctx, customerID)
        if err != nil && !errors.Is(err, ErrNotFound) {
            return err
        }
        return nil
    })
    
    // Load segments
    g.Go(func() error {
        var err error
        segments, err = s.segmentRepo.GetCustomerSegments(ctx, customerID)
        if err != nil && !errors.Is(err, ErrNotFound) {
            return err
        }
        return nil
    })
    
    if err := g.Wait(); err != nil {
        return nil, fmt.Errorf("failed to load customer details: %w", err)
    }
    
    // Attach related data
    customer.Profile = profile
    customer.Preferences = preferences
    customer.Addresses = addresses
    customer.Segments = segments
    
    return customer, nil
}

func (s *CustomerService) CreateCustomer(ctx context.Context, req *CreateCustomerRequest) (*Customer, error) {
    // Validate request
    if err := s.validateCreateRequest(req); err != nil {
        return nil, fmt.Errorf("invalid request: %w", err)
    }
    
    // Check if customer already exists
    if existing, err := s.customerRepo.GetByEmail(ctx, req.Email); err == nil && existing != nil {
        return nil, ErrCustomerAlreadyExists
    }
    
    // Create customer
    customer := &Customer{
        ID:                 uuid.New().String(),
        Email:              req.Email,
        FirstName:          req.FirstName,
        LastName:           req.LastName,
        CustomerType:       req.CustomerType,
        Status:             "pending", // Requires email verification
        EmailVerified:      false,
        RegistrationSource: req.RegistrationSource,
        CreatedAt:          time.Now(),
        UpdatedAt:          time.Now(),
    }
    
    if err := s.customerRepo.Create(ctx, customer); err != nil {
        return nil, fmt.Errorf("failed to create customer: %w", err)
    }
    
    // Create default profile and preferences
    if err := s.createDefaultProfile(ctx, customer.ID, req); err != nil {
        s.logger.Errorf("Failed to create default profile for customer %s: %v", customer.ID, err)
    }
    
    if err := s.createDefaultPreferences(ctx, customer.ID); err != nil {
        s.logger.Errorf("Failed to create default preferences for customer %s: %v", customer.ID, err)
    }
    
    // Publish customer created event
    s.publishCustomerCreatedEvent(ctx, customer)
    
    return customer, nil
}

func (s *CustomerService) UpdateCustomer(ctx context.Context, customerID string, updates *UpdateCustomerRequest) (*Customer, error) {
    customer, err := s.customerRepo.GetByID(ctx, customerID)
    if err != nil {
        return nil, fmt.Errorf("customer not found: %w", err)
    }
    
    // Apply updates
    if updates.FirstName != nil {
        customer.FirstName = *updates.FirstName
    }
    if updates.LastName != nil {
        customer.LastName = *updates.LastName
    }
    if updates.Status != nil {
        customer.Status = *updates.Status
    }
    
    customer.UpdatedAt = time.Now()
    
    if err := s.customerRepo.Update(ctx, customer); err != nil {
        return nil, fmt.Errorf("failed to update customer: %w", err)
    }
    
    // Publish customer updated event
    s.publishCustomerUpdatedEvent(ctx, customer, updates)
    
    return customer, nil
}
```

#### Pros:
- ✅ **True Microservice**: Domain-driven, loosely coupled
- ✅ **High Performance**: Optimized queries, no EAV overhead
- ✅ **Scalable**: Horizontal scaling, independent deployment
- ✅ **Maintainable**: Simple schema, clear boundaries
- ✅ **Flexible**: JSON fields cho extensibility
- ✅ **Modern Architecture**: Cloud-native, container-friendly
- ✅ **Simple Implementation**: No multi-tenant complexity
- ✅ **Fast Development**: Straightforward business logic

#### Cons:
- ⚠️ **Migration Complexity**: Need to flatten Magento EAV data
- ⚠️ **Custom Attributes**: Limited to JSON fields (no strong typing)
- ⚠️ **Single Tenant**: No built-in multi-store support

### Option 3B: Pure Microservice Architecture - Multi-Tenant

#### When Multi-tenancy is Required:
If you need multi-store/multi-website support, you can extend Option 3A with application-level tenancy:

#### Enhanced Schema for Multi-tenancy:
```sql
-- Add tenant context to existing tables
ALTER TABLE customers ADD COLUMN tenant_id VARCHAR(50);
ALTER TABLE customer_profiles ADD COLUMN tenant_id VARCHAR(50);
ALTER TABLE customer_preferences ADD COLUMN tenant_id VARCHAR(50);
ALTER TABLE customer_addresses ADD COLUMN tenant_id VARCHAR(50);

-- Tenant-specific overrides (optional)
CREATE TABLE customer_tenant_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    tenant_id VARCHAR(50) NOT NULL,
    override_data JSONB DEFAULT '{}', -- Tenant-specific data overrides
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(customer_id, tenant_id)
);

-- Update indexes for tenant-aware queries
CREATE INDEX idx_customers_tenant ON customers(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_profiles_tenant ON customer_profiles(tenant_id) WHERE tenant_id IS NOT NULL;
CREATE INDEX idx_addresses_tenant ON customer_addresses(tenant_id) WHERE tenant_id IS NOT NULL;
```

#### Multi-tenant Service Layer:
```go
// Tenant context for multi-store support
type TenantContext struct {
    TenantID string `json:"tenant_id"`
    StoreID  string `json:"store_id,omitempty"`
    Locale   string `json:"locale,omitempty"`
    Currency string `json:"currency,omitempty"`
}

// Enhanced service with tenant awareness
type CustomerService struct {
    customerRepo    CustomerRepository
    profileRepo     CustomerProfileRepository
    preferencesRepo CustomerPreferencesRepository
    addressRepo     CustomerAddressRepository
    segmentRepo     CustomerSegmentRepository
    tenantConfig    TenantConfigService
    logger          log.Logger
}

func (s *CustomerService) GetCustomerWithTenant(ctx context.Context, customerID string, tenantCtx TenantContext) (*Customer, error) {
    // Get customer with tenant filter
    customer, err := s.customerRepo.GetByIDAndTenant(ctx, customerID, tenantCtx.TenantID)
    if err != nil {
        return nil, fmt.Errorf("failed to get customer: %w", err)
    }
    
    // Apply tenant-specific overrides if they exist
    if overrides, err := s.customerRepo.GetTenantOverrides(ctx, customerID, tenantCtx.TenantID); err == nil {
        customer = s.applyTenantOverrides(customer, overrides, tenantCtx)
    }
    
    return customer, nil
}

func (s *CustomerService) CreateCustomerWithTenant(ctx context.Context, req *CreateCustomerRequest, tenantCtx TenantContext) (*Customer, error) {
    // Check if customer exists in this tenant
    if existing, err := s.customerRepo.GetByEmailAndTenant(ctx, req.Email, tenantCtx.TenantID); err == nil && existing != nil {
        return nil, ErrCustomerAlreadyExistsInTenant
    }
    
    // Create customer with tenant context
    customer := &Customer{
        ID:                 uuid.New().String(),
        Email:              req.Email,
        FirstName:          req.FirstName,
        LastName:           req.LastName,
        CustomerType:       req.CustomerType,
        Status:             "pending",
        EmailVerified:      false,
        RegistrationSource: req.RegistrationSource,
        TenantID:           tenantCtx.TenantID, // Set tenant context
        CreatedAt:          time.Now(),
        UpdatedAt:          time.Now(),
    }
    
    if err := s.customerRepo.Create(ctx, customer); err != nil {
        return nil, fmt.Errorf("failed to create customer: %w", err)
    }
    
    return customer, nil
}
```

## 🎯 Architecture Recommendation

### **Recommended: Option 3A - Pure Microservice Architecture (Single Tenant)**

#### Rationale:

1. **Simplicity First**: 
   - Start simple, add complexity when needed
   - Flat tables với optimized indexes
   - No EAV query complexity
   - Fast JSON operations cho flexible data

2. **Microservice Principles**:
   - Single responsibility (customer domain)
   - Loose coupling
   - Independent scalability
   - Clear domain boundaries

3. **Rapid Development**:
   - Straightforward business logic
   - No tenant complexity overhead
   - Fast time to market
   - Easy to test and debug

4. **Future-Proof**:
   - Can evolve to multi-tenant when needed
   - Cloud-native architecture
   - Container-friendly
   - Easy to scale and maintain

5. **Migration Strategy**:
   - Focus on core functionality first
   - Flatten Magento EAV data to JSON
   - Preserve legacy IDs for compatibility
   - Add multi-tenancy later if required

#### Implementation Strategy:

### Phase 1: Core Customer Service
```sql
-- Minimal viable schema
CREATE TABLE customers (
    id UUID PRIMARY KEY,
    legacy_id INTEGER UNIQUE,
    email VARCHAR(255) UNIQUE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    status VARCHAR(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE customer_profiles (
    customer_id UUID PRIMARY KEY REFERENCES customers(id),
    phone VARCHAR(20),
    date_of_birth DATE,
    profile_data JSONB DEFAULT '{}',
    updated_at TIMESTAMP
);
```

### Phase 2: Multi-tenant Support
```go
// Tenant-aware service layer
type CustomerService struct {
    repo CustomerRepository
}

func (s *CustomerService) GetCustomerWithTenantContext(
    ctx context.Context, 
    customerID string, 
    tenantCtx TenantContext,
) (*Customer, error) {
    customer, err := s.repo.GetCustomer(ctx, customerID)
    if err != nil {
        return nil, err
    }
    
    // Apply tenant-specific business rules
    return s.applyTenantRules(customer, tenantCtx), nil
}
```

### Phase 3: Advanced Features
- Customer segmentation service
- Preference management
- Advanced analytics
- Real-time personalization

## 📊 Comparison Matrix

| Aspect | Magento Pattern | Hybrid EAV+Flat | Pure Microservice (Single) | Pure Microservice (Multi-tenant) |
|--------|----------------|------------------|---------------------------|----------------------------------|
| **Performance** | ❌ Poor (EAV) | ⚠️ Good (Mixed) | ✅ Excellent (Flat) | ✅ Excellent (Flat) |
| **Scalability** | ❌ Limited | ⚠️ Moderate | ✅ High | ✅ High |
| **Complexity** | ❌ Very High | ⚠️ Moderate | ✅ Very Low | ⚠️ Moderate |
| **Flexibility** | ✅ Very High | ✅ High | ⚠️ Moderate | ⚠️ Moderate |
| **Migration Effort** | ✅ Low | ⚠️ Moderate | ⚠️ Moderate | ❌ High |
| **Maintenance** | ❌ High | ⚠️ Moderate | ✅ Very Low | ⚠️ Moderate |
| **Multi-tenancy** | ✅ Native | ✅ Native | ❌ Not Supported | ✅ Application-level |
| **Query Performance** | ❌ Poor | ⚠️ Mixed | ✅ Excellent | ✅ Excellent |
| **Storage Efficiency** | ❌ Poor | ⚠️ Moderate | ✅ Excellent | ✅ Good |
| **Development Speed** | ❌ Slow | ⚠️ Moderate | ✅ Very Fast | ⚠️ Moderate |
| **Time to Market** | ⚠️ Fast | ⚠️ Moderate | ✅ Very Fast | ⚠️ Moderate |

## 🚀 Implementation Roadmap

### Week 1-2: Core Architecture
- [ ] Implement core customer tables
- [ ] Basic CRUD operations
- [ ] Legacy ID mapping
- [ ] Migration scripts

### Week 3-4: Multi-tenant Support
- [ ] Tenant context middleware
- [ ] Tenant-aware business logic
- [ ] Configuration management
- [ ] Testing framework

### Week 5-6: Advanced Features
- [ ] Customer segmentation
- [ ] Preference management
- [ ] Analytics integration
- [ ] Performance optimization

### Week 7-8: Migration & Go-Live
- [ ] Data migration execution
- [ ] Integration testing
- [ ] Performance testing
- [ ] Production deployment

## 🎯 Decision Factors

### Choose **Pure Microservice (Single Tenant)** if:
- ✅ Performance is critical
- ✅ You want modern, scalable architecture
- ✅ Single store/website operation
- ✅ Fast time to market is priority
- ✅ Team has microservice experience
- ✅ Long-term maintainability is priority

### Choose **Pure Microservice (Multi-tenant)** if:
- ✅ Multiple stores/websites required
- ✅ Performance is still critical
- ✅ You want modern, scalable architecture
- ✅ Can handle moderate complexity
- ✅ Team has multi-tenant experience

### Choose **Hybrid EAV+Flat** if:
- ✅ Need extensive custom attributes
- ✅ Complex business requirements
- ✅ Migration timeline is tight
- ✅ Need to preserve Magento flexibility
- ✅ Multi-tenancy is required from day 1

### Choose **Magento Pattern** if:
- ✅ Minimal migration effort required
- ✅ Existing integrations depend on EAV
- ✅ Short-term solution needed
- ✅ Team lacks microservice experience
- ✅ Complex multi-tenant requirements

## 📝 Conclusion

**Recommendation: Pure Microservice Architecture - Single Tenant (Option 3A)**

This approach provides the best balance of simplicity, performance, and maintainability for a modern e-commerce platform. Key benefits:

### **Why Start Single Tenant:**
1. **Faster Development**: No multi-tenant complexity overhead
2. **Easier Testing**: Simpler business logic and data flows
3. **Better Performance**: No tenant filtering in queries
4. **Lower Risk**: Fewer moving parts, easier to debug
5. **Evolutionary Architecture**: Can add multi-tenancy later when needed

### **Migration Path:**
```
Phase 1: Single Tenant Core (Weeks 1-4)
├── Core customer CRUD operations
├── Profile and preferences management
├── Address management
├── Basic segmentation
└── Magento data migration

Phase 2: Enhanced Features (Weeks 5-6)
├── Advanced segmentation
├── Customer analytics
├── Preference management
└── Performance optimization

Phase 3: Multi-tenant (If Needed - Weeks 7-8)
├── Add tenant_id fields
├── Tenant-aware service layer
├── Tenant configuration management
└── Multi-store testing
```

### **When to Add Multi-tenancy:**
- Multiple stores/websites are confirmed requirement
- Single tenant version is stable and performant
- Team has bandwidth for additional complexity
- Business requirements justify the overhead

This evolutionary approach allows you to deliver value quickly while maintaining the flexibility to add complexity when it's actually needed, following the YAGNI (You Aren't Gonna Need It) principle.

---

**📅 Last Updated**: November 2024  
**📝 Version**: 1.0  
**👥 Prepared By**: Architecture Team