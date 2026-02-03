# Workflow Checklist: Loyalty & Rewards

**Workflow**: Loyalty & Rewards (Customer Journey)
**Status**: In Progress
**Last Updated**: 2026-01-31
**Review**: See `docs/07-development/standards/workflow-review-loyalty-rewards.md` (2026-01-31)

## 1. Documentation & Design
- [x] Main Flow (account → welcome bonus → purchase points → tier → redemption → referral → communications) documented
- [x] Alternative Flows (tier upgrade, points expiration) documented
- [x] Integration (Customer, Order, Notification, Analytics) documented
- [x] Prerequisites documented

## 2. Implementation Validation
- [x] Loyalty Service – accounts, points, tiers, rewards, campaigns, referral
- [x] Events publisher for loyalty events
- [ ] Points earning trigger (order.paid vs order.delivered) and event topic/payload documented
- [ ] Idempotency for points earning (order_id or payment_id) verified
- [ ] Tier evaluation timing and Customer segment sync documented
- [ ] Consistency with Browse to Purchase (AwardLoyaltyPoints on delivered) verified

## 3. Observability & Testing
- [ ] Points earning and redemption metrics
- [ ] Tier distribution and referral metrics
- [ ] E2E tests: purchase → points → tier → redeem
