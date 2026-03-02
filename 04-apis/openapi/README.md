# OpenAPI Directory (API Contracts)

All service OpenAPI specs are stored here, one file per service. These are **auto-generated from Protocol Buffer definitions** using `protoc-gen-openapi`.

## Proto-First Workflow
1. Define/update service API in `api/<service>/v1/*.proto` files.
2. Run `make api` or `protoc` to regenerate OpenAPI spec.
3. Generated spec is output to `docs/04-apis/openapi/<service>.openapi.yaml`.
4. PR must @mention service owner and integration team.

> **Note**: Do NOT manually edit these YAML files — changes will be overwritten on next proto generation. To modify API contracts, update the `.proto` source files.

## File Format
- OpenAPI 3.0.3 standard
- One file per service: `<service-name>.openapi.yaml`
- Version: `0.0.1` (auto-generated, not manually versioned)

## Example
See `gateway.openapi.yaml` for format sample.

---

**All API changes via proto-first workflow.**
