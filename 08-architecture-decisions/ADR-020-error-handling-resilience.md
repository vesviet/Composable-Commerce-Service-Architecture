# ADR-020: Error Handling and Resilience Patterns

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Architecture Team, Development Team, SRE Team

## Context

With 21+ microservices communicating over networks, we need:
- Consistent error handling across all services
- Resilience to network failures and service unavailability
- Graceful degradation when services are down
- Circuit breaker patterns to prevent cascading failures
- Retry mechanisms for transient failures
- Proper error communication to clients

We evaluated several error handling approaches:
- **Go-native errors**: Simple error handling with custom types
- **Circuit breaker libraries**: Hystrix, Resilience4j equivalents
- **Service mesh resilience**: Istio, Linkerd features
- **Custom implementation**: Build our own resilience patterns

## Decision

We will use **Go-native error handling with custom error types** and **circuit breaker implementation** for resilience.

### Error Handling Architecture:
1. **Custom Error Types**: Structured error types with context
2. **Error Wrapping**: Proper error wrapping with context
3. **HTTP Error Responses**: Consistent error response format
4. **Circuit Breaker**: Prevent cascading failures
5. **Retry Logic**: Exponential backoff for transient failures
6. **Graceful Degradation**: Fallback mechanisms

### Error Types:
```go
type ErrorCode string

const (
    ErrCodeValidation     ErrorCode = "VALIDATION_ERROR"
    ErrCodeNotFound       ErrorCode = "NOT_FOUND"
    ErrCodeUnauthorized   ErrorCode = "UNAUTHORIZED"
    ErrCodeForbidden      ErrorCode = "FORBIDDEN"
    ErrCodeConflict       ErrorCode = "CONFLICT"
    ErrCodeRateLimit      ErrorCode = "RATE_LIMIT"
    ErrCodeInternal       ErrorCode = "INTERNAL_ERROR"
    ErrCodeServiceUnavailable ErrorCode = "SERVICE_UNAVAILABLE"
)

type AppError struct {
    Code    ErrorCode `json:"code"`
    Message string    `json:"message"`
    Details string    `json:"details,omitempty"`
    Cause   error     `json:"-"`
}
```

### Error Response Format:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request parameters",
    "details": "Email field is required",
    "timestamp": "2026-02-03T10:30:45Z",
    "request_id": "req-123456"
  }
}
```

### Resilience Patterns:
- **Circuit Breaker**: Prevent calls to failing services
- **Retries**: Exponential backoff for transient failures
- **Timeouts**: Prevent hanging requests
- **Bulkheads**: Isolate resources to prevent total failure
- **Fallbacks**: Alternative logic when services fail
- **Graceful Degradation**: Reduced functionality during outages

### Circuit Breaker Configuration:
- **Failure Threshold**: 5 failures in a row
- **Timeout**: 60 seconds in open state
- **Half-open Requests**: 3 requests to test recovery
- **Success Threshold**: 3 successes to close circuit

### Retry Strategy:
- **Max Retries**: 3 attempts for transient failures
- **Backoff**: Exponential backoff with jitter
- **Retryable Errors**: Network timeouts, 5xx responses
- **Non-Retryable**: 4xx client errors, validation errors

### Timeout Configuration:
- **HTTP Client**: 30 seconds total timeout
- **Database**: 10 seconds query timeout
- **External APIs**: 15 seconds timeout
- **Circuit Breaker**: 5 seconds detection timeout

## Consequences

### Positive:
- ✅ **Consistency**: Standardized error handling across services
- ✅ **Resilience**: Circuit breakers prevent cascading failures
- ✅ **Debugging**: Structured errors with context and causality
- ✅ **User Experience**: Graceful degradation during failures
- ✅ **Monitoring**: Clear error metrics and alerting
- ✅ **Maintainability**: Centralized error handling patterns

### Negative:
- ⚠️ **Complexity**: Additional code complexity for resilience
- ⚠️ **Performance**: Circuit breaker and retry overhead
- ⚠️ **Learning Curve**: Team needs to understand resilience patterns
- ⚠️ **Testing**: Complex error scenarios to test

### Risks:
- **Circuit Breaker Misconfiguration**: Too sensitive or too lenient
- **Retry Storms**: Too many retries overwhelming services
- **Error Masking**: Important errors being hidden by fallbacks
- **Performance Impact**: Resilience patterns affecting performance

## Alternatives Considered

### 1. Service Mesh Resilience (Istio)
- **Rejected**: Complex infrastructure, overkill for current needs
- **Pros**: Infrastructure-level resilience, no code changes
- **Cons**: Complex setup, operational overhead

### 2. Hystrix-like Library
- **Rejected**: No mature Go equivalent, maintenance overhead
- **Pros**: Proven patterns, comprehensive features
- **Cons**: No good Go equivalent, maintenance burden

### 3. Simple Error Handling Only
- **Rejected**: No resilience to failures, cascading failures
- **Pros**: Simple, less code
- **Cons**: No resilience, cascading failures

### 4. External Service (API Gateway)
- **Rejected**: Single point of failure, limited flexibility
- **Pros**: Centralized control
- **Cons**: Single point of failure, limited flexibility

## Implementation Guidelines

- Implement consistent error types and responses
- Use circuit breakers for all external service calls
- Implement proper retry logic with exponential backoff
- Set appropriate timeouts for all operations
- Implement graceful degradation where possible
- Monitor error rates and circuit breaker states
- Test failure scenarios regularly
- Document error codes and handling procedures

## References

- [Go Error Handling Best Practices](https://go.dev/blog/errors-are-values)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Resilience Patterns](https://microservices.io/patterns/reliability/)
- [Graceful Degradation](https://12factor.net/backing-services)
