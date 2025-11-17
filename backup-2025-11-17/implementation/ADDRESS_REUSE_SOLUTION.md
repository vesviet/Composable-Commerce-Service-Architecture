# Address Interface Reuse Solution

> **Problem**: Order Service và Customer Service đều có address structure riêng, có thể reuse không?  
> **Solution**: Shared Common Address Proto + Service Reference Pattern  
> **Status**: ✅ **Implemented** (See [ADDRESS_REUSE_HYBRID_CHECKLIST.md](./ADDRESS_REUSE_HYBRID_CHECKLIST.md))  
> **Last Updated**: December 2024

---

## 📋 Problem Statement

### Current Situation

**Customer Service Address**:
- Uses local `Address` message
- String type field ("shipping", "billing", "both")
- String ID (UUID)

**Order Service Address**:
- Uses `OrderAddress` message
- Different field naming (`address_line1` vs `address_line_1`)
- Enum type field
- Int64 ID

### Key Differences
1. **Field Naming**: Inconsistent naming conventions
2. **Type Definition**: String vs enum
3. **ID Type**: String (UUID) vs int64
4. **Extra/Missing Fields**: Different field sets

---

## 🎯 Solution Options

### Option 1: Shared Common Proto ⭐

**Approach**: Create shared address proto in `common/proto/v1/address.proto`

**Benefits**:
- ✅ Single source of truth
- ✅ Consistent structure across services
- ✅ Easy to maintain and update
- ✅ Type-safe with protobuf

**Implementation**:
```protobuf
// common/proto/v1/address.proto
syntax = "proto3";
package api.common.v1;

message Address {
  string id = 1;
  AddressType type = 2;
  string first_name = 3;
  string last_name = 4;
  string company = 5;
  string address_line_1 = 6;
  string address_line_2 = 7;
  string city = 8;
  string state_province = 9;
  string postal_code = 10;
  string country_code = 11;
  string phone = 12;
  string email = 13;
  bool is_default = 14;
  bool is_verified = 15;
  google.protobuf.Timestamp created_at = 16;
  google.protobuf.Timestamp updated_at = 17;
  map<string, string> metadata = 18;
}

enum AddressType {
  ADDRESS_TYPE_UNSPECIFIED = 0;
  ADDRESS_TYPE_SHIPPING = 1;
  ADDRESS_TYPE_BILLING = 2;
  ADDRESS_TYPE_BOTH = 3;
}
```

---

### Option 2: Service Reference Pattern

**Approach**: Order Service references Customer Address ID instead of copying data

**Benefits**:
- ✅ No data duplication
- ✅ Always up-to-date address
- ✅ Smaller order payload

**Drawbacks**:
- ❌ Order address becomes stale if customer updates address
- ❌ Requires Customer Service availability
- ❌ More complex queries

---

### Option 3: Hybrid Approach (Recommended) ⭐⭐

**Approach**: 
- Use common Address proto for API consistency
- Store snapshot in order_addresses table (immutable)
- Optionally reference customer address ID

**Benefits**:
- ✅ Immutable order addresses (snapshot at order time)
- ✅ Consistent API structure
- ✅ Can reference customer address for convenience
- ✅ Works offline (no dependency on Customer Service)

**Implementation**:
```protobuf
// order/api/order/v1/order.proto
import "gitlab.com/ta-microservices/common/proto/v1/address.proto";

message Order {
  // ...
  api.common.v1.Address shipping_address = 7;  // Snapshot at order time
  api.common.v1.Address billing_address = 8;
  string customer_shipping_address_id = 9;     // Optional: reference to customer address
  string customer_billing_address_id = 10;
}
```

**Database Schema**:
```sql
-- Keep order_addresses table for snapshot
CREATE TABLE order_addresses (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    customer_address_id VARCHAR(36),  -- NEW: Reference to customer address (optional)
    type VARCHAR(20) NOT NULL,
    -- Snapshot fields (immutable)
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    -- ... other fields
);
```

---

## 🏗️ Recommended Solution: Hybrid Approach

### Why Hybrid?

1. **Order Address Immutability**: Orders need snapshot of address at order time
   - Customer can update address after order
   - Order should show address used at time of order
   - Legal/compliance requirement

2. **Customer Address Mutability**: Customer addresses can change
   - Customer can update default address
   - Address validation can change
   - Address verification status can change

3. **Best of Both Worlds**:
   - Common proto for API consistency
   - Snapshot for order immutability
   - Optional reference for convenience

### Implementation Benefits

- ✅ **API Consistency**: All services use same Address proto
- ✅ **Data Integrity**: Order addresses are immutable snapshots
- ✅ **Flexibility**: Can reference customer address or use custom address
- ✅ **Performance**: No need to fetch from Customer Service for order display
- ✅ **Offline Support**: Order data is self-contained

---

## 📊 Comparison

| Aspect | Option 1: Common Proto | Option 2: Reference | Option 3: Hybrid |
|--------|----------------------|-------------------|------------------|
| **Consistency** | ✅ High | ⚠️ Medium | ✅ High |
| **Data Duplication** | ⚠️ Yes | ✅ No | ⚠️ Yes (snapshot) |
| **Immutability** | ✅ Yes | ❌ No | ✅ Yes |
| **Service Dependency** | ✅ None | ❌ High | ✅ Low |
| **Complexity** | ✅ Low | ⚠️ Medium | ⚠️ Medium |
| **Performance** | ✅ Fast | ⚠️ Slower | ✅ Fast |
| **Best For** | All services | Simple cases | Orders |

---

## 🔄 Migration Strategy

### Phase 1: Add Common Proto (Non-Breaking)
1. Create `common/proto/v1/address.proto`
2. Generate Go code
3. Keep existing Address messages (for backward compatibility)

### Phase 2: Update Customer Service
1. Import common Address proto
2. Add conversion functions
3. Update service methods to use common Address
4. Keep backward compatibility with old Address message

### Phase 3: Update Order Service
1. Import common Address proto
2. Update Order proto to use common Address
3. Add customer_address_id reference
4. Update conversion functions

### Phase 4: Database Migration
1. Add `customer_address_id` column to `order_addresses`
2. Backfill existing orders (if possible)
3. Add indexes

### Phase 5: Remove Old Messages (Breaking)
1. Remove old Address/OrderAddress messages
2. Update all clients
3. Remove conversion functions

---

## 📚 Related Documentation

- [Address Reuse Hybrid Checklist](./ADDRESS_REUSE_HYBRID_CHECKLIST.md) - Implementation checklist
- [Address Service Logic](./ADDRESS_SERVICE_LOGIC.md) - Address service implementation details
- [Order Service Logic](./ORDER_SERVICE_LOGIC.md) - Order service implementation details
- [Cart & Order Data Structure Review](./CART_ORDER_DATA_STRUCTURE_REVIEW.md) - Data structure analysis
