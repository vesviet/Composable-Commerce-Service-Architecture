# Workflow Review: Loyalty & Rewards

**Workflow**: Loyalty & Rewards (Customer Journey)  
**Reviewer**: AI (workflow-review-sequence-guide)  
**Date**: 2026-01-31  
**Duration**: ~2 hours  
**Status**: Complete

---

## Review Summary

Review followed **workflow-review-sequence-guide.md** (Phase 3.2, item 15) and **end-to-end-workflow-review-prompt.md**. Focus: points calculation, tier progression, reward redemption.

**Workflow doc**: `docs/05-workflows/customer-journey/loyalty-rewards.md`  
**Dependencies**: Payment Processing, Account Management

---

## Service Participation Matrix

| Service | Role | Key Responsibilities |
|---------|------|----------------------|
| **Loyalty Service** | Primary | Account creation, points earning, tier, redemption, referral, communications |
| **Customer Service** | Profile | Customer profile, segmentation |
| **Order Service** | Purchase | Order completion event for points |
| **Notification Service** | Communication | Loyalty notifications |
| **Analytics Service** | Metrics | Loyalty performance |
| **Gateway** | Entry | API routing |

---

## Findings

### Strengths

1. **Workflow doc**: Covers main flow (account creation → welcome bonus → purchase points → tier evaluation → reward browsing → redemption → referral → communications), tier upgrade, points expiration; prerequisites; integration with Order and Payment for points earning.
2. **Loyalty Service**: Loyalty-rewards service exists; multi-domain (accounts, points, tiers, rewards, campaigns, referral); events publisher; integration with Order/Payment for points (event or API).
3. **Browse to Purchase**: Phase 6.2 – Order delivered → Loyalty.AwardLoyaltyPoints; points based on tier; Notification for points. Doc aligns with event-driven points award.
4. **Account Management**: Customer registration and segment; Loyalty account creation may be on first purchase or explicit enrollment; doc states "Customer registration, program enrollment."
5. **Points earning**: Doc states "Order completion event, purchase amount" → points earned; Loyalty consumes order/payment events or receives API call; confirm event topic and payload.

### Issues Found

#### P2 – Points earning trigger

- **Doc**: "Purchase Points Earning" – Order Service → Loyalty Service; "Order completion event, purchase amount."
- **Observation**: May be "order.paid" or "order.delivered" or "payment.captured"; Browse to Purchase says "Order delivered → AwardLoyaltyPoints". Confirm which event triggers points (payment captured vs order delivered) and idempotency (order_id or payment_id).
- **Recommendation**: Document event topic and payload for points earning; verify idempotency; align with Browse to Purchase doc (delivered vs paid).

#### P2 – Tier evaluation timing

- **Doc**: "Tier Evaluation" – after purchase; "Tier calculation engine" – spending history, points balance.
- **Observation**: Tier may be evaluated on each purchase or batch. Document when tier is evaluated and how Customer segment is updated (Loyalty → Customer event or API).
- **Recommendation**: Document tier evaluation trigger and Customer segment sync; add to checklist.

#### P2 – Checklist

- **Recommendation**: Create `customer-journey_loyalty-rewards_workflow_checklist.md`.

### Recommendations

1. **Points trigger**: Document and verify event (order.paid vs order.delivered) and idempotency for points earning.
2. **Tier and segment**: Document tier evaluation timing and Customer segment sync.
3. **Checklist**: Create Loyalty & Rewards workflow checklist.

---

## Dependencies Validated

- **Payment Processing**: Order paid/delivered triggers points; Payment events or Order events may be consumed; aligned at high level.
- **Account Management**: Customer profile and segment; Loyalty account creation; aligned.

---

## Next Steps

| Action | Owner | Priority |
|--------|--------|----------|
| Document points earning event (topic, payload) and idempotency | Loyalty / Order | P2 |
| Document tier evaluation timing and Customer segment sync | Loyalty / Customer | P2 |
| Create Loyalty & Rewards workflow checklist | Docs | P2 |
