# Payment Processing Workflow

**Version**: 1.0  
**Last Updated**: 2026-01-31  
**Category**: Operational Flows  
**Status**: Active

## Overview

Complete payment processing workflow covering multi-gateway payment authorization, capture, refunds, and reconciliation across multiple payment methods and providers.

**Used in**: [Browse to Purchase (Customer Journey)](../customer-journey/browse-to-purchase.md) — Phase 4.2 Order Confirmation & Payment (AuthorizePayment → CreateOrder → CapturePayment). This workflow doc provides the detailed steps; the customer journey doc describes the checkout-orchestrated sequence.

## Participants

### Primary Actors
- **Customer**: Initiates payment during checkout
- **Admin**: Processes refunds and manages payment settings
- **Payment Gateway**: External payment processors (Stripe, VNPay, MoMo, PayPal)

### Systems/Services
- **Payment Service**: Core payment processing logic
- **Order Service**: Order status management
- **Gateway Service**: API routing and security
- **Notification Service**: Payment confirmations and alerts
- **Analytics Service**: Payment metrics and reporting
- **Customer Service**: Customer payment history

## Prerequisites

### Business Prerequisites
- Valid order with confirmed items and pricing
- Customer authentication and verification
- Payment method validation
- Fraud detection clearance

### Technical Prerequisites
- Payment gateway configurations active
- Database connections healthy
- Event publishing system operational
- Notification channels configured

## Workflow Steps

### Main Flow: Credit/Debit Card Payment

1. **Payment Method Selection**
   - **Actor**: Customer
   - **System**: Payment Service
   - **Input**: Payment method choice, card details
   - **Output**: Payment method validated
   - **Duration**: 2-5 seconds

2. **Payment Authorization**
   - **Actor**: Payment Service
   - **System**: Payment Gateway (Stripe)
   - **Input**: Card details, amount, currency
   - **Output**: Authorization token, transaction ID
   - **Duration**: 1-3 seconds

3. **Fraud Detection**
   - **Actor**: Payment Service
   - **System**: Payment Gateway + Internal Rules
   - **Input**: Transaction details, customer history
   - **Output**: Risk score, approval/decline decision
   - **Duration**: 500ms - 2 seconds

4. **Order Confirmation**
   - **Actor**: Payment Service
   - **System**: Order Service
   - **Input**: Payment authorization, order ID
   - **Output**: Order status updated to "confirmed"
   - **Duration**: 200-500ms

5. **Payment Capture**
   - **Actor**: Payment Service
   - **System**: Payment Gateway
   - **Input**: Authorization token, final amount
   - **Output**: Payment captured, funds transferred
   - **Duration**: 1-2 seconds

6. **Notification Dispatch**
   - **Actor**: Payment Service
   - **System**: Notification Service
   - **Input**: Payment confirmation, customer details
   - **Output**: Email/SMS sent to customer
   - **Duration**: 1-3 seconds

7. **Analytics Update**
   - **Actor**: Payment Service
   - **System**: Analytics Service
   - **Input**: Payment event data
   - **Output**: Payment metrics updated
   - **Duration**: 100-300ms

### Alternative Flow 1: E-wallet Payment (VNPay, MoMo)

**Trigger**: Customer selects e-wallet payment method
**Steps**:
1. Redirect to e-wallet provider
2. Customer authenticates with e-wallet
3. Payment authorization from e-wallet
4. Redirect back to merchant
5. Payment confirmation and capture
6. Return to main flow step 4

### Alternative Flow 2: Cash on Delivery (COD)

**Trigger**: Customer selects COD payment method
**Steps**:
1. COD eligibility check (location, order value)
2. COD fee calculation
3. Order confirmation without payment capture
4. COD instructions sent to customer
5. Payment marked as "pending_cod"
6. Return to main flow step 6

### Alternative Flow 3: Bank Transfer

**Trigger**: Customer selects bank transfer payment method
**Steps**:
1. Generate unique payment reference
2. Display bank account details
3. Set payment expiry (24 hours)
4. Order status set to "pending_payment"
5. Monitor for payment confirmation
6. Manual/automatic payment verification
7. Return to main flow step 4

### Error Handling

#### Error Scenario 1: Payment Authorization Failed
**Trigger**: Payment gateway declines transaction
**Impact**: Order cannot be processed, customer cannot complete purchase
**Resolution**:
1. Log payment failure with reason code
2. Display user-friendly error message
3. Suggest alternative payment methods
4. Retry option with different card
5. Customer support contact information

#### Error Scenario 2: Payment Gateway Timeout
**Trigger**: Payment gateway doesn't respond within timeout
**Impact**: Payment status unknown, potential duplicate charges
**Resolution**:
1. Query payment status from gateway
2. If successful, continue with capture
3. If failed, retry authorization
4. If still unknown, mark for manual review
5. Notify customer of status

#### Error Scenario 3: Capture Failure After Authorization
**Trigger**: Payment capture fails after successful authorization
**Impact**: Order confirmed but payment not collected
**Resolution**:
1. Retry capture with exponential backoff
2. If retry fails, void authorization
3. Notify customer of payment failure
4. Cancel order or request new payment
5. Refund any partial charges

## Business Rules

### Validation Rules
- **Amount Validation**: Payment amount must match order total
- **Currency Validation**: Payment currency must match order currency
- **Card Validation**: Card number, CVV, expiry date format validation
- **Duplicate Prevention**: Prevent duplicate payments for same order

### Business Constraints
- **Payment Limits**: Daily/monthly payment limits per customer
- **Geographic Restrictions**: Payment methods available by region
- **Time Restrictions**: Payment processing hours for certain methods
- **Fraud Thresholds**: Automatic decline for high-risk transactions

## Integration Points

### Service Integrations
| Service | Integration Type | Purpose | Error Handling |
|---------|------------------|---------|----------------|
| Order Service | Synchronous gRPC | Order status updates | Retry with circuit breaker |
| Customer Service | Synchronous gRPC | Customer validation | Fallback to basic validation |
| Notification Service | Asynchronous Event | Payment notifications | Dead letter queue |
| Analytics Service | Asynchronous Event | Payment metrics | Best effort delivery |

### External Integrations
| External System | Integration Type | Purpose | SLA |
|-----------------|------------------|---------|-----|
| Stripe | REST API | Card payments | 99.9% uptime |
| VNPay | REST API | Local payments | 99.5% uptime |
| MoMo | REST API | Mobile wallet | 99.0% uptime |
| PayPal | REST API | International payments | 99.9% uptime |

## Performance Requirements

### Response Times
- Payment authorization: < 3 seconds (P95)
- Payment capture: < 2 seconds (P95)
- Refund processing: < 5 seconds (P95)
- End-to-end payment: < 10 seconds (P95)

### Throughput
- Peak load: 1,000 payments per minute
- Average load: 200 payments per minute
- Concurrent payments: 500 simultaneous

### Availability
- Target uptime: 99.9%
- Maximum downtime: 8.76 hours per year
- Recovery time: < 5 minutes

## Monitoring & Metrics

### Key Metrics
- **Payment Success Rate**: Percentage of successful payments (target: >95%)
- **Authorization Time**: Average time for payment authorization
- **Capture Success Rate**: Percentage of successful captures after authorization
- **Refund Processing Time**: Average time to process refunds
- **Gateway Response Time**: Response time from payment gateways

### Alerts
- **Critical**: Payment success rate < 90%
- **Critical**: Payment gateway timeout > 5 seconds
- **Warning**: Unusual payment failure patterns
- **Info**: High payment volume detected

### Dashboards
- Real-time payment processing dashboard
- Payment gateway performance dashboard
- Fraud detection dashboard
- Revenue and payment analytics

## Testing Strategy

### Test Scenarios
1. **Happy Path**: Successful card payment end-to-end
2. **Gateway Failures**: Payment gateway timeouts and errors
3. **Fraud Detection**: High-risk transaction handling
4. **Refund Processing**: Full and partial refunds
5. **Multi-gateway**: Failover between payment gateways

### Test Data
- Valid test card numbers for each gateway
- Invalid card numbers for error testing
- Test customer accounts with various risk profiles
- Mock payment gateway responses

## Troubleshooting

### Common Issues
- **Payment Stuck in Pending**: Check gateway webhook delivery
- **Duplicate Charges**: Verify idempotency key implementation
- **Refund Delays**: Check gateway processing times
- **High Decline Rate**: Review fraud detection rules

### Debug Procedures
1. Check payment service logs for transaction ID
2. Query payment gateway for transaction status
3. Verify webhook delivery and processing
4. Check database for payment record consistency
5. Review fraud detection scores and rules

## Changelog

### Version 1.0 (2026-01-31)
- Initial payment processing workflow documentation
- Multi-gateway support (Stripe, VNPay, MoMo, PayPal)
- Comprehensive error handling scenarios
- Performance requirements and monitoring

### Alternative Flow 4: Buy Now Pay Later (BNPL)

**Providers**: Kredivo, Atome, Akulaku (SEA markets)  
**Trigger**: Customer selects BNPL at checkout.

**Eligibility check** (before showing BNPL option):
- Customer account age ≥ 30 days
- Minimum 1 completed order on platform
- Order value within BNPL provider's limit (e.g., ₫200,000 – ₫20,000,000)
- Customer not on BNPL blacklist

**Flow**:
1. Platform calls BNPL provider API: `eligibility_check(customer_id, amount)`
2. Provider returns: eligible + available plans (3-month, 6-month, 12-month 0% EMI)
3. Customer selects payment plan
4. Redirect to BNPL provider: customer completes KYC / authentication with provider
5. BNPL provider returns: approval token
6. Platform: `create_bnpl_order(token, order_id, amount)` → order created with status PAID
7. BNPL provider pays platform immediately (full amount, upfront)
8. Customer repays BNPL provider in installments
9. Late repayment: BNPL provider's responsibility — platform not involved

**Platform records**: `payment_method=BNPL`, `provider=kredivo`, `plan=3_month`, `approved_amount`

---

### Alternative Flow 5: QR Code Payment (QRIS, PromptPay)

**Trigger**: Customer selects QR payment method.

1. Payment Service: `generate_qr(order_id, amount, currency)` → QR code image + `qr_ref_id`
2. Display QR code on checkout page (valid for 10 minutes)
3. Customer scans with banking app / e-wallet
4. Bank/wallet sends payment: confirms to clearing house
5. Clearing house → webhook to Payment Service: `qr_payment.completed(qr_ref_id, amount)`
6. Payment Service: dedup by `qr_ref_id`, update order status → PAID
7. QR code expires if not scanned within TTL → show "QR expired, generate new"

---

### Alternative Flow 6: Virtual Account (Bank Transfer with Auto-Confirmation)

**Trigger**: Customer selects bank transfer method (VNPay, Midtrans, etc.).

1. Payment Service: `create_virtual_account(order_id, amount, bank_code)` → `va_number`
2. Display: VA number, bank name, exact amount, expiry (e.g., 24 hours)
3. Payment expiry timer starts: order holds inventory reservation for VA expiry duration
4. Customer transfers from their bank app
5. Bank processes transfer → notifies payment aggregator
6. Aggregator → webhook: `va_payment.received(va_number, amount_received, timestamp)`
7. Payment Service:
   - If `amount_received == expected_amount`: PAID, advance order
   - If `amount_received < expected_amount`: PARTIAL_PAYMENT → notify customer to pay remainder or issue refund
   - If expired and no payment: release inventory reservation, cancel order
8. If VA expires before payment: send "Your payment window has expired" notification with option to re-initiate

---

### Alternative Flow 7: Installment via Credit Card (0% EMI)

**Trigger**: Customer selects "Pay in installments" with eligible card.

1. Checkout: fetch eligible installment plans for card BIN (via Stripe/payment gateway)
2. Customer selects plan: 3/6/12 months
3. Payment Service: `create_installment_payment(card_token, plan, order_id)` → gateway processes
4. Customer charged installment amount on monthly billing cycle
5. Platform receives full amount upfront from issuing bank (bank absorbs EMI fee if 0%)
6. Order proceeds exactly as normal captured payment

---

## Escrow Flow

### Escrow Hold (Marketplace Model)

```
Payment captured → Payment Service:
    → DO NOT pay seller immediately
    → Hold gross amount in platform escrow account
    → Ledger entry: ESCROW_HOLD
        { order_id, seller_id, gross_amount, commission_rate }
```

### Escrow Release

**Trigger**: `order.completed` event (buyer confirms OR auto-complete after N days post-delivery).

```
Payment Service:
    net_payout = gross_amount
                 - platform_commission (e.g., 5% of GMV)
                 - payment_processing_fee (e.g., 2.5%)
                 - seller_voucher_contribution (if seller-funded voucher applied)
                 - penalty_deductions (if late shipment penalty)

    → Ledger entry: ESCROW_RELEASED { net_payout, deductions_breakdown }
    → Add to seller pending balance
```

### Escrow Hold on Return/Dispute

```
Return Service → return.dispute_opened → Payment Service:
    → Freeze escrow release for dispute amount
    → Resolution:
        Return approved: deduct from escrow, refund buyer
        Return rejected: release escrow to seller
```

---

## Chargeback Handling

### What is a Chargeback

Customer disputes charge directly with issuing bank/card network (Visa/Mastercard), bypassing the platform. Bank may reverse the transaction unilaterally.

### Chargeback Flow

```
Card network → chargeback notification to payment gateway
Gateway → webhook: chargeback.received(order_id, gateway_txn_id, amount, reason_code, due_date)

Payment Service:
    1. Record chargeback: { order_id, amount, reason_code, representment_due_date }
    2. If order in ESCROW: freeze escrow for disputed amount
    3. Alert: FINANCE_ADMIN + automatic Jira ticket creation
    4. Order Service: flag order with chargeback_in_progress = true

FINANCE_ADMIN:
    → Gather evidence: order confirmation, delivery proof, IP/device logs, customer communication
    → Submit representment to gateway (within due_date, usually 5-20 business days)
    → Evidence package: packing photos, carrier delivery confirmation, customer sign-off

Gateway:
    → Bank reviews evidence
    → If platform wins: chargeback reversed, funds returned
    → If platform loses: funds deducted from platform account
```

### Chargeback Reason Codes

| Code | Meaning | Win Likelihood |
|---|---|---|
| 10.4 | Item not received | High (with delivery proof) |
| 10.3 | Not as described | Medium |
| 13.1 | Merchandise / service not received | High (with tracking) |
| 10.5 | Visa fraud | Low (card compromised) |
| 30 | Services not provided | Medium |

### Seller Impact

```
If chargeback is lost:
    → Deduct from seller escrow balance (if seller at fault: sent wrong item, counterfeit)
    → If platform-level fraud: platform absorbs loss
    → Seller with >0.5% chargeback rate: warning notification
    → Seller with >1% chargeback rate: SUSPENDED pending review
```

---

## Changelog

### Version 1.1 (2026-02-21)
- Added BNPL flow (Kredivo, Atome, Akulaku)
- Added QR code payment flow (QRIS, PromptPay)
- Added virtual account expiry and partial payment handling
- Added installment / 0% EMI flow
- Added escrow hold, release, and dispute freeze flow
- Added chargeback handling with representment process

### Version 1.0 (2026-01-31)
- Initial payment processing workflow documentation
- Multi-gateway support (Stripe, VNPay, MoMo, PayPal)
- Comprehensive error handling scenarios
- Performance requirements and monitoring

## References

- [Payment Service Documentation](../../03-services/core-services/payment-service.md)
- [Order Service Integration](../../03-services/core-services/order-service.md)
- [Payment Gateway APIs](../../04-apis/payment-api.md)
- [Payment Processing Sequence Diagram](../sequence-diagrams/checkout-payment-flow.mmd)
- [Idempotency & Saga Patterns](../integration-flows/idempotency-saga.md)
- [Seller & Merchant Flow — Escrow & Payout](./seller-merchant.md)