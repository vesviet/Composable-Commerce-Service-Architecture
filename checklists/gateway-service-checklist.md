# Gateway Service - Implementation Review Checklist

## 📋 Overview

This checklist documents findings from reviewing the Gateway Service implementation, focusing on routing, authentication, middleware, service discovery, circuit breaking, rate limiting, caching, and BFF capabilities.

**Service Location**: `gateway/` (root level)

**Review Date**: 2025-11-18

---

## ✅ Implemented Features

### 1. **Core Routing**
- ✅ Auto-routing based on `/api/v1/{resource}/*` pattern
- ✅ Resource-to-service mapping (`resource_mapping.go`)
- ✅ Service discovery via Consul
- ✅ Load balancing across service instances
- ✅ URL parsing and route resolution
- ✅ Legacy route support
- ✅ Kratos route support
- ✅ BFF route support

### 2. **Authentication & Authorization**
- ✅ JWT token validation
- ✅ Admin authentication middleware
- ✅ Role-based access control (admin, staff, super_admin)
- ✅ Public/protected route configuration
- ✅ Token validation with Auth Service fallback
- ✅ User context extraction from JWT
- ✅ Client type identification (customer/admin)

### 3. **Middleware Stack**
- ✅ Rate limiting (per-IP, per-user, per-endpoint)
- ✅ Circuit breaker (service failure protection)
- ✅ Smart caching (per-endpoint caching strategies)
- ✅ Request retry with exponential backoff
- ✅ CORS support
- ✅ Monitoring middleware (metrics, tracing)
- ✅ Audit logging for admin actions
- ✅ Request ID generation and propagation

### 4. **Service Discovery & Health Checks**
- ✅ Consul integration
- ✅ Service health monitoring
- ✅ Gateway health endpoint (`/health`)
- ✅ Service health aggregation (`/api/services/health`)
- ✅ Automatic service registration discovery

### 5. **BFF (Backend for Frontend)**
- ✅ Data aggregation from multiple services
- ✅ Data transformation (product transformer example)
- ✅ Admin action audit logging
- ✅ BFF route handlers

### 6. **Observability**
- ✅ Prometheus metrics
- ✅ Jaeger distributed tracing
- ✅ Structured JSON logging
- ✅ Request correlation IDs
- ✅ Error monitoring and aggregation

### 7. **Configuration**
- ✅ YAML configuration files
- ✅ Environment variable support
- ✅ Middleware configuration
- ✅ Service mapping configuration
- ✅ Resource mapping configuration

### 8. **Error Handling**
- ✅ Error aggregation
- ✅ Standard error response format
- ✅ Error metrics tracking
- ✅ Graceful error handling

---

## 🔴 Critical Issues

### 1. **Rate Limiter - Memory Leak (CRITICAL)**
- **File**: `gateway/internal/middleware/rate_limit.go:22-133`
- **Issue**: `limiters map[string]*rate.Limiter` grows indefinitely without cleanup
- **Code**:
  ```go
  limiters: make(map[string]*rate.Limiter), // Never cleaned up!
  
  // In checkMemoryLimit():
  limiter, exists := rl.limiters[key]
  if !exists {
      limiter = rate.NewLimiter(rateLimit, rule.BurstSize)
      rl.limiters[key] = limiter // Added but never removed
  }
  ```
- **Impact**: 
  - Memory leak: Each unique IP/user creates a limiter that's never removed
  - Under high traffic, map grows unbounded → OOM (Out of Memory)
  - Production system will crash after extended operation
- **Fix**: Implement cleanup mechanism:
  ```go
  // Option 1: TTL-based cleanup (recommended)
  type limiterEntry struct {
      limiter *rate.Limiter
      lastUsed time.Time
  }
  limiters map[string]*limiterEntry
  
  // Cleanup goroutine that runs periodically
  go func() {
      ticker := time.NewTicker(5 * time.Minute)
      for range ticker.C {
          rl.cleanupStaleLimiters(10 * time.Minute) // Remove limiters unused for 10min
      }
  }()
  
  // Option 2: LRU cache with max size
  // Use a library like github.com/hashicorp/golang-lru
  ```
- **Priority**: 🔴 **CRITICAL** - Must fix before production

### 2. **Resource Mapping - Hardcoded in Code**
- **File**: `gateway/internal/router/resource_mapping.go:62-176`
- **Issue**: All resource-to-service mappings are hardcoded in `getDefaultResourceMapping()` function
- **Code**:
  ```go
  func getDefaultResourceMapping() map[string]*ResourceConfig {
      return map[string]*ResourceConfig{
          "categories": {
              Service: "catalog",
              InternalPrefix: "/api/v1/catalog",
          },
          // ... 20+ more hardcoded mappings
      }
  }
  ```
- **Impact**: 
  - Adding new resources requires code changes and redeployment
  - Cannot configure mappings per environment
  - Difficult to maintain and extend
- **Fix**: Move all mappings to config file:
  ```yaml
  # configs/gateway.yaml
  routing:
    resource_mapping:
      categories:
        service: catalog
        internal_prefix: /api/v1/catalog
      products:
        service: catalog
        internal_prefix: /api/v1/catalog
      # ... all mappings in config
  ```
  - Update `LoadResourceMapping()` to load from config first, use hardcoded as fallback
  - Remove `getDefaultResourceMapping()` function
- **Priority**: 🟠 High - Affects maintainability

### 3. **JWT Validation - Missing Token Expiry Check**
- **File**: `gateway/internal/middleware/jwt_validator.go:11-106`
- **Issue**: Token validation checks signature and structure but doesn't explicitly validate expiry (`exp` claim)
- **Code**:
  ```go
  // Current validation only checks:
  if !token.Valid {
      return nil, fmt.Errorf("invalid token")
  }
  // Missing explicit expiry check
  ```
- **Impact**: Expired tokens might be accepted if JWT library doesn't validate expiry automatically
- **Fix**: Add explicit expiry validation:
  ```go
  // After token.Valid check
  if claims, ok := token.Claims.(jwt.MapClaims); ok {
      if exp, ok := claims["exp"].(float64); ok {
          if time.Now().Unix() > int64(exp) {
              return nil, fmt.Errorf("token expired")
          }
      }
  }
  ```

### 2. **Rate Limiting - Race Condition in In-Memory Limiters**
- **File**: `gateway/internal/middleware/rate_limit.go:19-45`
- **Issue**: In-memory limiters map (`limiters map[string]*rate.Limiter`) is accessed without proper locking in some paths
- **Code**:
  ```go
  limiters: make(map[string]*rate.Limiter),
  mu: sync.RWMutex,
  // But checkLimit might access limiters without lock
  ```
- **Impact**: Concurrent access to limiters map can cause race conditions
- **Fix**: Ensure all access to `limiters` map is protected by `mu` lock

### 3. **Circuit Breaker - No State Persistence**
- **File**: `gateway/internal/middleware/circuit_breaker.go:39-70`
- **Issue**: Circuit breaker state is stored only in memory, lost on gateway restart
- **Code**:
  ```go
  circuits: make(map[string]*ServiceCircuit), // In-memory only
  ```
- **Impact**: Circuit breaker state resets on restart, losing failure history
- **Fix**: Consider persisting circuit breaker state to Redis or at least logging state changes

### 4. **Auto Router - Missing Error Context in Failed Service Calls**
- **File**: `gateway/internal/router/auto_router.go:62-680`
- **Issue**: When service call fails, error response might not include enough context
- **Impact**: Difficult to debug service failures
- **Fix**: Ensure error responses include service name, request ID, and error details

### 5. **Smart Cache - Missing Invalidation Logic**
- **File**: `gateway/internal/middleware/smart_cache.go:1-170`
- **Issue**: Cache entries are never invalidated when data changes
- **Code**:
  ```go
  // Cache is set but never invalidated
  if err := m.redis.Set(ctx, cacheKey, string(body), strategy.TTL).Err(); err == nil {
      // No invalidation mechanism
  }
  ```
- **Impact**: 
  - Stale data served to clients after mutations (POST/PUT/DELETE)
  - Users see outdated product information
  - Cache grows indefinitely without cleanup
- **Fix**: Implement cache invalidation:
  ```go
  // Option 1: Invalidate on mutation
  func (m *SmartCacheMiddleware) InvalidatePattern(pattern string) {
      keys, _ := m.redis.Keys(ctx, pattern).Result()
      m.redis.Del(ctx, keys...)
  }
  
  // Option 2: Event-based invalidation
  // Subscribe to product update events and invalidate cache
  
  // Option 3: TTL-based with shorter TTL for mutable data
  // Use shorter TTL for endpoints that change frequently
  ```
- **Priority**: 🟠 High - Affects data consistency

### 6. **Resource Mapping - No Validation of Service Availability**
- **File**: `gateway/internal/router/resource_mapping.go:24-54`
- **Issue**: Resource mapping loads without validating if services exist in Consul
- **Code**:
  ```go
  // Validate that all services exist
  // Skip validation if service doesn't exist (might be optional or not yet deployed)
  ```
- **Impact**: Routes can be configured for non-existent services, causing runtime failures
- **Fix**: Add optional validation mode that warns about missing services

---

## 🟠 High Priority Issues

### 6. **Rate Limiting - Redis Fallback Not Implemented**
- **File**: `gateway/internal/middleware/rate_limit.go:19-45`
- **Issue**: Redis client is initialized but distributed rate limiting might not be fully implemented
- **Impact**: Rate limiting might not work correctly in multi-instance deployments
- **Fix**: Ensure Redis-based distributed rate limiting is properly implemented

### 7. **Smart Cache - No Cache Invalidation Strategy**
- **File**: `gateway/internal/middleware/smart_cache.go`
- **Issue**: Cache entries might not be invalidated when data changes
- **Impact**: Stale data served to clients
- **Fix**: Implement cache invalidation via events or TTL-based expiration

### 8. **JWT Validator - Missing Token Refresh Logic**
- **File**: `gateway/internal/middleware/jwt_validator.go:11-106`
- **Issue**: No automatic token refresh when token is about to expire
- **Impact**: Users need to manually refresh tokens
- **Fix**: Add token refresh logic or at least return refresh token in response

### 9. **Service Client - No Connection Pooling Configuration**
- **File**: `gateway/internal/client/service_client.go`
- **Issue**: HTTP client might not have proper connection pooling configured
- **Impact**: Performance degradation under high load
- **Fix**: Configure HTTP client with proper connection pooling, timeouts, and keep-alive

### 10. **Auto Router - Missing Request Body Size Limit**
- **File**: `gateway/internal/router/auto_router.go:62-680`
- **Issue**: No explicit request body size limit configured
- **Impact**: Large request bodies can cause memory issues
- **Fix**: Add `MaxRequestSize` configuration and enforce in router

### 11. **Circuit Breaker - No Metrics for Half-Open State**
- **File**: `gateway/internal/middleware/circuit_breaker.go:39-348`
- **Issue**: Half-open state transitions might not be properly tracked in metrics
- **Impact**: Difficult to monitor circuit breaker behavior
- **Fix**: Ensure all state transitions are tracked in Prometheus metrics

### 12. **Health Check - No Service Dependency Check**
- **File**: `gateway/internal/observability/health/health.go`
- **Issue**: Health check might not verify connectivity to critical dependencies (Consul, Redis)
- **Impact**: Gateway might report healthy even if dependencies are down
- **Fix**: Add dependency health checks (Consul, Redis connectivity)

### 13. **BFF Aggregation - No Timeout Per Service Call**
- **File**: `gateway/internal/handler/aggregation.go`
- **Issue**: When aggregating data from multiple services, no per-service timeout
- **Impact**: One slow service can block entire aggregation
- **Fix**: Add per-service timeout in aggregation logic

### 14. **Error Aggregator - Missing Error Classification**
- **File**: `gateway/internal/errors/error_aggregator.go`
- **Issue**: Errors might not be classified (retryable vs non-retryable)
- **Impact**: Retry logic might retry non-retryable errors
- **Fix**: Classify errors and only retry retryable ones

---

## 🟡 Medium Priority Issues

### 15. **Resource Mapping - Hardcoded Defaults**
- **File**: `gateway/internal/router/resource_mapping.go:62-176`
- **Issue**: Resource mappings are hardcoded in code
- **Impact**: Adding new resources requires code changes
- **Fix**: Move all mappings to configuration file

### 16. **JWT Validator - No Token Blacklist Check**
- **File**: `gateway/internal/middleware/jwt_validator.go:11-106`
- **Issue**: No check against token blacklist (for logout/invalidated tokens)
- **Impact**: Logged-out tokens might still be valid
- **Fix**: Add token blacklist check (Redis-based)

### 17. **Rate Limiting - No Adaptive Rate Limiting**
- **File**: `gateway/internal/middleware/rate_limit.go:19-274`
- **Issue**: Rate limits are static, no adaptive adjustment based on load
- **Impact**: Fixed limits might be too restrictive or too permissive
- **Fix**: Consider adaptive rate limiting based on system load

### 18. **Smart Cache - No Cache Warming Strategy**
- **File**: `gateway/internal/middleware/smart_cache.go`
- **Issue**: Cache is populated on-demand, no pre-warming
- **Impact**: Cold cache can cause slow initial requests
- **Fix**: Implement cache warming for frequently accessed endpoints

### 19. **Circuit Breaker - No Custom Failure Thresholds Per Service**
- **File**: `gateway/internal/middleware/circuit_breaker.go:39-348`
- **Issue**: Circuit breaker uses same thresholds for all services
- **Impact**: Some services might need different failure thresholds
- **Fix**: Add per-service circuit breaker configuration

### 20. **Auto Router - No Request Deduplication**
- **File**: `gateway/internal/router/auto_router.go:62-680`
- **Issue**: Duplicate requests (same request ID) are not deduplicated
- **Impact**: Retries can cause duplicate processing
- **Fix**: Add request deduplication based on request ID

### 21. **BFF Transformer - Limited Transformation Examples**
- **File**: `gateway/internal/transformer/product.go`
- **Issue**: Only product transformer example exists
- **Impact**: Other transformations need to be implemented from scratch
- **Fix**: Add more transformer examples or create transformer framework

### 22. **Monitoring - No Request Duration Percentiles**
- **File**: `gateway/internal/observability/prometheus/metrics.go`
- **Issue**: Metrics might not track percentiles (p50, p95, p99)
- **Impact**: Difficult to identify latency spikes
- **Fix**: Add histogram metrics with percentiles

### 23. **Service Discovery - No Health Check Retry Logic**
- **File**: `gateway/internal/router/service_registry.go`
- **Issue**: If Consul health check fails, no retry logic
- **Impact**: Temporary Consul issues can cause service discovery failures
- **Fix**: Add retry logic with exponential backoff for Consul calls

### 24. **Configuration - No Configuration Validation**
- **File**: `gateway/internal/config/config.go`
- **Issue**: Configuration is loaded without validation
- **Impact**: Invalid configuration can cause runtime errors
- **Fix**: Add configuration validation on startup

---

## 🟢 Low Priority Issues / Improvements

### 25. **Documentation - Missing API Examples**
- **File**: `gateway/README.md`, `gateway/GATEWAY_GUIDE.md`
- **Issue**: Some API examples might be missing
- **Impact**: Developers need to explore code to understand usage
- **Fix**: Add comprehensive API examples for all features

### 26. **Error Messages - Not User-Friendly**
- **File**: Multiple files
- **Issue**: Error messages might be too technical for end users
- **Impact**: Poor user experience
- **Fix**: Add user-friendly error messages while keeping technical details in logs

### 27. **Logging - No Log Level Configuration Per Component**
- **File**: `gateway/internal/observability/setup.go`
- **Issue**: Log level is global, not per-component
- **Impact**: Difficult to debug specific components
- **Fix**: Add per-component log level configuration

### 28. **Metrics - Missing Business Metrics**
- **File**: `gateway/internal/observability/prometheus/metrics.go`
- **Issue**: Metrics focus on technical metrics, not business metrics
- **Impact**: Difficult to track business KPIs
- **Fix**: Add business metrics (requests per user, popular endpoints, etc.)

### 29. **Testing - Missing Integration Tests**
- **File**: Test files
- **Issue**: Integration tests might be missing
- **Impact**: Difficult to verify end-to-end behavior
- **Fix**: Add integration tests for critical flows

### 30. **Performance - No Request Batching**
- **File**: `gateway/internal/router/auto_router.go`
- **Issue**: Each request is processed individually
- **Impact**: No optimization for batch requests
- **Fix**: Consider request batching for BFF endpoints

---

## 🧪 Testing Checklist

### Unit Tests
- [ ] JWT validation logic
- [ ] Rate limiting logic
- [ ] Circuit breaker state transitions
- [ ] URL parsing and route resolution
- [ ] Resource mapping
- [ ] Error aggregation
- [ ] Data transformation

### Integration Tests
- [ ] End-to-end request routing
- [ ] Service discovery with Consul
- [ ] Authentication flow
- [ ] Rate limiting with Redis
- [ ] Circuit breaker with service failures
- [ ] Cache hit/miss scenarios
- [ ] BFF aggregation

### Load Tests
- [ ] High concurrent request handling
- [ ] Rate limiting under load
- [ ] Circuit breaker under failures
- [ ] Cache performance under load
- [ ] Service discovery performance

### Security Tests
- [ ] JWT token validation
- [ ] Admin authentication
- [ ] CORS configuration
- [ ] Rate limiting bypass attempts
- [ ] SQL injection in query params (if applicable)

---

## 📚 Documentation Checklist

### Code Documentation
- [ ] All public functions have doc comments
- [ ] Complex logic has inline comments
- [ ] Configuration options are documented
- [ ] API examples in code comments

### User Documentation
- [ ] README.md is up to date
- [ ] GATEWAY_GUIDE.md covers all features
- [ ] API examples are comprehensive
- [ ] Configuration guide is complete
- [ ] Troubleshooting guide exists

### Architecture Documentation
- [ ] Architecture diagram is up to date
- [ ] Request flow diagram
- [ ] Middleware chain diagram
- [ ] Service discovery flow
- [ ] Error handling flow

---

## 🔧 Configuration Checklist

### Required Configuration
- [ ] Gateway port configuration
- [ ] Consul address and port
- [ ] Redis address and port
- [ ] JWT secret key
- [ ] Service discovery settings
- [ ] Middleware configuration (rate limit, circuit breaker, cache)

### Optional Configuration
- [ ] Custom resource mappings
- [ ] Per-service timeouts
- [ ] Custom middleware order
- [ ] Log level configuration
- [ ] Metrics configuration
- [ ] Tracing configuration

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] Configuration files are validated
- [ ] Environment variables are set
- [ ] Dependencies (Consul, Redis) are available
- [ ] Health checks are configured
- [ ] Monitoring is set up

### Deployment
- [ ] Gateway service starts successfully
- [ ] Service discovery works
- [ ] Health endpoint responds
- [ ] Metrics are being collected
- [ ] Tracing is working

### Post-Deployment
- [ ] All routes are accessible
- [ ] Authentication works
- [ ] Rate limiting is active
- [ ] Circuit breaker is monitoring services
- [ ] Cache is working
- [ ] Logs are being collected

---

## 📊 Monitoring Checklist

### Metrics to Monitor
- [ ] Request rate (requests per second)
- [ ] Request duration (p50, p95, p99)
- [ ] Error rate (4xx, 5xx)
- [ ] Circuit breaker state changes
- [ ] Rate limit hits
- [ ] Cache hit/miss ratio
- [ ] Service discovery latency

### Alerts to Configure
- [ ] High error rate (> 5%)
- [ ] High latency (p95 > 1s)
- [ ] Circuit breaker opened
- [ ] Service discovery failures
- [ ] Redis connection failures
- [ ] Consul connection failures

---

## 🔐 Security Checklist

### Authentication & Authorization
- [ ] JWT validation is working
- [ ] Token expiry is checked
- [ ] Admin authentication is enforced
- [ ] Role-based access control works
- [ ] Public routes don't require auth

### Rate Limiting & DDoS Protection
- [ ] Rate limiting is active
- [ ] Per-IP limits are configured
- [ ] Per-user limits are configured
- [ ] Per-endpoint limits are configured
- [ ] DDoS protection is effective

### Data Protection
- [ ] Sensitive data is not logged
- [ ] Request/response bodies are not logged (unless needed)
- [ ] Error messages don't leak sensitive info
- [ ] CORS is properly configured

---

## 📝 Notes

### Known Limitations
1. Circuit breaker state is not persisted across restarts
2. Cache invalidation strategy needs improvement
3. Some resource mappings are hardcoded
4. Token blacklist is not implemented

### Future Improvements
1. Implement distributed rate limiting with Redis
2. Add token blacklist for logout
3. Implement cache warming strategy
4. Add request deduplication
5. Implement adaptive rate limiting
6. Add per-service circuit breaker configuration
7. Add business metrics
8. Improve error classification

---

## 🔧 Refactoring Tasks (High Priority)

### **Task 1: Config Refactoring - Consolidate Multiple Config Files**

**Problem**: 4 config files with duplicate content:
- `configs/gateway.yaml` (522 lines)
- `configs/middleware.yaml` (172 lines) - **DUPLICATE**
- `configs/gateway-service-mapping.yaml` (263 lines) - **DUPLICATE**
- `configs/gateway-routes.yaml` (643 lines) - **DUPLICATE**

**Solution**: Consolidate into single `configs/gateway.yaml` file

**Implementation Checklist**:
- [ ] Review `CONFIG_REFACTORING_PROPOSAL.md` for detailed plan
- [ ] Create new unified `configs/gateway.yaml` structure
- [ ] Merge content from all 4 config files
- [ ] Remove duplicate definitions (CORS, rate limit, auth, services, routes)
- [ ] Add environment variable support (`${VAR:-default}` syntax)
- [ ] Update `internal/config/config.go` struct to match new structure
- [ ] Update `internal/config/provider.go` loader
- [ ] Add environment variable expansion in config loader
- [ ] Remove deprecated `Routes` field from config struct
- [ ] Update all code references to use new config structure
- [ ] Delete old config files:
  - [ ] `configs/middleware.yaml`
  - [ ] `configs/gateway-service-mapping.yaml`
  - [ ] `configs/gateway-routes.yaml`
- [ ] Update tests to use new config structure
- [ ] Test config loading in development
- [ ] Test config loading in staging
- [ ] Update documentation (README.md, GATEWAY_GUIDE.md)
- [ ] Document environment variables

**Files to Modify**:
- `configs/gateway.yaml` (create new unified version)
- `internal/config/config.go` (simplify struct)
- `internal/config/provider.go` (update loader)
- All files that reference old config structure

**Expected Benefits**:
- ✅ Single source of truth (1 file instead of 4)
- ✅ No duplicate definitions
- ✅ Easier maintenance (changes in one place)
- ✅ Environment variable support
- ✅ Clearer configuration structure

---

### **Task 2: Auto Router Refactoring - Remove Duplicate Logic**

**Problem**: Duplicate logic across multiple router files:
- JWT validation (3 implementations) - **Consolidate JWT validation**
- Request forwarding (5 implementations)
- CORS headers (2 implementations) - **Remove duplicate CORS logic**
- Error responses (many duplicate patterns)
- Header copying (4 implementations)
- Context headers (2 implementations)

**Solution**: Create shared utility package `internal/router/utils/`

**Implementation Checklist**:
- [ ] Review `AUTO_ROUTER_REFACTORING_PROPOSAL.md` for detailed plan
- [ ] Create `internal/router/utils/` package
- [ ] Implement `utils/jwt.go`:
  - [ ] `JWTValidator` struct
  - [ ] `ValidateToken()` method
  - [ ] `ValidateTokenWithAuthService()` method
  - [ ] `UserContext` struct
  - [ ] Unit tests
- [ ] Implement `utils/proxy.go`:
  - [ ] `ProxyHandler` struct
  - [ ] `ProxyRequest` struct
  - [ ] `RequestContext` struct
  - [ ] `ForwardRequest()` method
  - [ ] `copyHeaders()` method
  - [ ] `addContextHeaders()` method
  - [ ] `writeResponse()` method
  - [ ] `writeError()` method
  - [ ] Unit tests
- [ ] Implement `utils/cors.go`:
  - [ ] `CORSHandler` struct
  - [ ] `SetCORSHeaders()` method
  - [ ] Unit tests
- [ ] Implement `utils/errors.go`:
  - [ ] `WriteError()` function
  - [ ] `WriteServiceError()` function
  - [ ] `WriteValidationError()` function
  - [ ] `WriteUnauthorizedError()` function
  - [ ] `WriteForbiddenError()` function
  - [ ] `WriteNotFoundError()` function
  - [ ] Unit tests
- [ ] Refactor `auto_router.go`:
  - [ ] Replace `validateJWT()` with `JWTValidator`
  - [ ] Replace `forwardRequest()` with `ProxyHandler`
  - [ ] Replace `setCORSHeaders()` with `CORSHandler`
  - [ ] Replace error responses with `utils/errors.go` functions
  - [ ] Update tests
- [ ] Refactor `kratos_router.go`:
  - [ ] Replace `createProxyHandlerForRoute()` with `ProxyHandler`
  - [ ] Replace `handleBFFProductInternal()` proxy logic with `ProxyHandler`
  - [ ] Replace `handleBFFAdminInternal()` proxy logic with `ProxyHandler`
  - [ ] Replace `setCORSHeaders()` with `CORSHandler`
  - [ ] Replace `copyContextHeadersKratos()` with `ProxyHandler.addContextHeaders()`
  - [ ] Replace error responses with `utils/errors.go` functions
  - [ ] Update tests
- [ ] Refactor `proxy_handler.go`:
  - [ ] Replace `createProxyHandlerKratos()` with `ProxyHandler`
  - [ ] Replace `setCORSHeaders()` with `CORSHandler`
  - [ ] Update tests
- [ ] Refactor `legacy_router.go`:
  - [ ] Replace error responses with `utils/errors.go` functions
  - [ ] Update tests
- [ ] Integration tests:
  - [ ] Test all routing scenarios
  - [ ] Test error handling
  - [ ] Test CORS headers
  - [ ] Test JWT validation
  - [ ] Test request forwarding
- [ ] Code cleanup:
  - [ ] Remove duplicate code
  - [ ] Update comments
  - [ ] Verify no functionality broken
- [ ] Test in development environment
- [ ] Test in staging environment
- [ ] Update documentation

**Files to Create**:
- `internal/router/utils/jwt.go`
- `internal/router/utils/proxy.go`
- `internal/router/utils/cors.go`
- `internal/router/utils/errors.go`

**Files to Modify**:
- `internal/router/auto_router.go` (reduce from 680 to ~400 lines)
- `internal/router/kratos_router.go` (reduce from 882 to ~600 lines)
- `internal/router/proxy_handler.go` (reduce from 152 to ~50 lines)
- `internal/router/legacy_router.go` (update error handling)

**Expected Benefits**:
- ✅ Single source of truth for each logic
- ✅ ~264 lines of code reduction
- ✅ Easier maintenance (bug fixes in one place)
- ✅ Better consistency across routers
- ✅ Improved testability

---

### **Task 3: Fix Critical Issues**

#### **3.1: Fix Rate Limiter Memory Leak (CRITICAL)**

**Problem**: `limiters map[string]*rate.Limiter` grows indefinitely without cleanup

**Implementation Checklist**:
- [ ] Review memory leak issue in `rate_limit.go:22-133`
- [ ] Choose cleanup strategy:
  - [ ] Option 1: TTL-based cleanup (recommended)
  - [ ] Option 2: LRU cache with max size
  - [ ] Option 3: Periodic cleanup goroutine
- [ ] Implement cleanup mechanism:
  - [ ] Add `lastUsed` timestamp to limiter entries
  - [ ] Add cleanup goroutine or LRU eviction
  - [ ] Add cleanup interval configuration
  - [ ] Add max limiters configuration
- [ ] Add metrics for limiter count and cleanup operations
- [ ] Unit tests for cleanup logic
- [ ] Load tests to verify no memory leak
- [ ] Test in development environment
- [ ] Test in staging environment
- [ ] Monitor memory usage in production

**Files to Modify**:
- `internal/middleware/rate_limit.go` (add cleanup logic)
- `internal/middleware/config.go` (add cleanup config)

**Expected Benefits**:
- ✅ No memory leak
- ✅ Bounded memory usage
- ✅ Production stability

---

#### **3.2: Move Resource Mapping to Config**

**Problem**: Resource mappings hardcoded in `resource_mapping.go:62-176`

**Implementation Checklist**:
- [ ] Review hardcoded mappings in `resource_mapping.go`
- [ ] Add `resource_mapping` section to `configs/gateway.yaml`:
  ```yaml
  routing:
    resource_mapping:
      categories:
        service: catalog
        internal_prefix: /api/v1/catalog
      # ... all mappings
  ```
- [ ] Update `ResourceMapping` struct to load from config
- [ ] Update `LoadResourceMapping()` to:
  - [ ] Load from config file first
  - [ ] Use hardcoded mappings as fallback only
  - [ ] Log warning if using fallback
- [ ] Remove `getDefaultResourceMapping()` function (or keep as fallback)
- [ ] Add validation for resource mappings
- [ ] Update tests to use config-based mappings
- [ ] Test config loading
- [ ] Test fallback to hardcoded mappings
- [ ] Update documentation

**Files to Modify**:
- `configs/gateway.yaml` (add resource_mapping section)
- `internal/router/resource_mapping.go` (load from config)
- `internal/config/config.go` (add ResourceMappingConfig struct)

**Expected Benefits**:
- ✅ No code changes needed for new resources
- ✅ Environment-specific mappings
- ✅ Easier maintenance

---

#### **3.3: Add Cache Invalidation**

**Problem**: Smart cache never invalidates entries after mutations

**Implementation Checklist**:
- [ ] Review cache implementation in `smart_cache.go`
- [ ] Implement invalidation strategy:
  - [ ] Option 1: Pattern-based invalidation (recommended)
  - [ ] Option 2: Event-based invalidation
  - [ ] Option 3: Shorter TTL for mutable endpoints
- [ ] Add invalidation methods:
  - [ ] `InvalidatePattern(pattern string)` - Invalidate by pattern
  - [ ] `InvalidateKey(key string)` - Invalidate specific key
  - [ ] `InvalidateAll()` - Invalidate all cache (admin only)
- [ ] Add invalidation triggers:
  - [ ] On POST/PUT/DELETE requests (immediate invalidation)
  - [ ] On product update events (event-based)
  - [ ] Manual invalidation endpoint (admin)
- [ ] Add invalidation configuration:
  ```yaml
  middleware:
    smart_cache:
      invalidation:
        on_mutation: true
        patterns:
          - path: /api/v1/products/*
            methods: [POST, PUT, DELETE]
            invalidate: ["products:list:*", "product:detail:*"]
  ```
- [ ] Add cache statistics (hit/miss ratio, invalidation count)
- [ ] Unit tests for invalidation logic
- [ ] Integration tests for cache invalidation
- [ ] Test invalidation on mutations
- [ ] Test event-based invalidation (if implemented)
- [ ] Update documentation

**Files to Modify**:
- `internal/middleware/smart_cache.go` (add invalidation logic)
- `internal/middleware/config.go` (add invalidation config)
- `configs/gateway.yaml` (add invalidation patterns)

**Expected Benefits**:
- ✅ No stale data after mutations
- ✅ Better data consistency
- ✅ Configurable invalidation patterns

---

### **Task 4: Combined Implementation Strategy**

**Recommended Order**:
1. **Phase 1: Fix Critical Issues** (URGENT)
   - **1.1: Fix Rate Limiter Memory Leak** (CRITICAL - do first!)
   - **1.2: Move Resource Mapping to Config** (High priority)
   - **1.3: Add Cache Invalidation** (High priority)
   - These are production blockers or high-impact issues

2. **Phase 2: Config Refactoring** (Foundation)
   - Consolidate config files
   - This provides clean foundation for router refactoring
   - Easier to test config changes independently

3. **Phase 3: Auto Router Refactoring** (Build on foundation)
   - Create utility package
   - Refactor routers to use utilities
   - Consolidate JWT validation
   - Remove duplicate CORS logic
   - Can reference new unified config structure

**Testing Strategy**:
- Test each phase independently
- Integration tests after each phase
- Full system test after both phases complete

**Rollback Plan**:
- Keep old config files in git history
- Keep old router code in git history
- Can revert to previous version if issues arise

**Documentation Updates**:
- [ ] Update `README.md` with new config structure
- [ ] Update `GATEWAY_GUIDE.md` with refactored architecture
- [ ] Document utility package usage
- [ ] Add migration guide for config changes
- [ ] Update API examples if needed

---

## ✅ Review Status

- **Code Review**: ✅ Completed
- **Testing Review**: ⏳ Pending
- **Documentation Review**: ✅ Completed
- **Security Review**: ⏳ Pending
- **Performance Review**: ⏳ Pending

---

**Last Updated**: 2025-11-18  
**Reviewed By**: AI Assistant  
**Next Review Date**: TBD

---

## 📌 Quick Reference

### Refactoring Tasks Summary

| Task | Priority | Status | Estimated Effort |
|------|----------|--------|------------------|
| **Fix Rate Limiter Memory Leak** | 🔴 **CRITICAL** | ⏳ Pending | 1 day |
| Move Resource Mapping to Config | High | ⏳ Pending | 0.5 day |
| Add Cache Invalidation | High | ⏳ Pending | 1 day |
| Config Refactoring | High | ⏳ Pending | 2-3 days |
| Auto Router Refactoring | High | ⏳ Pending | 3-4 days |
| **Total** | - | - | **7.5-9.5 days** |

### Key Documents

- **Config Refactoring**: See `gateway/CONFIG_REFACTORING_PROPOSAL.md`
- **Auto Router Refactoring**: See `gateway/AUTO_ROUTER_REFACTORING_PROPOSAL.md`
- **Implementation Checklist**: This document (Refactoring Tasks section)

### Implementation Phases

1. **Phase 1**: Fix Critical Issues (URGENT)
   - Fix rate limiter memory leak (CRITICAL)
   - Move resource mapping to config
   - Add cache invalidation

2. **Phase 2**: Config Refactoring (Foundation)
   - Consolidate 4 config files → 1 unified file
   - Add environment variable support
   - Update config loader

3. **Phase 3**: Auto Router Refactoring (Build on foundation)
   - Create `internal/router/utils/` package
   - Extract duplicate logic to utilities
   - Consolidate JWT validation
   - Remove duplicate CORS logic
   - Refactor all routers to use utilities

### Success Criteria

- ✅ **Rate limiter memory leak fixed** (CRITICAL)
- ✅ Resource mappings in config file (not hardcoded)
- ✅ Cache invalidation working
- ✅ All config in single file (`configs/gateway.yaml`)
- ✅ No duplicate config definitions
- ✅ All duplicate router logic in utilities
- ✅ JWT validation consolidated
- ✅ CORS logic deduplicated
- ✅ ~264 lines of code reduction
- ✅ All tests passing
- ✅ Documentation updated
- ✅ No functionality broken
- ✅ Memory usage stable (no leaks)

