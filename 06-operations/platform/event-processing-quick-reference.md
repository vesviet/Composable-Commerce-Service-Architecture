# 🚀 Event Processing Quick Reference

**Search Service Event Processing Operations**

---

## 📊 Monitoring Commands

### Health Checks
```bash
# Service health
curl http://search-service/health

# DLQ statistics
curl http://search-service/api/v1/admin/dlq/stats

# Circuit breaker status
curl -s http://prometheus:9090/api/v1/query?query=search_circuit_breaker_state | jq '.data.result[] | "\(.metric.service_name): \(.value[1])"'

# Event processing rates (per minute)
curl -s http://prometheus:9090/api/v1/query?query=rate(search_event_processing_total[5m])*60 | jq '.data.result[] | "\(.metric.event_type): \(.value[1])"'
```

### Key Metrics
```bash
# DLQ message counts by topic
curl -s http://prometheus:9090/api/v1/query?query=search_dlq_message_count | jq '.data.result[] | {topic: .metric.topic, count: .value[1]}'

# Validation errors by type
curl -s http://prometheus:9090/api/v1/query?query=increase(search_validation_errors_total[1h]) | jq '.data.result[] | "\(.metric.event_type)@\(.metric.service): \(.value[1])"'

# Processing latency (95th percentile)
curl -s http://prometheus:9090/api/v1/query?query=histogram_quantile(0.95, rate(search_event_processing_duration_seconds_bucket[5m])) | jq '.data.result[0].value[1]'
```

---

## 🔧 Operational Commands

### Service Management
```bash
# Restart search service
kubectl rollout restart deployment/search-service

# Scale search service
kubectl scale deployment/search-service --replicas=2

# Check pod status
kubectl get pods -l app=search-service -o wide

# View service logs
kubectl logs -f deployment/search-service --tail=100
```

### DLQ Operations
```bash
# List failed events
curl http://search-service/api/v1/admin/dlq/failed-events | jq '.data[] | {id: .id, topic: .topic, error: .errorMessage}'

# Retry specific failed event
curl -X POST "http://search-service/api/v1/admin/dlq/retry?event_id=failed-event-123"

# Bulk retry recoverable errors
#!/bin/bash
curl -s http://search-service/api/v1/admin/dlq/failed-events | \
  jq -r '.data[] | select(.errorMessage | contains("timeout")) | .id' | \
  xargs -I {} curl -X POST "http://search-service/api/v1/admin/dlq/retry?event_id={}"
```

### Circuit Breaker Operations
```bash
# Check circuit breaker states
curl -s http://prometheus:9090/api/v1/query?query=search_circuit_breaker_state | jq '.data.result[] | select(.value[1] != "0") | "\(.metric.service_name): state=\(.value[1])"'

# Force circuit breaker reset (restart service)
kubectl rollout restart deployment/search-service
```

---

## 🚨 Alert Response Quick Reference

### 🔴 CRITICAL: Event Processing Completely Down
1. **Check service status**: `kubectl get pods -l app=search-service`
2. **Check dependencies**: Elasticsearch, Redis, downstream services
3. **Restart service**: `kubectl rollout restart deployment/search-service`
4. **Monitor recovery**: Watch DLQ stats and event processing metrics

### 🟡 WARNING: High DLQ Count
1. **Check DLQ stats**: `curl http://search-service/api/v1/admin/dlq/stats`
2. **Analyze error patterns**: Check failed events for common issues
3. **Identify root cause**: Validation errors → fix at source; timeouts → check downstream
4. **Manual recovery**: Retry recoverable events, fix data quality issues

### 🟡 WARNING: Circuit Breaker Open
1. **Identify affected service**: Check circuit breaker metrics
2. **Check downstream health**: `curl http://downstream-service/health`
3. **Resolve downstream issues**: Restart, scale, or fix the downstream service
4. **Monitor auto-recovery**: Circuit breaker recovers after 120s timeout

### 🟡 WARNING: High Validation Errors
1. **Check validation breakdown**: `curl -s http://prometheus:9090/api/v1/query?query=search_validation_errors_by_field_total`
2. **Identify problematic field**: Most failing validation field
3. **Check event source**: Publisher may have changed schema or data quality issues
4. **Fix at source**: Update validation rules or correct data

---

## 🔍 Debugging Commands

### Event Flow Debugging
```bash
# Check Dapr subscription status
kubectl get subscriptions -o yaml

# Check Dapr logs for event routing
kubectl logs -f deployment/search-service -c daprd | grep -i "event\|subscription"

# Check Redis pubsub for event delivery
kubectl exec -it deployment/redis -- redis-cli monitor | grep -i "publish\|subscribe"
```

### Performance Debugging
```bash
# Check Elasticsearch indexing performance
curl http://elasticsearch:9200/_cat/indices?v
curl http://elasticsearch:9200/_cluster/health

# Check search service resource usage
kubectl top pods -l app=search-service

# Check network latency to downstream services
kubectl exec -it deployment/search-service -- ping catalog-service
```

### Error Pattern Analysis
```bash
# Most common validation errors
curl -s http://prometheus:9090/api/v1/query?query=topk(5, increase(search_validation_errors_by_type_total[1h])) | jq '.data.result[] | "\(.metric.error_type): \(.value[1])"'

# Events with highest failure rates
curl -s http://prometheus:9090/api/v1/query?query=rate(search_event_processing_errors_total[1h]) / rate(search_event_processing_total[1h]) | jq '.data.result[] | select(.value[1] > 0.1) | "\(.metric.event_type): \(.value[1]*100)%"'

# DLQ growth rate
curl -s http://prometheus:9090/api/v1/query?query=rate(search_dlq_message_count[1h]) | jq '.data.result[] | select(.value[1] > 0) | "\(.metric.topic): +\(.value[1])/hour"'
```

---

## 📋 Event Type Reference

| Event Type | Consumer | DLQ Topic | Validation Rules | Retry Policy |
|------------|----------|-----------|------------------|--------------|
| `catalog.product.*` | ProductConsumer | `catalog.product.*.dlq` | ID, SKU, name required | 3 retries |
| `pricing.price.*` | PriceConsumer | `pricing.price.*.dlq` | ProductID, currency required | 2 retries |
| `warehouse.inventory.stock_changed` | StockConsumer | `warehouse.inventory.stock_changed.dlq` | SKU, warehouse_id required | 5 retries |
| `catalog.cms.page.*` | CMSConsumer | `catalog.cms.page.*.dlq` | PageID, title, slug required | 2 retries |

---

## 🎯 Configuration Reference

### Event Processing Config
```yaml
# search service config.yaml
event_processing:
  max_concurrent_events: 10
  timeout_seconds: 30
  retry_backoff_base: 5
  max_retries: 3
```

### Circuit Breaker Config
```yaml
circuit_breaker:
  failure_threshold: 5      # consecutive failures to trip
  recovery_timeout: 120     # seconds to wait before recovery
  max_requests_half_open: 5 # requests allowed in half-open state
```

### DLQ Monitoring Config
```yaml
dlq_monitoring:
  check_interval: 5m        # how often to check DLQ counts
  alert_cooldown: 10m       # minimum time between alerts
  thresholds:
    catalog.product.*: 10
    warehouse.inventory.*: 50
    catalog.cms.*: 5
```

---

## 🚀 Recovery Scripts

### Emergency DLQ Flush (Use with caution!)
```bash
#!/bin/bash
# Flush all DLQ topics - EMERGENCY ONLY
echo "⚠️  WARNING: This will delete all failed events!"
read -p "Are you sure? (type 'yes' to continue): " confirm
if [ "$confirm" != "yes" ]; then exit 1; fi

# Stop event processing
kubectl scale deployment/search-service --replicas=0

# Clear DLQ topics (requires Redis access)
kubectl exec -it deployment/redis -- redis-cli KEYS "dapr-*dlq*" | xargs redis-cli DEL

# Restart event processing
kubectl scale deployment/search-service --replicas=1
```

### Bulk Event Retry
```bash
#!/bin/bash
# Retry all events matching a pattern
PATTERN="timeout"  # Change to match your error pattern

curl -s http://search-service/api/v1/admin/dlq/failed-events | \
  jq -r ".data[] | select(.errorMessage | contains(\"$PATTERN\")) | .id" | \
  while read event_id; do
    echo "Retrying event: $event_id"
    curl -X POST "http://search-service/api/v1/admin/dlq/retry?event_id=$event_id"
    sleep 0.1  # Rate limiting
  done
```

### Health Check Script
```bash
#!/bin/bash
# Comprehensive health check

echo "=== Search Service Health Check ==="
echo "Timestamp: $(date)"

# Service status
echo -e "\n1. Service Status:"
kubectl get pods -l app=search-service -o jsonpath='{.items[*].status.phase}' | tr ' ' '\n' | sort | uniq -c

# DLQ status
echo -e "\n2. DLQ Status:"
curl -s http://search-service/api/v1/admin/dlq/stats | jq '.data | to_entries[] | select(.value.count > 0) | "\(.key): \(.value.count)"' 2>/dev/null || echo "Failed to get DLQ stats"

# Circuit breakers
echo -e "\n3. Circuit Breakers:"
curl -s http://prometheus:9090/api/v1/query?query=search_circuit_breaker_state | jq '.data.result[] | select(.value[1] != "0") | "\(.metric.service_name): state=\(.value[1])"' 2>/dev/null || echo "Failed to get circuit breaker status"

# Event processing rate
echo -e "\n4. Event Processing Rate (events/min):"
curl -s http://prometheus:9090/api/v1/query?query=rate(search_event_processing_total[5m])*60 | jq '.data.result[0].value[1]' 2>/dev/null || echo "Failed to get processing rate"

echo -e "\n=== Check Complete ==="
```

---

## 📞 Emergency Contacts

| Role | Contact | Escalation Time |
|------|---------|-----------------|
| **SRE On-call** | sre-oncall@company.com | Immediate (🔴) |
| **Platform Engineering** | platform-eng@company.com | 15 min (🟡) |
| **Search Team** | search-team@company.com | 1 hour (🔵) |
| **Tech Lead** | tech-lead@company.com | 4 hours |

**Incident Response Process**:
1. **Assess severity** using symptoms above
2. **Follow runbook** for specific incident type
3. **Escalate** if unable to resolve within timeline
4. **Document** root cause and resolution

---

**Quick Reference Version**: 1.0
**Full Manual**: [Event Processing Manual](event-processing-manual.md)
**Runbook**: [SRE Runbook](sre-runbooks/search-event-processing-runbook.md)