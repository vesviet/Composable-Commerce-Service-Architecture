
# Checkout Process Logic Checklist

This checklist is derived from the analysis of the Order Flow and Payment Service integration. It serves as a guide for validating the correctness and robustness of the checkout process.

## 1. Checkout Initialization & Cart Validation
- [ ] **Cart Validation**: Ensure `CreateOrder` validates cart status (must be active, not empty).
- [ ] **Stock Check**: Verify `ReserveStock` is called and handles "insufficient stock" gracefully (User P2 issue).
- [ ] **Pricing**: Confirm `GetPricesBulk` is used (optimized) and matches cart totals.
- [ ] **Address**: Validate shipping/billing address presence and completeness.

## 2. Order Creation & State Management
- [ ] **Status Transition**: Initial status must be `Pending`.
- [ ] **Idempotency**: `IdempotencyKey` must be unique per request; duplicate keys should return stored result.
- [ ] **Transaction**: Order creation and initial status history must be atomic (within transaction).
- [ ] **Timeouts**: Order created with expiration (e.g., 30m) for payment.

## 3. Payment Processing
- [ ] **Authorization**: `ProcessPayment` should Authorization (not Capture) first (unless AutoCapture enabled).
- [ ] **Webhook Verification**:
    - [ ] Signatures verified using `headers` (e.g., `Stripe-Signature`, `Paypal-Transmission-Sig`).
    - [ ] `Timestamp` tolerance checked (prevent replay attacks).
    - [ ] `Idempotency` checked for webhooks (don't process same event twice).
- [ ] **Status Updates**:
    - [ ] `payment_intent.succeeded` -> Capture -> Order `Paid` (or `Confirmed`).
    - [ ] `payment_intent.failed` -> Order `PaymentFailed` (trigger retry notification).
- [ ] **Fraud Check**: Fraud score analyzed before capturing. High risk -> Block/Review.

## 4. Post-Payment Fulfillment
- [ ] **Inventory Confirmation**: Confirm stock reservation upon payment success.
- [ ] **Shipping**: `CreateShipment` triggered only after payment confirmation.
- [ ] **Notifications**: Order confirmation email sent to user.

## 5. Error Handling & Resilience
- [ ] **Circuit Breakers**: Active on calls to Payment/Warehouse/Shipping services.
- [ ] **Retries**: Exponential backoff for transient failures (e.g., Gateway timeout).
- [ ] **Compensation**: If payment succeeds but inventory fails (rare race), auto-refund or manual alert? (Saga pattern required?).
