# Service Index - Microservices Platform

**Last Updated**: 2026-02-07  
**Total Services**: 23

## Service Categories

### Core Business Services (13)
Services that handle core business operations and transactions.

### Platform Services (5)
Infrastructure and platform-level services.

### Operational Services (5)
Supporting services for operations and management.

---

## Core Business Services

### 1. Auth Service
- **Version**: v1.1.1
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8000, gRPC 9000
- **Description**: Authentication, authorization, JWT token management, OAuth2, MFA
- **Key Features**:
  - JWT Authentication (RS256)
  - OAuth2 Social Login (Google, Facebook, GitHub)
  - Multi-Factor Authentication (TOTP)
  - Password Management
  - Session Management
  - Rate Limiting & Security
- **Dependencies**: PostgreSQL, Redis
- **Documentation**: [auth/README.md](auth/README.md)

### 2. User Service
- **Version**: v1.0.6
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8001, gRPC 9001
- **Description**: User profiles, roles, permissions, service access control
- **Key Features**:
  - User Profile Management
  - Role & Permission Management (RBAC)
  - Service Access Control
  - User Preferences
  - Authentication Integration
- **Dependencies**: PostgreSQL, Redis, Consul
- **Documentation**: [user/README.md](user/README.md)

### 3. Customer Service
- **Version**: v1.1.4
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8003, gRPC 9003
- **Description**: Customer profiles, addresses, segments, preferences
- **Key Features**:
  - Profile Management
  - Address Book
  - Customer Segmentation
  - GDPR-compliant Preferences
  - Event-Driven Architecture
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [customer/README.md](customer/README.md)

### 4. Catalog Service
- **Version**: v1.2.8
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8001, gRPC 9001
- **Description**: Product catalog with EAV attributes, categories, brands, CMS
- **Key Features**:
  - Product Management (CRUD, bulk operations)
  - EAV Attribute System (Tier 1 Hot + Tier 2 EAV)
  - Category & Brand Management
  - CMS Pages
  - Product Visibility Rules
  - Event Publishing
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [catalog/README.md](catalog/README.md)

### 5. Pricing Service
- **Version**: v1.1.4
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8002, gRPC 9002
- **Description**: Dynamic pricing, discount rules, tax calculation
- **Key Features**:
  - Dynamic Pricing
  - SKU & Warehouse Pricing
  - Discount Management
  - Tax Calculation
  - Price Rules Engine
  - Bulk Pricing
  - Multi-Currency Support
  - Price History
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [pricing/README.md](pricing/README.md)

### 6. Promotion Service
- **Version**: v1.1.2
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8000, gRPC 9000
- **Description**: Promotional campaigns, discount rules, coupon system
- **Key Features**:
  - Campaign Management
  - Cart Rules & Catalog Rules
  - Coupon Management
  - BOGO Promotions
  - Tiered Discounts
  - Usage Tracking
  - Analytics
- **Dependencies**: PostgreSQL, Redis, Consul
- **Documentation**: [promotion/README.md](promotion/README.md)

### 7. Checkout Service
- **Version**: v1.3.1
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8000, gRPC 9000
- **Description**: Cart management and checkout orchestration
- **Key Features**:
  - Cart Management (session-based, multi-warehouse)
  - Checkout Orchestration
  - Order Preview
  - Promotion Engine
  - Shipping Integration
  - Payment Method Validation
  - Automatic Customer Authentication
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [checkout/README.md](checkout/README.md)

### 8. Order Service
- **Version**: v1.2.0
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8001, gRPC 9001
- **Description**: Order lifecycle management from creation to fulfillment
- **Key Features**:
  - Order Lifecycle Management
  - Status Management (8 states)
  - Order Editing (limited)
  - Cancellation & Refunds
  - Event-Driven Architecture
  - Multi-Service Integration (11+ clients)
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [order/README.md](order/README.md)

### 9. Payment Service
- **Version**: v1.1.0
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8004, gRPC 9004
- **Description**: Payment processing, payment methods, refunds
- **Key Features**:
  - Payment Processing (Credit/Debit, E-wallet, Bank Transfer, COD)
  - Payment Gateways (Stripe, PayPal, VNPay, MoMo)
  - Payment Methods Management
  - Refunds (Full/Partial)
  - PCI DSS Compliance
  - Fraud Detection
  - Reconciliation
- **Dependencies**: PostgreSQL, Redis
- **Documentation**: [payment/README.md](payment/README.md)

### 10. Warehouse Service
- **Version**: v1.1.3
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8008, gRPC 9008
- **Description**: Warehouse, inventory tracking, stock movements, reservations
- **Key Features**:
  - Multi-Warehouse Management
  - Real-Time Inventory Tracking
  - Stock Movement Tracking
  - Reservation System
  - Throughput Capacity Management
  - Time Slot Management
  - Low Stock Alerts
  - Event-Driven Updates
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [warehouse/README.md](warehouse/README.md)

### 11. Fulfillment Service
- **Version**: v1.1.0
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8005, gRPC 9005
- **Description**: Order fulfillment, picking, packing, shipping workflow
- **Key Features**:
  - Order Fulfillment Management
  - Picking & Packing Workflow
  - Shipping Coordination
  - Fulfillment Status Tracking
- **Dependencies**: PostgreSQL, Warehouse Service, Catalog Service
- **Documentation**: [fulfillment/README.md](fulfillment/README.md)

### 12. Shipping Service
- **Version**: v1.1.2
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8000, gRPC 9000
- **Description**: Shipping methods, rates, labels, shipment tracking
- **Key Features**:
  - Multi-Carrier Integration (GHN, Grab, VNPay, MoMo)
  - Shipping Rates (dynamic calculation with caching)
  - JWT Authentication
  - Redis Caching
  - Real-time Tracking
  - Webhook-based Updates
- **Dependencies**: PostgreSQL, Redis
- **Documentation**: [shipping/README.md](shipping/README.md)

### 13. Return Service
- **Version**: v1.0.1
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8006, gRPC 9006
- **Description**: Product returns, exchanges, refunds
- **Key Features**:
  - Return Request Management
  - Exchange Processing
  - Refund Processing
  - Restock Coordination
  - Return Analytics
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [return/README.md](return/README.md)

---

## Platform Services

### 14. Gateway Service
- **Version**: Latest
- **Status**: ✅ Production Ready
- **Ports**: HTTP 80
- **Description**: API Gateway for centralized routing, authentication, security
- **Key Features**:
  - Request Routing
  - Authentication & Authorization
  - Rate Limiting
  - CORS Handling
  - Circuit Breaker
  - BFF (Backend for Frontend)
- **Dependencies**: Redis, JWT
- **Documentation**: [gateway/README.md](gateway/README.md)

### 15. Search Service
- **Version**: v1.0.12
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8010, gRPC 9010
- **Description**: Full-text search, autocomplete, analytics, recommendations
- **Key Features**:
  - Product Search (full-text, faceted, filters)
  - CMS Content Search
  - Autocomplete & Suggestions
  - Search Analytics
  - Event-Driven Indexing
  - Product Visibility Filtering
  - Alert System (Email & PagerDuty)
  - DLQ Management
- **Dependencies**: Elasticsearch, PostgreSQL, Redis, Dapr
- **Documentation**: [search/README.md](search/README.md)

### 16. Analytics Service
- **Version**: v1.0.0
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8017, gRPC 9017
- **Description**: Analytics and business intelligence
- **Key Features**:
  - Dashboard Overview
  - Revenue Analytics
  - Order Analytics
  - Product Performance
  - Customer Analytics
  - Inventory Analytics
  - Real-time Metrics
  - Event-Driven Architecture
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [analytics/README.md](analytics/README.md)

### 17. Review Service
- **Version**: v1.1.1
- **Status**: ✅ Production Ready (95%)
- **Ports**: HTTP 8016, gRPC 9016
- **Description**: Product reviews, ratings, content moderation
- **Key Features**:
  - Review Management (CRUD)
  - Rating System (1-5 stars)
  - Content Moderation (auto + manual)
  - Helpful Votes
  - Review Analytics
  - Abuse Detection
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [review/README.md](review/README.md)

### 18. Common Operations Service
- **Version**: Latest
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8000, gRPC 9000
- **Description**: Task orchestration, file operations, MinIO integration
- **Key Features**:
  - Task Orchestration
  - File Upload/Download
  - MinIO Integration
  - Async Job Processing
- **Dependencies**: PostgreSQL, Redis, MinIO
- **Documentation**: [common-operations/README.md](common-operations/README.md)

---

## Operational Services

### 19. Notification Service
- **Version**: v1.1.3
- **Status**: ✅ Production Ready (90%)
- **Ports**: HTTP 8009, gRPC 9009
- **Description**: Multi-channel notifications (email, SMS, push, in-app)
- **Key Features**:
  - Email Notifications
  - SMS Notifications
  - Push Notifications
  - In-App Notifications
  - Template Management
  - User Preferences
  - Delivery Tracking
- **Dependencies**: PostgreSQL, Redis, SendGrid/SES, Twilio
- **Documentation**: [notification/README.md](notification/README.md)

### 20. Location Service
- **Version**: v1.0.0
- **Status**: ✅ Production Ready (90%)
- **Ports**: HTTP 8017, gRPC 9017
- **Description**: Location tree management (Country → State → City → District → Ward)
- **Key Features**:
  - Hierarchical Location Management
  - Location Search & Filtering
  - Tree Traversal
  - Address Validation
  - Redis Caching
  - Outbox Pattern
- **Dependencies**: PostgreSQL, Redis
- **Documentation**: [location/README.md](location/README.md)

### 21. Loyalty Rewards Service
- **Version**: Latest
- **Status**: ✅ Production Ready
- **Ports**: HTTP 8013, gRPC 9013
- **Description**: Customer loyalty programs, points system, rewards
- **Key Features**:
  - Points System
  - Tier Management
  - Rewards Catalog
  - Activity Tracking
  - Referral Program
  - Bonus Campaigns
  - Expiration Management
  - Analytics
- **Dependencies**: PostgreSQL, Redis, Dapr
- **Documentation**: [loyalty-rewards/README.md](loyalty-rewards/README.md)

### 22. Admin Service
- **Version**: v1.0.0
- **Status**: ✅ Production Ready
- **Ports**: HTTP 3001
- **Description**: Admin panel frontend (React + Vite + Ant Design)
- **Key Features**:
  - Dashboard
  - Product Management
  - Order Management
  - Customer Management
  - User Management
  - Inventory Management
  - Reports
  - Settings
- **Dependencies**: Gateway Service (API proxy)
- **Documentation**: [admin/README.md](admin/README.md)

### 23. Frontend Service
- **Version**: Latest
- **Status**: ✅ Production Ready
- **Ports**: HTTP 3000
- **Description**: Customer-facing frontend (Next.js)
- **Key Features**:
  - Product Catalog
  - Shopping Cart
  - Checkout Flow
  - User Account
  - Order Tracking
  - Search
  - Reviews
- **Dependencies**: Gateway Service (API proxy)
- **Documentation**: [frontend/README.md](frontend/README.md)

---

## Service Statistics

### By Status
- ✅ Production Ready: 23/23 (100%)
- 🟡 In Development: 0/23 (0%)
- 🔴 Not Started: 0/23 (0%)

### By Category
- Core Business Services: 13
- Platform Services: 5
- Operational Services: 5

### Technology Stack
- **Language**: Go 1.21-1.25
- **Framework**: Kratos v2.7-v2.9
- **Database**: PostgreSQL 15+
- **Cache**: Redis 7+
- **Search**: Elasticsearch 8.11+
- **Message Broker**: Dapr PubSub (Redis)
- **Service Discovery**: Consul
- **API**: gRPC + HTTP (gRPC-Gateway)
- **Observability**: Prometheus, OpenTelemetry, Jaeger

---

## Service Dependencies Matrix

| Service | PostgreSQL | Redis | Elasticsearch | Dapr | Consul | MinIO | External APIs |
|---------|-----------|-------|---------------|------|--------|-------|---------------|
| Auth | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| User | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Customer | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Catalog | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Pricing | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Promotion | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Checkout | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Order | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Payment | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Warehouse | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Fulfillment | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Shipping | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| Return | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Gateway | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Search | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Analytics | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Review | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Common Ops | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ |
| Notification | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| Location | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Loyalty | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Admin | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Frontend | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Dependencies Notes:
- **External APIs**: SendGrid/SES, Twilio (Notification Service) | Stripe, PayPal, VNPay, MoMo (Payment Service) | GHN, Grab (Shipping Service)
- **Service-to-Service**: Fulfillment depends on Warehouse & Catalog services
- **Frontend Services**: Admin & Frontend only depend on Gateway Service

---

## Quick Reference

### Service Ports

| Service | HTTP | gRPC |
|---------|------|------|
| Auth | 8000 | 9000 |
| User | 8001 | 9001 |
| Pricing | 8002 | 9002 |
| Customer | 8003 | 9003 |
| Order | 8004 | 9004 |
| Payment | 8005 | 9005 |
| Warehouse | 8006 | 9006 |
| Location | 8007 | 9007 |
| Fulfillment | 8008 | 9008 |
| Notification | 8009 | 9009 |
| Checkout | 8010 | 9010 |
| Promotion | 8011 | 9011 |
| Shipping | 8012 | 9012 |
| Return | 8013 | 9013 |
| Loyalty | 8014 | 9014 |
| Catalog | 8015 | 9015 |
| Review | 8016 | 9016 |
| Search | 8017 | 9017 |
| Analytics | 8018 | 9018 |
| Common Ops | 8019 | 9019 |
| Gateway | 80 | - |
| Admin | 3001 | - |
| Frontend | 3000 | - |

### Common Commands

```bash
# Build service
make build

# Run service
make run

# Run tests
make test

# Generate proto code
make api

# Run migrations
make migrate-up

# Check health
curl http://localhost:{PORT}/health
```

---

**Generated**: 2026-02-07  
**Maintainer**: Platform Team
