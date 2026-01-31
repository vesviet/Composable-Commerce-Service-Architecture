# Workflow Review: Product Reviews

**Workflow**: Product Reviews (Customer Journey)  
**Reviewer**: AI (workflow-review-sequence-guide)  
**Date**: 2026-01-31  
**Duration**: ~1.5 hours  
**Status**: Complete

---

## Review Summary

Review followed **workflow-review-sequence-guide.md** (Phase 3.1, item 14) and **end-to-end-workflow-review-prompt.md**. Focus: review moderation, quality control, customer engagement.

**Workflow doc**: `docs/05-workflows/customer-journey/product-reviews.md`  
**Dependencies**: Order Fulfillment (purchase verification)

---

## Service Participation Matrix

| Service | Role | Key Responsibilities |
|---------|------|----------------------|
| **Review Service** | Primary | Eligibility, submission, moderation, publication, helpful voting, analytics |
| **Order Service** | Verification | Purchase verification for eligibility |
| **Catalog Service** | Product | Product info, review integration (display) |
| **User Service** | Auth | Customer authentication |
| **Notification Service** | Communication | Review-related notifications |
| **Analytics Service** | Analytics | Review performance, sentiment |

---

## Findings

### Strengths

1. **Workflow doc**: Covers main flow (eligibility → submission → auto moderation → manual if flagged → publication → discovery → helpful voting → analytics), review update, dispute resolution; prerequisites (purchased, delivered, 90 days); integration points.
2. **Review Service**: Review service exists (review/); events publisher; integration with Order for purchase verification; Catalog for product/review display.
3. **Eligibility**: Doc states order status "delivered" or "completed", 90 days; Review Service can call Order for verification.
4. **Moderation**: Doc describes auto-moderation and manual for flagged; implementation may have moderation workflow.
5. **Browse to Purchase**: Phase 6.2 – Order delivered → Review.EnableReviewCollection, SendReviewRequest; aligns with Product Reviews workflow.

### Issues Found

#### P2 – Purchase verification integration

- **Doc**: "Review Eligibility Check" – Order verification; "Integration with order service for purchase verification."
- **Observation**: Review Service must verify customer purchased and received product (Order API or event). Confirm how Review gets order/delivery data (API vs event) and eligibility window (90 days).
- **Recommendation**: Document Order ↔ Review integration (API vs event) and eligibility rules; add to checklist.

#### P2 – Catalog integration for display

- **Doc**: "Review Publication" – Catalog Service integration; "Review published and visible"; "Review Discovery" – reviews displayed.
- **Observation**: Catalog may store review summary/rating or Review Service serves reviews and Catalog embeds; Search may index reviews. Document how reviews are displayed on product page (Catalog API vs Review API vs Search).
- **Recommendation**: Document review display flow (Catalog vs Review vs Search); add to checklist.

#### P2 – Checklist

- **Recommendation**: Create `customer-journey_product-reviews_workflow_checklist.md`.

### Recommendations

1. **Order integration**: Document and verify purchase verification (API/event) and eligibility window.
2. **Display flow**: Document how reviews are shown on product page (Catalog/Review/Search).
3. **Checklist**: Create Product Reviews workflow checklist.

---

## Dependencies Validated

- **Order Fulfillment**: Order delivered triggers review eligibility; Browse to Purchase references EnableReviewCollection; aligned.

---

## Next Steps

| Action | Owner | Priority |
|--------|--------|----------|
| Document Order ↔ Review purchase verification (API/event) and eligibility | Review / Order | P2 |
| Document review display flow (Catalog/Review/Search) | Review / Catalog | P2 |
| Create Product Reviews workflow checklist | Docs | P2 |
