# Auth Service - SRE Runbook

**Service:** Auth Service  
**Port:** 8000 (HTTP), 9000 (gRPC)  
**Health Check:** `GET /health` (gRPC HealthCheck method)  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status (via gRPC)
grpcurl -plaintext localhost:9000 api.auth.v1.AuthService/HealthCheck

# Or via HTTP (if exposed)
curl http://localhost:8000/health

# Expected response:
# {"status":"healthy","service":"auth-service","version":"v1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: JWT Token Validation Fails

**Symptoms:**
- All authenticated requests return 401 Unauthorized
- Token validation errors in logs

**Diagnosis:**
```bash
# Check JWT secret configuration
docker compose exec auth-service env | grep JWT_SECRET

# Check token validation logs
docker compose logs auth-service | grep "token validation"

# Test token validation manually
curl -H "Authorization: Bearer <token>" http://localhost:8000/api/v1/auth/validate
```

**Fix:**
1. Verify JWT secret is set correctly:
   ```bash
   # Check config file
   cat auth/configs/config-docker.yaml | grep jwt_secret
   ```

2. Ensure JWT secret matches across services (Gateway, Auth):
   ```bash
   # All services must use same secret
   docker compose exec gateway-service env | grep JWT_SECRET
   ```

3. Restart service if secret was updated:
   ```bash
   docker compose restart auth-service
   ```

### Issue 2: High Login Failure Rate

**Symptoms:**
- Many failed login attempts
- Account lockouts

**Diagnosis:**
```bash
# Check failed login logs
docker compose logs auth-service | grep "login failed"

# Check rate limiting
docker compose exec redis redis-cli GET "rate_limit:login:IP-ADDRESS"

# Check account lockouts
docker compose exec postgres psql -U auth_user -d auth_db -c "SELECT * FROM users WHERE locked_until > NOW();"
```

**Fix:**
1. Check for brute force attacks:
   ```bash
   docker compose logs auth-service | grep "rate limit exceeded"
   ```

2. Unlock legitimate users if needed:
   ```sql
   UPDATE users SET locked_until = NULL WHERE email = 'user@example.com';
   ```

3. Adjust rate limit settings if needed (in config)

### Issue 3: Session Management Issues

**Symptoms:**
- Sessions not persisting
- Users logged out unexpectedly

**Diagnosis:**
```bash
# Check Redis connectivity
docker compose exec redis redis-cli PING

# Check session storage
docker compose exec redis redis-cli KEYS "session:*"

# Check session TTL
docker compose exec redis redis-cli TTL "session:SESSION-ID"
```

**Fix:**
1. Verify Redis is running:
   ```bash
   docker compose ps redis
   ```

2. Check Redis memory:
   ```bash
   docker compose exec redis redis-cli INFO memory
   ```

3. Clear expired sessions:
   ```bash
   # Sessions auto-expire, but can manually clean if needed
   docker compose exec redis redis-cli --scan --pattern "session:*" | xargs redis-cli DEL
   ```

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U auth_user auth_db > auth_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U auth_user auth_db < auth_backup.sql
```

### Token Blacklist Recovery

```bash
# Clear token blacklist if needed (emergency only)
docker compose exec redis redis-cli --scan --pattern "blacklist:*" | xargs redis-cli DEL
```

### Service Restart

```bash
# Graceful restart
docker compose restart auth-service

# Force restart
docker compose up -d --force-recreate auth-service
```

## Monitoring & Alerts

### Key Metrics
- `auth_requests_total` - Total authentication requests
- `auth_login_attempts_total` - Login attempts (success/failure)
- `auth_token_validations_total` - Token validations
- `auth_sessions_active` - Active sessions count
- `auth_rate_limit_hits_total` - Rate limit violations

### Alert Thresholds
- **Login failure rate > 20%**: Warning (possible attack)
- **Token validation failure > 10%**: Critical
- **Session creation failure > 5%**: Critical
- **Rate limit hits > 100/min**: Warning (DDoS possible)

## Security Considerations

### JWT Secret Rotation

```bash
# 1. Update JWT secret in config
vim auth/configs/config-docker.yaml

# 2. Restart auth service
docker compose restart auth-service

# 3. Restart gateway (must use same secret)
docker compose restart gateway-service

# Note: Existing tokens will be invalidated
```

### Account Lockout Management

```sql
-- Unlock specific user
UPDATE users SET locked_until = NULL, failed_login_attempts = 0 WHERE email = 'user@example.com';

-- Check locked accounts
SELECT email, locked_until, failed_login_attempts FROM users WHERE locked_until > NOW();
```

## Database Maintenance

### Cleanup Expired Sessions

```sql
-- Sessions are stored in Redis, but check database for audit
SELECT COUNT(*) FROM sessions WHERE expires_at < NOW();
```

### Cleanup Old Audit Logs

```sql
-- Archive audit logs older than 1 year
INSERT INTO audit_logs_archive 
SELECT * FROM audit_logs 
WHERE created_at < NOW() - INTERVAL '1 year';

DELETE FROM audit_logs 
WHERE created_at < NOW() - INTERVAL '1 year';
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Security Team**: security@company.com
- **Auth Team Lead**: auth-team@company.com

## Logs Location

```bash
# View auth service logs
docker compose logs -f auth-service

# Search for errors
docker compose logs auth-service | grep ERROR

# Filter by user email
docker compose logs auth-service | grep "user@example.com"
```

## Configuration

**Config File:** `auth/configs/config-docker.yaml`

**Key Settings:**
- `auth.jwt_secret`: JWT signing secret (must match Gateway)
- `auth.token_ttl`: Token expiration time
- `auth.rate_limit`: Login rate limit per IP
- `auth.max_login_attempts`: Max failed attempts before lockout

**Update Config:**
```bash
# Edit config
vim auth/configs/config-docker.yaml

# Restart service
docker compose restart auth-service
```

