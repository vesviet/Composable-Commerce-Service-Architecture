# Event Contract: {event-type}

**Event Type:** `{service}.{domain}.{action}`  
**Version:** `v{version}`  
**Schema:** [`json-schema/{event-type}.schema.json`](../json-schema/{event-type}.schema.json)  
**Last Updated:** {YYYY-MM-DD}  
**Status:** {Draft|Active|Deprecated}

## Overview

{Brief description of what this event represents and when it is published}

## Publisher

**Service:** {Service Name}  
**Component:** {Component/Handler Name}  
**Trigger:** {When is this event published? e.g., "When an order status changes to CONFIRMED"}

## Subscribers

| Service | Handler | Purpose |
|---------|---------|---------|
| {Service Name} | {Handler Name} | {What does this service do with the event?} |

## Event Schema

See full JSON Schema: [`{event-type}.schema.json`](../json-schema/{event-type}.schema.json)

### Key Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Event type: `{service}.{domain}.{action}` |
| `source` | string (URI) | Yes | Service that published the event |
| `id` | string (UUID) | Yes | Unique event identifier |
| `time` | string (ISO 8601) | Yes | Event timestamp |
| `data.{field}` | {type} | {Yes/No} | {Description} |

### Example Payload

```json
{
  "specversion": "1.0",
  "type": "{service}.{domain}.{action}",
  "source": "https://api.company.com/services/{service-name}",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "time": "2025-11-17T10:00:00Z",
  "datacontenttype": "application/json",
  "data": {
    "{field-name}": "{example-value}"
  },
  "metadata": {
    "correlationId": "550e8400-e29b-41d4-a716-446655440001",
    "traceId": "1234567890abcdef"
  }
}
```

## Publishing

### Via Dapr Pub/Sub

```go
// Example Go code
event := EventData{
    EventType: "{service}.{domain}.{action}",
    // ... other fields
}

daprClient.PublishEvent(ctx, "pubsub-redis", "{event-type}", event)
```

### Via HTTP (Dapr Sidecar)

```bash
curl -X POST http://localhost:3500/v1.0/publish/pubsub-redis/{event-type} \
  -H "Content-Type: application/json" \
  -d @event-payload.json
```

## Subscribing

### Dapr Subscription Configuration

```yaml
apiVersion: dapr.io/v2alpha1
kind: Subscription
metadata:
  name: {service-name}-{event-type}-subscription
spec:
  pubsubname: pubsub-redis
  topic: {event-type}
  routes:
    default: /api/v1/events/{event-type}
  scopes:
    - {service-name}
```

### Handler Implementation

```go
// Example Go handler
func (s *Service) HandleEvent(ctx context.Context, event *Event) error {
    // Process event
    return nil
}
```

## Versioning

### Current Version: v{version}

- **Breaking Changes:** {List any breaking changes}
- **Migration Guide:** {Link to migration guide if applicable}

### Previous Versions

- **v{previous-version}:** {Description of previous version, deprecation date}

## Backward Compatibility

{Describe backward compatibility strategy}

## Testing

### Publishing Test Event

```bash
# Publish test event via Dapr
curl -X POST http://localhost:3500/v1.0/publish/pubsub-redis/{event-type} \
  -H "Content-Type: application/json" \
  -d '{
    "specversion": "1.0",
    "type": "{service}.{domain}.{action}",
    "source": "https://api.company.com/services/{service-name}",
    "id": "test-event-001",
    "time": "2025-11-17T10:00:00Z",
    "datacontenttype": "application/json",
    "data": {
      "{field-name}": "{test-value}"
    }
  }'
```

### Validating Schema

```bash
# Validate event payload against schema
ajv validate -s docs/json-schema/{event-type}.schema.json -d event-payload.json
```

## Related Events

- **Triggers:** {List events that trigger this event}
- **Triggered By:** {List events that are triggered by this event}

## References

- [CloudEvents Specification](https://github.com/cloudevents/spec)
- [Dapr Pub/Sub Documentation](https://docs.dapr.io/developing-applications/building-blocks/pubsub/)
- [Event-Driven Architecture ADR](../adr/ADR-001-event-driven-architecture.md)

