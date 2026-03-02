# 📋 Architectural Analysis & Refactoring Report: Dapr PubSub & Event-Driven Choreography

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Asynchronous Messaging, Dapr Sidecar Integration & Event Publishing Resiliency  

---

## 🎯 Executive Summary
Event-driven architecture (EDA) is the circulatory system of a modern e-commerce platform. The integration of Dapr Pub/Sub as an abstracted sidecar guarantees robust message delivery (At-Least-Once), enabling resilient choreography between domains (e.g., Order completes -> Warehouse deducts stock -> Payment captures funds). 
The core implementation (`common/events`) successfully provides a fault-tolerant gRPC publisher with Circuit Breaking capabilities. However, instances of localized wrapper classes obscure these benefits and add unnecessary bloat.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

*No P0/P1/P2 issues remain. The superfluous publisher wrapper has been deleted.*

## ✅ RESOLVED / FIXED

- **[FIXED ✅] Location Publisher Wrapper Deleted**: Codebase audit (2026-03-01) confirms `location/internal/event/publisher.go` has been **deleted**. The directory now contains only `provider.go` with a clean Wire DI configuration injecting the core `events.EventPublisher` interface directly. Commit `13aa392`.
- **[FIXED ✅] Elimination of Single Point of Failure (SPOF) via Raw Clients**: Previous audits revealed that core backbone services (`warehouse` and `shipping`) were bypassing the resilient core library by instantiating raw `dapr.NewClient()` connections directly within their data mappings (`internal/data/storage.go` and `dapr_client.go`). This has been completely refactored. Both services successfully inject the core interface.

---

## 📋 Architectural Guidelines & Playbook

### 1. The Core Event-Driven Backbone (The Good)
The platform standardizes synchronous and asynchronous Dapr communication beautifully within the `common/events` package.
- **`DaprEventPublisherGRPC`**: Communicates directly over high-performance gRPC channels to the sidecar. It features integrated, enterprise-critical **Circuit Breakers** (halting request storms if the sidecar is unresponsive), internal **Retry** backoffs, and NoOp fallbacks for local development environments without Dapr.
- **`ConsumerClient`**: Automates the instantiation of listening endpoints, parses incoming CloudEvents payloads, and automatically injects distributed OpenTelemetry Context tracing into Go's `context.Context` pipeline.

### 2. Dependency Injection Purity
Dependency Injection exists to decouple domains from infrastructure, not to create endless layers of abstraction.

**Anti-Pattern (Hasty Abstraction in `Location`):**
```go
// Creating a useless wrapper struct
type LocalPublisher struct {
    core events.EventPublisher
}
func (p *LocalPublisher) Publish(ctx, topic, data) {
    p.core.Publish(ctx, topic, data)
}
```

**Shopee Standard (Direct Interface Injection):**
Inject the highest-level abstraction directly where it is consumed (the Biz/UseCase layer).
```go
// biz/location.go
type LocationUsecase struct {
    repo      LocationRepo
    publisher events.EventPublisher // Direct integration with the Core contract
}
```
*Note from the Senior TA: Any PR adding a wrapper struct to a core library interface must justify its existence with measurable business logic (e.g., specific payload encryption). Othewise, it will be rejected.*
