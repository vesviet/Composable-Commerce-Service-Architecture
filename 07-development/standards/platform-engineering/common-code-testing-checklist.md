# Common Code Testing Checklist

## 📋 Daily Testing Checklist - Common Code Validation

**Ngày:** ___________  
**Reviewer:** ___________  
**Service:** ___________  
**Phase:** ___________  
**Status:** 🔄 Testing / ✅ Passed / ❌ Failed

---

## 🎯 OVERVIEW

This checklist ensures thorough testing of each service after migrating to common code implementations. Use this checklist to validate that all functionality works correctly and no regressions are introduced.

---

## 🏥 PHASE 1: HEALTH CHECK TESTING

### Unit Testing
- [ ] **Health check endpoints respond correctly**
  ```bash
  curl -s http://localhost:8080/health | jq '.'
  # Expected: {"status": "healthy", "timestamp": "...", ...}
  ```

- [ ] **Readiness endpoint works**
  ```bash
  curl -s http://localhost:8080/health/ready | jq '.'
  # Expected: {"ready": true, "timestamp": "...", ...}
  ```

- [ ] **Liveness endpoint works**
  ```bash
  curl -s http://localhost:8080/health/live | jq '.'
  # Expected: {"alive": true, "timestamp": "...", ...}
  ```

- [ ] **Detailed endpoint provides comprehensive info**
  ```bash
  curl -s http://localhost:8080/health/detailed | jq '.'
  # Expected: Detailed health information with all checks
  ```

### Dependency Testing
- [ ] **Database health check**
  ```bash
  # Stop database
  docker stop postgres-container
  
  # Check health (should be unhealthy)
  curl -s http://localhost:8080/health | jq '.status'
  # Expected: "unhealthy"
  
  # Start database
  docker start postgres-container
  
  # Wait and check health (should recover)
  sleep 5
  curl -s http://localhost:8080/health | jq '.status'
  # Expected: "healthy"
  ```

- [ ] **Redis health check**
  ```bash
  # Stop Redis
  docker stop redis-container
  
  # Check health (Redis should be unhealthy, but service may still be healthy)
  curl -s http://localhost:8080/health/detailed | jq '.checks.redis'
  # Expected: {"status": "unhealthy", ...}
  
  # Start Redis
  docker start redis-container
  
  # Check recovery
  sleep 3
  curl -s http://localhost:8080/health/detailed | jq '.checks.redis'
  # Expected: {"status": "healthy", ...}
  ```

- [ ] **External service health checks**
  ```bash
  # Test each external service health check
  curl -s http://localhost:8080/health/detailed | jq '.checks'
  # Verify all configured services are checked
  ```

### Performance Testing
- [ ] **Health check response time**
  ```bash
  # Test response time (should be < 1 second)
  time curl -s http://localhost:8080/health > /dev/null
  # Expected: real time < 1s
  ```

- [ ] **Concurrent health checks**
  ```bash
  # Test multiple concurrent requests
  for i in {1..10}; do
    curl -s http://localhost:8080/health &
  done
  wait
  # All should succeed without errors
  ```

- [ ] **Health check caching**
  ```bash
  # First request (should hit services)
  time curl -s http://localhost:8080/health > /dev/null
  
  # Second request (should use cache)
  time curl -s http://localhost:8080/health > /dev/null
  # Second request should be faster
  ```

### Kubernetes Testing
- [ ] **Kubernetes readiness probe**
  ```bash
  kubectl get pods -n support-services -l app.kubernetes.io/name={service}
  # Pod should be Ready
  ```

- [ ] **Kubernetes liveness probe**
  ```bash
  kubectl describe pod {pod-name} -n support-services
  # Check Events section for probe failures
  ```

- [ ] **Pod restart behavior**
  ```bash
  # Kill pod and verify it restarts healthy
  kubectl delete pod {pod-name} -n support-services
  kubectl get pods -n support-services -w
  # New pod should become Ready
  ```

---

## 🗄️ PHASE 2: DATABASE CONNECTION TESTING

### Connection Testing
- [ ] **Database connection established**
  ```bash
  # Check service logs for connection message
  kubectl logs deployment/{service} -n support-services | grep "Database connected"
  # Expected: "✅ Database connected (max_open=100, max_idle=20)"
  ```

- [ ] **Redis connection established**
  ```bash
  # Check service logs for Redis connection
  kubectl logs deployment/{service} -n support-services | grep "Redis connected"
  # Expected: "✅ Redis connected (addr=..., db=0, pool_size=10)"
  ```

- [ ] **Environment variable override works**
  ```bash
  # Test DATABASE_URL override
  DATABASE_URL="postgres://test:test@localhost:5432/test" ./bin/{service} -conf ./configs
  # Check logs for override message
  ```

### Connection Pool Testing
- [ ] **Connection pool limits respected**
  ```bash
  # Monitor connection count under load
  # Use database monitoring tools to verify max connections
  ```

- [ ] **Connection recovery after database restart**
  ```bash
  # Restart database
  kubectl rollout restart deployment/postgres -n infrastructure
  
  # Verify service recovers
  sleep 30
  curl http://localhost:8080/health
  # Should be healthy after recovery
  ```

- [ ] **Connection timeout handling**
  ```bash
  # Simulate slow database
  # Verify service handles timeouts gracefully
  ```

### Data Operations Testing
- [ ] **CRUD operations work**
  ```bash
  # Test basic database operations through service API
  # Create, Read, Update, Delete operations
  ```

- [ ] **Transactions work**
  ```bash
  # Test database transactions
  # Verify rollback behavior on errors
  ```

- [ ] **Migration compatibility**
  ```bash
  # Verify database migrations still work
  # Check schema compatibility
  ```

---

## ⚙️ PHASE 3: CONFIGURATION TESTING

### Configuration Loading
- [ ] **Configuration loads from file**
  ```bash
  # Start service with config file
  ./bin/{service} -conf ./configs
  # Check logs for successful config loading
  ```

- [ ] **Environment variables override config**
  ```bash
  # Test various environment variable overrides
  {SERVICE}_SERVER_HTTP_ADDR=":8081" ./bin/{service} -conf ./configs
  # Verify service starts on port 8081
  ```

- [ ] **Service-specific configuration preserved**
  ```bash
  # Verify all service-specific config fields work
  # Check business logic configuration
  ```

### Configuration Validation
- [ ] **Invalid configuration handled**
  ```bash
  # Test with invalid config values
  # Service should fail to start with clear error message
  ```

- [ ] **Missing configuration handled**
  ```bash
  # Test with missing required config
  # Service should fail gracefully
  ```

- [ ] **Default values applied**
  ```bash
  # Test with minimal config
  # Verify defaults are applied correctly
  ```

### Runtime Configuration
- [ ] **Configuration changes don't require restart** (if applicable)
- [ ] **Configuration validation at startup**
- [ ] **Configuration logging (without secrets)**

---

## 🌐 PHASE 4: HTTP CLIENT TESTING

### Basic HTTP Client Testing
- [ ] **HTTP GET requests work**
  ```bash
  # Test service-to-service GET calls
  # Verify responses are correct
  ```

- [ ] **HTTP POST requests work**
  ```bash
  # Test service-to-service POST calls
  # Verify request bodies are sent correctly
  ```

- [ ] **HTTP PUT/DELETE requests work**
  ```bash
  # Test other HTTP methods
  # Verify all CRUD operations work
  ```

- [ ] **JSON serialization/deserialization works**
  ```bash
  # Test complex JSON payloads
  # Verify data integrity
  ```

### Circuit Breaker Testing
- [ ] **Circuit breaker opens on failures**
  ```bash
  # Stop target service
  kubectl scale deployment/{target-service} --replicas=0 -n support-services
  
  # Make requests (should fail and open circuit)
  # Check service logs for circuit breaker state changes
  ```

- [ ] **Circuit breaker closes on recovery**
  ```bash
  # Start target service
  kubectl scale deployment/{target-service} --replicas=1 -n support-services
  
  # Wait for service to be ready
  sleep 30
  
  # Make requests (circuit should close)
  # Verify requests succeed
  ```

- [ ] **Half-open state works correctly**
  ```bash
  # Test circuit breaker half-open behavior
  # Verify limited requests are allowed
  ```

- [ ] **Circuit breaker metrics available**
  ```bash
  # Check Prometheus metrics for circuit breaker state
  curl http://localhost:8080/metrics | grep circuit_breaker
  ```

### Retry Logic Testing
- [ ] **Retry on transient failures**
  ```bash
  # Simulate network issues
  # Verify requests are retried
  ```

- [ ] **No retry on permanent failures**
  ```bash
  # Test 4xx errors (should not retry)
  # Verify no unnecessary retries
  ```

- [ ] **Exponential backoff works**
  ```bash
  # Monitor retry timing
  # Verify backoff increases
  ```

### Performance Testing
- [ ] **HTTP client performance acceptable**
  ```bash
  # Load test service-to-service calls
  # Verify response times are acceptable
  ```

- [ ] **Connection pooling works**
  ```bash
  # Monitor connection reuse
  # Verify connections are pooled
  ```

- [ ] **Timeout handling works**
  ```bash
  # Test various timeout scenarios
  # Verify timeouts are respected
  ```

---

## 📡 PHASE 5: EVENT PUBLISHING TESTING

### Basic Event Publishing
- [ ] **Events publish successfully**
  ```bash
  # Trigger event publishing
  # Check Dapr logs for published events
  dapr logs --app-id {service}
  ```

- [ ] **Event format is correct**
  ```bash
  # Verify event structure matches common format
  # Check event metadata and timestamps
  ```

- [ ] **Event topics are correct**
  ```bash
  # Verify events are published to correct topics
  # Check topic naming conventions
  ```

### Event Publishing Reliability
- [ ] **Circuit breaker protects event publishing**
  ```bash
  # Stop Dapr sidecar
  kubectl delete pod {service-dapr-pod}
  
  # Trigger events (should fail gracefully)
  # Verify service continues to work
  ```

- [ ] **Event publishing recovery**
  ```bash
  # Restart Dapr sidecar
  # Verify event publishing resumes
  ```

- [ ] **Event publishing doesn't block main flow**
  ```bash
  # Simulate slow event publishing
  # Verify main business logic continues
  ```

### Event Content Testing
- [ ] **Event data is complete**
  ```bash
  # Verify all required event fields are present
  # Check event payload completeness
  ```

- [ ] **Event metadata is correct**
  ```bash
  # Verify service name, timestamp, event type
  # Check event versioning
  ```

- [ ] **Event serialization works**
  ```bash
  # Verify complex event objects serialize correctly
  # Test various data types
  ```

---

## 🔄 INTEGRATION TESTING

### End-to-End Testing
- [ ] **Complete business flows work**
  ```bash
  # Test full user journeys
  # Verify all services communicate correctly
  ```

- [ ] **Cross-service communication works**
  ```bash
  # Test service A → service B → service C flows
  # Verify data flows correctly
  ```

- [ ] **Event-driven workflows work**
  ```bash
  # Test event publishing and consumption
  # Verify event-driven business logic
  ```

### Error Handling Testing
- [ ] **Graceful degradation works**
  ```bash
  # Stop non-critical services
  # Verify core functionality continues
  ```

- [ ] **Error propagation is correct**
  ```bash
  # Test error scenarios
  # Verify appropriate error responses
  ```

- [ ] **Timeout handling across services**
  ```bash
  # Test various timeout scenarios
  # Verify cascading timeout handling
  ```

### Load Testing
- [ ] **Service handles expected load**
  ```bash
  # Run load tests
  # Verify performance under load
  ```

- [ ] **Circuit breakers handle load**
  ```bash
  # Test circuit breaker behavior under load
  # Verify protection works
  ```

- [ ] **Event publishing handles load**
  ```bash
  # Test high-volume event publishing
  # Verify no events are lost
  ```

---

## 📊 PERFORMANCE TESTING

### Response Time Testing
- [ ] **API response times acceptable**
  ```bash
  # Measure API response times
  # Compare with baseline (should be similar or better)
  ```

- [ ] **Health check response times fast**
  ```bash
  # Health checks should respond < 1 second
  time curl -s http://localhost:8080/health
  ```

- [ ] **Database query performance maintained**
  ```bash
  # Monitor database query times
  # Verify no performance regression
  ```

### Resource Usage Testing
- [ ] **Memory usage stable**
  ```bash
  # Monitor memory usage over time
  kubectl top pods -n support-services
  ```

- [ ] **CPU usage acceptable**
  ```bash
  # Monitor CPU usage under load
  # Verify no CPU spikes
  ```

- [ ] **Connection pool efficiency**
  ```bash
  # Monitor database connection usage
  # Verify efficient connection reuse
  ```

### Scalability Testing
- [ ] **Service scales horizontally**
  ```bash
  # Scale service replicas
  kubectl scale deployment/{service} --replicas=3 -n support-services
  
  # Verify load distribution
  ```

- [ ] **Circuit breakers work with multiple replicas**
  ```bash
  # Test circuit breaker behavior with multiple instances
  # Verify consistent behavior
  ```

---

## 🚨 FAILURE TESTING

### Service Failure Testing
- [ ] **Service handles database failures**
  ```bash
  # Stop database
  # Verify service fails gracefully
  ```

- [ ] **Service handles Redis failures**
  ```bash
  # Stop Redis
  # Verify service continues (if Redis is optional)
  ```

- [ ] **Service handles external service failures**
  ```bash
  # Stop external services
  # Verify circuit breakers protect
  ```

### Network Failure Testing
- [ ] **Service handles network partitions**
  ```bash
  # Simulate network issues
  # Verify retry and timeout behavior
  ```

- [ ] **Service handles DNS failures**
  ```bash
  # Test DNS resolution issues
  # Verify error handling
  ```

### Recovery Testing
- [ ] **Service recovers from failures**
  ```bash
  # Restart failed dependencies
  # Verify service recovers automatically
  ```

- [ ] **Circuit breakers recover**
  ```bash
  # Test circuit breaker recovery
  # Verify automatic state transitions
  ```

---

## 📋 REGRESSION TESTING

### Functional Regression
- [ ] **All existing APIs work**
  ```bash
  # Test all API endpoints
  # Verify no functionality is broken
  ```

- [ ] **Business logic unchanged**
  ```bash
  # Test core business workflows
  # Verify results are identical
  ```

- [ ] **Data integrity maintained**
  ```bash
  # Verify data operations produce same results
  # Check data consistency
  ```

### Performance Regression
- [ ] **No performance degradation**
  ```bash
  # Compare performance metrics with baseline
  # Response times should be similar or better
  ```

- [ ] **Memory usage not increased**
  ```bash
  # Compare memory usage with baseline
  # Should be similar or better
  ```

- [ ] **Database performance maintained**
  ```bash
  # Compare database query performance
  # Should be similar or better
  ```

---

## ✅ ACCEPTANCE CRITERIA

### Functional Acceptance
- [ ] **All health checks pass**
- [ ] **All API endpoints work**
- [ ] **All business workflows complete**
- [ ] **All events publish correctly**
- [ ] **All external service calls work**

### Performance Acceptance
- [ ] **Response times within 10% of baseline**
- [ ] **Memory usage within 10% of baseline**
- [ ] **CPU usage within 10% of baseline**
- [ ] **Database performance maintained**

### Reliability Acceptance
- [ ] **Circuit breakers function correctly**
- [ ] **Retry logic works as expected**
- [ ] **Error handling is appropriate**
- [ ] **Service recovers from failures**

### Operational Acceptance
- [ ] **Service starts successfully**
- [ ] **Kubernetes health checks pass**
- [ ] **Monitoring and logging work**
- [ ] **Metrics are available**

---

## 📝 TEST RESULTS

### Test Summary
**Service:** ___________  
**Migration Phase:** ___________  
**Test Date:** ___________  
**Tester:** ___________

### Results
- [ ] **All tests passed** ✅
- [ ] **Some tests failed** ❌ (see issues below)
- [ ] **Tests incomplete** 🔄 (continue testing)

### Issues Found
1. **Issue:** ________________________________
   **Severity:** High/Medium/Low
   **Status:** Open/Fixed/Deferred

2. **Issue:** ________________________________
   **Severity:** High/Medium/Low
   **Status:** Open/Fixed/Deferred

3. **Issue:** ________________________________
   **Severity:** High/Medium/Low
   **Status:** Open/Fixed/Deferred

### Performance Results
- **API Response Time:** _____ ms (baseline: _____ ms)
- **Health Check Time:** _____ ms (target: < 1000ms)
- **Memory Usage:** _____ MB (baseline: _____ MB)
- **CPU Usage:** _____ % (baseline: _____ %)

### Recommendations
- [ ] **Ready for production** ✅
- [ ] **Needs fixes before production** ❌
- [ ] **Needs performance optimization** ⚡
- [ ] **Needs additional testing** 🔄

---

**Testing completed by:** ___________  
**Date:** ___________  
**Next action:** ___________