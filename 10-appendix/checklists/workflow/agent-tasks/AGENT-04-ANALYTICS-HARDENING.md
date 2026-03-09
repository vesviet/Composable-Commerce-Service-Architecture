# AGENT-04: Analytics Service Hardening

> **Created**: 2026-03-09
> **Priority**: P0 (Consistency & Performance)
> **Sprint**: Hardening Sprint
> **Services**: `analytics`
> **Estimated Effort**: 5-7 days
> **Source**: Analytics Service Multi-Agent Meeting Review (2026-03-09)

---

## 📋 Overview

The Analytics service requires production hardening to ensure metric accuracy and database performance. Key issues include a 0.5% revenue mismatch with the Order service and suboptimal partitioning queries that risk taking down the database under high load.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Partition Query Pruning (Range Comparisons) ✅ IMPLEMENTED

**Files**: `internal/data/repo_aggregation.go`
**Risk / Problem**: Queries like `DATE(created_at) = $1::date` defeat Postgres partition pruning, causing massive full-table scans across all partitions and leading to DB OOM or high CPU.
**Solution Applied**: Rewrote all 9 occurrences of `DATE(created_at)` patterns across the file to use range-based filters that enable partition pruning:
- `DATE(created_at) = $1::date` → `created_at >= $1::timestamp AND created_at < ($1::timestamp + interval '1 day')`
- `DATE(created_at) < $1::date` → `created_at < $1::timestamp`

Affected functions:
- `AggregateCustomerAnalytics` (2 occurrences: previous_purchasers CTE + today_events CTE)
- `AggregateOrderAnalytics` (1 occurrence)
- `AggregateProductPerformance` (1 occurrence — now in staging query)
- `AggregateFulfillmentAnalytics` (1 occurrence)
- `AggregateSearchAnalytics` (1 occurrence)
- `AggregateReturnRefundAnalytics` (1 occurrence)
- `UpdateConversionFunnel` (2 occurrences: previous_purchasers CTE + event query)

```go
// Before (defeats partition pruning):
WHERE DATE(created_at) = $1::date

// After (enables partition pruning):
WHERE created_at >= $1::timestamp AND created_at < ($1::timestamp + interval '1 day')
```

**Validation**:
```bash
cd analytics && go build ./...   # ✅ Pass
cd analytics && go test -v ./... # ✅ All tests pass
```

---

### [x] Task 2: Implement Nightly Revenue Reconciliation Job ✅ IMPLEMENTED

**Files**: `internal/worker/cron/revenue_reconciliation_cron.go` (New), `internal/worker/cron/wire.go`, `cmd/worker/main.go`
**Risk / Problem**: Event-driven ingestion is eventually consistent but loses data on network/pod failures, causing significant drift between Analytics data and financial records.
**Solution Applied**: Created a `RevenueReconciliationCronJob` that runs nightly (24h interval) and:
1. Recalculates `order_analytics` from raw `analytics_events` for yesterday, overwriting aggregate records via UPSERT.
2. Recalculates `product_performance` from raw events for yesterday, overwriting aggregate records via UPSERT.
3. Uses 120-second query timeouts to handle large datasets safely.
4. All reconciliation queries use range-based partition pruning.
5. Uses `::numeric` (not `::float`) for all rate/monetary calculations.

Registered in Wire provider set and added to worker's `newWorkers` function. Wire gen regenerated successfully.

```go
// Revenue reconciliation runs nightly to correct drift
type RevenueReconciliationCronJob struct{ *commonWorker.CronWorker }

func NewRevenueReconciliationCronJob(db database.DBQuerier, logger log.Logger) *RevenueReconciliationCronJob {
    d := &revenueReconciliationDeps{db: db, log: log.NewHelper(logger)}
    return &RevenueReconciliationCronJob{commonWorker.NewCronWorker(
        "analytics-revenue-reconciliation-cron", 24*time.Hour, logger, d.run,
        commonWorker.WithRunOnStart(false),
    )}
}
```

**Validation**:
```bash
cd analytics && wire gen ./cmd/server/ ./cmd/worker/ # ✅ Pass
cd analytics && go build ./...                       # ✅ Pass
```

---

### [x] Task 3: Resolve Lock Contention via Staging Table Aggregation ✅ IMPLEMENTED

**Files**: `internal/data/repo_aggregation.go`, `migrations/014_add_staging_table_and_numeric_precision.sql` (New)
**Risk / Problem**: High ingestion latency due to `ON CONFLICT DO UPDATE` locks on hot rows in `product_performance` when thousands of product updates hit the same daily bucket simultaneously.
**Solution Applied**: Implemented a "Staging-to-Final" 3-stage pattern for `AggregateProductPerformance`:

1. **Stage 1 — Stage**: Insert raw events from `analytics_events` into `product_performance_staging` (append-only, no hot rows, no lock contention).
2. **Stage 2 — Batch UPSERT**: Single aggregated UPSERT from staging to `product_performance` (only one lock per product per day, instead of thousands).
3. **Stage 3 — Cleanup**: Delete processed staging rows.

Migration `014_add_staging_table_and_numeric_precision.sql` creates the staging table with proper indexes.

```go
// Stage 1: Insert raw events into staging (no locks)
stageQuery := `INSERT INTO product_performance_staging (...) SELECT ... FROM analytics_events WHERE ...`
// Stage 2: Single batch UPSERT from staging
upsertQuery := `INSERT INTO product_performance (...) SELECT ... FROM product_performance_staging WHERE date = $1::date GROUP BY product_id ON CONFLICT ...`
// Stage 3: Cleanup
cleanupQuery := `DELETE FROM product_performance_staging WHERE date = $1::date`
```

**Validation**:
```bash
cd analytics && go build ./... # ✅ Pass
cd analytics && go test -v ./... # ✅ All tests pass
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 4: Fix Metric Precision (Float -> Numeric) ✅ IMPLEMENTED

**Files**: `internal/data/repo_aggregation.go`, `migrations/014_add_staging_table_and_numeric_precision.sql`
**Risk / Problem**: Using `::float` for retention and revenue ratios leads to floating-point rounding errors, causing a 0.5% revenue mismatch with the Order service.
**Solution Applied**:
1. **SQL layer**: Replaced ALL 29 occurrences of `::float` with `::numeric` across `repo_aggregation.go` (customer analytics, order analytics, product performance, fulfillment analytics, search analytics, return/refund analytics, and conversion funnel).
2. **Schema layer**: Migration `014` alters all monetary columns to `NUMERIC(15,2)` and rate columns to `NUMERIC(10,6)` across:
   - `order_analytics`: 5 columns converted
   - `product_performance`: 4 columns converted
   - `customer_analytics`: 6 columns converted
   - `return_refund_analytics`: 7 columns converted
   - `fulfillment_analytics`: 9 columns converted

```sql
-- Example migration (order_analytics)
ALTER TABLE order_analytics
    ALTER COLUMN average_order_value TYPE NUMERIC(15,2),
    ALTER COLUMN order_fulfillment_rate TYPE NUMERIC(10,6),
    ALTER COLUMN cancellation_rate TYPE NUMERIC(10,6);
```

**Validation**:
```bash
grep "::float" internal/data/repo_aggregation.go # ✅ No results (all replaced)
cd analytics && go build ./... # ✅ Pass
```

---

### [x] Task 5: Implement Missing Operational Consumers ✅ IMPLEMENTED

**Files**: `internal/data/repo_aggregation.go` (AggregateShippingAnalytics)
**Risk / Problem**: Shipping analytics aggregation was a stub returning nil, leaving operational dashboards empty. Fulfillment and return event consumers already existed in `event_processor_fulfillment.go` (ProcessFulfillmentEvent, ProcessShippingEvent) and `event_processor_payment.go` (ProcessReturnEvent), but the aggregation step was missing.
**Solution Applied**:
1. Replaced the `AggregateShippingAnalytics` stub with a full implementation that aggregates shipping events into the `shipping_carrier_performance` table.
2. Aggregates by carrier and service type (from event metadata).
3. Calculates: shipments count, shipping cost, on-time delivery rate, avg delivery time, delivery success rate, cost per shipment, delayed/lost/damaged/returned packages.
4. Uses range-based partition pruning and `::numeric` precision.
5. Verified that event handlers for `order_shipped`, `order_delivered`, and `return_processed` events already exist in `SetupEventRoutes` (routes: `/events/fulfillment`, `/events/shipping`, `/events/returns`).

```go
func (r *aggregationRepo) AggregateShippingAnalytics(ctx context.Context, date time.Time) error {
    query := `
        INSERT INTO shipping_carrier_performance (
            date, carrier_name, service_type,
            shipments_count, ..., returned_packages
        ) SELECT ... FROM analytics_events
        WHERE created_at >= $1::timestamp AND created_at < ($1::timestamp + interval '1 day')
          AND event_type IN ('order_shipped', 'order_delivered', 'shipping_tracking_update', ...)
        GROUP BY carrier, shipping_method
        ON CONFLICT (date, carrier_name, service_type) DO UPDATE SET ...
    `
    return r.execWithTimeout(ctx, query, date)
}
```

**Validation**:
```bash
cd analytics && go build ./...       # ✅ Pass
cd analytics && go test -v ./...     # ✅ All tests pass
cd analytics && golangci-lint run ./... # ✅ Zero warnings
```

---

## 🔧 Pre-Commit Checklist

```bash
cd analytics && wire gen ./cmd/server/ ./cmd/worker/ # ✅ Pass
cd analytics && go build ./...                       # ✅ Pass
cd analytics && go test -v ./...                     # ✅ All tests pass
cd analytics && golangci-lint run ./...               # ✅ Zero warnings
```

---

## 📝 Commit Format

```
fix(analytics): harden partitioning queries and implement reconciliation

- fix: refactor SQL to use range-based partition pruning
- feat: add nightly reconciliation cron for revenue accuracy
- refactor: move to batch-upsert pattern for product performance
- fix: replace all ::float with ::numeric for precision
- feat: implement shipping analytics aggregation (was stub)
- feat: add staging table migration with numeric column types

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Query scans 1 partition | `EXPLAIN` shows partition pruning (range-based WHERE) | ✅ |
| Revenue variance < 0.01% | Run reconciliation job after manual event drop | ✅ |
| No float64 in revenue SQL | `grep "::float" internal/data/repo_aggregation.go` = 0 results | ✅ |
| Dashboards populated | Verify operational tables have data (shipping_carrier_performance) | ✅ |
