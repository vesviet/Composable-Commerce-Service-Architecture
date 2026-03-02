# 📋 Architectural Analysis & Refactoring Report: Internal Worker Lifecycle Management

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Asynchronous Background Processing (Cronjobs, Transactional Outboxes, DLQ Processors), Goroutine Lifecycle & DRY Adherence  

---

## 🎯 Executive Summary
Robust background processing guarantees that critical business events (like publishing an order placement message to the warehouse) eventually succeed despite transient failures. The ecosystem heavily utilizes the Transactional Outbox pattern alongside Cron aggregations. While the base `commonWorker.ContinuousWorker` interface provides an excellent foundation, severe technical debt exists in how individual teams are implementing the core polling loops. 
This report flags critical code duplication in the `order` service and the alarming bloat of boilerplate goroutines across manual Cron implementations. 

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

*No P0 issues remain in this domain. All critical outbox and cron worker violations have been resolved.*

## ✅ RESOLVED / FIXED

- **[FIXED ✅] Order Outbox Worker Migrated to Common Library**: Codebase audit (2026-03-01) confirms `order/internal/worker/outbox/wire.go` now exclusively uses `commonOutbox.NewWorker("order-outbox-worker", repo, publisher, logger)` with proper configuration (interval: 1s, maxRetries: 10, batchSize: 50, stuckRecovery: 5min, cleanup: 10min/30d). The legacy 160-line local `worker.go` has been deleted. Only a clean adapter pattern (`OutboxPublisherAdapter`) remains for interface compatibility.
- **[FIXED ✅] CronWorker Standard Adoption**: Track U confirmed done. Services use `commonWorker.NewCronWorker()` wrapper. Manual `for{select}` goroutine patterns have been eradicated from `order`, `analytics`, and `catalog` services.

---

## 📋 Architectural Guidelines & Playbook

### 1. The Core Asynchronous Topology (The Good)
The platform effectively segregates its async workflows into logical domains:
- **Cron Jobs**: Scheduled tasks (e.g., `aggregation_cron` in analytics, `order_cleanup`).
- **Event Consumers**: Listeners bound to Dapr PubSub topics.
- **Outbox Processors**: Relay mechanisms guaranteeing DB-to-Queue delivery.
- **DLQ Reprocessors**: Fault-tolerance nets for dead letters.

All topologies successfully implement the generic `commonWorker.ContinuousWorker` interface and embed `*commonWorker.BaseContinuousWorker` to unify Start, Stop, and HealthCheck signals under the Dual-Binary paradigm.

### 2. Abstracting Complexity (The Shopee/Shopify Cron Standard)
To achieve ultimate code cleanliness, the business developer should **never** write a `select` statement for a cron job. The framework must absorb the complexity.

**Lethal Anti-Pattern (Manual Goroutine Management):**
```go
func (j *MyCronJob) Start(ctx context.Context) error {
	ticker := time.NewTicker(15 * time.Minute)
	defer ticker.Stop() // Forgetting this equals OOM!
	for {
		select {
		case <-ticker.C:
			j.process()
		case <-ctx.Done(): ...
		case <-j.StopChan(): ...
		}
	}
}
```

**The New Mandated Standard (`CronWorker` Wrapper):**
The developer solely writes the pure business logic function (`Do`). The core framework provides the wrapper.
```go
// 1. Define Pure Business Logic
type OrderCleanupLogic struct { repo Repo }

func (l *OrderCleanupLogic) Do(ctx context.Context) error {
    // 100% focused on cleaning up database records.
    return nil
}

// 2. Instantiate via Wire DI
func ProvideCleanupWorker() commonWorker.ContinuousWorker {
    // The framework handles the infinite loop safely.
    return commonWorker.NewCronWorker(
        "order-cleanup", 15 * time.Minute, logger, &OrderCleanupLogic{},
    )
}
```
