# ADR-014: Configuration Management

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Platform Team, DevOps Team, Development Team

## Context

With 21+ microservices across multiple environments, we need:
- Environment-specific configuration management
- Secure handling of sensitive data (passwords, API keys)
- Configuration validation and type safety
- Hot configuration updates without restarts
- Configuration versioning and audit trails
- Developer-friendly configuration patterns

We evaluated several configuration approaches:
- **File-based + Environment Variables**: Simple, container-friendly
- **Consul KV**: Centralized configuration with service discovery
- **Kubernetes ConfigMaps/Secrets**: Native cloud configuration
- **Spring Cloud Config**: Java-centric configuration server

## Decision

We will use **file-based configuration with environment variables** for base configuration and **Consul KV for dynamic configuration**.

### Configuration Architecture:
1. **Base Configuration**: YAML files in service `configs/` directory
2. **Environment Variables**: Container-specific overrides
3. **Consul KV**: Dynamic configuration and feature flags
4. **Configuration Validation**: Type-safe configuration loading
5. **Secrets Management**: Environment variables for sensitive data
6. **Configuration Hierarchy**: Override precedence system

### Configuration Sources (in order of precedence):
1. **Environment Variables**: Highest precedence
2. **Consul KV**: Dynamic configuration
3. **Config Files**: Base configuration
4. **Default Values**: Built-in defaults

### File Structure:
```
service/
├── configs/
│   ├── config.yaml          # Base configuration
│   ├── config-dev.yaml      # Development overrides
│   ├── config-staging.yaml   # Staging overrides
│   └── config-production.yaml # Production overrides
```

### Configuration Categories:
- **Database**: Connection strings, pool settings
- **Service**: Ports, timeouts, retry policies
- **External APIs**: URLs, authentication, rate limits
- **Features**: Feature flags and toggles
- **Monitoring**: Metrics, tracing, logging settings
- **Security**: JWT settings, CORS policies

### Dynamic Configuration:
- **Feature Flags**: Enable/disable features without deployment
- **Rate Limits**: Adjust rate limits dynamically
- **Circuit Breakers**: Modify circuit breaker settings
- **Logging Levels**: Change log levels without restart

### Security Considerations:
- **Secrets**: Never store in Git, use environment variables
- **Encryption**: Sensitive configuration encrypted in Consul
- **Access Control**: RBAC for Consul KV access
- **Audit Trail**: Configuration change logging

## Consequences

### Positive:
- ✅ **Simple**: Easy to understand and implement
- ✅ **Container-Friendly**: Works well with Docker and Kubernetes
- ✅ **Flexible**: Multiple configuration sources and override mechanisms
- ✅ **Dynamic**: Consul KV enables runtime configuration changes
- ✅ **Secure**: Proper separation of config and secrets
- ✅ **Developer-Friendly**: Local development with file-based config

### Negative:
- ⚠️ **Complexity**: Multiple configuration sources can be confusing
- ⚠️ **Consul Dependency**: Dynamic config requires Consul availability
- ⚠️ **Validation**: Need comprehensive configuration validation
- ⚠️ **Documentation**: Requires good documentation of all config options

### Risks:
- **Configuration Drift**: Different environments having inconsistent config
- **Secret Exposure**: Accidental commit of sensitive configuration
- **Consul Failure**: Dynamic configuration unavailable if Consul down
- **Validation Errors**: Invalid configuration causing service failures

## Alternatives Considered

### 1. Consul KV Only
- **Rejected**: Complex for local development, single point of failure
- **Pros**: Centralized, dynamic, access control
- **Cons**: Complex setup, local development challenges

### 2. Kubernetes ConfigMaps/Secrets
- **Rejected**: Locks us to Kubernetes, complex for local development
- **Pros**: Native Kubernetes, built-in secret management
- **Cons**: K8s-specific, complex local development

### 3. Spring Cloud Config
- **Rejected**: Java-centric, doesn't fit our Go stack
- **Pros**: Mature, feature-rich
- **Cons**: Java ecosystem only, additional infrastructure

### 4. Environment Variables Only
- **Rejected**: Complex to manage, no validation, no dynamic updates
- **Pros**: Simple, container-friendly
- **Cons**: No structure, no validation, no dynamic updates

## Implementation Guidelines

- Use Viper for configuration loading and management
- Implement comprehensive configuration validation
- Use environment-specific config files
- Store secrets in environment variables, never in Git
- Use Consul KV for dynamic configuration and feature flags
- Implement configuration hot-reload where appropriate
- Document all configuration options and their effects
- Use configuration schemas for validation and documentation

## References

- [Viper Configuration Library](https://github.com/spf13/viper)
- [Twelve-Factor App - Configuration](https://12factor.net/config)
- [Consul KV Store](https://www.consul.io/docs/dynamic-app-config/kv)
- [Configuration Best Practices](https://microservices.io/patterns/configuration/index.html)
