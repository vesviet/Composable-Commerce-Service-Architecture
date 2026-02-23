# Warehouse Service - SRE Runbook

**Service:** Warehouse Service  
**Port:** 8008 (HTTP), 9008 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8008/health

# Expected response:
# {"status":"ok","service":"warehouse","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Stock Updates Not Publishing Events

**Symptoms:**
- Stock changes in database but events not published
- Downstream services (Catalog) not receiving updates

**Diagnosis:**
```bash
# Check event publishing logs
docker compose logs warehouse-service | grep "publish event"

# Check Dapr connectivity
curl http://localhost:3500/v1.0/health

# Verify event was published
docker compose exec redis redis-cli XINFO STREAM "pubsub-redis:warehouse.stock.updated"
```

**Fix:**
1. Check Dapr sidecar:
   ```bash
   docker compose ps | grep warehouse-dapr
   docker compose logs warehouse-service-dapr
   ```

2. Restart Dapr sidecar if needed:
   ```bash
   docker compose restart warehouse-service-dapr
   ```

3. Verify pub/sub component:
   ```bash
   curl http://localhost:3500/v1.0/metadata
   ```

### Issue 2: Inventory Reconciliation Fails

**Symptoms:**
- Inventory counts don't match physical stock
- Reconciliation job fails

**Diagnosis:**
```bash
# Check reconciliation logs
docker compose logs warehouse-service | grep "reconciliation"

# Check for data inconsistencies
docker compose exec postgres psql -U warehouse_user -d warehouse_db -c "SELECT sku, SUM(quantity) FROM inventory GROUP BY sku HAVING SUM(quantity) < 0;"
```

**Fix:**
1. Run manual reconciliation:
   ```bash
   # Trigger reconciliation via API
   curl -X POST http://localhost:8008/api/v1/warehouse/inventory/reconcile
   ```

2. Check for negative stock (data issue):
   ```sql
   -- Fix negative stock
   UPDATE inventory SET quantity = 0 WHERE quantity < 0;
   ```

### Issue 3: Stock Reservation Timeout

**Symptoms:**
- Orders fail due to stock reservation timeout
- Reservations not released

**Diagnosis:**
```bash
# Check reservation logs
docker compose logs warehouse-service | grep "reservation"

# Check pending reservations
docker compose exec postgres psql -U warehouse_user -d warehouse_db -c "SELECT * FROM reservations WHERE status='PENDING' AND expires_at < NOW();"
```

**Fix:**
1. Release expired reservations:
   ```bash
   curl -X POST http://localhost:8008/api/v1/warehouse/reservations/cleanup
   ```

2. Check reservation cleanup job is running

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U warehouse_user warehouse_db > warehouse_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U warehouse_user warehouse_db < warehouse_backup.sql
```

### Stock Data Recovery

```bash
# Recalculate stock from movements
docker compose exec postgres psql -U warehouse_user -d warehouse_db <<EOF
UPDATE inventory i
SET quantity = (
    SELECT COALESCE(SUM(
        CASE 
            WHEN type = 'IN' THEN quantity
            WHEN type = 'OUT' THEN -quantity
            ELSE 0
        END
    ), 0)
    FROM stock_movements sm
    WHERE sm.sku = i.sku AND sm.warehouse_id = i.warehouse_id
)
WHERE EXISTS (SELECT 1 FROM stock_movements WHERE sku = i.sku);
EOF
```

## Monitoring & Alerts

### Key Metrics
- `warehouse_stock_updates_total` - Total stock updates
- `warehouse_events_published_total` - Events published
- `warehouse_reservations_total` - Stock reservations
- `warehouse_inventory_reconciliation_duration_seconds` - Reconciliation time

### Alert Thresholds
- **Event publishing failure > 5%**: Critical
- **Stock reservation timeout > 10%**: Warning
- **Inventory reconciliation failure**: Critical
- **Negative stock detected**: Critical

## Database Maintenance

### Cleanup Old Stock Movements

```sql
-- Archive movements older than 1 year
INSERT INTO stock_movements_archive 
SELECT * FROM stock_movements 
WHERE created_at < NOW() - INTERVAL '1 year';

DELETE FROM stock_movements 
WHERE created_at < NOW() - INTERVAL '1 year';
```

### Reindex Database

```bash
docker compose exec postgres psql -U warehouse_user -d warehouse_db -c "REINDEX DATABASE warehouse_db;"
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Warehouse Team Lead**: warehouse-team@company.com
- **Database Admin**: dba@company.com

## Logs Location

```bash
# View warehouse service logs
docker compose logs -f warehouse-service

# Search for errors
docker compose logs warehouse-service | grep ERROR

# Filter by SKU
docker compose logs warehouse-service | grep "SKU-123"
```

