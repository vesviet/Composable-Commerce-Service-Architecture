# Service Migration & Audit Checklist

## 1. Services Calling Internal Services via HTTP (Need Migration to gRPC)

These services are currently making internal HTTP calls. This checklist tracks the migration to gRPC.

| Status | Source Service | Target Service | File Location | Priority |
|:---:|:---|:---|:---|:---|
| [ ] | **Customer** | **Order** | `customer/internal/client/order/order_client.go` | P1 |
| [ ] | **Customer** | **Notification** | `customer/internal/client/notification/notification_client.go` | P1 |
| [ ] | **Payment** | **Customer** | `payment/internal/client/customer_client.go` | P0 |
| [ ] | **Payment** | **Order** | `payment/internal/client/order_client.go` | P0 |
| [ ] | **Loyalty** | **Notification** | `loyalty-rewards/internal/client/notification_client.go` | P2 |
| [ ] | **Loyalty** | **Order** | `loyalty-rewards/internal/client/order_client.go` | P2 |
| [ ] | **Loyalty** | **Customer** | `loyalty-rewards/internal/client/customer_client.go` | P2 |
| [ ] | **Warehouse** | **Notification** | `warehouse/internal/client/notification_client.go` | P2 |
| [ ] | **Search** | **Catalog** | `search/internal/client/catalog_visibility_client.go` | P1 |
| [ ] | **Catalog** | **Pricing** | `catalog/internal/client/pricing_client.go` | P1 |

> **Note on Payment Service**: The Payment service calls other services primarily for validation or updates after payment. These should be strictly gRPC or Async Events (Dapr Pub/Sub). HTTP is risky here due to timeout handling.

### Migration Steps per Service:
1.  **Interface Definition**: Verify/Update the `internal/client/X` interface.
2.  **Implementation**: Create/Update the gRPC adapter (using `internal/conf` for service registry address).
3.  **Wire Injection**: Update `cmd/server/wire.go` to inject the gRPC client.
4.  **Removal**: Delete the HTTP client implementation.

---

## 2. Services Missing Public Tags (`google.api.http`)

The following services are missing HTTP transcoding annotations in their `.proto` files. This prevents them from being exposed via the JSON Gateway.

| Status | Service | Proto File | Affected RPCs |
|:---:|:---|:---|:---|
| [ ] | **Checkout** | `checkout/api/checkout/v1/checkout.proto` | `StartCheckout`, `GetCheckout`, `ConfirmCheckout`, etc. |
| [ ] | **Return** | `return/api/return/v1/return.proto` | `CreateReturnRequest`, `ApproveReturn`, etc. |

### Remediation Plan:
1.  **Add Option**: Add `option (google.api.http)` to each RPC in the `.proto` file.
2.  **Naming Convention**: Use RESTful paths (e.g., `POST /api/v1/checkout`, `GET /api/v1/returns/{id}`).
3.  **Regenerate**: Run `make api` to update generated code and Swagger/OpenAPI docs.

---

## 3. General Codebase Health

| Status | Issue | Description |
|:---:|:---|:---|
| [ ] | **Gateway Proxying** | `gateway/internal/client/service_client.go` contains generic HTTP proxy logic. Verify if this is still needed or can be fully replaced by Kratos/Envoy routing. |
