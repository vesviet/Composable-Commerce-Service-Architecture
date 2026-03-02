# Event Schemas (JSON Schema Contracts)

All event schemas are stored here, one file per event type. Format: `domain.action.schema.json`.

## Standard Envelope Format

Every event MUST use the structured envelope format:

```json
{
  "event_id": "uuid",           // Required: unique event instance ID (for idempotency)
  "event_type": "domain.action", // Required: event type identifier
  "event_version": "1.0",       // Required: schema version for evolution
  "timestamp": "ISO 8601",      // Required: when event occurred
  "source": "service-name",     // Required: producing service
  "data": {                     // Required: event-specific payload
    // ... domain fields
  }
}
```

## Naming Convention
- Files: `domain.action.schema.json` (e.g., `order.created.schema.json`)
- Field casing: `snake_case` for all fields
- Event types: `domain.action` (e.g., `order.created`, `inventory.reserved`)

## Workflow
1. Create/update event schema as `domain.action.schema.json`.
2. Include `event_id`, `event_type`, `event_version`, `timestamp`, `source`, and `data` fields.
3. Add `examples` section with a complete sample payload.
4. Validate with [ajv-cli](https://ajv.js.org/) or [jsonschema](https://pypi.org/project/jsonschema/).
5. **Backwards-incompatible changes** require bumping `event_version`. Add deprecation note.

## Example
See `inventory.reserved.schema.json` for the canonical format.

---

**All event/message interface changes must be merged before producer/consumer update code.**
