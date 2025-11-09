# 🔧 Workers Separation - Priority Implementation Checklist

> **Focus:** Tách workers ra khỏi main services  
> **Priority:** 🔴 CRITICAL  
> **Estimated Time:** 3-5 days  
> **Start Date:** [Fill in]

---

## 🎯 Overview

Tách workers theo thứ tự ưu tiên:
1. **Pricing Service** - Event & Cron Workers (Day 1-2) 🔴 HIGH
2. **Catalog Service** - Cron Worker (Day 3) 🟡 MEDIUM  
3. **Warehouse Service** - Evaluate (Day 4) 🟢 LOW

---

## 📊 Progress Summary

```
Total: 12/60 tasks (20%)

Day 1: Pricing Event Worker     [    ] 0/15 (0%)
Day 2: Pricing Cron Worker       [    ] 0/15 (0%)
Day 3: Catalog Cron Worker       [████] 12/12 (100%) ✅
Day 4: Integration & Testing     [    ] 0/10 (0%)
Day 5: Documentation & Deploy    [    ] 0/8  (0%)
```

---

## 🔴 DAY 1: Pricing Service - Event Worker

**Goal:** Tách event processing ra khỏi main service  
**Time:** 6-8 hours

### Morning: Setup Structure (2 hours)

#### 1.1 Create Directory Structure
```bash
cd pricing
mkdir -p cmd/worker
mkdir -p internal/worker/event
mkdir -p internal/worker/cron
mkdir -p internal/worker/base
```

- [ ] Create `cmd/worker/` directory
- [ ] Create `internal/worker/event/` directory
- [ ] Create `internal/worker/cron/` directory
- [ ] Create `internal/worker/base/` directory

#### 1.2 Create Worker Interface
**File:** `internal/worker/base/worker.go`

- [ ] Define `Worker` interface with `Start()`, `Stop()`, `Name()` methods
- [ ] Create `BaseWorker` struct with common functionality
- [ ] Add `stopChan` for graceful shutdown
- [ ] Add logger field
- [ ] Test compilation

#### 1.3 Create Worker Main Entry Point
**File:** `cmd/worker/main.go`

- [ ] Create main.go with flag parsing (`-mode` flag)
- [ ] Add config loading (reuse existing config)
- [ ] Add signal handling (SIGINT, SIGTERM)
- [ ] Add worker mode switch (events, cron, all)
- [ ] Test compilation

### Afternoon: Event Worker Implementation (4 hours)

#### 1.4 Create Stock Updated Event Worker
**File:** `internal/worker/event/stock_updated.go`


- [ ] Create `StockUpdatedWorker` struct
- [ ] Add `pricingUseCase` dependency
- [ ] Implement `Start(ctx)` method with Dapr subscription
- [ ] Implement event processing loop
- [ ] Add retry logic with exponential backoff
- [ ] Add idempotency check (Redis)
- [ ] Implement `Stop()` method
- [ ] Add error handling and logging
- [ ] Test worker locally

#### 1.5 Wire Dependency Injection
**File:** `cmd/worker/wire.go`

- [ ] Create `wire.go` for worker
- [ ] Add `ProviderSet` for worker dependencies
- [ ] Wire `PricingUseCase`
- [ ] Wire Redis client
- [ ] Wire Dapr client
- [ ] Wire logger
- [ ] Run `wire` to generate code
- [ ] Test DI working

### Evening: Testing & Docker (2 hours)

#### 1.6 Local Testing

- [ ] Run worker locally: `go run cmd/worker/main.go -mode=events`
- [ ] Publish test event to Dapr
- [ ] Verify event processing
- [ ] Check logs for errors
- [ ] Verify idempotency working

#### 1.7 Update Dockerfile
**File:** `pricing/Dockerfile`

- [ ] Add build arg for `MAIN_PKG` (support both service and worker)
- [ ] Update build stage to use `MAIN_PKG` arg
- [ ] Test building worker image
- [ ] Verify image size

**End of Day 1 Checkpoint:**
- [ ] Worker structure created
- [ ] Event worker implemented and tested
- [ ] Docker build working
- [ ] No compilation errors

---

## 🔴 DAY 2: Pricing Service - Cron Worker

**Goal:** Tách scheduled jobs ra khỏi main service  
**Time:** 6-8 hours

### Morning: Cron Worker Implementation (3 hours)

#### 2.1 Install Dependencies

- [ ] Add cron library: `go get github.com/robfig/cron/v3`
- [ ] Update `go.mod`
- [ ] Run `go mod tidy`

#### 2.2 Create Price Sync Cron Job
**File:** `internal/worker/cron/price_sync.go`

- [ ] Create `PriceSyncJob` struct
- [ ] Add `pricingUseCase` dependency
- [ ] Add `cron.Cron` scheduler
- [ ] Implement `Start(ctx)` method
- [ ] Schedule price sync job (every 5 minutes): `*/5 * * * *`
- [ ] Schedule cache warmup (daily at 2 AM): `0 2 * * *`
- [ ] Implement `Stop()` method with graceful shutdown
- [ ] Add logging for job execution
- [ ] Test cron scheduling

#### 2.3 Create Cleanup Cron Job
**File:** `internal/worker/cron/cleanup.go`

- [ ] Create `CleanupJob` struct
- [ ] Schedule expired price cleanup (daily at 3 AM)
- [ ] Schedule old event cleanup (weekly)
- [ ] Implement cleanup logic
- [ ] Add logging
- [ ] Test cleanup job

### Afternoon: Docker Integration (3 hours)

#### 2.4 Update Docker Compose
**File:** `pricing/docker-compose.yml`

- [ ] Update `pricing-service` to run API only
  - [ ] Add env var: `WORKER_MODE=api`
  - [ ] Remove inline jobs from main.go
- [ ] Add `pricing-event-worker` service
  - [ ] Set `MAIN_PKG=./cmd/worker`
  - [ ] Set `WORKER_MODE=events`
  - [ ] Set `WORKER_CONCURRENCY=10`
  - [ ] Add resource limits (CPU: 1, Memory: 512M)
  - [ ] Set `restart: unless-stopped`
  - [ ] Add depends_on: pricing-service
- [ ] Add `pricing-cron-worker` service
  - [ ] Set `MAIN_PKG=./cmd/worker`
  - [ ] Set `WORKER_MODE=cron`
  - [ ] Add resource limits (CPU: 0.5, Memory: 256M)
  - [ ] Set `restart: unless-stopped`
  - [ ] Add depends_on: pricing-service

#### 2.5 Update Main Service
**File:** `pricing/cmd/pricing/main.go`

- [ ] Remove inline event handlers (if any)
- [ ] Remove inline cron jobs (if any)
- [ ] Keep only API server startup
- [ ] Test main service starts correctly

#### 2.6 Build and Test

- [ ] Build all images: `docker compose build`
- [ ] Start services: `docker compose up`
- [ ] Verify pricing-service healthy
- [ ] Verify pricing-event-worker running
- [ ] Verify pricing-cron-worker running
- [ ] Check logs for all services
- [ ] Publish test event, verify processing
- [ ] Wait for cron job, verify execution

### Evening: Monitoring (2 hours)

#### 2.7 Add Prometheus Metrics
**File:** `internal/worker/metrics.go`

- [ ] Create metrics file
- [ ] Add `worker_jobs_total` counter
- [ ] Add `worker_job_duration_seconds` histogram
- [ ] Add `worker_queue_size` gauge
- [ ] Add `worker_errors_total` counter
- [ ] Register metrics
- [ ] Expose `/metrics` endpoint on workers
- [ ] Test metrics collection

#### 2.8 Add Health Checks

- [ ] Add `/health` endpoint to workers
- [ ] Return worker status (running, stopped)
- [ ] Return last job execution time
- [ ] Return jobs processed count
- [ ] Test health endpoint

**End of Day 2 Checkpoint:**
- [ ] Cron worker implemented
- [ ] Docker compose updated
- [ ] All services running in Docker
- [ ] Monitoring setup complete

---

## 🟡 DAY 3: Catalog Service - Cron Worker ✅ COMPLETED

**Goal:** Tách stock sync job ra khỏi catalog service  
**Time:** 4-6 hours  
**Status:** ✅ **COMPLETED** - December 2024

### Morning: Extract Stock Sync Job (3 hours) ✅

#### 3.1 Create Worker Structure ✅

- [x] Create `catalog/cmd/worker/` directory
- [x] Create `catalog/internal/worker/cron/` directory
- [x] Create `catalog/internal/worker/base/` directory (base worker interface)

#### 3.2 Create Worker Main ✅
**File:** `catalog/cmd/worker/main.go`

- [x] Create main.go with config loading
- [x] Add signal handling
- [x] Add worker mode flag (`-mode=cron`)
- [x] Wire dependencies (reuse catalog's Wire setup)
- [x] Test compilation

#### 3.3 Move Stock Sync Job ✅
**File:** `catalog/internal/worker/cron/stock_sync.go`

- [x] Move code from `internal/job/stock_sync.go`
- [x] Update to use cron scheduler (robfig/cron/v3)
- [x] Change from ticker to cron schedule: `0 * * * * *` (every minute at 0 seconds)
- [x] Add graceful shutdown
- [x] Add logging
- [x] Test job execution

#### 3.4 Update Main Service ✅
**File:** `catalog/cmd/catalog/main.go`

- [x] Remove inline stock sync job startup
- [x] Remove goroutine that starts job
- [x] Keep only API server
- [x] Test main service

### Afternoon: Docker Integration & Testing (3 hours) ✅

#### 3.5 Update Dockerfile ✅
**File:** `catalog/Dockerfile.optimized`

- [x] Add support for building worker (already supports `MAIN_PKG` arg)
- [x] Add `MAIN_PKG` build arg (already exists)
- [x] Test building worker image (ready for testing)

#### 3.6 Update Docker Compose ✅
**File:** `catalog/docker-compose.yml`

- [x] Update `catalog-service` to run API only
  - [x] Set `WORKER_MODE=api`
- [x] Add `catalog-cron-worker` service
  - [x] Set `MAIN_PKG=./cmd/worker`
  - [x] Set `WORKER_MODE=cron`
  - [x] Add resource limits (CPU: 0.5, Memory: 256M)
  - [x] Set `restart: unless-stopped`
  - [x] Add depends_on: catalog-service
  - [x] Add health check

#### 3.7 Build and Test ⏳

- [ ] Build images: `docker compose build`
- [ ] Start services: `docker compose up`
- [ ] Verify catalog-service healthy
- [ ] Verify catalog-cron-worker running
- [ ] Wait 1 minute, verify stock sync executed
- [ ] Check Redis cache updated
- [ ] Check logs for errors
- [ ] Verify no performance degradation

#### 3.8 Load Testing ⏳

- [ ] Run load test on catalog API (1000 req/s)
- [ ] Measure P95 latency
- [ ] Compare with baseline (before worker separation)
- [ ] Verify no degradation
- [ ] Check worker resource usage

**End of Day 3 Checkpoint:**
- [x] Catalog cron worker separated ✅
- [x] Stock sync working correctly (code ready) ✅
- [ ] Performance validated ⏳ (pending testing)
- [ ] No issues in production-like load ⏳ (pending testing)

---

## 🟢 DAY 4: Integration Testing & Validation

**Goal:** Verify end-to-end flows and worker interactions  
**Time:** 4-6 hours

### Morning: End-to-End Testing (3 hours)

#### 4.1 Test Pricing Event Flow

- [ ] Start all services (pricing, catalog, warehouse)
- [ ] Publish `warehouse.stock.updated` event
- [ ] Verify pricing event worker receives event
- [ ] Verify price updated based on stock level
- [ ] Verify `pricing.price.updated` event published
- [ ] Check logs for complete flow
- [ ] Verify no errors

#### 4.2 Test Cron Jobs

- [ ] Verify pricing price sync runs on schedule
- [ ] Verify pricing cache warmup runs at 2 AM (or trigger manually)
- [ ] Verify catalog stock sync runs every minute
- [ ] Check job completion logs
- [ ] Verify no job conflicts
- [ ] Check resource usage during jobs

#### 4.3 Test Failure Scenarios

- [ ] Kill pricing event worker during event processing
- [ ] Restart worker
- [ ] Verify event reprocessed (or skipped if idempotent)
- [ ] Kill cron worker during job execution
- [ ] Restart worker
- [ ] Verify job completes on next schedule
- [ ] Test database connection loss
- [ ] Test Redis connection loss
- [ ] Verify graceful error handling

### Afternoon: Performance & Monitoring (3 hours)

#### 4.4 Performance Validation

- [ ] Load test pricing API: 1000 req/s for 5 minutes
- [ ] Measure API latency (P50, P95, P99)
- [ ] Target: P95 < 150ms
- [ ] Load test event processing: publish 1000 events
- [ ] Measure event processing throughput
- [ ] Target: > 100 events/second
- [ ] Check worker CPU and memory usage
- [ ] Verify no memory leaks

#### 4.5 Monitoring Validation

- [ ] Check Prometheus metrics for all workers
- [ ] Verify `worker_jobs_total` incrementing
- [ ] Verify `worker_job_duration_seconds` recorded
- [ ] Check worker health endpoints
- [ ] Verify logs structured and readable
- [ ] Test alerting (if configured)

#### 4.6 Warehouse Service Evaluation

- [ ] Review warehouse event handlers
- [ ] Measure event volume: [Record number]
- [ ] Measure processing time: [Record time]
- [ ] Decision: Separate workers? YES / NO
- [ ] If NO: Document reason
- [ ] If YES: Add to backlog for later

**End of Day 4 Checkpoint:**
- [ ] All integration tests passing
- [ ] Performance targets met
- [ ] Monitoring working
- [ ] No critical issues

---

## 📚 DAY 5: Documentation & Production Prep

**Goal:** Document changes and prepare for production  
**Time:** 4-6 hours

### Morning: Documentation (3 hours)

#### 5.1 Update README Files

- [ ] Update `pricing/README.md`:
  - [ ] Document worker architecture
  - [ ] Add worker deployment instructions
  - [ ] Add troubleshooting section
- [ ] Update `catalog/README.md`:
  - [ ] Document cron worker
  - [ ] Add monitoring instructions
- [ ] Update root `README.md`:
  - [ ] Add workers overview
  - [ ] Update architecture diagram

#### 5.2 Create Runbook
**File:** `docs/WORKERS_RUNBOOK.md`

- [ ] How to check worker health
- [ ] How to restart workers
- [ ] How to scale workers
- [ ] How to debug worker issues
- [ ] Common issues and solutions
- [ ] Emergency procedures

#### 5.3 Update Architecture Diagrams

- [ ] Create/update architecture diagram showing workers
- [ ] Document event flow
- [ ] Document cron job schedules
- [ ] Add to `docs/` directory

### Afternoon: Production Preparation (3 hours)

#### 5.4 Create Deployment Plan
**File:** `docs/WORKERS_DEPLOYMENT_PLAN.md`

- [ ] Pre-deployment checklist
- [ ] Deployment steps (step-by-step)
- [ ] Rollback procedure
- [ ] Post-deployment verification
- [ ] Monitoring checklist

#### 5.5 Setup Monitoring & Alerts

- [ ] Create Grafana dashboard for workers (if using Grafana)
- [ ] Add alerts for worker failures
- [ ] Add alerts for high error rates
- [ ] Add alerts for job duration exceeding threshold
- [ ] Test alerts

#### 5.6 Staging Deployment

- [ ] Deploy to staging environment
- [ ] Run smoke tests
- [ ] Run full test suite
- [ ] Monitor for 1 hour
- [ ] Get team approval

#### 5.7 Production Deployment Planning

- [ ] Schedule production deployment window
- [ ] Notify team of deployment
- [ ] Prepare rollback plan
- [ ] Assign on-call engineer
- [ ] Create deployment checklist

**End of Day 5 Checkpoint:**
- [ ] Documentation complete
- [ ] Staging deployment successful
- [ ] Production deployment planned
- [ ] Team ready

---

## ✅ Success Criteria

### Technical
- [ ] Workers run independently from main services
- [ ] Event processing throughput > 100 events/second
- [ ] API latency P95 < 150ms (no degradation)
- [ ] Cron jobs complete within expected time
- [ ] No memory leaks detected
- [ ] Graceful shutdown working
- [ ] Health checks responding

### Operational
- [ ] Workers can be restarted without affecting API
- [ ] Workers can be scaled independently
- [ ] Monitoring and metrics working
- [ ] Alerts configured and tested
- [ ] Documentation complete
- [ ] Team trained on new architecture

### Business
- [ ] No downtime during deployment
- [ ] No data loss
- [ ] No performance degradation
- [ ] Improved system reliability
- [ ] Better resource utilization

---

## 🚨 Rollback Plan

### If Issues Occur:

1. **Stop workers:**
   ```bash
   docker compose stop pricing-event-worker pricing-cron-worker catalog-cron-worker
   ```

2. **Revert to inline jobs:**
   - [ ] Checkout previous commit
   - [ ] Rebuild main services
   - [ ] Deploy main services with inline jobs

3. **Verify system:**
   - [ ] Check API health
   - [ ] Verify jobs running
   - [ ] Monitor for 30 minutes

4. **Post-mortem:**
   - [ ] Document what went wrong
   - [ ] Identify root cause
   - [ ] Plan fixes
   - [ ] Schedule retry

---

## 📊 Daily Progress Template

### Day [X] - [Date]

**Completed:**
- [ ] Task 1
- [ ] Task 2

**In Progress:**
- [ ] Task 3

**Blockers:**
- None / [Describe]

**Notes:**
```
[Add notes here]
```

**Tomorrow:**
- [ ] Task 4
- [ ] Task 5

---

## 🔗 Quick Commands Reference

### Build
```bash
# Build all services
docker compose build

# Build specific worker
docker compose build pricing-event-worker
```

### Run
```bash
# Start all services
docker compose up

# Start specific worker
docker compose up pricing-event-worker

# Run in background
docker compose up -d
```

### Debug
```bash
# Check logs
docker logs -f pricing-event-worker

# Check worker status
docker ps | grep worker

# Check worker health
curl http://localhost:8002/worker/health

# Check metrics
curl http://localhost:8002/metrics
```

### Test
```bash
# Run unit tests
go test ./internal/worker/...

# Run integration tests
go test -tags=integration ./...

# Publish test event
curl -X POST http://localhost:3500/v1.0/publish/pubsub/warehouse.stock.updated \
  -H "Content-Type: application/json" \
  -d '{"productId":"test-123","sku":"SKU-001","newStock":100}'
```

---

## 📞 Support

### Team Contacts
- Backend Lead: [Name]
- DevOps: [Name]
- On-call: [Phone]

### Resources
- [Workers Architecture Guide](./JOBS_AND_WORKERS_ARCHITECTURE.md)
- [Workers Quick Guide](./WORKERS_QUICK_GUIDE.md)
- [Master Checklist](./MASTER_IMPLEMENTATION_CHECKLIST.md)

---

**Created:** November 9, 2024  
**Last Updated:** December 2024  
**Status:** In Progress - Day 3 Completed ✅  
**Priority:** 🔴 CRITICAL

---

## 📝 Implementation Notes

### Day 3 - Catalog Cron Worker (Completed December 2024)

**Implementation Summary:**
- ✅ Created worker base interface (`internal/worker/base/worker.go`)
- ✅ Created stock sync cron worker (`internal/worker/cron/stock_sync.go`)
- ✅ Created worker main entry point (`cmd/worker/main.go`)
- ✅ Configured Wire dependency injection (`cmd/worker/wire.go`)
- ✅ Updated main service to remove inline jobs (`cmd/catalog/main.go`)
- ✅ Updated docker-compose.yml with catalog-cron-worker service
- ✅ Used robfig/cron/v3 for cron scheduling (supports seconds)
- ✅ Cron schedule: `0 * * * * *` (every minute at 0 seconds)

**Files Created:**
- `catalog/cmd/worker/main.go`
- `catalog/cmd/worker/wire.go`
- `catalog/cmd/worker/wire_gen.go` (generated)
- `catalog/internal/worker/base/worker.go`
- `catalog/internal/worker/cron/stock_sync.go`
- `catalog/internal/worker/cron/provider.go`

**Files Updated:**
- `catalog/cmd/catalog/main.go` (removed inline stock sync job)
- `catalog/docker-compose.yml` (added catalog-cron-worker service)

**Next Steps:**
- Build and test worker in Docker environment
- Run integration tests
- Monitor worker performance and resource usage
- Proceed to Day 4 (Integration Testing) when ready
