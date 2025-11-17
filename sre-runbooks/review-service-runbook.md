# Review Service - SRE Runbook

**Service:** Review Service  
**Port:** 8014 (HTTP), 9014 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8014/health

# Expected response:
# {"status":"healthy","service":"review-service","version":"v1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Review Creation Fails

**Symptoms:**
- POST /api/v1/reviews returns 500
- Reviews not created

**Diagnosis:**
```bash
# Check service logs
docker compose logs review-service | tail -50

# Check database connectivity
docker compose exec postgres psql -U review_user -d review_db -c "SELECT 1"

# Check for duplicate reviews (one review per customer per product)
docker compose exec postgres psql -U review_user -d review_db -c "SELECT * FROM reviews WHERE customer_id = 'CUSTOMER-ID' AND product_id = 'PROD-ID';"
```

**Fix:**
1. Verify customer exists:
   ```bash
   curl http://localhost:8007/api/v1/customers/CUSTOMER-ID
   ```

2. Verify product exists:
   ```bash
   curl http://localhost:8015/api/v1/catalog/products/PROD-ID
   ```

3. Check review validation rules (rating 1-5, required fields)

### Issue 2: Rating Aggregation Not Working

**Symptoms:**
- Product ratings not updating
- Rating calculations incorrect

**Diagnosis:**
```bash
# Check rating aggregation logs
docker compose logs review-service | grep "rating"

# Check product ratings
docker compose exec postgres psql -U review_user -d review_db -c "SELECT * FROM ratings WHERE product_id = 'PROD-ID';"

# Check review count
docker compose exec postgres psql -U review_user -d review_db -c "SELECT COUNT(*) FROM reviews WHERE product_id = 'PROD-ID' AND status = 'APPROVED';"
```

**Fix:**
1. Manually trigger rating recalculation:
   ```bash
   curl -X POST http://localhost:8014/api/v1/ratings/PROD-ID/recalculate
   ```

2. Check rating aggregation logic in code

3. Verify reviews are approved (only approved reviews count)

### Issue 3: Auto-Moderation Not Working

**Symptoms:**
- Reviews not auto-moderated
- Moderation queue backlog

**Diagnosis:**
```bash
# Check moderation logs
docker compose logs review-service | grep "moderation"

# Check pending reviews
docker compose exec postgres psql -U review_user -d review_db -c "SELECT * FROM reviews WHERE status = 'PENDING' LIMIT 10;"

# Check moderation settings
docker compose exec postgres psql -U review_user -d review_db -c "SELECT * FROM moderation_settings;"
```

**Fix:**
1. Check auto-moderation is enabled in config:
   ```bash
   cat review/configs/config-docker.yaml | grep auto_moderate
   ```

2. Manually trigger moderation:
   ```bash
   curl -X POST http://localhost:8014/api/v1/moderation/auto/REVIEW-ID
   ```

3. Check moderation thresholds (auto_approve_threshold, auto_reject_threshold)

### Issue 4: Helpful Votes Not Counting

**Symptoms:**
- Helpful vote counts incorrect
- Votes not persisting

**Diagnosis:**
```bash
# Check helpful vote logs
docker compose logs review-service | grep "helpful"

# Check helpful votes
docker compose exec postgres psql -U review_user -d review_db -c "SELECT * FROM helpful_votes WHERE review_id = 'REVIEW-ID';"

# Check vote count
docker compose exec postgres psql -U review_user -d review_db -c "SELECT COUNT(*) FROM helpful_votes WHERE review_id = 'REVIEW-ID';"
```

**Fix:**
1. Verify review exists before voting

2. Check for duplicate votes (one vote per customer per review)

3. Recalculate helpful count:
   ```bash
   curl http://localhost:8014/api/v1/helpful/review/REVIEW-ID/count
   ```

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U review_user review_db > review_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U review_user review_db < review_backup.sql
```

### Recalculate All Ratings

```bash
# Trigger recalculation for all products (if endpoint exists)
# Or via SQL:
docker compose exec postgres psql -U review_user -d review_db <<EOF
UPDATE ratings r
SET average_rating = (
    SELECT AVG(rating) FROM reviews 
    WHERE product_id = r.product_id AND status = 'APPROVED'
),
total_reviews = (
    SELECT COUNT(*) FROM reviews 
    WHERE product_id = r.product_id AND status = 'APPROVED'
);
EOF
```

## Monitoring & Alerts

### Key Metrics
- `review_operations_total` - Total review operations
- `review_creation_duration_seconds` - Review creation latency
- `rating_calculations_total` - Rating calculations
- `moderation_operations_total` - Moderation operations
- `helpful_votes_total` - Helpful votes

### Alert Thresholds
- **Review creation failure > 10%**: Warning
- **Rating calculation failure > 5%**: Critical
- **Moderation queue size > 100**: Warning
- **Auto-moderation failure > 10%**: Warning

## Database Maintenance

### Cleanup Old Reviews

```sql
-- Archive reviews older than 2 years
INSERT INTO reviews_archive 
SELECT * FROM reviews 
WHERE created_at < NOW() - INTERVAL '2 years';

DELETE FROM reviews 
WHERE created_at < NOW() - INTERVAL '2 years';
```

### Cleanup Spam Reviews

```sql
-- Mark spam reviews as rejected
UPDATE reviews 
SET status = 'REJECTED', moderation_reason = 'Spam detected'
WHERE status = 'PENDING' 
AND created_at < NOW() - INTERVAL '30 days'
AND helpful_count = 0;
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Review Team Lead**: review-team@company.com

## Logs Location

```bash
# View review service logs
docker compose logs -f review-service

# Search for errors
docker compose logs review-service | grep ERROR

# Filter by product ID
docker compose logs review-service | grep "PROD-ID"
```

