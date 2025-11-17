# Core Data Flow

## Overview
This document describes the main data flows between microservices in the system.

## 🧩 Main Data Flows

### 1. Authentication & Authorization Flow
**Source:** Auth Service  
**Data:** JWT tokens, user permissions, authentication status

**Flow:**
```
Auth Service → All Services (token validation)
Auth Service → Customer Service (user profile sync)
Auth Service → Notification Service (security alerts)
```

### 2. Catalog & CMS Flow
**Source:** Catalog & CMS Service  
**Data:** Product info, attributes, categories, brands, warehouse mapping, CMS content

**Flow:**
```
Catalog & CMS Service → Pricing Service (SKU & product attributes)
Catalog & CMS Service → Search Service (product indexing + content)
Catalog & CMS Service → Review Service (product validation)
Catalog & CMS Service → Warehouse & Inventory (product mapping)
Catalog & CMS Service → Promotion Service (product attributes for targeting)
Catalog & CMS Service → Analytics Service (product performance data)
```

### 3. Pricing Flow (SKU + Warehouse Based Calculator)
**Source:** Pricing Service  
**Data:** Final calculated prices, applied discounts, tax calculations

**Inputs:**
```
Catalog & CMS Service → Pricing Service (SKU & product attributes)
Promotion Service → Pricing Service (discount rules per SKU + Warehouse)
Customer Service → Pricing Service (customer tiers)
Warehouse & Inventory → Pricing Service (warehouse-specific pricing config)
Loyalty & Rewards Service → Pricing Service (loyalty discounts & tier pricing)
```

**Outputs:**
```
Pricing Service → Order Service (checkout pricing)
Pricing Service → Search Service (indexed pricing)
Pricing Service → Cache Layer (price caching)
```

### 4. Promotion Flow (SKU + Warehouse Based)
**Source:** Promotion Service  
**Data:** Active rules, promo conditions, discount strategies per SKU + Warehouse

**Inputs:**
```
Catalog & CMS Service → Promotion Service (SKU, category, brand info)
Warehouse & Inventory → Promotion Service (warehouse-specific rules)
Customer Service → Promotion Service (customer segments)
Loyalty & Rewards Service → Promotion Service (loyalty-based promotions)
```

**Flow:**
```
Promotion Service → Pricing Service (discount rules per SKU + Warehouse)
Promotion Service → Search Service (promotional content)
Promotion Service → Analytics Service (promotion performance data)
```

### 5. Inventory Flow
**Source:** Warehouse & Inventory Service  
**Data:** Real-time stock, reserved quantities, availability by location

**Inputs:**
```
Order Service → Warehouse & Inventory (stock reservations, order fulfillment)
Shipping Service → Warehouse & Inventory (delivery confirmations, returns)
Catalog & CMS Service → Warehouse & Inventory (product-warehouse mappings)
```

**Outputs:**
```
Warehouse & Inventory → Order Service (stock reservation confirmations)
Warehouse & Inventory → Shipping Service (fulfillment availability)
Warehouse & Inventory → Pricing Service (inventory-based pricing adjustments)
Warehouse & Inventory → Search Service (availability indexing)
Warehouse & Inventory → Analytics Service (inventory analytics)
Warehouse & Inventory → Event Bus (inventory events)
```

### 6. Order Flow (Central Orchestrator)
**Source:** Order Service  
**Data:** Order data, payment status, fulfillment instructions

**Inputs:**
```
Customer Service → Order Service (customer details, billing/shipping addresses)
Pricing Service → Order Service (final pricing with all discounts applied)
Warehouse & Inventory → Order Service (stock availability and reservations)
Payment Service → Order Service (payment confirmation and transaction details)
Loyalty & Rewards Service → Order Service (points redemption, tier benefits)
Auth Service → Order Service (user authentication and permissions)
```

**Outputs:**
```
Order Service → Shipping Service (fulfillment creation and instructions)
Order Service → Payment Service (payment processing requests)
Order Service → Notification Service (order status updates and confirmations)
Order Service → Customer Service (order history and purchase records)
Order Service → Review Service (purchase verification for review eligibility)
Order Service → Analytics Service (sales data and transaction analytics)
Order Service → Loyalty & Rewards Service (points earning and tier progress)
Order Service → Promotion Service (promotion usage tracking)
Order Service → Event Bus (order lifecycle events)
```

### 7. Payment Flow
**Source:** Payment Service  
**Data:** Payment status, transaction details, refund information

**Flow:**
```
Payment Service → Order Service (payment confirmation)
Payment Service → Customer Service (payment methods)
Payment Service → Notification Service (payment alerts)
Payment Service → Event Bus (payment events)
```

### 8. Shipping & Fulfillment Flow
**Source:** Shipping Service  
**Data:** Shipment details, tracking status, delivery proof

**Flow:**
```
Shipping Service → Order Service (delivery updates)
Shipping Service → Notification Service (shipping alerts)
Shipping Service → Warehouse & Inventory (stock sync)
Shipping Service → Event Bus (shipping events)
```

### 9. Search & Discovery Flow
**Source:** Search Service  
**Data:** Search results, suggestions, analytics

**Inputs:**
```
Catalog & CMS Service → Search Service (product data)
Pricing Service → Search Service (pricing data)
Review Service → Search Service (ratings data)
Warehouse & Inventory → Search Service (availability data)
```

**Outputs:**
```
Search Service → Frontend/API Gateway (search results)
Search Service → Cache Layer (search caching)
```

### 10. Review & Rating Flow
**Source:** Review Service  
**Data:** Product reviews, ratings, customer feedback

**Flow:**
```
Review Service → Catalog & CMS Service (rating display)
Review Service → Search Service (rating indexing)
Review Service → Customer Service (review history)
Review Service → Notification Service (review alerts)
Review Service → Analytics Service (review analytics)
```

### 11. Customer Flow
**Source:** Customer Service  
**Data:** Profile, preferences, loyalty, purchase history

**Flow:**
```
Customer Service → Auth Service (authentication data)
Customer Service → Order Service (billing/shipping details)
Customer Service → Pricing Service (personalized pricing)
Customer Service → Promotion Service (targeted offers)
Customer Service → Notification Service (communication preferences)
```

### 12. User Management & Permissions Flow
**Source:** User Service  
**Data:** Internal user profiles, roles, permissions, service access rights

**Flow:**
```
User Service → Auth Service (user authentication & authorization)
User Service → All Services (permission validation)
User Service → Notification Service (admin notifications)
```

### 13. File Storage & Media Flow
**Source:** File Storage/CDN Service  
**Data:** Product images, videos, review media, documents

**Flow:**
```
Catalog Service → File Storage/CDN (product media upload)
Review Service → File Storage/CDN (review images/videos)
File Storage/CDN → Cache Layer (media caching)
File Storage/CDN → Frontend/API Gateway (content delivery)
```

### 14. Monitoring & Observability Flow
**Source:** Monitoring & Logging Service  
**Data:** System metrics, logs, alerts, performance data

**Flow:**
```
All Services → Monitoring & Logging (metrics & logs)
Monitoring & Logging → User Service (admin alerts)
Monitoring & Logging → Notification Service (system alerts)
Monitoring & Logging → Event Bus (monitoring events)
```

### 15. Analytics & Reporting Flow
**Source:** Analytics & Reporting Service  
**Data:** Business intelligence, metrics, reports, insights

**Inputs:**
```
Order Service → Analytics Service (sales data, transaction details, order patterns)
Customer Service → Analytics Service (customer behavior, demographics, lifecycle)
Catalog & CMS Service → Analytics Service (product performance, content engagement, catalog metrics)
Warehouse & Inventory → Analytics Service (inventory levels, turnover rates, stock optimization)
Review Service → Analytics Service (ratings, sentiment analysis, review trends)
Search Service → Analytics Service (search patterns, conversion rates, popular queries)
Loyalty & Rewards Service → Analytics Service (loyalty program performance, tier distribution)
Payment Service → Analytics Service (payment methods, transaction success rates)
Shipping Service → Analytics Service (delivery performance, shipping costs, fulfillment metrics)
Promotion Service → Analytics Service (campaign effectiveness, discount usage, ROI)
Pricing Service → Analytics Service (pricing performance, elasticity, margin analysis)
```

**Outputs:**
```
Analytics Service → User Service (dashboard access, business reports, KPI metrics)
Analytics Service → Notification Service (automated reports, performance alerts, anomaly detection)
Analytics Service → Pricing Service (demand-based pricing insights, price optimization recommendations)
Analytics Service → Promotion Service (campaign optimization data, effectiveness metrics, ROI analysis)
Analytics Service → Customer Service (customer insights, segmentation data, behavior patterns)
Analytics Service → Catalog & CMS Service (product performance insights, content optimization)
Analytics Service → Warehouse & Inventory Service (inventory optimization recommendations, demand forecasting)
Analytics Service → Event Bus (analytics events, report generation notifications)
```

### 16. Loyalty & Rewards Flow
**Source:** Loyalty & Rewards Service  
**Data:** Loyalty status, points, rewards, tier benefits

**Inputs:**
```
Customer Service → Loyalty Service (customer profiles, registration data)
Order Service → Loyalty Service (purchase behavior, transaction amounts)
Payment Service → Loyalty Service (payment confirmations for points)
```

**Flow:**
```
Loyalty Service → Customer Service (loyalty status, tier information)
Loyalty Service → Pricing Service (tier-based pricing, loyalty discounts)
Loyalty Service → Promotion Service (loyalty-based promotions)
Loyalty Service → Order Service (points redemption, tier benefits)
Loyalty Service → Notification Service (tier changes, rewards available)
```

### 17. Event-Driven Communication
**Source:** Event Bus  
**Data:** Asynchronous events between services

**Key Events:**
```
Order Events → Inventory, Shipping, Notification, Customer, Analytics, Loyalty Services
Payment Events → Order, Customer, Notification, User, Analytics, Loyalty Services
Inventory Events → Catalog, Search, Pricing, Order, Analytics Services
Customer Events → Auth, Promotion, Notification, User, Loyalty, Analytics Services
User Events → Auth, Notification, Monitoring Services
Catalog Events → Search, Pricing, Promotion, Cache, Analytics Services
Review Events → Catalog, Search, Notification, Customer, Analytics Services
Shipping Events → Order, Notification, Warehouse, Customer, Analytics Services
Loyalty Events → Customer, Pricing, Promotion, Notification, Analytics Services
Analytics Events → User, Notification, Pricing, Promotion Services
```