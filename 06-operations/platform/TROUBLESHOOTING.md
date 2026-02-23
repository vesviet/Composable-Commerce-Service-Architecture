# 🔧 Platform Troubleshooting Guide

**Purpose**: Comprehensive troubleshooting procedures for platform issues  
**Last Updated**: 2026-02-03  
**Status**: ✅ Active - Common issues and solutions documented

---

## 📋 Overview

This guide provides step-by-step troubleshooting procedures for common platform issues. It covers event processing, task orchestration, API gateway, and other platform services.

---

## 🚨 Quick Diagnosis

### **Platform Health Check**

```bash
#!/bin/bash
# platform-health-check.sh

echo "=== Platform Health Check - $(date) ==="

# Check Kubernetes cluster
echo "Checking Kubernetes cluster..."
kubectl cluster-info
kubectl get nodes

# Check critical services
echo "Checking critical services..."
kubectl get pods -n production | grep -E "(gateway|common-operations|dapr)"

# Check storage
echo "Checking storage..."
kubectl get pv,pvc --all-namespaces

# Check networking
echo "Checking networking..."
kubectl get services -n production
kubectl get ingress -n production

echo "=== Platform Health Check Complete ==="
```

### **Service Status Matrix**

| Service | Health Check | Common Issues | Quick Fix |
|---------|--------------|---------------|-----------|
| **API Gateway** | `curl http://gateway/health` | 503 errors, routing issues | Check upstream services |
| **Common Operations** | `curl http://common-ops/health` | Task failures, storage issues | Check database and storage |
| **Event Processing** | Check Dapr logs | Event delays, DLQ buildup | Process DLQ, restart consumers |
| **Dapr** | `kubectl get daprcomponents` | Component failures | Restart Dapr sidecars |

---

## 🔄 Event Processing Issues

### **Common Event Problems**

#### **Events Not Processing**

**Symptoms:**
- Events in queue but not being consumed
- Growing event backlog
- No error logs visible

**Diagnosis:**
```bash
# Check event consumer status
kubectl logs -f deployment/search-service -n production | grep "event"

# Check Dapr sidecar
kubectl logs -f deployment/search-service -n production -c daprd

# Check Redis streams
kubectl exec -it redis-pod -- redis-cli XINFO STREAMS operations.task.created

# Check consumer lag
kubectl exec -it redis-pod -- redis-cli XLEN operations.task.created
```

**Solutions:**
```bash
# Restart event consumer
kubectl rollout restart deployment/search-service -n production

# Check Dapr component configuration
kubectl get daprcomponents --all-namespaces -o yaml

# Process stuck events
kubectl exec -it redis-pod -- redis-cli XTRIM operations.task.created MAXLEN ~ 1000

# Force event processing
kubectl exec -it search-service-pod -- curl -X POST http://localhost:3500/v1.0/invoke/search-service/method/process-events
```

#### **Dead Letter Queue (DLQ) Issues**

**Symptoms:**
- Events accumulating in DLQ
- Processing failures
- Schema validation errors

**Diagnosis:**
```bash
# Check DLQ size
kubectl exec -it redis-pod -- redis-cli XLEN dlq:search-events

# Examine failed events
kubectl exec -it redis-pod -- redis-cli XREVRANGE dlq:search-events 0 -1

# Check error logs
kubectl logs deployment/search-service -n production | grep -i error | tail -20
```

**Solutions:**
```bash
# Manual DLQ processing
kubectl exec -it redis-pod -- redis-cli XREADGROUP GROUP dlq-group dlq-consumer COUNT 1 STREAMS dlq:search-events >

# Fix schema issues
# Update event schema in service
kubectl rollout restart deployment/search-service -n production

# Re-process fixed events
kubectl exec -it redis-pod -- redis-cli XADD operations.task.created * <fixed-event-data>
```

#### **Event Schema Validation Failures**

**Symptoms:**
- Schema validation errors
- Event rejection
- Type mismatch errors

**Diagnosis:**
```bash
# Check event schema
kubectl get configmap event-schemas -n production -o yaml

# Validate event manually
echo '{"type":"order.created","data":{...}}' | jq .

# Check consumer validation logic
kubectl logs deployment/search-service -n production | grep "validation"
```

**Solutions:**
```bash
# Update event schema
kubectl edit configmap event-schemas -n production

# Restart consumer with new schema
kubectl rollout restart deployment/search-service -n production

# Validate with new schema
kubectl exec -it search-service-pod -- curl -X POST http://localhost:8080/validate-event -d '{"event":{...}}'
```

---

## 🔧 Task Orchestration Issues

### **Common Task Problems**

#### **Tasks Not Starting**

**Symptoms:**
- Tasks stuck in "pending" status
- No worker processing tasks
- Queue buildup

**Diagnosis:**
```bash
# Check task service status
kubectl logs -f deployment/common-operations -n production

# Check database connectivity
kubectl exec -it common-operations-pod -- nc -zv postgres 5432

# Check task queue
curl -H "Authorization: Bearer $TOKEN" \
  https://api.company.com/api/v1/operations/tasks?status=pending

# Check worker status
kubectl get pods -l app=common-operations-worker -n production
```

**Solutions:**
```bash
# Restart task service
kubectl rollout restart deployment/common-operations -n production

# Restart workers
kubectl rollout restart deployment/common-operations-worker -n production

# Clear stuck tasks
curl -X POST -H "Authorization: Bearer $TOKEN" \
  https://api.company.com/api/v1/operations/tasks/clear-stuck

# Manual task processing
curl -X POST -H "Authorization: Bearer $TOKEN" \
  https://api.company.com/api/v1/operations/tasks/{taskId}/process
```

#### **Task Failures**

**Symptoms:**
- Tasks failing with errors
- High failure rate
- Resource exhaustion

**Diagnosis:**
```bash
# Check failed tasks
curl -H "Authorization: Bearer $TOKEN" \
  https://api.company.com/api/v1/operations/tasks?status=failed

# Check error logs
kubectl logs deployment/common-operations -n production | grep -i error

# Check resource usage
kubectl top pods -l app=common-operations -n production

# Check storage access
kubectl exec -it common-operations-pod -- mc ls common-operations/
```

**Solutions:**
```bash
# Retry failed tasks
curl -X POST -H "Authorization: Bearer $TOKEN" \
  https://api.company.com/api/v1/operations/tasks/{taskId}/retry

# Increase resources
kubectl patch deployment common-operations -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"common-operations","resources":{"limits":{"memory":"2Gi","cpu":"1000m"}}}]}}}}'

# Fix storage permissions
kubectl exec -it common-operations-pod -- mc policy set public common-operations/
```

#### **File Upload Issues**

**Symptoms:**
- File upload failures
- Storage access errors
- Permission denied

**Diagnosis:**
```bash
# Check storage service
kubectl logs -f deployment/minio -n production

# Check storage configuration
kubectl get configmap common-operations-config -n production -o yaml

# Test storage access
kubectl exec -it common-operations-pod -- mc ls common-operations/

# Check upload logs
kubectl logs deployment/common-operations -n production | grep -i upload
```

**Solutions:**
```bash
# Restart storage service
kubectl rollout restart deployment/minio -n production

# Update storage credentials
kubectl edit secret common-operations-secrets -n production

# Fix bucket permissions
kubectl exec -it minio-pod -- mc policy set public common-operations/

# Test upload manually
kubectl exec -it common-operations-pod -- curl -X POST http://localhost:8080/upload -F "file=@test.txt"
```

---

## 🌐 API Gateway Issues

### **Common Gateway Problems**

#### **503 Service Unavailable**

**Symptoms:**
- Gateway returning 503 errors
- Upstream service unreachable
- Health check failures

**Diagnosis:**
```bash
# Check gateway logs
kubectl logs -f deployment/gateway -n production

# Check upstream services
kubectl get services -n production
kubectl describe service SERVICE-NAME -n production

# Check service endpoints
kubectl get endpoints -n production

# Test direct service access
kubectl exec -it gateway-pod -- curl http://service-name:8080/health
```

**Solutions:**
```bash
# Restart upstream service
kubectl rollout restart deployment/SERVICE-NAME -n production

# Check service discovery
kubectl get pods -l app=SERVICE-NAME -n production

# Update gateway configuration
kubectl edit configmap gateway-config -n production

# Restart gateway
kubectl rollout restart deployment/gateway -n production
```

#### **Authentication Failures**

**Symptoms:**
- 401 Unauthorized errors
- JWT validation failures
- Authentication service issues

**Diagnosis:**
```bash
# Check auth service
kubectl logs -f deployment/auth-service -n production

# Check JWT configuration
kubectl get configmap gateway-config -n production -o yaml | grep -A 10 jwt

# Test authentication
curl -X POST https://api.company.com/auth/login -d '{"username":"test","password":"test"}'

# Check token validation
curl -H "Authorization: Bearer $TOKEN" https://api.company.com/protected
```

**Solutions:**
```bash
# Restart auth service
kubectl rollout restart deployment/auth-service -n production

# Update JWT configuration
kubectl edit configmap gateway-config -n production

# Refresh token signing keys
kubectl exec -it auth-service-pod -- curl -X POST http://localhost:8080/refresh-keys

# Test with new token
TOKEN=$(curl -s -X POST https://api.company.com/auth/login -d '{"username":"test","password":"test"}' | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" https://api.company.com/protected
```

#### **Rate Limiting Issues**

**Symptoms:**
- 429 Too Many Requests
- Legitimate traffic blocked
- Rate limit configuration issues

**Diagnosis:**
```bash
# Check rate limit configuration
kubectl get configmap gateway-config -n production -o yaml | grep -A 10 rate_limit

# Check current limits
curl -I https://api.company.com/api/test

# Check rate limit headers
curl -I https://api.company.com/api/test -H "X-User-ID: test-user"

# Monitor rate limiting
kubectl logs deployment/gateway -n production | grep -i "rate"
```

**Solutions:**
```bash
# Adjust rate limits
kubectl edit configmap gateway-config -n production

# Restart gateway
kubectl rollout restart deployment/gateway -n production

# Clear rate limit cache
kubectl exec -it gateway-pod -- redis-cli FLUSHDB

# Test new limits
for i in {1..150}; do curl -s https://api.company.com/api/test; done
```

---

## 🔍 Dapr Issues

### **Common Dapr Problems**

#### **Component Connection Failures**

**Symptoms:**
- Dapr component initialization failures
- Service discovery issues
- State store connection problems

**Diagnosis:**
```bash
# Check Dapr components
kubectl get daprcomponents --all-namespaces

# Check Dapr logs
kubectl logs -f deployment/SERVICE-NAME -n production -c daprd

# Check component configuration
kubectl get daprcomponent COMPONENT-NAME -n production -o yaml

# Test Dapr health
kubectl exec -it SERVICE-NAME-pod -c daprd -- curl http://localhost:3500/v1.0/healthz
```

**Solutions:**
```bash
# Restart Dapr sidecar
kubectl delete pod SERVICE-NAME-pod -n production

# Update component configuration
kubectl edit daprcomponent COMPONENT-NAME -n production

# Check component dependencies
kubectl logs -f deployment/redis -n production
kubectl logs -f deployment/postgres -n production

# Test component manually
kubectl exec -it SERVICE-NAME-pod -c daprd -- curl -X POST http://localhost:3500/v1.0/state/statestore/get -d '{"key":"test"}'
```

#### **Pub/Sub Issues**

**Symptoms:**
- Event publishing failures
- Subscription errors
- Message delivery delays

**Diagnosis:**
```bash
# Check pub/sub component
kubectl get daprcomponent pubsub -n production -o yaml

# Check Redis pub/sub
kubectl exec -it redis-pod -- redis-cli PUBSUB CHANNELS

# Test event publishing
kubectl exec -it SERVICE-NAME-pod -c daprd -- curl -X POST http://localhost:3500/v1.0/publish/pubsub/test-topic -d '{"data":"test"}'

# Check subscription status
kubectl logs deployment/SERVICE-NAME -n production | grep -i "subscription"
```

**Solutions:**
```bash
# Restart pub/sub component
kubectl delete daprcomponent pubsub -n production
kubectl apply -f dapr/pubsub.yaml

# Clear Redis pub/sub
kubectl exec -it redis-pod -- redis-cli FLUSHALL

# Test with simple event
kubectl exec -it SERVICE-NAME-pod -c daprd -- curl -X POST http://localhost:3500/v1.0/publish/pubsub/test -d '{"test": true}'

# Verify subscription
kubectl logs deployment/consumer-service -n production | grep -i "received"
```

---

## 📊 Performance Issues

### **Common Performance Problems**

#### **High Latency**

**Symptoms:**
- Slow API responses
- Increased response times
- User experience degradation

**Diagnosis:**
```bash
# Check response times
curl -w "@curl-format.txt" https://api.company.com/api/test

# Check resource usage
kubectl top pods -n production
kubectl top nodes

# Check database performance
kubectl exec -it postgres-pod -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Check network latency
kubectl exec -it pod1 -- ping pod2
```

**Solutions:**
```bash
# Scale services
kubectl scale deployment SERVICE-NAME --replicas=5 -n production

# Optimize database queries
kubectl exec -it postgres-pod -- psql -U postgres -c "EXPLAIN ANALYZE SELECT * FROM table;"

# Add resources
kubectl patch deployment SERVICE-NAME -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"SERVICE-NAME","resources":{"limits":{"memory":"2Gi","cpu":"1000m"}}}]}}}}'

# Enable caching
kubectl exec -it redis-pod -- redis-cli SET cache:key "value"
```

#### **High Memory Usage**

**Symptoms:**
- Memory exhaustion
- OOMKilled pods
- System instability

**Diagnosis:**
```bash
# Check memory usage
kubectl top pods -n production --sort-by=memory

# Check OOM events
kubectl describe pod POD-NAME -n production | grep -i oom

# Check memory leaks
kubectl exec -it POD-NAME -- ps aux

# Check garbage collection
kubectl logs deployment/SERVICE-NAME -n production | grep -i "gc"
```

**Solutions:**
```bash
# Increase memory limits
kubectl patch deployment SERVICE-NAME -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"SERVICE-NAME","resources":{"limits":{"memory":"4Gi"}}}]}}}}'

# Restart service
kubectl rollout restart deployment/SERVICE-NAME -n production

# Optimize application
kubectl exec -it SERVICE-NAME-pod -- pprof -http=:6060

# Add monitoring
kubectl exec -it SERVICE-NAME-pod -- curl http://localhost:6060/debug/pprof/heap
```

---

## 📞 Emergency Procedures

### **Platform-Wide Outage**

#### **Immediate Response**
```bash
#!/bin/bash
# emergency-platform-recovery.sh

echo "=== Emergency Platform Recovery ==="

# Scale all services to zero
kubectl scale deployment --all --replicas=0 -n production

# Check infrastructure
kubectl get nodes
kubectl get pv,pvc

# Restart critical services
kubectl scale deployment gateway --replicas=3 -n production
kubectl scale deployment auth-service --replicas=2 -n production

# Wait for critical services
kubectl wait --for=condition=available --timeout=300s deployment/gateway -n production
kubectl wait --for=condition=available --timeout=300s deployment/auth-service -n production

# Restart business services
kubectl scale deployment order-service --replicas=3 -n production
kubectl scale deployment payment-service --replicas=2 -n production
kubectl scale deployment catalog-service --replicas=3 -n production

echo "=== Emergency Recovery Complete ==="
```

#### **Verification Steps**
```bash
# Test API gateway
curl -f https://api.company.com/health

# Test authentication
TOKEN=$(curl -s -X POST https://api.company.com/auth/login -d '{"username":"test","password":"test"}' | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" https://api.company.com/api/test

# Check all services
kubectl get pods -n production

# Monitor logs
kubectl logs -f deployment/gateway -n production &
kubectl logs -f deployment/auth-service -n production &
```

---

## 📚 Related Documentation

### **Platform Documentation**
- [Platform Architecture](./PLATFORM_ARCHITECTURE.md) - Platform design
- [Event Processing Manual](./event-processing-manual.md) - Event processing details
- [Common Operations Flow](./common-operations-flow.md) - Task orchestration

### **Operational Documentation**
- [Monitoring Overview](../monitoring/README.md) - Monitoring and alerting
- [Incident Response](../incident-response/README.md) - Incident procedures
- [Security Operations](../security/README.md) - Security procedures

---

**Last Updated**: 2026-02-03  
**Review Cycle**: Monthly  
**Maintained By**: Platform Engineering Team
