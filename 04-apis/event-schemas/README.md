# JSON Schema Directory (Event Contracts)

Place all event schemas here, one file per event (`event-name.schema.json`). Must be valid JSON Schema Draft 07 or newer.

## Usage & Workflow
1. Create new event contract as `event-name.schema.json` (e.g., `order-created.schema.json`).
2. Include all required fields, type, enum, $id with version.
3. Use [ajv-cli](https://ajv.js.org/), [jsonschema](https://pypi.org/project/jsonschema/) or similar to validate contract & payloads.
4. **Backwards-incompatible changes** require bumping $id or major version. Add deprecation note in schema file.

## Example
See `order.created.schema.json`.

---

**All event/message interface changes must be merged before producer/consumer update code.**
