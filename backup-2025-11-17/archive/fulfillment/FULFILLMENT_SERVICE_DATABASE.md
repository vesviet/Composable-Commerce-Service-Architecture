# Fulfillment Service - Database Schema

> **Database:** PostgreSQL 15  
> **Schema Name:** fulfillment_db  
> **Status:** 🔴 Not Created

---

## Database Tables

### 1. fulfillments

**Purpose:** Main fulfillment records

```sql
CREATE TABLE fulfillments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    order_number VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    warehouse_id UUID,
    
    -- Tracking
    assigned_picker_id UUID,
    assigned_packer_id UUID,
    picklist_id UUID,
    package_id UUID,
    
    -- COD Support
    requires_cod_collection BOOLEAN DEFAULT FALSE,
    cod_amount DECIMAL(15,2),
    cod_currency VARCHAR(3) DEFAULT 'VND',
    
    -- Timestamps
    planned_at TIMESTAMP WITH TIME ZONE,
    picked_at TIMESTAMP WITH TIME ZONE,
    packed_at TIMESTAMP WITH TIME ZONE,
    ready_at TIMESTAMP WITH TIME ZONE,
    shipped_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT chk_fulfillment_status CHECK (
        status IN ('pending', 'planning', 'picking', 'picked', 'packing', 'packed', 'ready', 'shipped', 'completed', 'cancelled')
    )
);

-- Indexes
CREATE INDEX idx_fulfillments_order_id ON fulfillments(order_id);
CREATE INDEX idx_fulfillments_status ON fulfillments(status);
CREATE INDEX idx_fulfillments_warehouse_id ON fulfillments(warehouse_id);
CREATE INDEX idx_fulfillments_created_at ON fulfillments(created_at);
CREATE INDEX idx_fulfillments_picker ON fulfillments(assigned_picker_id) WHERE assigned_picker_id IS NOT NULL;
CREATE INDEX idx_fulfillments_packer ON fulfillments(assigned_packer_id) WHERE assigned_packer_id IS NOT NULL;

-- Comments
COMMENT ON TABLE fulfillments IS 'Main fulfillment records for order processing';
COMMENT ON COLUMN fulfillments.status IS 'pending, planning, picking, picked, packing, packed, ready, shipped, completed, cancelled';
```

---

### 2. fulfillment_items

**Purpose:** Items in each fulfillment

```sql
CREATE TABLE fulfillment_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
    order_item_id UUID NOT NULL,
    
    -- Product Info
    product_id UUID NOT NULL,
    product_sku VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    variant_id UUID,
    
    -- Quantities
    quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
    quantity_picked INT DEFAULT 0 CHECK (quantity_picked >= 0),
    quantity_packed INT DEFAULT 0 CHECK (quantity_packed >= 0),
    
    -- Location
    warehouse_location VARCHAR(50),
    bin_location VARCHAR(50),
    
    -- Pricing
    unit_price DECIMAL(15,2) NOT NULL,
    total_price DECIMAL(15,2) NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT chk_fulfillment_item_quantities CHECK (
        quantity_picked <= quantity_ordered AND
        quantity_packed <= quantity_picked
    )
);

-- Indexes
CREATE INDEX idx_fulfillment_items_fulfillment_id ON fulfillment_items(fulfillment_id);
CREATE INDEX idx_fulfillment_items_product_id ON fulfillment_items(product_id);
CREATE INDEX idx_fulfillment_items_sku ON fulfillment_items(product_sku);
CREATE INDEX idx_fulfillment_items_order_item ON fulfillment_items(order_item_id);

-- Comments
COMMENT ON TABLE fulfillment_items IS 'Items to be fulfilled in each fulfillment';
```

---

### 3. picklists

**Purpose:** Picking instructions for warehouse staff

```sql
CREATE TABLE picklists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
    picklist_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- Assignment
    warehouse_id UUID NOT NULL,
    assigned_to UUID,
    assigned_at TIMESTAMP WITH TIME ZONE,
    
    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    priority INT DEFAULT 0,
    
    -- Tracking
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Items (denormalized for quick access)
    total_items INT NOT NULL DEFAULT 0,
    picked_items INT DEFAULT 0,
    
    -- Metadata
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT chk_picklist_status CHECK (
        status IN ('pending', 'assigned', 'in_progress', 'completed', 'cancelled')
    ),
    CONSTRAINT chk_picklist_items CHECK (picked_items <= total_items)
);

-- Indexes
CREATE UNIQUE INDEX idx_picklists_number ON picklists(picklist_number);
CREATE INDEX idx_picklists_fulfillment_id ON picklists(fulfillment_id);
CREATE INDEX idx_picklists_warehouse_id ON picklists(warehouse_id);
CREATE INDEX idx_picklists_assigned_to ON picklists(assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX idx_picklists_status ON picklists(status);
CREATE INDEX idx_picklists_priority ON picklists(priority DESC, created_at ASC);

-- Comments
COMMENT ON TABLE picklists IS 'Picking instructions for warehouse staff';
COMMENT ON COLUMN picklists.priority IS 'Higher number = higher priority';
```

---

### 4. picklist_items

**Purpose:** Individual items in picklist with location info

```sql
CREATE TABLE picklist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    picklist_id UUID NOT NULL REFERENCES picklists(id) ON DELETE CASCADE,
    fulfillment_item_id UUID NOT NULL REFERENCES fulfillment_items(id),
    
    -- Product Info
    product_id UUID NOT NULL,
    product_sku VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    
    -- Picking Info
    quantity_to_pick INT NOT NULL CHECK (quantity_to_pick > 0),
    quantity_picked INT DEFAULT 0 CHECK (quantity_picked >= 0),
    
    -- Location
    warehouse_location VARCHAR(50) NOT NULL,
    bin_location VARCHAR(50),
    aisle VARCHAR(10),
    shelf VARCHAR(10),
    
    -- Tracking
    picked_by UUID,
    picked_at TIMESTAMP WITH TIME ZONE,
    
    -- Sequence (for optimized picking route)
    pick_sequence INT,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT chk_picklist_item_quantity CHECK (quantity_picked <= quantity_to_pick)
);

-- Indexes
CREATE INDEX idx_picklist_items_picklist_id ON picklist_items(picklist_id);
CREATE INDEX idx_picklist_items_fulfillment_item ON picklist_items(fulfillment_item_id);
CREATE INDEX idx_picklist_items_product ON picklist_items(product_id);
CREATE INDEX idx_picklist_items_location ON picklist_items(warehouse_location, bin_location);
CREATE INDEX idx_picklist_items_sequence ON picklist_items(picklist_id, pick_sequence);

-- Comments
COMMENT ON TABLE picklist_items IS 'Individual items in picklist with warehouse location';
COMMENT ON COLUMN picklist_items.pick_sequence IS 'Optimized picking order';
```

---

### 5. packages

**Purpose:** Packed packages ready for shipping

```sql
CREATE TABLE packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
    package_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- Package Info
    package_type VARCHAR(50) DEFAULT 'box',
    weight_kg DECIMAL(10,3) NOT NULL CHECK (weight_kg > 0),
    length_cm DECIMAL(10,2) NOT NULL CHECK (length_cm > 0),
    width_cm DECIMAL(10,2) NOT NULL CHECK (width_cm > 0),
    height_cm DECIMAL(10,2) NOT NULL CHECK (height_cm > 0),
    
    -- Packing Info
    packed_by UUID NOT NULL,
    packed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Items count
    total_items INT NOT NULL DEFAULT 0,
    
    -- Shipping
    shipping_label_url TEXT,
    tracking_number VARCHAR(100),
    
    -- Metadata
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT chk_package_dimensions CHECK (
        length_cm > 0 AND width_cm > 0 AND height_cm > 0
    )
);

-- Indexes
CREATE UNIQUE INDEX idx_packages_number ON packages(package_number);
CREATE INDEX idx_packages_fulfillment_id ON packages(fulfillment_id);
CREATE INDEX idx_packages_packed_by ON packages(packed_by);
CREATE INDEX idx_packages_tracking ON packages(tracking_number) WHERE tracking_number IS NOT NULL;

-- Comments
COMMENT ON TABLE packages IS 'Packed packages ready for shipping';
```

---

### 6. fulfillment_status_history

**Purpose:** Track status changes for audit trail

```sql
CREATE TABLE fulfillment_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fulfillment_id UUID NOT NULL REFERENCES fulfillments(id) ON DELETE CASCADE,
    
    -- Status Change
    from_status VARCHAR(20),
    to_status VARCHAR(20) NOT NULL,
    
    -- Who & When
    changed_by UUID,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Reason
    reason VARCHAR(255),
    notes TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_fulfillment_status_history_fulfillment ON fulfillment_status_history(fulfillment_id);
CREATE INDEX idx_fulfillment_status_history_changed_at ON fulfillment_status_history(changed_at);

-- Comments
COMMENT ON TABLE fulfillment_status_history IS 'Audit trail for fulfillment status changes';
```

---

## Migration Files

### migrations/001_create_fulfillments_table.sql
```sql
-- See fulfillments table above
```

### migrations/002_create_fulfillment_items_table.sql
```sql
-- See fulfillment_items table above
```

### migrations/003_create_picklists_table.sql
```sql
-- See picklists and picklist_items tables above
```

### migrations/004_create_packages_table.sql
```sql
-- See packages table above
```

### migrations/005_create_status_history_table.sql
```sql
-- See fulfillment_status_history table above
```

### migrations/006_create_indexes.sql
```sql
-- Additional composite indexes for performance
CREATE INDEX idx_fulfillments_warehouse_status ON fulfillments(warehouse_id, status);
CREATE INDEX idx_picklists_warehouse_status ON picklists(warehouse_id, status);
CREATE INDEX idx_fulfillment_items_fulfillment_product ON fulfillment_items(fulfillment_id, product_id);
```

---

## Database Initialization

Add to `source/scripts/init-db.sql`:

```sql
-- Create fulfillment database
CREATE DATABASE fulfillment_db;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE fulfillment_db TO ecommerce_user;

-- Connect to fulfillment_db
\c fulfillment_db

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

---

## Summary

**Tables:** 6 main tables
- fulfillments (main records)
- fulfillment_items (order items)
- picklists (picking instructions)
- picklist_items (items to pick)
- packages (packed packages)
- fulfillment_status_history (audit trail)

**Total Indexes:** ~30 indexes for performance
**Constraints:** Foreign keys, check constraints, unique constraints
**Features:** UUID primary keys, JSONB metadata, soft deletes, audit trail
