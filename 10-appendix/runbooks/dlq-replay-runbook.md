# DLQ Replay Runbook — Search & Catalog Event Pipeline

**Scope**: `catalog/`, `search/` Dapr pub/sub dead letter queues  
**Last updated**: 2026-02-23

---

## Background

Every Dapr consumer registers a `deadLetterTopic` so that events exhausting all retries are parked in a DLQ Redis stream instead of being dropped silently. The DLQ handler in each service logs an `[DLQ]` ERROR line (triggering alerts) and ACKs the message to prevent accumulation.

When an alert fires on a DLQ topic you must:
1. Identify **why** events are failing (fix root cause first)
2. Replay the DLQ messages so downstream state catches up

---

## DLQ Topic Map

| Service | Main Topic | DLQ Topic | Handler |
|---------|-----------|-----------|---------|
| Search | `catalog.product.created` | `catalog.product.created.dlq` | `HandleProductCreatedDLQ` |
| Search | `catalog.product.updated` | `catalog.product.updated.dlq` | `HandleProductUpdatedDLQ` |
| Search | `catalog.product.deleted` | `catalog.product.deleted.dlq` | `HandleProductDeletedDLQ` |
| Search | `warehouse.inventory.stock_changed` | `warehouse.inventory.stock_changed.dlq` | `HandleStockChangedDLQ` |
| Search | `pricing.price.updated` | `pricing.price.updated.dlq` | *(log-drain only)* |
| Search | `promotions.promotion.created` | `dlq.promotions.promotion.created` | *(log-drain only)* |
| Search | `promotions.promotion.updated` | `dlq.promotions.promotion.updated` | *(log-drain only)* |
| Search | `promotions.promotion.deleted` | `dlq.promotions.promotion.deleted` | *(log-drain only)* |
| Search | `catalog.category.deleted` | `catalog.category.deleted.dlq` | *(log-drain only)* |
| Catalog | `warehouse.inventory.stock_changed` | `warehouse.inventory.stock_changed.dlq` | `HandleStockChangedDLQ` |
| Catalog | `pricing.price.updated` | `pricing.price.updated.dlq` | *(log-drain only)* |

---

## Step 1 — Confirm Root Cause is Fixed

Do NOT replay until the underlying issue is resolved. Check:

```bash
# Check service logs for the error pattern
kubectl logs -n search-dev deployment/search-worker --since=1h | grep -E "DLQ|ERROR"
kubectl logs -n catalog-dev deployment/catalog-worker --since=1h | grep -E "DLQ|ERROR"

# Common root causes:
# - Elasticsearch down / index red → wait for ES recovery
# - PostgreSQL connection pool exhausted → check DB metrics
# - Malformed event payload → inspect DLQ message body (see Step 2)
```

---

## Step 2 — Inspect DLQ Messages

Dapr uses Redis Streams for pub/sub. DLQ topics are separate streams.

```bash
# Port-forward Redis
kubectl port-forward -n infrastructure svc/redis 6379:6379

# In another terminal — list DLQ stream entries (replace topic name)
redis-cli XRANGE 'warehouse.inventory.stock_changed.dlq' - + COUNT 10

# Inspect a single entry
redis-cli XRANGE 'catalog.product.created.dlq' - + COUNT 1
```

---

## Step 3 — Replay via Dapr Publish API

Replay is done by re-publishing each DLQ message to its **original main topic** via the Dapr sidecar HTTP API. The consumer's idempotency check (`EventIdempotencyRepo.IsProcessed`) will skip any already-processed events.

```bash
# Port-forward Dapr sidecar of the target service
kubectl port-forward -n search-dev pod/<search-worker-pod> 3500:3500

# Publish a single event to the main topic (replaces re-queuing)
# Replace <payload> with the JSON body from Step 2
curl -s -X POST http://localhost:3500/v1.0/publish/pubsub-redis/catalog.product.created \
  -H 'Content-Type: application/json' \
  -d '<payload>'
```

### Bulk replay script

For larger backlogs, use the helper script below. Run **after** fixing root cause.

```bash
#!/bin/bash
# Usage: ./replay_dlq.sh <dlq-topic> <main-topic> <redis-host> <dapr-port>
# Example: ./replay_dlq.sh 'catalog.product.created.dlq' 'catalog.product.created' localhost 3500

DLQ_TOPIC="$1"
MAIN_TOPIC="$2"
REDIS_HOST="${3:-localhost}"
DAPR_PORT="${4:-3500}"

echo "Replaying DLQ: $DLQ_TOPIC → $MAIN_TOPIC"

# Read all DLQ entries
ENTRIES=$(redis-cli -h "$REDIS_HOST" XRANGE "$DLQ_TOPIC" - +)

echo "$ENTRIES" | while read -r LINE; do
  # Extract JSON payload (field key is 'data' in Dapr Redis streams)
  PAYLOAD=$(echo "$LINE" | grep -o '"data":[^,}]*' | head -1 | sed 's/"data"://')
  if [ -n "$PAYLOAD" ]; then
    curl -s -X POST "http://localhost:$DAPR_PORT/v1.0/publish/pubsub-redis/$MAIN_TOPIC" \
      -H 'Content-Type: application/json' \
      -d "$PAYLOAD"
    echo "Replayed: $PAYLOAD"
    sleep 0.05  # 50ms throttle to avoid overwhelming consumer
  fi
done

echo "Replay complete."
```

---

## Step 4 — Acknowledge / Drain Remaining DLQ Entries

After successful replay, trim the DLQ stream to confirm it has been processed:

```bash
# Check current DLQ length
redis-cli XLEN 'catalog.product.created.dlq'

# After confirming all replayed successfully, trim the stream
redis-cli XTRIM 'catalog.product.created.dlq' MAXLEN 0
```

> ⚠️ Only trim after confirming downstream state (Elasticsearch, Redis cache) is up-to-date. Trimming is irreversible.

---

## Step 5 — Verify Recovery

```bash
# Check ES index for the replayed products — expect non-zero count
curl -s http://elasticsearch.infrastructure.svc.cluster.local:9200/products/_count | jq .count

# Check search worker processed count metric
kubectl port-forward -n search-dev svc/search 8017:8017
curl -s http://localhost:8017/metrics | grep catalog_outbox_events_processed_total
```

---

## Outbox FAILED Event Replay (Catalog)

The outbox pattern uses PostgreSQL, not Dapr DLQ. FAILED outbox events can be re-queued manually:

```sql
-- Connect to catalog DB
-- Reset FAILED events to PENDING for re-processing (max 5 retries)
UPDATE outbox_events
SET status = 'PENDING', retry_count = 0, error = NULL, updated_at = NOW()
WHERE status = 'FAILED'
  AND created_at > NOW() - INTERVAL '24 hours';

-- Verify
SELECT status, COUNT(*) FROM outbox_events GROUP BY status;
```

> The outbox worker polls every 100ms and will pick up `PENDING` events automatically.

---

## Monitoring Reference

| Metric | Alert Threshold | Meaning |
|--------|----------------|---------|
| `catalog_outbox_events_failed_total` | > 0 in 5min | Outbox event could not be published after 5 retries |
| `catalog_outbox_backlog` | > 1000 | Outbox processing stalled |
| Kibana: `[DLQ]` log entries | Any occurrence | Dapr retry exhaustion on consumer |
