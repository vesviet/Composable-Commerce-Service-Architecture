# Review Issues Checklist

## Order Service

### 1. Robustness & Error Handling
- [ ] **Reservation Confirmation Failure**: In `order/internal/biz/checkout/order_creation.go`, if `ConfirmReservation` fails after order creation, the error is only logged and added to metadata.
    - **Impact**: Inventory might remain reserved (timed out) or be released unexpectedly if not confirmed, while the order exists.
    - **Recommendation**: Implement a background reconciliation job or retry mechanism for failed confirmations.
- [ ] **Idempotency Implementation**: The code relies on checking `isUniqueViolation` by string matching error messages ("duplicate key value...").
    - **Impact**:Fragile if DB error messages change or differ between drivers/locales.
    - **Recommendation**: Use `pgconn.PgError` to check the specific SQL state code (`23505`).

### 2. Architecture & Design
- [ ] **Cart & Checkout Coupling**: `CheckoutService` has some duplication of logic with `CartService` (e.g., `extractCartIdentifiers` helper).
    - **Recommendation**: Standardize context/header extraction in `common` middleware or utility.
- [ ] **Logic in Controller/Service Layer**: `CheckoutService` (gRPC layer) contains some business logic validation (input checks) that might be better placed strictly in the `biz` layer to keep the transport layer thin.

### 3. Documentation
- [ ] **Outdated Docs**: `order/docs/*.md` files are flagged as outdated.
    - **Action**: Archive or update `order/docs/implementation_plan_v2.md` and `cart_implementation.md` to reflect the actual "Quote Pattern" implementation.

## General
- [ ] **Proto Standardization**: Ensure all services use consistent `google.api.http` options and field naming conventions (detected mix of `snake_case` and `camelCase` in some proto definitions during indexing).
