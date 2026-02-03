# Return Refund Flow Workflow Checklist

**Workflow**: return-refund-flow  
**Category**: sequence-diagrams  
**Diagram**: [return-refund-flow.mmd](../../../05-workflows/sequence-diagrams/return-refund-flow.mmd)  
**Review**: [workflow-review-sequence-diagrams.md](../../../07-development/standards/workflow-review-sequence-diagrams.md) (§19)  
**Related workflows**: [Returns & Exchanges](../../../05-workflows/customer-journey/returns-exchanges.md)  
**Last Updated**: 2026-01-31  
**Status**: In Progress

---

## 1. Diagram Validation & Alignment

### 1.1 Sequence Diagram Validation
- [x] Mermaid syntax is valid and renders correctly
- [x] All participants clearly identified (Customer, Frontend, Gateway, Return, Order, Payment, Warehouse, Shipping, Notification, Analytics)
- [x] Message flow follows logical sequence (Phase 1–7)
- [x] Synchronous vs asynchronous calls properly indicated
- [x] Error handling scenarios included (label failure, refund failure, restock failure, return window expired)
- [x] Alternative flows documented (auto-approve vs pending_review, REFUND/EXCHANGE/STORE_CREDIT)

### 1.2 Business Process Alignment
- [x] Diagram matches Returns & Exchanges workflow
- [x] Phase 1: Eligibility (R→O GetOrderDetails, 30 days, item policy) — aligned
- [x] Phase 2: CreateReturnRequest — aligned
- [x] Phase 3: Auto-approve vs pending_review, GenerateReturnLabel — aligned with Returns review (approval flow)
- [x] Phase 4: Return shipping, tracking — aligned
- [x] Phase 5: Receipt, W ScheduleReturnInspection, inspect, pass/fail, restock or inspection_failed — aligned
- [x] Phase 6: ProcessRefund (original method or store credit), R→O UpdateOrderRefund, events — aligned
- [x] Phase 7: Analytics, FinalizeReturn — aligned
- [x] Exchange flow (rect) — aligned

### 1.3 Technical Accuracy
- [x] Service names match actual service names (R=Return, O=Order, P=Payment, W=Warehouse, S=Shipping)
- [x] API paths match actual endpoints (e.g. GET return-eligibility, POST /api/v1/returns)
- [x] Event names match actual event schemas (ReturnApproved, ReturnRejected, ReturnTrackingUpdate, RefundProcessed)
- [x] Data flow accurately represented (eligibility → request → approval → label → shipping → inspection → refund)

---

## 2. Participating Services

| Service | Role | Diagram participant |
|---------|------|----------------------|
| **Customer** | User | C |
| **Frontend** | UI | F |
| **Gateway** | API routing | G |
| **Return Service** | Eligibility, CreateReturnRequest, approval, refund orchestration | R |
| **Order Service** | GetOrderDetails, UpdateOrderRefund | O |
| **Payment Service** | ProcessRefund | P |
| **Warehouse Service** | ScheduleReturnInspection, inspect, restock | W |
| **Shipping Service** | GenerateReturnLabel, return tracking | S |
| **Notification Service** | ReturnReviewRequired, ReturnApproved, ReturnRejected, ReturnTrackingUpdate | N |
| **Analytics Service** | Return analytics | A |

- [x] All participating services present in diagram
- [x] Dependency chain validated (R→O, R→S, R→P, R→W)
- [x] Critical path identified (eligibility → request → approval → label → shipping → inspection → refund → finalize)

---

## 3. Event & API Flow

### 3.1 Key API Calls
- [x] GET /api/v1/orders/{order_id}/return-eligibility — CheckReturnEligibility
- [x] POST /api/v1/returns — CreateReturnRequest
- [x] GenerateReturnLabel — Return → Shipping

### 3.2 Key Events
- [x] ReturnReviewRequired (manual review path)
- [x] ReturnApproved, ReturnRejected
- [x] ReturnTrackingUpdate (return shipment tracking)
- [x] RefundProcessed (after Payment.ProcessRefund)

### 3.3 Approval Flow
- [x] Auto-approval vs pending_review — use diagram as **reference** for approval flow and refund idempotency documentation in Returns & Exchanges workflow checklist

---

## 4. Error Handling & Recovery

- [x] **Label failure**: Retry, manual — aligned with Returns & Exchanges
- [x] **Refund failure**: Retry, store credit fallback — aligned
- [x] **Restock failure**: Inspection_failed path, compensation — aligned
- [x] **Return window expired**: Eligibility validation (30 days) — aligned
- [x] Error branches or alt blocks present in diagram or documented in workflow doc

---

## 5. Action Items from Review
- [x] Use this diagram as **reference** for return approval flow and refund idempotency (return_id / payment_refund_id) in [customer-journey_returns-exchanges_workflow_checklist.md](customer-journey_returns-exchanges_workflow_checklist.md)
- [x] Verify consistency with return-refund-flow.mmd when updating Returns & Exchanges workflow doc

---

## 6. References

- **Workflow doc**: [returns-exchanges.md](../../../05-workflows/customer-journey/returns-exchanges.md)
- **Review**: [workflow-review-sequence-diagrams.md](../../../07-development/standards/workflow-review-sequence-diagrams.md) — §19 Return Refund Flow
- **Sequence guide**: [workflow-review-sequence-guide.md](../../../07-development/standards/workflow-review-sequence-guide.md) Phase 4 item 19

---

**Checklist Version**: 1.0  
**Last Updated**: 2026-01-31
