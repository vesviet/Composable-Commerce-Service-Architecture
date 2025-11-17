on Analysis

## 📋 Overview

This document provides a comprehensive analysis of migrating customer data from Magento 2 to the new Customer microservice, including data mapping, transformation requirements, and migration strategies.

## 🏗️ Magento 2 Customer Data Structure

### Core Customer Tables in Magento 2

#### 1. **customer_entity** (Main Customer Table)
```sql
-- Magento 2 customer_entity structure
CREATE TABLE customer_entity (
    entity_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    website_id SMALLINT UNSIGNED,
    email VARCHAR(255),
    group_id SMALLINT UNSIGNED,
    increment_id VARCHAR(50),
    store_id SMALLINT UNSIGNED,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    is_active SMALLINT,
    disable_auto_group_change SMALLINT,
    created_in VARCHAR(255),
    prefix VARCHAR(40),
    firstname VARCHAR(255),
    middlename VARCHAR(255),
    lastname VARCHAR(255),
    suffix VARCHAR(40),
    dob DATE,
    password_hash VARCHAR(128),
    rp_token VARCHAR(256),
    rp_token_created_at TIMESTAMP,
    default_billing INT UNSIGNED,
    default_shipping INT UNSIGNED,
    taxvat VARCHAR(50),
    confirmation VARCHAR(64),
    gender SMALLINT,
    failures_num SMALLINT DEFAULT 0,
    first_failure TIMESTAMP,
    lock_expires TIMESTAMP
);
```

#### 2. **customer_address_entity** (Customer Addresses)
```sql
-- Magento 2 customer_address_entity structure
CREATE TABLE customer_address_entity (
    entity_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    increment_id VARCHAR(50),
    parent_id INT UNSIGNED, -- References customer_entity.entity_id
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    is_active SMALLINT DEFAULT 1,
    city VARCHAR(255),
    company VARCHAR(255),
    country_id VARCHAR(4),
    fax VARCHAR(255),
    firstname VARCHAR(255),
    lastname VARCHAR(255),
    middlename VARCHAR(255),
    postcode VARCHAR(255),
    prefix VARCHAR(40),
    region VARCHAR(255),
    region_id INT UNSIGNED,
    street TEXT,
    suffix VARCHAR(40),
    telephone VARCHAR(255),
    vat_id VARCHAR(255),
    vat_is_valid SMALLINT,
    vat_request_date VARCHAR(255),
    vat_request_id VARCHAR(255),
    vat_request_success SMALLINT
);
```

#### 3. **customer_group** (Customer Groups/Tiers)
```sql
-- Magento 2 customer_group structure
CREATE TABLE customer_group (
    customer_group_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_group_code VARCHAR(32),
    tax_class_id INT UNSIGNED
);
```

#### 4. **customer_entity_varchar/int/datetime** (EAV Attributes)
```sql
-- Magento 2 EAV attribute tables
CREATE TABLE customer_entity_varchar (
    value_id INT AUTO_INCREMENT PRIMARY KEY,
    attribute_id SMALLINT UNSIGNED,
    entity_id INT UNSIGNED,
    value VARCHAR(255)
);

CREATE TABLE customer_entity_int (
    value_id INT AUTO_INCREMENT PRIMARY KEY,
    attribute_id SMALLINT UNSIGNED,
    entity_id INT UNSIGNED,
    value INT
);

CREATE TABLE customer_entity_datetime (
    value_id INT AUTO_INCREMENT PRIMARY KEY,
    attribute_id SMALLINT UNSIGNED,
    entity_id INT UNSIGNED,
    value DATETIME
);
```

## 🔄 Data Mapping Strategy

### 1. **Legacy ID Mapping Requirements**

To maintain data integrity and enable future synchronization, we need to preserve the relationship between Magento entity IDs and new UUIDs:

#### **Enhanced Customer Table Schema**
```sql
-- Updated customers table with legacy_id field
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id INTEGER UNIQUE, -- Magento entity_id for mapping
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    date_of_birth DATE,
    gender VARCHAR(20) CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
    customer_type VARCHAR(20) DEFAULT 'individual' CHECK (customer_type IN ('individual', 'business')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'pending')),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    preferences JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    registration_source VARCHAR(50),
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for legacy mapping
CREATE INDEX idx_customers_legacy_id ON customers(legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX idx_customers_email ON customers(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_phone ON customers(phone) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_status ON customers(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_type ON customers(customer_type);
CREATE INDEX idx_customers_created_at ON customers(created_at);
```

#### **Enhanced Address Table Schema**
```sql
-- Updated customer_addresses table with legacy_id field
CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id INTEGER UNIQUE, -- Magento address entity_id for mapping
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    customer_legacy_id INTEGER, -- For faster lookups during migration
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

-- Indexes for legacy mapping
CREATE INDEX idx_addresses_legacy_id ON customer_addresses(legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX idx_addresses_customer_legacy_id ON customer_addresses(customer_legacy_id) WHERE customer_legacy_id IS NOT NULL;
CREATE INDEX idx_addresses_customer_id ON customer_addresses(customer_id);
CREATE INDEX idx_addresses_type ON customer_addresses(type);
CREATE INDEX idx_addresses_default ON customer_addresses(is_default) WHERE is_default = TRUE;
CREATE INDEX idx_addresses_country ON customer_addresses(country_code);
```

#### **Migration Mapping Table (Optional)**
```sql
-- Optional: Separate mapping table for complex scenarios
CREATE TABLE migration_id_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL, -- 'customer', 'address', etc.
    legacy_id INTEGER NOT NULL,
    new_id UUID NOT NULL,
    magento_website_id INTEGER,
    magento_store_id INTEGER,
    migration_batch VARCHAR(50),
    migrated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(entity_type, legacy_id)
);

CREATE INDEX idx_mapping_legacy_id ON migration_id_mapping(entity_type, legacy_id);
CREATE INDEX idx_mapping_new_id ON migration_id_mapping(new_id);
CREATE INDEX idx_mapping_batch ON migration_id_mapping(migration_batch);
```

### 2. **Customer Entity Mapping**

| Magento 2 Field | New Customer Service Field | Transformation Required | Notes |
|------------------|---------------------------|------------------------|-------|
| `entity_id` | `id` (UUID) + `legacy_id` | ✅ Convert to UUID | Generate new UUID, store original entity_id in legacy_id |
| `email` | `email` | ❌ Direct mapping | Validate email format |
| `firstname` | `first_name` | ❌ Direct mapping | - |
| `lastname` | `last_name` | ❌ Direct mapping | - |
| `middlename` | `metadata.middle_name` | ✅ Move to metadata | Optional field |
| `prefix` | `metadata.prefix` | ✅ Move to metadata | Mr., Mrs., Dr., etc. |
| `suffix` | `metadata.suffix` | ✅ Move to metadata | Jr., Sr., III, etc. |
| `dob` | `date_of_birth` | ❌ Direct mapping | Date format validation |
| `gender` | `gender` | ✅ Transform values | 1=male, 2=female, 3=other |
| `group_id` | `customer_segments` | ✅ Map to segments | Convert to segment membership |
| `website_id` | `metadata.website_id` | ✅ Move to metadata | Multi-store support |
| `store_id` | `metadata.store_id` | ✅ Move to metadata | Store context |
| `created_at` | `created_at` | ❌ Direct mapping | Timestamp conversion |
| `updated_at` | `updated_at` | ❌ Direct mapping | Timestamp conversion |
| `is_active` | `status` | ✅ Transform values | 1=active, 0=inactive |
| `taxvat` | `metadata.tax_vat` | ✅ Move to metadata | Tax identification |
| `default_billing` | Address relationship | ✅ Complex mapping | Link to address with type='billing' |
| `default_shipping` | Address relationship | ✅ Complex mapping | Link to address with type='shipping' |

### 2. **Address Entity Mapping**

| Magento 2 Field | New Address Field | Transformation Required | Notes |
|------------------|-------------------|------------------------|-------|
| `entity_id` | `id` (UUID) + `legacy_id` | ✅ Convert to UUID | Generate new UUID, store original entity_id in legacy_id |
| `parent_id` | `customer_id` + `customer_legacy_id` | ✅ Map to customer UUID | Use customer mapping, keep legacy reference |
| `firstname` | `first_name` | ❌ Direct mapping | - |
| `lastname` | `last_name` | ❌ Direct mapping | - |
| `company` | `company` | ❌ Direct mapping | - |
| `street` | `address_line_1`, `address_line_2` | ✅ Split street lines | Parse multiline street |
| `city` | `city` | ❌ Direct mapping | - |
| `region` | `state_province` | ❌ Direct mapping | - |
| `postcode` | `postal_code` | ❌ Direct mapping | - |
| `country_id` | `country_code` | ❌ Direct mapping | ISO country codes |
| `telephone` | `phone` | ❌ Direct mapping | - |
| `is_active` | Active addresses only | ✅ Filter inactive | Only migrate active addresses |
| Default billing/shipping | `type` and `is_default` | ✅ Complex logic | Determine address type and default status |

### 3. **Customer Group to Segment Mapping**

| Magento 2 Group | New Segment | Description |
|------------------|-------------|-------------|
| `General` (ID: 1) | `regular-customers` | Regular retail customers |
| `NOT LOGGED IN` (ID: 0) | `guest-customers` | Guest checkout customers |
| `Wholesale` (ID: 2) | `wholesale-customers` | B2B wholesale customers |
| `Retailer` (ID: 3) | `retail-partners` | Retail partner customers |
| Custom Groups | Custom segments | Map based on group code |

## 📊 Migration Data Requirements

### 1. **Essential Customer Data**
```json
{
  "customer_basic_info": {
    "required_fields": [
      "email",
      "first_name", 
      "last_name",
      "created_at",
      "status"
    ],
    "optional_fields": [
      "phone",
      "date_of_birth",
      "gender",
      "middle_name",
      "prefix",
      "suffix"
    ]
  }
}
```

### 2. **Address Data Requirements**
```json
{
  "address_requirements": {
    "required_fields": [
      "address_line_1",
      "city",
      "country_code"
    ],
    "optional_fields": [
      "address_line_2",
      "state_province",
      "postal_code",
      "phone",
      "company"
    ],
    "business_logic": [
      "determine_address_type",
      "set_default_addresses",
      "validate_country_postal_code"
    ]
  }
}
```

### 3. **Customer Segmentation Data**
```json
{
  "segmentation_data": {
    "customer_groups": "Map from customer_group table",
    "purchase_history": "From sales_order for RFM analysis",
    "customer_attributes": "From EAV tables",
    "behavioral_data": "From customer login/activity logs"
  }
}
```

## 🔧 Migration Implementation Strategy

### Phase 1: Data Extraction and Validation

#### 1. **Customer Data Extraction Query**
```sql
-- Extract customer data from Magento 2
SELECT 
    ce.entity_id,
    ce.email,
    ce.firstname,
    ce.lastname,
    ce.middlename,
    ce.prefix,
    ce.suffix,
    ce.dob,
    ce.gender,
    ce.group_id,
    ce.website_id,
    ce.store_id,
    ce.created_at,
    ce.updated_at,
    ce.is_active,
    ce.taxvat,
    ce.default_billing,
    ce.default_shipping,
    cg.customer_group_code,
    -- Custom attributes from EAV
    phone_attr.value as phone,
    company_attr.value as company
FROM customer_entity ce
LEFT JOIN customer_group cg ON ce.group_id = cg.customer_group_id
LEFT JOIN customer_entity_varchar phone_attr ON ce.entity_id = phone_attr.entity_id 
    AND phone_attr.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'phone')
LEFT JOIN customer_entity_varchar company_attr ON ce.entity_id = company_attr.entity_id 
    AND company_attr.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'company')
WHERE ce.is_active = 1
ORDER BY ce.entity_id;
```

#### 2. **Address Data Extraction Query**
```sql
-- Extract address data from Magento 2
SELECT 
    cae.entity_id,
    cae.parent_id as customer_id,
    cae.firstname,
    cae.lastname,
    cae.company,
    cae.street,
    cae.city,
    cae.region,
    cae.postcode,
    cae.country_id,
    cae.telephone,
    cae.created_at,
    cae.updated_at,
    cae.is_active,
    -- Determine if this is default billing/shipping
    CASE 
        WHEN ce.default_billing = cae.entity_id THEN 'billing'
        WHEN ce.default_shipping = cae.entity_id THEN 'shipping'
        WHEN ce.default_billing = cae.entity_id AND ce.default_shipping = cae.entity_id THEN 'both'
        ELSE 'additional'
    END as address_type,
    CASE 
        WHEN ce.default_billing = cae.entity_id OR ce.default_shipping = cae.entity_id THEN true
        ELSE false
    END as is_default
FROM customer_address_entity cae
JOIN customer_entity ce ON cae.parent_id = ce.entity_id
WHERE cae.is_active = 1
ORDER BY cae.parent_id, cae.entity_id;
```

### Phase 2: Data Transformation

#### 1. **Customer Transformation Logic**
```go
type MagentoCustomer struct {
    EntityID     int       `json:"entity_id"`
    Email        string    `json:"email"`
    FirstName    string    `json:"firstname"`
    LastName     string    `json:"lastname"`
    MiddleName   *string   `json:"middlename"`
    Prefix       *string   `json:"prefix"`
    Suffix       *string   `json:"suffix"`
    DOB          *string   `json:"dob"`
    Gender       *int      `json:"gender"`
    GroupID      int       `json:"group_id"`
    GroupCode    string    `json:"customer_group_code"`
    WebsiteID    int       `json:"website_id"`
    StoreID      int       `json:"store_id"`
    CreatedAt    time.Time `json:"created_at"`
    UpdatedAt    time.Time `json:"updated_at"`
    IsActive     int       `json:"is_active"`
    TaxVat       *string   `json:"taxvat"`
    Phone        *string   `json:"phone"`
    Company      *string   `json:"company"`
}

func TransformMagentoCustomer(mc *MagentoCustomer) (*Customer, error) {
    // Generate new UUID
    customerID := uuid.New().String()
    
    // Map gender values
    var gender string
    if mc.Gender != nil {
        switch *mc.Gender {
        case 1:
            gender = "male"
        case 2:
            gender = "female"
        case 3:
            gender = "other"
        default:
            gender = "prefer_not_to_say"
        }
    }
    
    // Map status
    status := "inactive"
    if mc.IsActive == 1 {
        status = "active"
    }
    
    // Parse date of birth
    var dob *time.Time
    if mc.DOB != nil && *mc.DOB != "" {
        if parsed, err := time.Parse("2006-01-02", *mc.DOB); err == nil {
            dob = &parsed
        }
    }
    
    // Build metadata
    metadata := map[string]interface{}{
        "magento_entity_id": mc.EntityID,
        "website_id":        mc.WebsiteID,
        "store_id":          mc.StoreID,
    }
    
    if mc.MiddleName != nil {
        metadata["middle_name"] = *mc.MiddleName
    }
    if mc.Prefix != nil {
        metadata["prefix"] = *mc.Prefix
    }
    if mc.Suffix != nil {
        metadata["suffix"] = *mc.Suffix
    }
    if mc.TaxVat != nil {
        metadata["tax_vat"] = *mc.TaxVat
    }
    if mc.Company != nil {
        metadata["company"] = *mc.Company
    }
    
    // Build preferences
    preferences := map[string]interface{}{
        "email_marketing": true,
        "sms_marketing":   false,
    }
    
    return &Customer{
        ID:                 customerID,
        Email:              mc.Email,
        FirstName:          mc.FirstName,
        LastName:           mc.LastName,
        Phone:              mc.Phone,
        DateOfBirth:        dob,
        Gender:             gender,
        CustomerType:       "individual", // Default, can be enhanced
        Status:             status,
        EmailVerified:      true, // Assume existing customers are verified
        PhoneVerified:      false,
        Preferences:        preferences,
        Metadata:           metadata,
        RegistrationSource: "magento_migration",
        CreatedAt:          mc.CreatedAt,
        UpdatedAt:          mc.UpdatedAt,
    }, nil
}
```

#### 2. **Address Transformation Logic**
```go
type MagentoAddress struct {
    EntityID     int     `json:"entity_id"`
    CustomerID   int     `json:"customer_id"`
    FirstName    string  `json:"firstname"`
    LastName     string  `json:"lastname"`
    Company      *string `json:"company"`
    Street       string  `json:"street"`
    City         string  `json:"city"`
    Region       *string `json:"region"`
    PostCode     *string `json:"postcode"`
    CountryID    string  `json:"country_id"`
    Telephone    *string `json:"telephone"`
    AddressType  string  `json:"address_type"`
    IsDefault    bool    `json:"is_default"`
    CreatedAt    time.Time `json:"created_at"`
    UpdatedAt    time.Time `json:"updated_at"`
}

func TransformMagentoAddress(ma *MagentoAddress, customerUUIDMap map[int]string) (*Address, error) {
    // Get customer UUID from mapping
    customerUUID, exists := customerUUIDMap[ma.CustomerID]
    if !exists {
        return nil, fmt.Errorf("customer UUID not found for Magento customer ID: %d", ma.CustomerID)
    }
    
    // Parse street address (Magento stores as multiline)
    streetLines := strings.Split(ma.Street, "\n")
    addressLine1 := strings.TrimSpace(streetLines[0])
    var addressLine2 string
    if len(streetLines) > 1 {
        addressLine2 = strings.TrimSpace(streetLines[1])
    }
    
    // Determine address type
    addressType := "shipping" // Default
    if ma.AddressType == "billing" || ma.AddressType == "both" {
        addressType = "billing"
    }
    
    return &Address{
        ID:           uuid.New().String(),
        CustomerID:   customerUUID,
        Type:         addressType,
        FirstName:    ma.FirstName,
        LastName:     ma.LastName,
        Company:      ma.Company,
        AddressLine1: addressLine1,
        AddressLine2: addressLine2,
        City:         ma.City,
        StateProvince: ma.Region,
        PostalCode:   ma.PostCode,
        CountryCode:  ma.CountryID,
        Phone:        ma.Telephone,
        IsDefault:    ma.IsDefault,
        IsVerified:   false, // Will need verification in new system
        CreatedAt:    ma.CreatedAt,
        UpdatedAt:    ma.UpdatedAt,
    }, nil
}
```

### Phase 3: Customer Segmentation Migration

#### 1. **Segment Creation Strategy**
```go
type SegmentMigrationPlan struct {
    DefaultSegments []CustomerSegment
    CustomSegments  []CustomerSegment
}

func CreateDefaultSegments() []CustomerSegment {
    return []CustomerSegment{
        {
            ID:          uuid.New().String(),
            Name:        "All Customers",
            Description: "All registered customers",
            Rules: map[string]interface{}{
                "type": "all",
            },
            IsActive: true,
        },
        {
            ID:          uuid.New().String(),
            Name:        "Regular Customers",
            Description: "Regular retail customers (migrated from Magento General group)",
            Rules: map[string]interface{}{
                "magento_group_id": 1,
            },
            IsActive: true,
        },
        {
            ID:          uuid.New().String(),
            Name:        "Wholesale Customers",
            Description: "B2B wholesale customers",
            Rules: map[string]interface{}{
                "magento_group_id": 2,
                "customer_type":    "business",
            },
            IsActive: true,
        },
        {
            ID:          uuid.New().String(),
            Name:        "VIP Customers",
            Description: "High-value customers based on purchase history",
            Rules: map[string]interface{}{
                "min_order_count":  10,
                "min_total_spent": 1000,
            },
            IsActive: true,
        },
        {
            ID:          uuid.New().String(),
            Name:        "New Customers",
            Description: "Customers registered in the last 30 days",
            Rules: map[string]interface{}{
                "registration_days": 30,
            },
            IsActive: true,
        },
    }
}
```

## 📈 Migration Performance Considerations

### 1. **Batch Processing Strategy**
- **Batch Size**: 1,000 customers per batch
- **Parallel Processing**: 4-8 concurrent workers
- **Memory Management**: Stream processing for large datasets
- **Error Handling**: Retry failed records with exponential backoff

### 2. **Data Validation Requirements**
```go
type ValidationRules struct {
    Email struct {
        Required bool
        Format   string // RFC 5322 email format
        Unique   bool
    }
    Phone struct {
        Format string // E.164 international format
    }
    Address struct {
        RequiredFields []string
        CountryValidation bool
        PostalCodeValidation bool
    }
}
```

### 3. **Migration Monitoring**
```go
type MigrationMetrics struct {
    TotalCustomers      int64
    ProcessedCustomers  int64
    FailedCustomers     int64
    TotalAddresses      int64
    ProcessedAddresses  int64
    FailedAddresses     int64
    ProcessingRate      float64 // customers per second
    EstimatedCompletion time.Time
    Errors              []MigrationError
}
```

## 🔍 Data Quality Assurance

### 1. **Pre-Migration Data Audit**
```sql
-- Check for data quality issues in Magento
SELECT 
    'Duplicate Emails' as issue,
    COUNT(*) as count
FROM (
    SELECT email, COUNT(*) as cnt
    FROM customer_entity 
    WHERE is_active = 1
    GROUP BY email 
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT 
    'Invalid Email Formats' as issue,
    COUNT(*) as count
FROM customer_entity 
WHERE is_active = 1 
AND (email IS NULL OR email = '' OR email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')

UNION ALL

SELECT 
    'Missing Names' as issue,
    COUNT(*) as count
FROM customer_entity 
WHERE is_active = 1 
AND (firstname IS NULL OR firstname = '' OR lastname IS NULL OR lastname = '')

UNION ALL

SELECT 
    'Addresses Without Required Fields' as issue,
    COUNT(*) as count
FROM customer_address_entity 
WHERE is_active = 1 
AND (street IS NULL OR street = '' OR city IS NULL OR city = '' OR country_id IS NULL OR country_id = '');
```

### 2. **Post-Migration Validation**
```go
type PostMigrationValidation struct {
    CustomerCountMatch    bool
    AddressCountMatch     bool
    EmailUniqueness      bool
    SegmentAssignments   bool
    DataIntegrity        bool
    PerformanceMetrics   MigrationMetrics
}

func ValidatePostMigration(ctx context.Context) (*PostMigrationValidation, error) {
    validation := &PostMigrationValidation{}
    
    // Validate customer count
    magentoCount := getMagentoCustomerCount()
    newServiceCount := getNewServiceCustomerCount(ctx)
    validation.CustomerCountMatch = (magentoCount == newServiceCount)
    
    // Validate email uniqueness
    validation.EmailUniqueness = validateEmailUniqueness(ctx)
    
    // Validate segment assignments
    validation.SegmentAssignments = validateSegmentAssignments(ctx)
    
    return validation, nil
}
```

## 🔧 Legacy ID Use Cases

### 1. **Data Synchronization**
```go
// Sync customer data from Magento to microservice
func SyncCustomerFromMagento(magentoEntityID int, customerData MagentoCustomer) error {
    // Check if customer already exists by legacy_id
    existingCustomer, err := GetCustomerByLegacyID(ctx, magentoEntityID)
    if err == nil {
        // Update existing customer
        return UpdateCustomer(existingCustomer.ID, customerData)
    }
    
    // Create new customer with legacy_id
    return CreateCustomerWithLegacyID(customerData, magentoEntityID)
}
```

### 2. **API Compatibility Layer**
```go
// Support both UUID and legacy ID in APIs
func GetCustomerHandler(w http.ResponseWriter, r *http.Request) {
    customerID := mux.Vars(r)["id"]
    
    var customer *Customer
    var err error
    
    // Try to parse as UUID first
    if _, uuidErr := uuid.Parse(customerID); uuidErr == nil {
        customer, err = GetCustomerByID(ctx, customerID)
    } else {
        // Try as legacy ID
        if legacyID, parseErr := strconv.Atoi(customerID); parseErr == nil {
            customer, err = GetCustomerByLegacyID(ctx, legacyID)
        } else {
            http.Error(w, "Invalid customer ID format", http.StatusBadRequest)
            return
        }
    }
    
    if err != nil {
        http.Error(w, "Customer not found", http.StatusNotFound)
        return
    }
    
    json.NewEncoder(w).Encode(customer)
}
```

### 3. **Data Validation & Audit**
```go
// Validate migration completeness
func ValidateMigrationCompleteness() error {
    // Check for missing customers
    missingCustomers := `
        SELECT me.entity_id 
        FROM magento.customer_entity me
        LEFT JOIN microservice.customers c ON me.entity_id = c.legacy_id
        WHERE me.is_active = 1 AND c.legacy_id IS NULL
    `
    
    // Check for missing addresses
    missingAddresses := `
        SELECT mae.entity_id 
        FROM magento.customer_address_entity mae
        LEFT JOIN microservice.customer_addresses ca ON mae.entity_id = ca.legacy_id
        WHERE mae.is_active = 1 AND ca.legacy_id IS NULL
    `
    
    return ValidateQueries(missingCustomers, missingAddresses)
}
```

### 4. **Rollback Strategy**
```go
// Rollback migration using legacy IDs
func RollbackMigration(migrationBatch string) error {
    // Delete customers migrated in this batch
    _, err := db.Exec(`
        DELETE FROM customers 
        WHERE legacy_id IN (
            SELECT legacy_id FROM migration_id_mapping 
            WHERE migration_batch = $1 AND entity_type = 'customer'
        )
    `, migrationBatch)
    
    return err
}
```

### 5. **Incremental Migration**
```go
// Migrate only new/updated customers since last migration
func IncrementalMigration(lastMigrationTime time.Time) error {
    query := `
        SELECT entity_id, email, firstname, lastname, updated_at
        FROM customer_entity 
        WHERE updated_at > ? 
        AND (
            entity_id NOT IN (SELECT legacy_id FROM customers WHERE legacy_id IS NOT NULL)
            OR updated_at > (
                SELECT updated_at FROM customers 
                WHERE legacy_id = customer_entity.entity_id
            )
        )
    `
    
    return ProcessIncrementalCustomers(query, lastMigrationTime)
}
```

## 🚀 Migration Execution Plan

### Week 1: Preparation
- [ ] Set up migration infrastructure
- [ ] Create data extraction scripts
- [ ] Implement transformation logic
- [ ] Set up validation framework

### Week 2: Data Migration
- [ ] Extract customer data from Magento
- [ ] Transform and validate data
- [ ] Migrate customers in batches
- [ ] Migrate addresses and relationships

### Week 3: Segmentation & Testing
- [ ] Create customer segments
- [ ] Assign customers to segments
- [ ] Run comprehensive validation
- [ ] Performance testing

### Week 4: Go-Live & Monitoring
- [ ] Switch traffic to new service
- [ ] Monitor system performance
- [ ] Handle any data issues
- [ ] Document lessons learned

## 📊 Expected Migration Results

### Data Volume Estimates
- **Customers**: ~50,000-100,000 records
- **Addresses**: ~150,000-300,000 records  
- **Segments**: ~10-20 segments
- **Migration Time**: 2-4 hours for full dataset

### Success Criteria
- ✅ 100% customer data migrated successfully
- ✅ 99.9% address data migrated successfully
- ✅ All customer segments created and assigned
- ✅ Data integrity validation passes
- ✅ Performance meets SLA requirements (<100ms response time)

---

**📅 Last Updated**: November 2024  
**📝 Version**: 1.0  
**👥 Prepared By**: Migration Team