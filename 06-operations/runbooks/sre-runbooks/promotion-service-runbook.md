# Promotion Service - SRE Runbook

**Service:** Promotion Service  
**Port:** 8003 (HTTP), 9003 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8003/health

# Expected response:
# {"status":"ok","service":"promotion","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Promotion Application Fails

**Symptoms:**
- Promotions not applied to orders
- Discount calculation errors

**Diagnosis:**
```bash
# Check service logs
docker compose logs promotion-service | grep "promotion"

# Check promotion rules
docker compose exec postgres psql -U promotion_user -d promotion_db -c "SELECT * FROM promotions WHERE status = 'ACTIVE';"

# Check coupon validity
docker compose exec postgres psql -U promotion_user -d promotion_db -c "SELECT * FROM coupons WHERE code = 'COUPON-CODE';"
```

**Fix:**
1. Verify promotion is active and within date range:
   ```sql
   SELECT * FROM promotions 
   WHERE id = 'PROMO-ID' 
   AND status = 'ACTIVE' 
   AND start_date <= NOW() 
   AND end_date >= NOW();
   ```

2. Check promotion rules match order criteria

3. Verify coupon code is valid and not expired

### Issue 2: Coupon Usage Tracking Issues

**Symptoms:**
- Coupon usage limits not enforced
- Coupon usage count incorrect

**Diagnosis:**
```bash
# Check coupon usage
docker compose exec postgres psql -U promotion_user -d promotion_db -c "SELECT * FROM coupon_usage WHERE coupon_id = 'COUPON-ID';"

# Check usage limits
docker compose exec postgres psql -U promotion_user -d promotion_db -c "SELECT usage_count, max_usage FROM coupons WHERE id = 'COUPON-ID';"
```

**Fix:**
1. Recalculate coupon usage:
   ```sql
   UPDATE coupons c
   SET usage_count = (
       SELECT COUNT(*) FROM coupon_usage cu WHERE cu.coupon_id = c.id
   )
   WHERE c.id = 'COUPON-ID';
   ```

2. Check for duplicate coupon applications

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U promotion_user promotion_db > promotion_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U promotion_user promotion_db < promotion_backup.sql
```

## Monitoring & Alerts

### Key Metrics
- `promotion_applications_total` - Total promotion applications
- `promotion_discount_amount_total` - Total discount amount
- `coupon_redemptions_total` - Coupon redemptions
- `promotion_rule_evaluations_total` - Rule evaluations

### Alert Thresholds
- **Promotion application failure > 10%**: Warning
- **Coupon usage limit exceeded**: Warning
- **Promotion rule evaluation errors > 5%**: Critical

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Promotion Team Lead**: promotion-team@company.com

## Logs Location

```bash
# View promotion service logs
docker compose logs -f promotion-service

# Search for errors
docker compose logs promotion-service | grep ERROR
```

