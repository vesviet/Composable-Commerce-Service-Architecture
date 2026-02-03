# gRPC Proto & Versioning Rules

This document outlines the standards for defining Protocol Buffers (Protos), versioning services, and generating code within our microservices ecosystem.

## 1. Proto Style Guide

We follow the [Google API Design Guide](https://cloud.google.com/apis/design) and [Buf Style Guide](https://buf.build/docs/style-guide).

### Naming Conventions

| Item | Convention | Example |
|------|------------|---------|
| **File Names** | `snake_case.proto` | `order_service.proto`, `user.proto`, `payment.proto` |
| **Package Names** | `versioned.snake_case` | `api.order.v1`, `api.common.v1`, `api.payment.v1` |
| **Message Names** | `PascalCase` | `CreateOrderRequest`, `UserProfile` |
| **Field Names** | **`snake_case`** (Strict) | `user_id`, `first_name`, `address_line_1` |
| **RPC Names** | `PascalCase` | `GetOrder`, `ListUsers` |
| **Enums** | `PascalCase` | `OrderStatus` |
| **Enum Values** | `UPPER_SNAKE_CASE` | `ORDER_STATUS_PENDING`, `ORDER_STATUS_SHIPPED` |

> [!IMPORTANT]
> **Why `snake_case` for fields?**
> Protobuf compilers automatically generate:
> - `PascalCase` struct fields for Go (e.g., `user_id` -> `UserId`).
> - `camelCase` JSON keys for HTTP APIs (e.g., `user_id` -> `userId`).
>
> Using `camelCase` in `.proto` files (e.g., `userId`) will result in `userId` in JSON, which is consistent, BUT strict `snake_case` is the canonical standard for Protobuf.

### Directory Structure

```text
service-name/
├── api/
│   └── service-name/
│       └── v1/
│           ├── service.proto      # Main service definition
│           └── messages.proto     # Data messages (optional split)
├── internal/                      # Private implementation
└── go.mod
```

### Deprecation

- Use the `deprecated = true` option for fields or messages that are no longer used.
- Do **not** reuse field numbers of deleted fields. `reserve` them instead.

```protobuf
message User {
  string id = 1;
  reserved 2; // Reserved deleted field
  reserved "username";
  // string username = 2 [deprecated = true]; // Alternative: keep but deprecated
}
```

---

## 2. Versioning Strategy

We use **Semantic Versioning** for Go modules and **Directory-based Versioning** for APIs.

### API Versioning (Protos)

- **v1, v2, vNext**: Major breaking changes to the API contract require a new version package.
- **Package Declaration**: `package api.order.v1;`
- **Go Options**: `option go_package = "gitlab.com/ta-microservices/order/api/order/v1;v1";`

### Module Versioning (Go)

- **Release Tagging**: Git tags (`v1.0.0`) are used to version the Go module.
- **Breaking Changes**: Go modules generally stay at `v0` or `v1` until major stability is reached.
- **Common Module**: The `common` module is a shared dependency.
  - When updating `common` protos, tag a new release (e.g., `v1.5.0`).
  - Consumers must `go get gitlab.com/ta-microservices/common@v1.5.0` to pull changes.

---

## 3. Code Generation Workflow

We use `Makefile` targets to standardize code generation.

### `make api`

This command generates Go code from `.proto` files.

**Prerequisites:**
- `protoc` compiler.
- `protoc-gen-go`
- `protoc-gen-go-grpc`
- `protoc-gen-openapiv2` (optional, for Swagger)
- `google/api` annotations (usually in `third_party/`).

**What it does:**
1.  Scans `api/**/*.proto`.
2.  Generates `*.pb.go` (Structs & Serialization).
3.  Generates `*_grpc.pb.go` (gRPC Client/Server interfaces).
4.  Generates `*.pb.validate.go` (if using protoc-gen-validate).

**Usage:**

```bash
# In directory: microservice/order/
make api
```

### `make wire`

We use **Google Wire** for compile-time dependency injection.

**What it does:**
1.  Scans `cmd/server/wire.go` (and other wire files).
2.  Generates `cmd/server/wire_gen.go`.

**Usage:**

```bash
make wire
```

### Recommended Workflow for API Changes

1.  **Modify Proto**: Edit `api/service/v1/service.proto`.
2.  **Lint**: Ensure style compliance.
3.  **Generate**: Run `make api`.
4.  **Implement**: Update `internal/service/` interfaces if RPC signatures changed.
5.  **Build**: Run `go build ./...` to verify compilation.
