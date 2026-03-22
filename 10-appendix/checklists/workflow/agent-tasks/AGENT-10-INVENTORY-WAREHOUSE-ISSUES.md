# AGENT-10: Inventory & Warehouse Flow Issues

**Created**: 2026-03-22
**Source**: QA Testing Session — Inventory & Warehouse Flows (Section 8)
**Priority**: Sorted by severity

---

### [x] Task 1: Warehouse Type Column Shows "---" Instead of Actual Type (P2) ✅ IMPLEMENTED — Added data normalizer in WarehousesPage.tsx to handle camelCase→snake_case mapping for `warehouseType`→`warehouse_type` and all other proto fields. Also improved Type column renderer with color-coded labels.

**Service**: `admin`
**File**: `admin/src/pages/WarehousesPage.tsx`
**Risk**: Admin cannot see warehouse type (Standard, Fulfillment, Returns, etc.) in list view
**Problem**: The "Type" column in the Warehouses table shows "---" for all 3 warehouses (WH-FUL-01, WH-RET-01, WH-MAIN). The `warehouse_type` field is either not returned from the API or its value doesn't match what the column renderer expects.
**Verify**: Warehouses list → Type column should show actual type (Standard, Fulfillment, Returns, Cross Dock).

---

### [ ] Task 2: All Inventory Only in Main Warehouse (WH-MAIN) (P3)

**Service**: `warehouse`
**Risk**: No stock in fulfillment or returns warehouses
**Problem**: All inventory items are only in "Main Warehouse (WH-MAIN)". WH-FUL-01 (Fulfillment Center) and WH-RET-01 (Returns Processing) have no inventory. For a multi-warehouse setup, stock should be distributed or at least available in the fulfillment center.
**Verify**: Data/seed issue — check if warehouse_id is correctly assigned during stock import.

---

### [ ] Task 3: Stock Transfers Empty — No Transfer History (P3)

**Service**: `warehouse`
**Risk**: Warehouse-to-warehouse transfer workflow not exercised
**Problem**: Stock Transfers page shows "No data". With 3 warehouses and all stock in WH-MAIN, no transfers have been executed. This could indicate the transfer API is untested in production-like conditions.
**Verify**: Try creating a transfer from WH-MAIN → WH-FUL-01 → verify both outbound/inbound movements created.

---

### [ ] Task 4: Stock Movements Only Show "Adjustment" Type (P3)

**Service**: `warehouse`
**Risk**: Only count_adjustment movements recorded, no reservation/release/outbound from order flow
**Problem**: All 3 stock movements are type "Adjustment" with reason "count_adjustment", dated 2026-03-22. There are no "reservation", "release", or "outbound" movements from actual order flows. This suggests the order → stock reservation pipeline isn't generating movement records.
**Verify**: Place a test order → check Stock Movements for "reservation" type entry.
