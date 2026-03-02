# 📋 Architectural Analysis & Refactoring Report: Database Pagination & N+1 Dependencies

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Data Access Layer (GORM, PostgreSQL), Performance & Query Optimization  

---

## 🎯 Executive Summary
Offset-based pagination (`OFFSET/LIMIT`) and aggressive "greedy fetching" via ORM `Preload()` are two of the most critically severe performance bottlenecks in high-throughput e-commerce domains. At scale (Shopify/Lazada patterns), `OFFSET/LIMIT` degrades exponentially `O(N)` with deeper pages, and N+1 loading cascades into DB connection pool exhaustion. 
This report outlines the mandatory shift toward Keyset (Cursor-based) Pagination and explicit `JOIN` aggregations.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

### 1. [🚨 P0] Greedy Fetching (N+1 Query Explosions) via Unbounded `Preload()`
* **Context**: Widespread use of `.Preload("Locations")` in warehouse and `.Preload("Items")` / `.Preload("ShippingAddress")` in orders.
* **Risk**: GORM emits a separate `SELECT` statement mapping every ID loaded. A list API returning 100 orders with 3 preloads emits 301 distinct DB queries per request. Under flash-sale loads, this instantly stalls connection pooling.
* **Current state**: 37 `.Preload()` calls across 6 services (warehouse 11, customer 11, fulfillment 10, location 3, shipping 1, catalog 1).
* **Action Required**: 
  - For `has_one` / `belongs_to` relationships (e.g., Addresses, Merchants): Replace `Preload()` with `.Joins("LEFT JOIN ...")` and selective `Select()`.
  - For `has_many` relationships: Utilize aggregated arrays natively in PostgreSQL (`JSON_AGG`) or perform exactly 2 strictly bounded queries using an `IN (id1, id2...)` clause.

### 2. [🟡 P1] Unbounded List Fetching (OOM Risk)
* **Context**: Internal relationships like `GetByReference` and `GetLocations` perform `.Find(&results)` without a definitive `.Limit(X)`.
* **Risk (Shopify standard)**: Internal sync protocols fetching relationships can hit Out Of Memory (OOM) pod crashes if an entity maps to tens of thousands of sub-records.
* **Action Required**: 
  - Enforce a hard cap (e.g., `.Limit(1000)`) on all internal `List*` or `Get*` relational data access scripts even if not explicitly requested by the caller.

## ✅ RESOLVED / FIXED

- **[FIXED ✅] Keyset Paginator Base Implementation**: The shared framework structure for cursor pagination (`common/utils/pagination/cursor.go`) has been validated via `transaction.go`.
- **[FIXED ✅] N+1 Resolution Sandbox**: `transaction.go` successfully transitioned from multiple `.Preload()` statements to raw left joins (`Joins("LEFT JOIN warehouses...")`).
- **[DONE ✅] Cursor Pagination Migration Complete (2026-03-02)**: All 16 services migrated to cursor-based pagination. 10 data files updated with cursor branches, 6 filter structs extended with `Cursor` field, 16 deps updated to `common@v1.23.0`. Warehouse offset `List` methods deprecated with `// Deprecated:` comments. Remaining `.Offset()` calls are intentionally kept (offset-fallback branches, raw-interface secondary methods, admin utilities, cron batch jobs).

---

## 📋 Architectural Guidelines & Playbook

### 1. Keyset (Cursor) Pagination Execution
Do not use `LIMIT X OFFSET Y` for any entity that scales over time (Events, Orders, Audit Logs, Products).
* **Pattern**: Sort the dataset by a deterministic unique key (e.g., `(created_at, id)`). The client passes the absolute value of the last seen record, and the DB uses index leaps: `WHERE (created_at, id) < (cursor_time, cursor_id)`.

### 2. Eliminating `Preload()` for List APIs
When serving list APIs, strict selective fetching must be enforced.
**From Anti-Pattern:**
```go
err := query.Preload("Locations").Find(&results).Error
```
**To Shopify/Lazada Pattern:**
```go
db.Table("warehouses w").
   Select("w.id, w.name, l.location_code"). // strictly projecting required fields
   Joins("LEFT JOIN warehouse_locations l ON w.id = l.warehouse_id").
   Find(&dtos)
```
*Note from the Senior TA: Any PR utilizing Preload() on a List API handler must be actively rejected during peer review.*
