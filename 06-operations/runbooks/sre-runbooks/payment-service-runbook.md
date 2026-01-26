# Payment Service - SRE Runbook

**Service:** Payment Service  
**Port:** 8005 (HTTP), 9005 (gRPC)  
**Health Check:** `GET /api/v1/payments/health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8005/api/v1/payments/health

# Expected response:
# {"status":"healthy","service":"payment-service","version":"v1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Payment Processing Fails

**Symptoms:**
- POST /api/v1/payments returns 500
- Payments not processed

**Diagnosis:**
```bash
# Check service logs
docker compose logs payment-service | tail -50

# Check payment gateway connectivity
docker compose logs payment-service | grep "gateway"

# Check database
docker compose exec postgres psql -U payment_user -d payment_db -c "SELECT * FROM payments WHERE order_id = 'ORDER-ID';"
```

**Fix:**
1. Verify payment gateway credentials:
   ```bash
   # Check Stripe connectivity
   curl -u sk_test_xxx: https://api.stripe.com/v1/charges
   ```

2. Check payment gateway status (Stripe, PayPal, etc.)

3. Verify order exists:
   ```bash
   curl http://localhost:8004/api/v1/orders/ORDER-ID
   ```

### Issue 2: Payment Gateway Webhook Failures

**Symptoms:**
- Webhook callbacks not received
- Payment status not updated

**Diagnosis:**
```bash
# Check webhook logs
docker compose logs payment-service | grep "webhook"

# Check webhook endpoint
curl -X POST http://localhost:8005/api/v1/webhooks/stripe -d '{"test":"data"}'

# Verify webhook signature validation
docker compose logs payment-service | grep "webhook signature"
```

**Fix:**
1. Verify webhook secret in config matches gateway

2. Check webhook endpoint is accessible:
   ```bash
   # Test webhook endpoint
   curl -X POST http://localhost:8005/api/v1/webhooks/stripe \
     -H "Stripe-Signature: test" \
     -d '{"type":"payment_intent.succeeded"}'
   ```

3. Replay failed webhooks from gateway dashboard if needed

### Issue 3: Refund Processing Fails

**Symptoms:**
- Refund requests fail
- Refunds not processed

**Diagnosis:**
```bash
# Check refund logs
docker compose logs payment-service | grep "refund"

# Check refund table
docker compose exec postgres psql -U payment_user -d payment_db -c "SELECT * FROM refunds WHERE payment_id = 'PAYMENT-ID';"

# Check refund window
docker compose exec postgres psql -U payment_user -d payment_db -c "SELECT * FROM payments WHERE id = 'PAYMENT-ID' AND created_at > NOW() - INTERVAL '30 days';"
```

**Fix:**
1. Verify refund is within window (default 30 days)

2. Check payment status (must be SUCCESS):
   ```sql
   SELECT status FROM payments WHERE id = 'PAYMENT-ID';
   ```

3. Verify refund amount doesn't exceed payment amount

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U payment_user payment_db > payment_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U payment_user payment_db < payment_backup.sql
```

### Payment Reconciliation

```bash
# Run daily reconciliation
curl -X POST http://localhost:8005/api/v1/admin/transactions/reconcile

# Check reconciliation results
curl http://localhost:8005/api/v1/admin/transactions/reconcile/status
```

## Monitoring & Alerts

### Key Metrics
- `payment_processing_total` - Total payment processing attempts
- `payment_success_total` - Successful payments
- `payment_failure_total` - Failed payments
- `payment_processing_duration_seconds` - Processing latency
- `payment_gateway_calls_total` - External gateway calls
- `refund_processing_total` - Refund operations

### Alert Thresholds
- **Payment failure rate > 10%**: Critical
- **Gateway timeout > 5%**: Critical
- **Refund failure rate > 5%**: Warning
- **Processing latency > 5s**: Warning

## Security Considerations

### Payment Gateway Credentials

```bash
# Rotate gateway credentials
# 1. Update credentials in config
vim payment/configs/config-docker.yaml

# 2. Restart service
docker compose restart payment-service

# 3. Verify connectivity
curl -u NEW_CREDENTIAL: https://api.stripe.com/v1/charges
```

### PCI Compliance

- **Never log full card numbers**
- **Use tokenization for card storage**
- **Encrypt sensitive payment data**
- **Regular security audits**

## Database Maintenance

### Cleanup Old Transactions

```sql
-- Archive transactions older than 2 years
INSERT INTO transactions_archive 
SELECT * FROM transactions 
WHERE created_at < NOW() - INTERVAL '2 years';

DELETE FROM transactions 
WHERE created_at < NOW() - INTERVAL '2 years';
```

### Payment Reconciliation

```sql
-- Check for unreconciled payments
SELECT * FROM payments 
WHERE status = 'SUCCESS' 
AND reconciled_at IS NULL 
AND created_at < NOW() - INTERVAL '1 day';
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Payment Team Lead**: payment-team@company.com
- **Security Team**: security@company.com (for fraud/security issues)

## Logs Location

```bash
# View payment service logs
docker compose logs -f payment-service

# Search for errors
docker compose logs payment-service | grep ERROR

# Filter by payment ID
docker compose logs payment-service | grep "payment-id-123"

# Filter by order ID
docker compose logs payment-service | grep "order-id-456"
```

## Configuration

**Config File:** `payment/configs/config-docker.yaml`

**Key Settings:**
- `payment.gateways.stripe.secret_key`: Stripe API key
- `payment.gateways.stripe.webhook_secret`: Webhook signature secret
- `payment.max_payment_amount`: Maximum payment amount
- `payment.refund_window_days`: Refund window (default 30 days)

**Update Config:**
```bash
# Edit config
vim payment/configs/config-docker.yaml

# Restart service
docker compose restart payment-service
```

