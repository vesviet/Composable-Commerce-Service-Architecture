# 📚 Microservices Architecture - Index & Navigation Guide

> **Tài liệu hướng dẫn điều hướng toàn bộ kiến trúc microservices**  
> **Migration từ Magento 2 sang kiến trúc microservices hiện đại**

---

## 🎯 Mục Lục Tổng Quan

### [1. Tổng Quan Kiến Trúc](#1-tổng-quan-kiến-trúc)
- [1.1 Tổng Quan Dự Án](#11-tổng-quan-dự-án)
- [1.2 Kiến Trúc 3 Lớp](#12-kiến-trúc-3-lớp)
- [1.3 Nguyên Tắc Thiết Kế](#13-nguyên-tắc-thiết-kế)

### [2. Tài Liệu Kiến Trúc](#2-tài-liệu-kiến-trúc)
- [2.1 Tổng Quan Hệ Thống](#21-tổng-quan-hệ-thống)
- [2.2 Sơ Đồ Kiến Trúc](#22-sơ-đồ-kiến-trúc)
- [2.3 Luồng Sự Kiện (Event Flow)](#23-luồng-sự-kiện-event-flow)
- [2.4 4-Layer Architecture Benefits](#24-4-layer-architecture-benefits)

### [3. Các Service Chính](#3-các-service-chính)
- [3.1 Application Services (11 services)](#31-application-services-11-services)
- [3.2 Infrastructure Services (8 services)](#32-infrastructure-services-8-services)

### [4. Luồng API & Data Flow](#4-luồng-api--data-flow)
- [4.1 API Flows](#41-api-flows)
- [4.2 Data Flows](#42-data-flows)

### [5. Hạ Tầng & Infrastructure](#5-hạ-tầng--infrastructure)
- [5.1 API Gateway & BFF](#51-api-gateway--bff)
- [5.2 Event Bus & Messaging](#52-event-bus--messaging)
- [5.3 Cache Layer](#53-cache-layer)
- [5.4 File Storage & CDN](#54-file-storage--cdn)
- [5.5 Monitoring & Logging](#55-monitoring--logging)

### [6. Bảo Mật](#6-bảo-mật)
- [6.1 Security Overview](#61-security-overview)
- [6.2 Service Permission Matrix](#62-service-permission-matrix)

### [7. Deployment & Operations](#7-deployment--operations)
- [7.1 Deployment Guide](#71-deployment-guide)
- [7.2 Performance Guide](#72-performance-guide)
- [7.3 Troubleshooting Guide](#73-troubleshooting-guide)
- [7.4 Testing Strategy](#74-testing-strategy)

### [8. Migration Plan](#8-migration-plan)

### [9. Examples & Implementation](#9-examples--implementation)
- [9.1 Service Templates](#91-service-templates)
- [9.2 Infrastructure Examples](#92-infrastructure-examples)
- [9.3 Code Samples](#93-code-samples)

---

## 1. Tổng Quan Kiến Trúc

### 1.1 Tổng Quan Dự Án

📄 **File**: [`README.md`](./README.md)

**Mục đích**: Tài liệu chính giới thiệu về dự án migration từ Magento 2 sang microservices.

**Nội dung chính**:
- Mục tiêu migration: Scalability, Performance, Maintainability
- Kiến trúc 4 lớp: Presentation → Application → Infrastructure → Platform & Runtime
- 19 microservices tổng cộng (11 Application + 8 Infrastructure)
- Technology stack và migration timeline 16 tuần
- Event-driven architecture với Dapr
- SKU + Warehouse based operations

**Đọc ngay nếu**: Bạn là người mới và muốn hiểu tổng quan về dự án.

---

### 1.2 Kiến Trúc 4 Lớp Cloud-Native

```
┌─────────────────────────────────────────────────────────────┐
│                🎨 Layer 1: Presentation Layer               │
│  Frontend/Storefront • Admin Dashboard • Mobile Apps       │
│                     API Gateway/BFF                        │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│            🏢 Layer 2: Application Services Layer           │
│  Catalog • Pricing • Promotion • Order • Payment          │
│  Shipping • Customer • Review • Warehouse & Inventory      │
│  Analytics • Loyalty & Rewards (11 Business Services)      │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│           🔧 Layer 3: Infrastructure Services Layer         │
│  Auth • User • Search • Notification (4 Services)         │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│           ☁️ Layer 4: Platform & Runtime Layer              │
│  Event Bus • Service Mesh • Cache • Storage • Monitoring   │
│  Dapr Runtime • Consul Discovery • Observability Stack     │
└─────────────────────────────────────────────────────────────┘
```

---

### 1.3 Nguyên Tắc Thiết Kế

- **Event-Driven Architecture**: Loose coupling qua Event Bus
- **SKU + Warehouse Based**: Pricing và operations theo SKU + Warehouse
- **Zero Trust Security**: Service-to-service authentication
- **Independent Scaling**: Mỗi service scale độc lập
- **Fault Tolerance**: Circuit breakers, retry, graceful degradation

---

## 2. Tài Liệu Kiến Trúc

### 2.1 Tổng Quan Hệ Thống

📄 **File**: [`docs/architecture/overview.md`](./docs/architecture/overview.md)

**Nội dung**:
- Chi tiết về 4-layer Cloud-Native architecture
- Danh sách và mô tả các services
- Design principles

**Đọc khi**: Cần hiểu chi tiết về kiến trúc tổng thể.

---

### 2.2 Sơ Đồ Kiến Trúc

📄 **File**: [`docs/architecture/complete-architecture-diagram.md`](./docs/architecture/complete-architecture-diagram.md)

**Nội dung**:
- Mermaid diagrams về system architecture
- Service communication patterns (Sync/Async)
- Data flow architecture
- Security architecture
- Scalability & performance patterns

**Đọc khi**: Cần visualize kiến trúc và mối quan hệ giữa các services.

---

### 2.3 Luồng Sự Kiện (Event Flow)

📄 **File**: [`docs/architecture/event-flow-diagram.md`](./docs/architecture/event-flow-diagram.md)

**Nội dung**:
- Event flow diagrams
- Event-driven communication patterns
- Event sourcing và audit trail

**Đọc khi**: Cần hiểu về event-driven communication giữa các services.

---

### 2.4 4-Layer Architecture Benefits

📄 **File**: [`docs/architecture/4-layer-benefits.md`](./docs/architecture/4-layer-benefits.md)

**Nội dung**:
- Lợi ích của 4-Layer Cloud-Native architecture
- So sánh với 3-Layer architecture
- Scalability và maintainability benefits
- Implementation và deployment strategies
- Security và observability advantages

**Đọc khi**: Cần hiểu tại sao chọn 4-Layer architecture và lợi ích của nó.

---

## 3. Các Service Chính

### 3.1 Application Services (11 services)

Các service xử lý business logic chính:

#### 🛍️ **Catalog & CMS Service**
📄 [`docs/services/catalog-cms-service.md`](./docs/services/catalog-cms-service.md)
- **Chức năng**: Product catalog, categories, brands, CMS (pages, blogs, banners)
- **Đặc điểm**: SEO content, multi-language, không có pricing logic

#### 💰 **Pricing Service**
📄 [`docs/services/pricing-service.md`](./docs/services/pricing-service.md)
- **Chức năng**: Tính giá theo SKU + Warehouse
- **Đặc điểm**: Dynamic pricing, promotions, customer tiers

#### 🎟️ **Promotion Service**
📄 [`docs/services/promotion-service.md`](./docs/services/promotion-service.md)
- **Chức năng**: Promotion rules theo SKU + Warehouse
- **Đặc điểm**: Customer segment targeting, coupon management

#### 📦 **Order Service**
📄 [`docs/services/order-service.md`](./docs/services/order-service.md)
- **Chức năng**: Xử lý order lifecycle
- **Đặc điểm**: Order status orchestration qua events

#### 💳 **Payment Service**
📄 [`docs/services/payment-service.md`](./docs/services/payment-service.md)
- **Chức năng**: Payment gateway integration
- **Đặc điểm**: PCI compliance, refund handling

#### 🚚 **Shipping Service**
📄 [`docs/services/shipping-service.md`](./docs/services/shipping-service.md)
- **Chức năng**: Fulfillment entity, carrier integration
- **Đặc điểm**: Last-mile, first-mile logistics

#### 👥 **Customer Service**
📄 [`docs/services/customer-service.md`](./docs/services/customer-service.md)
- **Chức năng**: Customer information management
- **Đặc điểm**: Customer profiles, order history

#### ⭐ **Review Service**
📄 [`docs/services/review-service.md`](./docs/services/review-service.md)
- **Chức năng**: Product reviews và ratings
- **Đặc điểm**: Review moderation workflow

#### 🏪 **Warehouse & Inventory Service**
📄 [`docs/services/warehouse-inventory-service.md`](./docs/services/warehouse-inventory-service.md)
- **Chức năng**: Multi-warehouse inventory management
- **Đặc điểm**: Real-time stock tracking, warehouse-specific operations

#### 📊 **Analytics & Reporting Service**
📄 [`docs/services/analytics-reporting-service.md`](./docs/services/analytics-reporting-service.md)
- **Chức năng**: Business intelligence và data analytics
- **Đặc điểm**: Real-time metrics, KPIs, customer behavior analytics

#### 🎁 **Loyalty & Rewards Service**
📄 [`docs/services/loyalty-rewards-service.md`](./docs/services/loyalty-rewards-service.md)
- **Chức năng**: Loyalty programs và rewards management
- **Đặc điểm**: Points accumulation, tier-based benefits

---

### 3.2 Infrastructure Services (8 services)

Các service hỗ trợ cho toàn hệ thống:

#### 🔐 **Auth Service (IAM)**
📄 [`docs/services/auth-service.md`](./docs/services/auth-service.md)
- **Chức năng**: Authentication và authorization
- **Đặc điểm**: JWT tokens, OAuth2, SSO, MFA

#### 👤 **User Service**
📄 [`docs/services/user-service.md`](./docs/services/user-service.md)
- **Chức năng**: Internal user management (admins, staff)
- **Đặc điểm**: RBAC, service ownership permissions

#### 🔍 **Search Service**
📄 [`docs/services/search-service.md`](./docs/services/search-service.md)
- **Chức năng**: Product search với Elasticsearch
- **Đặc điểm**: Real-time indexing, faceted search

#### 📢 **Notification Service**
📄 [`docs/services/notification-service.md`](./docs/services/notification-service.md)
- **Chức năng**: Multi-channel notifications
- **Đặc điểm**: Email, SMS, Push notifications

---

## 4. Luồng API & Data Flow

### 4.1 API Flows

#### 📥 **Get Product Flow**
📄 [`docs/api-flows/get-product-flow.md`](./docs/api-flows/get-product-flow.md)
- **Mô tả**: Luồng API lấy thông tin product đầy đủ
- **Đặc điểm**: Orchestration pattern, < 200ms response time
- **Services liên quan**: Catalog, Pricing, Review, Inventory

#### 🛒 **Checkout Flow**
📄 [`docs/api-flows/checkout-flow.md`](./docs/api-flows/checkout-flow.md)
- **Mô tả**: Luồng hoàn chỉnh từ cart đến order
- **Đặc điểm**: Event-driven, < 2 seconds response time
- **Services liên quan**: Order, Pricing, Payment, Inventory, Customer

#### 📦 **Fulfillment Order Flow**
📄 [`docs/api-flows/fulfillment-order-flow.md`](./docs/api-flows/fulfillment-order-flow.md)
- **Mô tả**: Luồng xử lý fulfillment sau khi order được tạo
- **Đặc điểm**: Event-driven orchestration
- **Services liên quan**: Shipping, Inventory, Notification, Order

#### ✅ **API Flows Validation**
📄 [`docs/api-flows/api-flows-validation.md`](./docs/api-flows/api-flows-validation.md)
- **Mô tả**: Validation và gap analysis của các API flows
- **Đặc điểm**: Service coverage, missing integrations

---

### 4.2 Data Flows

#### 🔄 **Core Data Flow**
📄 [`docs/data-flows/core-data-flow.md`](./docs/data-flows/core-data-flow.md)
- **Mô tả**: Data flow giữa các core services
- **Đặc điểm**: Event-driven data synchronization

#### 🔗 **Service Relationships**
📄 [`docs/data-flows/service-relationships.md`](./docs/data-flows/service-relationships.md)
- **Mô tả**: Dependencies và relationships giữa các services
- **Đặc điểm**: Service interaction matrix

---

## 5. Hạ Tầng & Infrastructure

### 5.1 API Gateway & BFF

📄 [`docs/infrastructure/api-gateway.md`](./docs/infrastructure/api-gateway.md)

**Chức năng chính**:
- Config-driven routing (zero-code service addition)
- Sub-50ms JWT authentication với Redis permission cache
- Service-to-service authentication
- Granular permission matrix
- Rate limiting, load balancing, circuit breakers

**BFF Patterns**:
- Web BFF (React/Vue Frontend)
- Mobile BFF (iOS/Android Apps)
- Admin BFF (Admin Dashboard)

**Đọc khi**: Cần implement hoặc cấu hình API Gateway.

---

### 5.2 Event Bus & Messaging

📄 [`docs/infrastructure/event-bus.md`](./docs/infrastructure/event-bus.md)

**Chức năng**:
- Dapr Pub/Sub với Redis Streams
- Service-to-service communication
- Event-driven architecture support
- Guaranteed delivery, retry policies

**Đọc khi**: Cần hiểu về event-driven communication.

---

### 5.3 Cache Layer

📄 [`docs/infrastructure/cache-layer.md`](./docs/infrastructure/cache-layer.md)

**Chức năng**:
- Redis Cluster distributed cache
- Multi-layer caching strategy (L1/L2/L3)
- Cache invalidation patterns
- Performance optimization

**Đọc khi**: Cần optimize performance hoặc cấu hình cache.

---

### 5.4 File Storage & CDN

📄 [`docs/infrastructure/file-storage-cdn.md`](./docs/infrastructure/file-storage-cdn.md)

**Chức năng**:
- File storage (S3, MinIO)
- CDN integration
- Media management
- Static content delivery

**Đọc khi**: Cần quản lý files và media assets.

---

### 5.5 Monitoring & Logging

📄 [`docs/infrastructure/monitoring-logging.md`](./docs/infrastructure/monitoring-logging.md)

**Chức năng**:
- Prometheus metrics collection
- Grafana dashboards
- ELK Stack logging
- Distributed tracing

**Đọc khi**: Cần setup monitoring và observability.

---

## 6. Bảo Mật

### 6.1 Security Overview

📄 [`docs/security/security-overview.md`](./docs/security/security-overview.md)

**Nội dung chính**:
- Zero Trust Architecture
- Event-Driven Authentication (20-50ms)
- MFA support
- Network security (mTLS, Service Mesh)
- Data encryption (at rest & in transit)
- Compliance (PCI DSS, GDPR, SOX)

**Đọc khi**: Cần hiểu về security architecture và best practices.

---

### 6.2 Service Permission Matrix

📄 [`docs/security/service-permission-matrix.md`](./docs/security/service-permission-matrix.md)

**Nội dung**:
- Matrix chi tiết về permissions của từng service
- Endpoint-level access control
- Service-to-service permission rules

**Đọc khi**: Cần cấu hình permissions và access control.

---

## 7. Deployment & Operations

### 7.1 Deployment Guide

📄 [`docs/deployment/deployment-guide.md`](./docs/deployment/deployment-guide.md)

**Nội dung**:
- Kubernetes deployment
- Helm charts
- Docker containers
- Environment configuration
- CI/CD pipelines

**Đọc khi**: Cần deploy services lên production.

**Xem examples**: 
- [`examples/infrastructure-examples/kubernetes-manifests/`](./examples/infrastructure-examples/kubernetes-manifests/)
- [`examples/infrastructure-examples/helm-charts/`](./examples/infrastructure-examples/helm-charts/)
- [`examples/infrastructure-examples/docker-compose/`](./examples/infrastructure-examples/docker-compose/)

---

### 7.2 Performance Guide

📄 [`docs/performance/performance-guide.md`](./docs/performance/performance-guide.md)

**Nội dung**:
- Performance optimization strategies
- Caching patterns
- Database optimization
- API response time targets
- Scalability metrics

**Đọc khi**: Cần optimize performance của hệ thống.

---

### 7.3 Troubleshooting Guide

📄 [`docs/operations/troubleshooting-guide.md`](./docs/operations/troubleshooting-guide.md)

**Nội dung**:
- Common issues và solutions
- Debugging techniques
- Log analysis
- Service health checks

**Đọc khi**: Gặp vấn đề trong production hoặc development.

---

### 7.4 Testing Strategy

📄 [`docs/testing/testing-strategy.md`](./docs/testing/testing-strategy.md)

**Nội dung**:
- Unit testing
- Integration testing
- End-to-end testing
- Performance testing
- Security testing

**Đọc khi**: Cần setup testing cho services.

---

## 8. Migration Plan

📄 [`docs/migration-plan.md`](./docs/migration-plan.md)

**Nội dung**:
- 16-week phased migration plan
- **Phase 1 (Weeks 1-4)**: Foundation
- **Phase 2 (Weeks 5-8)**: Order Management
- **Phase 3 (Weeks 9-12)**: Advanced Features
- **Phase 4 (Weeks 13-16)**: Integration & Go-Live

**Đọc khi**: Bắt đầu migration project hoặc planning.

---

## 9. Examples & Implementation

### 9.1 Service Templates

Code templates cho các service types:

#### **Go Service Template**
📄 [`examples/implementation-samples/service-templates/go-service/README.md`](./examples/implementation-samples/service-templates/go-service/README.md)
- Complete Go service template với Gin/Fiber
- gRPC support
- Database migrations
- Event handling

#### **Node.js Service Template**
📄 [`examples/implementation-samples/service-templates/nodejs-service/README.md`](./examples/implementation-samples/service-templates/nodejs-service/README.md)
- Express/Fastify template
- TypeScript support
- Event-driven patterns

#### **Flutter App Template**
📄 [`examples/implementation-samples/service-templates/flutter-app/README.md`](./examples/implementation-samples/service-templates/flutter-app/README.md)
- Mobile app template
- API client integration

#### **Service Templates Overview**
📄 [`examples/implementation-samples/service-templates/README.md`](./examples/implementation-samples/service-templates/README.md)

---

### 9.2 Infrastructure Examples

#### **Kubernetes Manifests**
📄 [`examples/infrastructure-examples/kubernetes-manifests/README.md`](./examples/infrastructure-examples/kubernetes-manifests/README.md)
- K8s deployment manifests
- Service definitions
- ConfigMaps, Secrets

#### **Docker Compose**
📄 [`examples/infrastructure-examples/docker-compose/README.md`](./examples/infrastructure-examples/docker-compose/README.md)
- Local development setup
- Service dependencies
- Environment configuration

#### **Terraform**
📄 [`examples/infrastructure-examples/terraform/README.md`](./examples/infrastructure-examples/terraform/README.md)
- Infrastructure as Code
- Cloud resource provisioning
- Multi-cloud support

#### **Helm Charts**
📄 [`examples/infrastructure-examples/helm-charts/README.md`](./examples/infrastructure-examples/helm-charts/README.md)
- Helm deployment charts
- Values configuration
- Release management

#### **Monitoring Configs**
📄 [`examples/infrastructure-examples/monitoring-configs/README.md`](./examples/infrastructure-examples/monitoring-configs/README.md)
- Prometheus configs
- Grafana dashboards
- Alert rules

---

### 9.3 Code Samples

#### **Generated Code Samples**
📄 [`examples/generated-code-samples.md`](./examples/generated-code-samples.md)
- Code examples từ documentation
- API client samples
- Event schema examples

#### **API Clients**
📄 [`examples/implementation-samples/api-clients/README.md`](./examples/implementation-samples/api-clients/README.md)
- Generated API client libraries
- Multi-language support

#### **Event Schemas**
📄 [`examples/implementation-samples/event-schemas/README.md`](./examples/implementation-samples/event-schemas/README.md)
- Event schema definitions
- Validation rules

#### **Database Migrations**
📄 [`examples/implementation-samples/database-migrations/README.md`](./examples/implementation-samples/database-migrations/README.md)
- Database schema migrations
- Version control

#### **Implementation Samples Overview**
📄 [`examples/implementation-samples/README.md`](./examples/implementation-samples/README.md)

---

## 🗺️ Quick Navigation Map

### Bắt Đầu Từ Đâu?

#### Nếu bạn là **Architect/Team Lead**:
1. Đọc [`README.md`](./README.md) để hiểu tổng quan
2. Xem [`docs/architecture/overview.md`](./docs/architecture/overview.md)
3. Xem [`docs/architecture/complete-architecture-diagram.md`](./docs/architecture/complete-architecture-diagram.md)
4. Xem [`docs/migration-plan.md`](./docs/migration-plan.md)

#### Nếu bạn là **Developer**:
1. Đọc [`README.md`](./README.md)
2. Chọn service bạn sẽ làm trong [`docs/services/`](./docs/services/)
3. Xem [`examples/implementation-samples/service-templates/`](./examples/implementation-samples/service-templates/)
4. Xem [`docs/api-flows/`](./docs/api-flows/) để hiểu API flows

#### Nếu bạn là **DevOps Engineer**:
1. Đọc [`docs/deployment/deployment-guide.md`](./docs/deployment/deployment-guide.md)
2. Xem [`examples/infrastructure-examples/`](./examples/infrastructure-examples/)
3. Xem [`docs/infrastructure/`](./docs/infrastructure/)

#### Nếu bạn là **Security Engineer**:
1. Đọc [`docs/security/security-overview.md`](./docs/security/security-overview.md)
2. Xem [`docs/security/service-permission-matrix.md`](./docs/security/service-permission-matrix.md)
3. Xem [`docs/infrastructure/api-gateway.md`](./docs/infrastructure/api-gateway.md)

---

## 📊 Tổng Kết Cấu Trúc

```
microservices_architecture/
├── README.md                           # 📋 Tổng quan dự án
├── ARCHITECTURE_INDEX.md               # 📚 Tài liệu này
│
├── docs/
│   ├── architecture/                   # 🏗️ Kiến trúc tổng thể
│   │   ├── overview.md
│   │   ├── complete-architecture-diagram.md
│   │   └── event-flow-diagram.md
│   │
│   ├── services/                       # 🔧 19 Microservices
│   │   ├── catalog-cms-service.md
│   │   ├── pricing-service.md
│   │   ├── promotion-service.md
│   │   ├── order-service.md
│   │   ├── payment-service.md
│   │   ├── shipping-service.md
│   │   ├── customer-service.md
│   │   ├── review-service.md
│   │   ├── warehouse-inventory-service.md
│   │   ├── analytics-reporting-service.md
│   │   ├── loyalty-rewards-service.md
│   │   ├── auth-service.md
│   │   ├── user-service.md
│   │   ├── search-service.md
│   │   └── notification-service.md
│   │
│   ├── api-flows/                      # 🔄 Luồng API
│   │   ├── get-product-flow.md
│   │   ├── checkout-flow.md
│   │   ├── fulfillment-order-flow.md
│   │   └── api-flows-validation.md
│   │
│   ├── data-flows/                     # 📊 Luồng dữ liệu
│   │   ├── core-data-flow.md
│   │   └── service-relationships.md
│   │
│   ├── infrastructure/                 # 🏛️ Hạ tầng
│   │   ├── api-gateway.md
│   │   ├── event-bus.md
│   │   ├── cache-layer.md
│   │   ├── file-storage-cdn.md
│   │   └── monitoring-logging.md
│   │
│   ├── security/                       # 🔒 Bảo mật
│   │   ├── security-overview.md
│   │   └── service-permission-matrix.md
│   │
│   ├── deployment/                     # 🚀 Deployment
│   │   └── deployment-guide.md
│   │
│   ├── performance/                    # ⚡ Performance
│   │   └── performance-guide.md
│   │
│   ├── operations/                     # 🔧 Operations
│   │   └── troubleshooting-guide.md
│   │
│   ├── testing/                        # 🧪 Testing
│   │   └── testing-strategy.md
│   │
│   └── migration-plan.md              # 📅 Migration plan
│
└── examples/                           # 💻 Code examples
    ├── generated-code-samples.md
    ├── implementation-samples/
    │   ├── service-templates/
    │   ├── api-clients/
    │   ├── event-schemas/
    │   └── database-migrations/
    └── infrastructure-examples/
        ├── kubernetes-manifests/
        ├── docker-compose/
        ├── terraform/
        ├── helm-charts/
        └── monitoring-configs/
```

---

## 🔍 Tìm Kiếm Nhanh

### Tôi cần tìm...

- **Cách tạo một service mới?** → [`examples/implementation-samples/service-templates/`](./examples/implementation-samples/service-templates/)
- **API flow của checkout?** → [`docs/api-flows/checkout-flow.md`](./docs/api-flows/checkout-flow.md)
- **Cách deploy lên K8s?** → [`docs/deployment/deployment-guide.md`](./docs/deployment/deployment-guide.md)
- **Security best practices?** → [`docs/security/security-overview.md`](./docs/security/security-overview.md)
- **Performance optimization?** → [`docs/performance/performance-guide.md`](./docs/performance/performance-guide.md)
- **Event schema examples?** → [`examples/implementation-samples/event-schemas/`](./examples/implementation-samples/event-schemas/)
- **Service dependencies?** → [`docs/data-flows/service-relationships.md`](./docs/data-flows/service-relationships.md)
- **Migration timeline?** → [`docs/migration-plan.md`](./docs/migration-plan.md)
- **How to setup local dev?** → [`examples/infrastructure-examples/docker-compose/`](./examples/infrastructure-examples/docker-compose/)
- **How Order Service works?** → [`docs/services/order-service.md`](./docs/services/order-service.md)

---

## 📝 Notes

- **Tất cả các tài liệu đều được viết bằng tiếng Anh**, nhưng index này bằng tiếng Việt để dễ điều hướng
- **Code examples** có thể được tìm trong thư mục `examples/`
- **Architecture diagrams** sử dụng Mermaid syntax
- **Last Updated**: Check individual files for last update dates

---

## 🤝 Đóng Góp

Nếu bạn tìm thấy thông tin không chính xác hoặc muốn thêm nội dung, vui lòng:
1. Tạo issue trên repository
2. Submit pull request với improvements
3. Update documentation trong file tương ứng

---

## 🚨 System Status & Issues

### Current Status: **NEEDS ATTENTION**

📋 **Audit Report**: [`SYSTEM_AUDIT_REPORT.md`](./SYSTEM_AUDIT_REPORT.md)

#### 🔴 Critical Issues Found:
- **Service Documentation Incomplete**: Many services missing API endpoints, database schemas
- ✅ **Architecture Consistency**: Standardized on 4-Layer Cloud-Native architecture
- **Missing Implementation**: Service templates have structure but no actual code
- **Event Schemas Undefined**: Event-driven architecture lacks concrete event definitions

#### 🟡 Medium Priority Issues:
- **Examples Incomplete**: Infrastructure examples need actual working code
- **Cross-Service Integration**: Service communication patterns need clarification
- **Testing Strategy**: Lacks concrete implementation examples

#### ✅ What's Working Well:
- **Documentation Structure**: Complete folder structure and navigation
- **Migration Plan**: Clear 16-week timeline
- **Architecture Vision**: Solid foundation with Dapr + Kratos + Consul

### 🎯 Immediate Action Required:

1. **Fix Architecture Consistency** (This Week)
   - ✅ Standardized on 4-Layer Cloud-Native architecture
   - Update all documents with consistent terminology
   - Ensure Kratos + Consul integration is reflected everywhere

2. **Complete Top 5 Service Docs** (Next Week)
   - Add complete API specifications
   - Define database schemas
   - Add event schemas
   - Include error handling

3. **Create Working Examples** (Week 3-4)
   - Implement actual service templates
   - Generate API clients
   - Create working infrastructure examples

### 📊 Progress Tracking:

| Component | Status | Priority | Owner | Due Date |
|-----------|--------|----------|-------|----------|
| Architecture Consistency | 🔴 Needs Fix | High | TBD | Week 1 |
| Service Documentation | 🟡 Partial | High | TBD | Week 2 |
| Code Templates | 🔴 Missing | Medium | TBD | Week 3 |
| Infrastructure Examples | 🟡 Partial | Medium | TBD | Week 4 |
| Event Schemas | 🔴 Missing | High | TBD | Week 2 |

---

**Happy Coding! 🚀**

> **⚠️ Note**: Please review the [System Audit Report](./SYSTEM_AUDIT_REPORT.md) before starting development to understand current gaps and priorities.

