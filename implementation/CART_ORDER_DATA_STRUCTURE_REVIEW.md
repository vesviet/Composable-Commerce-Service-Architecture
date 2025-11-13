# Cart & Order Data Structure Review

> **Review Date**: December 2024  
> **Status**: Complete Review with Recommendations

---

## 📋 Overview

Tài liệu này review chi tiết data structure của Cart và Order services, bao gồm database schema, relationships, indexes, constraints, và các recommendations để cải thiện performance và data integrity.

---

## 🗄️ Database Schema Overview

### Tables Summary
- **Cart**: `cart_sessions`, `cart_items`
- **Order**: `orders`, `order_items`, `order_addresses`, `order_status_history`, `order_payments`

---

## 🛒 CART DATA STRUCTURE

### 1. cart_sessions Table

#### Schema
```sql
CREATE TABLE cart_sessions (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    user_id VARCHAR(36),                    -- Changed to UUID string
    guest_token VARCHAR(100),
    expires_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### Model Structure
```go
type CartSession struct {
    ID         int64                  `gorm:"primaryKey;autoIncrement"`
    SessionID  string                 `gorm:"uniqueIndex;size:100;not null"`
    UserID     *string                `gorm:"index;type:varchar(36)"`  // UUID
    GuestToken string                 `gorm:"index;size:100"`
    ExpiresAt  *time.Time
    Metadata   map[string]interface{} `gorm:"type:jsonb"`
    CreatedAt  time.Time              `gorm:"index"`
    UpdatedAt  time.Time
    
    Items []CartItem `gorm:"foreignKey:SessionID;references:SessionID;constraint:OnDelete:CASCADE"`
}
```

#### Indexes
- ✅ `idx_cart_sessions_session_id` - UNIQUE (Primary lookup)
- ✅ `idx_cart_sessions_user_id` - For user cart lookup
- ✅ `idx_cart_sessions_guest_token` - For guest cart lookup
- ✅ `idx_cart_sessions_expires_at` - For expiration cleanup

#### ✅ Strengths
1. **Flexible Identification**: Supports SessionID, UserID, and GuestToken
2. **Proper Indexing**: All lookup paths are indexed
3. **Cascade Delete**: Items automatically deleted when session deleted
4. **Metadata Support**: JSONB for flexible data storage
5. **Expiration Support**: ExpiresAt field for cleanup

#### ⚠️ Issues & Recommendations

**Issue 1: Missing Composite Index**
- **Problem**: Queries filtering by `user_id` AND `expires_at` (for cleanup) may not use index efficiently
- **Recommendation**: Add composite index:
```sql
CREATE INDEX idx_cart_sessions_user_expires 
    ON cart_sessions(user_id, expires_at) 
    WHERE user_id IS NOT NULL;
```

**Issue 2: No Constraint on UserID/GuestToken**
- **Problem**: Both UserID and GuestToken can be NULL, but at least one should exist
- **Recommendation**: Add check constraint:
```sql
ALTER TABLE cart_sessions 
    ADD CONSTRAINT chk_cart_sessions_identifier 
    CHECK (user_id IS NOT NULL OR guest_token IS NOT NULL);
```

**Issue 3: SessionID Generation**
- **Problem**: No clear pattern for SessionID generation
- **Recommendation**: Use UUID format for SessionID:
```sql
ALTER TABLE cart_sessions 
    ALTER COLUMN session_id TYPE VARCHAR(36);
-- Generate UUIDs: gen_random_uuid()::VARCHAR(36)
```

---

### 2. cart_items Table

#### Schema
```sql
CREATE TABLE cart_items (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) NOT NULL,
    product_id VARCHAR(36) NOT NULL,        -- Changed to UUID string
    product_sku VARCHAR(100) NOT NULL,
    product_name VARCHAR(255),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2),
    total_price DECIMAL(12,2),
    discount_amount DECIMAL(10,2) DEFAULT 0.00,
    warehouse_id VARCHAR(36),                 -- Changed to UUID string
    in_stock BOOLEAN DEFAULT true,
    metadata JSONB,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_cart_items_session_id 
        FOREIGN KEY (session_id) 
        REFERENCES cart_sessions(session_id) 
        ON DELETE CASCADE,
    
    UNIQUE INDEX idx_cart_items_unique_product_warehouse 
        (session_id, product_id, warehouse_id)
);
```

#### Model Structure
```go
type CartItem struct {
    ID             int64                  `gorm:"primaryKey;autoIncrement"`
    SessionID      string                 `gorm:"index;size:100;not null"`
    ProductID      string                 `gorm:"index;type:varchar(36);not null"`  // UUID
    ProductSKU     string                 `gorm:"index;size:100;not null"`
    ProductName    string                 `gorm:"size:255"`
    Quantity       int32                  `gorm:"not null;check:quantity > 0"`
    UnitPrice      *float64               `gorm:"type:decimal(10,2)"`
    TotalPrice     *float64               `gorm:"type:decimal(12,2)"`
    DiscountAmount float64                `gorm:"type:decimal(10,2);default:0.00"`
    WarehouseID    *string                `gorm:"index;type:varchar(36)"`  // UUID
    InStock        bool                   `gorm:"default:true"`
    Metadata       map[string]interface{} `gorm:"type:jsonb"`
    AddedAt        time.Time              `gorm:"index;default:CURRENT_TIMESTAMP"`
    UpdatedAt      time.Time
    
    Session *CartSession `gorm:"foreignKey:SessionID;references:SessionID;constraint:OnDelete:CASCADE"`
}
```

#### Indexes
- ✅ `idx_cart_items_session_id` - For cart lookup
- ✅ `idx_cart_items_product_id` - For product queries
- ✅ `idx_cart_items_product_sku` - For SKU lookup
- ✅ `idx_cart_items_warehouse_id` - For warehouse filtering
- ✅ `idx_cart_items_added_at` - For sorting
- ✅ `idx_cart_items_unique_product_warehouse` - UNIQUE (Prevent duplicates)

#### ✅ Strengths
1. **Duplicate Prevention**: Unique constraint prevents same product+warehouse in cart
2. **Price Tracking**: Stores both unit and total price
3. **Stock Status**: InStock flag for quick status check
4. **Flexible Pricing**: UnitPrice nullable (can be calculated on demand)
5. **Metadata Support**: JSONB for custom data

#### ⚠️ Issues & Recommendations

**Issue 1: Price Consistency**
- **Problem**: No constraint ensuring `total_price = unit_price * quantity - discount_amount`
- **Recommendation**: Add check constraint or computed column:
```sql
ALTER TABLE cart_items 
    ADD CONSTRAINT chk_cart_items_price_consistency 
    CHECK (
        (unit_price IS NULL AND total_price IS NULL) OR
        (unit_price IS NOT NULL AND total_price IS NOT NULL AND 
         ABS(total_price - (unit_price * quantity - discount_amount)) < 0.01)
    );
```

**Issue 2: Product Name Denormalization**
- **Problem**: ProductName stored but may become stale
- **Recommendation**: 
  - Option A: Remove ProductName, fetch from Product Service on read
  - Option B: Add `product_name_updated_at` to track staleness
  - Option C: Keep as-is for performance (current approach)

**Issue 3: InStock Flag Staleness**
- **Problem**: InStock flag may become outdated
- **Recommendation**: 
  - Add `stock_checked_at` timestamp
  - Or remove flag and check on-demand

**Issue 4: Missing Currency Field**
- **Problem**: No currency field, assumes single currency
- **Recommendation**: Add currency field:
```sql
ALTER TABLE cart_items 
    ADD COLUMN currency VARCHAR(3) DEFAULT 'USD';
```

**Issue 5: WarehouseID in Unique Constraint**
- **Problem**: Unique constraint includes NULL warehouse_id, which may cause issues
- **Recommendation**: Use partial unique index:
```sql
-- Drop existing unique index
DROP INDEX idx_cart_items_unique_product_warehouse;

-- Create partial unique indexes
CREATE UNIQUE INDEX idx_cart_items_unique_product_warehouse_not_null
    ON cart_items(session_id, product_id, warehouse_id)
    WHERE warehouse_id IS NOT NULL;

CREATE UNIQUE INDEX idx_cart_items_unique_product_warehouse_null
    ON cart_items(session_id, product_id)
    WHERE warehouse_id IS NULL;
```

---

## 📦 ORDER DATA STRUCTURE

### 1. orders Table

#### Schema
```sql
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    user_id VARCHAR(36) NOT NULL,            -- Changed to UUID string
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    shipping_address_id BIGINT,
    billing_address_id BIGINT,
    payment_method VARCHAR(50),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    notes TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);
```

#### Model Structure
```go
type Order struct {
    ID                int64                  `gorm:"primaryKey;autoIncrement"`
    OrderNumber       string                 `gorm:"uniqueIndex;size:50;not null"`
    UserID            string                 `gorm:"index;type:varchar(36);not null"`  // UUID
    Status            string                 `gorm:"index;size:20;not null;default:pending"`
    TotalAmount       float64                `gorm:"type:decimal(12,2);not null;default:0.00"`
    Currency          string                 `gorm:"size:3;not null;default:USD"`
    ShippingAddressID *int64
    BillingAddressID  *int64
    PaymentMethod     string                 `gorm:"size:50"`
    PaymentStatus     string                 `gorm:"index;size:20;not null;default:pending"`
    Notes             string                 `gorm:"type:text"`
    Metadata          map[string]interface{} `gorm:"type:jsonb"`
    CreatedAt         time.Time              `gorm:"index"`
    UpdatedAt         time.Time
    ExpiresAt         *time.Time
    CancelledAt       *time.Time
    CompletedAt       *time.Time
    
    Items           []OrderItem           `gorm:"foreignKey:OrderID;constraint:OnDelete:CASCADE"`
    ShippingAddress *OrderAddress         `gorm:"foreignKey:ShippingAddressID"`
    BillingAddress  *OrderAddress        `gorm:"foreignKey:BillingAddressID"`
    StatusHistory   []OrderStatusHistory  `gorm:"foreignKey:OrderID;constraint:OnDelete:CASCADE"`
    Payments        []OrderPayment        `gorm:"foreignKey:OrderID;constraint:OnDelete:CASCADE"`
}
```

#### Indexes
- ✅ `idx_orders_user_id` - For user order lookup
- ✅ `idx_orders_status` - For status filtering
- ✅ `idx_orders_payment_status` - For payment status filtering
- ✅ `idx_orders_created_at` - For date range queries
- ✅ `idx_orders_order_number` - UNIQUE (Primary lookup)

#### ✅ Strengths
1. **Comprehensive Status Tracking**: Status, PaymentStatus, timestamps
2. **Order Number**: Unique identifier for customer-facing reference
3. **Expiration Support**: ExpiresAt for abandoned order cleanup
4. **Lifecycle Timestamps**: CreatedAt, CancelledAt, CompletedAt
5. **Metadata Support**: JSONB for flexible data

#### ⚠️ Issues & Recommendations

**Issue 1: Missing Status Constraint**
- **Problem**: No CHECK constraint on valid status values
- **Recommendation**: Add constraint:
```sql
ALTER TABLE orders 
    ADD CONSTRAINT chk_orders_status 
    CHECK (status IN (
        'pending', 'confirmed', 'processing', 'shipped', 
        'delivered', 'cancelled', 'failed', 'refunded'
    ));
```

**Issue 2: Missing Payment Status Constraint**
- **Problem**: No CHECK constraint on valid payment status values
- **Recommendation**: Add constraint:
```sql
ALTER TABLE orders 
    ADD CONSTRAINT chk_orders_payment_status 
    CHECK (payment_status IN (
        'pending', 'processing', 'authorized', 'captured', 
        'failed', 'refunded', 'cancelled'
    ));
```

**Issue 3: Address ID Foreign Keys Missing**
- **Problem**: ShippingAddressID and BillingAddressID don't have foreign key constraints
- **Recommendation**: Add foreign keys:
```sql
ALTER TABLE orders 
    ADD CONSTRAINT fk_orders_shipping_address 
    FOREIGN KEY (shipping_address_id) 
    REFERENCES order_addresses(id) 
    ON DELETE SET NULL;

ALTER TABLE orders 
    ADD CONSTRAINT fk_orders_billing_address 
    FOREIGN KEY (billing_address_id) 
    REFERENCES order_addresses(id) 
    ON DELETE SET NULL;
```

**Issue 4: Missing Composite Indexes**
- **Problem**: Common queries filter by multiple fields
- **Recommendation**: Add composite indexes:
```sql
-- For user order history with status filter
CREATE INDEX idx_orders_user_status_created 
    ON orders(user_id, status, created_at DESC);

-- For payment status queries
CREATE INDEX idx_orders_payment_status_created 
    ON orders(payment_status, created_at DESC);

-- For expiration cleanup
CREATE INDEX idx_orders_expires_status 
    ON orders(expires_at, status) 
    WHERE expires_at IS NOT NULL AND status = 'pending';
```

**Issue 5: Order Number Generation**
- **Problem**: No clear pattern for order number generation
- **Recommendation**: Use format like `ORD-{YYYYMMDD}-{SEQUENCE}` or UUID-based

**Issue 6: Total Amount Validation**
- **Problem**: No constraint ensuring total_amount matches sum of items
- **Recommendation**: 
  - Option A: Add check constraint (may be complex)
  - Option B: Use database trigger to validate
  - Option C: Validate in application layer (current approach)

---

### 2. order_items Table

#### Schema
```sql
CREATE TABLE order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id VARCHAR(36) NOT NULL,         -- Changed to UUID string
    product_sku VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    total_price DECIMAL(12,2) NOT NULL CHECK (total_price >= 0),
    discount_amount DECIMAL(10,2) DEFAULT 0.00,
    tax_amount DECIMAL(10,2) DEFAULT 0.00,
    warehouse_id VARCHAR(36),                -- Changed to UUID string
    reservation_id BIGINT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### Model Structure
```go
type OrderItem struct {
    ID             int64                  `gorm:"primaryKey;autoIncrement"`
    OrderID        int64                  `gorm:"index;not null"`
    ProductID      string                 `gorm:"index;type:varchar(36);not null"`  // UUID
    ProductSKU     string                 `gorm:"index;size:100;not null"`
    ProductName    string                 `gorm:"size:255;not null"`
    Quantity       int32                  `gorm:"not null;check:quantity > 0"`
    UnitPrice      float64                `gorm:"type:decimal(10,2);not null;check:unit_price >= 0"`
    TotalPrice     float64                `gorm:"type:decimal(12,2);not null;check:total_price >= 0"`
    DiscountAmount float64                `gorm:"type:decimal(10,2);default:0.00"`
    TaxAmount      float64                `gorm:"type:decimal(10,2);default:0.00"`
    WarehouseID    *string                `gorm:"index;type:varchar(36)"`  // UUID
    ReservationID  *int64
    Metadata       map[string]interface{} `gorm:"type:jsonb"`
    CreatedAt      time.Time
    UpdatedAt      time.Time
    
    Order *Order `gorm:"foreignKey:OrderID;constraint:OnDelete:CASCADE"`
}
```

#### Indexes
- ✅ `idx_order_items_order_id` - For order lookup
- ✅ `idx_order_items_product_id` - For product queries
- ✅ `idx_order_items_product_sku` - For SKU lookup
- ✅ `idx_order_items_warehouse_id` - For warehouse filtering

#### ✅ Strengths
1. **Price Constraints**: CHECK constraints on prices
2. **Quantity Constraint**: CHECK constraint on quantity
3. **Tax Tracking**: TaxAmount field for tax calculation
4. **Reservation Tracking**: ReservationID for stock reservation
5. **Immutable Data**: Order items are immutable (snapshot at order time)

#### ⚠️ Issues & Recommendations

**Issue 1: Price Consistency**
- **Problem**: No constraint ensuring `total_price = (unit_price * quantity) - discount_amount + tax_amount`
- **Recommendation**: Add check constraint:
```sql
ALTER TABLE order_items 
    ADD CONSTRAINT chk_order_items_price_consistency 
    CHECK (
        ABS(total_price - ((unit_price * quantity) - discount_amount + tax_amount)) < 0.01
    );
```

**Issue 2: ReservationID Foreign Key Missing**
- **Problem**: ReservationID references warehouse reservations but no FK constraint
- **Recommendation**: 
  - Option A: Add FK if reservation table exists
  - Option B: Keep as-is if reservations in different service

**Issue 3: Missing Currency Field**
- **Problem**: No currency field per item (assumes order currency)
- **Recommendation**: Add currency if multi-currency support needed:
```sql
ALTER TABLE order_items 
    ADD COLUMN currency VARCHAR(3) DEFAULT 'USD';
```

**Issue 4: Product Name Immutability**
- **Problem**: ProductName stored but product may be deleted/renamed
- **Recommendation**: Keep as-is (snapshot is correct approach for orders)

---

### 3. order_addresses Table

#### Schema
```sql
CREATE TABLE order_addresses (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('shipping', 'billing')),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    company VARCHAR(100),
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(2) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### Model Structure
```go
type OrderAddress struct {
    ID           int64     `gorm:"primaryKey;autoIncrement"`
    OrderID      int64     `gorm:"index;not null"`
    Type         string    `gorm:"index;size:20;not null;check:type IN ('shipping', 'billing')"`
    FirstName    string    `gorm:"size:100;not null"`
    LastName     string    `gorm:"size:100;not null"`
    Company      string    `gorm:"size:100"`
    AddressLine1 string    `gorm:"size:255;not null"`
    AddressLine2 string    `gorm:"size:255"`
    City         string    `gorm:"size:100;not null"`
    State        string    `gorm:"size:100"`
    PostalCode   string    `gorm:"size:20;not null"`
    Country      string    `gorm:"size:2;not null"`
    Phone        string    `gorm:"size:20"`
    Email        string    `gorm:"size:255"`
    CreatedAt    time.Time
    UpdatedAt    time.Time
    
    Order *Order `gorm:"foreignKey:OrderID;constraint:OnDelete:CASCADE"`
}
```

#### Indexes
- ✅ `idx_order_addresses_order_id` - For order lookup
- ✅ `idx_order_addresses_type` - For type filtering
- ✅ `idx_order_addresses_order_type` - UNIQUE (One address per type per order)

#### ✅ Strengths
1. **Type Constraint**: CHECK constraint ensures valid type
2. **Unique Constraint**: One shipping and one billing address per order
3. **Immutable Data**: Addresses are snapshots at order time
4. **Complete Address Fields**: All necessary address components

#### ⚠️ Issues & Recommendations

**Issue 1: Country Code Validation**
- **Problem**: No validation on country code format (ISO 3166-1 alpha-2)
- **Recommendation**: Add CHECK constraint or use ENUM:
```sql
ALTER TABLE order_addresses 
    ADD CONSTRAINT chk_order_addresses_country 
    CHECK (country ~ '^[A-Z]{2}$');
```

**Issue 2: Email Validation**
- **Problem**: No email format validation
- **Recommendation**: Add CHECK constraint:
```sql
ALTER TABLE order_addresses 
    ADD CONSTRAINT chk_order_addresses_email 
    CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');
```

**Issue 3: Phone Number Format**
- **Problem**: No phone number format validation
- **Recommendation**: Add validation or store as-is (validation in application)

**Issue 4: Missing Address Reference in Orders**
- **Problem**: Orders table has ShippingAddressID and BillingAddressID but relationship not enforced
- **Recommendation**: Add foreign keys (see orders table Issue 3)

---

### 4. order_status_history Table

#### Schema
```sql
CREATE TABLE order_status_history (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    from_status VARCHAR(20),
    to_status VARCHAR(20) NOT NULL,
    reason VARCHAR(255),
    notes TEXT,
    changed_by BIGINT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);
```

#### Model Structure
```go
type OrderStatusHistory struct {
    ID         int64                  `gorm:"primaryKey;autoIncrement"`
    OrderID    int64                  `gorm:"index;not null"`
    FromStatus string                 `gorm:"size:20"`
    ToStatus   string                 `gorm:"index;size:20;not null"`
    Reason     string                 `gorm:"size:255"`
    Notes      string                 `gorm:"type:text"`
    ChangedBy  *int64
    ChangedAt  time.Time              `gorm:"index;default:CURRENT_TIMESTAMP"`
    Metadata   map[string]interface{} `gorm:"type:jsonb"`
    
    Order *Order `gorm:"foreignKey:OrderID;constraint:OnDelete:CASCADE"`
}
```

#### Indexes
- ✅ `idx_order_status_history_order_id` - For order history lookup
- ✅ `idx_order_status_history_to_status` - For status queries
- ✅ `idx_order_status_history_changed_at` - For timeline queries

#### ✅ Strengths
1. **Complete Audit Trail**: Tracks all status changes
2. **Change Attribution**: ChangedBy field for user tracking
3. **Metadata Support**: JSONB for additional context
4. **Timeline Support**: ChangedAt for chronological ordering

#### ⚠️ Issues & Recommendations

**Issue 1: Missing Composite Index**
- **Problem**: Common query is order history by order_id ordered by changed_at
- **Recommendation**: Add composite index:
```sql
CREATE INDEX idx_order_status_history_order_changed 
    ON order_status_history(order_id, changed_at DESC);
```

**Issue 2: ChangedBy Type Mismatch**
- **Problem**: ChangedBy is BIGINT but UserID is VARCHAR(36) UUID
- **Recommendation**: Change to VARCHAR(36):
```sql
ALTER TABLE order_status_history 
    ALTER COLUMN changed_by TYPE VARCHAR(36);
```

**Issue 3: Status Validation**
- **Problem**: No CHECK constraint on valid status values
- **Recommendation**: Add constraint (same as orders.status)

---

### 5. order_payments Table

#### Schema
```sql
CREATE TABLE order_payments (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    payment_id VARCHAR(100) UNIQUE NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_provider VARCHAR(50) NOT NULL,
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    transaction_id VARCHAR(255),
    gateway_response JSONB,
    processed_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,
    failure_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### Model Structure
```go
type OrderPayment struct {
    ID              int64                  `gorm:"primaryKey;autoIncrement"`
    OrderID         int64                  `gorm:"index;not null"`
    PaymentID       string                 `gorm:"uniqueIndex;size:100;not null"`
    PaymentMethod   string                 `gorm:"index;size:50;not null"`
    PaymentProvider string                 `gorm:"size:50;not null"`
    Amount          float64                `gorm:"type:decimal(12,2);not null;check:amount > 0"`
    Currency        string                 `gorm:"size:3;not null;default:USD"`
    Status          string                 `gorm:"index;size:20;not null;default:pending"`
    TransactionID   string                 `gorm:"size:255"`
    GatewayResponse map[string]interface{} `gorm:"type:jsonb"`
    ProcessedAt     *time.Time
    FailedAt        *time.Time
    FailureReason   string                 `gorm:"type:text"`
    CreatedAt       time.Time
    UpdatedAt       time.Time
    
    Order *Order `gorm:"foreignKey:OrderID;constraint:OnDelete:CASCADE"`
}
```

#### Indexes
- ✅ `idx_order_payments_order_id` - For order payment lookup
- ✅ `idx_order_payments_payment_id` - UNIQUE (Payment service lookup)
- ✅ `idx_order_payments_status` - For status filtering
- ✅ `idx_order_payments_payment_method` - For method filtering

#### ✅ Strengths
1. **Payment ID Uniqueness**: UNIQUE constraint prevents duplicates
2. **Amount Validation**: CHECK constraint ensures positive amount
3. **Gateway Response**: JSONB stores full gateway response
4. **Status Tracking**: ProcessedAt, FailedAt timestamps
5. **Failure Tracking**: FailureReason for debugging

#### ⚠️ Issues & Recommendations

**Issue 1: Status Validation**
- **Problem**: No CHECK constraint on valid payment status values
- **Recommendation**: Add constraint:
```sql
ALTER TABLE order_payments 
    ADD CONSTRAINT chk_order_payments_status 
    CHECK (status IN (
        'pending', 'processing', 'authorized', 'captured', 
        'failed', 'refunded', 'cancelled'
    ));
```

**Issue 2: Missing Composite Index**
- **Problem**: Common query is payments by order and status
- **Recommendation**: Add composite index:
```sql
CREATE INDEX idx_order_payments_order_status 
    ON order_payments(order_id, status);
```

**Issue 3: Payment Method/Provider Validation**
- **Problem**: No validation on payment method/provider values
- **Recommendation**: Add CHECK constraints or use ENUMs

**Issue 4: Multiple Payments per Order**
- **Problem**: No constraint preventing multiple successful payments
- **Recommendation**: Add partial unique index:
```sql
CREATE UNIQUE INDEX idx_order_payments_unique_successful 
    ON order_payments(order_id) 
    WHERE status IN ('authorized', 'captured');
```

---

## 🔗 RELATIONSHIPS REVIEW

### Current Relationships

#### Cart Relationships
- ✅ `cart_items.session_id` → `cart_sessions.session_id` (CASCADE DELETE)

#### Order Relationships
- ✅ `order_items.order_id` → `orders.id` (CASCADE DELETE)
- ✅ `order_addresses.order_id` → `orders.id` (CASCADE DELETE)
- ✅ `order_status_history.order_id` → `orders.id` (CASCADE DELETE)
- ✅ `order_payments.order_id` → `orders.id` (CASCADE DELETE)
- ❌ `orders.shipping_address_id` → `order_addresses.id` (MISSING FK)
- ❌ `orders.billing_address_id` → `order_addresses.id` (MISSING FK)

### Recommendations

1. **Add Missing Foreign Keys**: Add FKs for shipping_address_id and billing_address_id
2. **Consider Soft Deletes**: For orders, consider soft deletes instead of CASCADE
3. **Add Reservation FK**: If reservation table exists, add FK for reservation_id

---

## 📊 DATA TYPE CONSISTENCY

### UUID Migration Status
- ✅ `cart_sessions.user_id`: VARCHAR(36) - UUID
- ✅ `cart_items.product_id`: VARCHAR(36) - UUID
- ✅ `cart_items.warehouse_id`: VARCHAR(36) - UUID
- ✅ `orders.user_id`: VARCHAR(36) - UUID
- ✅ `order_items.product_id`: VARCHAR(36) - UUID
- ✅ `order_items.warehouse_id`: VARCHAR(36) - UUID
- ❌ `order_status_history.changed_by`: BIGINT (should be VARCHAR(36))

### Recommendations
1. **Migrate ChangedBy**: Update order_status_history.changed_by to VARCHAR(36)
2. **Consistent UUID Format**: Ensure all UUIDs use same format (lowercase, with dashes)

---

## 🎯 PERFORMANCE RECOMMENDATIONS

### Missing Indexes
1. **Cart**: Composite index on (user_id, expires_at) for cleanup
2. **Order**: Composite indexes for common query patterns
3. **Order Status History**: Composite index on (order_id, changed_at DESC)
4. **Order Payments**: Composite index on (order_id, status)

### Query Optimization
1. **Pagination**: Ensure all list queries use LIMIT/OFFSET with proper indexes
2. **Date Range Queries**: Use indexes on created_at, expires_at
3. **Status Filtering**: Use composite indexes with status

---

## ✅ SUMMARY OF RECOMMENDATIONS

### High Priority
1. ✅ Add CHECK constraints on status fields
2. ✅ Add foreign keys for address references
3. ✅ Add composite indexes for common queries
4. ✅ Fix ChangedBy type mismatch
5. ✅ Add price consistency constraints

### Medium Priority
1. ⚠️ Add validation constraints (country code, email)
2. ⚠️ Add partial unique indexes where needed
3. ⚠️ Consider soft deletes for orders
4. ⚠️ Add currency fields if multi-currency needed

### Low Priority
1. 📝 Consider order number generation pattern
2. 📝 Add stock_checked_at timestamp for cart items
3. 📝 Consider computed columns for price calculations

---

## 📚 Related Documentation

- [Order Service Logic](./ORDER_SERVICE_LOGIC.md)
- [Cart Service Logic](./CART_SERVICE_LOGIC.md)
- [Database Migration Guide](../MIGRATION_SCRIPT.md)

