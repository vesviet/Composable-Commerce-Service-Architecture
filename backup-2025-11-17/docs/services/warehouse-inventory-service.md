# 🏭 Warehouse Inventory Service

## Overview
Service này quản lý **nhà phân phối (Distributor)**, **kho hàng (Warehouse)** và **tồn kho (Inventory)** trong hệ thống thương mại điện tử hoặc logistics microservice. Đảm bảo tính nhất quán tồn kho, truy vết luồng hàng, và điều phối phân phối.

## 🎯 Core Responsibilities
- Quản lý hệ thống **kho hàng**, **nhà phân phối**, và **tồn kho sản phẩm**
- Đảm bảo **tính nhất quán tồn kho**, **truy vết luồng hàng**, và **điều phối phân phối**
- Cung cấp API trung tâm cho các service khác như `order-service`, `procurement-service`, `shipment-service`

## 🏗️ Domain Model

### Core Entities

#### Distributor Management
- **Distributor**: Nhà phân phối quản lý nhiều kho trong khu vực cụ thể
- **DistributorRegion**: Vùng địa lý mà nhà phân phối phụ trách
- **DistributorWarehouse**: Mối quan hệ giữa nhà phân phối và kho hàng

#### Warehouse Management
- **Warehouse**: Cơ sở lưu trữ vật lý chứa các mặt hàng tồn kho
- **WarehouseLocation**: Vị trí cụ thể trong kho (kệ, tầng, khu vực)
- **WarehouseTransaction**: Giao dịch kho hàng (nhập, xuất, chuyển kho)

#### Inventory Management
- **StockItem**: Sản phẩm cụ thể với SKU được lưu trữ trong kho
- **StockTransaction**: Bản ghi di chuyển tồn kho (inbound, outbound, transfer, adjustment)
- **StockAdjustment**: Điều chỉnh thủ công số lượng tồn kho
- **StockReservation**: Giữ chỗ tạm thời tồn kho cho đơn hàng đang chờ xử lý

## 🔄 Business Flows

### Stock Reservation Flow
```
Order Service → Request Stock Reservation → Warehouse Inventory Service
Warehouse Inventory Service → Confirm/Reject Reservation → Order Service
```

### Inbound Stock Flow
```
Procurement Service → Notify Inbound Shipment → Warehouse
Warehouse → Increase Stock (StockTransaction: IN) → Inventory
Inventory → Event "StockUpdated" → Order Service, Procurement Service
```

### Outbound Stock Flow
```
Shipment Service → Notify Outbound Shipment → Warehouse
Warehouse → Decrease Stock (StockTransaction: OUT) → Inventory
Inventory → Event "StockUpdated" → Order Service, Procurement Service
```

### Stock Transfer Flow
```
Distributor → Request Stock Transfer → Warehouse
Warehouse → Adjust Stock (TRANSFER) → Inventory
Inventory → Event "StockUpdated" → Relevant Services
```

## 📡 Integration Points

### Outbound Data
- **Real-time stock levels** across all warehouses
- **Reserved quantities** for pending orders
- **Availability by location/warehouse** for fulfillment optimization
- **Stock movement history** for audit and analytics
- **Stock alerts** for low inventory and threshold breaches
- **Inventory analytics** for business intelligence

### Consumers (Services that use this data)

#### Order Service
- **Purpose**: Reserve and deduct stock during checkout process
- **Data Received**: Stock availability, reservation status, inventory updates
- **Events**: StockUpdated, StockReserved, StockReleased

#### Procurement Service
- **Purpose**: Monitor stock levels for replenishment decisions
- **Data Received**: Current stock levels, stock movement trends, low stock alerts
- **Events**: StockUpdated, LowStockAlert

#### Shipment Service
- **Purpose**: Ensure product availability for fulfillment and optimize shipping
- **Data Received**: Stock levels by warehouse, reserved quantities, warehouse locations
- **Events**: StockUpdated, StockReserved

#### Analytics Service
- **Purpose**: Generate inventory reports and business intelligence
- **Data Received**: Historical stock data, transaction records, inventory metrics
- **Events**: StockUpdated, InventoryAdjusted

### Data Sources
- **Procurement Service**: Inbound shipment notifications, purchase order updates
- **Shipment Service**: Outbound delivery confirmations, return notifications
- **Order Service**: Stock reservation requests, order cancellations
- **Manual Adjustments**: Stock corrections, cycle count results

## 🔌 Main APIs

### Distributor Management
- `GET /distributors` - List all distributors
- `POST /distributors` - Create new distributor
- `GET /distributors/{id}` - Get distributor details
- `PUT /distributors/{id}` - Update distributor information
- `GET /distributors/{id}/warehouses` - Get warehouses managed by distributor

### Warehouse Management
- `GET /warehouses` - List all warehouses
- `POST /warehouses` - Create new warehouse
- `GET /warehouses/{id}` - Get warehouse details
- `PUT /warehouses/{id}` - Update warehouse information
- `GET /warehouses/{id}/locations` - Get warehouse locations
- `POST /warehouses/{id}/locations` - Add warehouse location

### Inventory Management
- `GET /inventory/{productId}` - Get product inventory across all warehouses
- `GET /inventory/warehouse/{warehouseId}` - Get inventory by warehouse
- `GET /inventory/warehouse/{warehouseId}/product/{productId}` - Get specific product inventory in warehouse
- `POST /inventory/reserve` - Reserve stock for order
- `POST /inventory/release` - Release reserved stock
- `POST /inventory/adjust` - Adjust inventory levels
- `GET /inventory/transactions` - Get stock transaction history
- `GET /inventory/reservations` - Get active reservations

### Stock Transaction Management
- `POST /transactions/inbound` - Record inbound stock transaction
- `POST /transactions/outbound` - Record outbound stock transaction
- `POST /transactions/transfer` - Record stock transfer between warehouses
- `GET /transactions/{id}` - Get transaction details
- `GET /transactions/history` - Get transaction history with filters

### Analytics & Reporting
- `GET /analytics/stock-levels` - Current stock levels report
- `GET /analytics/stock-movements` - Stock movement analytics
- `GET /analytics/inventory-turnover` - Inventory turnover metrics
- `GET /analytics/warehouse-utilization` - Warehouse utilization reports

## 📊 Key Metrics
- **Stock Accuracy**: Percentage of accurate inventory records
- **Inventory Turnover**: Rate of inventory movement
- **Warehouse Utilization**: Percentage of warehouse capacity used
- **Reservation Success Rate**: Percentage of successful stock reservations
- **Transaction Processing Time**: Average time to process stock transactions
- **Stock Availability**: Percentage of products in stock across warehouses

## 🔒 Business Rules
- Stock reservations automatically expire after configurable timeout
- Stock adjustments require proper authorization and reason codes
- Negative stock levels are not allowed (except for specific business cases)
- Stock transfers must maintain audit trails between source and destination
- Inventory consistency must be maintained across all operations
- Real-time stock updates must be propagated to dependent services