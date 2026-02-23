# Loyalty Rewards Service - SRE Runbook

**Service:** Loyalty Rewards Service  
**Port:** 8013 (HTTP), 9013 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8013/health

# Expected response:
# {"status":"healthy","service":"loyalty-rewards"}
```

## Common Issues & Quick Fixes

### Issue 1: Points Not Awarded

**Symptoms:**
- Points not credited after order completion
- Transaction not created

**Diagnosis:**
```bash
# Check service logs
docker compose logs loyalty-rewards-service | grep "earn points"

# Check transaction logs
docker compose logs loyalty-rewards-service | grep "transaction"

# Check account balance
docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT * FROM loyalty_accounts WHERE customer_id = 'CUSTOMER-ID';"

# Check transactions
docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT * FROM loyalty_transactions WHERE customer_id = 'CUSTOMER-ID' ORDER BY created_at DESC LIMIT 10;"
```

**Fix:**
1. Verify order completion event was received:
   ```bash
   docker compose logs loyalty-rewards-service | grep "order.completed"
   ```

2. Check points calculation rules:
   ```bash
   docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT * FROM point_rules WHERE enabled = true;"
   ```

3. Manually award points if needed:
   ```bash
   curl -X POST http://localhost:8013/api/v1/loyalty/points/earn \
     -d '{"customer_id":"CUSTOMER-ID","points":100,"reason":"Manual adjustment"}'
   ```

### Issue 2: Tier Upgrade Not Working

**Symptoms:**
- Customer tier not updating
- Tier benefits not applied

**Diagnosis:**
```bash
# Check tier calculation logs
docker compose logs loyalty-rewards-service | grep "tier"

# Check customer tier
docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT * FROM loyalty_accounts WHERE customer_id = 'CUSTOMER-ID';"

# Check tier rules
docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT * FROM loyalty_tiers ORDER BY min_points;"
```

**Fix:**
1. Manually recalculate tier:
   ```bash
   curl -X POST http://localhost:8013/api/v1/loyalty/tiers/CUSTOMER-ID/recalculate
   ```

2. Check tier upgrade rules (points threshold)

3. Verify account points balance is correct

### Issue 3: Reward Redemption Fails

**Symptoms:**
- Reward redemption returns error
- Points not deducted

**Diagnosis:**
```bash
# Check redemption logs
docker compose logs loyalty-rewards-service | grep "redemption"

# Check reward availability
docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT * FROM loyalty_rewards WHERE id = 'REWARD-ID';"

# Check account balance
docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT points_balance FROM loyalty_accounts WHERE customer_id = 'CUSTOMER-ID';"
```

**Fix:**
1. Verify customer has enough points:
   ```sql
   SELECT points_balance FROM loyalty_accounts WHERE customer_id = 'CUSTOMER-ID';
   ```

2. Check reward is available and not expired:
   ```sql
   SELECT * FROM loyalty_rewards WHERE id = 'REWARD-ID' AND enabled = true AND (expires_at IS NULL OR expires_at > NOW());
   ```

3. Check redemption limits (max per customer, max per day)

### Issue 4: Referral Program Not Working

**Symptoms:**
- Referral bonuses not awarded
- Referral tracking fails

**Diagnosis:**
```bash
# Check referral logs
docker compose logs loyalty-rewards-service | grep "referral"

# Check referrals
docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT * FROM referral_programs WHERE referrer_id = 'CUSTOMER-ID';"

# Check referral completion
docker compose exec postgres psql -U loyalty_user -d loyalty_db -c "SELECT * FROM referral_programs WHERE status = 'PENDING';"
```

**Fix:**
1. Manually complete referral:
   ```bash
   curl -X POST http://localhost:8013/api/v1/loyalty/referrals/complete \
     -d '{"referral_id":"REFERRAL-ID"}'
   ```

2. Check referral bonus rules

3. Verify referred customer completed first purchase

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U loyalty_user loyalty_db > loyalty_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U loyalty_user loyalty_db < loyalty_backup.sql
```

### Recalculate Account Balances

```sql
-- Recalculate points balance from transactions
UPDATE loyalty_accounts la
SET points_balance = (
    SELECT COALESCE(SUM(
        CASE 
            WHEN type = 'EARN' THEN points
            WHEN type = 'REDEEM' THEN -points
            ELSE 0
        END
    ), 0)
    FROM loyalty_transactions lt
    WHERE lt.customer_id = la.customer_id
    AND lt.status = 'COMPLETED'
    AND (lt.expires_at IS NULL OR lt.expires_at > NOW())
)
WHERE EXISTS (SELECT 1 FROM loyalty_transactions WHERE customer_id = la.customer_id);
```

## Monitoring & Alerts

### Key Metrics
- `loyalty_points_earned_total` - Total points earned
- `loyalty_points_redeemed_total` - Total points redeemed
- `loyalty_transactions_total` - Total transactions
- `loyalty_tier_upgrades_total` - Tier upgrades
- `loyalty_redemptions_total` - Reward redemptions
- `loyalty_referrals_total` - Referral completions

### Alert Thresholds
- **Points award failure > 5%**: Critical
- **Tier calculation failure > 10%**: Warning
- **Redemption failure > 10%**: Warning
- **Points balance discrepancy**: Critical

## Database Maintenance

### Cleanup Expired Points

```sql
-- Mark expired points transactions
UPDATE loyalty_transactions 
SET status = 'EXPIRED'
WHERE type = 'EARN'
AND expires_at < NOW()
AND status = 'COMPLETED';
```

### Archive Old Transactions

```sql
-- Archive transactions older than 2 years
INSERT INTO loyalty_transactions_archive 
SELECT * FROM loyalty_transactions 
WHERE created_at < NOW() - INTERVAL '2 years';

DELETE FROM loyalty_transactions 
WHERE created_at < NOW() - INTERVAL '2 years';
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Loyalty Team Lead**: loyalty-team@company.com

## Logs Location

```bash
# View loyalty service logs
docker compose logs -f loyalty-rewards-service

# Search for errors
docker compose logs loyalty-rewards-service | grep ERROR

# Filter by customer ID
docker compose logs loyalty-rewards-service | grep "CUSTOMER-ID"
```

