# Code Refactoring Plan — Domain Split & File Size

> Created: 2026-02-23
> Scope: All microservices
> Trigger: Code review identified 10 production files > 1000 lines and 2 services with no `biz/` layer

---

## Background

Code review across all services (2026-02-23) found:
- **10 Go files > 1000 lines** (excluding generated, test, mock files)
- **2 services with no real `biz/` domain layer** (`search`, `analytics`)
- **3 service-layer files containing business logic** violating Clean Architecture

Standard target: **no production file > 600 lines**, `service/` layer is mapping-only.

---

## P0 — Critical (This Sprint)

### P0-1 · `promotion` — Biz logic leaking into service layer

| File | Lines | Action |
|------|-------|--------|
| `promotion/internal/service/promotion.go` | **1264** | Move orchestration → biz; keep service as thin mapper |
| `promotion/internal/biz/promotion.go` | **1176** | Split into sub-packages |

**Proposed biz structure after refactor:**
```
promotion/internal/biz/
  coupon/
    coupon.go           # CRUD, lookup
    validation.go       # rule validation  ← extract from biz/validation.go
  campaign/
    campaign.go         # campaign lifecycle
  discount/
    discount_calculator.go  ← already exists, move here
  usage/
    usage_tracking.go       ← already exists, move here
  free_shipping/
    free_shipping.go        ← already exists
```

**Acceptance:** `promotion.go` (biz) < 300 lines; `service/promotion.go` < 400 lines, no biz logic.

---

### P0-2 · `pricing` — Fat handler file

| File | Lines | Action |
|------|-------|--------|
| `pricing/internal/service/pricing_handlers.go` | **1219** | Move orchestration → biz; split handlers by domain |
| `pricing/internal/biz/price/price.go` | **1217** | Split by concern |

**Proposed split for `biz/price/`:**
```
price_crud.go       # Create/Read/Update/Delete ops
price_bulk.go       # Bulk price import / override
price_snapshot.go   # Snapshot & history
price_events.go     # Event publishing
price_cache.go      # Cache invalidation helpers
```

**Proposed split for `service/`:**
```
pricing_read_handlers.go    # GetPrice, ListPrices, ...
pricing_write_handlers.go   # CreatePrice, UpdatePrice, ...
pricing_rule_handlers.go    # Rules endpoints → move from pricing_rules.go
```

**Acceptance:** No single handler file > 400 lines; `price.go` removed/replaced.

---

## P1 — High Priority (Next Sprint)

### [x] P1-1 · `fulfillment` — God object biz file

| File | Lines | Action |
|------|-------|--------|
| `fulfillment/internal/biz/fulfillment/fulfillment.go` | **1598** | Split into sub-domains |

**Proposed biz structure:**
```
fulfillment/internal/biz/
  picklist/
    picklist.go       # pick-list creation & management
  packing/
    packing.go        # package grouping, weight calc
  dispatch/
    dispatch.go       # handover to shipping, label gen
  sla/
    sla.go            # SLA tracking, breach detection
```

**Note:** `fulfillment/internal/service/fulfillment_service.go` (705 lines) and `picklist_service.go` (603 lines) should also be split in tandem.

**Acceptance:** No single file in fulfillment/biz > 400 lines.

---

### P1-2 · `user` — Mixing RBAC + account management + audit

| File | Lines | Action |
|------|-------|--------|
| `user/internal/biz/user/user.go` | **1214** | Split by responsibility |
| `user/internal/service/user.go` | **887** | Trim after biz refactor |

**Proposed biz structure:**
```
user/internal/biz/
  account/
    account.go        # profile, status, metadata
    password.go       ← extract from user.go
  rbac/
    rbac.go           # role assignment, permission check
    permission.go     # permission set management
  audit/
    audit_log.go      # user action audit trail
```

**Acceptance:** `user.go` removed; `service/user.go` < 400 lines.

---

### P1-3 · `order` — Fat service layer

| File | Lines | Action |
|------|-------|--------|
| `order/internal/service/order.go` | **1187** | Split into focused service files |
| `order/internal/biz/order_edit/order_edit.go` | **973** | Split by edit type |

**Proposed service split:**
```
service/
  order_query.go      # GetOrder, ListOrders, ...
  order_command.go    # CreateOrder, CancelOrder, ...
  order_lifecycle.go  # Status transitions
  # event_handler.go already exists
```

**Proposed biz split for `order_edit/`:**
```
order_edit/
  edit_items.go
  edit_address.go
  edit_payment.go
  recalculation.go
```

---

## P2 — Backlog

### P2-1 · `search` — No `biz/` layer (all domain logic in `service/`)

| Files | Lines | Concern |
|-------|-------|---------|
| `service/product_consumer.go` | 917 | Index-building logic |
| `service/cms_consumer.go` | 619 | CMS indexing |
| `service/price_consumer.go` | 464 | Price indexing |

**Proposed:**
```
search/internal/
  biz/
    indexing/
      product_indexer.go    # Document mapping + enrichment
      cms_indexer.go
      price_indexer.go
    query/
      search_query.go       # Query building
    suggest/
      autocomplete.go
  service/                  # thin Dapr consumer wiring only
```

---

### P2-2 · `analytics` — Hollow `biz/` layer

`biz/` currently contains only model structs and stub use-cases. All logic lives in `service/` (5 files × 600–780 lines).

**Action:** Migrate aggregation/event processing logic into `biz/` use-cases; thin down service layer to protocol translation only.

---

### P2-3 · `customer` — `customer.go` + `auth.go` still large

| File | Lines | Action |
|------|-------|--------|
| `customer/internal/biz/customer/customer.go` | 1356 | Extract `profile.go`, `gdpr.go` |
| `customer/internal/biz/customer/auth.go` | 1025 | Extract `verification.go`, `password.go` |

*(Customer already has good sub-package structure; these are the remaining large files.)*

---

### P2-4 · `catalog` — EAV data layer

| File | Lines | Action |
|------|-------|--------|
| `catalog/internal/data/postgres/product_attribute.go` | 1031 | Split into `_crud.go`, `_search.go`, `_eav.go` |

---

## Services — No Action Needed

| Service | Reason |
|---------|--------|
| `auth` | Clean sub-packages, all files < 700 lines |
| `checkout` | Excellent domain split, focused files |
| `payment` | Well-decomposed `gateway/`, `fraud/`, `webhook/` |
| `warehouse` | Good sub-domain structure |
| `return` | Clean and well-sized |
| `notification` | Well separated |
| `loyalty-rewards` | Acceptable structure |
| `review` | Clean |

---

## How to Execute Each Refactor

1. **Create new sub-package directory** and move functions
2. **Update imports** across the service (`grep -r "old/package" .`)
3. **Ensure `wire.go` / provider files** are updated in new packages
4. **Run build**: `go build ./...`
5. **Run tests**: `go test ./...`
6. **No logic changes** — pure structural refactors only

> ⚠️ Do NOT change function signatures or behavior during the split. This is structural only.
