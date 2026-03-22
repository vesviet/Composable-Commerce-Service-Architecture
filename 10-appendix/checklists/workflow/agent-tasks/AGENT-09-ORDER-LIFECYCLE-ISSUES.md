# AGENT-09: Order Lifecycle Flow Issues

**Created**: 2026-03-22
**Source**: QA Testing Session — Order Lifecycle Flows (Section 6)
**Priority**: Sorted by severity

---

### [x] Task 1: Frontend Order Detail Subtotal Shows ₫0 (P1) ✅ IMPLEMENTED — Added snake_case proto field mapping + compute subtotal from items fallback

**Service**: `frontend`
**File**: `frontend/src/components/orders/OrderDetail.tsx`
**Risk**: Confusing Order Summary — customer sees subtotal ₫0 but total is correct
**Problem**: On the order detail page (`/orders/{id}`), the Order Summary section shows:
- Subtotal: ₫0
- Shipping: ₫0
- Total: ₫658,061.28 (correct)

The subtotal field is not being populated from the API response. The `normalizeOrder` function in `order-utils.ts` likely doesn't map the subtotal field correctly from the backend response.
**Verify**: Order detail → Order Summary → Subtotal should equal sum of item prices.

---

### [x] Task 2: Frontend Order Detail Missing Shipping/Billing Addresses (P1) ✅ IMPLEMENTED — Added `normalizeAddress` helper to map proto `stateProvince`/`countryCode` to frontend `state`/`country`

**Service**: `frontend` / `order`
**File**: `frontend/src/components/orders/OrderDetail.tsx`
**Risk**: Customer cannot see their delivery address, reducing trust
**Problem**: Both Shipping and Billing addresses display "Shipping address not available" and "Billing address not available" on every order detail page — even for orders with status "Shipped" which already have a destination.

Either the `GET /api/v1/orders/{id}` API doesn't return address data, or the frontend component doesn't correctly map the address fields.
**Verify**: Order detail → Delivery Information → Should show actual address for shipped orders.

---

### [x] Task 3: Frontend Order Detail Missing Progress/Timeline Bar (P2) ✅ IMPLEMENTED — Added `OrderProgressTimeline` component with 5-step visual progress (Pending→Confirmed→Processing→Shipped→Delivered). Shows green checks for completed steps, indigo ring for current, and red for terminal states (cancelled/refunded/failed).

**Service**: `frontend`
**File**: `frontend/src/components/orders/OrderDetail.tsx`
**Risk**: Customer cannot visually track order lifecycle stage
**Problem**: The admin OrderDetailPage has a 5-step progress bar (Pending → Confirmed → Processing → Shipped → Delivered), but the customer-facing order detail page has no equivalent timeline/progress indicator. Customers can only see the status as a text badge.
**Fix**: Add an Order Progress component to `OrderDetail.tsx` similar to the admin's `<Steps>` component.
**Verify**: Order detail → Should show a progress bar with lifecycle stages.

---

### [x] Task 4: Frontend Order Detail Shipping Method "Not specified" (P2) ✅ IMPLEMENTED — Improved shipping method fallback with string-to-object conversion and generic fallback when shipping cost > 0

**Service**: `frontend` / `order`
**File**: `frontend/src/components/orders/OrderDetail.tsx`
**Risk**: Customer sees "Not specified" for shipping method even for shipped orders
**Problem**: The Shipping & Payment section shows "Shipping Method: Not specified" for all orders. The payment method correctly shows "Cash on Delivery" but the shipping method mapping is missing.
**Verify**: Order detail → Shipping & Payment → Shipping Method should show actual carrier.

---

### [ ] Task 5: Admin Fulfillments/Picklists/Packages/Shipments All Empty (P2)

**Service**: `admin` / `fulfillment` / `shipping`
**Risk**: Admin cannot manage order fulfillment stages
**Problem**: All four order lifecycle pages in the admin sidebar show "No data":
- `/orders/fulfillments` — "No data"
- `/orders/picklists` — "No data"
- `/orders/packages` — "No data"
- `/orders/shipments` — "No data"

Even though ORD-2602-000002 has status "SHIPPED", there are no corresponding fulfillment records. Either the fulfillment service is not processing orders or the admin API isn't querying the correct data.
**Verify**: After a new order is shipped → Fulfillments page should show related records.

---

### [ ] Task 6: Admin App Crashes with "Something went wrong" (P1)

**Service**: `admin`
**Risk**: Admin dashboard becomes unusable, requires manual page reload
**Problem**: The admin React app frequently shows a full-page error screen with "Something went wrong / An unexpected error occurred. Please reload the page." This happens especially during rapid page navigation (e.g., login → orders → detail → back). The error boundary catches an unhandled runtime error. This blocks automated Playwright tests.
**Verify**: Navigate admin pages quickly in sequence → no crash screen.
