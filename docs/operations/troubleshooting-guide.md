# Troubleshooting & Operations Guide

## Common Issues & Solutions

### Service Connectivity Issues

#### Symptom: Service Unavailable (503 Error)
```yaml
diagnosis_steps:
  1. Check service health endpoints
  2. Verify service discovery registration
  3. Check load balancer configuration
  4. Verify network connectivity
  5. Check resource constraints (CPU/Memory)

solutions:
  - restart_unhealthy_pods: "kubectl rollout restart deployment/service-name"
  - scale_up_replicas: "kubectl scale deployment/service-name --replicas=5"
  - check_resource_limits: "kubectl describe pod pod-name"
  - verify_network_policies: "kubectl get networkpolicies"
```

#### Symptom: High Response Times
```bash
# Check service metrics
kubectl top pods -n service-namespace

# Check service logs for slow queries
kubectl logs -f deployment/service-name | grep "slow"

# Check database performance
kubectl exec -it postgres-pod -- psql -c "
  SELECT query, mean_time, calls 
  FROM pg_stat_statements 
  ORDER BY mean_time DESC 
  LIMIT 10;"
```

### Database Issues

#### Connection Pool Exhaustion
```sql
-- Check active connections
SELECT 
  state,
  count(*) 
FROM pg_stat_activity 
GROUP BY state;

-- Kill long-running queries
SELECT 
  pid,
  now() - pg_stat_activity.query_start AS duration,
  query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';

-- Kill specific connection
SELECT pg_terminate_backend(pid);
```

#### Slow Query Performance
```sql
-- Enable slow query logging
ALTER SYSTEM SET log_min_duration_statement = 1000; -- 1 second
SELECT pg_reload_conf();

-- Analyze query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM orders 
WHERE customer_id = 'CUST-123' 
ORDER BY created_at DESC;

-- Check missing indexes
SELECT 
  schemaname,
  tablename,
  attname,
  n_distinct,
  correlation 
FROM pg_stats 
WHERE schemaname = 'public' 
  AND n_distinct > 100;
```

### Cache Issues

#### Redis Memory Issues
```bash
# Check Redis memory usage
redis-cli info memory

# Check key distribution
redis-cli --bigkeys

# Clear specific pattern
redis-cli --scan --pattern "cache:product:*" | xargs redis-cli del

# Monitor Redis performance
redis-cli monitor
```

#### Cache Miss Issues
```javascript
// Cache debugging utility
class CacheDebugger {
  async analyzeCachePerformance(pattern) {
    const keys = await redis.keys(pattern);
    const stats = {
      totalKeys: keys.length,
      hitRate: 0,
      avgTtl: 0,
      keysByTtl: {}
    };
    
    for (const key of keys) {
      const ttl = await redis.ttl(key);
      stats.keysByTtl[ttl] = (stats.keysByTtl[ttl] || 0) + 1;
      stats.avgTtl += ttl;
    }
    
    stats.avgTtl = stats.avgTtl / keys.length;
    return stats;
  }
}
```

### Event Bus Issues

#### Message Processing Delays
```bash
# Check Kafka consumer lag
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group order-processing-group

# Check topic partition distribution
kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --topic order-events

# Reset consumer group offset (if needed)
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group order-processing-group --reset-offsets \
  --to-latest --topic order-events --execute
```

#### Dead Letter Queue Processing
```javascript
// Dead letter queue handler
class DeadLetterQueueHandler {
  async processFailedMessages() {
    const dlqMessages = await this.getDLQMessages();
    
    for (const message of dlqMessages) {
      try {
        // Attempt to reprocess
        await this.reprocessMessage(message);
        await this.removeDLQMessage(message.id);
      } catch (error) {
        // Log for manual investigation
        logger.error('DLQ reprocessing failed', {
          messageId: message.id,
          error: error.message,
          attempts: message.attempts
        });
        
        if (message.attempts > 3) {
          await this.moveToManualReview(message);
        }
      }
    }
  }
}
```

## Monitoring & Alerting

### Health Check Endpoints
```javascript
// Comprehensive health check
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    checks: {}
  };
  
  try {
    // Database connectivity
    await db.query('SELECT 1');
    health.checks.database = 'healthy';
  } catch (error) {
    health.checks.database = 'unhealthy';
    health.status = 'unhealthy';
  }
  
  try {
    // Redis connectivity
    await redis.ping();
    health.checks.cache = 'healthy';
  } catch (error) {
    health.checks.cache = 'unhealthy';
    health.status = 'degraded';
  }
  
  try {
    // External service connectivity
    await axios.get('http://external-service/health', { timeout: 5000 });
    health.checks.external_service = 'healthy';
  } catch (error) {
    health.checks.external_service = 'unhealthy';
    health.status = 'degraded';
  }
  
  const statusCode = health.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(health);
});
```

### Custom Metrics Collection
```javascript
// Business metrics collector
class MetricsCollector {
  constructor() {
    this.orderCounter = new prometheus.Counter({
      name: 'orders_total',
      help: 'Total number of orders',
      labelNames: ['status', 'payment_method']
    });
    
    this.orderValue = new prometheus.Histogram({
      name: 'order_value_dollars',
      help: 'Order value distribution',
      buckets: [10, 50, 100, 500, 1000, 5000]
    });
  }
  
  recordOrder(order) {
    this.orderCounter.inc({
      status: order.status,
      payment_method: order.paymentMethod
    });
    
    this.orderValue.observe(order.totalAmount);
  }
}
```

## Incident Response Procedures

### Incident Classification
```yaml
incident_levels:
  P0_critical:
    description: "Complete service outage"
    response_time: "15 minutes"
    escalation: "immediate"
    examples:
      - "Payment processing down"
      - "Complete site outage"
      - "Data breach"
      
  P1_high:
    description: "Major functionality impaired"
    response_time: "1 hour"
    escalation: "30 minutes"
    examples:
      - "Search not working"
      - "Order creation failing"
      - "High error rates"
      
  P2_medium:
    description: "Minor functionality impaired"
    response_time: "4 hours"
    escalation: "2 hours"
    examples:
      - "Slow response times"
      - "Non-critical feature down"
      
  P3_low:
    description: "Cosmetic or minor issues"
    response_time: "24 hours"
    escalation: "next business day"
```

### Incident Response Playbook
```yaml
incident_response_steps:
  1_acknowledge:
    - acknowledge_alert: "within 5 minutes"
    - create_incident_ticket: "in incident management system"
    - notify_stakeholders: "via Slack/email"
    
  2_assess:
    - determine_scope: "affected services and users"
    - classify_severity: "P0, P1, P2, or P3"
    - estimate_impact: "business and technical impact"
    
  3_mitigate:
    - implement_workaround: "if available"
    - scale_resources: "if resource-related"
    - rollback_changes: "if deployment-related"
    
  4_resolve:
    - identify_root_cause: "through investigation"
    - implement_fix: "permanent solution"
    - verify_resolution: "confirm fix works"
    
  5_communicate:
    - update_stakeholders: "regular status updates"
    - post_mortem: "within 48 hours"
    - action_items: "prevent recurrence"
```

## Performance Troubleshooting

### CPU Performance Issues
```bash
# Check CPU usage by process
kubectl top pods --sort-by=cpu

# Get detailed CPU metrics
kubectl exec -it pod-name -- top -p 1

# Check CPU throttling
kubectl describe pod pod-name | grep -i throttl

# Analyze CPU usage patterns
kubectl exec -it pod-name -- cat /proc/stat
```

### Memory Issues
```bash
# Check memory usage
kubectl top pods --sort-by=memory

# Check for memory leaks
kubectl exec -it pod-name -- cat /proc/meminfo

# Analyze heap dump (Java applications)
kubectl exec -it java-pod -- jcmd 1 GC.run_finalization
kubectl exec -it java-pod -- jcmd 1 VM.classloader_stats
```

### Network Issues
```bash
# Check network connectivity
kubectl exec -it pod-name -- nslookup service-name

# Test service connectivity
kubectl exec -it pod-name -- curl -v http://service-name:8080/health

# Check network policies
kubectl get networkpolicies -o yaml

# Analyze network traffic
kubectl exec -it pod-name -- netstat -tulpn
```

## Data Consistency Issues

### Database Synchronization
```sql
-- Check replication lag
SELECT 
  client_addr,
  state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication;

-- Verify data consistency between replicas
SELECT 
  schemaname,
  tablename,
  n_tup_ins,
  n_tup_upd,
  n_tup_del
FROM pg_stat_user_tables
ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC;
```

### Event Sourcing Issues
```javascript
// Event consistency checker
class EventConsistencyChecker {
  async checkEventSequence(aggregateId) {
    const events = await this.getEvents(aggregateId);
    const expectedSequence = events.map((e, i) => i + 1);
    const actualSequence = events.map(e => e.sequenceNumber);
    
    const missingEvents = expectedSequence.filter(
      seq => !actualSequence.includes(seq)
    );
    
    if (missingEvents.length > 0) {
      logger.error('Missing events detected', {
        aggregateId,
        missingEvents
      });
      
      return { consistent: false, missingEvents };
    }
    
    return { consistent: true };
  }
  
  async repairEventSequence(aggregateId, missingEvents) {
    // Attempt to recover missing events from backup
    for (const sequenceNumber of missingEvents) {
      const backupEvent = await this.getEventFromBackup(
        aggregateId, 
        sequenceNumber
      );
      
      if (backupEvent) {
        await this.insertEvent(backupEvent);
      }
    }
  }
}
```

## Backup & Recovery

### Database Backup Verification
```bash
# Test backup restoration
pg_restore --verbose --clean --no-acl --no-owner \
  -h localhost -U postgres -d test_restore backup.dump

# Verify backup integrity
pg_dump --schema-only original_db > original_schema.sql
pg_dump --schema-only restored_db > restored_schema.sql
diff original_schema.sql restored_schema.sql
```

### Service Recovery Procedures
```yaml
recovery_procedures:
  database_failure:
    1. Switch to read replica
    2. Promote replica to master
    3. Update service configurations
    4. Verify data consistency
    5. Resume write operations
    
  service_failure:
    1. Check service health
    2. Restart unhealthy instances
    3. Scale up if needed
    4. Verify functionality
    5. Monitor for stability
    
  complete_outage:
    1. Activate disaster recovery site
    2. Restore from backups
    3. Update DNS/load balancers
    4. Verify all services
    5. Communicate to users
```

## Maintenance Procedures

### Planned Maintenance
```yaml
maintenance_checklist:
  pre_maintenance:
    - notify_stakeholders: "24 hours in advance"
    - create_maintenance_window: "in monitoring system"
    - prepare_rollback_plan: "document steps"
    - backup_critical_data: "before changes"
    
  during_maintenance:
    - monitor_system_health: "continuously"
    - follow_change_procedures: "step by step"
    - document_issues: "as they occur"
    - communicate_progress: "regular updates"
    
  post_maintenance:
    - verify_functionality: "end-to-end testing"
    - monitor_for_issues: "extended monitoring"
    - update_documentation: "reflect changes"
    - conduct_retrospective: "lessons learned"
```

### Emergency Procedures
```bash
#!/bin/bash
# Emergency rollback script

echo "Starting emergency rollback..."

# Rollback deployment
kubectl rollout undo deployment/order-service -n production

# Wait for rollback to complete
kubectl rollout status deployment/order-service -n production

# Verify service health
kubectl get pods -n production -l app=order-service

# Check service endpoints
curl -f http://order-service/health || echo "Health check failed"

# Notify team
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Emergency rollback completed for order-service"}' \
  $SLACK_WEBHOOK_URL

echo "Emergency rollback completed"
```