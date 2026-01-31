# Workflow Checklist: External APIs

**Workflow**: External APIs (Integration Flows)
**Status**: In Progress
**Last Updated**: 2026-01-31

## 1. Documentation & Design
- [x] Workflow Overview and Participants defined
- [x] Main Flow (API call initiation → metrics) documented
- [x] Alternative Flows (Failover, Rate Limit, Webhook) documented
- [x] Error Handling (Timeout, Auth failure, Degradation) documented
- [x] Business Rules (Provider selection, Retry/Failover) defined
- [x] Integration Points and external systems listed
- [x] Performance Requirements and Monitoring defined

## 2. Implementation Validation
- [x] Circuit Breaker (e.g. Payment middleware) – Present in Payment service
- [x] Rate Limiting – Present in Payment service
- [ ] Failover / backup provider selection verified per service (Payment, Shipping, Notification)
- [x] Webhook endpoints and handlers – Payment gateways (Stripe, VNPay, MoMo, PayPal)
- [ ] Webhook signature validation verified per provider
- [ ] Webhook idempotency verified
- [ ] Timeout and retry configuration aligned with workflow (e.g. 3 retries, exponential backoff)
- [ ] Auth token refresh (OAuth) verified for Auth Service

## 3. Observability & Monitoring
- [ ] API success rate per provider
- [ ] Response time and error rate per provider
- [ ] Circuit breaker state metrics and alerts
- [ ] Failover rate and rate limit utilization
- [ ] Dashboard for external API health
- [ ] Alerts: success rate < 90%, circuit open, response time > 5s

## 4. Security & Compliance
- [ ] Webhook signature verification documented and verified
- [ ] API credentials and secrets management (no plaintext in config)
- [ ] Rate limiting and abuse prevention

## 5. Testing
- [ ] Happy path tests per provider (Payment, Shipping, Notification)
- [ ] Provider failure and failover tests
- [ ] Rate limit and timeout tests
- [ ] Webhook signature and idempotency tests
