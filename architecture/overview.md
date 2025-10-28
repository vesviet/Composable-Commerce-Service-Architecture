# Architecture Overview (v2)

This version reflects the updated architecture where **Fulfillment** is now an **entity inside the Shipping Service**.  
It supports future expansion to **Last Mile, First Mile, and Hub-based logistics**.

## System Overview

## 3-Layer Architecture

### 1️⃣ Presentation Layer
- **Frontend (Storefront/Admin)**: User interfaces
- **API Gateway/BFF**: Backend for Frontend, request routing

### 2️⃣ Application Services Layer
Core business logic services:

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

### 3️⃣ Shared & Infrastructure Services
Supporting ecosystem services:

- **Auth Service (IAM)**: Authentication and authorization
- **User Service**: Internal user management and permissions
- **Notification Service**: Multi-channel notifications
- **Search Service**: Fast product and content search
- **Event Bus**: Asynchronous service communication
- **Cache Layer**: Performance optimization
- **File Storage/CDN**: Media and static content delivery
- **Monitoring & Logging**: System observability

## Design Principles

- Event-driven architecture
- Loose coupling between services
- Real-time data synchronization
- Scalable and extensible design