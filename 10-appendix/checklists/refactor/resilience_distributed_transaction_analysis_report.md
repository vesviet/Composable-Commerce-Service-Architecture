# 📋 Architectural Analysis & Refactoring Report: Resilience & Distributed Transactions (Saga Pattern)

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Distributed State Machines (Sagas), Fault Tolerance, Circuit Breaking & Compensation Logic  

---

## 🎯 Executive Summary
In an environment where a single "Checkout" traverses 4 distinct aggregates (`Order` -> `Payment` -> `Warehouse` -> `Notification`), maintaining ACID guarantees is impossible. E-commerce platforms survive by embracing Eventual Consistency via the **Saga Pattern**. 
This report commends the exemplary implementation of a Durable Saga within the `order` and `payment` services, featuring automated retries, bulletproof compensations, and Dead Letter Queue (DLQ) safety nets. This architecture meets the highest tier (Staff/Principal Engineer level) of e-commerce system design.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

*No P0/P1 architectural flaws exist in this domain. The Dapr Saga and Kratos Circuit Breaker implementations are functioning exceptionally well.*

## ✅ RESOLVED / FIXED

- **[FIXED ✅] System Documentation Gap**: A sequence diagram (`docs/05-workflows/sequence-diagrams/order-saga-pattern-validation.md`) has been merged. It visually maps the 3 phases of the Saga (Authorization, Capture, Compensation) ensuring junior engineers understand the state machine before modifying core code.
- **[FIXED ✅] Alerting System Integration**: The native `biz.AlertService` inside the Order service (`order/internal/biz/monitoring.go`) has successfully been wired to the `NotificationService`. Critical state failures (e.g., `CART_CLEANUP_FAILED`, `PAYMENT_COMPENSATION_FAILED`) now trigger immediate PagerDuty/Slack escalations to the Ops team.

---

## 📋 Architectural Guidelines & Playbook

### 1. 🚦 The Durable Saga Pattern (Textbook Standard)
The **Order Service** implements a textbook Durable Saga Pattern to handle split-brain transactions.

**Phase 1: Persistent State Tracking (Authorized)**
- The `orders` table actively tracks the distributed transaction via the `payment_saga_state` column (States: `Authorized`, `CapturePending`, `CaptureFailed`, `Captured`). Storing state in the DB ensures the transaction is never "lost" even if the Order Pod crashes mid-execution.

**Phase 2: Automated Idempotent Retries (Capture)**
- A background worker (`worker/cron/capture_retry.go`) continuously polls for `CaptureFailed` orders caused by transient network timeouts from the Payment API. It automatically orchestrates retries with exponential backoff.

**Phase 3: Compensating Transactions (Rollback)**
- If the retry limit (`MaxCaptureRetries = 3`) is exhausted, the state machine triggers physical compensations via `worker/cron/payment_compensation.go`. This acts as the ultimate fail-safe:
  1. Calls the Payment Gateway to `Void` the locked Authorization.
  2. Transitions the Order to `OrderStatusCancelled`.
  3. Fires a Dapr Event to the Warehouse to release the reserved inventory lock.

### 2. 🛡️ The Ultimate Safety Net: Dead Letter Queues (DLQ)
What happens if the Payment Gateway is entirely offline during the Compensation phase (Phase 3)?
- Instead of abandoning the transaction and locking the customer's funds in limbo, the system writes the failed compensation into a Postgres Dead Letter Queue (`biz.FailedCompensationRepo`).
- A dedicated Admin API (`service/failed_compensation_handler.go`) allows Customer Support (CS) to query these "dead" transactions and execute a manual **Retry** (`RetryFailedCompensation`) once the gateway recovers.

### 3. Fault Tolerance & Telemetry (The Good)
- **gRPC Edge Resilience**: All internal Service-to-Service communication via the `common/client` library is hardcoded with strict Timeouts (e.g., 5 seconds), automated Retries, and aggressive **Circuit Breakers**. If the Payment service crashes, the Order service trips the breaker instantly, preventing cascading TCP exhaustion.
