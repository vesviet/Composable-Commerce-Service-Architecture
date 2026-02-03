# Search Indexing Operational Runbook

**Version**: 1.0
**Last Updated**: 2026-01-31
**Service**: Search Service
**Category**: Operations

## Overview

This runbook provides operational procedures for managing the search indexing workflow, including event lag handling, DLQ replay, bulk reindexing, and troubleshooting common issues.

## Incident Response Procedures

### High Event Processing Lag

**Detection**: Alert `SearchEventProcessingLagHigh` triggers when event processing lag > 300 seconds.

**Immediate Actions**:
1. Check search service health and resource utilization
2. Verify Elasticsearch cluster status and performance
3. Check event consumer status and thread pool utilization
4. Review recent error logs for event processing failures

**Resolution Steps**:
1. **Scale Search Service**:
   ```bash
   kubectl scale deployment search-service --replicas=3
   ```

2. **Check Event Consumer Health**:
   ```bash
   # Check consumer pod logs
   kubectl logs -l app=search-service -c event-consumer --tail=100

   # Check consumer metrics
   curl http://search-service:9090/metrics | grep event_processing
   ```

3. **Restart Event Consumers** (if unresponsive):
   ```bash
   kubectl rollout restart deployment search-service
   ```

4. **Verify Event Lag Recovery**:
   ```bash
   # Monitor lag metrics
   watch -n 10 'curl -s http://search-service:9090/metrics | grep event_processing_lag'
   ```

**Prevention**:
- Monitor event queue depth and consumer throughput
- Implement auto-scaling based on event processing lag
- Regular capacity planning based on event volume trends

### DLQ Message Accumulation

**Detection**: Alert `SearchDLQDepthHigh` triggers when DLQ contains > 100 messages.

**Investigation**:
1. **Check DLQ Contents**:
   ```bash
   # Query DLQ messages
   SELECT id, event_type, error_message, retry_count, created_at
   FROM search_dlq_messages
   ORDER BY created_at DESC
   LIMIT 10;
   ```

2. **Analyze Error Patterns**:
   ```bash
   # Group errors by type
   SELECT error_type, COUNT(*) as count
   FROM search_dlq_messages
   GROUP BY error_type
   ORDER BY count DESC;
   ```

3. **Check System Health During DLQ Period**:
   - Elasticsearch cluster status
   - Database connectivity
   - Network connectivity to dependent services

**DLQ Replay Procedure**:

1. **Manual DLQ Replay**:
   ```bash
   # Use the DLQ replay script
   ./scripts/dlq-replay.sh --service=search --max-retries=3 --batch-size=10
   ```

2. **Automated DLQ Processing**:
   ```bash
   # Enable automatic DLQ replay
   kubectl set env deployment/search-service DLQ_AUTO_REPLAY=true
   kubectl set env deployment/search-service DLQ_MAX_RETRIES=5
   kubectl rollout restart deployment/search-service
   ```

3. **Monitor Replay Progress**:
   ```bash
   # Watch DLQ processing metrics
   watch -n 30 'curl -s http://search-service:9090/metrics | grep dlq'
   ```

**Root Cause Analysis**:
- Identify the root cause of message failures
- Fix underlying issues (Elasticsearch connectivity, data validation, etc.)
- Implement circuit breakers for dependent services
- Update error handling logic to prevent similar failures

### Bulk Reindexing

**Trigger Conditions**:
- Schema changes requiring full reindex
- Data quality issues affecting search results
- Elasticsearch cluster migration
- Major catalog data updates

**Preparation**:
1. **Assess Scope**:
   ```bash
   # Check current index size
   curl -X GET "localhost:9200/_cat/indices/products?v"

   # Estimate reindexing time based on document count
   ```

2. **Schedule Maintenance Window**:
   - Notify stakeholders of search degradation during reindexing
   - Schedule during low-traffic periods
   - Prepare rollback plan

3. **Backup Current Index** (optional):
   ```bash
   # Create snapshot
   curl -X PUT "localhost:9200/_snapshot/my_backup/snapshot_$(date +%Y%m%d_%H%M%S)" -H 'Content-Type: application/json' -d'
   {
     "indices": "products",
     "ignore_unavailable": true,
     "include_global_state": false
   }'
   ```

**Execution**:

1. **Trigger Bulk Reindex**:
   ```bash
   # Use the bulk reindex API
   curl -X POST "http://search-service:8080/api/v1/admin/reindex" \
     -H "Content-Type: application/json" \
     -d '{
       "index_name": "products",
       "batch_size": 1000,
       "workers": 4
     }'
   ```

2. **Monitor Reindexing Progress**:
   ```bash
   # Check reindexing status
   curl http://search-service:8080/api/v1/admin/reindex/status

   # Monitor metrics
   watch -n 60 'curl -s http://search-service:9090/metrics | grep reindex'
   ```

3. **Verify Reindexing Success**:
   ```bash
   # Compare document counts
   curl "localhost:9200/_cat/indices/products?v"

   # Test search functionality
   curl "http://search-service:8080/api/v1/search?q=test"
   ```

**Rollback Procedure** (if needed):
1. **Switch Back to Old Index**:
   ```bash
   curl -X POST "http://search-service:8080/api/v1/admin/switch-alias" \
     -H "Content-Type: application/json" \
     -d '{
       "alias": "products",
       "old_index": "products_v2",
       "new_index": "products_v1"
     }'
   ```

2. **Clean Up Failed Index**:
   ```bash
   curl -X DELETE "localhost:9200/products_v2"
   ```

### Index Latency Issues

**Detection**: Alert `SearchIndexLatencyHigh` triggers when P95 index latency > 60 seconds.

**Diagnosis**:
1. **Check Elasticsearch Performance**:
   ```bash
   # Check cluster health
   curl -X GET "localhost:9200/_cluster/health?pretty"

   # Check index performance
   curl -X GET "localhost:9200/_cat/indices/products?v&s=docs.count:desc"
   ```

2. **Analyze Slow Queries**:
   ```bash
   # Check slow query logs
   curl -X GET "localhost:9200/_cluster/settings" | jq '.transient."logger.org.elasticsearch.index.search.slowlog"'
   ```

3. **Check Resource Utilization**:
   ```bash
   # Monitor Elasticsearch JVM and system metrics
   kubectl top pods -l app=elasticsearch
   ```

**Resolution**:
1. **Optimize Index Settings**:
   ```bash
   curl -X PUT "localhost:9200/products/_settings" -H 'Content-Type: application/json' -d'
   {
     "index": {
       "refresh_interval": "10s",
       "number_of_replicas": 0
     }
   }'
   ```

2. **Scale Elasticsearch Cluster**:
   ```bash
   kubectl scale statefulset elasticsearch --replicas=5
   ```

3. **Implement Index Sharding Strategy**:
   - Review shard allocation
   - Consider index rollover strategy
   - Implement hot/warm architecture

## Monitoring & Alerting

### Key Metrics to Monitor

| Metric | Threshold | Alert |
|--------|-----------|-------|
| `search_index_latency_seconds` (P95) | > 60s | Critical |
| `search_event_processing_lag_seconds` | > 300s | Warning |
| `search_dlq_message_count` | > 100 | Critical |
| `search_elasticsearch_errors_total` | > 0.05/s | Critical |
| `search_indexing_errors_total` | > 0.1/s | Warning |

### Health Checks

**Search Service Health**:
```bash
curl http://search-service:8080/health
```

**Elasticsearch Health**:
```bash
curl -X GET "localhost:9200/_cluster/health?wait_for_status=yellow&timeout=50s"
```

**Event Processing Health**:
```bash
# Check consumer connectivity
curl http://search-service:8080/health/consumers
```

## Maintenance Procedures

### Regular Index Maintenance

**Weekly Tasks**:
1. **Optimize Indices**:
   ```bash
   curl -X POST "localhost:9200/products/_forcemerge?max_num_segments=1"
   ```

2. **Update Index Mappings** (if needed):
   ```bash
   curl -X PUT "localhost:9200/products/_mapping" -H 'Content-Type: application/json' -d @new_mapping.json
   ```

3. **Clean Up Old Indices**:
   ```bash
   # List old indices
   curl -X GET "localhost:9200/_cat/indices/*products*?v"

   # Delete indices older than 30 days
   curl -X DELETE "localhost:9200/products_$(date -d '30 days ago' +%Y%m%d)"
   ```

### Capacity Planning

**Monitor Trends**:
- Daily indexing volume
- Peak search query rates
- Index size growth
- Elasticsearch cluster utilization

**Scaling Guidelines**:
- Scale search service pods based on event processing lag
- Scale Elasticsearch data nodes based on index size and query load
- Implement index lifecycle management for cost optimization

## Troubleshooting Guide

### Common Issues

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| High indexing latency | Products not appearing in search quickly | Check ES cluster health, scale resources |
| Event processing lag | Events backing up in queue | Restart consumers, check downstream dependencies |
| DLQ accumulation | Failed events not being processed | Analyze error patterns, fix root causes, replay DLQ |
| Search result inconsistencies | Different results for same query | Check index refresh settings, force refresh |
| Elasticsearch circuit breaker | Search requests failing | Reduce batch sizes, optimize queries |

### Debug Commands

**Check Event Processing Status**:
```bash
# View recent events
kubectl logs -l app=search-service --tail=100 | grep "Processing.*event"

# Check event consumer metrics
curl http://search-service:9090/metrics | grep event
```

**Analyze Elasticsearch Performance**:
```bash
# Check slow queries
curl -X GET "localhost:9200/_cluster/settings?include_defaults" | jq '.defaults."search.slowlog"'

# Profile search queries
curl -X POST "localhost:9200/products/_search?profile=true" -H 'Content-Type: application/json' -d '{"query":{"match":{"name":"test"}}}'
```

**Database Query Analysis**:
```bash
# Check slow queries in PostgreSQL
SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;
```

## Emergency Contacts

- **Primary On-Call**: Search Team Lead
- **Secondary On-Call**: Platform Engineering
- **Elasticsearch SME**: Infrastructure Team
- **Database SME**: Data Engineering

## References

- [Search Service Documentation](../../03-services/core-services/search-service.md)
- [Elasticsearch Operations Guide](../../06-operations/infrastructure/elasticsearch-setup.md)
- [Event Processing Architecture](../../02-business-domains/content/search-discovery.md)