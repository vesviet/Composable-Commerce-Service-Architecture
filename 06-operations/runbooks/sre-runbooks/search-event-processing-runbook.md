# 🚨 Search Service - Event Processing Runbook

**Version**: 1.0
**Last Updated**: 2026-01-21
**Severity Levels**: 🔴 Critical | 🟡 Warning | 🔵 Info

---

## 📋 Quick Reference

### Key Metrics to Check
```bash
# Event processing health
curl -s http://prometheus:9090/api/v1/query?query=up{job="search-service"} | jq '.data.result[0].value[1]'

# DLQ message counts
curl -s http://prometheus:9090/api/v1/query?query=search_dlq_message_count | jq '.data.result[] | {topic: .metric.topic, count: .value[1]}'

# Circuit breaker states
curl -s http://prometheus:9090/api/v1/query?query=search_circuit_breaker_state | jq '.data.result[] | {service: .metric.service_name, state: .value[1]}'

# Event processing rate (last 5m)
curl -s http://prometheus:9090/api/v1/query?query=rate(search_event_processing_total[5m]) | jq '.data.result[0].value[1]'
```

### Common Commands
```bash
# Check service logs
kubectl logs -f deployment/search-service --tail=50

# Check DLQ status
curl http://search-service/api/v1/admin/dlq/stats

# Restart service
kubectl rollout restart deployment/search-service

# Check Elasticsearch health
curl http://elasticsearch:9200/_cluster/health | jq '.status'
```

---

## 🔴 CRITICAL INCIDENTS

### C1: Complete Event Processing Failure

**Symptoms**:
- All event processing stopped
- DLQ messages accumulating rapidly
- Search index not updating
- Alert: "Event Processing Down"

**Immediate Actions** (2 minutes):
```bash
# 1. Check service health
kubectl get pods -l app=search-service

# 2. Check service logs for errors
kubectl logs -f deployment/search-service --tail=100 | grep -i error

# 3. Verify dependencies
kubectl get pods -l app=elasticsearch
kubectl get pods -l app=redis
```

**Diagnosis** (5 minutes):
```bash
# Check circuit breakers
curl -s http://prometheus:9090/api/v1/query?query=search_circuit_breaker_state | jq '.data.result[] | select(.value[1] == "2")'

# Check downstream services
curl http://catalog-service/health
curl http://pricing-service/health
curl http://warehouse-service/health
curl http://elasticsearch:9200/_cluster/health
```

**Recovery** (10 minutes):
```bash
# 1. Restart search service
kubectl rollout restart deployment/search-service

# 2. If restart doesn't help, check resource limits
kubectl describe pod -l app=search-service

# 3. Scale up if needed
kubectl scale deployment search-service --replicas=2

# 4. Monitor recovery
watch 'curl http://search-service/api/v1/admin/dlq/stats | jq .data.\"catalog.product.created.dlq\".count'
```

### C2: Data Corruption in Search Index

**Symptoms**:
- Search results showing incorrect data
- High validation error rates
- DLQ filling with validation errors
- Alert: "High Validation Error Rate"

**Immediate Actions** (5 minutes):
```bash
# 1. Stop event processing to prevent further corruption
kubectl scale deployment/search-service --replicas=0

# 2. Check validation error breakdown
curl -s http://prometheus:9090/api/v1/query?query=search_validation_errors_by_field_total | jq '.data.result[] | {field: .metric.field, count: .value[1]}'

# 3. Identify problematic event source
curl -s http://prometheus:9090/api/v1/query?query=search_validation_errors_total | jq '.data.result[] | {event: .metric.event_type, service: .metric.service, count: .value[1]}'
```

**Investigation** (15 minutes):
```bash
# Check recent failed events
curl http://search-service/api/v1/admin/dlq/failed-events | jq '.data[0:5][] | {topic: .topic, error: .errorMessage, data: .data}'

# Check event publisher logs
kubectl logs -f deployment/catalog-service --tail=100 | grep -i "publish\|event"

# Verify event schema compatibility
# Compare event structures between versions
```

**Recovery** (30 minutes):
```bash
# 1. Fix root cause (schema change, data validation)
# Deploy hotfix to event publisher or consumer

# 2. Reindex affected data
kubectl apply -f search-sync-job.yaml

# 3. Restart event processing
kubectl scale deployment/search-service --replicas=1

# 4. Monitor reindexing progress
kubectl logs -f job/search-sync-job
```

---

## 🟡 WARNING INCIDENTS

### W1: High DLQ Message Accumulation

**Symptoms**:
- DLQ count > threshold (10-50 depending on topic)
- Alert: "DLQ Alert: {topic}"
- Gradual performance degradation

**Diagnosis** (5 minutes):
```bash
# Check DLQ statistics
curl http://search-service/api/v1/admin/dlq/stats

# Analyze error patterns
curl http://search-service/api/v1/admin/dlq/failed-events | jq '.data[] | {topic: .topic, error: .errorMessage} | group_by(.error) | map({error: .[0].error, count: length})'

# Check recent logs for patterns
kubectl logs deployment/search-service --tail=500 | grep -i "error\|failed\|dlq" | tail -20
```

**Recovery** (15 minutes):
```bash
# 1. Identify root cause from error patterns
# - If validation errors: Fix data quality at source
# - If timeout errors: Check downstream service performance
# - If circuit breaker: Check downstream service health

# 2. Manual retry for recoverable errors
#!/bin/bash
curl -s http://search-service/api/v1/admin/dlq/failed-events | \
  jq -r '.data[] | select(.errorMessage | contains("timeout") or contains("temporary")) | .id' | \
  xargs -I {} curl -X POST "http://search-service/api/v1/admin/dlq/retry?event_id={}"

# 3. Monitor DLQ reduction
watch 'curl http://search-service/api/v1/admin/dlq/stats | jq .data'
```

### W2: Circuit Breaker Tripped

**Symptoms**:
- Circuit breaker state = "open"
- Alert: "Circuit Breaker Open - {service}"
- Service calls failing fast

**Diagnosis** (3 minutes):
```bash
# Check circuit breaker details
curl -s http://prometheus:9090/api/v1/query?query=search_circuit_breaker_state{service_name="catalog"} | jq '.data.result[0]'

# Check downstream service health
curl http://catalog-service/health

# Check network connectivity
kubectl exec -it deployment/search-service -- curl -f http://catalog-service:80/health
```

**Recovery** (5 minutes):
```bash
# 1. Verify downstream service is healthy
kubectl get pods -l app=catalog-service

# 2. Check resource utilization
kubectl top pods -l app=catalog-service

# 3. If service is down, restart it
kubectl rollout restart deployment/catalog-service

# 4. Circuit breaker will auto-recover after timeout (120s)
# Monitor recovery progress
watch 'curl -s http://prometheus:9090/api/v1/query?query=search_circuit_breaker_state{service_name="catalog"} | jq .data.result[0].value[1]'
```

### W3: Event Processing Latency Spike

**Symptoms**:
- Event processing duration > 30s
- Alert: "Event Processing Latency High"
- Events backing up in queue

**Diagnosis** (5 minutes):
```bash
# Check processing latency percentiles
curl -s http://prometheus:9090/api/v1/query?query=histogram_quantile(0.95, rate(search_event_processing_duration_seconds_bucket[5m]))) | jq '.data.result[0].value[1]'

# Check Elasticsearch performance
curl http://elasticsearch:9200/_cluster/health
curl http://elasticsearch:9200/_cat/indices?v

# Check search service resources
kubectl top pods -l app=search-service
```

**Recovery** (10 minutes):
```bash
# 1. Check Elasticsearch cluster status
curl http://elasticsearch:9200/_cluster/allocation/explain | jq '.explanations[0].explanation'

# 2. Scale up search service if needed
kubectl scale deployment/search-service --replicas=2

# 3. Check for hot threads in Elasticsearch
curl http://elasticsearch:9200/_nodes/hot_threads

# 4. Force merge indices if fragmented
curl -X POST http://elasticsearch:9200/_forcemerge?max_num_segments=1
```

---

## 🔵 INFO INCIDENTS

### I1: Event Processing Degraded

**Symptoms**:
- Event processing rate slightly down
- Occasional timeouts
- No immediate impact on users

**Monitoring** (5 minutes):
```bash
# Check processing rates
curl -s http://prometheus:9090/api/v1/query?query=rate(search_event_processing_total[5m]) | jq '.data.result[] | {event: .metric.event_type, rate: .value[1]}'

# Check error rates
curl -s http://prometheus:9090/api/v1/query?query=rate(search_event_processing_errors_total[5m]) | jq '.data.result[] | {event: .metric.event_type, error_rate: .value[1]}'

# Check resource utilization trends
kubectl top pods -l app=search-service --containers
```

**Action** (Optional):
- Monitor for 15 minutes to see if it self-corrects
- Check for pattern (time-based, load-based)
- Consider proactive scaling if trend continues

### I2: DLQ Messages Detected

**Symptoms**:
- Small number of DLQ messages (< threshold)
- No immediate alerts
- Normal operation continues

**Investigation** (5 minutes):
```bash
# Check DLQ message details
curl http://search-service/api/v1/admin/dlq/failed-events | jq '.data[] | {topic: .topic, error: .errorMessage, time: .createdAt}'

# Check if it's a one-off or pattern
curl -s http://prometheus:9090/api/v1/query?query=increase(search_dlq_message_count[1h]) | jq '.data.result[] | select(.value[1] > 0)'
```

**Action**:
- Log for investigation during next maintenance window
- Monitor for increasing trend
- Consider manual cleanup if messages are old/stale

---

## 🔧 MAINTENANCE PROCEDURES

### Daily Checks

```bash
#!/bin/bash
# Daily health check script

echo "=== Search Service Daily Check ==="

# 1. Service health
echo "Service Status:"
kubectl get pods -l app=search-service -o wide

# 2. DLQ Status
echo "DLQ Counts:"
curl -s http://search-service/api/v1/admin/dlq/stats | jq '.data | to_entries[] | select(.value.count > 0) | "\(.key): \(.value.count)"'

# 3. Circuit Breaker Status
echo "Circuit Breakers:"
curl -s http://prometheus:9090/api/v1/query?query=search_circuit_breaker_state | jq '.data.result[] | select(.value[1] != "0") | "\(.metric.service_name): \(.value[1])"'

# 4. Event Processing Rates
echo "Processing Rates (events/min):"
curl -s http://prometheus:9090/api/v1/query?query=rate(search_event_processing_total[5m])*60 | jq '.data.result[] | "\(.metric.event_type): \(.value[1])"'

echo "=== Check Complete ==="
```

### Weekly Maintenance

1. **Review Failed Events**
   ```bash
   # Export failed events for analysis
   curl http://search-service/api/v1/admin/dlq/failed-events > weekly_failed_events_$(date +%Y%m%d).json

   # Analyze error patterns
   jq '.data[] | {topic: .topic, error: .errorMessage} | group_by(.error) | map({error: .[0].error, count: length})' weekly_failed_events_$(date +%Y%m%d).json
   ```

2. **Clean Old Alert History**
   ```bash
   # Alert history is cleaned automatically, but verify
   curl -s http://prometheus:9090/api/v1/query?query=count(search_dlq_message_count) | jq '.data.result[0].value[1]'
   ```

3. **Performance Tuning Review**
   ```bash
   # Check 95th percentile latencies
   curl -s http://prometheus:9090/api/v1/query?query=histogram_quantile(0.95, rate(search_event_processing_duration_seconds_bucket[1w])) | jq '.data.result[0].value[1]'
   ```

### Monthly Maintenance

1. **Capacity Planning Review**
   - Analyze peak event processing rates
   - Review resource utilization patterns
   - Plan scaling requirements

2. **Error Trend Analysis**
   ```bash
   # Monthly error trend
   curl -s http://prometheus:9090/api/v1/query?query=increase(search_event_processing_errors_total[30d]) | jq '.data.result[] | {event: .metric.event_type, errors: .value[1]}'
   ```

3. **DLQ Backlog Assessment**
   - Review long-term DLQ trends
   - Identify systemic issues
   - Implement preventive measures

---

## 📞 ESCALATION MATRIX

### Severity Levels
- **🔴 Critical**: Complete service outage, data loss risk
- **🟡 Warning**: Degraded performance, requires attention
- **🔵 Info**: Minor issues, monitor and log

### Escalation Timeline
- **Immediate (0-5 min)**: Critical issues, SRE on-call
- **15 minutes**: Warning issues, platform engineering
- **1 hour**: Info issues, regular business hours
- **4 hours**: Non-urgent issues, next business day

### Contact Information
- **Primary SRE**: sre-oncall@company.com / +1-555-SRE-ONCALL
- **Platform Engineering**: platform-eng@company.com
- **Development Team**: search-team@company.com
- **Management**: tech-lead@company.com

### External Resources
- **Monitoring Dashboard**: https://grafana.company.com/d/search-events
- **Runbook Repository**: https://wiki.company.com/runbooks/search-service
- **Incident Tracker**: https://jira.company.com/projects/INC

---

## 📊 PERFORMANCE BASELINES

### Normal Operating Parameters

| Metric | Normal Range | Warning Threshold | Critical Threshold |
|--------|--------------|-------------------|-------------------|
| Event Processing Latency (p95) | < 5s | 10s | 30s |
| DLQ Message Count | 0 | 10-50 (by topic) | 100+ |
| Circuit Breaker State | Closed | Half-Open | Open |
| Validation Error Rate | < 1% | 5% | 10% |
| Event Processing Success Rate | > 99% | 95% | 90% |

### Scaling Triggers

| Condition | Action |
|-----------|--------|
| Event queue depth > 1000 | Scale search service +1 |
| Processing latency > 15s for 5min | Scale search service +1 |
| CPU utilization > 80% | Scale search service +1 |
| Memory utilization > 85% | Scale search service +1 |

### Auto-scaling Configuration
```yaml
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: search-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: search-service
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

**Last Reviewed**: 2026-01-21
**Next Review**: 2026-04-21
**Document Owner**: Platform Engineering Team