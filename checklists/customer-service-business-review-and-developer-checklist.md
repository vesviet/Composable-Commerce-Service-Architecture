# Customer Service — Tech Lead Business Review & Developer Checklist

**Purpose:** Tech lead review of Customer service business responsibilities and a developer-facing checklist for gaps/improvements.

**Status:** ✅ **Core Implementation Done**. Integration with downstream services (Order, Pricing, Promotion) is the next step.

**Platform context:**
- Promotion rules depend on customer segmentation and/or customer group.
- Tax (Magento-like) can depend on `customer_group_id`.
- Checkout needs a complete shipping address (country/state/postcode).

---

## 1) What Customer service should own (authoritative boundaries)

### 1.1 Customer identity & lifecycle

- Customer master record: ID, email, name, status, `customer_type`, `customer_group_id`.
- Registration, verification, 2FA, social login.
- GDPR operations.

### 1.2 Customer profile data

- Profile fields: phone, DOB, gender.

### 1.3 Addresses (shipping/billing)

- Address book management.

### 1.4 Segments (dynamic marketing segments)

- Segment definitions and rules engine.

### 1.5 Preferences & Wishlists

- Communication preferences and wishlists.

---

## 2) Gaps / Risks vs platform needs (Post-Implementation Review)

### 2.1 CRITICAL: Customer Group vs Segment

- **Status:** ✅ **RESOLVED**. 
- **Evidence:**
  - `customer/api/customer/v1/customer.proto` now includes `string customer_group_id = 24;` on the `Customer` message.
  - A full suite of RPCs for managing `StableCustomerGroup` has been added (`Create/Update/Get/Delete/AssignCustomerGroup`).
  - This correctly separates stable business groups (for tax/pricing) from dynamic marketing segments.

### 2.2 Shipping address completeness contract

- **Status:** ✅ **RESOLVED**.
- **Evidence:** The service now imports and uses `api.common.v1.Address`, which includes all necessary fields (`country_code`, `state_province`, `postal_code`, `city`).

### 2.3 Guest vs registered customer flows

- **Status:** 🟡 **Policy Decision Needed**.
- **Action:**
  - [ ] Define a policy for guest checkout:
    - [ ] whether a customer record is created at checkout.
    - [ ] how orders are linked if a user later registers with the same email.

### 2.4 Security & privacy

- **Status:** 🟡 **Needs Audit**.
- **Action:**
  - [ ] Ensure password handling / login flows are consistent with Auth service usage.
  - [ ] Ensure GDPR deletion/anonymization is auditable and irreversible.

---

## 3) Developer Implementation Checklist (Customer)

### 3.1 Customer group support (required for Pricing/Tax)

- ✅ Add `customer_group_id` field to customer model and DB.
- ✅ Provide CRUD/update endpoint for customer group.
- ✅ Ensure group is included in customer profile responses.

### 4.2 Segmentation

- ✅ Ensure segment assignment logic is deterministic.
- 🟡 Define rule versioning strategy for segments (if complex rules evolve).

### 4.3 Addresses

- ✅ Ensure addresses support shipping/tax fields (`postcode`, etc.).
- 🟡 Provide a clear “default shipping address” concept (API exists, but business logic for fallback needs to be confirmed across services).

### 4.4 Integration contracts (API Ready, Integration Pending)

- ✅ **Contract with Order:**
  - Order can fetch customer group and addresses for totals calculation.
- ✅ **Contract with Promotion:**
  - Promotion can receive `customer_segments[]` and `customer_group_id`.
- ✅ **Contract with Pricing:**
  - Pricing can receive `customer_group_id` for tax rules.

**Next Step:** Downstream services (Order, Pricing, Promotion) now need to be updated to *use* this data.

---

## 5) References

- Customer service code: `customer/internal/biz/*`
- Existing checklist: `docs/checklists/customer-account-management-checklist.md`
- Promotion checklist: `docs/checklists/promotion-service-checklist.md`
- Tax checklist: `docs/checklists/tax-implementation-checklist-magento-vs-shopify.md`
