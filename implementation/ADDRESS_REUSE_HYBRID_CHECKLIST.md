# Address Reuse - Hybrid Approach Implementation Checklist

> **Solution**: Hybrid Approach - Common Address Proto + Snapshot Pattern  
> **Status**: ✅ **Implementation Completed** (Phase 1-5 done, Phase 6 Deployment pending)  
> **Last Updated**: December 2024

---

## 📋 Overview

Checklist để implement Hybrid Approach cho address reuse giữa Customer Service và Order Service.

**Goal**: 
- ✅ Shared common Address proto
- ✅ Order addresses là immutable snapshots
- ✅ Optional customer address reference

---

## 📊 Progress Tracking

### Overall Progress: **~90%** (Implementation Complete, Deployment Pending)

**Phase 1: Common Package Setup** - ✅ **4/4 tasks (100%)**
- [x] 1.1. Create Common Address Proto
- [x] 1.2. Generate Proto Code
- [x] 1.3. Create Conversion Utilities
- [x] 1.4. Update Common Package Dependencies

**Phase 2: Customer Service Updates** - ✅ **5/5 tasks (100%)**
- [x] 2.1. Update Customer Proto
- [x] 2.2. Regenerate Customer Proto Code
- [x] 2.3. Update Customer Service Layer
- [x] 2.4. Update Customer Business Logic
- [x] 2.5. Update Customer Tests

**Phase 3: Order Service Updates** - ✅ **8/8 tasks (100%)**
- [x] 3.1. Update Order Proto
- [x] 3.2. Regenerate Order Proto Code
- [x] 3.3. Update Database Schema
- [x] 3.4. Update Order Model
- [x] 3.5. Update Order Service Layer
- [x] 3.6. Update Order Business Logic
- [x] 3.7. Add Customer Service Client
- [x] 3.8. Update Order Tests

**Phase 4: Frontend Updates** - ✅ **5/5 tasks (100%)**
- [x] 4.1. Update TypeScript Types
- [x] 4.2. Update API Clients
- [x] 4.3. Update Checkout Forms
- [x] 4.4. Update Order Display
- [x] 4.5. Update Order Detail Page

**Phase 5: Testing & Validation** - ✅ **4/4 tasks (100%)**
- [x] 5.1. Integration Testing (Documentation & Scripts)
- [x] 5.2. End-to-End Testing (Documentation)
- [x] 5.3. Performance Testing (Documentation)
- [x] 5.4. Manual Testing Checklist

**Phase 6: Deployment** - ⏳ **0/4 tasks (0%) - Pending**
- [ ] 6.1. Pre-Deployment Checklist
- [ ] 6.2. Database Migration
- [ ] 6.3. Service Deployment
- [ ] 6.4. Post-Deployment Validation

---

## 🚀 Phase 6: Deployment (Pending)

### 6.1. Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Code review completed
- [ ] Documentation updated
- [ ] Migration scripts tested
- [ ] Rollback plan prepared

**Estimated Time**: 2 hours

---

### 6.2. Database Migration

#### Migration Script
**File**: `order/migrations/010_add_customer_address_reference.sql`

**Changes**:
- Add `customer_address_id VARCHAR(36)` column to `order_addresses` table
- Create index `idx_order_addresses_customer_address_id` for faster lookups
- Column is optional (nullable) - existing orders will have NULL
- Address data is still stored as snapshot (immutable)

**Migration Content**:
```sql
-- +goose Up
ALTER TABLE order_addresses 
    ADD COLUMN IF NOT EXISTS customer_address_id VARCHAR(36);

CREATE INDEX IF NOT EXISTS idx_order_addresses_customer_address_id 
    ON order_addresses(customer_address_id);

COMMENT ON COLUMN order_addresses.customer_address_id IS 
    'Optional reference to customer address ID from customer service. Address data is still stored as snapshot.';

-- +goose Down
DROP INDEX IF EXISTS idx_order_addresses_customer_address_id;
ALTER TABLE order_addresses 
    DROP COLUMN IF EXISTS customer_address_id;
```

#### Pre-Migration Checklist
- [ ] Backup database (full backup before migration)
- [ ] Verify database connection
- [ ] Check current migration version
- [ ] Review migration script
- [ ] Test migration on local/dev environment
- [ ] Prepare rollback plan

#### Migration Steps

**1. Staging Environment**
```bash
# Navigate to order service
cd order

# Check current migration status
make migrate-status DATABASE_URL="postgres://user:pass@staging-host:5432/order_db?sslmode=disable"

# Run migration
make migrate-up DATABASE_URL="postgres://user:pass@staging-host:5432/order_db?sslmode=disable"

# Verify migration
make migrate-status DATABASE_URL="postgres://user:pass@staging-host:5432/order_db?sslmode=disable"
```

**2. Verify Migration Success**
```sql
-- Check column exists
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'order_addresses' 
AND column_name = 'customer_address_id';

-- Check index exists
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'order_addresses' 
AND indexname = 'idx_order_addresses_customer_address_id';

-- Verify existing data (should show NULL for old orders)
SELECT COUNT(*) as total_addresses,
       COUNT(customer_address_id) as with_reference,
       COUNT(*) - COUNT(customer_address_id) as without_reference
FROM order_addresses;
```

**3. Test on Staging**
- [ ] Create new order with customer address ID
- [ ] Verify `customer_address_id` is saved correctly
- [ ] Create new order with custom address (no customer address ID)
- [ ] Verify existing orders still work (customer_address_id is NULL)
- [ ] Test order retrieval and display
- [ ] Verify address snapshot is still stored

**4. Production Migration**
```bash
# Schedule maintenance window (if needed)
# Run during low-traffic period

# Check current migration status
make migrate-status DATABASE_URL="postgres://user:pass@prod-host:5432/order_db?sslmode=disable"

# Run migration
make migrate-up DATABASE_URL="postgres://user:pass@prod-host:5432/order_db?sslmode=disable"

# Verify migration
make migrate-status DATABASE_URL="postgres://user:pass@prod-host:5432/order_db?sslmode=disable"
```

**5. Post-Migration Verification**
- [ ] Verify column and index created successfully
- [ ] Check application logs for errors
- [ ] Monitor database performance
- [ ] Test order creation with customer address ID
- [ ] Test order creation with custom address
- [ ] Verify existing orders still accessible
- [ ] Monitor for 24 hours

#### Rollback Plan

**If Migration Fails**:
```bash
# Rollback last migration
make migrate-down DATABASE_URL="postgres://user:pass@host:5432/order_db?sslmode=disable"

# Verify rollback
make migrate-status DATABASE_URL="postgres://user:pass@host:5432/order_db?sslmode=disable"
```

**Rollback Verification**:
```sql
-- Verify column removed
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'order_addresses' 
AND column_name = 'customer_address_id';
-- Should return 0 rows

-- Verify index removed
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'order_addresses' 
AND indexname = 'idx_order_addresses_customer_address_id';
-- Should return 0 rows
```

**Note**: Rollback is safe - column is optional and nullable, so removing it won't affect existing data.

#### Backfill Strategy (Optional)

**If you want to backfill existing orders**:
```sql
-- This is optional - only if you have customer address IDs for existing orders
-- Most existing orders will have NULL customer_address_id (which is fine)

-- Example backfill (customize based on your data):
-- UPDATE order_addresses oa
-- SET customer_address_id = (
--     SELECT ca.id::text 
--     FROM customer_addresses ca
--     WHERE ca.customer_id::text = oa.order_id::text 
--     AND ca.is_default = true
--     LIMIT 1
-- )
-- WHERE oa.customer_address_id IS NULL
-- AND EXISTS (
--     SELECT 1 FROM customer_addresses ca 
--     WHERE ca.customer_id::text = oa.order_id::text
-- );
```

**Estimated Time**: 
- Pre-migration: 30 minutes
- Migration execution: 5-10 minutes
- Verification: 30 minutes
- Monitoring: 2 hours
- **Total**: ~3 hours

---

### 6.3. Service Deployment
- [ ] Deploy Common package first
- [ ] Deploy Customer Service
- [ ] Deploy Order Service
- [ ] Deploy Frontend
- [ ] Monitor services
- [ ] Verify functionality

**Estimated Time**: 2 hours

---

### 6.4. Post-Deployment Validation
- [ ] Verify address CRUD works
- [ ] Verify order creation works
- [ ] Verify checkout flow works
- [ ] Check error logs
- [ ] Monitor metrics
- [ ] Verify backward compatibility

**Estimated Time**: 2 hours

---

## 🔗 Dependencies

### Service Dependencies
- Common package must be deployed first
- Customer Service updates before Order Service
- Order Service updates before Frontend

### External Dependencies
- Proto compiler (buf/protoc)
- Go 1.21+
- PostgreSQL migration tools

---

## 📝 Notes

### Backward Compatibility
- Keep old Address/OrderAddress messages deprecated
- Support both old and new formats during transition
- Remove old messages after all clients updated

### Migration Strategy
- Deploy in phases
- Test thoroughly at each phase
- Have rollback plan ready
- Monitor closely after deployment

### Testing Strategy
- Unit tests for all conversion functions
- Integration tests for service interactions
- E2E tests for complete flows
- Performance tests for address fetching

---

## 📚 Related Documentation

- [Address Reuse Solution](./ADDRESS_REUSE_SOLUTION.md)
- [Address Service Logic](./ADDRESS_SERVICE_LOGIC.md)
- [Order Service Logic](./ORDER_SERVICE_LOGIC.md)
- [Cart & Order Data Structure Review](./CART_ORDER_DATA_STRUCTURE_REVIEW.md)
