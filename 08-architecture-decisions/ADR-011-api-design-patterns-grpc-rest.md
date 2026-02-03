# ADR-011: API Design Patterns (REST + gRPC)

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Architecture Team, API Team, Development Team

## Context

With 21+ microservices, we need a consistent API strategy that supports:
- Internal service-to-service communication
- External client access (web, mobile, third-party)
- High performance and low latency
- Strong typing and contract enforcement
- Easy integration and documentation
- Future-proofing and evolution

We evaluated several API approaches:
- **REST only**: Simple, widely adopted, but performance limitations
- **gRPC only**: High performance, but limited external access
- **GraphQL**: Flexible queries, but complexity and caching challenges
- **Dual API (REST + gRPC)**: Best of both worlds with proper separation

## Decision

We will use **dual API approach**: **gRPC for internal service communication** and **REST for external client access**.

### API Architecture:
1. **gRPC**: Internal service-to-service communication
2. **REST**: External client access (web, mobile, third-party)
3. **API Gateway**: Single entry point for external requests
4. **Protocol Buffers**: Strong typing and code generation
5. **OpenAPI/Swagger**: REST API documentation
6. **Service Mesh**: Advanced routing and load balancing

### gRPC Usage:
- **Internal Communication**: All service-to-service calls
- **Performance**: Binary protocol, HTTP/2, low latency
- **Code Generation**: Auto-generated client/server stubs
- **Streaming**: Bidirectional streaming for real-time updates
- **Load Balancing**: Client-side load balancing via Consul

### REST Usage:
- **External Clients**: Web frontend, mobile apps, third-party integrations
- **API Gateway**: Single entry point with authentication and rate limiting
- **Documentation**: OpenAPI/Swagger for interactive documentation
- **Browser Compatibility**: Works with web browsers and HTTP clients
- **Caching**: HTTP caching headers and CDN integration

### API Gateway Pattern:
```
External Client → API Gateway (REST) → Internal Services (gRPC)
```

### Protocol Buffer Design:
- **Versioning**: Use semantic versioning in proto packages
- **Validation**: Built-in field validation rules
- **Enums**: Use enums for fixed value sets
- **Messages**: Clear, descriptive message definitions
- **Services**: Logical grouping of related operations

## Consequences

### Positive:
- ✅ **Performance**: gRPC provides high-performance internal communication
- ✅ **Compatibility**: REST works with all external clients
- ✅ **Type Safety**: Protocol buffers provide strong typing
- ✅ **Documentation**: Auto-generated docs from proto files
- ✅ **Evolution**: Protocol buffer evolution supports backward compatibility
- ✅ **Monitoring**: Built-in metrics and tracing support

### Negative:
- ⚠️ **Complexity**: Need to maintain two API protocols
- ⚠️ **Learning Curve**: Team needs to learn gRPC and Protocol Buffers
- ⚠️ **Tooling**: Additional tooling for proto compilation and code generation
- ⚠️ **Debugging**: gRPC debugging more complex than REST

### Risks:
- **Protocol Mismatch**: REST and gRPC models diverging over time
- **Performance Bottleneck**: API Gateway becoming bottleneck
- **Version Conflicts**: gRPC and REST version synchronization
- **Skill Gaps**: Team unfamiliar with gRPC concepts

## Alternatives Considered

### 1. REST Only
- **Rejected**: Performance limitations for internal communication
- **Pros**: Simple, widely adopted, easy debugging
- **Cons**: Higher latency, text-based protocol, limited streaming

### 2. gRPC Only
- **Rejected**: Poor browser support, limited external access
- **Pros**: High performance, strong typing, streaming support
- **Cons**: Browser compatibility, external integration challenges

### 3. GraphQL
- **Rejected**: Complexity, caching challenges, over-fetching issues
- **Pros**: Flexible queries, single endpoint, strong typing
- **Cons**: Complex implementation, caching difficulties, N+1 queries

### 4. REST + JSON API
- **Rejected**: Less efficient than gRPC for internal communication
- **Pros**: Standardized, widely adopted
- **Cons**: Text-based protocol, no streaming, higher overhead

## Implementation Guidelines

- Define all APIs in Protocol Buffer files first
- Use go-kratos gRPC+HTTP gateway for dual protocol support
- Implement proper API versioning (v1, v2, etc.)
- Use OpenAPI/Swagger for REST documentation
- Implement proper error handling and status codes
- Use API Gateway for authentication, rate limiting, and routing
- Implement proper request/response validation
- Monitor API performance and error rates

## References

- [gRPC Documentation](https://grpc.io/docs/)
- [Protocol Buffers](https://developers.google.com/protocol-buffers)
- [go-kratos API Design](https://go-kratos.dev/docs/api/)
- [API Gateway Patterns](https://microservices.io/patterns/apigateway/)
- [REST API Design Best Practices](https://restfulapi.net/)
