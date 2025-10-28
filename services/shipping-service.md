# Shipping Service (with Fulfillment Entity)

## Description
Service that manages shipping and fulfillment, including last-mile and first-mile logistics.

## Main Entities

### Fulfillment
- Represents a physical delivery unit (package/route)
- Manages delivery workflow from warehouse to customer

### Carrier/Label/Tracking
- Manages delivery flow
- Integrates last-mile/first-mile integrations
- Tracking and proof of delivery

## Outbound Data
- Shipment details and tracking info
- Delivery status updates
- Proof of delivery
- Return processing status

## Consumers (Services that use this data)

### Order Service
- **Purpose**: Receive shipment status updates
- **Data Received**: Delivery status, tracking updates, completion status

### Notification Service
- **Purpose**: Send delivery updates to customers
- **Data Received**: Shipping notifications, delivery confirmations

### Warehouse & Inventory
- **Purpose**: Sync stock after delivery or return
- **Data Received**: Delivered quantities, return quantities

## Data Sources
- **Order Service**: Order details and fulfillment instructions
- **Warehouse & Inventory**: Product availability for fulfillment

## Main APIs
- `POST /shipments` - Create new shipment
- `GET /shipments/{id}` - Get shipment information
- `GET /shipments/{id}/tracking` - Get tracking info
- `PUT /shipments/{id}/status` - Update delivery status
- `POST /fulfillment` - Create fulfillment entity
- `GET /fulfillment/{id}` - Get fulfillment details