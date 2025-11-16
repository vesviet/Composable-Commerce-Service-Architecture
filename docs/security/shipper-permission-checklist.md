# Shipper Permission Implementation Checklist

## Overview
Checklist đầy đủ cho việc implement permission system cho shipper (delivery person) trong microservices architecture.

---

## Phase 1: Role & Permission Definition

### 1.1 Create Shipper Role in User Service
- [x] **Define Role Structure** ✅
  - [x] Role ID: Generate UUID (`a1b2c3d4-e5f6-7890-abcd-ef1234567890`) ✅
  - [x] Role Name: `shipper` ✅
  - [x] Description: `"Delivery personnel who handle shipment delivery"` ✅
  - [x] Scope: `3` (RoleScopeOperational - same as operations_staff) ✅
  - [x] Permissions: `["read", "write"]` ✅
  - [x] Services: `["shipping-service"]` ✅

- [x] **Update Seed Data** ✅
  - [x] File: `user/internal/data/postgres/seed.go` ✅
  - [x] Add shipper role to `seeds` array ✅
  - [x] Update SQL seed file: `user/scripts/seed-user.sql` ✅
  - [ ] Test seed data creation (TODO: Test after migration)

- [ ] **Verify Role Creation**
  - [ ] Run migrations: `make migrate-up`
  - [ ] Verify role exists in database
  - [ ] Test role retrieval via API: `GET /api/v1/roles`

---

## Phase 2: Database Schema Updates

### 2.1 Shipment Table - Add assigned_to Field
- [x] **Create Migration File** ✅
  - [x] File: `shipping/migrations/004_add_assigned_to_shipments.sql` ✅
  - [x] Migration content created ✅

- [x] **Update Shipment Model** ✅
  - [x] File: `shipping/internal/model/shipment.go` ✅
  - [x] Add field: `AssignedTo *string` ✅
  - [x] Add index ✅

- [x] **Update Shipment Domain Entity** ✅
  - [x] File: `shipping/internal/biz/shipment/shipment.go` ✅
  - [x] Add field: `AssignedTo *string` ✅

- [x] **Update Proto Definition** ✅
  - [x] File: `shipping/api/shipping/v1/shipping.proto` ✅
  - [x] Add `assigned_to` field to Shipment message ✅
  - [x] Regenerate protobuf: `make api` ✅

- [ ] **Test Migration**
  - [ ] Run migration up: `make migrate-up`
  - [ ] Verify column exists: `\d shipments` (PostgreSQL)
  - [ ] Verify index created
  - [ ] Test migration down: `make migrate-down`
  - [ ] Test migration up again

---

## Phase 3: Shipping Service - API Updates

### 3.1 List Shipments - Filter by assigned_to
- [ ] **Update ListShipments Handler**
  - [ ] File: `shipping/internal/service/shipping.go`
  - [ ] Extract user ID from JWT token (from gateway headers)
  - [ ] Check user role:
    - [ ] If role = `shipper` → Filter: `WHERE assigned_to = {user_id}`
    - [ ] If role = `admin` or `operations_staff` → No filter (see all)
  - [ ] Add query parameter: `?assigned_to={user_id}` (optional, for admin)

- [ ] **Update Repository Method**
  - [ ] File: `shipping/internal/data/postgres/shipment.go`
  - [ ] Add filter logic:
    ```go
    if assignedTo != nil {
        query = query.Where("assigned_to = ?", *assignedTo)
    }
    ```

- [ ] **Update Business Logic**
  - [ ] File: `shipping/internal/biz/shipment/shipment.go`
  - [ ] Add `AssignedTo` filter parameter to `ListShipments` method
  - [ ] Validate: Shipper can only see their own shipments

- [ ] **Test API**
  - [ ] Test as shipper: Should only see assigned shipments
  - [ ] Test as admin: Should see all shipments
  - [ ] Test with invalid user_id: Should return empty list

### 3.2 Get Shipment - Check Access
- [ ] **Update GetShipment Handler**
  - [ ] File: `shipping/internal/service/shipping.go`
  - [ ] Extract user ID and role from headers
  - [ ] Check access:
    - [ ] If role = `shipper` → Verify `assigned_to = {user_id}`
    - [ ] If role = `admin` → Allow access
  - [ ] Return 403 if shipper tries to access unassigned shipment

- [ ] **Update Repository Method**
  - [ ] File: `shipping/internal/data/postgres/shipment.go`
  - [ ] No changes needed (already fetches by ID)

- [ ] **Update Business Logic**
  - [ ] File: `shipping/internal/biz/shipment/shipment.go`
  - [ ] Add access check in `GetShipment`:
    ```go
    if userRole == "shipper" && shipment.AssignedTo != nil && *shipment.AssignedTo != userID {
        return nil, errors.New("access denied: shipment not assigned to you")
    }
    ```

- [ ] **Test API**
  - [ ] Test shipper accessing assigned shipment: Should succeed
  - [ ] Test shipper accessing unassigned shipment: Should return 403
  - [ ] Test admin accessing any shipment: Should succeed

### 3.3 Update Shipment Status - Validate Transitions
- [ ] **Update UpdateShipmentStatus Handler**
  - [ ] File: `shipping/internal/service/shipping.go`
  - [ ] Extract user ID and role
  - [ ] Check access (same as GetShipment)
  - [ ] Validate status transition:
    - [ ] `ready` → `picked_up` ✅
    - [ ] `picked_up` → `in_transit` ✅
    - [ ] `in_transit` → `out_for_delivery` ✅
    - [ ] `out_for_delivery` → `delivered` ✅
    - [ ] Other transitions → ❌ (only admin can do)
  - [ ] Add audit log: who, when, what changed

- [ ] **Update Business Logic**
  - [ ] File: `shipping/internal/biz/shipment/shipment.go`
  - [ ] Add `ValidateStatusTransition` method:
    ```go
    func ValidateStatusTransition(oldStatus, newStatus, userRole string) error {
        validTransitions := map[string][]string{
            "ready":           {"picked_up"},
            "picked_up":       {"in_transit"},
            "in_transit":      {"out_for_delivery"},
            "out_for_delivery": {"delivered"},
        }
        // Check if transition is valid
        // If not, check if user is admin (admin can do any transition)
    }
    ```

- [ ] **Test API**
  - [ ] Test valid transitions: Should succeed
  - [ ] Test invalid transitions: Should return 400
  - [ ] Test admin doing any transition: Should succeed
  - [ ] Test shipper accessing unassigned shipment: Should return 403

### 3.4 Add Tracking Event
- [ ] **Update AddTrackingEvent Handler** (if exists)
  - [ ] File: `shipping/internal/service/shipping.go`
  - [ ] Extract user ID and role
  - [ ] Check access (same as GetShipment)
  - [ ] Validate: Only shipper assigned to shipment can add events
  - [ ] Store event with user_id, timestamp, location (if available)

- [ ] **Update Business Logic**
  - [ ] File: `shipping/internal/biz/shipment/shipment.go`
  - [ ] Add `AddTrackingEvent` method
  - [ ] Validate access before adding event

- [ ] **Test API**
  - [ ] Test shipper adding event to assigned shipment: Should succeed
  - [ ] Test shipper adding event to unassigned shipment: Should return 403

### 3.5 Confirm Delivery
- [ ] **Update ConfirmDelivery Handler** (if exists)
  - [ ] File: `shipping/internal/service/shipping.go`
  - [ ] Extract user ID and role
  - [ ] Check access (same as GetShipment)
  - [ ] Validate: Status must be `out_for_delivery`
  - [ ] Update status to `delivered`
  - [ ] Store delivery signature (if provided)
  - [ ] Store delivery photo (if provided)
  - [ ] Store delivery timestamp
  - [ ] Publish event: `shipment.delivered`

- [ ] **Update Business Logic**
  - [ ] File: `shipping/internal/biz/shipment/shipment.go`
  - [ ] Add `ConfirmDelivery` method
  - [ ] Validate status before confirming

- [ ] **Test API**
  - [ ] Test shipper confirming delivery: Should succeed
  - [ ] Test shipper confirming delivery with wrong status: Should return 400
  - [ ] Test shipper confirming delivery for unassigned shipment: Should return 403

### 3.6 Assign Shipment to Shipper
- [ ] **Update AssignShipment Handler** (NEW endpoint)
  - [ ] File: `shipping/internal/service/shipping.go`
  - [ ] Endpoint: `POST /api/v1/shipments/{id}/assign`
  - [ ] **Permission**: Only `admin` or `operations_staff` can assign
  - [ ] Request body: `{ "assigned_to": "user_id" }`
  - [ ] Validate: User exists and has role `shipper`
  - [ ] Update shipment: `assigned_to = {user_id}`
  - [ ] Publish event: `shipment.assigned`

- [ ] **Update Business Logic**
  - [ ] File: `shipping/internal/biz/shipment/shipment.go`
  - [ ] Add `AssignShipment` method
  - [ ] Validate user role before assigning

- [ ] **Test API**
  - [ ] Test admin assigning shipment: Should succeed
  - [ ] Test shipper trying to assign: Should return 403
  - [ ] Test assigning to non-shipper user: Should return 400

---

## Phase 4: Gateway - Authentication & Authorization

### 4.1 JWT Token Validation
- [x] **Update Gateway Middleware** ✅
  - [x] File: `gateway/internal/middleware/admin_auth.go` ✅
  - [x] Support `shipper` role in token validation ✅
  - [x] Extract `shipper` role from JWT claims ✅
  - [x] Set headers: `X-User-ID`, `X-User-Role`, `X-Client-Type: shipper` ✅

- [x] **Update Auto Router** ✅
  - [x] File: `gateway/internal/router/auto_router.go` ✅
  - [x] Support `shipper` client_type in JWT validation ✅
  - [x] Allow `shipper` role access to `/admin/v1/shipping/*` endpoints ✅
  - [x] Extract `client_type` from JWT claims (including "shipper") ✅
  - [x] Set `X-Client-Type`, `X-MD-Client-Type`, `X-MD-Global-Client-Type` headers ✅

- [ ] **Test Gateway**
  - [ ] Test shipper token validation: Should succeed
  - [ ] Test shipper accessing shipping endpoints: Should succeed
  - [ ] Test shipper accessing admin endpoints: Should return 403

### 4.2 Route Configuration
- [x] **Update Gateway Routes** ✅
  - [x] Note: Gateway uses auto-routing via `/admin/v1/` prefix ✅
  - [x] Shipping service routes accessible via `/admin/v1/shipping/*` ✅
  - [x] `admin_auth` middleware applied to `/admin/v1/` routes ✅
  - [x] Middleware updated to support `shipper` role ✅
  - [x] Route configuration handled by existing routing patterns in `gateway.yaml` ✅

- [ ] **Test Routes**
  - [ ] Test shipper accessing allowed endpoints: Should succeed
  - [ ] Test shipper accessing restricted endpoints: Should return 403

---

## Phase 5: Auth Service - Token Generation

### 5.1 Support Shipper Client Type
- [x] **Update Auth Service** ✅
  - [x] File: `auth/internal/biz/token/token.go` ✅
  - [x] Updated `GenerateTokenRequest` to include `Roles []string` ✅
  - [x] Updated `generateAccessToken` to include `roles` in JWT claims ✅
  - [x] Generate JWT token with:
    - [x] `client_type: "shipper"` (or `user_type: "shipper"` for backward compatibility) ✅
    - [x] `roles: ["shipper"]` ✅
    - [x] `user_id: {user_id}` ✅
    - [x] `email: {email}` ✅

- [x] **Update Token Claims** ✅
  - [x] Include shipper role in JWT claims ✅
  - [x] Set appropriate expiration (uses existing accessTokenTTL) ✅

- [ ] **Test Auth Service**
  - [ ] Test shipper login: Should return JWT with shipper role
  - [ ] Test token validation: Should validate shipper token correctly

---

## Phase 6: User Service - User Management

### 6.1 Create Shipper User API
- [ ] **Update CreateUser Handler**
  - [ ] File: `user/internal/service/user.go`
  - [ ] Support creating user with `shipper` role
  - [ ] Validate: Only admin can create shipper users

- [ ] **Update AssignRole Handler**
  - [ ] File: `user/internal/service/user.go`
  - [ ] Support assigning `shipper` role to user
  - [ ] Validate: User exists, role exists

- [ ] **Test User Service**
  - [ ] Test creating shipper user: Should succeed
  - [ ] Test assigning shipper role: Should succeed
  - [ ] Test retrieving shipper user: Should return with role

### 6.2 List Users by Role
- [ ] **Update ListUsers Handler**
  - [ ] File: `user/internal/service/user.go`
  - [ ] Add filter: `?role=shipper`
  - [ ] Return users with shipper role

- [ ] **Test API**
  - [ ] Test listing shipper users: Should return all shippers
  - [ ] Test filtering by role: Should work correctly

---

## Phase 7: Admin UI - Shipper Management

### 7.1 Shipper User Management
- [ ] **Create Shipper List Page**
  - [ ] File: `admin/src/pages/ShippersPage.tsx` (NEW)
  - [ ] List all users with `shipper` role
  - [ ] Display: Name, Email, Phone, Status, Assigned Shipments Count
  - [ ] Actions: View, Edit, Deactivate

- [ ] **Create Shipper Form**
  - [ ] File: `admin/src/components/ShipperForm.tsx` (NEW)
  - [ ] Fields: Username, Email, First Name, Last Name, Phone, Password
  - [ ] Auto-assign `shipper` role on creation
  - [ ] Validation: Email format, password strength

- [ ] **Update User Management**
  - [ ] File: `admin/src/pages/UsersPage.tsx`
  - [ ] Add filter: "Shippers" tab
  - [ ] Show shipper role badge

- [ ] **Test Admin UI**
  - [ ] Test creating shipper user: Should succeed
  - [ ] Test listing shippers: Should display correctly
  - [ ] Test editing shipper: Should update correctly

### 7.2 Shipment Assignment UI
- [ ] **Update Shipments Page**
  - [ ] File: `admin/src/pages/ShipmentsPage.tsx` (if exists)
  - [ ] Add "Assign Shipper" action
  - [ ] Dropdown: Select shipper from list
  - [ ] Update shipment: `assigned_to` field
  - [ ] Display assigned shipper in shipment list

- [ ] **Update Shipment Details**
  - [ ] Show assigned shipper name
  - [ ] Show "Assign Shipper" button (if not assigned)
  - [ ] Show "Reassign Shipper" button (if assigned)

- [ ] **Test Admin UI**
  - [ ] Test assigning shipper to shipment: Should succeed
  - [ ] Test reassigning shipper: Should succeed
  - [ ] Test displaying assigned shipper: Should show correctly

---

## Phase 8: Mobile/Web App for Shipper

### 8.1 Shipper Login
- [ ] **Login Screen**
  - [ ] Username/Email input
  - [ ] Password input
  - [ ] Login button
  - [ ] Call Auth Service: `POST /api/v1/auth/login`
  - [ ] Store JWT token in secure storage

- [ ] **Token Management**
  - [ ] Store token: `localStorage` or `AsyncStorage` (mobile)
  - [ ] Add token to all API requests: `Authorization: Bearer {token}`
  - [ ] Handle token expiration: Redirect to login

- [ ] **Test Login**
  - [ ] Test shipper login: Should succeed
  - [ ] Test invalid credentials: Should show error
  - [ ] Test token storage: Should persist

### 8.2 Shipment List
- [ ] **My Shipments Screen**
  - [ ] Fetch shipments: `GET /api/v1/shipments`
  - [ ] Display: Shipment ID, Customer Name, Address, Status, Priority
  - [ ] Filter: Status (ready, picked_up, in_transit, out_for_delivery)
  - [ ] Sort: By priority, by address proximity
  - [ ] Pull to refresh

- [ ] **Shipment Details**
  - [ ] Fetch: `GET /api/v1/shipments/{id}`
  - [ ] Display: Full address, customer phone, notes, tracking number
  - [ ] Actions: Update Status, Add Tracking Event, Confirm Delivery

- [ ] **Test App**
  - [ ] Test listing shipments: Should show only assigned shipments
  - [ ] Test viewing details: Should display correctly
  - [ ] Test filtering: Should work correctly

### 8.3 Update Status
- [ ] **Status Update Screen**
  - [ ] Current status display
  - [ ] Next status options (based on valid transitions)
  - [ ] Notes input (optional)
  - [ ] Location capture (GPS, optional)
  - [ ] Submit button
  - [ ] Call API: `PUT /api/v1/shipments/{id}/status`

- [ ] **Test Status Update**
  - [ ] Test valid transitions: Should succeed
  - [ ] Test invalid transitions: Should show error
  - [ ] Test location capture: Should store correctly

### 8.4 Confirm Delivery
- [ ] **Delivery Confirmation Screen**
  - [ ] Customer name display
  - [ ] Address display
  - [ ] Signature capture (touch/pen)
  - [ ] Photo capture (optional)
  - [ ] Notes input
  - [ ] Confirm button
  - [ ] Call API: `POST /api/v1/shipments/{id}/delivery`

- [ ] **Test Delivery**
  - [ ] Test confirming delivery: Should succeed
  - [ ] Test signature capture: Should store correctly
  - [ ] Test photo capture: Should upload correctly

---

## Phase 9: Audit & Logging

### 9.1 Audit Logging
- [ ] **Log Status Updates**
  - [ ] File: `shipping/internal/biz/shipment/shipment.go`
  - [ ] Log: `shipment.status.updated`
  - [ ] Include: user_id, old_status, new_status, timestamp, location

- [ ] **Log Assignments**
  - [ ] Log: `shipment.assigned`
  - [ ] Include: shipment_id, assigned_to, assigned_by, timestamp

- [ ] **Log Delivery Confirmations**
  - [ ] Log: `shipment.delivered`
  - [ ] Include: shipment_id, delivered_by, delivered_at, signature_url, photo_url

- [ ] **Test Logging**
  - [ ] Test status update logging: Should log correctly
  - [ ] Test assignment logging: Should log correctly
  - [ ] Test delivery logging: Should log correctly

### 9.2 Event Publishing
- [ ] **Publish Events**
  - [ ] Event: `shipment.assigned` (when assigned to shipper)
  - [ ] Event: `shipment.status_changed` (when status updated)
  - [ ] Event: `shipment.delivered` (when delivery confirmed)
  - [ ] Use Dapr Pub/Sub: `publish-event`

- [ ] **Test Events**
  - [ ] Test event publishing: Should publish correctly
  - [ ] Test event consumption: Should be consumed by other services

---

## Phase 10: Testing & Validation

### 10.1 Unit Tests
- [ ] **Shipping Service Tests**
  - [ ] Test ListShipments with shipper filter
  - [ ] Test GetShipment access control
  - [ ] Test UpdateShipmentStatus validation
  - [ ] Test AssignShipment permission check

- [ ] **User Service Tests**
  - [ ] Test creating shipper role
  - [ ] Test assigning shipper role to user
  - [ ] Test retrieving shipper users

- [ ] **Gateway Tests**
  - [ ] Test shipper token validation
  - [ ] Test shipper route access

### 10.2 Integration Tests
- [ ] **End-to-End Flow**
  - [ ] Test: Admin creates shipper user
  - [ ] Test: Admin assigns shipment to shipper
  - [ ] Test: Shipper logs in
  - [ ] Test: Shipper views assigned shipments
  - [ ] Test: Shipper updates status
  - [ ] Test: Shipper confirms delivery

- [ ] **Access Control Tests**
  - [ ] Test: Shipper cannot see unassigned shipments
  - [ ] Test: Shipper cannot access admin endpoints
  - [ ] Test: Shipper cannot assign shipments
  - [ ] Test: Shipper cannot do invalid status transitions

### 10.3 Security Tests
- [ ] **Permission Tests**
  - [ ] Test: Shipper with invalid token → 401
  - [ ] Test: Shipper accessing other shipper's shipment → 403
  - [ ] Test: Shipper trying to assign shipment → 403
  - [ ] Test: Shipper trying invalid status transition → 400

- [ ] **Data Isolation Tests**
  - [ ] Test: Shipper A cannot see Shipper B's shipments
  - [ ] Test: Shipper can only update assigned shipments
  - [ ] Test: Admin can see all shipments

---

## Phase 11: Documentation

### 11.1 API Documentation
- [ ] **Update OpenAPI Spec**
  - [ ] File: `shipping/openapi.yaml`
  - [ ] Document shipper endpoints
  - [ ] Document access control rules
  - [ ] Document status transitions

- [ ] **Update Service Documentation**
  - [ ] File: `docs/docs/services/shipping-service.md`
  - [ ] Document shipper role
  - [ ] Document permission requirements
  - [ ] Document API endpoints for shipper

### 11.2 User Documentation
- [ ] **Shipper Guide**
  - [ ] File: `docs/docs/guides/shipper-guide.md`
  - [ ] How to login
  - [ ] How to view shipments
  - [ ] How to update status
  - [ ] How to confirm delivery

- [ ] **Admin Guide**
  - [ ] File: `docs/docs/guides/admin-shipper-management.md`
  - [ ] How to create shipper user
  - [ ] How to assign shipment to shipper
  - [ ] How to monitor shipper activity

---

## Phase 12: Deployment

### 12.1 Database Migration
- [ ] **Run Migrations**
  - [ ] Run User Service migration: Create shipper role
  - [ ] Run Shipping Service migration: Add assigned_to column
  - [ ] Verify migrations: Check database schema

- [ ] **Seed Data**
  - [ ] Run seed script: Create shipper role
  - [ ] Verify role exists in database

### 12.2 Service Deployment
- [ ] **Deploy User Service**
  - [ ] Build Docker image
  - [ ] Deploy to staging
  - [ ] Verify shipper role exists

- [ ] **Deploy Shipping Service**
  - [ ] Build Docker image
  - [ ] Deploy to staging
  - [ ] Verify assigned_to column exists

- [ ] **Deploy Gateway**
  - [ ] Build Docker image
  - [ ] Deploy to staging
  - [ ] Verify shipper routes work

- [ ] **Deploy Auth Service**
  - [ ] Build Docker image
  - [ ] Deploy to staging
  - [ ] Verify shipper token generation

### 12.3 Verification
- [ ] **Smoke Tests**
  - [ ] Test shipper login: Should succeed
  - [ ] Test shipper viewing shipments: Should work
  - [ ] Test shipper updating status: Should work
  - [ ] Test admin assigning shipment: Should work

- [ ] **Monitoring**
  - [ ] Check logs: No errors
  - [ ] Check metrics: API calls successful
  - [ ] Check alerts: No critical issues

---

## Summary

**Total Phases:** 12

**Key Components:**
1. Role & Permission Definition
2. Database Schema Updates
3. Shipping Service API Updates
4. Gateway Authentication
5. Auth Service Token Generation
6. User Service User Management
7. Admin UI Shipper Management
8. Mobile/Web App for Shipper
9. Audit & Logging
10. Testing & Validation
11. Documentation
12. Deployment

**Critical Security Points:**
- ✅ Data isolation: Shipper only sees assigned shipments
- ✅ Access control: Shipper cannot access admin endpoints
- ✅ Status validation: Only valid transitions allowed
- ✅ Audit trail: All actions logged

**Key API Endpoints:**
- `GET /api/v1/shipments` - List shipments (filtered by assigned_to)
- `GET /api/v1/shipments/{id}` - Get shipment details
- `PUT /api/v1/shipments/{id}/status` - Update status
- `POST /api/v1/shipments/{id}/assign` - Assign shipment (admin only)
- `POST /api/v1/shipments/{id}/delivery` - Confirm delivery

**Database Changes:**
- Add `assigned_to` column to `shipments` table
- Create index on `assigned_to`
- Add foreign key to `users` table

**Role Definition:**
- Role Name: `shipper`
- Permissions: `["read", "write"]`
- Services: `["shipping-service"]`
- Scope: `3` (Operational)

