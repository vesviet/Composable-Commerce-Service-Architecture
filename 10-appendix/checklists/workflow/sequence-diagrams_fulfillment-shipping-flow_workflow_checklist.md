# Fulfillment Shipping Flow Workflow Checklist

**Workflow**: fulfillment-shipping-flow  
**Category**: sequence-diagrams  
**Diagram**: [fulfillment-shipping-flow.mmd](../../../05-workflows/sequence-diagrams/fulfillment-shipping-flow.mmd)  
**Review**: [workflow-review-sequence-diagrams.md](../../../07-development/standards/workflow-review-sequence-diagrams.md) (§18)  
**Related workflows**: [Order Fulfillment](../../../05-workflows/operational-flows/order-fulfillment.md), [Quality Control](../../../05-workflows/operational-flows/quality-control.md), [Shipping & Logistics](../../../05-workflows/operational-flows/shipping-logistics.md)  
**Last Updated**: 2026-01-31  
**Status**: In Progress

---

## 1. Diagram Validation & Alignment

### 1.1 Sequence Diagram Validation
- [ ] Mermaid syntax is valid and renders correctly
- [ ] All participants clearly identified (Order, Fulfillment, Warehouse, Shipping, Catalog, Notification, Location, Analytics)
- [ ] Message flow follows logical sequence (Phase 1–9)
- [ ] Synchronous vs asynchronous calls properly indicated
- [ ] Error handling scenarios included (inventory shortage, label failure, carrier delay, QC failure)
- [ ] Alternative flows documented (QC pass/fail, high-value vs random sampling)

### 1.2 Business Process Alignment
- [ ] Diagram matches Order Fulfillment workflow
- [ ] Phase 1: O→F CreateFulfillment, F→W GetWarehouseAssignment — aligned
- [ ] Phase 2: Picking (W GeneratePickingList, C GetProductDetails, PickItem loop) — aligned
- [ ] Phase 3: Packing — aligned
- [ ] Phase 4: QC (high-value or random), pass/fail, return to packing on fail — aligned with Quality Control
- [ ] Phase 5–6: S CreateShipment, L ValidateAddress, label, handover, status shipped — aligned with Shipping & Logistics
- [ ] Phase 7–9: Tracking, O DELIVERED, events (FulfillmentShipped, OrderDelivered, FulfillmentCompleted) — aligned

### 1.3 Technical Accuracy
- [ ] Service names match actual service names (O=Order, F=Fulfillment, W=Warehouse, S=Shipping, C=Catalog, L=Location)
- [ ] API/event names match actual schemas
- [ ] Data flow accurately represented (fulfillment → pick → pack → QC → ship → deliver)

---

## 2. Participating Services

| Service | Role | Diagram participant |
|---------|------|----------------------|
| **Order Service** | Order data, status updates | O |
| **Fulfillment Service** | Workflow orchestration, picklist, QC, packing | F |
| **Warehouse Service** | GetWarehouseAssignment, GeneratePickingList, PickItem, GetPackagingRequirements | W |
| **Catalog Service** | GetProductDetails | C |
| **Shipping Service** | CreateShipment, ValidateAddress (via L), label, handover, tracking | S |
| **Location Service** | ValidateAddress (delivery) | L |
| **Notification Service** | Status updates, events | N |
| **Analytics Service** | Fulfillment metrics | A |

- [ ] All participating services present in diagram
- [ ] Dependency chain validated (O→F→W, F→C, F→S→L)
- [ ] Critical path identified (CreateFulfillment → Pick → Pack → QC → CreateShipment → Label → Handover → Delivered)

---

## 3. Event & Flow Validation

### 3.1 Key Flows
- [ ] CreateFulfillment(order_id, items) — Order → Fulfillment
- [ ] GetWarehouseAssignment — Fulfillment → Warehouse
- [ ] GeneratePickingList, PickItem loop — Fulfillment ↔ Warehouse
- [ ] GetProductDetails — Warehouse → Catalog (for picking)
- [ ] QC trigger (high-value or random), pass/fail, ReturnToInventory on fail
- [ ] CreateShipment, ValidateAddress — Fulfillment → Shipping → Location
- [ ] Label, handover, tracking — Shipping
- [ ] Events: FulfillmentShipped, OrderDelivered, FulfillmentCompleted

### 3.2 QC Integration
- [ ] QC pass → continue to shipping
- [ ] QC fail → return to packing (repack, re-inspect) — aligned with Order Fulfillment and Quality Control reviews

---

## 4. Error Handling & Recovery

- [ ] **Inventory shortage**: Alternative/partial fulfillment — aligned with Order Fulfillment
- [ ] **Label failure**: Retry, manual — aligned with Shipping & Logistics
- [ ] **Carrier delay**: Tracking, notification — documented
- [ ] **QC failure**: ReturnToInventory, replacement or partial cancel — aligned with Order Fulfillment and Quality Control reviews
- [ ] Error branches or alt blocks present in diagram or documented in workflow doc

---

## 5. Action Items from Review

- [ ] None — diagram **aligned** with Order Fulfillment, Quality Control, and Shipping & Logistics workflows
- [ ] Use diagram for validation of fulfillment-shipping-flow.mmd when workflow docs change

---

## 6. References

- **Workflow doc**: [order-fulfillment.md](../../../05-workflows/operational-flows/order-fulfillment.md), [quality-control.md](../../../05-workflows/operational-flows/quality-control.md), [shipping-logistics.md](../../../05-workflows/operational-flows/shipping-logistics.md)
- **Review**: [workflow-review-sequence-diagrams.md](../../../07-development/standards/workflow-review-sequence-diagrams.md) — §18 Fulfillment Shipping Flow
- **Sequence guide**: [workflow-review-sequence-guide.md](../../../07-development/standards/workflow-review-sequence-guide.md) Phase 4 item 18

---

**Checklist Version**: 1.0  
**Last Updated**: 2026-01-31
