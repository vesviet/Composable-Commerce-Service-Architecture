# Monitoring and Observability System

## Overview

This document describes the comprehensive monitoring and observability system implemented across the microservices architecture. The system provides real-time monitoring, circuit breaker management, error aggregation, and health checks.

## Architecture

### Components

1. **Circuit Breaker Pattern**
   - Automatic failure detection and recovery
   - Configurable thresholds and timeouts
   - State management (Closed, Half-Open, Open)
   - Metrics collection and monitoring

2. **Error Aggregation**
   - Centralized error collection and classification
   - Error rate monitoring and alerting
   - Service-specific error tracking
   - Severity-based error categorization

3. **Health Checks**
   - Service health monitoring
   - Database connection status
   - Circuit breaker status integration
   - Readiness and liveness probes

4. **Metrics Collection**
   - Prometheus-based metrics
   - Request/response monitoring
   - Performance metrics
   - Business metrics

## Implementation

### Circuit Breaker

#### Configuration
```go
type Config struct {
    MaxRequests uint32        // Max requests in half-open state
    Interval    time.Duration // Reset interval for closed state
    Timeout     time.Duration // Timeout for open state
    ReadyToTrip func(counts Counts) bool // Failure threshold function
}
```

#### Usage
```go
// Create circuit breaker
cb := circuitbreaker.NewCircuitBreaker("user-service", config, logger)

// Execute with circuit breaker protection
result, err := cb.Execute(func() (interface{}, error) {
    return userService.GetUser(ctx, userID)
})
```

#### States
- **Closed**: Normal operation, requests pass through
- **Half-Open**: Testing if service has recovered
- **Open**: Failing fast, requests rejected immediately

### Monitoring Endpoints

#### Auth Service
- `GET /circuit-breakers/status` - Circuit breaker status
- `POST /circuit-breakers/reset` - Reset circuit breaker
- `GET /health` - Health check with circuit breaker status

#### Gateway Service
- `GET /monitoring/metrics` - Service metrics
- `GET /monitoring/health/dashboard` - Health dashboard
- `GET /monitoring/circuit-breakers` - Circuit breaker status
- `POST /monitoring/circuit-breakers/reset` - Reset circuit breakers
- `GET /monitoring/errors/stats` - Error statistics
- `GET /monitoring/errors/details` - Detailed error information

#### User Service
- `GET /metrics` - Service metrics
- `GET /health` - Health check
- `GET /ready` - Readiness check
- `GET /live` - Liveness check
- `GET /database/status` - Database status

### Metrics

#### Circuit Breaker Metrics
```prometheus
# Circuit breaker state (0=closed, 1=half-open, 2=open)
circuit_breaker_state{service="user-service", name="user-client"} 0

# Total requests through circuit breaker
circuit_breaker_requests_total{service="auth-service", name="user-client", state="closed", result="success"} 1000

# Circuit breaker state changes
circuit_breaker_state_changes_total{service="auth-service", name="user-client", from_state="closed", to_state="open"} 1
```

#### Service Metrics
```prometheus
# Request duration histogram
http_request_duration_seconds{method="GET", path="/api/v1/users", status="200"}

# Request count
http_requests_total{method="GET", path="/api/v1/users", status="200"} 1500

# Active connections
active_connections{service="gateway"} 45

# Error rate
error_rate{service="auth-service", type="authentication"} 0.02
```

### Error Classification

#### Error Types
- `authentication` - Authentication failures
- `authorization` - Authorization failures  
- `validation` - Input validation errors
- `service_unavailable` - Service unavailability
- `timeout` - Request timeouts
- `rate_limit` - Rate limiting errors
- `circuit_breaker` - Circuit breaker errors
- `internal` - Internal server errors
- `not_found` - Resource not found

#### Severity Levels
- `low` - Minor issues, no immediate action required
- `medium` - Moderate issues, monitoring required
- `high` - Serious issues, investigation needed
- `critical` - Critical issues, immediate action required

### Health Checks

#### Health Check Response
```json
{
  "timestamp": "2024-11-03T10:30:00Z",
  "status": "healthy",
  "version": "v1.0.0",
  "details": {
    "database_status": "healthy",
    "circuit_breaker_status": "CLOSED",
    "user_service_status": "CLOSED"
  },
  "circuit_breaker": {
    "service": "user-service",
    "state": "CLOSED",
    "counts": {
      "requests": 1000,
      "total_successes": 995,
      "total_failures": 5,
      "consecutive_successes": 50,
      "consecutive_failures": 0
    }
  }
}
```

#### Status Values
- `healthy` - All systems operational
- `degraded` - Some issues but service functional
- `unhealthy` - Service not operational

## Monitoring Dashboard

### Gateway Dashboard
```json
{
  "gateway": {
    "name": "api-gateway",
    "version": "v1.0.0",
    "status": "healthy",
    "uptime": "2d 14h 32m",
    "requests": {
      "total": 125000,
      "successful": 123500,
      "failed": 1500,
      "rate": "98.8%"
    }
  },
  "services": {
    "auth-service": {
      "status": "healthy",
      "response_time": "45ms",
      "error_rate": "0.2%",
      "circuit_breaker": "CLOSED"
    },
    "user-service": {
      "status": "healthy", 
      "response_time": "32ms",
      "error_rate": "0.1%",
      "circuit_breaker": "CLOSED"
    }
  },
  "alerts": [
    {
      "level": "warning",
      "service": "catalog-service",
      "message": "High response time detected",
      "timestamp": "2024-11-03T10:15:00Z",
      "duration": "15m"
    }
  ]
}
```

## Integration Tests

### Circuit Breaker Testing
```go
func TestCircuitBreakerMonitoring(t *testing.T) {
    // Test circuit breaker state monitoring
    // Test metrics collection
    // Test state transitions
    // Test reset functionality
}
```

### Health Check Testing
```go
func TestHealthCheckMonitoring(t *testing.T) {
    // Test health check includes circuit breaker status
    // Test health status reflects circuit breaker state
    // Test database status monitoring
}
```

## Configuration

### Environment Variables
```bash
# Metrics
METRICS_ENABLED=true
METRICS_PORT=9090
METRICS_PATH=/metrics

# Tracing
TRACING_ENABLED=true
TRACING_ENDPOINT=http://jaeger:14268/api/traces
TRACING_SAMPLER=0.1

# Health Checks
HEALTH_ENABLED=true
HEALTH_PORT=8080
HEALTH_PATH=/health

# Circuit Breaker
CIRCUIT_BREAKER_MAX_REQUESTS=5
CIRCUIT_BREAKER_INTERVAL=60s
CIRCUIT_BREAKER_TIMEOUT=60s
CIRCUIT_BREAKER_FAILURE_THRESHOLD=5
```

### Docker Compose
```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
      - "14268:14268"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

## Best Practices

### Circuit Breaker Configuration
1. Set appropriate failure thresholds based on service SLA
2. Configure timeout values based on expected recovery time
3. Use exponential backoff for retry logic
4. Monitor circuit breaker metrics regularly

### Error Handling
1. Classify errors appropriately by type and severity
2. Implement graceful degradation for non-critical failures
3. Provide meaningful error messages to clients
4. Log errors with sufficient context for debugging

### Monitoring
1. Set up alerts for critical metrics
2. Monitor error rates and response times
3. Track circuit breaker state changes
4. Implement health check endpoints for all services

### Performance
1. Use sampling for tracing in production
2. Implement efficient metrics collection
3. Cache health check results when appropriate
4. Monitor resource usage of monitoring components

## Troubleshooting

### Common Issues

#### Circuit Breaker Stuck Open
- Check service health and connectivity
- Verify circuit breaker configuration
- Review error logs for root cause
- Consider manual reset if service is healthy

#### High Error Rates
- Check service logs for error patterns
- Verify database connectivity
- Monitor resource usage (CPU, memory)
- Check for configuration issues

#### Missing Metrics
- Verify Prometheus configuration
- Check service metric endpoints
- Ensure proper labeling
- Verify network connectivity

### Debugging Commands
```bash
# Check circuit breaker status
curl http://auth-service:8080/circuit-breakers/status

# Reset circuit breaker
curl -X POST http://auth-service:8080/circuit-breakers/reset?service=user-service

# Check service health
curl http://user-service:8080/health

# View metrics
curl http://gateway:9090/metrics
```

## Future Enhancements

1. **Advanced Alerting**
   - Integration with PagerDuty/Slack
   - Smart alert correlation
   - Anomaly detection

2. **Distributed Tracing**
   - Complete Jaeger integration
   - Trace correlation across services
   - Performance bottleneck identification

3. **Advanced Circuit Breaker**
   - Adaptive thresholds
   - Machine learning-based failure prediction
   - Service dependency mapping

4. **Enhanced Dashboards**
   - Real-time service topology
   - Interactive error analysis
   - Capacity planning metrics