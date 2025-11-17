# Order Domain - Domain Model

**Bounded Context:** Order Context  
**Service:** Order Service  
**Last Updated:** 2025-11-17

## Domain Overview

The Order domain handles the complete order lifecycle from cart creation to order fulfillment, including shopping cart management and order processing.

## Core Entities

### Order
**Description:** Represents a customer order  
**Attributes:**
- `id` (UUID): Unique order identifier
- `customer_id` (UUID): Customer who placed the order
- `status` (enum): Order status (PENDING, CONFIRMED, PROCESSING, SHIPPED, DELIVERED, CANCELLED)
- `total_amount` (decimal): Total order amount
- `currency` (string): ISO 4217 currency code
- `created_at` (timestamp): Order creation time
- `updated_at` (timestamp): Last update time

**Business Rules:**
- Order must have at least one item
- Order total must match sum of item totals
- Order status transitions must follow state machine
- Cancelled orders cannot be modified

### OrderItem
**Description:** Individual product in an order  
**Attributes:**
- `id` (UUID): Unique item identifier
- `order_id` (UUID): Parent order reference
- `product_id` (UUID): Product reference
- `sku` (string): Product SKU at time of order
- `quantity` (integer): Item quantity
- `price` (decimal): Price per unit at time of order
- `subtotal` (decimal): Quantity × Price

**Business Rules:**
- Quantity must be > 0
- Price must be > 0
- SKU must match product at time of order

### Cart
**Description:** Shopping cart for a customer or guest  
**Attributes:**
- `id` (UUID): Unique cart identifier
- `customer_id` (UUID, nullable): Customer if logged in
- `session_id` (string, nullable): Session ID for guest
- `expires_at` (timestamp): Cart expiration time
- `created_at` (timestamp): Cart creation time

**Business Rules:**
- Cart expires after 30 days of inactivity
- Guest carts merge with user cart on login
- Cart can be converted to order

### CartItem
**Description:** Product in shopping cart  
**Attributes:**
- `id` (UUID): Unique cart item identifier
- `cart_id` (UUID): Parent cart reference
- `product_id` (UUID): Product reference
- `sku` (string): Product SKU
- `quantity` (integer): Item quantity
- `added_at` (timestamp): When item was added

**Business Rules:**
- Quantity must be > 0
- Stock must be available (validated on add)
- Price calculated dynamically from Pricing Service

## Value Objects

### OrderStatus
**Values:** PENDING, CONFIRMED, PROCESSING, SHIPPED, DELIVERED, CANCELLED  
**State Transitions:**
- PENDING → CONFIRMED (payment successful)
- CONFIRMED → PROCESSING (fulfillment started)
- PROCESSING → SHIPPED (carrier picked up)
- SHIPPED → DELIVERED (customer received)
- Any → CANCELLED (order cancelled)

### Address
**Attributes:**
- `street` (string)
- `city` (string)
- `state` (string)
- `postal_code` (string)
- `country` (string)

## Domain Services

### OrderProcessor
**Responsibility:** Process orders through lifecycle  
**Operations:**
- `ProcessOrder(orderId)`: Move order through statuses
- `ValidateOrder(order)`: Validate order before processing
- `CalculateTotals(order)`: Calculate order totals

### CartService
**Responsibility:** Manage shopping cart operations  
**Operations:**
- `AddItem(cartId, productId, quantity)`: Add item to cart
- `RemoveItem(cartId, itemId)`: Remove item from cart
- `UpdateQuantity(cartId, itemId, quantity)`: Update item quantity
- `Checkout(cartId)`: Convert cart to order

## Aggregates

### Order Aggregate
**Root:** Order  
**Children:** OrderItem, OrderStatusHistory, OrderAddress  
**Invariants:**
- Order total = sum of item subtotals
- Order must have at least one item
- Status transitions must be valid

### Cart Aggregate
**Root:** Cart  
**Children:** CartItem  
**Invariants:**
- Cart must have valid customer_id or session_id
- Cart items must reference valid products

## Domain Events

### OrderCreated
**Published:** When order is created from cart  
**Payload:** Order ID, Customer ID, Total Amount, Items

### OrderStatusChanged
**Published:** When order status changes  
**Payload:** Order ID, Old Status, New Status, Timestamp

### CartItemAdded
**Published:** When item added to cart  
**Payload:** Cart ID, Product ID, SKU, Quantity

### CartCheckedOut
**Published:** When cart is converted to order  
**Payload:** Cart ID, Order ID, Customer ID

## Repository Interfaces

### OrderRepository
```go
type OrderRepository interface {
    Create(ctx context.Context, order *Order) (*Order, error)
    GetByID(ctx context.Context, id string) (*Order, error)
    UpdateStatus(ctx context.Context, id string, status OrderStatus) error
    ListByCustomer(ctx context.Context, customerID string) ([]*Order, error)
}
```

### CartRepository
```go
type CartRepository interface {
    Create(ctx context.Context, cart *Cart) (*Cart, error)
    GetByID(ctx context.Context, id string) (*Cart, error)
    GetByCustomerID(ctx context.Context, customerID string) (*Cart, error)
    GetBySessionID(ctx context.Context, sessionID string) (*Cart, error)
    Update(ctx context.Context, cart *Cart) error
    Delete(ctx context.Context, id string) error
}
```

## Use Cases

### CreateOrder
1. Validate cart exists and has items
2. Reserve inventory for all items
3. Calculate totals (pricing + shipping)
4. Create order with PENDING status
5. Publish OrderCreated event
6. Clear cart

### AddToCart
1. Validate product exists and in stock
2. Get or create cart for customer/session
3. Add item to cart
4. Publish CartItemAdded event

### ProcessOrder
1. Validate order status (must be CONFIRMED)
2. Update status to PROCESSING
3. Notify warehouse for fulfillment
4. Publish OrderStatusChanged event

## References

- Order Service README: `/order/README.md`
- Event Schema: `/docs/json-schema/order.created.schema.json`
- API Spec: `/docs/openapi/order.openapi.yaml`

