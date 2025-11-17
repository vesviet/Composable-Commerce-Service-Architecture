# Gateway Service - SRE Runbook

**Service:** Gateway Service  
**Port:** 8080 (HTTP)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8080/health

# Expected response:
# {"status":"ok","service":"gateway","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Gateway Returns 502 Bad Gateway

**Symptoms:**
- All requests return 502
- Gateway logs show "upstream service unavailable"

**Diagnosis:**
```bash
# Check Consul service discovery
curl http://localhost:8500/v1/health/service/gateway

# Check if downstream services are registered
curl http://localhost:8500/v1/catalog/services
```

**Fix:**
1. Check if downstream services are running:
   ```bash
   docker compose ps
   ```

2. Restart gateway if needed:
   ```bash
   docker compose restart gateway-service
   ```

3. Check Consul connectivity:
   ```bash
   docker compose logs gateway-service | grep consul
   ```

### Issue 2: High Latency (>500ms)

**Symptoms:**
- API responses slow
- Timeout errors

**Diagnosis:**
```bash
# Check gateway metrics
curl http://localhost:8080/metrics | grep gateway_request_duration

# Check downstream service latency
curl http://localhost:8500/v1/health/service/catalog-service
```

**Fix:**
1. Check downstream service health
2. Scale gateway if needed:
   ```bash
   docker compose up -d --scale gateway-service=3
   ```
3. Check network connectivity

### Issue 3: Authentication Failures

**Symptoms:**
- 401 Unauthorized errors
- JWT validation failures

**Diagnosis:**
```bash
# Check Auth Service connectivity
curl http://localhost:8500/v1/health/service/auth-service

# Test token validation
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/v1/customers/me
```

**Fix:**
1. Verify Auth Service is running
2. Check JWT secret configuration
3. Verify token format

## Recovery Steps

### Full Service Restart

```bash
# Stop gateway
docker compose stop gateway-service

# Start gateway
docker compose up -d gateway-service

# Verify health
curl http://localhost:8080/health
```

### Rollback to Previous Version

```bash
# Check current version
docker images | grep gateway

# Rollback to previous image
docker compose up -d --force-recreate gateway-service
```

## Monitoring & Alerts

### Key Metrics
- `gateway_requests_total` - Total requests
- `gateway_request_duration_seconds` - Request latency
- `gateway_errors_total` - Error count
- `gateway_upstream_errors_total` - Downstream service errors

### Alert Thresholds
- **Latency > 500ms**: Warning
- **Error rate > 5%**: Critical
- **Upstream errors > 10%**: Critical

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Platform Team Lead**: platform-lead@company.com
- **SRE Team**: sre@company.com

## Logs Location

```bash
# View gateway logs
docker compose logs -f gateway-service

# Search for errors
docker compose logs gateway-service | grep ERROR

# Last 100 lines
docker compose logs --tail=100 gateway-service
```

## Configuration

**Config File:** `gateway/configs/config.yaml`

**Key Settings:**
- `server.http.addr`: Gateway listen address
- `consul.address`: Consul service discovery address
- `auth.jwt_secret`: JWT validation secret

**Update Config:**
```bash
# Edit config
vim gateway/configs/config.yaml

# Restart service
docker compose restart gateway-service
```

