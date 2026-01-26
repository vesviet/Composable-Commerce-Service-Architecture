# Shipping Service - SRE Runbook

**Service:** Shipping Service  
**Port:** 8006 (HTTP), 9006 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8006/health

# Expected response:
# {"status":"ok","service":"shipping","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Shipment Creation Fails

**Symptoms:**
- POST /api/v1/shipments returns 500
- Shipments not created

**Diagnosis:**
```bash
# Check service logs
docker compose logs shipping-service | tail -50

# Check database connectivity
docker compose exec postgres psql -U shipping_user -d shipping_db -c "SELECT 1"

# Check order exists
curl http://localhost:8004/api/v1/orders/ORDER-ID
```

**Fix:**
1. Verify order exists and is in correct status (CONFIRMED)

2. Check carrier configuration:
   ```bash
   docker compose exec postgres psql -U shipping_user -d shipping_db -c "SELECT * FROM carriers WHERE enabled = true;"
   ```

3. Verify warehouse exists:
   ```bash
   curl http://localhost:8008/api/v1/warehouses/WAREHOUSE-ID
   ```

### Issue 2: Carrier API Failures

**Symptoms:**
- Carrier API calls fail
- Tracking numbers not generated

**Diagnosis:**
```bash
# Check carrier API logs
docker compose logs shipping-service | grep "carrier API"

# Test carrier connectivity
curl https://api.ups.com/v1/shipments

# Check carrier credentials
docker compose exec shipping-service env | grep CARRIER
```

**Fix:**
1. Verify carrier API credentials:
   ```bash
   # Check config
   cat shipping/configs/config-docker.yaml | grep carrier
   ```

2. Check carrier API status (UPS, FedEx, DHL status pages)

3. Use fallback carrier if primary fails

### Issue 3: Tracking Updates Not Working

**Symptoms:**
- Tracking status not updating
- Delivery confirmation not received

**Diagnosis:**
```bash
# Check tracking worker logs
docker compose logs shipping-service | grep "tracking"

# Check shipment status
docker compose exec postgres psql -U shipping_user -d shipping_db -c "SELECT * FROM shipments WHERE tracking_number = 'TRACKING-NUMBER';"

# Check carrier webhook
docker compose logs shipping-service | grep "webhook"
```

**Fix:**
1. Manually trigger tracking update:
   ```bash
   curl -X POST http://localhost:8006/api/v1/shipments/TRACKING-NUMBER/update-tracking
   ```

2. Check carrier webhook configuration

3. Verify tracking number format

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U shipping_user shipping_db > shipping_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U shipping_user shipping_db < shipping_backup.sql
```

### Shipment Status Recovery

```bash
# Re-sync shipment statuses from carrier
curl -X POST http://localhost:8006/api/v1/admin/shipments/sync-statuses
```

## Monitoring & Alerts

### Key Metrics
- `shipment_creation_total` - Total shipments created
- `shipment_processing_duration_seconds` - Processing latency
- `carrier_api_calls_total` - Carrier API calls
- `carrier_api_errors_total` - Carrier API errors
- `tracking_updates_total` - Tracking status updates

### Alert Thresholds
- **Shipment creation failure > 5%**: Critical
- **Carrier API failure > 10%**: Critical
- **Tracking update lag > 1 hour**: Warning
- **Delivery confirmation missing > 5%**: Warning

## Database Maintenance

### Cleanup Old Shipments

```sql
-- Archive shipments older than 1 year
INSERT INTO shipments_archive 
SELECT * FROM shipments 
WHERE created_at < NOW() - INTERVAL '1 year';

DELETE FROM shipments 
WHERE created_at < NOW() - INTERVAL '1 year';
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Shipping Team Lead**: shipping-team@company.com
- **Carrier Support**: Check carrier-specific support channels

## Logs Location

```bash
# View shipping service logs
docker compose logs -f shipping-service

# Search for errors
docker compose logs shipping-service | grep ERROR

# Filter by shipment ID
docker compose logs shipping-service | grep "shipment-id-123"
```

