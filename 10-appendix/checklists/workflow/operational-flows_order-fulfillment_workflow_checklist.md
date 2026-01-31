# Workflow Checklist: Order Fulfillment

**Workflow**: Order Fulfillment (Operational Flows)
**Status**: In Progress
**Last Updated**: 2026-01-31
**Workflow doc**: [order-fulfillment.md](../../../05-workflows/operational-flows/order-fulfillment.md)
**Review**: [workflow-review-order-fulfillment.md](../../../07-development/standards/workflow-review-order-fulfillment.md) (2026-01-31)

## 1. Documentation & Design
- [x] Phases (Planning, Picking, Packing & QC, Shipping) documented
- [x] Service participation and sequence diagrams
- [x] Warehouse selection and pick list optimization documented
- [x] QC integration and pass/fail flow documented
- [x] Shipping handover and tracking documented

## 2. Implementation Validation
- [x] Fulfillment Service – workflow, picklist, QC, outbox
- [x] Order → Fulfillment trigger (event or API)
- [x] Warehouse – reserve, pick list, record picked
- [x] Shipping – label, handover
- [x] Fulfillment creation idempotency (duplicate order paid events) verified (See Section 4 Actions; review P2 Fulfillment creation trigger.)
- [x] QC failure handling and compensation (release stock, notify) documented (See Section 4 Actions; review P2 QC failure.)
- [x] Consistency with fulfillment-shipping-flow.mmd verified (Phase 4) (See Section 4 Actions; review P2 sequence diagram.)

## 3. Observability & Testing
- [ ] Fulfillment latency and success rate metrics
- [ ] QC pass/fail rate and re-work metrics
- [ ] E2E tests: order confirmed → fulfillment → pick → pack → QC → ship

## 4. Service Participation Validation

Evidence: see [order-fulfillment.md](../../../05-workflows/operational-flows/order-fulfillment.md) and [workflow-review-order-fulfillment.md](../../../07-development/standards/workflow-review-order-fulfillment.md).

| Service | Role | Key Responsibilities |
|---------|------|----------------------|
| **Fulfillment Service** | Orchestration | Fulfillment workflow, task management, QC triggers |
| **Order Service** | Order data | Order details, status updates |
| **Warehouse Service** | Inventory | Stock allocation, pick list, capacity |
| **Catalog Service** | Product data | Product details, locations |
| **Shipping Service** | Logistics | Label, handover, tracking |
| **Notification Service** | Communication | Status updates, alerts |
| **Analytics Service** | Metrics | Fulfillment metrics |

### Actions from Review
- **Fulfillment / Order**: Document Fulfillment creation trigger (event/API) and idempotency for duplicate order paid events. — **Done** (code: `CreateFromOrderMulti` idempotency guard; event path already idempotent; doc in order-fulfillment.md).
- **Fulfillment / Warehouse**: Document QC failure handling and compensation (release stock, notify). — **Done** (code: `HandleQCFailed`, `ReleaseReservation`, `fulfillments.fulfillment.qc.failed` event; doc in order-fulfillment.md §3.4).
- **Docs**: Validate checklist and workflow against fulfillment-shipping-flow.mmd (Phase 4 sequence diagram). — **Done** (workflow doc updated; checklist items marked complete).
