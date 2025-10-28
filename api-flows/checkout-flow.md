# Complete Checkout Flow - From Cart to Order Completion

## Overview
This document describes the complete checkout flow from adding items to cart through order completion. The flow is broken down into multiple sub-flows that work together to provide a seamless checkout experience.

## Flow Structure
1. **Add to Cart Flow** - Adding products to shopping cart
2. **Cart Management Flow** - View, update, and validate cart
3. **Checkout Initiation Flow** - Start checkout process with validation
4. **Payment Processing Flow** - Handle payment and confirmation
5. **Order Completion Flow** - Finalize order and trigger fulfillment

---

# 1. Add to Cart Flow

## Sequence Diagram - Add to Cart

```mermaid
sequenceDiagram
    participant Client
    participant API as API Gateway
    participant Auth as Auth Service
    participant Cart as Cart Service
    participant Cat as Catalog Service
    participant Inv as Warehouse & Inventory
    participant Cache as Cache Layer

    %% Add Item to Cart
    Client->>API: POST /cart/items
    Note over Client: Payload: {productId, sku, quantity, warehouseId}
    
    API->>Auth: Validate JWT Token
    Auth-->>API: Token Valid + Customer ID
    
    %% Get Product Data with Pricing
    API->>Cat: GET /catalog/products/{productId}/complete
    Note over Cat: Get complete product data:<br/>- Product details<br/>- Current pricing<br/>- Stock availability<br/>- Promotions
    Cat-->>API: Complete Product Data
    
    %% Validate Stock Availability
    alt Stock Available
        API->>Cart: Add Item to Cart
        Cart->>Cart: Calculate cart totals
        Cart-->>API: Cart Updated
        
        %% Update Cache
        API->>Cache: Update cart cache
        
        API-->>Client: 200 OK + Updated Cart
    else Out of Stock
        API-->>Client: 400 Bad Request - Out of Stock
    end
```

## Add to Cart API

### Request
```http
POST /api/v1/cart/items
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "productId": "PROD-12345",
  "sku": "SKU-ABC-001",
  "quantity": 2,
  "warehouseId": "US-WEST-01"
}
```

### Response
```json
{
  "success": true,
  "cart": {
    "id": "CART-789012",
    "customerId": "CUST-12345",
    "items": [
      {
        "id": "CART_ITEM-001",
        "productId": "PROD-12345",
        "sku": "SKU-ABC-001",
        "name": "Premium Wireless Headphones",
        "quantity": 2,
        "unitPrice": 249.99,
        "totalPrice": 499.98,
        "warehouse": "US-WEST-01",
        "addedAt": "2024-08-10T14:30:00Z"
      }
    ],
    "totals": {
      "subtotal": 499.98,
      "itemCount": 2,
      "currency": "USD"
    },
    "updatedAt": "2024-08-10T14:30:00Z"
  }
}
```

---

# 2. Cart Management Flow

## Sequence Diagram - View/Update Cart

```mermaid
sequenceDiagram
    participant Client
    participant API as API Gateway
    participant Auth as Auth Service
    participant Cart as Cart Service
    participant Cat as Catalog Service
    participant Cache as Cache Layer

    %% Get Cart
    Client->>API: GET /cart
    API->>Auth: Validate JWT Token
    Auth-->>API: Token Valid + Customer ID
    
    %% Check Cache First
    API->>Cache: Get cached cart
    alt Cache Hit
        Cache-->>API: Cached Cart Data
    else Cache Miss
        API->>Cart: GET /carts/{customerId}
        Cart-->>API: Cart Data
        
        %% Get Fresh Pricing for All Items
        loop For each cart item
            API->>Cat: GET /catalog/products/{productId}/pricing
            Cat-->>API: Current Pricing
        end
        
        API->>Cart: Update cart with fresh pricing
        Cart-->>API: Updated Cart
        
        API->>Cache: Cache updated cart (TTL: 5min)
    end
    
    API-->>Client: Cart with Current Pricing

    %% Update Cart Item
    Client->>API: PUT /cart/items/{itemId}
    Note over Client: Update quantity or remove item
    
    API->>Auth: Validate JWT Token
    Auth-->>API: Token Valid + Customer ID
    
    API->>Cart: Update Cart Item
    Cart->>Cart: Recalculate totals
    Cart-->>API: Updated Cart
    
    %% Invalidate Cache
    API->>Cache: Invalidate cart cache
    
    API-->>Client: 200 OK + Updated Cart
```

## Cart Management APIs

### Get Cart
```http
GET /api/v1/cart
Authorization: Bearer {jwt_token}
```

### Update Cart Item
```http
PUT /api/v1/cart/items/{itemId}
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "quantity": 3
}
```

### Remove Cart Item
```http
DELETE /api/v1/cart/items/{itemId}
Authorization: Bearer {jwt_token}
```

---

# 3. Checkout Initiation Flow

## Sequence Diagram - Start Checkout

```mermaid
sequenceDiagram
    participant Client
    participant API as API Gateway
    participant Auth as Auth Service
    participant Checkout as Checkout Service
    participant Cart as Cart Service
    participant Cat as Catalog Service
    participant Cust as Customer Service
    participant Promo as Promotion Service
    participant Loyalty as Loyalty Service

    %% Initiate Checkout
    Client->>API: POST /checkout/initiate
    API->>Auth: Validate JWT Token
    Auth-->>API: Token Valid + Customer ID
    
    %% Get Current Cart
    API->>Cart: GET /carts/{customerId}
    Cart-->>API: Current Cart Items
    
    %% Validate All Cart Items (Parallel)
    par Validate Cart Items
        loop For each cart item
            API->>Cat: GET /catalog/products/{productId}/complete
            Note over Cat: Validate:<br/>- Product still available<br/>- Current pricing<br/>- Stock availability
            Cat-->>API: Product Validation Result
        end
    and
        %% Get Customer Context
        API->>Cust: GET /customers/{customerId}/checkout-context
        Note over Cust: Get:<br/>- Saved addresses<br/>- Payment methods<br/>- Preferences
        Cust-->>API: Customer Checkout Context
    and
        %% Get Available Promotions
        API->>Promo: GET /promotions/applicable
        Note over Promo: Get promotions applicable<br/>to current cart items
        Promo-->>API: Available Promotions
    and
        %% Get Loyalty Information
        API->>Loyalty: GET /loyalty/{customerId}/checkout-benefits
        Note over Loyalty: Get:<br/>- Available points<br/>- Tier benefits<br/>- Redemption options
        Loyalty-->>API: Loyalty Benefits
    end
    
    %% Create Checkout Session
    API->>Checkout: Create Checkout Session
    Note over Checkout: Create session with:<br/>- Validated cart items<br/>- Customer context<br/>- Available promotions<br/>- Loyalty benefits
    Checkout-->>API: Checkout Session Created
    
    API-->>Client: Checkout Session + Available Options
```

## Checkout Initiation API

### Request
```http
POST /api/v1/checkout/initiate
Authorization: Bearer {jwt_token}
```

### Response
```json
{
  "checkoutSessionId": "CHECKOUT-789012",
  "cart": {
    "items": [
      {
        "productId": "PROD-12345",
        "sku": "SKU-ABC-001",
        "name": "Premium Wireless Headphones",
        "quantity": 2,
        "unitPrice": 249.99,
        "totalPrice": 499.98,
        "stockStatus": "available"
      }
    ],
    "totals": {
      "subtotal": 499.98,
      "currency": "USD"
    }
  },
  "customer": {
    "addresses": [
      {
        "id": "ADDR-001",
        "type": "shipping",
        "street": "123 Main St",
        "city": "San Francisco",
        "state": "CA",
        "zipCode": "94105",
        "isDefault": true
      }
    ],
    "paymentMethods": [
      {
        "id": "PM-001",
        "type": "credit_card",
        "last4": "4242",
        "brand": "visa",
        "isDefault": true
      }
    ]
  },
  "promotions": [
    {
      "code": "SUMMER2024",
      "description": "Summer Sale - 20% off",
      "discount": 99.99,
      "applicable": true
    }
  ],
  "loyalty": {
    "availablePoints": 1250,
    "pointsValue": 12.50,
    "tierBenefits": {
      "freeShipping": true,
      "discountPercentage": 5
    }
  }
}
```

---

# 4. Payment Processing Flow

## Sequence Diagram - Process Payment

```mermaid
sequenceDiagram
    participant Client
    participant API as API Gateway
    participant Auth as Auth Service
    participant Checkout as Checkout Service
    participant Order as Order Service
    participant Pay as Payment Service
    participant Inv as Warehouse & Inventory
    participant Ship as Shipping Service
    participant Promo as Promotion Service
    participant Loyalty as Loyalty Service

    %% Submit Checkout
    Client->>API: POST /checkout/submit
    Note over Client: Payload includes:<br/>- Checkout session ID<br/>- Shipping address<br/>- Payment method<br/>- Promotion codes
    
    API->>Auth: Validate JWT Token
    Auth-->>API: Token Valid + Customer ID
    
    %% Get Checkout Session
    API->>Checkout: GET /checkout/{sessionId}
    Checkout-->>API: Checkout Session Data
    
    %% Reserve Stock for All Items
    par Reserve Stock
        loop For each item
            API->>Inv: POST /inventory/reserve
            Note over Inv: Reserve stock for 15 minutes
            Inv-->>API: Reservation ID
        end
    and
        %% Calculate Final Pricing
        API->>Checkout: Calculate final totals
        Note over Checkout: Apply:<br/>- Promotions<br/>- Loyalty discounts<br/>- Shipping costs<br/>- Taxes
        Checkout-->>API: Final Order Totals
    and
        %% Validate Payment Method
        API->>Pay: POST /payments/validate
        Pay-->>API: Payment Method Valid
    end
    
    %% Create Pending Order
    API->>Order: Create Order (PENDING_PAYMENT)
    Order-->>API: Order Created
    
    %% Process Payment
    API->>Pay: POST /payments/process
    Note over Pay: Process payment with<br/>external payment gateway
    
    alt Payment Successful
        Pay-->>API: Payment Confirmed
        
        %% Confirm Order
        API->>Order: Update Order Status (CONFIRMED)
        Order-->>API: Order Confirmed
        
        %% Confirm Stock Reservations
        loop For each reservation
            API->>Inv: POST /inventory/confirm-reservation
            Inv-->>API: Stock Confirmed
        end
        
        %% Track Promotion Usage
        opt Promotions Applied
            API->>Promo: POST /promotions/track-usage
            Promo-->>API: Usage Tracked
        end
        
        %% Award Loyalty Points
        API->>Loyalty: POST /loyalty/points/earn
        Loyalty-->>API: Points Awarded
        
        %% Create Shipment
        API->>Ship: POST /shipments/create
        Ship-->>API: Shipment Created
        
        API-->>Client: 201 Created + Order Details
        
    else Payment Failed
        Pay-->>API: Payment Failed
        
        %% Release Stock Reservations
        loop For each reservation
            API->>Inv: POST /inventory/release-reservation
            Inv-->>API: Stock Released
        end
        
        %% Update Order Status
        API->>Order: Update Order Status (PAYMENT_FAILED)
        Order-->>API: Order Updated
        
        API-->>Client: 400 Bad Request + Payment Error
    end
```

## Checkout Submit API

### Request
```http
POST /api/v1/checkout/submit
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "checkoutSessionId": "CHECKOUT-789012",
  "shippingAddress": {
    "street": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "zipCode": "94105",
    "country": "US"
  },
  "billingAddress": {
    "street": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "zipCode": "94105",
    "country": "US"
  },
  "paymentMethod": {
    "id": "PM-001",
    "type": "credit_card"
  },
  "shippingMethod": "standard",
  "promotionCodes": ["SUMMER2024"],
  "loyaltyPointsToUse": 500,
  "notes": "Please deliver after 5 PM"
}
```

### Response - Success
```json
{
  "orderId": "ORD-789012",
  "orderNumber": "ORD-2024-001234",
  "status": "CONFIRMED",
  "customerId": "CUST-12345",
  "items": [
    {
      "productId": "PROD-12345",
      "sku": "SKU-ABC-001",
      "name": "Premium Wireless Headphones",
      "quantity": 2,
      "unitPrice": 249.99,
      "totalPrice": 499.98,
      "warehouse": "US-WEST-01"
    }
  ],
  "pricing": {
    "subtotal": 499.98,
    "discounts": [
      {
        "type": "promotion",
        "code": "SUMMER2024",
        "amount": 75.00
      },
      {
        "type": "loyalty_points",
        "pointsUsed": 500,
        "amount": 5.00
      }
    ],
    "totalDiscounts": 80.00,
    "shipping": 15.99,
    "tax": 35.20,
    "total": 471.17,
    "currency": "USD"
  },
  "payment": {
    "transactionId": "txn_1234567890",
    "method": "credit_card",
    "status": "COMPLETED",
    "last4": "4242"
  },
  "shipping": {
    "method": "standard",
    "cost": 15.99,
    "estimatedDelivery": "2024-08-15",
    "trackingNumber": null,
    "warehouse": "US-WEST-01"
  },
  "loyalty": {
    "pointsEarned": 471,
    "pointsUsed": 500,
    "newBalance": 1221
  },
  "timestamps": {
    "createdAt": "2024-08-10T14:30:00Z",
    "confirmedAt": "2024-08-10T14:30:15Z"
  }
}
```

---

# 5. Order Completion Flow

## Sequence Diagram - Complete Order

```mermaid
sequenceDiagram
    participant Order as Order Service
    participant EB as Event Bus
    participant Cart as Cart Service
    participant Notif as Notification Service
    participant Analytics as Analytics Service
    participant Cust as Customer Service
    participant Cache as Cache Layer

    %% Order Confirmed - Trigger Completion Flow
    Note over Order: Order Status: CONFIRMED<br/>Payment Successful
    
    %% Publish Order Created Event
    Order->>EB: Publish "order.created" event
    Note over EB: Event contains complete order data
    
    %% Event Consumers React
    par Event Processing
        EB->>Cart: order.created event
        Cart->>Cart: Clear customer cart
        Cart->>Cache: Invalidate cart cache
    and
        EB->>Notif: order.created event
        Notif->>Notif: Send order confirmation email
        Notif->>Notif: Send SMS notification
    and
        EB->>Analytics: order.created event
        Analytics->>Analytics: Track order metrics
        Analytics->>Analytics: Update customer behavior data
        Analytics->>Analytics: Update product performance
    and
        EB->>Cust: order.created event
        Cust->>Cust: Update customer order history
        Cust->>Cust: Update customer lifetime value
    end
    
    %% Update Order Status
    Order->>Order: Update Status to PROCESSING
    
    %% Publish Processing Event
    Order->>EB: Publish "order.processing" event
    
    Note over EB: Fulfillment process begins<br/>(handled by Shipping Service)
```

## Order Completion Events

### order.created Event
```json
{
  "eventId": "evt-order-001",
  "eventType": "order.created",
  "timestamp": "2024-08-10T14:30:00Z",
  "source": "order-service",
  "data": {
    "orderId": "ORD-789012",
    "orderNumber": "ORD-2024-001234",
    "customerId": "CUST-12345",
    "status": "CONFIRMED",
    "items": [
      {
        "productId": "PROD-12345",
        "sku": "SKU-ABC-001",
        "name": "Premium Wireless Headphones",
        "quantity": 2,
        "unitPrice": 249.99,
        "totalPrice": 499.98
      }
    ],
    "totals": {
      "subtotal": 499.98,
      "discounts": 80.00,
      "shipping": 15.99,
      "tax": 35.20,
      "total": 471.17,
      "currency": "USD"
    },
    "customer": {
      "id": "CUST-12345",
      "email": "customer@example.com",
      "tier": "gold"
    },
    "addresses": {
      "shipping": {
        "street": "123 Main St",
        "city": "San Francisco",
        "state": "CA",
        "zipCode": "94105"
      }
    },
    "payment": {
      "method": "credit_card",
      "transactionId": "txn_1234567890"
    },
    "loyalty": {
      "pointsEarned": 471,
      "pointsUsed": 500
    }
  }
}
```

---

# Complete Checkout Flow Summary

## Flow Sequence
```
1. Add to Cart → 2. Cart Management → 3. Checkout Initiation → 4. Payment Processing → 5. Order Completion
```

## Key Integration Points

### Service Dependencies
- **Cart Service**: Manages shopping cart state and persistence
- **Catalog Service**: Product data and pricing orchestration
- **Checkout Service**: Checkout session management and validation
- **Order Service**: Order lifecycle management and status tracking
- **Payment Service**: Payment processing and transaction management
- **Inventory Service**: Stock management and reservations
- **Customer Service**: Customer data, addresses, and preferences
- **Promotion Service**: Discount and promotion management
- **Loyalty Service**: Points, tier benefits, and redemptions
- **Shipping Service**: Shipping calculation and fulfillment coordination
- **Notification Service**: Customer communications and alerts
- **Analytics Service**: Business intelligence and reporting

### Data Flow Optimization
- **Parallel Processing**: Multiple validations happen simultaneously
- **Caching Strategy**: Cart and product data cached for performance
- **Event-Driven**: Order completion triggers async processing
- **Stock Reservations**: Temporary holds during checkout process
- **Graceful Degradation**: Partial failures don't break entire flow
- **Session Management**: Checkout sessions maintain state across steps

### Performance Considerations
- **Cart Cache TTL**: 5 minutes for active carts
- **Stock Reservation Timeout**: 15 minutes during checkout
- **Parallel API Calls**: Reduce checkout initiation time
- **Event-Driven Completion**: Non-blocking order finalization
- **Optimistic Locking**: Prevent cart conflicts during checkout

### Error Handling
- **Stock Validation**: Real-time availability checks
- **Payment Failures**: Automatic stock release and cleanup
- **Session Expiry**: Graceful handling of expired checkout sessions
- **Service Timeouts**: Fallback strategies for service failures
- **Data Consistency**: Transactional integrity across services

### Security Measures
- **JWT Authentication**: Required for all cart and checkout operations
- **Payment Tokenization**: Secure payment method handling
- **Address Validation**: Shipping and billing address verification
- **Fraud Detection**: Integration with payment service fraud checks
- **Rate Limiting**: Prevent abuse of cart and checkout APIs