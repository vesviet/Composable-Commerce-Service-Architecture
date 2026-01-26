# Pricing Service - SRE Runbook

**Service:** Pricing Service  
**Port:** 8002 (HTTP), 9002 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8002/health

# Expected response:
# {"status":"ok","service":"pricing","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Price Calculation Fails

**Symptoms:**
- Price calculation returns error
- Prices not calculated correctly

**Diagnosis:**
```bash
# Check service logs
docker compose logs pricing-service | grep "price calculation"

# Check Redis cache
docker compose exec redis redis-cli GET "prices:product:PROD-123:VND"

# Check database
docker compose exec postgres psql -U pricing_user -d pricing_db -c "SELECT * FROM prices WHERE product_id = 'PROD-123';"
```

**Fix:**
1. Verify product exists in Catalog Service:
   ```bash
   curl http://localhost:8015/api/v1/catalog/products/PROD-123
   ```

2. Check price priority logic (SKU+WH > SKU > Product+WH > Product)

3. Clear cache and recalculate:
   ```bash
   docker compose exec redis redis-cli DEL "prices:product:PROD-123:VND"
   curl -X POST http://localhost:8002/api/v1/pricing/calculate -d '{"product_id":"PROD-123"}'
   ```

### Issue 2: Price Sync Not Working

**Symptoms:**
- Prices not syncing to Catalog Service
- Price events not published

**Diagnosis:**
```bash
# Check event publishing logs
docker compose logs pricing-service | grep "publish event"

# Check Dapr connectivity
curl http://localhost:3500/v1.0/health

# Check price sync worker
docker compose logs pricing-service | grep "sync worker"
```

**Fix:**
1. Check Dapr sidecar:
   ```bash
   docker compose ps | grep pricing-dapr
   ```

2. Manually trigger price sync:
   ```bash
   curl -X POST http://localhost:8002/api/v1/pricing/sync
   ```

3. Check event subscription in Catalog Service
   - Verify Subscription to `pricing.price.updated`
   - Check Consumer logs for `PriceScope` filtering (product/warehouse/sku)

### Debugging Unified Price Topic
Since Jan 2026, all price updates (Product, Warehouse, SKU) are published to a single topic: `pricing.price.updated`.

**Check Payload:**
Ensure `priceScope` field is present:
```json
{
  "productId": "p1",
  "priceScope": "warehouse",  <-- CRITICAL
  "warehouseId": "wh1",
  "newPrice": 100
}
```

### Issue 3: Cache Hit Rate Low

**Symptoms:**
- High database load
- Slow price calculations

**Diagnosis:**
```bash
# Check cache hit rate
curl http://localhost:8002/metrics | grep cache_hit_rate

# Check Redis memory
docker compose exec redis redis-cli INFO memory

# Check cache keys
docker compose exec redis redis-cli KEYS "prices:*" | head -20
```

**Fix:**
1. Warm up cache:
   ```bash
   curl -X POST http://localhost:8002/api/v1/pricing/cache/warm
   ```

2. Increase cache TTL if appropriate (in config)

3. Check Redis memory limits

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U pricing_user pricing_db > pricing_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U pricing_user pricing_db < pricing_backup.sql
```

### Cache Recovery

```bash
# Clear all price cache
docker compose exec redis redis-cli --scan --pattern "prices:*" | xargs redis-cli DEL

# Cache will rebuild on next request
```

## Monitoring & Alerts

### Key Metrics
- `pricing_calculations_total` - Total price calculations
- `pricing_calculation_duration_seconds` - Calculation latency
- `pricing_cache_hits_total` - Cache hits
- `pricing_cache_misses_total` - Cache misses
- `pricing_events_published_total` - Events published

### Alert Thresholds
- **Price calculation failure > 5%**: Critical
- **Cache hit rate < 80%**: Warning
- **Calculation latency > 200ms**: Warning
- **Event publishing failure > 10%**: Critical

## Database Maintenance

### Recalculate All Prices

```sql
-- Trigger recalculation for all products (via API)
-- This should be done via service endpoint, not direct SQL
```

### Cleanup Old Price History

```sql
-- Archive price history older than 1 year
INSERT INTO price_history_archive 
SELECT * FROM price_history 
WHERE created_at < NOW() - INTERVAL '1 year';

DELETE FROM price_history 
WHERE created_at < NOW() - INTERVAL '1 year';
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Pricing Team Lead**: pricing-team@company.com

## Logs Location

```bash
# View pricing service logs
docker compose logs -f pricing-service

# Search for errors
docker compose logs pricing-service | grep ERROR

# Filter by product ID
docker compose logs pricing-service | grep "PROD-123"
```

