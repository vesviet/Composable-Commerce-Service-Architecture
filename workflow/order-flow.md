# Order Flow Documentation

> **Note:** This documentation is derived from codebase analysis of `order/internal` (specifically `checkout` and `order` biz logic) as of Jan 2026.

## 1. High-Level Overview

The Order creation process follows a **Quote Pattern**:
1.  **Checkout Session**: A checkout session is initialized from a Cart. No draft order is created at this stage.
2.  **State Updates**: The session is updated with shipping address, billing address, payment method, etc.
3.  **Confirmation**: When the user confirms, the Order is created atomically.
4.  **Post-Processing**: Payment status is updated, inventory reservations are confirmed, and the Cart is finalized.

## 2. Detailed Flow Stages

### Stage 1: Checkout Initialization (`StartCheckout`)
- **Endpoint**: `POST /checkout/start` (via Gateway) / gRPC `StartCheckout`
- **Logic**:
    - Extracts `session_id` and `customer_id`.
    - Creates a `CheckoutSession` based on the current Cart.
    - **Key Characteristic**: No persistent "Draft Order" is created in the `orders` table. The state is maintained in the checkout session (Redis/Cache + DB persistence for session).

### Stage 2: Checkout State Management (`UpdateCheckoutState`)
- **Endpoint**: `PUT /checkout/state` / gRPC `UpdateCheckoutState`
- **Logic**:
    - Updates mutable fields: `ShippingAddress`, `BillingAddress`, `PaymentMethod`, `PromotionCodes`, `Notes`.
    - Validates addresses and other data.
    - Calculates totals (preview) but does not commit.

### Stage 3: Order Confirmation (`ConfirmCheckout`)
- **Endpoint**: `POST /checkout/confirm` / gRPC `ConfirmCheckout`
- **Core Orchestration**: `order/internal/biz/checkout/order_creation.go` -> `order/internal/biz/order/create.go`

#### Step 3.1: Build Request
- Converts `CheckoutSession` + `Cart` into a `CreateOrderRequest`.
- Maps Cart Items to Order Items (including extracting current prices).

#### Step 3.2: Reservation & Validation
- **Inventory**: Builds a reservation map. Calls Warehouse Service to reserve stock (`buildReservationsMap`).
- **Product Data**: Fetches and caches latest product details (Name, SKU, Price) from Catalog/Pricing services.
- **Address**: Fetches customer profiles if IDs are provided.

#### Step 3.3: Atomic Creation (Transactional Outbox)
- **Transaction Start**:
    1.  **Insert Order**: Saves the `Order` struct to the PostgreSQL database.
    2.  **Outbox Event**: Inserts an `OrderStatusChanged` event into the `outbox` table within the same transaction.
    3.  **Idempotency**: Relies on `cart_session_id` unique constraint to prevent duplicate orders.

#### Step 3.4: Payment Status Update
- Immediately after creation, the payment status (from the payment gateway callback or checkout state) is updated on the order.
- **Persistence**: The order is updated again to reflect `payment_status` (e.g., `paid`, `captured`, or `pending` for COD).

#### Step 3.5: Reservation Confirmation
- Calls `warehouseInventoryService.ConfirmReservation(reservationID)`.
- **Failure Handling**: If confirmation fails, errors are logged and stored in `order.metadata["reservation_confirmation_errors"]`. The order is **not** rolled back (Soft Failure). Admin intervention may be required.

#### Step 3.6: Cart Finalization
- marks the Cart as `is_active = false`.
- Invalidates Cart Cache.

## 3. Asynchronous Processing (Outbox)
- The `OrderStatusChanged` event (saved in Step 3.3) is picked up by a background worker (Change Data Capture or Polling).
- This worker publishes the event to the Event Bus (Dapr/Kafka) for other services:
    - **Notification**: Send email confirmation.
    - **Loyalty**: Accrue points.
    - **Analytics**: Track sales.

## 4. Key Dependencies
- **Catalog Service**: Product details.
- **Pricing Service**: Price calculation.
- **Warehouse Service**: Inventory check and reservation.
- **Payment Service**: (Implicit) Payment execution usually happens before confirmation or is integrated into the flow.

## 5. Error Handling
- **Idempotency**: Returns existing order if `cart_session_id` conflict occurs.
- **Reservation Failure**: Rollbacks are attempted if validation fails before order commit.
- **Post-Commit Failures**: (e.g., Warehouse confirmation) handled via logging/alerting (Metadata flagging).
