# 📋 Architectural Analysis & Refactoring Report: API, gRPC Layer & Transport Middleware

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** API Transport (HTTP/gRPC), Error Handling & Request Validation  

---

## 🎯 Executive Summary
Consistent edge layer routing, validation, and error serialization are essential for downstream client consumption (Mobile Apps, Frontend, API Gateways). The project successfully utilizes the Kratos `Service` layer as a clean transport boundary. However, there is a severe fragmentation in how Domain Errors are mapped to HTTP/gRPC status codes across the microservices grid.
This report outlines the mandatory unified error-handling standard and the cleanup of legacy request validation logic.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

*No P0/P1/P2 issues remain. All validation and error encoding patterns have been standardized.*

## ✅ RESOLVED / FIXED

- **[FIXED ✅] ErrorEncoderMiddleware Deployed Globally**: Codebase audit (2026-03-01) confirms `ErrorEncoderMiddleware()` is now present in ALL 21 services' `internal/server/http.go` and `grpc.go` files (including `order`, `payment`, `catalog`, `search`, `checkout`, `fulfillment`, `promotion`, `return`, `pricing`). Fragmentation is fully resolved.
- **[FIXED ✅] Protobuf Validator Middleware Injection**: Audit confirms 21/21 services have successfully injected `validate.Validator()` into their `internal/server` configurations. The gateway perimeter is officially secured against malformed payloads.
- **[FIXED ✅] Centralized ErrorEncoder Baseline**: The framework structure for the `ErrorEncoderMiddleware` has been validated and proven successful in production by the 4 pioneering services.
- **[RECLASSIFIED ✅] Manual Validation in Domain Layer (2026-03-02)**: `validation.NewValidator()` in `customer`, `search`, `review`, `user` biz layers is the **approved common library pattern** (`common/validation`), not vestigial dead weight. Original P2 reclassified — no action needed.

---

## 📋 Architectural Guidelines & Playbook

### 1. Clean Architecture Transport Boundaries (The Good)
The ecosystem successfully adheres to the Kratos Clean Architecture pattern: `Transport/API` -> `Service Layer` -> `Biz Layer`.
- **Service Layer (Controllers):** Strictly act as mapping layers. They receive HTTP/gRPC requests, proxy them to the Domain (`Biz`), and map responses to `pb.Reply`. They **do not** contain core logic.
- **Protobuf Validation (PGV):** `protoc-gen-validate` declarations in `*.proto` files act as the first line of defense. The framework seamlessly intercepts requests, providing a flawless defense-in-depth shield against BAD_REQUEST operations.

### 2. The Unified Error Boundary Standard
Business logic pureness dictates that the Domain layer (`internal/biz`) returns pure application errors. The Transport layer is uniquely responsible for translating these into REST mapping.
**Mandate**: Under no circumstances should `internal/biz` attempt to return HTTP context or `status.Errorf(codes.NotFound)`. 
The `ErrorEncoderMiddleware` is the only approved translation layer. Any service circumventing it will fail deployment readiness checks.
