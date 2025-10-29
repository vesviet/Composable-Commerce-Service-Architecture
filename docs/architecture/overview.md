# Architecture Overview (v3) - Kratos + Consul Integration

This version reflects the updated architecture with **go-kratos/kratos** framework and **Consul** integration for modern cloud-native microservices. **Fulfillment** remains an **entity inside the Shipping Service** and supports future expansion to **Last Mile, First Mile, and Hub-based logistics**.

## System Overview

## 4-Layer Cloud-Native Architecture

### 1️⃣ Presentation Layer
- **Frontend (Storefront/Admin)**: User interfaces
- **API Gateway/BFF**: Backend for Frontend, request routing with Consul service discovery

### 2️⃣ Application Services Layer (Kratos Framework)
Core business logic services built with **go-kratos/kratos**:

- **Catalog & CMS Service**: Manages product catalog, categories, brands, and content management
- **Pricing Service**: Calculates final product prices based on SKU + Warehouse configuration
- **Promotion Service**: Handles promotions and discount rules per SKU + Warehouse
- **Warehouse & Inventory Service**: Manages warehouses and inventory
- **Order Service**: Processes orders
- **Payment Service**: Handles payment processing and transactions
- **Shipping Service**: Manages shipping and fulfillment
- **Customer Service**: Manages customer information
- **Review Service**: Manages product reviews and ratings
- **Analytics & Reporting Service**: Provides business intelligence and data analytics
- **Loyalty & Rewards Service**: Manages customer loyalty programs and rewards

### 3️⃣ Shared & Infrastructure Services (Kratos Framework)
Supporting ecosystem services:

- **Auth Service (IAM)**: High-performance authentication and authorization with Consul permission matrix
- **User Service**: Internal user management and permissions
- **Notification Service**: Multi-channel notifications
- **Search Service**: Fast product and content search
- **Cache Layer**: Performance optimization with Redis
- **File Storage/CDN**: Media and static content delivery
- **Monitoring & Logging**: System observability with Prometheus + Jaeger

### 4️⃣ Event-Driven Runtime Layer (Dapr)
Portable event-driven runtime:

- **Dapr Pub/Sub**: Event-driven messaging with Redis backend
- **Dapr State Store**: Distributed state management
- **Dapr Service Invocation**: Service-to-service communication
- **Dapr Bindings**: External system integration
- **Dapr Secrets**: Secure secret management

### 5️⃣ Service Mesh & Discovery Layer (Consul)
Cloud-native infrastructure services:

- **Consul Service Discovery**: Automatic service registration and discovery
- **Consul KV Store**: Centralized configuration and service permission matrix
- **Consul Health Checks**: Service health monitoring and catalog management
- **Consul Connect**: Service mesh with automatic mTLS (optional)
- **Consul Sessions**: Distributed coordination and locking

## Design Principles

### Cloud-Native Principles
- **Kratos Framework**: Modern Go microservice framework
- **Service Discovery**: Dynamic service registration via Consul
- **Configuration Management**: Multi-source config (file, env, Consul KV)
- **Observability**: Built-in metrics, tracing, and structured logging
- **Dual Protocol**: gRPC (internal) + HTTP/REST (external)

### Event-Driven Architecture Principles
- **Dapr Event Bus**: Portable, event-driven runtime with Redis backend
- **Pub/Sub Messaging**: Asynchronous communication via Dapr pub/sub
- **Event Sourcing**: Event-driven data synchronization
- **Message Reliability**: At-least-once delivery guarantees
- **Multi-Cloud Portability**: Dapr abstracts infrastructure differences

### Security Principles
- **Zero Trust Architecture**: Every service call authenticated and authorized
- **Service Permission Matrix**: Centralized authorization via Consul KV
- **JWT Security**: RS256 signing with key rotation
- **Consul ACL**: Service-level access control
- **Dapr Security**: Built-in service-to-service authentication

### Performance Principles
- **Event-driven architecture**: Asynchronous communication via Dapr + Redis
- **Loose coupling between services**: Via service discovery and events
- **Real-time data synchronization**: Event streaming with Redis pub/sub
- **High-performance caching**: Redis + Consul KV optimization
- **Sub-30ms authentication**: Kratos framework optimization

### Operational Principles
- **Scalable and extensible design**: Horizontal scaling with Kubernetes + Dapr
- **Graceful shutdown**: Production-ready lifecycle management
- **Circuit breaker patterns**: Built-in resilience via Dapr
- **Health-based routing**: Only healthy services receive traffic
- **Infrastructure Abstraction**: Dapr provides portable runtime