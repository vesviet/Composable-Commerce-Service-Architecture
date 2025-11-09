# ⚡ Workers Quick Implementation Guide

> **TL;DR:** Hướng dẫn nhanh implement workers cho microservices

---

## 🎯 Quick Decision Tree

```
Do you need separate workers?
│
├─ Event processing > 100ms? ──────────────────────► YES → Separate Event Worker
├─ Event volume > 1000/min? ───────────────────────► YES → Separate Event Worker
├─ Cron job runtime > 1 minute? ───────────────────► YES → Separate Cron Worker
├─ Need retry logic? ──────────────────────────────► YES → Separate Worker
├─ Need independent scaling? ──────────────────────► YES → Separate Worker
└─ Simple & fast (< 50ms)? ────────────────────────► NO  → Keep Inline
```

---

## 📦 Quick Setup: Pricing Service Example

### Step 1: Create Worker Directory Structure (5 minutes)

```bash
cd pricing
mkdir -p cmd/worker
mkdir -p internal/worker/event
mkdir -p internal/worker/cron
```

### Step 2: Create Worker Main (10 minutes)

```go
// cmd/worker/main.go
package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"syscall"
)

var workerMode = flag.String("mode", "events", "events|cron|all")

func main() {
	flag.Parse()
	
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	// Load config & dependencies (use existing Wire setup)
	deps := initDependencies()
	
	// Start workers based on mode
	switch *workerMode {
	case "events":
		startEventWorkers(ctx, deps)
	case "cron":
		startCronWorkers(ctx, deps)
	case "all":
		startEventWorkers(ctx, deps)
		startCronWorkers(ctx, deps)
	}
	
	// Wait for signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
}
```

### Step 3: Create Event Worker (15 minutes)

```go
// internal/worker/event/stock_updated.go
package event

import (
	"context"
	"github.com/go-kratos/kratos/v2/log"
	"pricing/internal/biz"
)

type StockUpdatedWorker struct {
	pricingUC *biz.PricingUseCase
	log       *log.Helper
	stopChan  chan struct{}
}

func NewStockUpdatedWorker(uc *biz.PricingUseCase, logger log.Logger) *StockUpdatedWorker {
	return &StockUpdatedWorker{
		pricingUC: uc,
		log:       log.NewHelper(logger),
		stopChan:  make(chan struct{}),
	}
}

func (w *StockUpdatedWorker) Start(ctx context.Context) error {
	w.log.Info("Starting stock updated worker")
	
	// Subscribe to Dapr events
	// Process events with retry
	
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-w.stopChan:
			return nil
		// Process events
		}
	}
}

func (w *StockUpdatedWorker) Stop() {
	close(w.stopChan)
}
```

### Step 4: Create Cron Worker (15 minutes)

```go
// internal/worker/cron/price_sync.go
package cron

import (
	"context"
	"github.com/robfig/cron/v3"
	"pricing/internal/biz"
)

type PriceSyncJob struct {
	pricingUC *biz.PricingUseCase
	cron      *cron.Cron
}

func NewPriceSyncJob(uc *biz.PricingUseCase) *PriceSyncJob {
	return &PriceSyncJob{
		pricingUC: uc,
		cron:      cron.New(),
	}
}

func (j *PriceSyncJob) Start(ctx context.Context) error {
	// Every 5 minutes
	j.cron.AddFunc("*/5 * * * *", func() {
		j.pricingUC.SyncPrices(ctx)
	})
	
	j.cron.Start()
	<-ctx.Done()
	return nil
}
```

### Step 5: Update Docker Compose (10 minutes)

```yaml
# pricing/docker-compose.yml
services:
  pricing-service:
    # Main API service
    environment:
      - WORKER_MODE=api
    
  pricing-event-worker:
    build:
      context: ..
      dockerfile: pricing/Dockerfile
      args:
        MAIN_PKG: ./cmd/worker
    container_name: pricing-event-worker
    environment:
      - WORKER_MODE=events
    depends_on:
      - pricing-service
    networks:
      - microservices
    restart: unless-stopped
    
  pricing-cron-worker:
    build:
      context: ..
      dockerfile: pricing/Dockerfile
      args:
        MAIN_PKG: ./cmd/worker
    container_name: pricing-cron-worker
    environment:
      - WORKER_MODE=cron
    depends_on:
      - pricing-service
    networks:
      - microservices
    restart: unless-stopped
```

### Step 6: Update Dockerfile (5 minutes)

```dockerfile
# pricing/Dockerfile
ARG MAIN_PKG=./cmd/pricing
ARG BIN_NAME=pricing

FROM golang:1.21-alpine AS builder
ARG MAIN_PKG
ARG BIN_NAME

WORKDIR /src
COPY . .
RUN go build -o /app/bin/${BIN_NAME} ${MAIN_PKG}

FROM alpine:latest
ARG BIN_NAME
COPY --from=builder /app/bin/${BIN_NAME} /app/bin/${BIN_NAME}
ENTRYPOINT ["/app/bin/${BIN_NAME}"]
```

---

## 🚀 Quick Commands

### Build & Run

```bash
# Build worker
docker compose build pricing-event-worker

# Run event worker
docker compose up pricing-event-worker

# Run cron worker
docker compose up pricing-cron-worker

# Run all
docker compose up
```

### Development

```bash
# Run worker locally
go run cmd/worker/main.go -mode=events

# Run with config
go run cmd/worker/main.go -mode=cron -conf=./configs
```

### Monitoring

```bash
# Check worker logs
docker logs -f pricing-event-worker

# Check worker status
docker ps | grep worker

# Check worker health
curl http://localhost:8002/worker/health
```

---

## 📊 Quick Metrics

### Add to Worker

```go
import "github.com/prometheus/client_golang/prometheus"

var (
	jobsProcessed = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "worker_jobs_total",
		},
		[]string{"worker", "status"},
	)
)

func init() {
	prometheus.MustRegister(jobsProcessed)
}

// In worker
jobsProcessed.WithLabelValues("stock-updated", "success").Inc()
```

---

## 🔍 Quick Debugging

### Common Issues

**Worker not starting:**
```bash
# Check logs
docker logs pricing-event-worker

# Check dependencies
docker compose ps

# Check network
docker network inspect source_microservices
```

**Events not processing:**
```bash
# Check Dapr subscription
curl http://localhost:3500/v1.0/metadata

# Check Redis
redis-cli MONITOR

# Check event publishing
curl -X POST http://localhost:3500/v1.0/publish/pubsub/test
```

**Cron not running:**
```bash
# Check cron schedule
docker exec pricing-cron-worker ps aux

# Check logs
docker logs pricing-cron-worker | grep "cron"
```

---

## ✅ Quick Checklist

### Before Separating Workers

- [ ] Measure current performance (event volume, processing time)
- [ ] Identify bottlenecks (CPU, memory, I/O)
- [ ] Estimate resource requirements
- [ ] Plan deployment strategy

### After Separating Workers

- [ ] Monitor worker health
- [ ] Check event processing latency
- [ ] Verify job completion
- [ ] Monitor resource usage
- [ ] Set up alerts

---

## 🎯 Service-Specific Recommendations

### Pricing Service
```
✅ Separate: Event worker (stock updates)
✅ Separate: Cron worker (price sync)
Priority: HIGH
Time: 2-3 days
```

### Catalog Service
```
⚠️ Separate: Cron worker (stock sync)
✅ Keep inline: Event handlers (for now)
Priority: MEDIUM
Time: 1-2 days
```

### Warehouse Service
```
✅ Keep inline: All workers
Priority: LOW
Time: N/A
```

---

## 📚 Quick References

### Cron Schedule Examples

```
*/5 * * * *     # Every 5 minutes
0 * * * *       # Every hour
0 2 * * *       # Daily at 2 AM
0 0 * * 0       # Weekly on Sunday
0 0 1 * *       # Monthly on 1st
```

### Dapr Topics

```
warehouse.stock.updated
warehouse.inventory.low_stock
pricing.price.updated
catalog.product.created
```

### Resource Limits

```yaml
# Light worker
resources:
  limits:
    cpus: '0.5'
    memory: 256M

# Medium worker
resources:
  limits:
    cpus: '1'
    memory: 512M

# Heavy worker
resources:
  limits:
    cpus: '2'
    memory: 1G
```

---

## 🔗 Related Docs

- [Full Architecture Guide](./JOBS_AND_WORKERS_ARCHITECTURE.md)
- [Pricing Implementation](../pricing/PRICING_SKU_WAREHOUSE_CHECKLIST.md)
- [Stock Integration](../catalog/STOCK_IMPLEMENTATION_SUMMARY.md)

---

**Total Setup Time:** ~1 hour per service  
**Difficulty:** Medium  
**Impact:** High (better scalability & reliability)
