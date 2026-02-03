# Core Services Documentation

**Last Updated**: 2026-01-27  
**Architecture**: Microservices  
**Total Services**: 8 Core Services

---

## 🎯 Overview

Core Services là tập hợp các microservices cốt lõi trong hệ thống e-commerce, xử lý các business domains chính và cung cấp foundation cho toàn bộ platform.

### Service Split Architecture (2026)

Hệ thống đã được tối ưu hóa thông qua việc tách tách Order Service thành 3 services chuyên biệt:

```
┌─────────────────────────────────────────────────────────────┐
│                    CORE SERVICES ECOSYSTEM                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐    │
│  │ Cart Service│    │Checkout      │    │Order Service│    │
│  │             │───▶│Service       │───▶│             │    │
│  │ (Shopping)  │    │(Orchestration)│    │(Lifecycle)  │    │
│  └─────────────┘    └──────────────┘    └─────────────┘    │
│                                                │            │
│                                                ▼            │
│                                         ┌─────────────┐    │
│                                         │Return       │    │
│                                         │Service      │    │
│                                         │(Post-order) │    │
│                                         └─────────────┘    │
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐    │
│  │Auth Service │    │Customer      │    │Payment      │    │
│  │             │    │Service       │    │Service      │    │
│  │(Identity)   │    │(Profile)     │    │(Financial)  │    │
│  └─────────────┘    └──────────────┘    └─────────────┘    │
│                                                             │
│                    ┌──────────────┐                        │
│                    │Catalog       │                        │
│                    │Service       │                        │
│                    │(Products)    │                        │
│                    └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📚 Service Documentation

### 🛒 E-commerce Core Services

#### 1. [Cart Service](./cart-service.md) 🆕
- **Purpose**: Shopping cart management
- **Port**: HTTP `:8012`, gRPC `:9012`
- **Database**: `cart_db`
- **Key Features**: 
  - Session-based cart management
  - Real-time pricing integration
  - Cart persistence and recovery
  - Promotion application
- **Split From**: Order Service (2026)

#### 2. [Checkout Service](./checkout-service.md) 🆕
- **Purpose**: Checkout orchestration and session management
- **Port**: HTTP `:8005`, gRPC `:9005`
- **Database**: `checkout_db`
- **Key Features**:
  - Checkout session management
  - Saga pattern orchestration
  - Payment coordination
  - Order creation workflow
- **Split From**: Order Service (2026)

#### 3. [Order Service](./order-service.md) ✅ Updated
- **Purpose**: Order lifecycle management (post-checkout)
- **Port**: HTTP `:8004`, gRPC `:9004`
- **Database**: `order_db`
- **Key Features**:
  - Order status management
  - Order modifications and cancellations
  - Fulfillment coordination
  - Order analytics
- **Updated**: Refocused after service split

#### 4. [Return Service](./return-service.md) 🆕
- **Purpose**: Return and refund processing
- **Port**: HTTP `:8006`, gRPC `:9006`
- **Database**: `return_db`
- **Key Features**:
  - Return request management
  - Refund processing
  - Restock coordination
  - Return analytics
- **Split From**: Order Service (2026)

### 👤 Identity & Customer Services

#### 5. [Auth Service](./auth-service.md)
- **Purpose**: Authentication and authorization
- **Port**: HTTP `:8001`, gRPC `:9001`
- **Database**: `auth_db`
- **Key Features**:
  - JWT token management
  - Role-based access control
  - Session management
  - OAuth integration

#### 6. [User Service](./user-service.md)
- **Purpose**: User profile and account management
- **Port**: HTTP `:8003`, gRPC `:9003`
- **Database**: `user_db`
- **Key Features**:
  - User registration and profiles
  - Account management
  - User preferences
  - Profile analytics

#### 7. [Customer Service](./customer-service.md)
- **Purpose**: Customer data and relationship management
- **Port**: HTTP `:8003`, gRPC `:9003`
- **Database**: `customer_db`
- **Key Features**:
  - Customer profiles
  - Address management
  - Customer segmentation
  - Customer analytics

### 🛍️ Product & Payment Services

#### 8. [Catalog Service](./catalog-service.md)
- **Purpose**: Product catalog and inventory management
- **Port**: HTTP `:8002`, gRPC `:9002`
- **Database**: `catalog_db`
- **Key Features**:
  - Product management
  - Category hierarchy
  - Product search and filtering
  - Inventory tracking

#### 9. [Payment Service](./payment-service.md)
- **Purpose**: Payment processing and financial operations
- **Port**: HTTP `:8007`, gRPC `:9007`
- **Database**: `payment_db`
- **Key Features**:
  - Payment processing
  - Multiple payment gateways
  - Refund management
  - Payment analytics

#### 10. [Promotion Service](./promotion-service.md)
- **Purpose**: Promotional campaigns, discounts, and coupon management
- **Port**: HTTP `:8003`, gRPC `:9003`
- **Database**: `promotion_db`
- **Key Features**:
  - Campaign management
  - Promotion rules (cart & catalog)
  - Discount calculation engine
  - Coupon generation and validation
  - Usage tracking and analytics

---

## 🔄 Service Interaction Patterns

### 1. Shopping Flow
```
Customer → Cart Service → Checkout Service → Order Service → Fulfillment
```

### 2. Return Flow
```
Customer → Return Service → Payment Service (refund) + Warehouse Service (restock)
                ↓
         Order Service (status update)
```

### 3. Authentication Flow
```
Frontend → Auth Service → User/Customer Service → Business Services
```

### 4. Product Discovery Flow
```
Frontend → Catalog Service → Pricing Service → Cart Service
```

---

## 📊 Service Metrics & SLAs

| Service | Availability SLA | Response Time (P95) | Throughput Target |
|---------|------------------|---------------------|-------------------|
| **Cart Service** | 99.9% | <50ms | 500 req/sec |
| **Checkout Service** | 99.9% | <1.5s | 100 req/sec |
| **Order Service** | 99.5% | <200ms | 200 req/sec |
| **Return Service** | 99.0% | <500ms | 50 req/sec |
| **Auth Service** | 99.9% | <100ms | 1000 req/sec |
| **User Service** | 99.5% | <150ms | 300 req/sec |
| **Customer Service** | 99.5% | <150ms | 300 req/sec |
| **Catalog Service** | 99.5% | <100ms | 800 req/sec |
| **Payment Service** | 99.9% | <2s | 100 req/sec |

---

## 🚀 Service Split Benefits (2026)

### Before Split (Monolithic Order Service)
- ❌ Single point of failure for all order operations
- ❌ Difficult to scale individual components
- ❌ Complex deployments affecting multiple domains
- ❌ Team dependencies and coordination overhead

### After Split (Specialized Services)
- ✅ **Cart Service**: Optimized for high-frequency, low-latency operations
- ✅ **Checkout Service**: Specialized for complex orchestration workflows
- ✅ **Order Service**: Focused on order lifecycle management
- ✅ **Return Service**: Dedicated to customer service operations
- ✅ **Independent Scaling**: Each service scales based on its specific needs
- ✅ **Team Autonomy**: Dedicated teams for each domain
- ✅ **Fault Isolation**: Failures in one service don't affect others

---

## 🛠️ Development Guidelines

### Service Communication
- **Synchronous**: gRPC for real-time operations (cart → checkout → order)
- **Asynchronous**: Dapr Pub/Sub for event-driven workflows
- **Circuit Breakers**: All inter-service calls protected
- **Retry Logic**: Exponential backoff with jitter

### Data Consistency
- **Eventual Consistency**: Between services via events
- **Strong Consistency**: Within service boundaries
- **Saga Pattern**: For distributed transactions (checkout flow)
- **Compensation**: For failure scenarios

### Monitoring & Observability
- **Distributed Tracing**: OpenTelemetry across all services
- **Metrics**: Prometheus with service-specific dashboards
- **Health Checks**: Liveness and readiness probes
- **Alerting**: Service-specific SLA monitoring

---

## 📋 Migration Status

### ✅ Completed (2026)
- [x] **Cart Service**: Extracted from Order Service
- [x] **Checkout Service**: Extracted from Order Service  
- [x] **Return Service**: Extracted from Order Service
- [x] **Order Service**: Refactored and focused
- [x] **Documentation**: Updated for all services

### 🔄 In Progress
- [ ] **Performance Optimization**: Load testing and tuning
- [ ] **Monitoring Enhancement**: Advanced metrics and alerting
- [ ] **Security Hardening**: Service-to-service authentication

### 📅 Future Roadmap
- [ ] **Cart Service**: AI-powered recommendations
- [ ] **Checkout Service**: Multi-step checkout flows
- [ ] **Return Service**: Automated return processing
- [ ] **Order Service**: Advanced order analytics

---

## 🔗 Related Documentation

### Architecture Documentation
- [System Architecture Overview](../../01-architecture/system-architecture.md)
- [API Architecture](../../01-architecture/api-architecture.md)
- [Database Architecture](../../01-architecture/database-architecture.md)

### Development Standards
- [Common Package Usage](../../07-development/standards/common-package-usage.md)
- [Development Review Checklist](../../07-development/standards/development-review-checklist.md)
- [API Design Standards](../../07-development/standards/api-design-standards.md)

### Operations
- [Deployment Guide](../../06-operations/deployment-guide.md)
- [Monitoring Guide](../../06-operations/monitoring-guide.md)
- [Troubleshooting Guide](../../06-operations/troubleshooting-guide.md)

---

**Service Architecture**: Microservices with Domain-Driven Design  
**Communication**: gRPC + Event-Driven (Dapr)  
**Data Storage**: PostgreSQL per service + Redis caching  
**Deployment**: Kubernetes with Helm charts  
**Monitoring**: Prometheus + Grafana + OpenTelemetry