# User Service - SRE Runbook

**Service:** User Service  
**Port:** 8001 (HTTP), 9001 (gRPC)  
**Health Check:** `GET /health`, `GET /health/ready`, `GET /health/live`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8001/health

# Readiness check (Kubernetes)
curl http://localhost:8001/health/ready

# Liveness check (Kubernetes)
curl http://localhost:8001/health/live

# Expected response:
# {"status":"ok","service":"user","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: User Creation Fails

**Symptoms:**
- POST /api/v1/users returns 500
- Users not created in database

**Diagnosis:**
```bash
# Check service logs
docker compose logs user-service | tail -50

# Check database connectivity
docker compose exec postgres psql -U user_user -d user_db -c "SELECT 1"

# Check Elasticsearch connectivity (if used)
curl http://localhost:9200/_cluster/health
```

**Fix:**
1. Check database connection:
   ```bash
   docker compose exec postgres psql -U user_user -d user_db
   ```

2. Verify Elasticsearch is running (if used for search):
   ```bash
   docker compose ps elasticsearch
   curl http://localhost:9200/_cluster/health
   ```

3. Check for duplicate email/username:
   ```sql
   SELECT email, username FROM users WHERE email = 'user@example.com';
   ```

### Issue 2: Role/Permission Assignment Fails

**Symptoms:**
- Role assignment returns error
- Permissions not applied

**Diagnosis:**
```bash
# Check role assignment logs
docker compose logs user-service | grep "role assignment"

# Check roles table
docker compose exec postgres psql -U user_user -d user_db -c "SELECT * FROM roles;"

# Check user roles
docker compose exec postgres psql -U user_user -d user_db -c "SELECT * FROM user_roles WHERE user_id = 'USER-ID';"
```

**Fix:**
1. Verify role exists:
   ```sql
   SELECT * FROM roles WHERE id = 'ROLE-ID';
   ```

2. Check user-role relationship:
   ```sql
   SELECT ur.*, r.name FROM user_roles ur 
   JOIN roles r ON ur.role_id = r.id 
   WHERE ur.user_id = 'USER-ID';
   ```

### Issue 3: Search Functionality Not Working

**Symptoms:**
- User search returns empty results
- Elasticsearch errors

**Diagnosis:**
```bash
# Check Elasticsearch health
curl http://localhost:9200/_cluster/health

# Check user index
curl http://localhost:9200/users/_search?q=*

# Check Elasticsearch logs
docker compose logs elasticsearch | tail -50
```

**Fix:**
1. Reindex users if needed:
   ```bash
   # Trigger reindex via API (if endpoint exists)
   curl -X POST http://localhost:8001/api/v1/admin/reindex
   ```

2. Check Elasticsearch cluster status:
   ```bash
   curl http://localhost:9200/_cluster/health?pretty
   ```

## Recovery Steps

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U user_user user_db > user_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U user_user user_db < user_backup.sql
```

### Elasticsearch Recovery

```bash
# Backup Elasticsearch indices
curl -X GET "http://localhost:9200/_snapshot/backup_repo/snapshot_1" | jq

# Restore from snapshot
curl -X POST "http://localhost:9200/_snapshot/backup_repo/snapshot_1/_restore"
```

## Monitoring & Alerts

### Key Metrics
- `user_operations_total` - Total user operations
- `user_creation_duration_seconds` - User creation latency
- `user_search_duration_seconds` - Search query latency
- `user_role_assignments_total` - Role assignments
- `elasticsearch_queries_total` - Elasticsearch queries

### Alert Thresholds
- **User creation failure > 5%**: Critical
- **Search latency > 500ms**: Warning
- **Elasticsearch errors > 10%**: Critical
- **Database connection pool > 80%**: Critical

## Database Maintenance

### Cleanup Inactive Users

```sql
-- Archive inactive users (not logged in for 1 year)
UPDATE users SET status = 'INACTIVE' 
WHERE last_login_at < NOW() - INTERVAL '1 year' AND status = 'ACTIVE';
```

### Reindex Elasticsearch

```bash
# Reindex all users (if search is broken)
# This should be done via service API if available
curl -X POST http://localhost:8001/api/v1/admin/reindex
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **User Team Lead**: user-team@company.com
- **Database Admin**: dba@company.com

## Logs Location

```bash
# View user service logs
docker compose logs -f user-service

# Search for errors
docker compose logs user-service | grep ERROR

# Filter by user ID
docker compose logs user-service | grep "user-id-123"
```

