# Event-Driven Flow Diagram

## Main Event Flow Diagram

```mermaid
flowchart TD
    %% Frontend Layer
    UI[Frontend/Storefront] --> API[API Gateway/BFF]
    
    %% Authentication Flow
    API --> AUTH[Auth Service]
    AUTH --> CUST[Customer Service]
    
    %% Core Business Flow
    API --> SEARCH[Search Service]
    API --> CAT[Catalog Service]
    API --> PRICE[Pricing Service]
    
    %% Pricing Calculation
    CAT -->|SKU & Catalog Info| PRICE
    PROMO[Promotion Service] -->|Discount Rules| PRICE
    CUST -->|Customer Tier| PRICE
    INV[Warehouse & Inventory] -->|Stock Info| PRICE
    
    %% Order Processing
    PRICE -->|Final Price| ORDER[Order Service]
    INV -->|Availability| ORDER
    ORDER -->|Payment Request| PAY[Payment Service]
    PAY -->|Payment Status| ORDER
    
    %% Fulfillment Flow
    ORDER -->|Order Created| SHIP[Shipping Service]
    SHIP -->|Fulfillment + Tracking| ORDER
    SHIP -->|Stock Sync| INV
    
    %% Search & Reviews
    CAT -->|Catalog Data| SEARCH
    PRICE -->|Pricing Data| SEARCH
    REV[Review Service] -->|Ratings| SEARCH
    ORDER -->|Purchase Verification| REV
    
    %% Notifications
    ORDER -->|Order Updates| NOTIF[Notification Service]
    SHIP -->|Delivery Status| NOTIF
    PAY -->|Payment Status| NOTIF
    AUTH -->|Security Alerts| NOTIF
    
    %% Event Bus (Async Communication)
    EB[Event Bus] -.->|Events| ORDER
    EB -.->|Events| INV
    EB -.->|Events| NOTIF
    EB -.->|Events| SEARCH
    
    %% Cache Layer
    CACHE[Cache Layer] -.->|Cached Data| PRICE
    CACHE -.->|Cached Data| CAT
    CACHE -.->|Cached Data| SEARCH
```

## Flow Description

### 1. User Authentication & Authorization
- **Frontend** communicates through **API Gateway**
- **Auth Service** handles authentication and authorization
- **Customer Service** manages user profiles and preferences

### 2. Product Discovery & Search
- **Search Service** provides fast product discovery with Elasticsearch
- **Catalog Service** supplies product catalog data to search index
- **Review Service** contributes ratings and reviews to search results

### 3. Pricing Calculation (SKU + Warehouse Based)
- **Pricing Service** acts as central price calculator
- Receives SKU and product info from **Catalog Service**
- Applies discount rules from **Promotion Service** (per SKU + Warehouse)
- Considers customer tiers from **Customer Service**
- Uses warehouse-specific pricing from **Warehouse & Inventory**

### 4. Order Processing
- **Order Service** orchestrates the complete order lifecycle
- **Payment Service** handles secure payment processing
- **Warehouse & Inventory** manages stock reservation and allocation

### 5. Fulfillment & Delivery
- **Shipping Service** manages fulfillment and carrier integration
- Updates inventory levels after delivery
- Provides tracking information

### 6. Communication & Events
- **Event Bus** enables asynchronous communication between services
- **Notification Service** sends multi-channel notifications
- **Cache Layer** optimizes performance for frequently accessed data

### 7. Observability
- **Monitoring & Logging** provides system observability
- **File Storage/CDN** handles media and static content delivery