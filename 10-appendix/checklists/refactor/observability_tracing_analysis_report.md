# 📋 Architectural Analysis & Refactoring Report: Observability, Distributed Tracing & Logging

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Telemetry (OpenTelemetry), Trace Propagation (W3C traceparent) & Centralized Logging (Kibana/Loki)  

---

## 🎯 Executive Summary
In a highly decoupled e-commerce microservices environment, tracing a single customer checkout request across 10+ services is paramount for debugging and MTTR (Mean Time To Recovery). The platform successfully leverages OpenTelemetry (OTel) and the Dapr sidecar mesh to automatically propagate W3C `traceparent` headers across synchronous (gRPC/HTTP) and asynchronous (PubSub) boundaries. However, a critical blind spot exists within the Transactional Outbox pattern that severs the distributed trace lineage.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

*No P0/P1 issues remain. Trace lineage through the Transactional Outbox has been fully restored.*

## ✅ RESOLVED / FIXED

- **[FIXED ✅] Trace Lineage Restored at Transactional Outbox**: Codebase audit (2026-03-01) confirms `Traceparent` field is now present in outbox event construction across all critical services:
  - `order/internal/biz/biz.go` — `Traceparent` injected ✅
  - `order/internal/data/postgres/outbox.go` — `Traceparent` persisted ✅
  - `payment/internal/biz/events/outbox.go` — `Traceparent` injected ✅
  - `payment/internal/data/postgres/outbox.go` — `Traceparent` persisted ✅
  The background Outbox Worker now correctly inherits the original trace context, producing unified end-to-end traces in Jaeger/Kibana.
- **[FIXED ✅] Centralized JSON Logging Missing Trace IDs**: The `cmd/main.go` bootstrap configurations now correctly utilize the Kratos native `log.With()` middleware to inject `tracing.TraceID()` directly into the `stdout` JSON formatter.

---

## 📋 Architectural Guidelines & Playbook

### 1. The Seamless Tracing Mesh (The Good)
When interacting with infrastructure, developers should ideally write zero tracing code. The ecosystem achieves this flawlessly in two vectors:
- **Synchronous Edge (gRPC/HTTP)**: Kratos middlewares automatically decode incoming W3C headers. If the request routes through the Dapr mesh, the sidecar automatically handles the `dapr.io/config: tracing-config` telemetry.
- **Asynchronous Edge (CloudEvents)**: When publishing directly to Dapr PubSub, the sidecar natively injects the active trace context into the CloudEvents envelope envelope without requiring developer intervention.

### 2. The Outbox Propagation Pattern (Mandatory Fix)
Because the Outbox pattern intentionally breaks the synchronous execution thread (saving to a DB instead of dialing a network), explicit context propagation is mandatory.

**Anti-Pattern (Severed Trace):**
```go
outboxEvent := &model.OutboxEvent{
    EventType: "PaymentCompleted",
    Payload:   string(payloadBytes),
    // Missing Traceparent! The worker will start a brand new trace.
}
```

**Shopify/Lazada Standard (Unified Trace Lineage):**
```go
outboxEvent := &model.OutboxEvent{
    EventType:   "PaymentCompleted",
    Payload:     string(payloadBytes),
    // Crucial: Bridge the gap between the API request and the background worker
    Traceparent: tracing.ExtractTraceparent(ctx), 
}
```
*Note from the Senior TA: Any PR utilizing the Outbox pattern that fails to explicitly map the `Traceparent` string will fail CI checks.*
