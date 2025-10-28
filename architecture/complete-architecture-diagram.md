# Complete Microservices Architecture Diagram

## System Architecture Overview

```mermaid
graph TB
    %% Presentation Layer
    subgraph "Presentation Layer"
        UI[Frontend/Storefront]
        ADMIN[Admin Dashboard]
        MOBILE[Mobile App]
        API[API Gateway/BFF]
    end
    
    %% Application Services Layer
    subgraph "Application Services Layer"
        subgraph "Core Business Services"
            PROD[Product Service]
            PRICE[Pricing Service]
            PROMO[Promotion Service]
            ORDER[Order Service]
            PAY[Payment Service]
            SHIP[Shipping Service]
            CUST[Customer Service]
            REV[Review Service]
            INV[Warehouse & Inventory]
        end
    end
    
    %% Infrastructure Services Layer
    subgraph "Infrastructure Services Layer"
        AUTH[Auth Service IAM]
        USER[User Service]
        SEARCH[Search Service]
        NOTIF[Notification Service]
        EB[Event Bus]
        CACHE[Cache Layer]
        STORAGE[File Storage/CDN]
        MONITOR[Monitoring & Logging]
    end
    
    %% External Systems
    subgraph "External Systems"
        PAYGATE[Payment Gateways]
        CARRIERS[Shipping Carriers]
        EMAIL[Email/SMS Providers]
        ELASTIC[Elasticsearch]
        REDIS[Redis Cluster]
    end
    
    %% Connections - Presentation to API
    UI --> API
    ADMIN --> API
    MOBILE --> API
    
    %% API Gateway to Services
    API --> AUTH
    API --> PROD
    API --> SEARCH
    API --> ORDER
    API --> CUST
    
    %% Core Service Interactions
    PROD --> PRICE
    PROMO --> PRICE
    CUST --> PRICE
    INV --> PRICE
    
    PRICE --> ORDER
    INV --> ORDER
    CUST --> ORDER
    ORDER --> PAY
    ORDER --> SHIP
    ORDER --> REV
    
    %% Search Service Inputs
    PROD --> SEARCH
    PRICE --> SEARCH
    REV --> SEARCH
    INV --> SEARCH
    
    %% Event Bus Connections
    ORDER --> EB
    PAY --> EB
    SHIP --> EB
    INV --> EB
    CUST --> EB
    
    EB --> NOTIF
    EB --> SEARCH
    EB --> CACHE
    
    %% Infrastructure Connections
    AUTH --> CUST
    AUTH --> USER
    USER --> AUTH
    NOTIF --> EMAIL
    PAY --> PAYGATE
    SHIP --> CARRIERS
    SEARCH --> ELASTIC
    CACHE --> REDIS
    
    %% Monitoring
    MONITOR -.-> PROD
    MONITOR -.-> ORDER
    MONITOR -.-> PAY
    MONITOR -.-> SHIP
    
    %% Cache Connections
    CACHE -.-> PRICE
    CACHE -.-> PROD
    CACHE -.-> SEARCH
    
    %% Storage
    PROD --> STORAGE
    REV --> STORAGE
```

## Service Communication Patterns

### 1. Synchronous Communication (REST APIs)
```mermaid
sequenceDiagram
    participant Client
    participant API as API Gateway
    participant Auth as Auth Service
    participant Order as Order Service
    participant Pricing as Pricing Service
    participant Payment as Payment Service
    
    Client->>API: Create Order Request
    API->>Auth: Validate Token
    Auth-->>API: Token Valid
    API->>Order: Create Order
    Order->>Pricing: Calculate Final Price
    Pricing-->>Order: Final Price
    Order->>Payment: Process Payment
    Payment-->>Order: Payment Confirmed
    Order-->>API: Order Created
    API-->>Client: Order Response
```

### 2. Asynchronous Communication (Event Bus)
```mermaid
sequenceDiagram
    participant Order as Order Service
    participant EventBus as Event Bus
    participant Shipping as Shipping Service
    participant Inventory as Inventory Service
    participant Notification as Notification Service
    
    Order->>EventBus: Publish "order.created"
    EventBus->>Shipping: order.created event
    EventBus->>Inventory: order.created event
    EventBus->>Notification: order.created event
    
    Shipping->>EventBus: Publish "shipment.created"
    EventBus->>Order: shipment.created event
    EventBus->>Notification: shipment.created event
```

## Data Flow Architecture

### 1. Product Discovery Flow
```mermaid
flowchart LR
    A[User Search] --> B[Search Service]
    B --> C[Elasticsearch]
    B --> D[Cache Layer]
    
    E[Product Service] --> B
    F[Pricing Service] --> B
    G[Review Service] --> B
    H[Inventory Service] --> B
    
    B --> I[Search Results]
```

### 2. Order Processing Flow
```mermaid
flowchart TD
    A[Add to Cart] --> B[Pricing Service]
    B --> C[Order Service]
    C --> D[Payment Service]
    D --> E[Shipping Service]
    E --> F[Inventory Update]
    F --> G[Notification Service]
    
    H[Event Bus] -.-> C
    H -.-> E
    H -.-> F
    H -.-> G
```

## Technology Stack by Layer

### Presentation Layer
- **Frontend**: React/Vue.js, Mobile Apps
- **API Gateway**: Kong, AWS API Gateway, or Nginx
- **Load Balancer**: HAProxy, AWS ALB

### Application Services
- **Runtime**: Node.js, Java Spring Boot, Python FastAPI
- **Databases**: PostgreSQL, MongoDB per service
- **API**: REST, GraphQL

### Infrastructure Services
- **Message Queue**: Apache Kafka, RabbitMQ
- **Cache**: Redis Cluster
- **Search**: Elasticsearch
- **Storage**: AWS S3, MinIO
- **Monitoring**: Prometheus, Grafana, ELK Stack

### Deployment & Orchestration
- **Containers**: Docker
- **Orchestration**: Kubernetes
- **Service Mesh**: Istio, Linkerd
- **CI/CD**: Jenkins, GitLab CI, GitHub Actions

## Security Architecture

```mermaid
flowchart TD
    A[Client Request] --> B[API Gateway]
    B --> C[Rate Limiting]
    C --> D[Auth Service]
    D --> E[JWT Validation]
    E --> F[Service Authorization]
    F --> G[Business Logic]
    
    H[WAF] --> B
    I[TLS/SSL] --> A
    J[Service Mesh Security] --> G
```

## Scalability & Performance

### Horizontal Scaling
- Each service can scale independently
- Load balancing across service instances
- Database sharding per service

### Caching Strategy
- **L1 Cache**: Application-level caching
- **L2 Cache**: Redis distributed cache
- **L3 Cache**: CDN for static content

### Performance Optimization
- Async processing via Event Bus
- Database read replicas
- Connection pooling
- Circuit breaker patterns