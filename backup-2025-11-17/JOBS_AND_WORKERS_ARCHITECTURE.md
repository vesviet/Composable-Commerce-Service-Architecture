# 🏗️ Jobs & Workers Architecture - Recommendations

> **Review Date:** November 9, 2024  
> **Status:** Architecture Review & Recommendations

---

## 📊 Current Architecture Analysis

### ✅ What's Working Well

1. **Migration Jobs** - Đã tách riêng thành separate containers
   - `catalog-migration`, `warehouse-migration`, `pricing-migration`
   - Run once với `restart: "no"`
   - Dependency management với `condition: service_completed_successfully`
   - ✅ **Good practice!**

2. **Event Handlers** - Inline trong main service
   - Dapr subscriptions qua HTTP endpoints
   - Event processing trong service container
   - ✅ **Acceptable for current scale**

3. **Cron Jobs** - Inline trong main service
   - Stock sync job chạy trong goroutine
   - Simple ticker-based scheduling
   - ⚠️ **Needs improvement for production**

---

## 🎯 Recommended Architecture

### Pattern 1: Separate Worker Containers (Recommended)

```
┌─────────────────────────────────────────────────────────────┐
│                    Service Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐     ┌──────────────────┐            │
│  │  Main Service    │     │  Event Worker    │            │
│  │  - HTTP/gRPC API │     │  - Dapr PubSub   │            │
│  │  - Business Logic│     │  - Event Handler │            │
│  │  - No Jobs       │     │  - Retry Logic   │            │
│  └──────────────────┘     └──────────────────┘            │
│                                                              │
│  ┌──────────────────┐     ┌──────────────────┐            │
│  │  Cron Worker     │     │  Migration Job   │            │
│  │  - Scheduled Jobs│     │  - Run Once      │            │
│  │  - Background    │     │  - Schema Update │            │
│  │  - Cleanup Tasks │     │  - Data Migration│            │
│  └──────────────────┘     └──────────────────┘            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Benefits

✅ **Separation of Concerns**
- API service không bị ảnh hưởng bởi heavy jobs
- Scale workers độc lập với API service
- Restart workers không ảnh hưởng API uptime

✅ **Resource Management**
- Allocate resources riêng cho từng loại workload
- API service: High CPU, Low memory
- Event worker: Medium CPU, Medium memory
- Cron worker: Low CPU, High memory (for batch jobs)

✅ **Monitoring & Debugging**
- Logs riêng cho từng worker type
- Metrics riêng cho job performance
- Easier to debug job failures

✅ **Deployment Flexibility**
- Deploy API service frequently (new features)
- Deploy workers less frequently (stable)
- Rollback workers independently

---

## 📋 Implementation Recommendations

### 🔴 HIGH Priority: Separate Event Workers

**When to separate:**
- ✅ Event processing > 100ms per event
- ✅ Event volume > 1000 events/minute
- ✅ Need retry logic and dead letter queue
- ✅ Multiple event types with different processing logic

**Pricing Service Example:**

```yaml
# pricing/docker-compose.yml
services:
  # Main API Service
  pricing-service:
    build:
      context: ..
      dockerfile: pricing/Dockerfile
      args:
        MAIN_PKG: ./cmd/pricing
    container_name: pricing-service
    ports:
      - "8002:80"
      - "9002:81"
    environment:
      - KRATOS_CONF=/app/configs
      - WORKER_MODE=api  # Only run API server
    depends_on:
      - pricing-migration
    networks:
      - microservices
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          cpus: '1'
          memory: 512M

  # Event Worker (Dapr PubSub)
  pricing-event-worker:
    build:
      context: ..
      dockerfile: pricing/Dockerfile
      args:
        MAIN_PKG: ./cmd/worker
    container_name: pricing-event-worker
    environment:
      - KRATOS_CONF=/app/configs
      - WORKER_MODE=events  # Only process events
      - WORKER_CONCURRENCY=10
    depends_on:
      - pricing-service
    networks:
      - microservices
    deploy:
      replicas: 2  # Scale event processing
      resources:
        limits:
          cpus: '1'
          memory: 512M
    restart: unless-stopped

  # Cron Worker (Scheduled Jobs)
  pricing-cron-worker:
    build:
      context: ..
      dockerfile: pricing/Dockerfile
      args:
        MAIN_PKG: ./cmd/worker
    container_name: pricing-cron-worker
    environment:
      - KRATOS_CONF=/app/configs
      - WORKER_MODE=cron  # Only run scheduled jobs
    depends_on:
      - pricing-service
    networks:
      - microservices
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
    restart: unless-stopped
```

---

## 🏗️ Code Structure

### Directory Layout

```
pricing/
├── cmd/
│   ├── pricing/          # Main API service
│   │   ├── main.go
│   │   └── wire.go
│   ├── worker/           # NEW: Worker entry point
│   │   ├── main.go       # Worker main
│   │   ├── wire.go       # Worker DI
│   │   └── modes.go      # Worker modes (events, cron)
│   └── migrate/          # Migration job (existing)
│       └── main.go
├── internal/
│   ├── worker/           # NEW: Worker implementations
│   │   ├── event/        # Event workers
│   │   │   ├── stock_updated.go
│   │   │   ├── price_changed.go
│   │   │   └── handler.go
│   │   ├── cron/         # Cron jobs
│   │   │   ├── price_sync.go
│   │   │   ├── cache_warmup.go
│   │   │   └── scheduler.go
│   │   └── worker.go     # Worker interface
│   ├── biz/              # Business logic (shared)
│   ├── data/             # Data layer (shared)
│   └── service/          # API services
```

### Worker Main Entry Point

```go
// cmd/worker/main.go
package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"syscall"

	"github.com/go-kratos/kratos/v2/log"
	"pricing/internal/worker"
	"pricing/internal/worker/cron"
	"pricing/internal/worker/event"
)

var (
	workerMode = flag.String("mode", "events", "Worker mode: events, cron, all")
	flagconf   = flag.String("conf", "../../configs", "config path")
)

func main() {
	flag.Parse()
	
	logger := log.NewStdLogger(os.Stdout)
	
	// Load config
	bc, err := loadConfig(*flagconf)
	if err != nil {
		panic(err)
	}
	
	// Initialize dependencies via Wire
	deps, cleanup, err := wireWorker(bc, logger)
	if err != nil {
		panic(err)
	}
	defer cleanup()
	
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	// Start workers based on mode
	var workers []worker.Worker
	
	switch *workerMode {
	case "events":
		workers = append(workers, 
			event.NewStockUpdatedWorker(deps.PricingUC, logger),
			event.NewPriceChangedWorker(deps.PricingUC, logger),
		)
	case "cron":
		workers = append(workers,
			cron.NewPriceSyncJob(deps.PricingUC, logger),
			cron.NewCacheWarmupJob(deps.PricingUC, logger),
		)
	case "all":
		// Start all workers (for development)
		workers = append(workers,
			event.NewStockUpdatedWorker(deps.PricingUC, logger),
			event.NewPriceChangedWorker(deps.PricingUC, logger),
			cron.NewPriceSyncJob(deps.PricingUC, logger),
			cron.NewCacheWarmupJob(deps.PricingUC, logger),
		)
	default:
		panic("Invalid worker mode: " + *workerMode)
	}
	
	// Start all workers
	for _, w := range workers {
		go func(worker worker.Worker) {
			if err := worker.Start(ctx); err != nil {
				logger.Log(log.LevelError, "msg", "Worker failed", "error", err)
			}
		}(w)
	}
	
	logger.Log(log.LevelInfo, "msg", "Workers started", "mode", *workerMode)
	
	// Wait for interrupt signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
	
	logger.Log(log.LevelInfo, "msg", "Shutting down workers...")
	cancel()
	
	// Graceful shutdown
	for _, w := range workers {
		w.Stop()
	}
}
```

### Worker Interface

```go
// internal/worker/worker.go
package worker

import "context"

// Worker represents a background worker
type Worker interface {
	// Start starts the worker
	Start(ctx context.Context) error
	
	// Stop gracefully stops the worker
	Stop() error
	
	// Name returns the worker name
	Name() string
}

// BaseWorker provides common functionality
type BaseWorker struct {
	name     string
	stopChan chan struct{}
}

func NewBaseWorker(name string) *BaseWorker {
	return &BaseWorker{
		name:     name,
		stopChan: make(chan struct{}),
	}
}

func (w *BaseWorker) Name() string {
	return w.name
}

func (w *BaseWorker) Stop() error {
	close(w.stopChan)
	return nil
}
```

### Event Worker Example

```go
// internal/worker/event/stock_updated.go
package event

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	dapr "github.com/dapr/go-sdk/client"
	"pricing/internal/biz"
	"pricing/internal/worker"
)

type StockUpdatedWorker struct {
	*worker.BaseWorker
	pricingUC  *biz.PricingUseCase
	daprClient dapr.Client
	log        *log.Helper
}

func NewStockUpdatedWorker(pricingUC *biz.PricingUseCase, logger log.Logger) *StockUpdatedWorker {
	daprClient, err := dapr.NewClient()
	if err != nil {
		panic(err)
	}
	
	return &StockUpdatedWorker{
		BaseWorker: worker.NewBaseWorker("stock-updated-worker"),
		pricingUC:  pricingUC,
		daprClient: daprClient,
		log:        log.NewHelper(logger),
	}
}

func (w *StockUpdatedWorker) Start(ctx context.Context) error {
	w.log.Info("Starting stock updated event worker")
	
	// Subscribe to Dapr topic
	subscription := &dapr.Subscription{
		PubsubName: "pubsub",
		Topic:      "warehouse.stock.updated",
		Route:      "/events/stock-updated",
	}
	
	// Start HTTP server for Dapr callbacks
	// Or use Dapr SDK's subscription API
	
	return w.processEvents(ctx)
}

func (w *StockUpdatedWorker) processEvents(ctx context.Context) error {
	// Process events with retry logic
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-w.stopChan:
			return nil
		default:
			// Process event
			// Implement retry logic with exponential backoff
		}
	}
}

func (w *StockUpdatedWorker) handleEvent(ctx context.Context, event *StockUpdatedEvent) error {
	w.log.WithContext(ctx).Infof("Processing stock updated event: %s", event.ProductID)
	
	// Check if we have dynamic pricing rules
	rules, err := w.pricingUC.GetStockBasedRules(ctx, event.ProductID)
	if err != nil {
		return fmt.Errorf("failed to get pricing rules: %w", err)
	}
	
	// Apply dynamic pricing based on stock level
	for _, rule := range rules {
		if w.shouldApplyRule(rule, event) {
			newPrice := w.calculateDynamicPrice(rule, event)
			
			err := w.pricingUC.UpdatePrice(ctx, &biz.Price{
				ProductID:   event.ProductID,
				SKU:         &event.SKU,
				WarehouseID: &event.WarehouseID,
				BasePrice:   newPrice,
			})
			
			if err != nil {
				return fmt.Errorf("failed to update price: %w", err)
			}
			
			w.log.Infof("Updated price for %s: %f", event.SKU, newPrice)
		}
	}
	
	return nil
}

type StockUpdatedEvent struct {
	ProductID   string
	SKU         string
	WarehouseID string
	OldStock    int64
	NewStock    int64
	Timestamp   time.Time
}
```

### Cron Worker Example

```go
// internal/worker/cron/price_sync.go
package cron

import (
	"context"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/robfig/cron/v3"
	"pricing/internal/biz"
	"pricing/internal/worker"
)

type PriceSyncJob struct {
	*worker.BaseWorker
	pricingUC *biz.PricingUseCase
	cron      *cron.Cron
	log       *log.Helper
}

func NewPriceSyncJob(pricingUC *biz.PricingUseCase, logger log.Logger) *PriceSyncJob {
	return &PriceSyncJob{
		BaseWorker: worker.NewBaseWorker("price-sync-job"),
		pricingUC:  pricingUC,
		cron:       cron.New(),
		log:        log.NewHelper(logger),
	}
}

func (j *PriceSyncJob) Start(ctx context.Context) error {
	j.log.Info("Starting price sync cron job")
	
	// Schedule: Every 5 minutes
	_, err := j.cron.AddFunc("*/5 * * * *", func() {
		j.syncPrices(ctx)
	})
	if err != nil {
		return err
	}
	
	// Schedule: Daily cache warmup at 2 AM
	_, err = j.cron.AddFunc("0 2 * * *", func() {
		j.warmupCache(ctx)
	})
	if err != nil {
		return err
	}
	
	j.cron.Start()
	
	// Wait for stop signal
	<-j.stopChan
	return nil
}

func (j *PriceSyncJob) Stop() error {
	j.log.Info("Stopping price sync cron job")
	j.cron.Stop()
	return j.BaseWorker.Stop()
}

func (j *PriceSyncJob) syncPrices(ctx context.Context) {
	startTime := time.Now()
	j.log.Info("Starting price sync")
	
	// Sync prices from external sources
	err := j.pricingUC.SyncPricesFromWarehouse(ctx)
	if err != nil {
		j.log.Errorf("Failed to sync prices: %v", err)
		return
	}
	
	duration := time.Since(startTime)
	j.log.Infof("Price sync completed in %v", duration)
}

func (j *PriceSyncJob) warmupCache(ctx context.Context) {
	j.log.Info("Starting cache warmup")
	
	err := j.pricingUC.WarmupPriceCache(ctx)
	if err != nil {
		j.log.Errorf("Failed to warmup cache: %v", err)
		return
	}
	
	j.log.Info("Cache warmup completed")
}
```

---

## 🟡 MEDIUM Priority: Separate Cron Workers

**When to separate:**
- ✅ Cron jobs run > 1 minute
- ✅ Multiple scheduled jobs with different intervals
- ✅ Jobs require significant resources (memory, CPU)
- ✅ Need job history and monitoring

**Current Catalog Service:**
```go
// catalog/cmd/catalog/main.go
// ⚠️ Current: Inline in main service
go func() {
    stockSyncJob := job.NewStockSyncJob(productUsecase, logger, 1*time.Minute)
    stockSyncJob.Start(ctx)
}()
```

**Recommended: Separate Worker:**
```yaml
# catalog/docker-compose.yml
services:
  catalog-service:
    # API service only
    environment:
      - WORKER_MODE=api

  catalog-cron-worker:
    build:
      context: ..
      dockerfile: catalog/Dockerfile.optimized
      args:
        MAIN_PKG: ./cmd/worker
    container_name: catalog-cron-worker
    environment:
      - WORKER_MODE=cron
    depends_on:
      - catalog-service
    networks:
      - microservices
    restart: unless-stopped
```

---

## 🟢 LOW Priority: Keep Inline

**When to keep inline:**
- ✅ Simple event handlers (< 50ms processing)
- ✅ Low event volume (< 100 events/minute)
- ✅ Simple cron jobs (< 10 seconds)
- ✅ No retry logic needed
- ✅ Development/staging environments

**Example: Simple health check ticker**
```go
// Keep inline - simple and lightweight
ticker := time.NewTicker(30 * time.Second)
defer ticker.Stop()
```

---

## 📊 Decision Matrix

| Criteria | Inline | Separate Worker |
|----------|--------|-----------------|
| **Event Volume** | < 100/min | > 100/min |
| **Processing Time** | < 50ms | > 50ms |
| **Retry Logic** | No | Yes |
| **Resource Usage** | Low | High |
| **Scaling Needs** | No | Yes |
| **Monitoring** | Basic | Advanced |
| **Deployment Frequency** | High | Low |

---

## 🎯 Recommendations by Service

### Pricing Service 🔴 HIGH Priority

**Separate:**
- ✅ Event Worker: Stock-based dynamic pricing
- ✅ Event Worker: Price change notifications
- ✅ Cron Worker: Price sync from external sources
- ✅ Cron Worker: Cache warmup (daily)

**Reason:**
- High event volume from warehouse
- Complex pricing calculations
- Need retry logic for price updates
- Resource-intensive cache warmup

### Catalog Service 🟡 MEDIUM Priority

**Separate:**
- ⚠️ Cron Worker: Stock sync job (currently inline)
- ⚠️ Event Worker: Product updates (if volume increases)

**Keep Inline:**
- ✅ Simple event handlers (low volume)

**Reason:**
- Stock sync runs every 1 minute (can be heavy)
- Event volume currently manageable
- Can separate later if needed

### Warehouse Service 🟢 LOW Priority

**Keep Inline:**
- ✅ Event publishing (lightweight)
- ✅ Simple notifications

**Reason:**
- Low processing overhead
- Event publishing is fast
- No complex background jobs

---

## 🚀 Migration Path

### Phase 1: Pricing Service (Week 1-2)

1. Create `cmd/worker` directory
2. Implement worker interface
3. Move event handlers to workers
4. Move cron jobs to workers
5. Update docker-compose.yml
6. Deploy and monitor

### Phase 2: Catalog Service (Week 3-4)

1. Extract stock sync job to worker
2. Add event worker if needed
3. Update docker-compose.yml
4. Deploy and monitor

### Phase 3: Other Services (As Needed)

- Evaluate based on metrics
- Separate workers when criteria met

---

## 📈 Monitoring & Observability

### Metrics to Track

```go
// Worker metrics
var (
	WorkerJobsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "worker_jobs_total",
			Help: "Total number of jobs processed",
		},
		[]string{"worker", "status"},
	)
	
	WorkerJobDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "worker_job_duration_seconds",
			Help: "Job processing duration",
		},
		[]string{"worker"},
	)
	
	WorkerQueueSize = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "worker_queue_size",
			Help: "Current queue size",
		},
		[]string{"worker"},
	)
)
```

### Health Checks

```go
// Worker health endpoint
func (w *Worker) Health() map[string]interface{} {
	return map[string]interface{}{
		"name":           w.Name(),
		"status":         "running",
		"jobs_processed": w.jobsProcessed,
		"last_run":       w.lastRun,
		"queue_size":     w.queueSize,
	}
}
```

---

## ✅ Summary

### Do Separate Workers When:
- ✅ High event volume (> 100/min)
- ✅ Long processing time (> 50ms)
- ✅ Need retry logic
- ✅ Resource-intensive jobs
- ✅ Need independent scaling
- ✅ Production environment

### Keep Inline When:
- ✅ Low event volume (< 100/min)
- ✅ Fast processing (< 50ms)
- ✅ Simple logic
- ✅ Low resource usage
- ✅ Development environment

### Priority:
1. 🔴 **Pricing Service** - Separate event & cron workers
2. 🟡 **Catalog Service** - Separate cron worker (stock sync)
3. 🟢 **Warehouse Service** - Keep inline (for now)

---

**Created by:** Kiro AI  
**Last Updated:** November 9, 2024
