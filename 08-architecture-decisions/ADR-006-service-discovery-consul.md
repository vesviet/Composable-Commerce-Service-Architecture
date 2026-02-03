# ADR-006: Service Discovery with Consul

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Platform Team, SRE Team, Architecture Team

## Context

With 21+ microservices running in a distributed environment, we need:
- Dynamic service registration and discovery
- Health checking capabilities
- Load balancing across service instances
- Configuration management
- Multi-environment support (local, staging, production)

We evaluated several service discovery solutions:
- **Consul**: Full-featured service mesh with health checking
- **Kubernetes Native Services**: Built-in K8s service discovery
- **Eureka**: Netflix OSS service discovery
- **etcd**: Distributed key-value store with service discovery

## Decision

We will use **HashiCorp Consul** for service discovery, health checking, and configuration management.

### Architecture Components:
1. **Consul Server**: Central service registry (clustered in production)
2. **Consul Clients**: Sidecar agents on each service instance
3. **Service Registration**: Automatic registration via go-kratos Consul integration
4. **Health Checking**: HTTP/TCP/gRPC health checks
5. **DNS Interface**: Service resolution via DNS names
6. **Key-Value Store**: Dynamic configuration storage

### Service Discovery Pattern:
- **Registration**: Services auto-register on startup via go-kratos Consul registry
- **Discovery**: Services discover others via Consul DNS or API
- **Health Checks**: Consul monitors service health every 10 seconds
- **Load Balancing**: DNS-based load balancing across healthy instances

### Integration Details:
- **go-kratos Registry**: `github.com/go-kratos/kratos/contrib/registry/consul/v2`
- **Service Naming**: `{service-name}.service.consul` (e.g., `auth.service.consul`)
- **Health Endpoints**: `/healthz` for HTTP, gRPC health service
- **Configuration**: Consul KV store for environment-specific configs

## Consequences

### Positive:
- ✅ **Multi-Environment**: Works in Docker Compose, Kubernetes, bare metal
- ✅ **Health Monitoring**: Built-in health checks and automatic deregistration
- ✅ **DNS Interface**: Simple service resolution via DNS
- ✅ **Configuration**: Centralized config management with Consul KV
- ✅ **Service Mesh**: Ready for advanced features like service mesh
- ✅ **UI Dashboard**: Consul UI for service visualization

### Negative:
- ⚠️ **Additional Infrastructure**: Need to maintain Consul cluster
- ⚠️ **Network Complexity**: Requires proper network configuration
- ⚠️ **Consul Dependency**: Services depend on Consul availability
- ⚠️ **Learning Curve**: Team needs to understand Consul concepts

### Risks:
- **Consul Failure**: Single point of failure (mitigated by clustering)
- **Network Partitions**: Split-brain scenarios (mitigated by consensus protocol)
- **Performance**: DNS resolution overhead (acceptable for our scale)

## Alternatives Considered

### 1. Kubernetes Native Services
- **Rejected**: Locks us into Kubernetes, doesn't work in Docker Compose
- **Pros**: Built-in, no additional infrastructure
- **Cons**: K8s-specific, limited health checking, no configuration management

### 2. Eureka
- **Rejected**: Netflix OSS in maintenance mode, less active development
- **Pros**: Netflix battle-tested, Spring Boot integration
- **Cons**: Java-centric, limited multi-language support

### 3. etcd
- **Rejected**: Primarily a key-value store, service discovery is add-on
- **Pros**: Strong consistency, Kubernetes backbone
- **Cons**: Limited service discovery features, no built-in health checking

## Implementation Guidelines

- All services must register with Consul on startup
- Implement proper health checks (`/healthz` endpoint)
- Use service names in format: `{service-name}.service.consul`
- Configure Consul client with proper retry and timeout settings
- Use Consul KV for dynamic configuration (feature flags, etc.)
- Monitor Consul cluster health and performance
- Implement proper security with ACL tokens in production

## References

- [Consul Documentation](https://www.consul.io/docs)
- [go-kratos Consul Integration](https://github.com/go-kratos/kratos/tree/main/contrib/registry/consul)
- [Service Discovery Patterns](https://microservices.io/patterns/service-discovery/index.html)
- [Consul vs Kubernetes Service Discovery](https://www.consul.io/docs/k8s/service-discovery)
