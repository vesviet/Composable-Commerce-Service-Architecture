# ADR-017: Common Library Architecture

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Architecture Team, Development Team, Platform Team

## Context

With 21+ microservices sharing common patterns and functionality, we need:
- Code reuse across services to avoid duplication
- Consistent implementation of common patterns
- Centralized maintenance of shared utilities
- Version management and backward compatibility
- Testing and validation of shared components
- Dependency management across services

We evaluated several approaches for shared code:
- **Go Module**: Native Go dependency management
- **Monorepo**: Single repository with shared packages
- **Service Mesh**: Move common functionality to infrastructure
- **Copy-Paste**: Simple duplication (rejected for maintainability)

## Decision

We will use a **shared Go module** (`gitlab.com/ta-microservices/common`) for common functionality.

### Common Library Architecture:
1. **Go Module**: Native Go dependency management
2. **Semantic Versioning**: Versioned releases with backward compatibility
3. **Continuous Integration**: Automated testing and publishing
4. **Documentation**: Comprehensive documentation and examples
5. **Breaking Changes**: Clear communication and migration guides

### Module Structure:
```
common/
├── client/                 # HTTP/gRPC clients
├── config/                 # Configuration utilities
├── database/              # Database utilities and migrations
├── middleware/            # HTTP/gRPC middleware
├── auth/                  # Authentication utilities
├── events/                # Event publishing utilities
├── logging/               # Structured logging
├── metrics/               # Prometheus metrics
├── errors/                # Error handling utilities
├── validation/            # Input validation
└── utils/                 # General utilities
```

### Key Components:
- **HTTP Client**: Circuit breaker, retry logic, timeouts
- **Database**: Connection management, common patterns
- **Authentication**: JWT validation, middleware
- **Events**: Dapr event publishing utilities
- **Logging**: Structured logging with correlation IDs
- **Metrics**: Prometheus metrics collection
- **Configuration**: Viper-based configuration utilities
- **Validation**: Input validation and sanitization

### Version Management:
- **Semantic Versioning**: MAJOR.MINOR.PATCH format
- **Backward Compatibility**: No breaking changes in minor/patch versions
- **Release Process**: Automated releases with GitLab CI
- **Dependency Updates**: Regular updates to dependencies
- **Changelog**: Detailed change log for each version

### Integration Pattern:
```go
// Service go.mod
require gitlab.com/ta-microservices/common v1.9.5
```

### Development Workflow:
1. **Development**: Make changes in common module
2. **Testing**: Comprehensive testing including integration tests
3. **Version Bump**: Update version based on changes
4. **Release**: Automated release with GitLab CI
5. **Service Updates**: Services update to new version
6. **Validation**: Test services with new common version

## Consequences

### Positive:
- ✅ **Code Reuse**: Significant reduction in duplicated code
- ✅ **Consistency**: Standardized patterns across all services
- ✅ **Maintenance**: Centralized maintenance and bug fixes
- ✅ **Quality**: Comprehensive testing of shared components
- ✅ **Version Control**: Clear versioning and dependency management
- ✅ **Documentation**: Centralized documentation and examples

### Negative:
- ⚠️ **Version Complexity**: Managing versions across 21+ services
- ⚠️ **Breaking Changes**: Impact of breaking changes on all services
- ⚠️ **Development Bottleneck**: Common module changes affect all services
- ⚠️ **Testing Complexity**: Need comprehensive integration testing

### Risks:
- **Version Drift**: Services using different common versions
- **Breaking Changes**: Unintended breaking changes affecting services
- **Dependency Hell**: Complex dependency resolution issues
- **Single Point of Failure**: Bug in common module affects all services

## Alternatives Considered

### 1. Monorepo with Shared Packages
- **Rejected**: Complex build setup, tooling challenges
- **Pros**: Atomic commits, shared tooling
- **Cons**: Complex build setup, tooling complexity

### 2. Service Mesh (Infrastructure)
- **Rejected**: Moves complexity to infrastructure, less flexible
- **Pros**: No code dependencies, infrastructure-level features
- **Cons**: Complex infrastructure setup, less flexibility

### 3. Copy-Paste with Standards
- **Rejected**: High maintenance overhead, inconsistency risk
- **Pros**: Service autonomy, no version conflicts
- **Cons**: Duplication, maintenance nightmare

### 4. Micro Libraries
- **Rejected**: Too many small dependencies to manage
- **Pros**: Granular dependencies, smaller impact
- **Cons**: Dependency management complexity

## Implementation Guidelines

- Use semantic versioning strictly
- Maintain comprehensive test coverage
- Document all public APIs with examples
- Implement proper error handling and logging
- Use interfaces to allow for mocking and testing
- Regular security audits and dependency updates
- Provide migration guides for breaking changes
- Monitor usage and performance across services

## References

- [Go Modules Documentation](https://go.dev/blog/using-go-modules)
- [Semantic Versioning](https://semver.org/)
- [Microservices Common Patterns](https://microservices.io/patterns/)
- [Go Best Practices](https://golang.org/doc/effective_go.html)
