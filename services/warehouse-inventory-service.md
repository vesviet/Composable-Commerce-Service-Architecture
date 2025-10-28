# Warehouse & Inventory Service

## Description
Service that manages warehouses, inventory and availability by location.

## Outbound Data
- Real-time stock levels
- Reserved quantities
- Availability by location/warehouse
- Stock movement history

## Consumers (Services that use this data)

### Order Service
- **Purpose**: Reserve and deduct stock during checkout process
- **Data Received**: Stock availability, reservation status

### Shipping Service
- **Purpose**: Ensure product availability for fulfillment
- **Data Received**: Stock levels, warehouse locations

### Product Service
- **Purpose**: Display availability info
- **Data Received**: Real-time stock status

## Data Sources
- **Shipping Service**: Stock updates after delivery or return
- **Order Service**: Stock reservations and deductions

## Main APIs
- `GET /inventory/{productId}` - Get product inventory
- `POST /inventory/reserve` - Reserve stock for order
- `POST /inventory/release` - Release reserved stock
- `GET /inventory/warehouse/{id}` - Get inventory by warehouse
- `POST /inventory/adjust` - Adjust inventory levels