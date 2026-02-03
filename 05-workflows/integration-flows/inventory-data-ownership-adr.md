# ADR: Inventory Data Ownership & Availability Management

**Status**: Accepted  
**Date**: 2026-01-31  
**Decision Makers**: Platform Team, Warehouse Team, Catalog Team, Search Team  
**Related**: Inventory Management Workflow, Data Synchronization Architecture

## Context

The microservices platform has multiple services that interact with inventory and stock availability data:
- **Warehouse Service**: Manages physical stock, reservations, allocations
- **Catalog Service**: Manages product metadata, caching
- **Search Service**: Indexes product data including availability for search
- **Order Service**: Creates reservations during checkout
- **Fulfillment Service**: Confirms reservations and allocates stock

This creates questions about:
1. **Source of Truth**: Which service owns stock availability data?
2. **Data Synchronization**: How does availability propagate across services?
3. **Caching Strategy**: What should each service cache?
4. **Terminology**: What's the difference between reservation and allocation?

## Decision

### 1. Source of Truth

**Warehouse Service is the ONLY source of truth for:**
- Stock levels (`quantity_available`, `quantity_reserved`)
- Stock reservations (pending orders)
- Stock allocations (fulfillment assignments)
- Warehouse locations and capacity
- Stock movements and transactions

**Catalog Service:**
- Does NOT own stock data
- MAY cache product metadata (name, SKU, category, brand)
- MUST invalidate cache on warehouse events
- MUST query Warehouse Service for real-time stock via gRPC

**Search Service:**
- Indexes availability data for search/filtering
- Data is **eventually consistent** (acceptable delay: <5 seconds)
- Updates via event subscription to `warehouse.inventory.stock_changed`
- NOT authoritative - always defer to Warehouse for real-time queries

**Order Service:**
- Does NOT store stock data
- Calls Warehouse Service gRPC API for stock checks and reservations
- Receives synchronous confirmation of stock availability

### 2. Terminology Standardization

| Term | Definition | Lifecycle | Owner Service |
|------|------------|-----------|---------------|
| **Stock Level** | Physical quantity in warehouse | Updated by: receiving, transfers, adjustments, returns | Warehouse |
| **Available Stock** | `quantity_available - quantity_reserved` | Computed field | Warehouse |
| **Reservation** | Stock held for pending order (before payment/fulfillment) | Created → Active → Confirmed/Cancelled/Expired | Warehouse |
| **Allocation** | Stock assigned to fulfillment (bin location, picker, batch) | Created during fulfillment start → Completed | Warehouse (future) |
| **Stock Status** | `in_stock`, `out_of_stock`, `low_stock` | Computed based on `available_stock` | Warehouse |

**Key Distinction**:
- **Reservation** = Temporary hold for pending order (customer checkout → payment)
- **Allocation** = Warehouse operations assignment (fulfillment start → shipment)

**Current Implementation Note**: Allocations are NOT separately modeled. Reservations serve dual purpose through fulfillment. The `reference_type` field in `stock_reservations` table distinguishes usage:
- `reference_type = 'order'`: Pre-payment reservation
- `reference_type = 'fulfillment'`: During fulfillment (acts as allocation)

### 3. Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     WAREHOUSE SERVICE                            │
│                   (Source of Truth)                              │
│                                                                   │
│  ┌──────────────┐      ┌─────────────────┐                     │
│  │  Inventory   │◄────►│  Reservations   │                     │
│  │   (Stock)    │      │  (TTL, Status)  │                     │
│  └──────────────┘      └─────────────────┘                     │
│         │                       │                                │
│         │ Stock Changes         │ Reservation Events             │
│         ▼                       ▼                                │
│  ┌────────────────────────────────────┐                         │
│  │     Transactional Outbox           │                         │
│  │   (Reliable Event Publishing)      │                         │
│  └────────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
                        │
                        │ Dapr PubSub (Redis)
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   CATALOG    │ │    SEARCH    │ │   ANALYTICS  │
│   SERVICE    │ │   SERVICE    │ │   SERVICE    │
├──────────────┤ ├──────────────┤ ├──────────────┤
│ • Invalidate │ │ • Update ES  │ │ • Track      │
│   product    │ │   index with │ │   stock      │
│   cache      │ │   stock data │ │   movements  │
│ • No stock   │ │ • Eventually │ │              │
│   storage    │ │   consistent │ │              │
└──────────────┘ └──────────────┘ └──────────────┘
```

### 4. Event-Driven Synchronization

**Published Events** (from Warehouse Service):

| Event | Topic | Trigger | Consumers |
|-------|-------|---------|-----------|
| Stock Changed | `warehouse.inventory.stock_changed` | Adjust/Transfer/Restock | Catalog, Search, Analytics |
| Reservation Expired | `warehouse.inventory.reservation_expired` | TTL worker | Order (for cleanup) |
| Low Stock Alert | `warehouse.inventory.low_stock` | Below reorder point | Notification |

**Event Payload** (`warehouse.inventory.stock_changed`):
```json
{
  "event_type": "warehouse.inventory.stock_changed",
  "warehouse_id": "wh-123",
  "product_id": "prod-456",
  "sku": "WIDGET-001",
  "old_stock": 100,
  "new_stock": 95,
  "quantity_available": 95,
  "quantity_reserved": 10,
  "available_stock": 85,
  "stock_status": "in_stock",
  "movement_type": "adjusted",
  "sequence_number": 42,
  "timestamp": "2026-01-31T10:30:00Z"
}
```

**Consumer Responsibilities**:
- **Catalog**: Invalidate `catalog:product:{product_id}` cache key
- **Search**: Update Elasticsearch document fields: `stock_status`, `available_quantity`, `warehouse_availability[]`
- **Analytics**: Record stock movement metrics

### 5. Caching Strategy

**Catalog Service**:
- **DOES cache**: Product metadata (name, description, category, brand, images)
- **DOES NOT cache**: Stock levels, availability, prices
- **Cache TTL**: 1 hour (metadata changes infrequently)
- **Invalidation**: On `warehouse.inventory.stock_changed` event (precautionary, even though stock not cached)

**Search Service**:
- **Indexes**: Product data + stock availability (for filtering)
- **Update Strategy**: Event-driven real-time updates
- **Consistency**: Eventually consistent (acceptable lag: <5 seconds)
- **DLQ**: Failed events → `dlq.warehouse.inventory.stock_changed` for retry

**Order Service**:
- **NO caching**: Always query Warehouse Service for real-time stock
- **Reason**: Stock changes rapidly during checkout (race conditions)

### 6. Real-Time Stock Queries

For operations requiring **authoritative, real-time stock data**:
- Order checkout stock validation
- Reservation creation
- Admin stock management UI

**MUST** use gRPC calls to Warehouse Service:
```protobuf
rpc GetStock(GetStockRequest) returns (GetStockResponse);
rpc ReserveStock(ReserveStockRequest) returns (ReserveStockResponse);
rpc GetBulkStock(GetBulkStockRequest) returns (GetBulkStockResponse);
```

**Never** rely on:
- Cached data in Catalog
- Indexed data in Search (for transactional operations)

## Consequences

### Positive

1. **Clear Ownership**: No ambiguity about source of truth
2. **Data Consistency**: Single writer pattern prevents conflicts
3. **Scalability**: Event-driven sync decouples services
4. **Performance**: Search can filter on stock without querying Warehouse
5. **Reliability**: Transactional outbox ensures event delivery

### Negative

1. **Complexity**: Event-driven architecture requires monitoring
2. **Eventual Consistency**: Search results may show outdated stock (max 5s lag)
3. **Dependency**: All services depend on Warehouse availability
4. **Network Calls**: Real-time queries require gRPC calls (latency)

### Mitigation Strategies

1. **Circuit Breaker**: Wrap Warehouse gRPC calls to prevent cascading failures
2. **Graceful Degradation**: Search can show "Call for availability" if sync fails
3. **Monitoring**: Track event lag, publish failures, sync delays
4. **Retry Logic**: DLQ for failed events, automatic retry with backoff

## Compliance

Services MUST adhere to these rules:

✅ **DO**:
- Query Warehouse Service for real-time stock operations
- Subscribe to `warehouse.inventory.stock_changed` for cache invalidation
- Use sequence numbers for event ordering
- Implement idempotency in event consumers
- Monitor sync lag and alert on delays

❌ **DO NOT**:
- Store stock levels in other services (except Search index)
- Cache stock availability for transactional operations
- Bypass Warehouse Service for stock modifications
- Assume Search data is authoritative for stock
- Create direct database connections to Warehouse DB

## References

- [Warehouse Service Architecture](../warehouse/README.md)
- [Event-Driven Data Sync](../data-synchronization-checklist.md)
- [Reservation Lifecycle State Machine](#reservation-lifecycle) (below)
- [Catalog Service Caching Strategy](../../catalog/docs/caching-strategy.md)

---

## Appendix: Reservation Lifecycle State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│                  RESERVATION LIFECYCLE                           │
└─────────────────────────────────────────────────────────────────┘

                    ┌──────────────┐
                    │   CREATED    │
                    └──────┬───────┘
                           │
                           │ ReserveStock()
                           │ • Increment quantity_reserved
                           │ • Set TTL based on payment method
                           │
                           ▼
                    ┌──────────────┐
            ┌──────►│    ACTIVE    │◄──────┐
            │       └──────┬───────┘       │
            │              │               │
            │              │               │ ExtendReservation()
            │              │               │ (payment delay)
            │              │               │
            │         ┌────┴────┐          │
            │         │         │          │
            │         │         │          │
            ▼         ▼         ▼          │
    ┌───────────┐ ┌──────────┐ ┌──────────────┐
    │ CANCELLED │ │ EXPIRED  │ │  CONFIRMED   │
    │           │ │          │ │              │
    │ • Manual  │ │ • TTL    │ │ • Payment OK │
    │   cancel  │ │   reached│ │ • Ready for  │
    │ • Payment │ │ • Worker │ │   fulfillment│
    │   failed  │ │   cleanup│ │              │
    └───────────┘ └──────────┘ └──────┬───────┘
         │             │               │
         │             │               │ CompleteReservation()
         │             │               │ (fulfillment done)
         │             │               │
         ▼             ▼               ▼
    ┌─────────────────────────────────────┐
    │         TERMINAL STATES             │
    │                                     │
    │  • quantity_reserved decremented   │
    │  • No further state changes        │
    │  • Audit log preserved             │
    └─────────────────────────────────────┘
              │
              │ If CONFIRMED
              │
              ▼
    ┌──────────────┐
    │  FULFILLED   │
    │              │
    │ • Shipment   │
    │   completed  │
    └──────────────┘
```

### State Definitions

| State | Description | `quantity_reserved` | Next States |
|-------|-------------|---------------------|-------------|
| **ACTIVE** | Reservation created, TTL running | +N (incremented) | CONFIRMED, CANCELLED, EXPIRED |
| **CONFIRMED** | Payment successful, ready for fulfillment | N (unchanged) | FULFILLED |
| **CANCELLED** | Manual cancellation or payment failed | -N (decremented) | None (terminal) |
| **EXPIRED** | TTL reached, auto-released by worker | -N (decremented) | None (terminal) |
| **FULFILLED** | Order shipped, reservation completed | -N (decremented) | None (terminal) |

### Transitions

| Trigger | From State | To State | Action |
|---------|-----------|----------|--------|
| `ReserveStock()` | - | ACTIVE | Increment `quantity_reserved`, set `expires_at` |
| `ConfirmReservation()` | ACTIVE | CONFIRMED | Update status, keep reserved qty |
| `ReleaseReservation()` | ACTIVE | CANCELLED | Decrement `quantity_reserved` |
| `CompleteReservation()` | CONFIRMED | FULFILLED | Decrement `quantity_reserved`, set `quantity_fulfilled` |
| TTL Worker | ACTIVE (expired) | EXPIRED | Decrement `quantity_reserved`, publish event |
| `ExtendReservation()` | ACTIVE | ACTIVE | Update `expires_at` |

### TTL Configuration (Payment Method Based)

| Payment Method | Default TTL | Rationale |
|----------------|-------------|-----------|
| COD (Cash on Delivery) | 24 hours | Long window for courier delivery |
| Bank Transfer | 4 hours | Bank confirmation time |
| Credit Card | 30 minutes | Quick payment processing |
| E-Wallet | 15 minutes | Instant payment expected |
| Installment | 2 hours | Approval process time |
| Default | 30 minutes | Conservative fallback |

Configuration in `warehouse/configs/config.yaml`:
```yaml
reservation:
  expiry:
    cod: 24h
    bank_transfer: 4h
    credit_card: 30m
    e_wallet: 15m
    installment: 2h
    default: 30m
  warning_before_expiry: 5m # Alert user before expiration
```

### Race Condition Prevention (P0 Fixes)

**P0-5: TOCTOU Prevention**:
```go
// WRONG: Check then Act (race condition)
if inventory.QuantityAvailable >= quantity {
    inventory.QuantityReserved += quantity // ❌ Gap between check and update
}

// CORRECT: Atomic increment first
inventory.QuantityReserved += quantity // ✅ Increment first
if inventory.QuantityAvailable < inventory.QuantityReserved {
    return ErrInsufficientStock // Check constraint after
}
```

**P0-6: Transaction Atomicity**:
```go
// Wrap reservation release in transaction
tx := db.Begin()
inventory := tx.FindByWarehouseAndProductForUpdate() // Row lock
inventory.QuantityReserved -= reservation.Quantity
reservation.Status = "cancelled"
tx.Commit() // ✅ Atomic operation
```

---

**Last Updated**: 2026-01-31  
**Review Cycle**: Quarterly or when architectural changes proposed
