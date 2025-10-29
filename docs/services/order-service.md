# Order Service

## Description
Service that processes orders from creation to completion.

## Outbound Data
- Order data and order details
- Payment reference
- Fulfillment instructions
- Order status updates

## Consumers (Services that use this data)

### Shipping Service
- **Purpose**: Create shipment entities (Fulfillment) per order
- **Data Received**: Order details, shipping address, fulfillment requirements

### Notification Service
- **Purpose**: Customer & admin updates
- **Data Received**: Order status, customer info, notification triggers

### Warehouse & Inventory
- **Purpose**: Update reserved stock quantities
- **Data Received**: Product quantities, stock adjustments

### Customer Service
- **Purpose**: Store order history
- **Data Received**: Order records, customer purchase history

### Promotion Service
- **Purpose**: Track applied coupons or promotions
- **Data Received**: Promotion usage, discount applications

## Data Sources
- **Product Service**: Product validation and pricing
- **Promotion Service**: Discount rules and applications
- **Warehouse & Inventory**: Stock availability
- **Customer Service**: Customer details and shipping info

## Main APIs
- `POST /orders` - Create new order
- `GET /orders/{id}` - Get order information
- `PUT /orders/{id}/status` - Update order status
- `GET /orders/customer/{id}` - Get customer orders