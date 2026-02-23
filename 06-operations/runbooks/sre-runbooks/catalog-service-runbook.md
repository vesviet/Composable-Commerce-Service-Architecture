# Catalog Service - SRE Runbook

**Service:** Catalog Service  
**Port:** 8015 (HTTP), 9015 (gRPC)  
**Health Check:** `GET /api/v1/catalog/health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8015/api/v1/catalog/health

# Expected response:
# {"status":"ok","service":"catalog","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Stock Sync Not Working

**Symptoms:**
- Product stock levels not updating
- Stock events not being processed

**Diagnosis:**
```bash
# Check event handler logs
docker compose logs catalog-service | grep "stock-updated"

# Check Dapr connectivity
curl http://localhost:3500/v1.0/health

# Check Redis cache
docker compose exec redis redis-cli GET "stock:SKU-123:warehouse-456"
```

**Fix:**
1. Verify Dapr sidecar is running:
   ```bash
   docker compose ps | grep catalog-dapr
   ```

2. Check event subscription:
   ```bash
   curl http://localhost:3500/v1.0/metadata | jq '.subscriptions'
   ```

3. Restart event handler if needed:
   ```bash
   docker compose restart catalog-service
   ```

### Issue 2: High Database Load

**Symptoms:**
- Slow product queries
- Database connection pool exhausted

**Diagnosis:**
```bash
# Check database connections
docker compose exec postgres psql -U catalog_user -d catalog_db -c "SELECT count(*) FROM pg_stat_activity WHERE datname='catalog_db';"

# Check slow queries
docker compose exec postgres psql -U catalog_user -d catalog_db -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

**Fix:**
1. Check connection pool settings in config
2. Add database indexes for slow queries
3. Scale service if needed:
   ```bash
   docker compose up -d --scale catalog-service=3
   ```

### Issue 3: Cache Miss Rate High

**Symptoms:**
- High database load
- Slow API responses

**Diagnosis:**
```bash
# Check Redis cache stats
docker compose exec redis redis-cli INFO stats | grep keyspace

# Check cache hit rate metric
curl http://localhost:8015/metrics | grep cache_hit_rate
```

**Fix:**
1. Warm up cache:
   ```bash
   curl http://localhost:8015/api/v1/catalog/products/bulk/stock?ids=1,2,3
   ```

2. Increase cache TTL if appropriate
3. Check Redis memory:
   ```bash
   docker compose exec redis redis-cli INFO memory
   ```

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U catalog_user catalog_db > catalog_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U catalog_user catalog_db < catalog_backup.sql
```

### Cache Recovery

```bash
# Clear cache and let it rebuild
docker compose exec redis redis-cli FLUSHDB

# Or clear specific patterns
docker compose exec redis redis-cli --scan --pattern "stock:*" | xargs redis-cli DEL
```

## Monitoring & Alerts

### Key Metrics
- `catalog_requests_total` - Total API requests
- `catalog_request_duration_seconds` - Request latency
- `catalog_stock_sync_latency_seconds` - Stock sync latency
- `catalog_cache_hit_rate` - Cache hit rate
- `catalog_events_processed_total` - Events processed

### Alert Thresholds
- **Stock sync latency > 200ms**: Warning
- **Cache hit rate < 90%**: Warning
- **Database connection pool > 80%**: Critical
- **Event processing failure > 5%**: Critical

## Database Maintenance

### Reindex Database

```bash
docker compose exec postgres psql -U catalog_user -d catalog_db -c "REINDEX DATABASE catalog_db;"
```

### Vacuum Database

```bash
docker compose exec postgres psql -U catalog_user -d catalog_db -c "VACUUM ANALYZE;"
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Catalog Team Lead**: catalog-team@company.com
- **Database Admin**: dba@company.com

## Logs Location

```bash
# View catalog service logs
docker compose logs -f catalog-service

# Search for errors
docker compose logs catalog-service | grep ERROR

# Filter by product ID
docker compose logs catalog-service | grep "product-id-123"
```

