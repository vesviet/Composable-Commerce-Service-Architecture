# gRPC Client Standardization & Enhancement Checklist

## 📋 Clean Implementation Checklist

**Created:** 2025-12-25  
**Purpose:** Standardize and enhance gRPC client implementations across all services  
**Status:** 🔄 Ready to Execute

---

## 🎯 OVERVIEW

This checklist addresses critical inconsistencies and missing features identified in the gRPC client review. Focus on standardization, performance, and production readiness.

### Target Services:
- 🔴 **Order Service** - 10 gRPC clients (needs performance + error handling)
- 🟡 **Warehouse Service** - 4 gRPC clients (needs error handling)
- 🟡 **Catalog Service** - 4 gRPC clients (needs error handling)
- 🟡 **Fulfillment Service** - 2 gRPC clients (needs error handling)
- 🟢 **Customer Service** - 1 gRPC client (reference implementation)
- 🟢 **Search Service** - 3 gRPC clients (good implementation)
- 🟢 **Promotion Service** - 4 gRPC clients (good implementation)
- 🔴 **Gateway Service** - 1 gRPC client (needs full enhancement)

---

## 🔴 PHASE 1: CIRCUIT BREAKER STANDARDIZATION (CRITICAL)

### Step 1: Replace Local Circuit Breakers with Common Implementation

#### Order Service (10 clients) 🔴 **HIGH PRIORITY**
- [ ] **Update imports**
  ```go
  // Replace:
  import "gitlab.com/ta-microservices/order/internal/client/circuitbreaker"
  
  // With:
  import "gitlab.com/ta-microservices/common/client/circuitbreaker"
  ```

- [ ] **Standardize circuit breaker creation**
  ```go
  // Replace:
  circuitBreaker := circuitbreaker.NewCircuitBreaker("service-name-grpc")
  
  // With:
  config := circuitbreaker.DefaultConfig()
  config.MaxRequests = 5
  config.Timeout = 120 * time.Second
  config.ReadyToTrip = func(counts circuitbreaker.Counts) bool {
      return counts.ConsecutiveFailures >= 5
  }
  circuitBreaker := circuitbreaker.NewCircuitBreaker("service-name-grpc", config, logger)
  ```

- [ ] **Update call signatures**
  ```go
  // Ensure consistent usage:
  err := c.circuitBreaker.Call(func() error {
      // gRPC call here
      return nil
  })
  ```

#### Warehouse Service (4 clients) 🟡
- [ ] **catalog_grpc_client.go** - Update to common circuit breaker
- [ ] **notification_grpc_client.go** - Update to common circuit breaker
- [ ] **location_client.go** (data layer) - Update to common circuit breaker
- [ ] **operations_client.go** (data layer) - Update to common circuit breaker

#### Catalog Service (4 clients) 🟡
- [ ] **warehouse_grpc_client.go** - Update to common circuit breaker
- [ ] **pricing_grpc_client.go** - Update to common circuit breaker
- [ ] **customer_grpc_client.go** - Update to common circuit breaker
- [ ] **promotion_grpc_client.go** - Update to common circuit breaker

#### Gateway Service (1 client) 🔴
- [ ] **warehouse_grpc_client.go** - Update to common circuit breaker

### Step 2: Remove Local Circuit Breaker Files
- [ ] **Order Service** - Remove `internal/client/circuitbreaker/`
- [ ] **Warehouse Service** - Remove `internal/client/circuitbreaker/`
- [ ] **Catalog Service** - Remove `internal/client/circuitbreaker/`
- [ ] **Gateway Service** - Remove `internal/client/circuitbreaker/`

### Step 3: Validation
- [ ] **Build all services successfully**
  ```bash
  cd order && go build ./cmd/order
  cd warehouse && go build ./cmd/warehouse
  cd catalog && go build ./cmd/catalog
  cd gateway && go build ./cmd/gateway
  ```

- [ ] **Test circuit breaker functionality**
  ```bash
  # Start service, stop dependency, verify circuit opens
  # Restart dependency, verify circuit closes
  ```

---

## 🟡 PHASE 2: PERFORMANCE OPTIMIZATION (HIGH PRIORITY)

### Step 1: Add Keep-Alive Configuration

#### Order Service (10 clients) 🔴 **MISSING**
- [ ] **user_grpc_client.go** - Add keep-alive
- [ ] **payment_grpc_client.go** - Add keep-alive
- [ ] **shipping_grpc_client.go** - Add keep-alive
- [ ] **notification_grpc_client.go** - Add keep-alive
- [ ] **promotion_grpc_client.go** - Add keep-alive
- [ ] **catalog_grpc_client.go** - Add keep-alive
- [ ] **customer_grpc_client.go** - Add keep-alive
- [ ] **warehouse_client.go** (data layer) - Add keep-alive
- [ ] **pricing_client.go** (data layer) - Add keep-alive
- [ ] **catalog_client.go** (data layer) - Add keep-alive

#### Gateway Service (1 client) 🔴 **MISSING**
- [ ] **warehouse_grpc_client.go** - Add keep-alive

**Implementation Pattern:**
```go
conn, err := grpc.NewClient(
    serviceAddr,
    grpc.WithTransportCredentials(insecure.NewCredentials()),
    // Add these lines:
    grpc.WithKeepaliveParams(keepalive.ClientParameters{
        Time:                10 * time.Second,
        Timeout:             3 * time.Second,
        PermitWithoutStream: true,
    }),
    grpc.WithDefaultCallOptions(grpc.UseCompressor(gzip.Name)),
)
```

### Step 2: Add gzip Compression

#### Order Service (10 clients) 🔴 **MISSING**
- [ ] Add `grpc.WithDefaultCallOptions(grpc.UseCompressor(gzip.Name))` to all clients

#### Gateway Service (1 client) 🔴 **MISSING**
- [ ] Add compression to warehouse client

### Step 3: Validation
- [ ] **Monitor connection metrics**
  ```bash
  # Check connection reuse
  netstat -an | grep :grpc_port | wc -l
  ```

- [ ] **Test compression effectiveness**
  ```bash
  # Monitor network traffic before/after
  # Should see reduced bytes transferred
  ```

---

## 🟡 PHASE 3: ERROR HANDLING ENHANCEMENT (HIGH PRIORITY)

### Step 1: Add gRPC Status Code Mapping

#### Order Service (10 clients) 🔴 **NEEDS ENHANCEMENT**
- [ ] **Add mapGRPCError method to each client**
  ```go
  func (c *grpcClient) mapGRPCError(err error, method string) error {
      st, ok := status.FromError(err)
      if !ok {
          return fmt.Errorf("service error in %s: %w", method, err)
      }
      
      switch st.Code() {
      case codes.DeadlineExceeded:
          return fmt.Errorf("service timeout in %s: %w", method, err)
      case codes.Unavailable:
          return fmt.Errorf("service unavailable in %s: %w", method, err)
      case codes.NotFound:
          return fmt.Errorf("resource not found in %s: %w", method, err)
      case codes.InvalidArgument:
          return fmt.Errorf("invalid request in %s: %w", method, err)
      case codes.PermissionDenied:
          return fmt.Errorf("permission denied in %s: %w", method, err)
      case codes.Unauthenticated:
          return fmt.Errorf("authentication failed in %s: %w", method, err)
      case codes.ResourceExhausted:
          return fmt.Errorf("service rate limited in %s: %w", method, err)
      case codes.Internal:
          return fmt.Errorf("service internal error in %s: %w", method, err)
      default:
          return fmt.Errorf("service error [%s] in %s: %w", st.Code(), method, err)
      }
  }
  ```

- [ ] **Update all gRPC calls to use error mapping**
  ```go
  resp, err := c.client.Method(ctx, req)
  if err != nil {
      return c.mapGRPCError(err, "Method")
  }
  ```

#### Warehouse Service (4 clients) 🟡
- [ ] **catalog_grpc_client.go** - Add error mapping
- [ ] **notification_grpc_client.go** - Add error mapping
- [ ] **location_client.go** - Add error mapping
- [ ] **operations_client.go** - Add error mapping

#### Catalog Service (4 clients) 🟡
- [ ] **warehouse_grpc_client.go** - Add error mapping
- [ ] **pricing_grpc_client.go** - Add error mapping
- [ ] **customer_grpc_client.go** - Add error mapping
- [ ] **promotion_grpc_client.go** - Add error mapping

#### Gateway Service (1 client) 🔴
- [ ] **warehouse_grpc_client.go** - Add error mapping

### Step 2: Validation
- [ ] **Test error scenarios**
  ```bash
  # Stop target service
  # Verify meaningful error messages
  # Check error logs for proper categorization
  ```

---

## 🟢 PHASE 4: OBSERVABILITY ENHANCEMENT (MEDIUM PRIORITY)

### Step 1: Add Structured Logging

#### All Services
- [ ] **Add request/response logging**
  ```go
  func (c *grpcClient) logRequest(ctx context.Context, method string, req interface{}) {
      c.logger.WithContext(ctx).Debugf("gRPC call: %s, request: %+v", method, req)
  }
  
  func (c *grpcClient) logResponse(ctx context.Context, method string, duration time.Duration, err error) {
      if err != nil {
          c.logger.WithContext(ctx).Errorf("gRPC call failed: %s, duration: %v, error: %v", method, duration, err)
      } else {
          c.logger.WithContext(ctx).Debugf("gRPC call success: %s, duration: %v", method, duration)
      }
  }
  ```

- [ ] **Add performance logging**
  ```go
  start := time.Now()
  defer func() {
      duration := time.Since(start)
      c.logResponse(ctx, "MethodName", duration, err)
  }()
  ```

### Step 2: Add Metrics (Future Enhancement)
- [ ] **gRPC client metrics**
  - `grpc_client_requests_total{service, method, status}`
  - `grpc_client_duration_seconds{service, method}`
  - `grpc_client_errors_total{service, method, error_type}`

### Step 3: Add Distributed Tracing (Future Enhancement)
- [ ] **OpenTelemetry integration**
- [ ] **Span creation for gRPC calls**
- [ ] **Context propagation**

---

## 🔧 PHASE 5: TESTING & VALIDATION (MEDIUM PRIORITY)

### Step 1: Unit Tests
- [ ] **Create test templates**
  ```go
  func TestGRPCClient_Success(t *testing.T) {
      // Mock gRPC server
      // Test successful call
      // Verify response mapping
  }
  
  func TestGRPCClient_CircuitBreaker(t *testing.T) {
      // Test circuit breaker behavior
      // Verify failure handling
  }
  
  func TestGRPCClient_Timeout(t *testing.T) {
      // Test timeout scenarios
      // Verify timeout handling
  }
  ```

### Step 2: Integration Tests
- [ ] **End-to-end gRPC communication tests**
- [ ] **Service discovery tests**
- [ ] **Circuit breaker integration tests**

### Step 3: Load Tests
- [ ] **Performance benchmarks**
- [ ] **Connection pool efficiency tests**
- [ ] **Circuit breaker under load tests**

---

## 📊 IMPLEMENTATION PRIORITY

### 🔴 **WEEK 1: Critical Fixes**
1. **Circuit Breaker Standardization** (Order, Gateway services)
2. **Performance Optimization** (Order, Gateway services)
3. **Basic Error Handling** (Order service - highest impact)

### 🟡 **WEEK 2: Service Completion**
1. **Error Handling Enhancement** (Warehouse, Catalog services)
2. **Circuit Breaker Updates** (Warehouse, Catalog services)
3. **Validation & Testing**

### 🟢 **WEEK 3: Quality Improvements**
1. **Structured Logging** (All services)
2. **Unit Tests** (Critical services first)
3. **Documentation Updates**

---

## ✅ VALIDATION CHECKLIST

### Per Service Completion
- [ ] **Circuit breaker uses common implementation**
- [ ] **Keep-alive and compression enabled**
- [ ] **gRPC status code mapping implemented**
- [ ] **Timeout policies consistent (5s/10s/30s)**
- [ ] **Structured logging added**
- [ ] **Service builds successfully**
- [ ] **Basic tests pass**

### System-wide Validation
- [ ] **All services use consistent patterns**
- [ ] **No local circuit breaker implementations remain**
- [ ] **Performance metrics show improvement**
- [ ] **Error handling provides meaningful messages**
- [ ] **Circuit breakers function correctly under load**

---

## 🚨 ROLLBACK PLAN

### If Issues Occur
1. **Keep backup of original implementations**
   ```bash
   cp -r service/internal/client service/internal/client.backup
   ```

2. **Gradual rollout per service**
   - Complete one service fully before moving to next
   - Test thoroughly before proceeding

3. **Monitoring during rollout**
   - Watch error rates
   - Monitor response times
   - Check circuit breaker states

---

## 📈 SUCCESS METRICS

### Code Quality
- [ ] **100% services use common circuit breaker**
- [ ] **100% services have performance optimizations**
- [ ] **100% services have enhanced error handling**
- [ ] **Zero local circuit breaker implementations**

### Performance
- [ ] **Connection reuse > 80%**
- [ ] **Response time improvement > 10%**
- [ ] **Error categorization accuracy > 95%**
- [ ] **Circuit breaker effectiveness > 99%**

### Operational
- [ ] **Meaningful error messages in logs**
- [ ] **Consistent monitoring across services**
- [ ] **Reduced debugging time by 50%**
- [ ] **Team confidence in gRPC reliability**

---

**Checklist Owner:** ___________  
**Start Date:** ___________  
**Target Completion:** ___________  
**Status:** 🔄 Ready to Execute

---

## 📝 IMPLEMENTATION NOTES

### Quick Reference Commands

```bash
# Check current circuit breaker usage
find . -name "*.go" -exec grep -l "circuitbreaker" {} \; | grep -v common

# Verify gRPC imports
find . -name "*grpc*client*.go" -exec grep -l "google.golang.org/grpc" {} \;

# Test service builds
for service in order warehouse catalog gateway; do
    echo "Building $service..."
    cd $service && go build ./cmd/$service && cd ..
done

# Monitor gRPC connections
netstat -an | grep :grpc_port | wc -l
```

### Common Patterns

```go
// Standard gRPC client setup
conn, err := grpc.NewClient(
    serviceAddr,
    grpc.WithTransportCredentials(insecure.NewCredentials()),
    grpc.WithKeepaliveParams(keepalive.ClientParameters{
        Time:                10 * time.Second,
        Timeout:             3 * time.Second,
        PermitWithoutStream: true,
    }),
    grpc.WithDefaultCallOptions(grpc.UseCompressor(gzip.Name)),
)

// Standard circuit breaker setup
config := circuitbreaker.DefaultConfig()
cb := circuitbreaker.NewCircuitBreaker("service-name-grpc", config, logger)

// Standard method implementation
func (c *client) Method(ctx context.Context, req *Request) (*Response, error) {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    
    var resp *Response
    err := c.circuitBreaker.Call(func() error {
        var callErr error
        resp, callErr = c.client.Method(ctx, req)
        if callErr != nil {
            return c.mapGRPCError(callErr, "Method")
        }
        return nil
    })
    
    return resp, err
}
```