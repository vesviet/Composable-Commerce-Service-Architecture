# ADR-003: Dapr Pub/Sub vs Direct Redis Streams for Event Messaging

**Date:** 2025-11-17  
**Status:** Accepted  
**Deciders:** Platform Team, SRE Team

## Context

We need to choose between:
1. **Dapr Pub/Sub** (abstraction layer, uses Redis Streams backend)
2. **Direct Redis Streams** (direct Redis client access)

Both approaches are currently used in the codebase:
- Most services use Dapr Pub/Sub (HTTP API)
- Some workers use direct Redis Streams for performance

We need a consistent approach for maintainability and portability.

## Decision

**Use Dapr Pub/Sub as the primary pattern** for all services, with **direct Redis Streams as an exception** for high-performance workers only.

### When to Use Dapr Pub/Sub:
- ✅ **All service-to-service events** (Order, Payment, Warehouse, Catalog, etc.)
- ✅ **Standard event publishing** (via Dapr HTTP API)
- ✅ **When portability matters** (can switch backend to Kafka/RabbitMQ later)
- ✅ **When built-in features needed** (retry, dead letter queue, observability)

### When to Use Direct Redis Streams:
- ✅ **High-performance workers** (Fulfillment workers processing 1000+ events/sec)
- ✅ **When Dapr overhead is unacceptable** (<5ms latency requirement)
- ✅ **Standalone event processors** (not part of main service)

### Hybrid Approach:
- **Services publish via Dapr** → Events stored in Redis Streams
- **Workers can read directly from Redis Streams** (same stream, different consumer)
- This provides best of both worlds: standardized publishing + high-performance consumption

## Consequences

### Positive:
- ✅ **Standardization**: Most services use same pattern (Dapr)
- ✅ **Portability**: Can switch backend without code changes
- ✅ **Built-in Features**: Retry, DLQ, observability out of the box
- ✅ **Performance Option**: Workers can use direct Redis when needed
- ✅ **Flexibility**: Hybrid approach allows optimization where needed

### Negative:
- ⚠️ **Dual Patterns**: Two patterns to maintain (mitigated by clear guidelines)
- ⚠️ **Dapr Dependency**: Services depend on Dapr sidecar (acceptable trade-off)
- ⚠️ **Learning Curve**: Team must understand both patterns

### Risks:
- **Pattern Confusion**: Mitigated by clear documentation and code reviews
- **Dapr Overhead**: ~5-10ms overhead acceptable for most use cases

## Alternatives Considered

### 1. Dapr Only
- **Rejected**: Some workers need <5ms latency, Dapr adds overhead

### 2. Direct Redis Streams Only
- **Rejected**: Loses portability, must implement retry/DLQ ourselves, harder to maintain

### 3. Kafka
- **Rejected**: Overkill for current scale, adds infrastructure complexity

## Implementation Guidelines

- **Default**: Use Dapr Pub/Sub for all new services
- **Exception**: Use direct Redis Streams only with architecture team approval
- **Documentation**: Clearly document which pattern each component uses
- **Monitoring**: Track event latency for both patterns

## References

- See `/docs/backup-2025-11-17/DAPR_VS_REDIS_STREAMS_COMPARISON.md` for detailed comparison
- [Dapr Pub/Sub](https://docs.dapr.io/developing-applications/building-blocks/pubsub/)
- [Redis Streams](https://redis.io/docs/data-types/streams/)

