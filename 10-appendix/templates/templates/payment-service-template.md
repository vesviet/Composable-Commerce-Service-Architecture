# Payment Service - Documentation Template

**Copy this template to create Payment Service documentation**

## Quick Start

```bash
cp templates/payment-service-template.md docs/services/payment-service.md
cp templates/service-openapi-template.yaml docs/openapi/payment.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/payment-service-runbook.md
```

## Service Information

- **Service Name:** Payment Service
- **HTTP Port:** 8005
- **gRPC Port:** 9005
- **Repository:** `payment/`
- **Bounded Context:** Payment Processing

## Key Responsibilities

- Payment processing (credit card, bank transfer, e-wallet)
- Payment gateway integration
- Refund processing
- Payment status tracking
- Transaction history

## Published Events

| Event Type | Topic | Description |
|------------|-------|-------------|
| `payment.payment.processed` | `payment.processed` | Published when payment is successfully processed |
| `payment.payment.failed` | `payment.failed` | Published when payment fails |
| `payment.refund.processed` | `refund.processed` | Published when refund is processed |

## Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `order.order.created` | `order.created` | `HandleOrderCreated` | Initiate payment processing |
| `order.order.cancelled` | `order.cancelled` | `HandleOrderCancelled` | Process refund |

## Key API Endpoints

- `POST /api/v1/payments` - Create payment
- `GET /api/v1/payments/{id}` - Get payment by ID
- `POST /api/v1/payments/{id}/refund` - Process refund
- `POST /api/v1/payments/webhook` - Payment gateway webhook

## Database Tables

- `payments` - Payment records
- `payment_transactions` - Transaction history
- `refunds` - Refund records

## Dependencies

- **Order Service:** Order information
- **Customer Service:** Customer payment methods
- **External:** Payment gateways (Stripe, PayPal, etc.)

## Security Considerations

- PCI DSS compliance required
- Sensitive data encryption
- Webhook signature verification
- Rate limiting on payment endpoints

## Configuration

```yaml
server:
  http:
    addr: 0.0.0.0:8005
  grpc:
    addr: 0.0.0.0:9005

payment:
  gateways:
    stripe:
      apiKey: ${STRIPE_API_KEY}
      webhookSecret: ${STRIPE_WEBHOOK_SECRET}
    paypal:
      clientId: ${PAYPAL_CLIENT_ID}
      clientSecret: ${PAYPAL_CLIENT_SECRET}

dapr:
  subscriptions:
    - pubsubName: pubsub-redis
      topic: order.created
      route: /api/v1/events/order.created
```

