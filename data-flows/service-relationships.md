# Service Relationships

## Service Relationships Overview

### Service Dependencies Matrix

| Service | Depends On | Provides Data To |
|---------|------------|------------------|
| **Auth Service** | Customer, User | All Services (token validation) |
| **User Service** | Auth | Auth, All Services (permission validation) |
| **Catalog Service** | - | Pricing, Search, Review, Warehouse, Promotion |
| **Pricing Service** | Catalog, Promotion, Customer, Warehouse | Order, Search, Cache |
| **Promotion Service** | Catalog, Customer, Warehouse | Pricing, Search |
| **Warehouse & Inventory** | Order, Shipping | Order, Shipping, Pricing, Search |
| **Order Service** | Auth, Pricing, Warehouse, Customer, Payment | Shipping, Payment, Notification, Customer, Review, Event Bus |
| **Payment Service** | Order, Customer | Order, Customer, Notification, Event Bus |
| **Shipping Service** | Order, Warehouse | Order, Notification, Warehouse, Event Bus |
| **Customer Service** | Auth, Order | Auth, Pricing, Promotion, Order, Notification |
| **Search Service** | Product, Pricing, Review, Warehouse | Frontend/API Gateway, Cache |
| **Review Service** | Order, Customer, Product | Product, Search, Customer, Notification |
| **Notification Service** | Order, Shipping, Payment, Auth, Review, User | External (Customers, Admins) |
| **Event Bus** | All Services | All Services (async events) |
| **Cache Layer** | Pricing, Product, Search | Pricing, Product, Search |

### Critical Data Paths

#### 1. Complete Order Creation Path
```
Frontend → API Gateway → Auth Service (authentication)
                      → Search Service (product discovery)
                      → Catalog Service (product details)
                      → Pricing Service ← Catalog Service (SKU & attributes)
                                       ← Promotion Service (SKU + Warehouse discounts)
                                       ← Customer Service (tier pricing)
                                       ← Warehouse Service (warehouse pricing config)
                      → Order Service ← Pricing Service (final price)
                                     ← Warehouse Service (stock check)
                                     ← Customer Service (billing info)
                      → Payment Service (payment processing)
                      → Shipping Service (fulfillment)
                      → Notification Service (confirmations)
                      → Event Bus (order events)
```

#### 2. Product Discovery & Search Path
```
Customer → Search Service ← Catalog Service (product catalog data)
                         ← Pricing Service (SKU + Warehouse prices)
                         ← Review Service (ratings)
                         ← Warehouse Service (availability)
                         → Cache Layer (performance)
```

#### 3. Inventory & Fulfillment Path
```
Shipping Service → Warehouse Service → Product Service (availability updates)
                                    → Pricing Service (stock-based pricing)
                                    → Search Service (availability indexing)
                                    → Order Service (stock status)
                                    → Event Bus (inventory events)
```

#### 4. Customer Experience & Personalization Path
```
Auth Service → Customer Service → Pricing Service (personalized pricing)
                                → Promotion Service (targeted offers)
                                → Order Service (purchase history)
                                → Review Service (review history)
                                → Notification Service (preferences)
```

#### 5. Payment Processing Path
```
Order Service → Payment Service → External Payment Gateways
                                → Customer Service (payment methods)
                                → Notification Service (payment alerts)
                                → Event Bus (payment events)
                                → Order Service (payment confirmation)
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
- **Order Events**: Order Service → Event Bus → (Shipping, Notification, Warehouse)
- **Payment Events**: Payment Service → Event Bus → (Order, Customer, Notification)
- **Inventory Events**: Warehouse Service → Event Bus → (Product, Search, Pricing)
- **Customer Events**: Customer Service → Event Bus → (Auth, Promotion, Notification)
- **Shipping Events**: Shipping Service → Event Bus → (Order, Notification, Warehouse)
- **Review Events**: Review Service → Event Bus → (Product, Search, Notification)

### Data Consistency Patterns

#### Strongly Consistent (ACID Transactions)
- **Payment Processing**: Payment confirmation and order status
- **Stock Reservation**: Inventory allocation during checkout
- **User Authentication**: Login and authorization
- **Order Creation**: Order data integrity

#### Eventually Consistent (Event-Driven)
- **Search Indexing**: Product, pricing, and inventory data in search
- **Cache Updates**: Cached data across services
- **Customer Order History**: Order records in customer service
- **Promotion Usage Tracking**: Promotion statistics and limits
- **Review Aggregation**: Product ratings and review counts
- **Notification Delivery**: Multi-channel notification status

#### Cached Data (Performance Optimization)
- **Product Catalog**: Frequently accessed product information
- **Pricing Data**: Calculated prices and promotional offers
- **Search Results**: Popular search queries and results
- **Customer Profiles**: User preferences and settings
- **Inventory Levels**: Stock availability (with TTL)