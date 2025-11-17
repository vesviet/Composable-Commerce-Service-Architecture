# Testing Guide: Address Reuse Hybrid Approach

This guide provides comprehensive testing procedures for the Address Reuse Hybrid Approach implementation.

## 📋 Table of Contents

1. [Integration Testing](#integration-testing)
2. [End-to-End Testing](#end-to-end-testing)
3. [Manual Testing Checklist](#manual-testing-checklist)
4. [Performance Testing](#performance-testing)
5. [Test Scenarios](#test-scenarios)

---

## 🔗 Integration Testing

### 5.1. Customer Service Address CRUD

#### Test 1: Create Address
```bash
# Test creating a new address
curl -X POST http://localhost:8080/api/customer/v1/customers/{customerId}/addresses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "type": "ADDRESS_TYPE_SHIPPING",
    "first_name": "John",
    "last_name": "Doe",
    "address_line_1": "123 Main St",
    "city": "New York",
    "state_province": "NY",
    "postal_code": "10001",
    "country_code": "US",
    "phone": "123-456-7890",
    "is_default": true
  }'

# Expected: 200 OK with address containing common.Address format
# Verify: Address has all fields, type is ADDRESS_TYPE_SHIPPING
```

#### Test 2: Get Customer Addresses
```bash
# Test getting all addresses for a customer
curl -X GET http://localhost:8080/api/customer/v1/customers/{customerId}/addresses \
  -H "Authorization: Bearer {token}"

# Expected: 200 OK with array of common.Address
# Verify: All addresses returned in common.Address format
```

#### Test 3: Update Address
```bash
# Test updating an address
curl -X PUT http://localhost:8080/api/customer/v1/customers/{customerId}/addresses/{addressId} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "first_name": "Jane",
    "last_name": "Smith",
    "address_line_1": "456 Oak Ave"
  }'

# Expected: 200 OK with updated address
# Verify: Address updated, still in common.Address format
```

#### Test 4: Set Default Address
```bash
# Test setting default address
curl -X POST http://localhost:8080/api/customer/v1/customers/{customerId}/addresses/{addressId}/set-default \
  -H "Authorization: Bearer {token}"

# Expected: 200 OK
# Verify: Address is_default = true, other addresses is_default = false
```

#### Test 5: Delete Address
```bash
# Test deleting an address
curl -X DELETE http://localhost:8080/api/customer/v1/customers/{customerId}/addresses/{addressId} \
  -H "Authorization: Bearer {token}"

# Expected: 200 OK
# Verify: Address deleted from database
```

### 5.2. Order Service with Customer Address ID

#### Test 1: Create Order with Customer Address ID
```bash
# Test creating order with customer shipping address ID
curl -X POST http://localhost:8080/api/order/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "user_id": "{customerId}",
    "items": [
      {
        "product_id": "{productId}",
        "product_sku": "SKU-001",
        "quantity": 2
      }
    ],
    "customer_shipping_address_id": "{customerAddressId}",
    "customer_billing_address_id": "{customerAddressId}",
    "payment_method": "credit_card"
  }'

# Expected: 200 OK with order
# Verify: 
# - Order created successfully
# - Shipping address contains full snapshot data
# - Billing address contains full snapshot data
# - order_addresses.customer_address_id is set
# - Address data matches customer address from Customer Service
```

#### Test 2: Create Order with Custom Address
```bash
# Test creating order with custom address (no customer address ID)
curl -X POST http://localhost:8080/api/order/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "user_id": "{customerId}",
    "items": [
      {
        "product_id": "{productId}",
        "product_sku": "SKU-001",
        "quantity": 1
      }
    ],
    "shipping_address": {
      "type": "ADDRESS_TYPE_SHIPPING",
      "first_name": "Guest",
      "last_name": "User",
      "address_line_1": "789 Guest St",
      "city": "Los Angeles",
      "state_province": "CA",
      "postal_code": "90001",
      "country_code": "US"
    },
    "payment_method": "credit_card"
  }'

# Expected: 200 OK with order
# Verify:
# - Order created successfully
# - Shipping address contains provided data
# - order_addresses.customer_address_id is NULL
```

#### Test 3: Create Order with Mixed Addresses
```bash
# Test creating order with customer shipping address ID but custom billing address
curl -X POST http://localhost:8080/api/order/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "user_id": "{customerId}",
    "items": [{"product_id": "{productId}", "quantity": 1}],
    "customer_shipping_address_id": "{customerAddressId}",
    "billing_address": {
      "type": "ADDRESS_TYPE_BILLING",
      "first_name": "Different",
      "last_name": "Billing",
      "address_line_1": "999 Billing Ave",
      "city": "Chicago",
      "state_province": "IL",
      "postal_code": "60601",
      "country_code": "US"
    },
    "payment_method": "credit_card"
  }'

# Expected: 200 OK
# Verify:
# - Shipping address has customer_address_id set
# - Billing address has customer_address_id = NULL
# - Both addresses are snapshotted correctly
```

### 5.3. Address Snapshot Verification

#### Test: Verify Address Snapshot After Customer Address Update
```bash
# Step 1: Create order with customer address ID
# Step 2: Update customer address in Customer Service
# Step 3: Verify order address remains unchanged

# 1. Create order
ORDER_ID=$(curl -X POST ... | jq -r '.order.id')

# 2. Update customer address
curl -X PUT http://localhost:8080/api/customer/v1/customers/{customerId}/addresses/{addressId} \
  -d '{"address_line_1": "UPDATED ADDRESS"}'

# 3. Get order and verify address
curl -X GET http://localhost:8080/api/order/v1/orders/{ORDER_ID}

# Expected: Order address still has old address_line_1
# Verify: Address snapshot is immutable
```

### 5.4. Address Conversion Testing

#### Test: Verify Common Address Proto Conversion
```bash
# Test that Customer Service returns common.Address format
curl -X GET http://localhost:8080/api/customer/v1/customers/{customerId}/addresses

# Verify response structure:
# {
#   "addresses": [
#     {
#       "id": "uuid",
#       "type": "ADDRESS_TYPE_SHIPPING",
#       "first_name": "...",
#       "last_name": "...",
#       "address_line_1": "...",
#       ...
#     }
#   ]
# }

# Test that Order Service accepts common.Address format
# (Already tested in order creation tests above)
```

### 5.5. Backward Compatibility Testing

#### Test: Verify Old API Still Works
```bash
# Test that existing order creation without customer_address_id still works
# (This should work as customer_address_id is optional)
```

---

## 🎯 End-to-End Testing

### E2E Test 1: Checkout Flow with Saved Address

**Steps:**
1. Login as customer
2. Add items to cart
3. Go to checkout
4. Select "Use Saved Address"
5. Choose a saved address
6. Continue to payment
7. Place order
8. Verify order created with customer_address_id

**Expected Results:**
- ✅ Address selector shows saved addresses
- ✅ Selected address is used
- ✅ Order created successfully
- ✅ Order detail shows "From Saved Address" badge
- ✅ Order address has customer_address_id reference

### E2E Test 2: Checkout Flow with Custom Address

**Steps:**
1. Login as customer
2. Add items to cart
3. Go to checkout
4. Select "Enter New Address"
5. Fill in address form
6. Continue to payment
7. Place order
8. Verify order created without customer_address_id

**Expected Results:**
- ✅ Address form displays correctly
- ✅ Form validation works
- ✅ Order created successfully
- ✅ Order detail shows address without "From Saved Address" badge
- ✅ Order address has customer_address_id = NULL

### E2E Test 3: Guest Checkout

**Steps:**
1. Add items to cart (as guest)
2. Go to checkout
3. Fill in address form (no saved addresses available)
4. Continue to payment
5. Place order

**Expected Results:**
- ✅ Address form displays (no saved address option)
- ✅ Order created successfully
- ✅ Order address has customer_address_id = NULL

### E2E Test 4: Address Update After Order

**Steps:**
1. Create order with customer address ID
2. Update customer address in Customer Service
3. View order detail
4. Verify order address unchanged

**Expected Results:**
- ✅ Customer address updated successfully
- ✅ Order address remains unchanged (snapshot)
- ✅ Order detail still shows old address

---

## ✅ Manual Testing Checklist

### Customer Service

- [ ] **Create Address**
  - [ ] Create shipping address
  - [ ] Create billing address
  - [ ] Create both type address
  - [ ] Set as default address
  - [ ] Verify address returned in common.Address format

- [ ] **Get Addresses**
  - [ ] Get all addresses for customer
  - [ ] Verify addresses in common.Address format
  - [ ] Verify default address flag

- [ ] **Update Address**
  - [ ] Update address fields
  - [ ] Change default address
  - [ ] Verify update successful

- [ ] **Delete Address**
  - [ ] Delete address
  - [ ] Verify deletion successful
  - [ ] Verify cannot delete if used in orders (if business rule exists)

### Order Service

- [ ] **Create Order with Customer Address ID**
  - [ ] Create order with customer_shipping_address_id
  - [ ] Create order with customer_billing_address_id
  - [ ] Create order with both customer address IDs
  - [ ] Verify address data fetched from Customer Service
  - [ ] Verify address snapshot created in order_addresses
  - [ ] Verify customer_address_id stored in order_addresses

- [ ] **Create Order with Custom Address**
  - [ ] Create order with shipping_address (no customer_address_id)
  - [ ] Create order with billing_address (no customer_address_id)
  - [ ] Verify address snapshot created
  - [ ] Verify customer_address_id is NULL

- [ ] **Get Order**
  - [ ] Get order by ID
  - [ ] Verify shipping address returned
  - [ ] Verify billing address returned
  - [ ] Verify customer_address_id in response (if exposed)

### Frontend

- [ ] **Checkout Page**
  - [ ] Address selector shows saved addresses (if logged in)
  - [ ] Can toggle between "Use Saved Address" and "Enter New Address"
  - [ ] Can select saved address
  - [ ] Can enter custom address
  - [ ] Form validation works
  - [ ] Order created successfully

- [ ] **Order Detail Page**
  - [ ] Order detail displays correctly
  - [ ] Address information displayed
  - [ ] "From Saved Address" badge shows when customer_address_id exists
  - [ ] Address snapshot displayed correctly

- [ ] **Customer Address Management** (if implemented)
  - [ ] Can view addresses
  - [ ] Can create new address
  - [ ] Can update address
  - [ ] Can delete address
  - [ ] Can set default address

---

## ⚡ Performance Testing

### Test 1: Address Fetching Performance
```bash
# Test fetching addresses for customer with many addresses
# Measure response time for:
# - 10 addresses
# - 100 addresses
# - 1000 addresses

# Expected: Response time < 100ms for 100 addresses
```

### Test 2: Order Creation Performance
```bash
# Test order creation with customer address ID
# Measure time for:
# - Fetching customer address
# - Creating order
# - Total time

# Expected: Total time < 500ms
```

### Test 3: Database Query Performance
```sql
-- Test query performance for order_addresses with customer_address_id
EXPLAIN ANALYZE
SELECT * FROM order_addresses 
WHERE customer_address_id = '...';

-- Verify index is used
-- Expected: Index scan, not sequential scan
```

---

## 🧪 Test Scenarios

### Scenario 1: Happy Path - Saved Address
**Given:** Customer has saved addresses  
**When:** Customer creates order using saved address  
**Then:** 
- Order created with customer_address_id
- Address snapshot created
- Order detail shows "From Saved Address" badge

### Scenario 2: Happy Path - Custom Address
**Given:** Customer is at checkout  
**When:** Customer enters new address  
**Then:**
- Order created without customer_address_id
- Address snapshot created
- Order detail shows address without badge

### Scenario 3: Customer Address Update
**Given:** Order exists with customer_address_id  
**When:** Customer updates address in Customer Service  
**Then:**
- Customer address updated
- Order address unchanged (snapshot)

### Scenario 4: Customer Address Deletion
**Given:** Order exists with customer_address_id  
**When:** Customer deletes address from Customer Service  
**Then:**
- Customer address deleted
- Order address still exists (snapshot)
- Order detail still shows address

### Scenario 5: Customer Service Unavailable
**Given:** Order creation with customer_address_id  
**When:** Customer Service is down  
**Then:**
- Order creation fails gracefully OR
- Order created with provided address (if fallback implemented)
- Error logged

---

## 📊 Test Results Template

```
Test Date: __________
Tester: __________
Environment: __________

### Customer Service Tests
- [ ] Create Address: PASS / FAIL
- [ ] Get Addresses: PASS / FAIL
- [ ] Update Address: PASS / FAIL
- [ ] Delete Address: PASS / FAIL

### Order Service Tests
- [ ] Create Order with Customer Address ID: PASS / FAIL
- [ ] Create Order with Custom Address: PASS / FAIL
- [ ] Get Order: PASS / FAIL

### Frontend Tests
- [ ] Checkout with Saved Address: PASS / FAIL
- [ ] Checkout with Custom Address: PASS / FAIL
- [ ] Order Detail Display: PASS / FAIL

### Performance Tests
- [ ] Address Fetching: PASS / FAIL (Time: ___ms)
- [ ] Order Creation: PASS / FAIL (Time: ___ms)

### Issues Found
1. __________
2. __________
```

---

## 🔍 Debugging Tips

### Issue: Customer Address Not Fetched
- Check Customer Service is running
- Check customer_address_id is correct
- Check authorization/authentication
- Check logs for errors

### Issue: Address Snapshot Not Created
- Check order creation logic
- Check database migration applied
- Check order_addresses table structure

### Issue: Frontend Not Showing Saved Addresses
- Check API call to Customer Service
- Check user authentication
- Check customer ID is correct
- Check browser console for errors

---

## 📝 Notes

- All tests should be run in staging environment first
- Database should be backed up before testing
- Test data should be cleaned up after testing
- Performance tests should be run with realistic data volumes

