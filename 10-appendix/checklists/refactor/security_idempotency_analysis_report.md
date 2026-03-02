# 📋 Architectural Analysis & Refactoring Report: Security, RBAC & Idempotency Workflows

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Access Control (RBAC/Zero-Trust) & Distributed Idempotency (Double-Charge Prevention)  

---

## 🎯 Executive Summary
In e-commerce architectures handling high-concurrency external traffic, zero-trust perimeter security and flawless idempotency are baseline requirements. A single race condition during flash sales can result in massive financial loss via double-charging or split-brain order creation.
This report evaluates the current API gateway authentication flow and the Redis/Postgres idempotency keys securing the financial transaction ledgers.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

*No P0/P1/P2 issues remain in this domain. Both idempotency and RBAC issues have been resolved or reclassified.*

## ✅ RESOLVED / FIXED

- **[FIXED ✅] RBAC Middleware Migration Complete**: Codebase audit (2026-03-01) confirms all 5 originally flagged services have migrated to `RequireRoleKratos` from `common/middleware/auth.go`:
  - `catalog/internal/server/http.go` → Uses `RequireRoleKratos` ✅
  - `review/internal/server/{http,grpc}.go` → Uses `RequireRoleKratos` ✅
  - `promotion/internal/server/{http,grpc}.go` → Uses `RequireRoleKratos` ✅
  - `return/internal/middleware/auth.go` → **Deleted** (no local RequireRole) ✅
  - `pricing/internal/middleware/auth.go` → **Deleted** (no local RequireRole) ✅
- **[RECLASSIFIED ✅] Payment Idempotency Is Legitimate Domain Logic**: `payment/internal/biz/common/idempotency.go` implements a unique `Begin/MarkCompleted/MarkFailed` state machine for payment gateway idempotency. This is NOT a copy-paste of `common/idempotency` (which uses simple `SETNX` locks). The payment version manages complex lifecycle transitions required for multi-gateway support. **Verdict: Legitimate domain logic, no refactoring needed.**
- **[FIXED ✅] Double-Charge Race Condition Mitigated (Payment Service)**: The localized `payment` idempotency file successfully implements the atomic `SETNX` (Set if Not eXists) operator. The lethal anti-pattern of `GET -> (if nil) -> SET` has been successfully eradicated.

---

## 📋 Architectural Guidelines & Playbook

### 1. 🛡️ Zero-Trust Security & Authentication Flow (RBAC)
The overarching ecosystem design excels in separation of concerns regarding edge security:
- **Zero-Trust Perimeter:** The primary API Gateway acts as the SSL/TLS termination point and HTTP header parser. The gateway validates the JWT (`HMAC`), internal claim structures, and drops malicious payloads before they enter the cluster.
- **Kratos Downstream:** Kratos natively unmarshals `x-md-user_id` into the `context.Context` (via `ExtractUserID`), allowing the Domain layer to safely extract the authorized user identity without touching the HTTP Transport logic.
- *Mandate*: Any local drift of `RequireRole()` middleware strictly violates this established pattern and must be remediated.

### 2. 🛡️ Idempotency Execution Patterns (Double-Charge Shield)

**Pattern A: Database-Level Idempotency (Order Service - Perfect Standard)**
- The `order` service natively implements `ON CONFLICT DO UPDATE` via `common/idempotency/event_processing.go`.
- This leverages Postgres ACID transaction isolation to drop redundant insert requests (specifically retried events from the Dapr PubSub mesh). This is the gold standard for backend async ingestion.

**Pattern B: Redis SETNX Distributed Locking (Payment Gateway)**
- Implementing immediate lock rejection using Redis `SETNX`.
- **Why?** When a user's mobile app connection drops and auto-retries the payment submission within the same millisecond, Thread A and Thread B fire concurrently. If relying on a database SELECT, both read `Nil` and proceed to call the external Stripe Gateway API. 
- Using Redis atomic operations, Thread A locks the key, forcing Thread B to receive a `409 Conflict`. Race condition averted.
