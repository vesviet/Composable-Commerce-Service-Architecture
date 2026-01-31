# Type-per-Service & Common Base-Func Only – Implementation Checklist

**Created**: 2026-01-30  
**Principle**: Types follow the owning service; common package provides only base/helper functions (no domain structs).  
**Scope**: Order service + Common package alignment; pattern for other services.

---

## Executive Summary

- **Type theo service**: Domain types (Shipment, Payment*, Address for shipping, etc.) are owned by the service that defines them. Consumers (e.g. order) use types from that service (proto-generated or package types), not from common.
- **Common chỉ base func**: Common keeps utilities, helpers, event publisher factory, validation, errors, config, etc. Common does **not** define cross-service domain structs (Shipment, ReturnShipment, PaymentRequest, ShippingRateRequest, Address, etc.).

This checklist guides implementation for **order service** and **common package** to align with this rule.

---

## Phase 1: Common Package

### 1.1 Audit & Plan

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | List all domain types in `common/services/interfaces.go` (Shipment, ReturnShipment, Payment*, ShippingRate*, Address, Item, CreateShipmentRequest, etc.) | ☐ | Identify what to move or deprecate |
| 2 | Decide per type: remove from common vs keep as optional compatibility alias (deprecated) | ☐ | Prefer remove; alias only if breaking too many repos at once |
| 3 | Ensure common keeps only: event helpers, validation, errors, config loader, repository base, auth helpers, logging, etc. | ☐ | No domain DTOs in common |

### 1.2 Common Code Changes

| # | Task | Status | Notes |
|---|------|--------|-------|
| 4 | Move or remove `Shipment`, `ReturnShipment`, `CreateShipmentRequest`, `CreateReturnShipmentRequest` from common (owner: **shipping** service) | ☐ | Shipping proto/types become source of truth |
| 5 | Move or remove `PaymentRequest`, `PaymentCaptureRequest`, `PaymentVoidRequest`, `PaymentRefundRequest`, `PaymentResponse`, `PaymentStatus`, etc. from common (owner: **payment** service) | ☐ | Payment proto/types become source of truth |
| 6 | Move or remove `ShippingRateRequest`, `ShippingRate`, `Address`, `Item` (for shipping) from common (owner: **shipping** service) | ☐ | Or keep minimal `Address` in common only if used as pure value object by many services |
| 7 | Move or remove promotion/pricing/catalog-related DTOs from common if they belong to specific services | ☐ | Optional; do after shipping/payment |
| 8 | Bump common version (e.g. v1.8.9) and document breaking change: “Domain types removed; use types from owning service” | ☐ | CHANGELOG + release note |

---

## Phase 2: Order Service – Shipping Types

### 2.1 Dependencies

| # | Task | Status | Notes |
|---|------|--------|-------|
| 9 | Add/ensure order depends on **shipping** module (proto or Go package) for Shipment types | ☐ | e.g. `shipping/api/shipping/v1` or equivalent |
| 10 | Generate or import: `Shipment`, `CreateShipmentRequest`, `CreateReturnShipmentRequest`, `ReturnShipment`, `Address`, `ShippingRateRequest`, `ShippingRate`, `Item` from shipping | ☐ | Prefer proto-generated types |

### 2.2 Biz Layer (order)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 11 | Remove from `order/internal/biz/biz.go`: type aliases for `Shipment`, `ReturnShipment`, `CreateShipmentRequest`, `CreateReturnShipmentRequest`, `ShippingRateRequest`, `ShippingRate`, `Address`, `Item` from common | ☐ | Delete or comment out lines that alias commonServices.* for these |
| 12 | Define biz interfaces (e.g. `ShippingService`) to use **shipping** types: `CreateShipment(...) (*shippingv1.Shipment, error)` (or equivalent) | ☐ | Replace `*biz.Shipment` with shipping type |
| 13 | Update all biz code that references `biz.Shipment`, `biz.ReturnShipment`, `biz.CreateShipmentRequest`, `biz.ShippingRateRequest`, `biz.ShippingRate`, `biz.Address` to use shipping package types | ☐ | Grep and replace; fix compile |

### 2.3 Data Layer – Shipping Client (order)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 14 | In `order/internal/data/grpc_client/shipping_client.go`: change return type of `CreateShipment` to `*shippingv1.Shipment` (or shipping type), not `*biz.Shipment` | ☐ | Return proto response directly or map to shipping type only |
| 15 | Same for `CreateReturnShipment`: return shipping’s `ReturnShipment` type (or proto) | ☐ | Remove `biz.ReturnShipment` and `LabelURL` if not in common (already done when using shipping type) |
| 16 | Replace `convertToProtoAddress(addr *biz.Address)` with shipping’s Address type (e.g. `*shippingv1.Address` from request) | ☐ | Use shipping proto Address; no biz.Address from common |
| 17 | `CalculateRates`: use shipping’s request/response types; remove dependency on common `ShippingRateRequest` / `ShippingRate` | ☐ | Implement using shipping proto only |

### 2.4 Client Adapters & Service Layer (order)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 18 | Update `order/internal/data/client_adapters.go` (shipping adapter) to return shipping types instead of `biz.Shipment` | ☐ | Align with grpc_client |
| 19 | Update order service layer (HTTP/gRPC handlers) that return or accept Shipment/ReturnShipment to use shipping types or their JSON mapping | ☐ | Response DTOs can wrap shipping type fields |

---

## Phase 3: Order Service – Payment Types

### 3.1 Dependencies & Biz

| # | Task | Status | Notes |
|---|------|--------|-------|
| 20 | Add/ensure order depends on **payment** module for payment types | ☐ | Proto or Go package |
| 21 | Remove from `order/internal/biz/biz.go`: type aliases for `PaymentRequest`, `PaymentCaptureRequest`, `PaymentVoidRequest`, `PaymentRefundRequest`, `PaymentResponse`, `PaymentStatus`, etc. from common | ☐ | |
| 22 | Define payment-related interfaces to use **payment** types (e.g. `*paymentv1.CaptureRequest`, `*paymentv1.PaymentResponse`) | ☐ | Replace common aliases |
| 23 | Update biz: cancellation, order_edit, worker (capture_retry, payment_compensation), eventbus (payment_consumer) to use payment package types | ☐ | All struct literals and function signatures |

### 3.2 Data Layer – Payment Client & Mocks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 24 | In order’s payment client / grpc adapter: use payment proto types for requests and responses | ☐ | No common.PaymentRequest etc. |
| 25 | Update `order/internal/biz/mocks.go`: replace `PaymentStatus`, `PaymentCaptureResponse`, and other payment struct literals with payment package types; fix fields (e.g. remove `ProcessedAt`, `PaymentID` if not in payment type) | ☐ | Match payment service’s actual structs |

---

## Phase 4: Order Service – Other Common Types (Optional)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 26 | CustomerAddress, Product, StockReservation, User: keep from common only if they remain in common as “base” value objects; otherwise move to customer/catalog/warehouse and use their types | ☐ | Can be later phase |
| 27 | PriceCalculation, DiscountItem, AppliedDiscount, CouponValidation, EligiblePromotion, PromotionValidationRequest/Result: move to **pricing** / **promotion** if common drops them; order then imports from those services | ☐ | Optional |

---

## Phase 5: Verification & Docs

| # | Task | Status | Notes |
|---|------|--------|-------|
| 28 | Run `go mod tidy` and `go mod vendor` in order; no `replace` for common/shipping/payment | ☐ | |
| 29 | Build: `go build ./...` in order; fix any remaining type errors | ☐ | |
| 30 | Run `golangci-lint run ./...` in order; fix lint | ☐ | |
| 31 | Update `docs/03-services/core-services/order-service.md` and `order/README.md`: document that order uses types from shipping/payment (and optionally pricing/promotion); common is base-func only | ☐ | |
| 32 | Update `docs/10-appendix/checklists/v3/order_service_checklist_v3.md`: remove P1 about common type alignment; note “types per service” as done | ☐ | |

---

## Summary Table

| Phase | Focus | Key deliverables |
|-------|--------|-------------------|
| 1 | Common | Remove/deprecate domain types; keep only base func |
| 2 | Order – Shipping | Use shipping types for Shipment, ReturnShipment, Address, ShippingRate* |
| 3 | Order – Payment | Use payment types for Payment*, fix mocks |
| 4 | Order – Others | Optional: Customer, Product, Pricing, Promotion types from their services |
| 5 | Verify & Docs | Build, lint, docs updated |

---

## Reference

- **Principle**: “type theo service, common chỉ base func”
- **Order biz types to migrate**: `order/internal/biz/biz.go` (lines ~216–246: commonServices aliases)
- **Order shipping client**: `order/internal/data/grpc_client/shipping_client.go`
- **Order payment mocks**: `order/internal/biz/mocks.go` (PaymentStatus, PaymentCaptureResponse, etc.)
- **Common domain types**: `common/services/interfaces.go` (Shipment, ReturnShipment, Payment*, ShippingRate*, Address, Item, etc.)
