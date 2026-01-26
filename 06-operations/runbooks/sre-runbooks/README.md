# SRE Runbooks Index

> **Quick reference guide for all service runbooks. Each runbook contains health checks, common issues, recovery steps, monitoring, and emergency contacts.**

## 📋 Runbooks by Service

### Core Infrastructure Services

| Service | Port | Health Check | Runbook |
|---------|------|--------------|---------|
| **Gateway** | 8080 | `GET /health` | [gateway-runbook.md](./gateway-runbook.md) |
| | | | API routing, JWT validation, upstream service issues |

### Order & Fulfillment Services

| Service | Port | Health Check | Runbook |
|---------|------|--------------|---------|
| **Order** | 8004, 9004 | `GET /health` | [order-service-runbook.md](./order-service-runbook.md) |
| | | | Order creation, cart operations, event publishing |
| **Fulfillment** | 8010, 9010 | `GET /health` | [fulfillment-service-runbook.md](./fulfillment-service-runbook.md) |
| | | | Fulfillment creation, picklist generation, batch processing |

### Product & Inventory Services

| Service | Port | Health Check | Runbook |
|---------|------|--------------|---------|
| **Catalog** | 8015, 9015 | `GET /api/v1/catalog/health` | [catalog-service-runbook.md](./catalog-service-runbook.md) |
| | | | Stock sync, product search, cache optimization |
| **Warehouse** | 8008, 9008 | `GET /health` | [warehouse-service-runbook.md](./warehouse-service-runbook.md) |
| | | | Stock updates, inventory reconciliation, reservations |
| **Pricing** | 8002, 9002 | `GET /health` | [pricing-service-runbook.md](./pricing-service-runbook.md) |
| | | | Price calculation, price sync, cache hit rate |
| **Search** | 8010, 9010 | `GET /health` | [search-service-runbook.md](./search-service-runbook.md) |
| | | | Elasticsearch cluster, search performance, indexing |

### Customer & User Services

| Service | Port | Health Check | Runbook |
|---------|------|--------------|---------|
| **Customer** | 8007, 9007 | `GET /health` | [customer-service-runbook.md](./customer-service-runbook.md) |
| | | | Customer profiles, addresses, segmentation |
| **User** | 8001, 9001 | `GET /health` | [user-service-runbook.md](./user-service-runbook.md) |
| | | | User management, roles, permissions, Elasticsearch |
| **Auth** | 8000, 9000 | `GET /health` | [auth-service-runbook.md](./auth-service-runbook.md) |
| | | | JWT validation, login failures, session management |

### Payment & Shipping Services

| Service | Port | Health Check | Runbook |
|---------|------|--------------|---------|
| **Payment** | 8005, 9005 | `GET /api/v1/payments/health` | [payment-service-runbook.md](./payment-service-runbook.md) |
| | | | Payment processing, gateway webhooks, refunds, PCI compliance |
| **Shipping** | 8006, 9006 | `GET /health` | [shipping-service-runbook.md](./shipping-service-runbook.md) |
| | | | Shipment creation, carrier APIs, tracking updates |

### Marketing & Engagement Services

| Service | Port | Health Check | Runbook |
|---------|------|--------------|---------|
| **Promotion** | 8003, 9003 | `GET /health` | [promotion-service-runbook.md](./promotion-service-runbook.md) |
| | | | Promotion application, coupon usage, discount calculation |
| **Notification** | 8009, 9009 | `GET /health` | [notification-service-runbook.md](./notification-service-runbook.md) |
| | | | Email/SMS/Push delivery, provider connectivity |
| **Review** | 8014, 9014 | `GET /health` | [review-service-runbook.md](./review-service-runbook.md) |
| | | | Review creation, rating aggregation, moderation |
| **Loyalty Rewards** | 8013, 9013 | `GET /health` | [loyalty-rewards-service-runbook.md](./loyalty-rewards-service-runbook.md) |
| | | | Points awarding, tier upgrades, redemptions, referrals |

---

## 🚨 Quick Troubleshooting Guide

### Service Won't Start
1. Check health endpoint: `curl http://localhost:PORT/health`
2. Check logs: `docker compose logs -f SERVICE-NAME`
3. Check database connectivity
4. Check Consul registration
5. Check port conflicts

### High Error Rate
1. Check service logs for errors
2. Check database connection pool
3. Check external service connectivity
4. Check rate limits
5. Check resource usage (CPU, memory)

### Slow Performance
1. Check database query performance
2. Check cache hit rate
3. Check external service latency
4. Check connection pool usage
5. Check for deadlocks or locks

### Event Processing Issues
1. Check Dapr sidecar status
2. Check event subscription
3. Check Redis Streams
4. Check event handler logs
5. Verify event schema compatibility

---

## 📊 Common Monitoring Metrics

All services expose Prometheus metrics at `/metrics`. Key metrics to monitor:

- **Request Rate**: `{service}_requests_total`
- **Error Rate**: `{service}_errors_total`
- **Latency**: `{service}_request_duration_seconds`
- **Database**: Connection pool, query duration
- **Cache**: Hit rate, miss rate
- **Events**: Published, consumed, failures

---

## 🔧 Common Recovery Commands

### Service Restart
```bash
# Graceful restart
docker compose restart SERVICE-NAME

# Force restart
docker compose up -d --force-recreate SERVICE-NAME
```

### Database Backup/Restore
```bash
# Backup
docker compose exec postgres pg_dump -U USER DB_NAME > backup.sql

# Restore
docker compose exec -T postgres psql -U USER DB_NAME < backup.sql
```

### Clear Cache
```bash
# Redis cache
docker compose exec redis redis-cli FLUSHDB

# Service-specific cache
docker compose exec redis redis-cli --scan --pattern "PATTERN:*" | xargs redis-cli DEL
```

### Check Service Discovery
```bash
# Consul services
curl http://localhost:8500/v1/catalog/services

# Service health
curl http://localhost:8500/v1/health/service/SERVICE-NAME
```

---

## 📞 Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Platform Team**: platform-team@company.com
- **Database Admin**: dba@company.com
- **SRE Team**: sre@company.com

---

## 📝 Runbook Maintenance

**Update runbooks when:**
- New common issues are discovered
- Recovery procedures change
- Monitoring thresholds change
- Service configuration changes
- After incident post-mortem

**Runbook Template:**
- Quick Health Check
- Common Issues & Quick Fixes
- Recovery Steps
- Monitoring & Alerts
- Database Maintenance (if applicable)
- Emergency Contacts
- Logs Location
- Configuration Details

---

## 🔗 Related Documentation

- [API Contracts](../openapi/) - OpenAPI specifications
- [Event Contracts](../json-schema/) - JSON Schema event definitions
- [Architecture Decisions](../adr/) - ADR documents
- [Design Docs](../design/) - Technical design documents
- [DDD Context Map](../ddd/context-map.md) - Domain boundaries

---

**Last Updated:** 2025-11-17  
**Total Runbooks:** 17 services
