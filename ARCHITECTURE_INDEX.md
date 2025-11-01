# 📚 Microservices Architecture - Index & Navigation Guide

> **Tài liệu hướng dẫn điều hướng toàn bộ kiến trúc microservices**  
> **Migration từ Magento 2 sang kiến trúc microservices hiện đại**  
> **🔄 Updated**: Index được cập nhật với cấu trúc file thực tế

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
- [2.5 Frontend Architecture](#25-frontend-architecture)
- [2.6 Kratos + Consul Integration](#26-kratos--consul-integration)
- [2.7 Service Communication Patterns](#27-service-communication-patterns)

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

📄 **File**: [`docs/docs/architecture/overview.md`](./docs/docs/architecture/overview.md)

**Nội dung**:
- Chi tiết về 4-layer Cloud-Native architecture
- Danh sách và mô tả các services
- Design principles

**Đọc khi**: Cần hiểu chi tiết về kiến trúc tổng thể.

---

### 2.2 Sơ Đồ Kiến Trúc

📄 **File**: [`docs/docs/architecture/complete-architecture-diagram.md`](./docs/docs/architecture/complete-architecture-diagram.md)

**Nội dung**:
- Mermaid diagrams về system architecture
- Service communication patterns (Sync/Async)
- Data flow architecture
- Security architecture
- Scalability & performance patterns

**Đọc khi**: Cần visualize kiến trúc và mối quan hệ giữa các services.

---

### 2.3 Luồng Sự Kiện (Event Flow)

📄 **File**: [`docs/docs/architecture/event-flow-diagram.md`](./docs/docs/architecture/event-flow-diagram.md)

**Nội dung**:
- Event flow diagrams
- Event-driven communication patterns
- Event sourcing và audit trail

**Đọc khi**: Cần hiểu về event-driven communication giữa các services.

---

### 2.4 4-Layer Architecture Benefits

📄 **File**: [`docs/docs/architecture/4-layer-benefits.md`](./docs/docs/architecture/4-layer-benefits.md)

**Nội dung**:
- Lợi ích của 4-Layer Cloud-Native architecture
- So sánh với 3-Layer architecture
- Scalability và maintainability benefits
- Implementation và deployment strategies
- Security và observability advantages

**Đọc khi**: Cần hiểu tại sao chọn 4-Layer architecture và lợi ích của nó.

---

### 2.5 Frontend Architecture

📄 **File**: [`docs/docs/architecture/frontend-architecture.md`](./docs/docs/architecture/frontend-architecture.md)

**Nội dung**:
- Multi-platform frontend architecture (Web, Mobile, Admin)
- Flutter mobile app integration
- BFF (Backend for Frontend) patterns
- Frontend-backend communication với Kratos + Consul + Dapr

**Đọc khi**: Cần hiểu về frontend architecture và integration patterns.

---

### 2.6 Kratos + Consul Integration

📄 **File**: [`docs/docs/architecture/kratos-consul-integration.md`](./docs/docs/architecture/kratos-consul-integration.md)

**Nội dung**:
- go-kratos/kratos framework integration với Consul service discovery
- Service registration và discovery patterns
- Configuration management
- Health checks và monitoring

**Đọc khi**: Cần implement services với Kratos framework và Consul integration.

---

### 2.7 Service Communication Patterns

📄 **File**: [`docs/docs/architecture/service-communication-patterns.md`](./docs/docs/architecture/service-communication-patterns.md)

**Nội dung**:
- Synchronous và asynchronous communication patterns
- gRPC, HTTP REST, và Event-driven communication
- Circuit breakers và retry patterns
- Service mesh integration

**Đọc khi**: Cần hiểu về communication patterns giữa các services.

---

## 3. Các Service Chính

### 3.1 Application Services (11 services)

Các service xử lý business logic chính:

#### 🛍️ **Catalog & CMS Service**
📄 [`docs/docs/services/catalog-cms-service.md`](./docs/docs/services/catalog-cms-service.md)
- **Chức năng**: Product catalog, categories, brands, CMS (pages, blogs, banners)
- **Đặc điểm**: SEO content, multi-language, không có pricing logic

#### 💰 **Pricing Service**
📄 [`docs/docs/services/pricing-service.md`](./docs/docs/services/pricing-service.md)
- **Chức năng**: Tính giá theo SKU + Warehouse
- **Đặc điểm**: Dynamic pricing, promotions, customer tiers

#### 🎟️ **Promotion Service**
📄 [`docs/docs/services/promotion-service.md`](./docs/docs/services/promotion-service.md)
- **Chức năng**: Promotion rules theo SKU + Warehouse
- **Đặc điểm**: Customer segment targeting, coupon management

#### 📦 **Order Service**
📄 [`docs/docs/services/order-service.md`](./docs/docs/services/order-service.md)
- **Chức năng**: Xử lý order lifecycle
- **Đặc điểm**: Order status orchestration qua events

#### 💳 **Payment Service**
📄 [`docs/docs/services/payment-service.md`](./docs/docs/services/payment-service.md)
- **Chức năng**: Payment gateway integration
- **Đặc điểm**: PCI compliance, refund handling

#### 🚚 **Shipping Service**
📄 [`docs/docs/services/shipping-service.md`](./docs/docs/services/shipping-service.md)
- **Chức năng**: Fulfillment entity, carrier integration
- **Đặc điểm**: Last-mile, first-mile logistics

#### 👥 **Customer Service**
📄 [`docs/docs/services/customer-service.md`](./docs/docs/services/customer-service.md)
- **Chức năng**: Customer information management
- **Đặc điểm**: Customer profiles, order history

#### ⭐ **Review Service**
📄 [`docs/docs/services/review-service.md`](./docs/docs/services/review-service.md)
- **Chức năng**: Product reviews và ratings
- **Đặc điểm**: Review moderation workflow

#### 🏪 **Warehouse & Inventory Service**
📄 [`docs/docs/services/warehouse-inventory-service.md`](./docs/docs/services/warehouse-inventory-service.md)
- **Chức năng**: Multi-warehouse inventory management
- **Đặc điểm**: Real-time stock tracking, warehouse-specific operations

#### 📊 **Analytics & Reporting Service**
📄 [`docs/docs/services/analytics-reporting-service.md`](./docs/docs/services/analytics-reporting-service.md)
- **Chức năng**: Business intelligence và data analytics
- **Đặc điểm**: Real-time metrics, KPIs, customer behavior analytics

#### 🎁 **Loyalty & Rewards Service**
📄 [`docs/docs/services/loyalty-rewards-service.md`](./docs/docs/services/loyalty-rewards-service.md)
- **Chức năng**: Loyalty programs và rewards management
- **Đặc điểm**: Points accumulation, tier-based benefits

---

### 3.2 Infrastructure Services (8 services)

Các service hỗ trợ cho toàn hệ thống:

#### 🔐 **Auth Service (IAM)**
📄 [`docs/docs/services/auth-service.md`](./docs/docs/services/auth-service.md)
- **Chức năng**: Authentication và authorization
- **Đặc điểm**: JWT tokens, OAuth2, SSO, MFA

#### 👤 **User Service**
📄 [`docs/docs/services/user-service.md`](./docs/docs/services/user-service.md)
- **Chức năng**: Internal user management (admins, staff)
- **Đặc điểm**: RBAC, service ownership permissions

#### 🔍 **Search Service**
📄 [`docs/docs/services/search-service.md`](./docs/docs/services/search-service.md)
- **Chức năng**: Product search với Elasticsearch
- **Đặc điểm**: Real-time indexing, faceted search

#### 📢 **Notification Service**
📄 [`docs/docs/services/notification-service.md`](./docs/docs/services/notification-service.md)
- **Chức năng**: Multi-channel notifications
- **Đặc điểm**: Email, SMS, Push notifications

---

## 4. Luồng API & Data Flow

### 4.1 API Flows

#### 📥 **Get Product Flow**
📄 [`docs/docs/api-flows/get-product-flow.md`](./docs/docs/api-flows/get-product-flow.md)
- **Mô tả**: Luồng API lấy thông tin product đầy đủ
- **Đặc điểm**: Orchestration pattern, < 200ms response time
- **Services liên quan**: Catalog, Pricing, Review, Inventory

#### 🛒 **Checkout Flow**
📄 [`docs/docs/api-flows/checkout-flow.md`](./docs/docs/api-flows/checkout-flow.md)
- **Mô tả**: Luồng hoàn chỉnh từ cart đến order
- **Đặc điểm**: Event-driven, < 2 seconds response time
- **Services liên quan**: Order, Pricing, Payment, Inventory, Customer

#### 📦 **Fulfillment Order Flow**
📄 [`docs/docs/api-flows/fulfillment-order-flow.md`](./docs/docs/api-flows/fulfillment-order-flow.md)
- **Mô tả**: Luồng xử lý fulfillment sau khi order được tạo
- **Đặc điểm**: Event-driven orchestration
- **Services liên quan**: Shipping, Inventory, Notification, Order

#### ✅ **API Flows Validation**
📄 [`docs/docs/api-flows/api-flows-validation.md`](./docs/docs/api-flows/api-flows-validation.md)
- **Mô tả**: Validation và gap analysis của các API flows
- **Đặc điểm**: Service coverage, missing integrations

---

### 4.2 Data Flows

#### 🔄 **Core Data Flow**
📄 [`docs/docs/data-flows/core-data-flow.md`](./docs/docs/data-flows/core-data-flow.md)
- **Mô tả**: Data flow giữa các core services
- **Đặc điểm**: Event-driven data synchronization

#### 🔗 **Service Relationships**
📄 [`docs/docs/data-flows/service-relationships.md`](./docs/docs/data-flows/service-relationships.md)
- **Mô tả**: Dependencies và relationships giữa các services
- **Đặc điểm**: Service interaction matrix

---

## 5. Hạ Tầng & Infrastructure

### 5.1 API Gateway & BFF

📄 [`docs/docs/infrastructure/api-gateway.md`](./docs/docs/infrastructure/api-gateway.md)

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

📄 [`docs/docs/infrastructure/event-bus.md`](./docs/docs/infrastructure/event-bus.md)

**Chức năng**:
- Dapr Pub/Sub với Redis Streams
- Service-to-service communication
- Event-driven architecture support
- Guaranteed delivery, retry policies

**Đọc khi**: Cần hiểu về event-driven communication.

---

### 5.3 Cache Layer

📄 [`docs/docs/infrastructure/cache-layer.md`](./docs/docs/infrastructure/cache-layer.md)

**Chức năng**:
- Redis Cluster distributed cache
- Multi-layer caching strategy (L1/L2/L3)
- Cache invalidation patterns
- Performance optimization

**Đọc khi**: Cần optimize performance hoặc cấu hình cache.

---

### 5.4 File Storage & CDN

📄 [`docs/docs/infrastructure/file-storage-cdn.md`](./docs/docs/infrastructure/file-storage-cdn.md)

**Chức năng**:
- File storage (S3, MinIO)
- CDN integration
- Media management
- Static content delivery

**Đọc khi**: Cần quản lý files và media assets.

---

### 5.5 Monitoring & Logging

📄 [`docs/docs/infrastructure/monitoring-logging.md`](./docs/docs/infrastructure/monitoring-logging.md)

**Chức năng**:
- Prometheus metrics collection
- Grafana dashboards
- ELK Stack logging
- Distributed tracing

**Đọc khi**: Cần setup monitoring và observability.

---

## 6. Bảo Mật

### 6.1 Security Overview

📄 [`docs/docs/security/security-overview.md`](./docs/docs/security/security-overview.md)

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

📄 [`docs/docs/security/service-permission-matrix.md`](./docs/docs/security/service-permission-matrix.md)

**Nội dung**:
- Matrix chi tiết về permissions của từng service
- Endpoint-level access control
- Service-to-service permission rules

**Đọc khi**: Cần cấu hình permissions và access control.

---

## 7. Deployment & Operations

### 7.1 Deployment Guide

📄 [`docs/docs/deployment/deployment-guide.md`](./docs/docs/deployment/deployment-guide.md)

**Nội dung**:
- Kubernetes deployment
- Helm charts
- Docker containers
- Environment configuration
- CI/CD pipelines

**Đọc khi**: Cần deploy services lên production.

**Xem examples**: 
- [`docs/examples/infrastructure-examples/kubernetes-manifests/`](./docs/examples/infrastructure-examples/kubernetes-manifests/)
- [`docs/examples/infrastructure-examples/helm-charts/`](./docs/examples/infrastructure-examples/helm-charts/)
- [`docs/examples/infrastructure-examples/docker-compose/`](./docs/examples/infrastructure-examples/docker-compose/)

---

### 7.2 Performance Guide

📄 [`docs/docs/performance/performance-guide.md`](./docs/docs/performance/performance-guide.md)

**Nội dung**:
- Performance optimization strategies
- Caching patterns
- Database optimization
- API response time targets
- Scalability metrics

**Đọc khi**: Cần optimize performance của hệ thống.

---

### 7.3 Troubleshooting Guide

📄 [`docs/docs/operations/troubleshooting-guide.md`](./docs/docs/operations/troubleshooting-guide.md)

**Nội dung**:
- Common issues và solutions
- Debugging techniques
- Log analysis
- Service health checks

**Đọc khi**: Gặp vấn đề trong production hoặc development.

---

### 7.4 Testing Strategy

📄 [`docs/docs/testing/testing-strategy.md`](./docs/docs/testing/testing-strategy.md)

**Nội dung**:
- Unit testing
- Integration testing
- End-to-end testing
- Performance testing
- Security testing

**Đọc khi**: Cần setup testing cho services.

---

## 8. Migration Plan

📄 [`docs/docs/migration-plan.md`](./docs/docs/migration-plan.md)

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
📄 [`docs/examples/implementation-samples/service-templates/go-service/README.md`](./docs/examples/implementation-samples/service-templates/go-service/README.md)
- Complete Go service template với Gin/Fiber
- gRPC support
- Database migrations
- Event handling

#### **Node.js Service Template**
📄 [`docs/examples/implementation-samples/service-templates/nodejs-service/README.md`](./docs/examples/implementation-samples/service-templates/nodejs-service/README.md)
- Express/Fastify template
- TypeScript support
- Event-driven patterns

#### **Flutter App Template**
📄 [`docs/examples/implementation-samples/service-templates/flutter-app/README.md`](./docs/examples/implementation-samples/service-templates/flutter-app/README.md)
- Mobile app template
- API client integration

#### **Web App Template**
📄 [`docs/examples/implementation-samples/service-templates/web-app/README.md`](./docs/examples/implementation-samples/service-templates/web-app/README.md)
- React/Vue frontend template
- TypeScript support
- API integration patterns

#### **Service Templates Overview**
📄 [`docs/examples/implementation-samples/service-templates/README.md`](./docs/examples/implementation-samples/service-templates/README.md)

---

### 9.2 Infrastructure Examples

#### **Kubernetes Manifests**
📄 [`docs/examples/infrastructure-examples/kubernetes-manifests/README.md`](./docs/examples/infrastructure-examples/kubernetes-manifests/README.md)
- K8s deployment manifests
- Service definitions
- ConfigMaps, Secrets

#### **Docker Compose**
📄 [`docs/examples/infrastructure-examples/docker-compose/README.md`](./docs/examples/infrastructure-examples/docker-compose/README.md)
- Local development setup
- Service dependencies
- Environment configuration

#### **Terraform**
📄 [`docs/examples/infrastructure-examples/terraform/README.md`](./docs/examples/infrastructure-examples/terraform/README.md)
- Infrastructure as Code
- Cloud resource provisioning
- Multi-cloud support

#### **Helm Charts**
📄 [`docs/examples/infrastructure-examples/helm-charts/README.md`](./docs/examples/infrastructure-examples/helm-charts/README.md)
- Helm deployment charts
- Values configuration
- Release management

#### **Monitoring Configs**
📄 [`docs/examples/infrastructure-examples/monitoring-configs/README.md`](./docs/examples/infrastructure-examples/monitoring-configs/README.md)
- Prometheus configs
- Grafana dashboards
- Alert rules

---

### 9.3 Code Samples

#### **Generated Code Samples**
📄 [`docs/examples/generated-code-samples.md`](./docs/examples/generated-code-samples.md)
- Code examples từ documentation
- API client samples
- Event schema examples

#### **API Clients**
📄 [`docs/examples/implementation-samples/api-clients/README.md`](./docs/examples/implementation-samples/api-clients/README.md)
- Generated API client libraries
- Multi-language support

#### **Event Schemas**
📄 [`docs/examples/implementation-samples/event-schemas/README.md`](./docs/examples/implementation-samples/event-schemas/README.md)
- Event schema definitions
- Validation rules

#### **Database Migrations**
📄 [`docs/examples/implementation-samples/database-migrations/README.md`](./docs/examples/implementation-samples/database-migrations/README.md)
- Database schema migrations
- Version control

#### **Implementation Samples Overview**
📄 [`docs/examples/implementation-samples/README.md`](./docs/examples/implementation-samples/README.md)

---

## 🗺️ Quick Navigation Map

### Bắt Đầu Từ Đâu?

#### Nếu bạn là **Architect/Team Lead**:
1. Đọc [`README.md`](./README.md) để hiểu tổng quan
2. Xem [`docs/docs/architecture/overview.md`](./docs/docs/architecture/overview.md)
3. Xem [`docs/docs/architecture/complete-architecture-diagram.md`](./docs/docs/architecture/complete-architecture-diagram.md)
4. Xem [`docs/docs/migration-plan.md`](./docs/docs/migration-plan.md)

#### Nếu bạn là **Developer**:
1. Đọc [`README.md`](./README.md)
2. Chọn service bạn sẽ làm trong [`docs/docs/services/`](./docs/docs/services/)
3. Xem [`docs/examples/implementation-samples/service-templates/`](./docs/examples/implementation-samples/service-templates/)
4. Xem [`docs/docs/api-flows/`](./docs/docs/api-flows/) để hiểu API flows

#### Nếu bạn là **DevOps Engineer**:
1. Đọc [`docs/docs/deployment/deployment-guide.md`](./docs/docs/deployment/deployment-guide.md)
2. Xem [`docs/examples/infrastructure-examples/`](./docs/examples/infrastructure-examples/)
3. Xem [`docs/docs/infrastructure/`](./docs/docs/infrastructure/)

#### Nếu bạn là **Security Engineer**:
1. Đọc [`docs/docs/security/security-overview.md`](./docs/docs/security/security-overview.md)
2. Xem [`docs/docs/security/service-permission-matrix.md`](./docs/docs/security/service-permission-matrix.md)
3. Xem [`docs/docs/infrastructure/api-gateway.md`](./docs/docs/infrastructure/api-gateway.md)

---

## 📊 Tổng Kết Cấu Trúc

```
docs/
├── README.md                           # 📋 Tổng quan dự án
├── ARCHITECTURE_INDEX.md               # 📚 Tài liệu này
├── MIGRATION_STATUS_REPORT.md          # 📊 Migration status
├── MISSING_SERVICES_REPORT.md          # ⚠️ Missing services report
│
├── docs/                               # 📁 Main documentation
│   ├── architecture/                   # 🏗️ Kiến trúc tổng thể
│   │   ├── overview.md
│   │   ├── complete-architecture-diagram.md
│   │   ├── event-flow-diagram.md
│   │   ├── 4-layer-benefits.md
│   │   ├── frontend-architecture.md
│   │   ├── kratos-consul-integration.md
│   │   └── service-communication-patterns.md
│   │
│   ├── services/                       # 🔧 15 Microservices
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
│   ├── api-flows/                      # � Luồnng API
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
│   ├── deployment/                     # � Deplaoyment
│   │   └── deployment-guide.md
│   │
│   ├── performance/                    # ⚡ Performance
│   │   └── performance-guide.md
│   │
│   ├── operations/                     # � iOperations
│   │   └── troubleshooting-guide.md
│   │
│   ├── testing/                        # 🧪 Testing
│   │   └── testing-strategy.md
│   │
│   ├── migration-plan.md              # 📅 Migration plan
│   └── SERVICE_DOCUMENTATION_TEMPLATE.md # 📝 Service template
│
└── examples/                           # 💻 Code examples
    ├── generated-code-samples.md
    ├── implementation-samples/
    │   ├── README.md
    │   ├── service-templates/
    │   │   ├── README.md
    │   │   ├── go-service/README.md
    │   │   ├── nodejs-service/README.md
    │   │   ├── flutter-app/README.md
    │   │   └── web-app/README.md
    │   ├── api-clients/README.md
    │   ├── event-schemas/README.md
    │   └── database-migrations/README.md
    └── infrastructure-examples/
        ├── kubernetes-manifests/README.md
        ├── docker-compose/README.md
        ├── terraform/README.md
        ├── helm-charts/README.md
        └── monitoring-configs/README.md
```

---

## 🔍 Tìm Kiếm Nhanh

### Tôi cần tìm...

- **Cách tạo một service mới?** → [`docs/examples/implementation-samples/service-templates/`](./docs/examples/implementation-samples/service-templates/)
- **API flow của checkout?** → [`docs/docs/api-flows/checkout-flow.md`](./docs/docs/api-flows/checkout-flow.md)
- **Cách deploy lên K8s?** → [`docs/docs/deployment/deployment-guide.md`](./docs/docs/deployment/deployment-guide.md)
- **Security best practices?** → [`docs/docs/security/security-overview.md`](./docs/docs/security/security-overview.md)
- **Performance optimization?** → [`docs/docs/performance/performance-guide.md`](./docs/docs/performance/performance-guide.md)
- **Event schema examples?** → [`docs/examples/implementation-samples/event-schemas/`](./docs/examples/implementation-samples/event-schemas/)
- **Service dependencies?** → [`docs/docs/data-flows/service-relationships.md`](./docs/docs/data-flows/service-relationships.md)
- **Migration timeline?** → [`docs/docs/migration-plan.md`](./docs/docs/migration-plan.md)
- **How to setup local dev?** → [`docs/examples/infrastructure-examples/docker-compose/`](./docs/examples/infrastructure-examples/docker-compose/)
- **How Order Service works?** → [`docs/docs/services/order-service.md`](./docs/docs/services/order-service.md)
- **Kratos + Consul integration?** → [`docs/docs/architecture/kratos-consul-integration.md`](./docs/docs/architecture/kratos-consul-integration.md)
- **Frontend architecture?** → [`docs/docs/architecture/frontend-architecture.md`](./docs/docs/architecture/frontend-architecture.md)

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

