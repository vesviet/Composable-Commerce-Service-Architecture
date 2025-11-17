# Shipping Flow Checklist - Từ Picklist đến Delivery

## Overview
Checklist đầy đủ cho flow shipping từ picklist completion đến delivery, bao gồm tất cả các bước, events, integrations, và edge cases.

---

## Phase 1: Picklist Completion → Package Creation

### 1.1 Picklist Completion
- [x] Picklist status: `in_progress` → `completed` ✅
- [x] Validate: All items picked (quantity_picked = quantity_to_pick) ✅
- [x] Update picklist: `completed_at` timestamp ✅
- [x] Event published: `picklist.status_changed` ✅
  - Event type: `picklist.status_changed`
  - Old status: `in_progress`
  - New status: `completed`
  - Payload includes: picklist_id, fulfillment_id, warehouse_id, items

### 1.2 Fulfillment Status Update (Auto)
- [x] **Worker listens `picklist.status_changed` event** ✅
- [x] **Auto-update fulfillment status: `picking` → `picked`** ✅
- [x] **Auto-update fulfillment items với quantity_picked** ✅
- [x] Update fulfillment: `picked_at` timestamp ✅
- [x] Event published: `fulfillment.status_changed` ✅
  - Old status: `picking`
  - New status: `picked`

### 1.3 Packing Phase (Manual/Admin)
- [ ] Admin/Packer confirms items are packed
- [ ] Enter package details:
  - [ ] Package type (box, envelope, pallet, bag, custom)
  - [ ] Weight (kg)
  - [ ] Dimensions (length, width, height in cm)
  - [ ] Packed by (packer ID)
  - [ ] Notes (optional)

### 1.4 Package Creation
- [x] Generate package number: `PKG-{YYMM}-{000001}` ✅
- [x] Create package record: ✅
  - [x] Status: `created` ✅
  - [x] Link to fulfillment_id ✅
  - [x] Store package details (type, weight, dimensions) ✅
  - [x] Store packer info ✅
- [x] Create package_items: ✅
  - [x] Link to fulfillment_items ✅
  - [x] Quantity packed = quantity picked ✅
- [x] Update package: `total_items` count ✅
- [x] Event published: `package.status_changed` ✅
  - Old status: `""` (new package)
  - New status: `created`
  - Payload includes: package_id, package_number, fulfillment_id, order_id, warehouse_id

### 1.5 Fulfillment Status Update
- [x] Fulfillment status: `picked` → `packed` ✅
- [x] Update fulfillment: `packed_at` timestamp ✅
- [x] Update fulfillment: `package_id` reference ✅
- [x] Event published: `fulfillment.status_changed` ✅
  - Old status: `picked`
  - New status: `packed`

---

## Phase 2: Package → Shipment Creation

### 2.1 Shipping Service Worker Setup
- [x] Worker listens: `package.status_changed` event ✅
- [x] Filter: Only process when new_status = `created` ✅
- [x] Error handling: Retry mechanism for failed events ✅

### 2.2 Get Package Details
- [x] **Get package details from event payload** ✅
- [x] Retrieve package details:
  - [x] Package ID, number ✅
  - [x] Fulfillment ID ✅
  - [x] Weight, dimensions ✅
  - [x] Package type ✅
- [x] Error handling: If package not found, log and skip ✅

### 2.3 Get Order Details
- [ ] Call Order Service API: `GET /api/v1/orders/{order_id}` (TODO: Will be enhanced later)
- [ ] Retrieve order details:
  - [ ] Order ID, number
  - [ ] Shipping method ID (from checkout)
  - [ ] Shipping address
  - [ ] Customer ID
- [x] **Current: Extract order_id from event metadata** ✅
- [ ] Error handling: If order not found, log and skip (TODO: Will be enhanced)

### 2.4 Get Shipping Method Details
- [ ] Call Shipping Service API: `GET /api/v1/shipping-methods/{shipping_method_id}` (TODO: Will be enhanced later)
- [ ] Retrieve shipping method:
  - [ ] Method ID, name, code
  - [ ] Carrier (fedex, ups, dhl, internal, etc.)
  - [ ] Method type (internal/external)
  - [ ] Service type
- [x] **Current: Use default carrier from metadata or "internal"** ✅
- [ ] Error handling: If method not found, use default (TODO: Will be enhanced)

### 2.5 Determine Carrier
- [x] Extract carrier from shipping method ✅
- [x] If internal method → carrier = "internal" ✅
- [x] If external method → carrier from shipping method config ✅
- [x] Store carrier in shipment record ✅

### 2.6 Create Shipment Record
- [x] Generate shipment ID (UUID) ✅
- [x] Create shipment with fields: ✅
  - [x] `fulfillment_id` (from package) ✅
  - [x] `order_id` (from package/fulfillment metadata) ✅
  - [x] `package_id` (stored in metadata) ✅
  - [ ] `shipping_method_id` (TODO: Will be added when order service integration complete)
  - [ ] `shipping_method_type` (TODO: Will be added when order service integration complete)
  - [x] `carrier` (from shipping method or default) ✅
  - [x] `carrier_service` (nullable, will be set later) ✅
  - [x] `status` = `draft` ✅
  - [x] `weight` (from package) ✅
  - [x] `dimensions` (from package) ✅
  - [x] `shipping_cost` (default 0, will be updated later) ✅
  - [x] `currency` (default "USD", will be updated from order) ✅
- [x] Save shipment to database ✅
- [x] Event published: `shipment.created` ✅
  - Payload includes: shipment_id, fulfillment_id, order_id, package_id, carrier, status

---

## Phase 3: Label Generation

### 3.1 Label Generation Decision
- [x] Check shipping method type: ✅
  - [x] If `internal` → Generate internal label ✅
  - [x] If `external` → Generate label via carrier API (basic implementation) ✅

### 3.2 Get Shipping Address
- [ ] Get shipping address from order
- [ ] Validate address fields:
  - [ ] Street address
  - [ ] City, state, postal code
  - [ ] Country
  - [ ] Phone number (for carrier)

### 3.3 Get Warehouse Address (From Address)
- [ ] Get warehouse address from Warehouse Service
- [ ] Use warehouse_id from fulfillment
- [ ] Validate warehouse address

### 3.4 Generate Shipping Label (External Methods)
- [ ] Call carrier API (FedEx, UPS, DHL, etc.):
  - [ ] Prepare request payload:
    - [ ] From address (warehouse)
    - [ ] To address (customer)
    - [ ] Package weight, dimensions
    - [ ] Service type
    - [ ] Reference numbers (order_number, package_number)
  - [ ] Send request to carrier API
  - [ ] Handle API response
- [ ] Extract from response:
  - [ ] Tracking number
  - [ ] Shipping label (PDF/image URL)
  - [ ] Tracking URL
  - [ ] Estimated delivery date
  - [ ] Shipping cost (if different from order)
- [ ] Error handling:
  - [ ] If API fails → Retry mechanism
  - [ ] If API down → Queue for retry
  - [ ] Log errors for monitoring

### 3.5 Update Shipment
- [x] Update shipment record: ✅
  - [x] `tracking_number` (from carrier) ✅
  - [x] `label_url` (stored in metadata) ✅
  - [x] `tracking_url` (carrier tracking URL) ✅
  - [x] `estimated_delivery` (from carrier) ✅
  - [x] `status` = `processing` ✅
  - [x] `shipping_cost` (update if different) ✅
- [x] Save to database ✅
- [x] Event published: `shipment.label_generated` ✅
  - Payload includes: shipment_id, tracking_number, label_url, tracking_url

### 3.6 Update Package (Fulfillment Service)
- [x] **FulfillmentClient interface created** ✅
- [x] **Call Fulfillment Service gRPC: `UpdatePackageTracking`** ✅
- [x] Update package:
  - [x] `tracking_number` (from shipment) ✅
  - [x] `shipping_label_url` (from shipment) ✅
  - [ ] `status` = `created` → `labeled` (TODO: Will be handled by fulfillment service)
- [ ] Event published: `package.status_changed` (TODO: Will be handled by fulfillment service)
  - Old status: `created`
  - New status: `labeled`
  - Payload includes: tracking_number, label_url

### 3.7 Internal Method Handling
- [x] If internal method: ✅
  - [x] Generate internal tracking number ✅
  - [x] Create internal label URL ✅
  - [x] Update shipment status: `draft` → `processing` ✅
  - [ ] Update package status: `created` → `labeled` (TODO: Via fulfillment service)

---

## Phase 4: Package Ready

### 4.1 Package Status Update
- [x] Package status: `labeled` → `ready` ✅
- [x] Meaning: Package có label, sẵn sàng cho carrier pickup ✅
- [x] Update package: `ready_at` timestamp (handled by fulfillment service) ✅
- [x] Event published: `package.status_changed` ✅
  - Old status: `labeled`
  - New status: `ready`
- [x] **FulfillmentClient.MarkPackageReady() method created** ✅

### 4.2 Fulfillment Status Update
- [x] Fulfillment status: `packed` → `ready` ✅ (handled by fulfillment service)
- [x] Update fulfillment: `ready_at` timestamp (handled by fulfillment service) ✅
- [x] Event published: `fulfillment.status_changed` ✅ (handled by fulfillment service)
  - Old status: `packed`
  - New status: `ready`
- [x] **Fulfillment service has MarkReadyToShip() API** ✅

### 4.3 Shipment Status Update
- [x] Shipment status: `processing` → `ready` ✅ (tracked via metadata)
- [x] Update shipment: `ready_at` timestamp (stored in metadata) ✅
- [x] Event published: `shipment.status_changed` ✅
  - Old status: `processing`
  - New status: `processing` (with ready metadata)
- [x] **HandlePackageReady() method created** ✅
- [x] **MarkShipmentReady() method created** ✅
- [x] **Auto-update when package.status_changed to "ready"** ✅

---

## Phase 5: Package Shipped

### 5.1 Physical Handover
- [ ] Physical action: Package được carrier pickup
- [ ] Or: Admin marks as shipped manually
- [ ] Or: Shipping service webhook from carrier (pickup confirmation)

### 5.2 Package Status Update
- [ ] Package status: `ready` → `shipped`
- [ ] Update package: `shipped_at` timestamp
- [ ] Event published: `package.status_changed`
  - Old status: `ready`
  - New status: `shipped`

### 5.3 Fulfillment Status Update
- [ ] Fulfillment status: `ready` → `shipped`
- [ ] Update fulfillment: `shipped_at` timestamp
- [ ] Event published: `fulfillment.status_changed`
  - Old status: `ready`
  - New status: `shipped`

### 5.4 Shipment Status Update
- [ ] Shipment status: `ready` → `shipped`
- [ ] Update shipment: `shipped_at` timestamp
- [ ] Event published: `shipment.status_changed`
  - Old status: `ready`
  - New status: `shipped`

### 5.5 Order Status Update (Optional)
- [ ] Order status: `processing` → `shipped` (if needed)
- [ ] Update order: `shipped_at` timestamp
- [ ] Event published: `order.status_changed` (if order service listens)

---

## Phase 6: Tracking Updates

### 6.1 Carrier Webhook Setup
- [ ] Configure webhook endpoints for each carrier
- [ ] Webhook security: Validate signatures
- [ ] Webhook routing: Route to correct handler

### 6.2 Receive Tracking Updates
- [ ] Receive webhook from carrier:
  - [ ] FedEx webhook
  - [ ] UPS webhook
  - [ ] DHL webhook
  - [ ] Other carriers
- [ ] Parse webhook payload:
  - [ ] Tracking number
  - [ ] Event type (in_transit, out_for_delivery, delivered, etc.)
  - [ ] Location
  - [ ] Timestamp
  - [ ] Description
- [ ] Error handling: Invalid webhook → Log and reject

### 6.3 Update Shipment Tracking
- [ ] Find shipment by tracking number
- [ ] Add tracking event to shipment:
  - [ ] Event type
  - [ ] Status
  - [ ] Location
  - [ ] Timestamp
  - [ ] Description
- [ ] Update shipment status (if status changed):
  - [ ] `shipped` → `in_transit`
  - [ ] `in_transit` → `out_for_delivery`
  - [ ] `out_for_delivery` → `delivered`
- [ ] Update shipment: `delivered_at` (if delivered)
- [ ] Save to database
- [ ] Event published: `shipment.tracking_updated`
  - Payload includes: shipment_id, tracking_number, status, events

### 6.4 Update Package Metadata (Fulfillment Service)
- [ ] Call Fulfillment Service API: `PATCH /api/v1/packages/{package_id}/status`
- [ ] Update package metadata (NOT status):
  - [ ] `metadata.shipping_status` = current shipment status
  - [ ] `metadata.tracking_events` = array of events
  - [ ] `metadata.last_tracking_update` = timestamp
- [ ] Package status remains `shipped` (not changed)
- [ ] Event published: `package.metadata_updated` (optional)

### 6.5 Polling Fallback (If Webhook Fails)
- [ ] Periodic job: Poll carrier API for tracking updates
- [ ] Frequency: Every 1-4 hours (configurable)
- [ ] Query shipments: Status = `shipped` or `in_transit`
- [ ] Call carrier API: Get tracking updates
- [ ] Process updates same as webhook
- [ ] Error handling: If polling fails → Retry next cycle

---

## Phase 7: Delivery Completed

### 7.1 Delivery Confirmation
- [ ] Carrier webhook: Status = `delivered`
- [ ] Or: Polling detects delivery
- [ ] Validate: Tracking number matches shipment

### 7.2 Shipment Status Update
- [ ] Shipment status: `out_for_delivery` → `delivered`
- [ ] Update shipment: `delivered_at` timestamp
- [ ] Update shipment: Delivery signature (if available)
- [ ] Event published: `shipment.status_changed`
  - Old status: `out_for_delivery`
  - New status: `delivered`
- [ ] Event published: `shipment.delivered`
  - Payload includes: shipment_id, tracking_number, delivered_at

### 7.3 Fulfillment Status Update
- [ ] Fulfillment status: `shipped` → `completed`
- [ ] Update fulfillment: `completed_at` timestamp
- [ ] Event published: `fulfillment.status_changed`
  - Old status: `shipped`
  - New status: `completed`

### 7.4 Package Status Update
- [ ] Package status remains `shipped` (terminal state)
- [ ] Update package metadata:
  - [ ] `metadata.shipping_status` = `delivered`
  - [ ] `metadata.delivered_at` = timestamp
- [ ] Event published: `package.metadata_updated` (optional)

### 7.5 Order Status Update (Optional)
- [ ] Order status: `shipped` → `delivered` or `completed` (if needed)
- [ ] Update order: `delivered_at` timestamp
- [ ] Event published: `order.status_changed` (if order service listens)

### 7.6 Customer Notification
- [ ] Send delivery notification to customer:
  - [ ] Email notification
  - [ ] SMS notification (optional)
  - [ ] Push notification (optional)
- [ ] Include: Tracking number, delivery date, signature (if available)

---

## Auto-Assignment Flow (Internal Shipping Methods)

### A.1 Picklist Generated Event
- [ ] Fulfillment Service publishes: `picklist.generated`
- [ ] Event payload includes:
  - [ ] `picklist_id`, `picklist_number`
  - [ ] `fulfillment_id`, `order_id`
  - [ ] `shipping_method_id` (from order)
  - [ ] `shipping_method_type` (internal/external)
  - [ ] `warehouse_id`
  - [ ] `priority`
  - [ ] `items` (picklist items)

### A.2 Shipping Service Worker
- [ ] Worker listens: `picklist.generated` event
- [ ] Filter: Only process if shipping_method_type = `internal`
- [ ] Get shipping method details (if needed)

### A.3 Picker Selection Logic
- [ ] Get available pickers for warehouse:
  - [ ] Query picker service or database
  - [ ] Filter: Active pickers, assigned to warehouse
- [ ] Check picker capacity:
  - [ ] Current workload (number of active picklists)
  - [ ] Max capacity per picker
- [ ] Consider priority:
  - [ ] If priority >= 15 (urgent) → Select experienced picker
  - [ ] If priority >= 10 (high) → Select available picker
  - [ ] If priority < 10 (normal/low) → Round-robin or least-loaded
- [ ] Select best picker:
  - [ ] Algorithm: Least-loaded, round-robin, or priority-based
  - [ ] Return picker ID

### A.4 Auto Assign Picklist
- [ ] Call Fulfillment Service API: `POST /api/v1/picklists/{picklist_id}/assign`
- [ ] Request payload:
  - [ ] `picklist_id`
  - [ ] `picker_id` (selected picker)
- [ ] Fulfillment Service updates:
  - [ ] Picklist: `assigned_to` = picker_id
  - [ ] Picklist: `assigned_at` = timestamp
  - [ ] Picklist: `status` = `pending` → `assigned`
- [ ] Event published: `picklist.status_changed`
  - Old status: `pending`
  - New status: `assigned`

### A.5 Error Handling
- [ ] If no picker available:
  - [ ] Log warning
  - [ ] Picklist remains `pending`
  - [ ] Admin can manual assign later
- [ ] If assign fails:
  - [ ] Retry mechanism (exponential backoff)
  - [ ] Log error for monitoring
  - [ ] Alert admin if retries exhausted

---

## Integration Points

### I.1 Fulfillment Service → Shipping Service
- [ ] Event: `package.status_changed` (created)
  - [ ] Action: Create shipment
- [ ] Event: `package.status_changed` (labeled)
  - [ ] Action: Update shipment label info
- [ ] Event: `package.status_changed` (ready)
  - [ ] Action: Update shipment status
- [ ] Event: `package.status_changed` (shipped)
  - [ ] Action: Update shipment status

### I.2 Shipping Service → Fulfillment Service
- [ ] API: `PATCH /api/v1/packages/{package_id}/tracking`
  - [ ] Update package tracking number
  - [ ] Update package label URL
  - [ ] Update package status (created → labeled)
- [ ] API: `PATCH /api/v1/packages/{package_id}/status`
  - [ ] Update package metadata (tracking events)
  - [ ] Update package metadata (shipping status)

### I.3 Shipping Service → Carrier APIs
- [ ] FedEx API: Generate label, track shipment
- [ ] UPS API: Generate label, track shipment
- [ ] DHL API: Generate label, track shipment
- [ ] Other carriers: As needed
- [ ] Error handling: API failures, retries, fallbacks

### I.4 Carrier → Shipping Service
- [ ] Webhook: Tracking updates
  - [ ] FedEx webhook
  - [ ] UPS webhook
  - [ ] DHL webhook
  - [ ] Other carriers
- [ ] Webhook security: Signature validation
- [ ] Webhook processing: Parse, validate, update

### I.5 Shipping Service → Order Service (Optional)
- [ ] Event: `shipment.delivered`
  - [ ] Action: Update order status
  - [ ] Action: Update order delivered_at

### I.6 Shipping Service → Notification Service (Optional)
- [ ] Event: `shipment.label_generated`
  - [ ] Action: Notify customer (tracking number available)
- [ ] Event: `shipment.shipped`
  - [ ] Action: Notify customer (package shipped)
- [ ] Event: `shipment.delivered`
  - [ ] Action: Notify customer (package delivered)

---

## Database Schema Updates

### D.1 Shipment Table (Shipping Service)
- [ ] Add `package_id` column (UUID, nullable initially)
- [ ] Add `shipping_method_id` column (UUID)
- [ ] Add `shipping_method_type` column (VARCHAR(20))
- [ ] Add `label_url` column (TEXT)
- [ ] Create indexes:
  - [ ] `idx_shipments_package_id`
  - [ ] `idx_shipments_shipping_method_id`
  - [ ] `idx_shipments_shipping_method_type`

### D.2 Shipment Model (Shipping Service)
- [ ] Update `Shipment` struct:
  - [ ] Add `PackageID` field
  - [ ] Add `ShippingMethodID` field
  - [ ] Add `ShippingMethodType` field
  - [ ] Add `LabelURL` field (if not exists)

### D.3 Migration Script
- [ ] Create migration: `XXX_add_shipment_fields.sql`
- [ ] Add columns with proper types
- [ ] Create indexes
- [ ] Add comments/documentation
- [ ] Test migration up/down

---

## Event Definitions

### E.1 Package Events (Fulfillment Service)
- [ ] `package.status_changed`
  - [ ] Payload: package_id, old_status, new_status, tracking_number, label_url
- [ ] `package.generated` (optional - if needed)
  - [ ] Payload: package_id, fulfillment_id, order_id

### E.2 Shipment Events (Shipping Service)
- [ ] `shipment.created`
  - [ ] Payload: shipment_id, fulfillment_id, order_id, package_id, carrier
- [ ] `shipment.label_generated`
  - [ ] Payload: shipment_id, tracking_number, label_url, tracking_url
- [ ] `shipment.status_changed`
  - [ ] Payload: shipment_id, old_status, new_status
- [ ] `shipment.tracking_updated`
  - [ ] Payload: shipment_id, tracking_number, status, events
- [ ] `shipment.delivered`
  - [ ] Payload: shipment_id, tracking_number, delivered_at

### E.3 Picklist Events (Fulfillment Service)
- [ ] `picklist.generated` (NEW - for auto-assignment)
  - [ ] Payload: picklist_id, fulfillment_id, order_id, shipping_method_id, shipping_method_type, warehouse_id, priority
- [ ] `picklist.status_changed`
  - [ ] Payload: picklist_id, old_status, new_status, assigned_to

---

## Worker Implementations

### W.1 Package Created Worker (Shipping Service)
- [ ] Listen: `package.status_changed` (new_status = `created`)
- [ ] Get package details from Fulfillment Service
- [ ] Get order details from Order Service
- [ ] Get shipping method details
- [ ] Create shipment record
- [ ] Error handling: Retries, dead letter queue

### W.2 Label Generation Worker (Shipping Service)
- [ ] Listen: `shipment.created` or `package.status_changed` (labeled)
- [ ] Check shipping method type
- [ ] If external → Generate label via carrier API
- [ ] Update shipment with label info
- [ ] Update package via Fulfillment Service API
- [ ] Error handling: Retries, fallbacks

### W.3 Auto-Assignment Worker (Shipping Service)
- [ ] Listen: `picklist.generated` event
- [ ] Check shipping method type
- [ ] If internal → Select picker and assign
- [ ] Call Fulfillment Service to assign picklist
- [ ] Error handling: Retries, fallbacks

### W.4 Tracking Update Worker (Shipping Service)
- [ ] Listen: Carrier webhooks
- [ ] Parse webhook payload
- [ ] Update shipment tracking
- [ ] Update package metadata via Fulfillment Service
- [ ] Error handling: Invalid webhooks, retries

### W.5 Polling Worker (Shipping Service)
- [ ] Periodic job: Poll carrier APIs
- [ ] Query shipments: Status = `shipped` or `in_transit`
- [ ] Call carrier API for each shipment
- [ ] Process tracking updates
- [ ] Error handling: API failures, rate limiting

---

## API Endpoints

### A.1 Fulfillment Service APIs
- [ ] `GET /api/v1/packages/{package_id}`
  - [ ] Returns: Package details
- [ ] `PATCH /api/v1/packages/{package_id}/tracking`
  - [ ] Updates: tracking_number, label_url, status
- [ ] `PATCH /api/v1/packages/{package_id}/status`
  - [ ] Updates: metadata (tracking events, shipping status)
- [ ] `POST /api/v1/picklists/{picklist_id}/assign`
  - [ ] Assigns: picker_id to picklist

### A.2 Shipping Service APIs
- [ ] `POST /api/v1/shipments`
  - [ ] Creates: New shipment
- [ ] `GET /api/v1/shipments/{shipment_id}`
  - [ ] Returns: Shipment details
- [ ] `PATCH /api/v1/shipments/{shipment_id}/label`
  - [ ] Updates: Label generation result
- [ ] `POST /api/v1/shipments/{shipment_id}/tracking`
  - [ ] Updates: Tracking events
- [ ] `POST /api/v1/webhooks/{carrier}`
  - [ ] Receives: Carrier webhooks

### A.3 Order Service APIs (If needed)
- [ ] `GET /api/v1/orders/{order_id}`
  - [ ] Returns: Order details (shipping method, address)

---

## Error Handling & Edge Cases

### E.1 Label Generation Failures
- [ ] Carrier API timeout → Retry with exponential backoff
- [ ] Carrier API error → Log error, queue for retry
- [ ] Invalid address → Return error, notify admin
- [ ] Carrier service down → Queue for retry, alert monitoring

### E.2 Webhook Failures
- [ ] Invalid webhook signature → Reject, log security event
- [ ] Webhook parsing error → Log error, return 400
- [ ] Shipment not found → Log warning, return 404
- [ ] Duplicate webhook → Idempotency check, ignore duplicate

### E.3 Service Communication Failures
- [ ] Fulfillment Service down → Retry with exponential backoff
- [ ] Order Service down → Cache order data, retry later
- [ ] Network timeout → Retry with backoff
- [ ] Rate limiting → Implement rate limiter, queue requests

### E.4 Package Split/Merge
- [ ] Package split → Create multiple shipments (one per package)
- [ ] Package merge → Update shipment to reference new package
- [ ] Handle: Shipment updates when packages change

### E.5 Package Cancellation
- [ ] Package cancelled → Cancel shipment
- [ ] Update shipment: Status = `cancelled`
- [ ] Cancel carrier label (if possible)
- [ ] Event published: `shipment.cancelled`

### E.6 Delivery Failures
- [ ] Delivery failed → Update shipment status = `failed`
- [ ] Handle return/retry logic
- [ ] Notify customer
- [ ] Update fulfillment status (if needed)

---

## Monitoring & Observability

### M.1 Metrics
- [ ] Event publishing rate (events/second)
- [ ] API call latency (p50, p95, p99)
- [ ] Label generation success rate (%)
- [ ] Webhook processing time
- [ ] End-to-end flow duration (picklist → delivered)
- [ ] Error rates by service/operation

### M.2 Logging
- [ ] Structured logging for all operations
- [ ] Log levels: INFO, WARN, ERROR
- [ ] Include: request_id, shipment_id, package_id, order_id
- [ ] Log all API calls (request/response)
- [ ] Log all events (published/received)

### M.3 Alerts
- [ ] High error rate (> 5%)
- [ ] Label generation failures (> 10%)
- [ ] Webhook processing failures
- [ ] Service communication failures
- [ ] Long-running shipments (> expected delivery time)

### M.4 Dashboards
- [ ] Shipment status distribution
- [ ] Label generation metrics
- [ ] Tracking update frequency
- [ ] Delivery time distribution
- [ ] Error rate trends

---

## Testing Checklist

### T.1 Unit Tests
- [ ] Shipment creation logic
- [ ] Label generation logic
- [ ] Picker selection algorithm
- [ ] Webhook parsing
- [ ] Status transition validation

### T.2 Integration Tests
- [ ] Package created → Shipment created
- [ ] Label generation → Package updated
- [ ] Webhook → Shipment updated
- [ ] Auto-assignment flow
- [ ] End-to-end flow (picklist → delivered)

### T.3 E2E Tests
- [ ] Complete flow: Picklist → Package → Shipment → Label → Shipped → Delivered
- [ ] Auto-assignment: Picklist generated → Auto assigned
- [ ] Error scenarios: API failures, retries
- [ ] Webhook scenarios: All carrier webhooks

---

## Documentation

### Doc.1 API Documentation
- [ ] Update OpenAPI spec for all endpoints
- [ ] Document request/response formats
- [ ] Document error codes and messages
- [ ] Add examples for each endpoint

### Doc.2 Event Documentation
- [ ] Document all events (payload, triggers)
- [ ] Document event consumers
- [ ] Document event flow diagrams

### Doc.3 Architecture Documentation
- [ ] Update architecture diagrams
- [ ] Document service interactions
- [ ] Document data flow
- [ ] Document error handling strategies

---

## Deployment Checklist

### Deploy.1 Database Migrations
- [ ] Review migration scripts
- [ ] Test migrations on staging
- [ ] Backup production database
- [ ] Run migrations in production
- [ ] Verify migration success

### Deploy.2 Service Deployments
- [ ] Deploy Fulfillment Service (if changes)
- [ ] Deploy Shipping Service (if changes)
- [ ] Deploy Workers (if new)
- [ ] Verify service health
- [ ] Verify event publishing

### Deploy.3 Configuration
- [ ] Update environment variables
- [ ] Configure carrier API credentials
- [ ] Configure webhook endpoints
- [ ] Configure retry policies
- [ ] Configure monitoring alerts

### Deploy.4 Verification
- [ ] Test label generation
- [ ] Test webhook processing
- [ ] Test auto-assignment
- [ ] Monitor error rates
- [ ] Verify metrics collection

---

## Summary

**Total Phases:** 7 (Picklist → Package → Shipment → Label → Ready → Shipped → Delivered)

**Key Integrations:**
- Fulfillment Service ↔ Shipping Service (events + APIs)
- Shipping Service ↔ Carrier APIs (label generation + tracking)
- Carrier ↔ Shipping Service (webhooks)

**Key Features:**
- Auto-assignment for internal shipping methods
- Automatic label generation for external methods
- Real-time tracking updates via webhooks
- Polling fallback for webhook failures

**Critical Paths:**
1. Package created → Shipment created → Label generated
2. Package shipped → Tracking updates → Delivery confirmed
3. Picklist generated → Auto-assignment (internal methods)

