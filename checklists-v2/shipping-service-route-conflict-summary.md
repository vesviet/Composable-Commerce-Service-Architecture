# Shipping Service Route Conflict - Summary

## Bug: Route Conflicts

### Problem

**Multiple route conflicts** between Carrier and ShippingMethod endpoints:

| Method | Route | Conflict |
|--------|-------|----------|
| GET | `/admin/v1/shipping/methods` | ListCarriers vs ListShippingMethods |
| GET | `/admin/v1/shipping/methods/{id}` | GetCarrier vs GetShippingMethod |
| POST | `/admin/v1/shipping/methods` | **CreateCarrier vs CreateShippingMethod** ⚠️ |
| PUT | `/admin/v1/shipping/methods/{id}` | UpdateCarrier vs UpdateShippingMethod |

### User's Request

```bash
POST /admin/v1/shipping/methods
Body: {
  "code": "FLAT_RATE",
  "name": "Shipping Fee",
  "type": "flat_rate",
  "enabled": true,
  "display_order": 0,
  "config": {"rate": 50000, "currency": "VND"},
  "conditions": {}
}
```

**Expected**: Create ShippingMethod  
**Actual**: May route to CreateCarrier handler (if registered first) → **FAILS**

## Root Cause

**Inconsistent Route Naming**:
- Some Carrier endpoints use `/carriers/` (DeleteCarrier, TestCarrierConnection, GetCarrierRates)
- But CRUD operations use `/methods/` (conflicts with ShippingMethod)

**Design Issue**: Both resources share same route prefix `/admin/v1/shipping/methods`

## Solution: Fix Route Conflicts

### Recommended Fix

**Change Carrier CRUD routes to use `/admin/v1/shipping/carriers`**:

```protobuf
// BEFORE (conflicts)
rpc ListCarriers(...) {
  option (google.api.http) = {
    get: "/admin/v1/shipping/methods"  // ❌
  };
}

rpc CreateCarrier(...) {
  option (google.api.http) = {
    post: "/admin/v1/shipping/methods"  // ❌
  };
}

// AFTER (fixed)
rpc ListCarriers(...) {
  option (google.api.http) = {
    get: "/admin/v1/shipping/carriers"  // ✅
  };
}

rpc CreateCarrier(...) {
  option (google.api.http) = {
    post: "/admin/v1/shipping/carriers"  // ✅
  };
}
```

### Complete Route Mapping

**Carrier Routes** (should be `/carriers/`):
- `GET /admin/v1/shipping/carriers` → ListCarriers
- `GET /admin/v1/shipping/carriers/{id}` → GetCarrier
- `POST /admin/v1/shipping/carriers` → CreateCarrier
- `PUT /admin/v1/shipping/carriers/{id}` → UpdateCarrier
- `DELETE /admin/v1/shipping/carriers/{id}` → DeleteCarrier ✅ (already correct)

**ShippingMethod Routes** (keep `/methods/`):
- `GET /admin/v1/shipping/methods` → ListShippingMethods
- `GET /admin/v1/shipping/methods/{id}` → GetShippingMethod
- `POST /admin/v1/shipping/methods` → CreateShippingMethod
- `PUT /admin/v1/shipping/methods/{id}` → UpdateShippingMethod
- `DELETE /admin/v1/shipping/methods/{id}` → DeleteShippingMethod

## Implementation

### Step 1: Update Proto File

**File**: `shipping/api/shipping/v1/shipping.proto`

**Changes**:
```protobuf
// Line 150-154: Change ListCarriers
rpc ListCarriers(ListCarriersRequest) returns (ListCarriersResponse) {
  option (google.api.http) = {
    get: "/admin/v1/shipping/carriers"  // Changed from /methods
  };
}

// Line 157-161: Change GetCarrier
rpc GetCarrier(GetCarrierRequest) returns (GetCarrierResponse) {
  option (google.api.http) = {
    get: "/admin/v1/shipping/carriers/{id}"  // Changed from /methods/{id}
  };
}

// Line 164-169: Change CreateCarrier
rpc CreateCarrier(CreateCarrierRequest) returns (CreateCarrierResponse) {
  option (google.api.http) = {
    post: "/admin/v1/shipping/carriers"  // Changed from /methods
    body: "*"
  };
}

// Line 172-177: Change UpdateCarrier
rpc UpdateCarrier(UpdateCarrierRequest) returns (UpdateCarrierResponse) {
  option (google.api.http) = {
    put: "/admin/v1/shipping/carriers/{id}"  // Changed from /methods/{id}
    body: "*"
  };
}
```

### Step 2: Regenerate Code

```bash
cd shipping
make api  # Regenerate protobuf code
```

### Step 3: Update Frontend (if needed)

**File**: `admin/src/lib/api/shipping-api.ts`

Check if frontend calls Carrier endpoints and update routes if needed.

### Step 4: Test

- [ ] POST `/admin/v1/shipping/methods` creates shipping method ✅
- [ ] POST `/admin/v1/shipping/carriers` creates carrier ✅
- [ ] No route conflicts in generated code ✅

## Impact Analysis

### Before Fix
- ❌ Route conflicts cause unpredictable behavior
- ❌ CreateCarrier may not work
- ❌ User's request may fail or route to wrong handler

### After Fix
- ✅ Clear separation: `/carriers/` vs `/methods/`
- ✅ No route conflicts
- ✅ User's request will work correctly
- ✅ Both endpoints accessible

## Priority

**Severity**: 🔴 **High**  
**Priority**: 🔴 **High**  
**Effort**: 🟢 **Low** (simple proto change)

## Files to Change

1. `shipping/api/shipping/v1/shipping.proto` - Update routes
2. Regenerate: `shipping/api/shipping/v1/shipping_http.pb.go`
3. Test: Verify routes work correctly

## Conclusion

**Bug**: Route conflicts between Carrier and ShippingMethod endpoints

**Fix**: Change Carrier routes to `/admin/v1/shipping/carriers`

**Status**: Ready to implement
