# Order Service - SRE Runbook

**Service:** Order Service  
**Port:** 8004 (HTTP), 9004 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8004/health

# Expected response:
# {"status":"ok","service":"order","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Order Creation Fails

**Symptoms:**
- POST /api/v1/orders returns 500
- Orders not created in database

**Diagnosis:**
```bash
# Check service logs
docker compose logs order-service | tail -50

# Check database connectivity
docker compose exec order-service psql -h postgres -U order_user -d order_db -c "SELECT 1"

# Check external service calls
docker compose logs order-service | grep "circuit breaker"
```

**Fix:**
1. Check database connection:
   ```bash
   docker compose exec postgres psql -U order_user -d order_db
   ```

2. Verify external services (Catalog, Pricing, Warehouse):
   ```bash
   curl http://localhost:8500/v1/health/service/catalog-service
   curl http://localhost:8500/v1/health/service/pricing-service
   curl http://localhost:8500/v1/health/service/warehouse-service
   ```

3. Check circuit breaker state (if open, wait for recovery)

### Issue 2: Cart Operations Slow

**Symptoms:**
- Cart API responses >1s
- Redis connection errors

**Diagnosis:**
```bash
# Check Redis connectivity
docker compose exec redis redis-cli PING

# Check Redis memory
docker compose exec redis redis-cli INFO memory

# Check cart operations in logs
docker compose logs order-service | grep "cart"
```

**Fix:**
1. Restart Redis if needed:
   ```bash
   docker compose restart redis
   ```

2. Clear old cart sessions:
   ```bash
   docker compose exec redis redis-cli --scan --pattern "cart:*" | xargs redis-cli DEL
   ```

### Issue 3: Event Publishing Fails

**Symptoms:**
- Orders created but events not published
- Downstream services not receiving updates

**Diagnosis:**
```bash
# Check Dapr connectivity
curl http://localhost:3500/v1.0/health

# Check event publishing logs
docker compose logs order-service | grep "publish event"

# Check Dapr sidecar
docker compose logs order-service-dapr
```

**Fix:**
1. Restart Dapr sidecar:
   ```bash
   docker compose restart order-service-dapr
   ```

2. Verify Dapr pub/sub component:
   ```bash
   curl http://localhost:3500/v1.0/metadata
   ```

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U order_user order_db > order_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U order_user order_db < order_backup.sql
```

### Service Restart

```bash
# Graceful restart
docker compose restart order-service

# Force restart
docker compose up -d --force-recreate order-service
```

## Monitoring & Alerts

### Key Metrics
- `orders_created_total` - Total orders created
- `orders_failed_total` - Failed order creations
- `order_operation_duration_seconds` - Operation latency
- `cart_operations_total` - Cart operations count
- `order_events_published_total` - Events published

### Alert Thresholds
- **Order creation failure rate > 5%**: Critical
- **Cart operation latency > 1s**: Warning
- **Event publishing failure > 10%**: Critical

## Database Maintenance

### Cleanup Old Orders

```sql
-- Archive orders older than 1 year
INSERT INTO orders_archive SELECT * FROM orders WHERE created_at < NOW() - INTERVAL '1 year';
DELETE FROM orders WHERE created_at < NOW() - INTERVAL '1 year';
```

### Vacuum Database

```bash
docker compose exec postgres psql -U order_user -d order_db -c "VACUUM ANALYZE;"
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Order Team Lead**: order-team@company.com
- **Database Admin**: dba@company.com

## Logs Location

```bash
# View order service logs
docker compose logs -f order-service

# Search for errors
docker compose logs order-service | grep ERROR

# Filter by order ID
docker compose logs order-service | grep "order-id-123"
```

