# OpenAPI Directory (API Contracts)

Put all service OpenAPI specs here, one file per service. Format: openapi.yaml or swagger.yaml, versioned incrementally.

## How to add/update API contract
1. Create/update `your-service.openapi.yaml`. Use OpenAPI 3.x standard.
2. Add examples, schemas, enums, response codes.
3. Validate with [openapi-generator-cli](https://openapi-generator.tech/) or Swagger Editor.
4. Review: PR must @mention service owner and integration team.

## Example:
See `gateway.openapi.yaml` for format sample.

---

**All API changes via contract-first workflow.**
