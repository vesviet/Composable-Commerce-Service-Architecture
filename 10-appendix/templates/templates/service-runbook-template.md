# {Service Name} Service - SRE Runbook

**Service:** {Service Name}  
**Port:** {HTTP Port} (HTTP), {gRPC Port} (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** {YYYY-MM-DD}

## Quick Health Check

```bash
# Check service status
curl http://localhost:{http-port}/health

# Expected response:
# {"status":"ok","service":"{service-name}","version":"1.0.0"}

# Check via Consul
curl http://localhost:8500/v1/health/service/{service-name}

# Check service info
curl http://localhost:{http-port}/api/v1/service/info
```

## Service Dependencies

| Dependency | Type | Health Check |
|------------|------|--------------|
| PostgreSQL | Database | `docker compose exec postgres pg_isready` |
| Redis | Cache/PubSub | `docker compose exec redis redis-cli ping` |
| Consul | Service Discovery | `curl http://localhost:8500/v1/status/leader` |
| Dapr | Event Messaging | `curl http://localhost:3500/v1.0/healthz` |

## Common Issues & Quick Fixes

### Issue 1: {Common Issue Name}

**Symptoms:**
- {Symptom 1}
- {Symptom 2}

**Diagnosis:**
```bash
# Check service logs
docker compose logs {service-name}-service | tail -50

# Check specific error patterns
docker compose logs {service-name}-service | grep -i "error\|fatal\|panic"

# Check database connectivity
docker compose exec {service-name}-service psql -h postgres -U {user} -d {dbname} -c "SELECT 1"

# Check Redis connectivity
docker compose exec {service-name}-service redis-cli -h redis ping
```

**Fix:**
1. {Step 1}
   ```bash
   {command}
   ```

2. {Step 2}
   ```bash
   {command}
   ```

**Prevention:**
- {Prevention measure 1}
- {Prevention measure 2}

### Issue 2: {Another Common Issue}

**Symptoms:**
- {Symptom}

**Diagnosis:**
```bash
{diagnosis commands}
```

**Fix:**
{Solution steps}

## Recovery Procedures

### Service Restart

```bash
# Graceful restart
docker compose restart {service-name}-service

# Force restart
docker compose up -d --force-recreate {service-name}-service

# Rebuild and restart (after code changes)
docker compose build {service-name}-service
docker compose up -d --force-recreate {service-name}-service
```

### Database Recovery

```bash
# Check database status
docker compose exec postgres psql -U {user} -d {dbname} -c "SELECT version();"

# Run migrations
docker compose exec {service-name}-service make migrate-up

# Rollback migrations (if needed)
docker compose exec {service-name}-service make migrate-down
```

### Cache Clear

```bash
# Clear Redis cache for this service
docker compose exec redis redis-cli -n {db-number} FLUSHDB

# Clear specific keys
docker compose exec redis redis-cli -n {db-number} KEYS "{service-name}:*" | xargs docker compose exec redis redis-cli -n {db-number} DEL
```

## Monitoring

### Key Metrics

| Metric | Threshold | Alert |
|--------|-----------|-------|
| `{metric_name}` | {threshold} | {alert condition} |
| Request rate | {threshold} req/s | > {threshold} |
| Error rate | {threshold}% | > {threshold}% |
| Response time (p95) | {threshold}ms | > {threshold}ms |

### Log Queries

```bash
# Recent errors
docker compose logs {service-name}-service | grep -i error | tail -20

# High latency requests
docker compose logs {service-name}-service | grep "duration" | awk '$NF > 1000'

# Event processing issues
docker compose logs {service-name}-service | grep -i "event\|pubsub"
```

### Prometheus Queries

```promql
# Request rate
rate(http_requests_total{service="{service-name}"}[5m])

# Error rate
rate(http_requests_total{service="{service-name}",status=~"5.."}[5m])

# Response time (p95)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{service="{service-name}"}[5m]))
```

## Scaling

### Horizontal Scaling

```bash
# Scale service instances
docker compose up -d --scale {service-name}-service=3

# Check service instances
docker compose ps {service-name}-service
```

### Database Connection Pool

```yaml
# configs/config.yaml
data:
  database:
    maxOpenConns: 25
    maxIdleConns: 10
    connMaxLifetime: 5m
```

## Emergency Contacts

- **On-Call Engineer:** {Contact}
- **Service Owner:** {Contact}
- **Database Admin:** {Contact}
- **Platform Team:** {Contact}

## Escalation Path

1. **Level 1:** Check runbook, restart service
2. **Level 2:** Contact on-call engineer
3. **Level 3:** Escalate to service owner
4. **Level 4:** Escalate to platform team

## Related Documentation

- [Service Documentation](../services/{service-name}.md)
- [OpenAPI Spec](../openapi/{service-name}.openapi.yaml)
- [Event Contracts](../json-schema/)

