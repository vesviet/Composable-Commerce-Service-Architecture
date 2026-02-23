# ADR-018: Local Development Environment

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Development Team, Platform Team, DevOps Team

## Context

With 21+ microservices, developers need an efficient local development setup that:
- Provides production-like environment
- Supports hot reload and fast iteration
- Works across different developer machines
- Integrates with existing tooling and workflows
- Minimizes resource usage and setup complexity
- Enables debugging and troubleshooting

We evaluated several local development approaches:
- **Docker Compose + Tilt**: Containerized with hot reload
- **Local Binaries**: Native Go execution with local databases
- **K3d + Skaffold**: Local Kubernetes cluster
- **VM-based Development**: Full virtualized environment

## Decision

We will use **Docker Compose for infrastructure** with **Tilt for hot reload and orchestration**.

### Development Architecture:
1. **Docker Compose**: Infrastructure services (databases, Redis, etc.)
2. **Tilt**: Hot reload and service orchestration
3. **Local Go Execution**: Services run locally for fast iteration
4. **Shared Infrastructure**: Common databases and message brokers
5. **Development Tools**: Integrated debugging and profiling

### Infrastructure Components:
```yaml
# docker-compose.yml services
- consul: Service discovery
- postgres: Shared database
- redis: Caching and pub/sub
- elasticsearch: Search service
- jaeger: Distributed tracing
- prometheus: Metrics collection
```

### Tilt Configuration:
- **Hot Reload**: Automatic rebuild on code changes
- **Service Dependencies**: Proper startup ordering
- **Resource Management**: Efficient resource usage
- **Live Updates**: Fast iteration without full rebuilds
- **Port Forwarding**: Easy access to services

### Development Workflow:
1. **Setup**: Clone repository, run `tilt up`
2. **Infrastructure**: Docker Compose starts shared services
3. **Development**: Tilt watches for code changes
4. **Hot Reload**: Services rebuild and restart on changes
5. **Debugging**: Integrated debugging with IDE support
6. **Testing**: Run tests against local environment

### Developer Experience:
- **Fast Startup**: Services start in seconds, not minutes
- **Live Updates**: See changes immediately without manual restarts
- **Consistent Environment**: Same as production infrastructure
- **Easy Debugging**: Native Go debugging with breakpoints
- **Resource Efficiency**: Only run needed services
- **IDE Integration**: Works with VS Code, GoLand, etc.

### Configuration Management:
- **Environment Variables**: Local development configuration
- **Volume Mounts**: Live code mounting for hot reload
- **Port Mapping**: Consistent port assignments
- **Network Configuration**: Service communication setup

## Consequences

### Positive:
- ✅ **Productivity**: Fast iteration with hot reload
- ✅ **Consistency**: Production-like environment locally
- ✅ **Resource Efficiency**: Only run necessary services
- ✅ **Easy Setup**: Simple `tilt up` to start development
- ✅ **Debugging**: Native Go debugging capabilities
- ✅ **Team Consistency**: Same setup across all developers

### Negative:
- ⚠️ **Resource Usage**: Docker containers consume memory/CPU
- ⚠️ **Complexity**: Tilt learning curve and configuration
- ⚠️ **Performance**: Slower than native binary execution
- ⚠️ **Dependencies**: Docker and Tilt required

### Risks:
- **Resource Constraints**: Developer machines may lack resources
- **Tilt Configuration**: Complex Tiltfile maintenance
- **Environment Drift**: Local environment diverging from production
- **Performance Issues**: Slow hot reload affecting productivity

## Alternatives Considered

### 1. Local Binaries Only
- **Rejected**: Complex setup, inconsistent environments
- **Pros**: Fastest execution, no container overhead
- **Cons**: Complex setup, environment inconsistency

### 2. Full Kubernetes (k3d)
- **Rejected**: Too heavy for local development
- **Pros**: Production-like environment
- **Cons**: Resource intensive, slow startup

### 3. Docker Compose Only
- **Rejected**: No hot reload, manual service management
- **Pros**: Simple, containerized environment
- **Cons**: No hot reload, manual service restarts

### 4. VM-based Development
- **Rejected**: Heavy, slow, resource intensive
- **Pros**: Isolated environment
- **Cons**: Very heavy, slow, poor developer experience

## Implementation Guidelines

- Provide comprehensive setup documentation
- Use consistent port assignments across services
- Implement proper health checks in Tilt configuration
- Optimize Docker images for fast builds
- Provide debugging configurations for popular IDEs
- Monitor resource usage and provide optimization guidelines
- Regularly update Tilt configuration and dependencies
- Provide troubleshooting guides for common issues

## References

- [Tilt Documentation](https://tilt.dev/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Local Development Best Practices](https://microservices.io/patterns/local-development/)
- [Go Hot Reload Techniques](https://github.com/cosmtrek/air)
