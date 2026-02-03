# Fulfillment Service - SRE Runbook

**Service:** Fulfillment Service  
**Port:** 8010 (HTTP), 9010 (gRPC)  
**Health Check:** `GET /health`, `GET /health/ready`, `GET /health/live`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8010/health

# Readiness check (Kubernetes)
curl http://localhost:8010/health/ready

# Liveness check (Kubernetes)
curl http://localhost:8010/health/live

# Expected response:
# {"status":"healthy","service":"fulfillment-service","version":"v1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Fulfillment Creation Fails

**Symptoms:**
- POST /api/v1/fulfillments returns 500
- Fulfillments not created

**Diagnosis:**
```bash
# Check service logs
docker compose logs fulfillment-service | tail -50

# Check database connectivity
docker compose exec postgres psql -U ecommerce_user -d fulfillment_db -c "SELECT 1"

# Check order exists
curl http://localhost:8004/api/v1/orders/ORDER-ID

# Check event subscription
docker compose logs fulfillment-service | grep "order.status_changed"
```

**Fix:**
1. Verify order exists and is in correct status (CONFIRMED):
   ```bash
   curl http://localhost:8004/api/v1/orders/ORDER-ID
   ```

2. Check event subscription is working:
   ```bash
   docker compose logs fulfillment-service | grep "subscribed"
   ```

3. Verify Catalog Service connectivity:
   ```bash
   curl http://localhost:8015/api/v1/catalog/products/PROD-ID
   ```

### Issue 2: Picklist Generation Fails

**Symptoms:**
- Picklists not generated
- Fulfillment stuck in PENDING

**Diagnosis:**
```bash
# Check picklist generation logs
docker compose logs fulfillment-service | grep "picklist"

# Check fulfillment status
docker compose exec postgres psql -U ecommerce_user -d fulfillment_db -c "SELECT * FROM fulfillments WHERE status = 'PENDING' LIMIT 10;"

# Check warehouse stock
curl http://localhost:8008/api/v1/warehouse/inventory/SKU/WAREHOUSE-ID
```

**Fix:**
1. Verify stock availability:
   ```bash
   curl http://localhost:8008/api/v1/warehouse/inventory/SKU/WAREHOUSE-ID
   ```

2. Manually trigger picklist generation:
   ```bash
   curl -X POST http://localhost:8010/api/v1/fulfillments/FULFILLMENT-ID/generate-picklist
   ```

3. Check picklist expiry settings (default 24 hours)

### Issue 3: Event Processing Fails

**Symptoms:**
- Order status changes not processed
- Fulfillments not created from events

**Diagnosis:**
```bash
# Check event processing logs
docker compose logs fulfillment-service | grep "event"

# Check Dapr connectivity
curl http://localhost:3500/v1.0/health

# Check event subscription
curl http://localhost:3500/v1.0/metadata | jq '.subscriptions'
```

**Fix:**
1. Check Dapr sidecar is running:
   ```bash
   docker compose ps | grep fulfillment-dapr
   ```

2. Verify event subscription:
   ```bash
   curl http://localhost:3500/v1.0/metadata | jq '.subscriptions[] | select(.topic == "orders.order.status_changed")'
   ```

3. Restart Dapr sidecar if needed:
   ```bash
   docker compose restart fulfillment-service-dapr
   ```

### Issue 4: Batch Processing Issues

**Symptoms:**
- Batch fulfillment operations fail
- High memory usage

**Diagnosis:**
```bash
# Check batch processing logs
docker compose logs fulfillment-service | grep "batch"

# Check batch size configuration
cat fulfillment/configs/config-docker.yaml | grep max_batch_size

# Check memory usage
docker stats fulfillment-service
```

**Fix:**
1. Reduce batch size if memory issues:
   ```yaml
   fulfillment:
     max_batch_size: 500  # Reduce from 1000
   ```

2. Check batch processing is enabled:
   ```yaml
   fulfillment:
     enable_batch_processing: true
   ```

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U ecommerce_user fulfillment_db > fulfillment_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U ecommerce_user fulfillment_db < fulfillment_backup.sql
```

### Retry Failed Fulfillments

```bash
# Retry failed fulfillments
curl -X POST http://localhost:8010/api/v1/fulfillments/retry-failed

# Or retry specific fulfillment
curl -X POST http://localhost:8010/api/v1/fulfillments/FULFILLMENT-ID/retry
```

## Monitoring & Alerts

### Key Metrics
- `fulfillment_created_total` - Total fulfillments created
- `fulfillment_processing_duration_seconds` - Processing latency
- `picklist_generated_total` - Picklists generated
- `fulfillment_events_processed_total` - Events processed
- `batch_operations_total` - Batch operations

### Alert Thresholds
- **Fulfillment creation failure > 5%**: Critical
- **Picklist generation failure > 10%**: Critical
- **Event processing failure > 10%**: Critical
- **Processing latency > 5s**: Warning
- **Batch processing failure > 5%**: Warning

## Database Maintenance

### Cleanup Expired Picklists

```sql
-- Mark expired picklists
UPDATE fulfillments 
SET status = 'EXPIRED'
WHERE status = 'PICKLIST_GENERATED'
AND picklist_generated_at < NOW() - INTERVAL '24 hours';
```

### Archive Old Fulfillments

```sql
-- Archive fulfillments older than 1 year
INSERT INTO fulfillments_archive 
SELECT * FROM fulfillments 
WHERE created_at < NOW() - INTERVAL '1 year';

DELETE FROM fulfillments 
WHERE created_at < NOW() - INTERVAL '1 year';
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Fulfillment Team Lead**: fulfillment-team@company.com
- **Warehouse Team**: warehouse-team@company.com

## Logs Location

```bash
# View fulfillment service logs
docker compose logs -f fulfillment-service

# Search for errors
docker compose logs fulfillment-service | grep ERROR

# Filter by fulfillment ID
docker compose logs fulfillment-service | grep "FULFILLMENT-ID"

# Filter by order ID
docker compose logs fulfillment-service | grep "ORDER-ID"
```

## Configuration

**Config File:** `fulfillment/configs/config-docker.yaml`

**Key Settings:**
- `fulfillment.default_priority`: Default fulfillment priority (1-10)
- `fulfillment.picklist_expiry_hours`: Picklist expiry time (default 24)
- `fulfillment.enable_batch_processing`: Enable batch operations
- `fulfillment.max_batch_size`: Maximum batch size (default 1000)

**Update Config:**
```bash
# Edit config
vim fulfillment/configs/config-docker.yaml

# Restart service
docker compose restart fulfillment-service
```

