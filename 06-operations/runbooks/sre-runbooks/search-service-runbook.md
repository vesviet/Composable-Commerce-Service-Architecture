# Search Service - SRE Runbook

**Service:** Search Service  
**Port:** 8010 (HTTP), 9010 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8010/health

# Check Elasticsearch health
curl http://localhost:9200/_cluster/health

# Expected response:
# {"status":"ok","service":"search","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Search Returns No Results

**Symptoms:**
- Search queries return empty results
- Products not indexed

**Diagnosis:**
```bash
# Check Elasticsearch indices
curl http://localhost:9200/_cat/indices

# Check product index
curl http://localhost:9200/products/_search?q=*

# Check index document count
curl http://localhost:9200/products/_count
```

**Fix:**
1. Trigger reindex:
   ```bash
   curl -X POST http://localhost:8010/api/v1/search/reindex
   ```

2. Check index mapping:
   ```bash
   curl http://localhost:9200/products/_mapping
   ```

3. Verify products are being indexed from Catalog Service

### Issue 2: Elasticsearch Cluster Issues

**Symptoms:**
- Elasticsearch errors
- Search service unavailable

**Diagnosis:**
```bash
# Check Elasticsearch cluster health
curl http://localhost:9200/_cluster/health?pretty

# Check Elasticsearch logs
docker compose logs elasticsearch | tail -50

# Check node status
curl http://localhost:9200/_cat/nodes
```

**Fix:**
1. Check cluster status (should be green):
   ```bash
   curl http://localhost:9200/_cluster/health
   # Status: green (healthy), yellow (warning), red (critical)
   ```

2. Restart Elasticsearch if needed:
   ```bash
   docker compose restart elasticsearch
   ```

3. Check disk space:
   ```bash
   docker compose exec elasticsearch df -h
   ```

### Issue 3: Search Performance Issues

**Symptoms:**
- Slow search queries (>1s)
- High Elasticsearch load

**Diagnosis:**
```bash
# Check search latency
curl http://localhost:8010/metrics | grep search_duration

# Check Elasticsearch slow queries
curl http://localhost:9200/_cat/thread_pool/search

# Check index size
curl http://localhost:9200/_cat/indices/products?v
```

**Fix:**
1. Optimize search queries (add filters, limit results)

2. Add Elasticsearch replicas for better performance:
   ```bash
   curl -X PUT "http://localhost:9200/products/_settings" -H 'Content-Type: application/json' -d'
   {
     "index": {
       "number_of_replicas": 2
     }
   }'
   ```

3. Scale Elasticsearch cluster if needed

## Recovery Steps

### Elasticsearch Recovery

```bash
# Backup Elasticsearch indices
curl -X PUT "http://localhost:9200/_snapshot/backup_repo" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/backup/elasticsearch"
  }
}'

# Create snapshot
curl -X PUT "http://localhost:9200/_snapshot/backup_repo/snapshot_1?wait_for_completion=true"

# Restore from snapshot
curl -X POST "http://localhost:9200/_snapshot/backup_repo/snapshot_1/_restore"
```

### Reindex All Products

```bash
# Trigger full reindex
curl -X POST http://localhost:8010/api/v1/search/reindex?full=true

# Check reindex progress
curl http://localhost:8010/api/v1/search/reindex/status
```

## Monitoring & Alerts

### Key Metrics
- `search_queries_total` - Total search queries
- `search_duration_seconds` - Search query latency
- `search_results_count` - Average results per query
- `elasticsearch_queries_total` - Elasticsearch queries
- `index_updates_total` - Index update operations

### Alert Thresholds
- **Search latency > 1s**: Warning
- **Elasticsearch cluster status = red**: Critical
- **Index update failure > 5%**: Critical
- **Search error rate > 10%**: Critical

## Database Maintenance

### Elasticsearch Index Optimization

```bash
# Force merge indices (reduce segments)
curl -X POST "http://localhost:9200/products/_forcemerge?max_num_segments=1"

# Refresh indices
curl -X POST "http://localhost:9200/products/_refresh"
```

### Cleanup Old Indices

```bash
# Delete old indices (if using time-based indices)
curl -X DELETE "http://localhost:9200/products-2024-01-*"
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Search Team Lead**: search-team@company.com
- **Elasticsearch Admin**: es-admin@company.com

## Logs Location

```bash
# View search service logs
docker compose logs -f search-service

# View Elasticsearch logs
docker compose logs -f elasticsearch

# Search for errors
docker compose logs search-service | grep ERROR
```

