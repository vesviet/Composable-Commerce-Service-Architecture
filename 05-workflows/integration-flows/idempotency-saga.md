# Idempotency & Distributed Transaction Patterns

**Purpose**: Document idempotency guarantees, Outbox pattern, Saga choreography/orchestration, DLQ retry, and payment callback deduplication across the platform  
**Pattern Reference**: Shopify Order API, Stripe idempotency keys, Netflix Saga, AWS DLQ pattern

---

## Overview

In a distributed system, any operation can fail partway through. Without idempotency and compensation mechanisms, failures lead to double-charges, double-inventory deductions, or stuck orders. This document defines the patterns used platform-wide.

---

## 1. Idempotency Fundamentals

### 1.1 Rule

> Every mutating API call and every event handler MUST be idempotent. Calling an operation twice with the same input must produce the same result without side effects.

### 1.2 Idempotency Key Sources

| Layer | Idempotency Key | Source |
|---|---|---|
| HTTP API | `Idempotency-Key` header | Client generates UUID per request |
| Payment callback | `gateway_transaction_id` | Payment gateway |
| Event processing | `event_id` (CloudEvents `id` field) | Publishing service (UUID) |
| Order creation | `checkout_session_id` | Checkout Service |
| Refund | `refund_request_id` | CS agent / Return Service |

### 1.3 Idempotency Storage

```
Redis (idempotency store):
    Key: "idempotency:{service}:{idempotency_key}"
    Value: { status: "processing"|"completed", response_hash, created_at }
    TTL: 24 hours

Flow on HTTP request:
    1. Check Redis: key exists?
       - Yes + status=completed → return cached response (do not re-execute)
       - Yes + status=processing → return 409 Conflict (request in flight)
       - No → set status=processing, execute, set status=completed + cache result
```

---

## 2. Outbox Pattern

### 2.1 Why Outbox

Without the Outbox pattern, this failure is possible:
```
DB commit → success
Publish event → network failure → event lost
→ Downstream services never know about the DB change
```

The Outbox pattern guarantees: **if the DB commit succeeds, the event will eventually be published.**

### 2.2 Outbox Table Schema

```sql
CREATE TABLE outbox_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic       TEXT NOT NULL,        -- Dapr pub/sub topic
    event_type  TEXT NOT NULL,        -- e.g. "order.placed"
    event_id    UUID NOT NULL UNIQUE, -- idempotency key for consumers
    payload     JSONB NOT NULL,
    status      TEXT NOT NULL DEFAULT 'PENDING', -- PENDING | PUBLISHED | FAILED
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    attempts    INT NOT NULL DEFAULT 0,
    last_error  TEXT
);
```

### 2.3 Write Flow (same DB transaction)

```
BEGIN TRANSACTION;
    INSERT INTO orders (...) VALUES (...);          -- domain write
    INSERT INTO outbox_events (topic, event_type, event_id, payload)
        VALUES ('order.events', 'order.placed', uuid_generate_v4(), '{"order_id": ...}');
COMMIT;
-- If commit fails: neither order nor event is created (consistent)
-- If commit succeeds: event guaranteed to be in outbox
```

### 2.4 Outbox Publisher Worker

```
Outbox Worker (polls every 500ms):
    SELECT * FROM outbox_events
    WHERE status = 'PENDING' AND attempts < 5
    ORDER BY created_at ASC
    LIMIT 100
    FOR UPDATE SKIP LOCKED;     -- safe for multi-instance workers

    For each event:
        attempts++
        → Dapr Pub/Sub: publish(topic, event_id, payload)
        → If success:
            UPDATE status = 'PUBLISHED', published_at = NOW()
        → If failure:
            UPDATE last_error = ..., status = 'PENDING'  -- retry next poll
        
    If attempts >= 5:
        UPDATE status = 'FAILED'
        Alert: ops team (dead outbox event)
```

### 2.5 Consumer Deduplication

```
Consumer receives event with event_id:
    1. Check: SELECT 1 FROM processed_events WHERE event_id = ?
    2. If found → already processed, ack and skip
    3. BEGIN TRANSACTION;
        Execute business logic
        INSERT INTO processed_events (event_id, processed_at) VALUES (...)
       COMMIT;
    4. Ack event to Dapr
```

---

## 3. Saga Pattern — Choreography

### 3.1 When to Use Choreography

Use when: flow is simple, few services, each service can make its own compensation decision.

**Example: Order Placement Saga**

```
Services: Checkout, Order, Payment, Warehouse

Happy path (events):
    Checkout → order.placement_requested
        → Order Service: create order (PENDING_PAYMENT)
            → order.pending_payment
        → Payment Service: initiate payment (PAYMENT_INITIATED)
            → payment.captured
        → Order Service: update status → PAID
            → order.paid
        → Warehouse Service: confirm reservation (STOCK_CONFIRMED)
            → stock.reserved
        → Order Service: update status → PROCESSING
```

```
Failure: payment.failed
    → Order Service: cancel order (CANCELLED)
        → order.cancelled
    → Warehouse Service: release reservation
        → stock.released
```

### 3.2 Choreography Rules

- Each service listens only to its own domain events + events it explicitly needs
- Compensating events must mirror the business event: `stock.reserved` ↔ `stock.released`
- No service knows about the overall saga state — each reacts to events independently
- All event handlers are idempotent (see section 1)

---

## 4. Saga Pattern — Orchestration

### 4.1 When to Use Orchestration

Use when: flow involves 4+ services, complex conditional branching, need centralized saga state for visibility.

**Example: Return Processing Saga**

```
Orchestrator: Return Service (saga coordinator)

Step 1: Return Service → Shipping Service: create_return_label()
    → If fail: abort saga, notify buyer

Step 2: Return Service → Wait for carrier.pickup_confirmed event
    → Timeout: 5 days
    → If timeout: escalate to CS

Step 3: Return Service → Warehouse Service: inspect_return()
    → Outcome: APPROVED | DAMAGED | REJECTED

Step 4 (if APPROVED):
    → Payment Service: initiate_refund(order_id, amount)
    → Notification: refund processed email
    → Warehouse Service: restock or quarantine item

Step 4 (if REJECTED):
    → Return Service: notify buyer of rejection
    → Optionally: re-ship item back to buyer
```

### 4.2 Saga State Table

```sql
CREATE TABLE saga_instances (
    saga_id         UUID PRIMARY KEY,
    saga_type       TEXT NOT NULL,           -- 'return_processing', 'order_placement'
    entity_id       UUID NOT NULL,           -- order_id, return_id
    current_step    TEXT NOT NULL,
    status          TEXT NOT NULL,           -- RUNNING | COMPLETED | FAILED | COMPENSATING
    context         JSONB NOT NULL,          -- accumulates data from each step
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL
);
```

---

## 5. Payment Callback Idempotency

### 5.1 Problem

Payment gateways may send duplicate webhooks. Processing the same `payment.captured` event twice causes double order confirmation and potentially double inventory deduction.

### 5.2 Solution

```
Gateway webhook → Payment Service: POST /webhooks/payment

Payment Service handler:
    1. Parse: gateway_transaction_id from payload
    2. Acquire distributed lock: lock("payment_webhook:{txn_id}", ttl=30s)
    3. Check: SELECT id FROM payment_events WHERE gateway_txn_id = ?
       - Exists: log "duplicate webhook, skip", release lock, return 200
    4. Execute:
        INSERT INTO payment_events (gateway_txn_id, ...)
        UPDATE orders SET status = 'PAID' WHERE ...
        INSERT INTO outbox_events (topic='order.events', event_type='order.paid', ...)
    5. COMMIT
    6. Release lock
    7. Return 200 OK
```

**Critical**: Always return `200 OK` to gateway even for duplicates. Returning 4xx/5xx causes the gateway to retry indefinitely.

---

## 6. Dead Letter Queue (DLQ) Flow

### 6.1 When Events Go to DLQ

```
Consumer fails to process event after N retries (e.g., 5 attempts):
    → Dapr: move event to dead-letter topic (e.g., "order.events.dlq")
    → DLQ Consumer: write to dlq_events table
        {
            event_id, topic, event_type, payload,
            consumer_service, error_message, failed_at, attempts
        }
    → Alert: ops-alerts Slack channel
```

### 6.2 DLQ Investigation & Replay

```
Ops engineer:
    1. View DLQ dashboard: dlq_events by service, event_type, error
    2. Diagnose: is it a code bug? DB outage? Bad payload?
    3. Fix: deploy code fix if needed
    4. Replay:
        POST /admin/dlq/replay { event_id: [...] }
        → DLQ Service: re-publish events to original topic
        → Consumer processes normally
    5. Mark: status = 'REPLAYED' | 'DISCARDED' + reason

    If discarded: requires SUPER_ADMIN approval (immutable record)
```

### 6.3 DLQ Retention

- DLQ events retained for 30 days
- Alert if DLQ depth > 100 events per service
- Weekly: automated report of DLQ events per service to engineering leads

---

## 7. Cart-Level Idempotency (Order Deduplication)

**Problem**: Network timeout causes buyer to click "Place Order" twice → 2 orders created.

```
Checkout Service assigns checkout_session_id (UUID) per checkout attempt.

Order Service — create_order(checkout_session_id):
    1. SELECT id FROM orders WHERE checkout_session_id = ?
    2. If found: return existing order (do not create new)
    3. If not:
        BEGIN TRANSACTION;
        INSERT INTO orders (checkout_session_id, ...) ON CONFLICT (checkout_session_id) DO NOTHING
        SELECT id FROM orders WHERE checkout_session_id = ?  -- read back
        COMMIT;
    4. Return order_id
```

The `ON CONFLICT DO NOTHING` + read-back pattern handles race conditions between concurrent requests.

---

## 8. Summary: Which Pattern Goes Where

| Scenario | Pattern |
|---|---|
| Guarantee event publish after DB write | Outbox Pattern |
| Prevent duplicate event processing | Consumer deduplication by event_id |
| Prevent duplicate API calls | Idempotency-Key header + Redis |
| Prevent duplicate payment webhook | gateway_txn_id dedup + distributed lock |
| Prevent duplicate order creation | checkout_session_id + DB unique constraint |
| Multi-service rollback (simple flow) | Saga Choreography + compensating events |
| Multi-service rollback (complex, many steps) | Saga Orchestration + saga_instances table |
| Handle permanently failed events | DLQ + manual replay workflow |

---

**Last Updated**: 2026-02-21  
**Owner**: Platform Architecture Team
