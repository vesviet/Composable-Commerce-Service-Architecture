# ADR-010: Observability Stack (Prometheus + Jaeger)

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Platform Team, SRE Team, Development Team

## Context

With 21+ microservices in a distributed system, we need comprehensive observability:
- Metrics collection and monitoring for performance analysis
- Distributed tracing for request flow visualization
- Alerting for proactive issue detection
- Debugging capabilities for complex distributed systems
- Service dependency mapping
- Performance bottleneck identification

We evaluated several observability solutions:
- **Prometheus + Jaeger**: Metrics + distributed tracing
- **Datadog**: Commercial all-in-one solution
- **New Relic**: Commercial APM solution
- **OpenTelemetry + Vendor**: Open standards with backend choice

## Decision

We will use **Prometheus for metrics** and **Jaeger for distributed tracing** with OpenTelemetry instrumentation.

### Observability Stack:
1. **Prometheus**: Metrics collection and storage
2. **Jaeger**: Distributed tracing and visualization
3. **Grafana**: Metrics visualization and dashboards
4. **OpenTelemetry**: Standardized instrumentation
5. **AlertManager**: Alert routing and notification
6. **Dapr Telemetry**: Built-in observability features

### Metrics Architecture:
- **Collection**: Prometheus scrapes metrics from all services
- **Format**: OpenMetrics format via HTTP endpoints
- **Storage**: Time-series database with configurable retention
- **Visualization**: Grafana dashboards per service and system-wide
- **Alerting**: AlertManager for routing alerts to teams

### Tracing Architecture:
- **Instrumentation**: OpenTelemetry Go SDK in all services
- **Propagation**: W3C Trace Context headers
- **Collection**: Jaeger collector receives traces from services
- **Storage**: Elasticsearch backend for trace storage
- **Visualization**: Jaeger UI for trace analysis

### Integration Points:
- **go-kratos**: Built-in Prometheus metrics integration
- **Dapr**: Automatic metrics and tracing collection
- **Consul**: Service discovery for Prometheus targets
- **GitLab CI**: Performance testing with metrics collection

## Consequences

### Positive:
- ✅ **Open Source**: No licensing costs, full control
- ✅ **Standardized**: OpenTelemetry provides vendor-neutral standards
- ✅ **Scalable**: Can handle high-volume metrics and traces
- ✅ **Integrations**: Rich ecosystem of exporters and integrations
- ✅ **Debugging**: Powerful distributed tracing for complex issues
- ✅ **Alerting**: Proactive monitoring and alerting capabilities

### Negative:
- ⚠️ **Complexity**: Multiple components to maintain and configure
- ⚠️ **Storage Costs**: Time-series data requires significant storage
- ⚠️ **Learning Curve**: Team needs to learn Prometheus query language
- ⚠️ **Resource Usage**: Observability stack consumes resources

### Risks:
- **Storage Growth**: Unbounded growth of metrics and traces
- **Performance Impact**: Instrumentation overhead on services
- **Complex Debugging**: Distributed systems debugging complexity
- **Alert Fatigue**: Too many alerts leading to ignored notifications

## Alternatives Considered

### 1. Datadog
- **Rejected**: High cost, vendor lock-in
- **Pros**: All-in-one solution, great UI, minimal setup
- **Cons**: Expensive, less control, vendor dependency

### 2. New Relic
- **Rejected**: Similar to Datadog - high cost and vendor lock-in
- **Pros**: Comprehensive APM, good user experience
- **Cons**: Expensive, less flexibility

### 3. OpenTelemetry + Cloud Backend
- **Rejected**: Would require cloud provider dependency
- **Pros**: Standardized instrumentation, managed backend
- **Cons**: Cloud provider lock-in, potential costs

### 4. Zipkin
- **Rejected**: Jaeger has better features and UI
- **Pros**: Simpler setup, widely adopted
- **Cons**: Fewer features, less active development

## Implementation Guidelines

- Instrument all services with OpenTelemetry Go SDK
- Export metrics in Prometheus format on `/metrics` endpoint
- Implement proper sampling strategies for traces
- Create Grafana dashboards for key metrics
- Set up AlertManager with proper routing rules
- Use Dapr telemetry for automatic instrumentation
- Implement service-level objectives (SLOs) and error budgets
- Regularly review and optimize observability costs

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Go](https://opentelemetry.io/docs/instrumentation/go/)
- [Dapr Observability](https://docs.dapr.io/developing-applications/building-blocks/observability/)
- [Observability Best Practices](https://sre.google/workbook/monitoring-distributed-systems/)
