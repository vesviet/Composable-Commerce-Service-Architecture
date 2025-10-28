# Service Relationships

## Service Relationships Overview

### Service Dependencies Matrix

| Service | Depends On | Provides Data To |
|---------|------------|------------------|
| **Auth Service** | Customer, User | All Services (token validation) |
| **User Service** | Auth | Auth, All Services (permission validation) |
| **Catalog & CMS Service** | - | Pricing, Search, Review, Warehouse, Promotion, Analytics |
| **Pricing Service** | Catalog, Promotion, Customer, Warehouse, Loyalty | Order, Search, Cache |
| **Promotion Service** | Catalog, Customer, Warehouse, Loyalty | Pricing, Search |
| **Warehouse & Inventory** | Order, Shipping | Order, Shipping, Pricing, Search |
| **Order Service** | Auth, Pricing, Warehouse, Customer, Payment, Loyalty | Shipping, Payment, Notification, Customer, Review, Analytics, Loyalty, Event Bus |
| **Payment Service** | Order, Customer | Order, Customer, Notification, Analytics, Event Bus |
| **Shipping Service** | Order, Warehouse | Order, Notification, Warehouse, Analytics, Event Bus |
| **Customer Service** | Auth, Order, Loyalty | Auth, Pricing, Promotion, Order, Notification, Loyalty, Analytics |
| **Search Service** | Catalog, Pricing, Review, Warehouse | Frontend/API Gateway, Cache |
| **Review Service** | Order, Customer, Catalog | Catalog, Search, Customer, Notification, Analytics |
| **Analytics & Reporting Service** | All Services | User, Notification, Pricing, Promotion |
| **Loyalty & Rewards Service** | Customer, Order, Payment | Customer, Pricing, Promotion, Order, Notification |
| **Notification Service** | Order, Shipping, Payment, Auth, Review, User | External (Customers, Admins) |
| **Event Bus** | All Services | All Services (async events) |
| **Cache Layer** | Pricing, Catalog, Search | Pricing, Catalog, Search |
| **File Storage/CDN** | Catalog, Review | Frontend/API Gateway |
| **Monitoring & Logging** | All Services | Operations Team, Alerts |

### Critical Data Paths

#### 1. Complete Order Creation Path
```
Frontend → API Gateway → Auth Service (authentication)
                      → Search Service (product discovery)
                      → Catalog & CMS Service (product details)
                      → Pricing Service ← Catalog Service (SKU & attributes)
                                       ← Promotion Service (SKU + Warehouse discounts)
                                       ← Customer Service (tier pricing)
                                       ← Warehouse Service (warehouse pricing config)
                                       ← Loyalty Service (loyalty discounts)
                      → Order Service ← Pricing Service (final price)
                                     ← Warehouse Service (stock check)
                                     ← Customer Service (billing info)
                                     ← Loyalty Service (points redemption)
                      → Payment Service (payment processing)
                      → Shipping Service (fulfillment)
                      → Notification Service (confirmations)
                      → Analytics Service (order tracking)
                      → Loyalty Service (points earning)
                      → Event Bus (order events)
```

#### 2. Product Discovery & Search Path
```
Customer → API Gateway → Search Service ← Catalog Service (product catalog data)
                                       ← Pricing Service (SKU + Warehouse prices)
                                       ← Review Service (ratings)
                                       ← Warehouse Service (availability)
                                       → Cache Layer (performance)
                                       → File Storage/CDN (product images)
```

#### 3. Inventory & Fulfillment Path
```
Shipping Service → Warehouse Service → Catalog & CMS Service (availability updates)
                                    → Pricing Service (stock-based pricing)
                                    → Search Service (availability indexing)
                                    → Order Service (stock status)
                                    → Analytics Service (fulfillment metrics)
                                    → Event Bus (inventory events)
```

#### 4. Customer Experience & Personalization Path
```
Auth Service → Customer Service → Pricing Service (personalized pricing)
                                → Promotion Service (targeted offers)
                                → Order Service (purchase history)
                                → Review Service (review history)
                                → Notification Service (preferences)
                                → Search Service (personalized results)
```

#### 5. Admin & Internal User Management Path
```
User Service → Auth Service → All Services (permission validation)
            → Notification Service (admin alerts)
            → Monitoring & Logging (audit trails)
            → Event Bus (user events)
```

#### 6. Payment Processing Path
```
Order Service → Payment Service → External Payment Gateways
                                → Customer Service (payment methods)
                                → Notification Service (payment alerts)
                                → Event Bus (payment events)
                                → Order Service (payment confirmation)
                                → User Service (admin payment alerts)
```

#### 7. Content & Media Management Path
```
Catalog & CMS Service → File Storage/CDN (product images, videos, CMS content)
Review Service → File Storage/CDN (review images, videos)
                → Cache Layer (media caching)
                → Frontend/API Gateway (content delivery)
```

#### 8. Analytics & Business Intelligence Path
```
All Services → Analytics Service (business data, metrics, events)
Analytics Service → User Service (dashboards, reports, insights)
Analytics Service → Pricing Service (demand insights, optimization)
Analytics Service → Promotion Service (campaign effectiveness, ROI)
Analytics Service → Notification Service (automated reports, alerts)
Analytics Service → Event Bus (analytics events)
```

#### 9. Loyalty & Customer Retention Path
```
Customer Service → Loyalty Service (customer profiles, registration)
Order Service → Loyalty Service (purchase behavior, points earning)
Payment Service → Loyalty Service (transaction confirmations)
Loyalty Service → Pricing Service (tier-based discounts)
Loyalty Service → Promotion Service (loyalty-based campaigns)
Loyalty Service → Customer Service (tier status, benefits)
Loyalty Service → Notification Service (tier changes, rewards)
```

### Event Propagation

#### Synchronous Calls (Real-time Requirements)
- **Authentication**: All services → Auth Service (token validation)
- **Price Calculation**: Order → Pricing Service (real-time pricing)
- **Payment Processing**: Order → Payment Service (payment confirmation)
- **Stock Validation**: Order → Warehouse Service (availability check)
- **Customer Lookup**: Order → Customer Service (billing/shipping info)
- **Search Queries**: Frontend → Search Service (product discovery)

#### Asynchronous Events (Event-Driven Communication)
- **Order Events**: Order Service → Event Bus → (Shipping, Notification, Warehouse, Customer, Analytics, Loyalty)
- **Payment Events**: Payment Service → Event Bus → (Order, Customer, Notification, User, Analytics, Loyalty)
- **Inventory Events**: Warehouse Service → Event Bus → (Catalog, Search, Pricing, Order, Analytics)
- **Customer Events**: Customer Service → Event Bus → (Auth, Promotion, Notification, User, Loyalty, Analytics)
- **Shipping Events**: Shipping Service → Event Bus → (Order, Notification, Warehouse, Customer, Analytics, Loyalty)
- **Review Events**: Review Service → Event Bus → (Catalog, Search, Notification, Customer, Analytics)
- **User Events**: User Service → Event Bus → (Auth, Notification, Monitoring, Analytics)
- **Catalog Events**: Catalog Service → Event Bus → (Search, Pricing, Promotion, Cache, Analytics)
- **Promotion Events**: Promotion Service → Event Bus → (Pricing, Search, Notification, Analytics)
- **Search Events**: Search Service → Event Bus → (Monitoring, Analytics)
- **Loyalty Events**: Loyalty Service → Event Bus → (Customer, Pricing, Promotion, Notification, Analytics)
- **Analytics Events**: Analytics Service → Event Bus → (User, Notification, Pricing, Promotion)

### Data Consistency Patterns

#### Strongly Consistent (ACID Transactions)
- **Payment Processing**: Payment confirmation and order status
- **Stock Reservation**: Inventory allocation during checkout
- **User Authentication**: Login and authorization
- **Order Creation**: Order data integrity

#### Eventually Consistent (Event-Driven)
- **Search Indexing**: Catalog, pricing, inventory, and review data in search
- **Cache Updates**: Cached data across all services
- **Customer Order History**: Order records in customer service
- **Promotion Usage Tracking**: Promotion statistics and limits
- **Review Aggregation**: Product ratings and review counts
- **Notification Delivery**: Multi-channel notification status
- **User Permission Updates**: Role and permission changes across services
- **Media Content**: Product images and review media in CDN

#### Cached Data (Performance Optimization)
- **Catalog Data**: Product information, categories, brands
- **Pricing Data**: Calculated prices and promotional offers
- **Search Results**: Popular search queries and results
- **Customer Profiles**: User preferences and settings
- **Inventory Levels**: Stock availability (with TTL)
- **User Permissions**: Role-based access control data
- **Media URLs**: Product and review media references