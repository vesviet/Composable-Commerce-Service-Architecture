# ⚡ Workers Separation - Quick Start Guide

> **Get started in 30 minutes!**

---

## 🚀 Quick Setup (Pricing Event Worker)

### Step 1: Create Structure (5 min)

```bash
cd pricing

# Create directories
mkdir -p cmd/worker
mkdir -p internal/worker/event
mkdir -p internal/worker/cron
mkdir -p internal/worker/base

# Create files
touch cmd/worker/main.go
touch cmd/worker/wire.go
touch internal/worker/base/worker.go
touch internal/worker/event/stock_updated.go
```

### Step 2: Worker Interface (5 min)

**File:** `internal/worker/base/worker.go`

```go
package base

import (
	"context"
	"github.com/go-kratos/kratos/v2/log"
)

type Worker interface {
	Start(ctx context.Context) error
	Stop() error
	Name() string
}

type BaseWorker struct {
	name     string
	stopChan chan struct{}
	log      *log.Helper
}

func NewBaseWorker(name string, logger log.Logger) *BaseWorker {
	return &BaseWorker{
		name:     name,
		stopChan: make(chan struct{}),
		log:      log.NewHelper(logger),
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

### Step 3: Worker Main (10 min)

**File:** `cmd/worker/main.go`

```go
package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"syscall"
	
	"github.com/go-kratos/kratos/v2/log"
	"pricing/internal/worker/event"
)

var (
	workerMode = flag.String("mode", "events", "Worker mode: events|cron|all")
	flagconf   = flag.String("conf", "../../configs", "config path")
)

func main() {
	flag.Parse()
	
	logger := log.NewStdLogger(os.Stdout)
	log.NewHelper(logger).Info("Starting worker", "mode", *workerMode)
	
	// TODO: Load config and wire dependencies
	// deps := initDependencies(*flagconf, logger)
	
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	// Start workers based on mode
	var workers []interface{ Start(context.Context) error; Stop() error }
	
	switch *workerMode {
	case "events":
		// workers = append(workers, event.NewStockUpdatedWorker(deps.PricingUC, logger))
		log.NewHelper(logger).Info("Event worker mode")
	case "cron":
		log.NewHelper(logger).Info("Cron worker mode")
	case "all":
		log.NewHelper(logger).Info("All workers mode")
	}
	
	// Start all workers
	for _, w := range workers {
		go w.Start(ctx)
	}
	
	// Wait for signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
	
	log.NewHelper(logger).Info("Shutting down...")
	for _, w := range workers {
		w.Stop()
	}
}
```

### Step 4: Event Worker (10 min)

**File:** `internal/worker/event/stock_updated.go`

```go
package event

import (
	"context"
	"github.com/go-kratos/kratos/v2/log"
	"pricing/internal/biz"
	"pricing/internal/worker/base"
)

type StockUpdatedWorker struct {
	*base.BaseWorker
	pricingUC *biz.PricingUseCase
}

func NewStockUpdatedWorker(uc *biz.PricingUseCase, logger log.Logger) *StockUpdatedWorker {
	return &StockUpdatedWorker{
		BaseWorker: base.NewBaseWorker("stock-updated-worker", logger),
		pricingUC:  uc,
	}
}

func (w *StockUpdatedWorker) Start(ctx context.Context) error {
	w.log.Info("Starting stock updated worker")
	
	// TODO: Subscribe to Dapr events
	// TODO: Process events with retry
	
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-w.stopChan:
			return nil
		// TODO: Process events
		}
	}
}
```

### Step 5: Update Docker Compose (5 min)

**File:** `pricing/docker-compose.yml`

```yaml
services:
  pricing-service:
    # ... existing config ...
    environment:
      - WORKER_MODE=api  # API only
  
  pricing-event-worker:
    build:
      context: ..
      dockerfile: pricing/Dockerfile
      args:
        MAIN_PKG: ./cmd/worker
        BIN_NAME: worker
    container_name: pricing-event-worker
    environment:
      - KRATOS_CONF=/app/configs
      - WORKER_MODE=events
    volumes:
      - ./configs/config-docker.yaml:/app/configs/config.yaml
    depends_on:
      - pricing-service
    networks:
      - microservices
    restart: unless-stopped
```

### Step 6: Test (5 min)

```bash
# Build
docker compose build pricing-event-worker

# Run
docker compose up pricing-event-worker

# Check logs
docker logs -f pricing-event-worker
```

---

## 📋 Next Steps

1. ✅ Complete Step 1-6 above
2. ⏳ Implement full event processing logic
3. ⏳ Add Wire dependency injection
4. ⏳ Add retry logic and idempotency
5. ⏳ Add metrics and monitoring
6. ⏳ Create cron worker
7. ⏳ Full testing

---

## 🔗 Full Checklist

See [WORKERS_SEPARATION_CHECKLIST.md](./WORKERS_SEPARATION_CHECKLIST.md) for complete implementation guide.

---

**Time to complete:** 30 minutes for basic setup  
**Time to production:** 3-5 days for full implementation
