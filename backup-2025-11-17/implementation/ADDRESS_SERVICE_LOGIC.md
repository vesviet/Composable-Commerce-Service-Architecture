# Address Service - Logic Implementation Review

> **Service**: Address Service (part of Customer Service)  
> **Last Updated**: December 2024  
> **Status**: Implementation Complete

---

## 📋 Overview

Address Service quản lý địa chỉ của customers, bao gồm shipping addresses và billing addresses. Service này cung cấp CRUD operations, address validation, và default address management.

---

## 🏗️ Architecture

### Service Structure
```
customer/
├── internal/
│   ├── biz/
│   │   └── address/
│   │       ├── address.go      # Address usecase
│   │       ├── cache.go        # Address caching
│   │       └── events.go       # Address events
│   ├── service/
│   │   └── address.go         # Address gRPC handlers
│   ├── data/
│   │   └── postgres/
│   │       └── address.go     # Address repository
│   └── model/
│       └── address.go         # Address domain model
```

### Key Features
- Address CRUD operations
- Address validation by country
- Default address management
- Address caching with Redis
- Address events publishing

---

## 🔄 Core Business Logic

### 1. Create Address Flow

**Location**: `customer/internal/biz/address/address.go:86`

**Flow**:
1. **Validate Required Fields** - CustomerID, AddressLine1, City, CountryCode
2. **Validate Country Code** - Check format (2 letters, ISO 3166-1 alpha-2)
3. **Validate Address by Country** - Country-specific validation (postal code, state, phone)
4. **Standardize Address** - Standardize city name, postal code format, uppercase country code
5. **Create Address Entity** - Type: shipping, billing, or both
6. **Save Address** - Use repository Create method
7. **Set Default Address** (if requested) - Publish AddressDefaultChanged event
8. **Cache Address** - Store in Redis cache
9. **Publish Events** - AddressCreated event
10. **Return Address**

---

### 2. Update Address Flow

**Location**: `customer/internal/biz/address/address.go:174`

**Flow**:
1. **Get Existing Address** - Find address by ID
2. **Track Changes** - Track which fields changed
3. **Update Fields** (if provided) - AddressLine1, City, CountryCode, FirstName, LastName, etc.
4. **Re-validate Address** (if country/postal code changed) - Validate new address format
5. **Standardize Updated Fields** - Standardize city, postal code
6. **Save Updated Address**
7. **Set Default Address** (if requested) - Publish AddressDefaultChanged event
8. **Invalidate Cache** - Remove old address, re-cache updated address
9. **Publish Events** - AddressUpdated event (if changes made)
10. **Return Updated Address**

---

### 3. Get Address Flow

**Location**: `customer/internal/biz/address/address.go:302`

**Flow**:
1. **Check Cache** - Try to get address from Redis cache
2. **Fetch from Database** - Get address by ID from repository
3. **Cache Address** - Store in Redis cache for future requests
4. **Return Address**

---

### 4. List Addresses Flow

**Location**: `customer/internal/biz/address/address.go:335`

**Flow**:
1. **Validate Pagination** - Limit must be > 0 and <= 100 (default: 20)
2. **Fetch Addresses** - Get all addresses for customer
3. **Apply Pagination** - Apply offset and limit
4. **Return Addresses and Total**

---

### 5. Default Address Management

**Location**: `customer/internal/biz/address/address.go:392`

**Flow**:
1. **Verify Address** - Check address exists and belongs to customer
2. **Get Old Default** - Track previous default address
3. **Set New Default** - Call repository SetDefaultAddress
4. **Invalidate Cache** - Invalidate customer addresses cache
5. **Publish Event** - AddressDefaultChanged event
6. **Return Success**

---

### 6. Delete Address Flow

**Location**: `customer/internal/biz/address/address.go:436`

**Flow**:
1. **Check Address Exists** - Get address by ID
2. **Validate Deletion** - Cannot delete if it's the only address for customer
3. **Handle Default Address** - If deleting default address, set another address as default
4. **Publish Event** - AddressDeleted event
5. **Delete Address** - Call repository DeleteByID
6. **Invalidate Cache** - Invalidate address cache and customer addresses cache
7. **Return Success**

---

## 📊 Domain Models

### Address Entity
```go
type Address struct {
    ID            uuid.UUID
    CustomerID    uuid.UUID
    Type          int32         // 1=shipping, 2=billing, 3=both
    FirstName     string
    LastName      string
    Company       string
    AddressLine1  string
    AddressLine2  string
    City          string
    StateProvince string
    PostalCode    string
    CountryCode   string        // ISO 3166-1 alpha-2
    Phone         string
    IsDefault     bool
    IsVerified    bool
    CreatedAt     time.Time
    UpdatedAt     time.Time
}
```

---

## 🔔 Events Published

### AddressCreated
- **Topic**: `address.created`
- **Payload**: AddressID, CustomerID, Address details, Timestamp

### AddressUpdated
- **Topic**: `address.updated`
- **Payload**: AddressID, CustomerID, Changed fields, Timestamp

### AddressDeleted
- **Topic**: `address.deleted`
- **Payload**: AddressID, CustomerID, Timestamp

### AddressDefaultChanged
- **Topic**: `address.default_changed`
- **Payload**: AddressID, CustomerID, NewDefaultAddress, OldDefaultAddress, Timestamp

---

## 🔐 Business Rules

### Address Types
- **shipping**: Shipping address only
- **billing**: Billing address only
- **both**: Both shipping and billing

### Address Validation by Country

#### Vietnam (VN)
- **Postal Code**: 6 digits
- **Phone**: Must start with +84 or 0

#### United States (US)
- **Postal Code**: 5 digits or 5+4 format (12345 or 12345-6789)
- **State**: 2-letter code

#### Other Countries
- **Postal Code**: Minimum 3 characters
- Basic validation

### Address Standardization
- **City**: Capitalize first letter of each word
- **Postal Code**: Format based on country
  - US: Format as 12345 or 12345-6789
  - VN: Ensure 6 digits
  - Others: Remove spaces and dashes
- **Country Code**: Uppercase

### Default Address
- Only one default address per customer
- Automatically set when creating first address
- Automatically reassigned when deleting default address

### Address Deletion
- Cannot delete if it's the only address for customer
- If deleting default address, automatically set another as default

---

## 🔗 Service Integration

### Customer Service
- **Authorization**: Customer can only manage their own addresses
- **Admin**: Admin can manage any customer's addresses

### Order Service
- **Consume**: Get customer addresses for order shipping
- **Use**: Default address for order creation

### Shipping Service
- **Consume**: Validate and use addresses for fulfillment

---

## 🚨 Error Handling

### Common Errors
- **Customer ID Required**: CustomerID is required
- **Address Line 1 Required**: AddressLine1 is required
- **City Required**: City is required
- **Country Code Required**: CountryCode is required
- **Invalid Country Code**: Country code format invalid
- **Address Validation Failed**: Address validation failed
- **Address Not Found**: Address doesn't exist
- **Cannot Delete Only Address**: Cannot delete the only address

### Error Scenarios
1. **Invalid Country Code**: Return error before validation
2. **Invalid Postal Code**: Return error with country-specific message
3. **Invalid Phone Number**: Return error with format requirements
4. **Address Not Found**: Return error when getting/updating/deleting
5. **Delete Only Address**: Return error, prevent deletion

---

## 📈 Caching Strategy

### Cache Keys
- **Address**: `address:{addressID}` - TTL: 30 minutes
- **Customer Addresses**: `customer:{customerID}:addresses` - TTL: 15 minutes

### Cache Operations
- **Set**: Cache address after create/update/get
- **Get**: Check cache before database query
- **Invalidate**: Invalidate on update/delete
- **Invalidate Customer**: Invalidate customer addresses on default change

---

## 📝 Notes & TODOs

### Completed Features
- ✅ Address CRUD operations
- ✅ Address validation by country
- ✅ Default address management
- ✅ Address caching
- ✅ Address events
- ✅ Address standardization

### Future Enhancements
1. **Address Verification**
   - Integration with address verification APIs
   - Verify address with postal service
   - Set IsVerified flag

2. **Address Suggestions**
   - Autocomplete address suggestions
   - Address validation API integration

3. **Address History**
   - Track address change history
   - Audit log for address changes

4. **Multi-Language Support**
   - Support for international address formats
   - Localized address validation

---

## 📚 Related Documentation

- [Address Reuse Solution](./ADDRESS_REUSE_SOLUTION.md)
- [Address Reuse Hybrid Checklist](./ADDRESS_REUSE_HYBRID_CHECKLIST.md)
- [Order Service Logic](./ORDER_SERVICE_LOGIC.md)
- [Shipping Service Logic](./SHIPPING_SERVICE_LOGIC.md)
