# Customer Service - SRE Runbook

**Service:** Customer Service  
**Port:** 8007 (HTTP), 9007 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8007/health

# Expected response:
# {"status":"ok","service":"customer","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Customer Profile Creation Fails

**Symptoms:**
- POST /api/v1/customers returns 500
- Customer profiles not created

**Diagnosis:**
```bash
# Check service logs
docker compose logs customer-service | tail -50

# Check database connectivity
docker compose exec postgres psql -U customer_user -d customer_db -c "SELECT 1"

# Check for duplicate email
docker compose exec postgres psql -U customer_user -d customer_db -c "SELECT * FROM customers WHERE email = 'email@example.com';"
```

**Fix:**
1. Verify database connection
2. Check for duplicate email (must be unique)
3. Verify required fields are provided

### Issue 2: Address Management Issues

**Symptoms:**
- Address operations fail
- Addresses not saved

**Diagnosis:**
```bash
# Check address table
docker compose exec postgres psql -U customer_user -d customer_db -c "SELECT * FROM addresses WHERE customer_id = 'CUSTOMER-ID';"

# Check address validation logs
docker compose logs customer-service | grep "address validation"
```

**Fix:**
1. Verify address data format
2. Check address validation rules
3. Ensure customer exists before adding address

### Issue 3: Customer Segmentation Not Working

**Symptoms:**
- Segments not updating
- Customer not assigned to segments

**Diagnosis:**
```bash
# Check segments table
docker compose exec postgres psql -U customer_user -d customer_db -c "SELECT * FROM segments;"

# Check customer segments
docker compose exec postgres psql -U customer_user -d customer_db -c "SELECT * FROM customer_segments WHERE customer_id = 'CUSTOMER-ID';"

# Check segmentation worker logs
docker compose logs customer-service | grep "segmentation"
```

**Fix:**
1. Trigger manual segmentation:
   ```bash
   curl -X POST http://localhost:8007/api/v1/customers/segments/recalculate
   ```

2. Check segmentation rules in database

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U customer_user customer_db > customer_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U customer_user customer_db < customer_backup.sql
```

## Monitoring & Alerts

### Key Metrics
- `customer_operations_total` - Total customer operations
- `customer_creation_duration_seconds` - Customer creation latency
- `address_operations_total` - Address operations
- `segmentation_updates_total` - Segmentation updates

### Alert Thresholds
- **Customer creation failure > 5%**: Critical
- **Address operations failure > 10%**: Warning
- **Segmentation lag > 1 hour**: Warning

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Customer Team Lead**: customer-team@company.com

## Logs Location

```bash
# View customer service logs
docker compose logs -f customer-service

# Search for errors
docker compose logs customer-service | grep ERROR
```

