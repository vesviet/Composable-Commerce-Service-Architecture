# Checkout Payment Flow Workflow Checklist

**Workflow**: checkout-payment-flow  
**Category**: sequence-diagrams  
**Diagram**: [checkout-payment-flow.mmd](../../../05-workflows/sequence-diagrams/checkout-payment-flow.mmd)  
**Review**: [workflow-review-sequence-diagrams.md](../../../07-development/standards/workflow-review-sequence-diagrams.md) (§17)  
**Related workflows**: [Browse to Purchase](../../../05-workflows/customer-journey/browse-to-purchase.md), [Payment Processing](../../../05-workflows/operational-flows/payment-processing.md)  
**Last Updated**: 2026-01-31  
**Status**: In Progress

---

## 1. Diagram Validation & Alignment

### 1.1 Sequence Diagram Validation
- [ ] Mermaid syntax is valid and renders correctly
- [ ] All participants clearly identified (Customer, Frontend, Gateway, Checkout, Order, Payment, Warehouse, Notification, Analytics)
- [ ] Message flow follows logical sequence (Phase 1–8)
- [ ] Synchronous vs asynchronous calls properly indicated
- [ ] Error handling scenarios included (timeout, inventory conflict, payment gateway failover)
- [ ] Alternative flows documented (Credit Card, E-wallet, COD)

### 1.2 Business Process Alignment
- [ ] Diagram matches Browse to Purchase and Payment Processing workflows
- [ ] Phase 4: CreateOrder then ReserveInventory (order creation before payment) — use as canonical ref for doc alignment
- [ ] Phase 5: ProcessPayment (card/e-wallet/COD)
- [ ] Phase 6: ConfirmPayment, Order status "confirmed"
- [ ] Phase 7: events (OrderConfirmed, OrderCreated, InventoryReserved)
- [ ] All critical steps included (checkout session, shipping, payment method, order creation, payment, confirmation)

### 1.3 Technical Accuracy
- [ ] Service names match actual service names (CH=Checkout, O=Order, P=Payment, W=Warehouse)
- [ ] API paths match actual endpoints (e.g. GET /api/v1/checkout/session, POST /api/v1/checkout/complete)
- [ ] Event names match actual event schemas (OrderConfirmed, OrderCreated, InventoryReserved)
- [ ] Data flow accurately represented (session → order → reserve → payment → confirm)

---

## 2. Participating Services

| Service | Role | Diagram participant |
|---------|------|----------------------|
| **Customer** | User | C |
| **Frontend** | UI | F |
| **Gateway** | API routing, auth | G |
| **Checkout Service** | Cart, checkout, orchestration | CH |
| **Order Service** | CreateOrder, ConfirmPayment, status | O |
| **Payment Service** | ValidatePaymentMethod, ProcessPayment | P |
| **Warehouse Service** | ValidateInventory, ReserveInventory | W |
| **Notification Service** | OrderConfirmed event consumer | N |
| **Analytics Service** | Order analytics | A |

- [ ] All participating services present in diagram
- [ ] Dependency chain validated (CH → O, CH → P, O → W)
- [ ] Critical path identified (CompleteCheckout → CreateOrder → ReserveInventory → ProcessPayment → ConfirmPayment)

---

## 3. Event & API Flow

### 3.1 Key API Calls
- [ ] GET /api/v1/checkout/session — Checkout initiation
- [ ] PUT /api/v1/checkout/shipping — Address & shipping
- [ ] PUT /api/v1/checkout/payment-method — Payment method
- [ ] POST /api/v1/checkout/complete — Order creation & payment

### 3.2 Key Events (Phase 7)
- [ ] OrderConfirmed event (O → N)
- [ ] OrderCreated event
- [ ] InventoryReserved event

### 3.3 Order vs Payment Order
- [ ] Diagram shows CreateOrder then ReserveInventory then ProcessPayment then ConfirmPayment — documented as canonical order for Browse to Purchase / Payment Processing doc alignment

---

## 4. Error Handling & Recovery

- [ ] **Timeout**: Retry, cancel order — aligned with Payment Processing
- [ ] **Inventory conflict**: Partial order flow — aligned with Payment Processing
- [ ] **Payment gateway failure**: Failover — aligned with External APIs
- [ ] Error branches or alt blocks present in diagram or documented in workflow doc

---

## 5. Action Items from Review

- [ ] Use this diagram as **reference** for order vs payment order in Browse to Purchase and Payment Processing doc alignment
- [ ] Ensure Payment Processing and Browse to Purchase docs state same order: CreateOrder → ReserveInventory → ProcessPayment → ConfirmPayment

---

## 6. References

- **Workflow doc**: [browse-to-purchase.md](../../../05-workflows/customer-journey/browse-to-purchase.md), [payment-processing.md](../../../05-workflows/operational-flows/payment-processing.md)
- **Review**: [workflow-review-sequence-diagrams.md](../../../07-development/standards/workflow-review-sequence-diagrams.md) — §17 Checkout Payment Flow
- **Sequence guide**: [workflow-review-sequence-guide.md](../../../07-development/standards/workflow-review-sequence-guide.md) Phase 4 item 17

---

**Checklist Version**: 1.0  
**Last Updated**: 2026-01-31
