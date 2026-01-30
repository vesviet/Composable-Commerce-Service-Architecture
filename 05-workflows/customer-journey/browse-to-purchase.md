# 🛍️ Complete Customer Journey: Browse to Purchase

**Last Updated**: January 29, 2026  
**Status**: Based on Actual Implementation  
**Services Involved**: 15 services across the complete customer journey  
**Navigation**: [← Customer Journey](README.md) | [← Workflows](../README.md)

---

## 📋 **Overview**

This document describes the complete end-to-end customer journey from product discovery to order delivery, based on the actual implementation of our 19-service microservices platform. The workflow spans multiple services and includes all business logic, event flows, and integration points.

### **Business Context**
- **Domain**: Complete E-Commerce Customer Experience
- **Objective**: Convert visitors to customers through seamless shopping experience
- **Success Criteria**: Order completion with customer satisfaction
- **Key Metrics**: Conversion rate (target: 3-5%), cart abandonment rate, order completion time

---

## 🏗️ **Service Architecture**

### **Primary Services**
| Service | Role | Completion | Key Responsibilities |
|---------|------|------------|---------------------|
| 🚪 **Gateway Service** | Entry Point | 95% | Request routing, authentication, rate limiting |
| 🔍 **Search Service** | Discovery | 95% | Product search, filtering, recommendations |
| 📦 **Catalog Service** | Product Data | 95% | Product details, categories, attributes |
| 💰 **Pricing Service** | Price Calculation | 92% | Dynamic pricing, tax calculation |
| 📊 **Warehouse Service** | Stock Data | 90% | Inventory levels, availability |
| 🛍️ **Checkout Service** | Cart & Checkout | 90% | Cart management, checkout orchestration |
| 🎯 **Promotion Service** | Discounts | 92% | Coupon validation, discount calculation |
| 💳 **Payment Service** | Payment Processing | 95% | Multi-gateway payment processing |
| 🛒 **Order Service** | Order Management | 90% | Order creation, status management |
| 📋 **Fulfillment Service** | Order Processing | 92% | Pick, pack, ship workflow |
| 🚚 **Shipping Service** | Logistics | 85% | Multi-carrier shipping, tracking |
| 📧 **Notification Service** | Communication | 90% | Email, SMS, push notifications |
| ⭐ **Review Service** | Feedback | 85% | Product reviews, ratings |
| 🎁 **Loyalty Service** | Rewards | 95% | Points, tiers, rewards |
| 👤 **Customer Service** | Profile Data | 95% | Customer profiles, preferences |

---

## 🔄 **Complete Customer Journey Flow**

### **Phase 1: Discovery & Browsing**

#### **1.1 Product Search & Discovery**
**Services**: Gateway → Search → Catalog → Warehouse → Pricing

```mermaid
sequenceDiagram
    participant C as Customer
    participant G as Gateway
    participant S as Search Service
    participant CAT as Catalog Service
    participant W as Warehouse Service
    participant P as Pricing Service
    
    C->>G: GET /search?q=laptop&category=electronics
    G->>G: Rate limiting, authentication (optional)
    G->>S: SearchProducts(query, filters)
    
    S->>S: Elasticsearch query with facets
    S->>CAT: GetProductDetails(product_ids)
    S->>W: GetStockLevels(product_ids)
    S->>P: GetPrices(product_ids, currency=VND)
    
    par Parallel Data Fetching
        CAT-->>S: Product details, attributes
    and
        W-->>S: Stock levels per warehouse
    and
        P-->>S: Prices with discounts
    end
    
    S->>S: Apply visibility rules, merge data
    S-->>G: SearchResults with facets
    G-->>C: Product listing with filters
```

**Key Features:**
- **Full-text Search**: Elasticsearch with Vietnamese language support
- **Faceted Search**: Category, brand, price range, ratings filters
- **Real-time Stock**: Warehouse-specific availability
- **Dynamic Pricing**: Real-time price calculation with promotions
- **Visibility Rules**: Age restrictions, geo-restrictions, customer segments

#### **1.2 Product Detail View**
**Services**: Gateway → Catalog → Pricing → Warehouse → Review

```mermaid
sequenceDiagram
    participant C as Customer
    participant G as Gateway
    participant CAT as Catalog Service
    participant P as Pricing Service
    participant W as Warehouse Service
    participant R as Review Service
    
    C->>G: GET /products/{product_id}
    G->>CAT: GetProduct(product_id)
    
    par Parallel Data Loading
        CAT->>CAT: Get product details, attributes
        CAT-->>G: Product information
    and
        G->>P: GetPrice(product_id, customer_segment)
        P-->>G: Price with tax, discounts
    and
        G->>W: GetStock(product_id, warehouses)
        W-->>G: Stock levels, delivery estimates
    and
        G->>R: GetReviews(product_id, limit=10)
        R-->>G: Customer reviews, ratings
    end
    
    G->>G: Merge product data
    G-->>C: Complete product details
```

**Product Data Includes:**
- **Basic Info**: Name, description, SKU, brand
- **Attributes**: EAV system (Tier 1: hot attributes, Tier 2: flexible attributes)
- **Pricing**: Base price, discounts, tax-inclusive price
- **Availability**: Stock levels per warehouse, delivery estimates
- **Reviews**: Customer ratings, review summaries
- **Recommendations**: Related products, frequently bought together

---

### **Phase 2: Cart Management & Engagement**

#### **2.1 Add to Cart**
**Services**: Gateway → Checkout → Catalog → Pricing → Warehouse

```mermaid
sequenceDiagram
    participant C as Customer
    participant G as Gateway
    participant CH as Checkout Service
    participant CAT as Catalog Service
    participant P as Pricing Service
    participant W as Warehouse Service
    participant Cache as Redis Cache
    
    C->>G: POST /cart/items {product_id, quantity, warehouse_id}
    G->>G: Extract customer context (JWT or guest token)
    G->>CH: AddToCart(session_id, item)
    
    CH->>CH: Get or create cart session
    
    par Validation & Pricing
        CH->>CAT: ValidateProduct(product_id)
        CAT-->>CH: Product valid, active
    and
        CH->>P: CalculatePrice(product_id, quantity, warehouse_id)
        P-->>CH: Item price with tax
    and
        CH->>W: CheckStock(product_id, warehouse_id, quantity)
        W-->>CH: Stock available
    end
    
    alt Item exists in cart
        CH->>CH: Update existing item quantity
    else New item
        CH->>CH: Create new cart item
    end
    
    CH->>Cache: InvalidateCart(session_id)
    CH->>CH: PublishEvent(cart_item_added)
    CH-->>G: Cart updated
    G-->>C: Item added to cart
```

**Business Rules:**
- **Stock Validation**: Must have sufficient stock in selected warehouse
- **Price Calculation**: Real-time pricing with customer-specific discounts
- **Quantity Limits**: Maximum quantity per item (configurable)
- **Product Validation**: Product must be active and available
- **Session Management**: Guest sessions converted to customer sessions on login

#### **2.2 Cart Management Operations**
**Services**: Checkout Service (primary)

**Supported Operations:**
- **Update Quantity**: Recalculate pricing and validate stock
- **Remove Item**: Clean removal with cache invalidation
- **Apply Coupon**: Promotion service integration
- **Cart Merge**: Guest to customer cart merge on login
- **Cart Refresh**: Handle price/stock changes

#### **2.3 Promotion Application**
**Services**: Checkout → Promotion → Customer

```mermaid
sequenceDiagram
    participant C as Customer
    participant CH as Checkout Service
    participant PR as Promotion Service
    participant CUS as Customer Service
    
    C->>CH: ApplyCoupon(cart_id, coupon_code)
    CH->>PR: ValidatePromotion(coupon_code, cart_data)
    
    PR->>PR: Check coupon validity, usage limits
    PR->>CUS: GetCustomerSegment(customer_id)
    CUS-->>PR: Customer segment data
    
    PR->>PR: Evaluate promotion rules
    alt Promotion valid
        PR->>PR: Calculate discount amount
        PR-->>CH: Discount details
        CH->>CH: Apply discount to cart
        CH-->>C: Coupon applied successfully
    else Promotion invalid
        PR-->>CH: Validation error
        CH-->>C: Coupon invalid or expired
    end
```

---

### **Phase 3: Checkout Process**

#### **3.1 Checkout Initiation**
**Services**: Gateway → Checkout → Warehouse → Shipping

```mermaid
sequenceDiagram
    participant C as Customer
    participant G as Gateway
    participant CH as Checkout Service
    participant W as Warehouse Service
    participant SH as Shipping Service
    
    C->>G: POST /checkout/start {cart_session_id}
    G->>CH: StartCheckout(cart_session_id)
    
    CH->>CH: Validate cart has items
    CH->>CH: Create checkout session
    
    par Checkout Preparation
        CH->>W: ReserveStock(cart_items, ttl=30min)
        W-->>CH: Stock reserved
    and
        CH->>SH: GetShippingRates(destination, items)
        SH-->>CH: Available shipping methods
    end
    
    CH->>CH: Lock cart (prevent modifications)
    CH-->>G: Checkout session created
    G-->>C: Checkout ready
```

#### **3.2 Shipping & Address Selection**
**Services**: Checkout → Shipping → Customer

```mermaid
sequenceDiagram
    participant C as Customer
    participant CH as Checkout Service
    participant SH as Shipping Service
    participant CUS as Customer Service
    
    C->>CH: UpdateShippingAddress(checkout_id, address)
    CH->>CUS: ValidateAddress(address)
    CUS-->>CH: Address valid
    
    CH->>SH: CalculateShippingRates(address, items)
    SH->>SH: Multi-carrier rate calculation
    SH-->>CH: Shipping options with rates
    
    CH->>CH: Update checkout session
    CH-->>C: Shipping options available
    
    C->>CH: SelectShippingMethod(checkout_id, method_id)
    CH->>CH: Update checkout with shipping method
    CH-->>C: Shipping method selected
```

#### **3.3 Payment Method Selection**
**Services**: Checkout → Payment

```mermaid
sequenceDiagram
    participant C as Customer
    participant CH as Checkout Service
    participant PAY as Payment Service
    
    C->>CH: SelectPaymentMethod(checkout_id, payment_method_id)
    CH->>PAY: ValidatePaymentMethod(customer_id, payment_method_id)
    PAY-->>CH: Payment method valid
    
    CH->>CH: Update checkout session
    CH-->>C: Payment method selected
```

---

### **Phase 4: Order Creation & Payment**

#### **4.1 Order Preview**
**Services**: Checkout → Pricing → Promotion → Shipping

```mermaid
sequenceDiagram
    participant C as Customer
    participant CH as Checkout Service
    participant P as Pricing Service
    participant PR as Promotion Service
    participant SH as Shipping Service
    
    C->>CH: PreviewOrder(checkout_id)
    
    par Final Calculations
        CH->>P: CalculateTax(items, shipping_address)
        P-->>CH: Tax amount
    and
        CH->>PR: ValidatePromotions(cart, customer)
        PR-->>CH: Final discount amount
    and
        CH->>SH: GetFinalShippingCost(method, address)
        SH-->>CH: Shipping cost
    end
    
    CH->>CH: Calculate final totals
    CH-->>C: Order preview with all costs
```

#### **4.2 Order Confirmation & Payment**
**Services**: Checkout → Order → Payment → Warehouse → Notification

```mermaid
sequenceDiagram
    participant C as Customer
    participant CH as Checkout Service
    participant O as Order Service
    participant PAY as Payment Service
    participant W as Warehouse Service
    participant N as Notification Service
    
    C->>CH: ConfirmCheckout(checkout_id)
    
    CH->>CH: Final validation
    CH->>PAY: AuthorizePayment(amount, payment_method)
    PAY-->>CH: Payment authorized
    
    CH->>O: CreateOrder(order_data)
    O->>O: Create order record
    O-->>CH: Order created
    
    CH->>PAY: CapturePayment(authorization_id)
    PAY-->>CH: Payment captured
    
    CH->>W: ConfirmStockReservation(reservation_ids)
    W-->>CH: Stock confirmed
    
    CH->>N: SendOrderConfirmation(order_id, customer_id)
    N-->>CH: Notification sent
    
    CH-->>C: Order confirmed
```

**Payment Methods Supported:**
- **Credit/Debit Cards**: Stripe integration
- **E-wallets**: PayPal, VNPay, MoMo
- **Bank Transfer**: VNPay integration
- **Cash on Delivery**: COD with shipping validation

---

### **Phase 5: Order Fulfillment**

#### **5.1 Fulfillment Creation**
**Services**: Order → Fulfillment → Warehouse

```mermaid
sequenceDiagram
    participant O as Order Service
    participant F as Fulfillment Service
    participant W as Warehouse Service
    
    O->>O: Order status: CONFIRMED
    O->>F: CreateFulfillment(order_id)
    
    F->>F: Create fulfillment record
    F->>W: GetWarehouseCapacity(warehouses, date)
    W-->>F: Available time slots
    
    F->>F: Assign warehouse and time slot
    F->>F: Status: PLANNING
    F-->>O: Fulfillment created
    
    O->>O: Order status: PROCESSING
```

#### **5.2 Pick, Pack, Ship Workflow**
**Services**: Fulfillment → Warehouse → Shipping → Notification

```mermaid
sequenceDiagram
    participant F as Fulfillment Service
    participant W as Warehouse Service
    participant SH as Shipping Service
    participant N as Notification Service
    
    Note over F: Picking Phase
    F->>F: Generate picking list
    F->>W: UpdateStock(picked_items)
    F->>F: Status: PICKED
    
    Note over F: Packing Phase
    F->>F: Verify package weight
    F->>F: Generate packing slip
    F->>F: Status: PACKED
    
    Note over F: Quality Control (if required)
    F->>F: Perform QC checks
    F->>F: Record QC results
    
    Note over F: Shipping Phase
    F->>SH: GenerateShippingLabel(package_data)
    SH-->>F: Shipping label
    F->>SH: HandoverToCarrier(package_id)
    SH-->>F: Tracking number
    
    F->>F: Status: SHIPPED
    F->>N: SendShippingNotification(order_id, tracking)
    N-->>Customer: Shipping notification
```

**Quality Control Rules:**
- **High-value orders** (≥1M VND): 100% QC required
- **Random sampling**: 10% of all orders
- **Manual QC**: Admin-triggered for specific orders
- **QC checks**: Item count, weight verification, defect inspection

---

### **Phase 6: Delivery & Post-Purchase**

#### **6.1 Delivery Tracking**
**Services**: Shipping → Notification → Order

```mermaid
sequenceDiagram
    participant Carrier as Shipping Carrier
    participant SH as Shipping Service
    participant N as Notification Service
    participant O as Order Service
    participant Customer as Customer
    
    Carrier->>SH: Webhook: Package in transit
    SH->>N: SendTrackingUpdate(order_id, status)
    N-->>Customer: Package in transit
    
    Carrier->>SH: Webhook: Package delivered
    SH->>O: UpdateOrderStatus(order_id, DELIVERED)
    O->>O: Order status: DELIVERED
    SH->>N: SendDeliveryConfirmation(order_id)
    N-->>Customer: Package delivered
```

#### **6.2 Post-Purchase Experience**
**Services**: Review → Loyalty → Analytics

```mermaid
sequenceDiagram
    participant O as Order Service
    participant R as Review Service
    participant L as Loyalty Service
    participant A as Analytics Service
    participant N as Notification Service
    participant Customer as Customer
    
    O->>O: Order delivered (7 days ago)
    O->>R: EnableReviewCollection(order_id)
    R->>N: SendReviewRequest(customer_id, products)
    N-->>Customer: Review request email
    
    O->>L: AwardLoyaltyPoints(customer_id, order_value)
    L->>L: Calculate points based on tier
    L->>N: SendPointsNotification(customer_id, points)
    N-->>Customer: Points awarded notification
    
    Customer->>R: SubmitReview(product_id, rating, comment)
    R->>R: Store review, update product rating
    R->>A: TrackReviewSubmission(customer_id, product_id)
```

---

## 📊 **Event Flow Architecture**

### **Key Events Published**

**Search & Discovery Events:**
- `search.query.executed` → Analytics Service
- `product.viewed` → Analytics Service
- `search.result.clicked` → Analytics Service

**Cart & Checkout Events:**
- `cart.item.added` → Analytics Service
- `cart.item.removed` → Analytics Service
- `cart.abandoned` → Notification Service (abandoned cart emails)
- `checkout.started` → Analytics Service
- `checkout.completed` → Analytics Service

**Order Events:**
- `order.created` → Fulfillment, Notification, Analytics
- `order.confirmed` → Fulfillment, Notification, Analytics
- `order.shipped` → Notification, Analytics, Loyalty
- `order.delivered` → Review, Loyalty, Analytics

**Payment Events:**
- `payment.authorized` → Order Service
- `payment.captured` → Order Service, Notification
- `payment.failed` → Order Service, Notification

**Fulfillment Events:**
- `fulfillment.created` → Warehouse Service
- `fulfillment.picked` → Warehouse Service
- `fulfillment.packed` → Shipping Service
- `fulfillment.shipped` → Notification Service

---

## 🎯 **Business Rules & Validation**

### **Cart Management Rules**
- **Maximum items per cart**: 50 items
- **Maximum quantity per item**: 99 units
- **Stock validation**: Real-time stock checking
- **Price recalculation**: On every cart modification
- **Session timeout**: 24 hours for guest, 30 days for customers

### **Checkout Validation Rules**
- **Minimum order value**: 50,000 VND
- **Maximum order value**: 50,000,000 VND
- **Stock reservation**: 30-minute TTL
- **Address validation**: Required for shipping
- **Payment method validation**: Must belong to customer

### **Order Processing Rules**
- **Payment authorization**: Required before order creation
- **Stock confirmation**: Must confirm reservations
- **Fulfillment assignment**: Based on warehouse capacity
- **Quality control**: High-value orders require QC

---

## 📈 **Performance Metrics & SLAs**

### **Target Performance**
| Operation | Target Latency (P95) | Target Throughput |
|-----------|---------------------|-------------------|
| Product Search | <100ms | 1,000 queries/sec |
| Add to Cart | <200ms | 500 operations/sec |
| Checkout Start | <300ms | 100 operations/sec |
| Order Creation | <500ms | 50 orders/sec |
| Payment Processing | <2s | 25 payments/sec |

### **Business Metrics**
| Metric | Target | Current |
|--------|--------|---------|
| Conversion Rate | 3-5% | Tracking |
| Cart Abandonment | <70% | Tracking |
| Order Completion Time | <5 minutes | Tracking |
| Customer Satisfaction | >4.5/5 | Tracking |

---

## 🔒 **Security & Compliance**

### **Security Measures**
- **JWT Authentication**: All customer operations
- **Rate Limiting**: Prevent abuse and DDoS
- **Input Validation**: All user inputs sanitized
- **PCI DSS Compliance**: Payment data protection
- **GDPR Compliance**: Customer data protection

### **Audit Trails**
- **Customer Actions**: All cart and order operations logged
- **Payment Transactions**: Complete payment audit trail
- **Order Changes**: Full order lifecycle tracking
- **Security Events**: Authentication and authorization events

---

## 🚨 **Error Handling & Recovery**

### **Common Error Scenarios**

**Stock Unavailability:**
- **Detection**: Real-time stock checking
- **Response**: Remove item from cart, notify customer
- **Recovery**: Suggest alternatives, backorder option

**Payment Failures:**
- **Detection**: Payment gateway response
- **Response**: Retry payment, alternative methods
- **Recovery**: Hold cart for 15 minutes, send recovery email

**Service Unavailability:**
- **Detection**: Circuit breaker patterns
- **Response**: Graceful degradation, cached data
- **Recovery**: Automatic retry with exponential backoff

### **Compensation Patterns**
- **Order Creation Failure**: Release stock reservations, void payment
- **Payment Capture Failure**: Cancel order, release stock
- **Fulfillment Failure**: Retry or cancel order with refund

---

## 📋 **Integration Points**

### **External Integrations**
- **Payment Gateways**: Stripe, PayPal, VNPay, MoMo
- **Shipping Carriers**: GHN, Grab, VNPay Shipping, MoMo
- **Email Service**: SendGrid, AWS SES
- **SMS Service**: Twilio, local providers
- **Analytics**: Google Analytics, custom analytics

### **Internal Service Dependencies**
- **Critical Path**: Gateway → Search/Catalog → Checkout → Order → Payment → Fulfillment
- **Supporting Services**: Pricing, Promotion, Warehouse, Shipping, Notification
- **Data Services**: Customer, Review, Loyalty, Analytics

---

## 🔄 **Continuous Improvement**

### **Optimization Opportunities**
- **Search Performance**: Elasticsearch optimization, caching strategies
- **Cart Performance**: Redis optimization, session management
- **Checkout Conversion**: A/B testing, UX improvements
- **Payment Success**: Gateway optimization, retry strategies

### **Monitoring & Analytics**
- **Real-time Dashboards**: Order flow monitoring
- **Business Intelligence**: Conversion funnel analysis
- **Performance Monitoring**: Service latency and throughput
- **Customer Feedback**: Review analysis, satisfaction surveys

---

**Document Status**: ✅ Complete Implementation-Based Documentation  
**Last Updated**: January 29, 2026  
**Next Review**: February 29, 2026  
**Maintained By**: Customer Experience & Architecture Team