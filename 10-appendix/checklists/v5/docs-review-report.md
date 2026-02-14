# 📄 Documentation Review Report
> **Date**: 2026-02-14
> **Scope**: `docs/03-services` codebase & skills

---

## 🚨 Critical Findings

### 1. Duplicate & Stale Documentation
There is a significant "Split Brain" issue in `docs/03-services`. The same services are documented in multiple locations with different versions.

| Service | `core-services` Version | `operational-services` Version | Status |
|---------|-------------------------|--------------------------------|--------|
| **Payment** | v1.0.7 (Newer, Complete) | v1.0.0 (Stale) | ❌ **DUPLICATE** |
| **Promotion** | v1.1.2 (Newer, Detailed) | v1.0.0 (Stale) | ❌ **DUPLICATE** |
| **Warehouse** | Present | Present | ❌ **DUPLICATE** |
| **Fulfillment** | Present | Present | ❌ **DUPLICATE** |
| **Loyalty** | Present | Present | ❌ **DUPLICATE** |
| **Return** | Present | Present | ❌ **DUPLICATE** |

**Recommendation**:
-   **Delete** the Stale files in `docs/03-services/operational-services`.
-   **Consolidate** all service docs into `docs/03-services/{category}/`.
-   **Redirect** or remove `docs/03-services/operational-services` if it becomes empty.

### 2. Service Logic Verification (`Customer` Service)
I verified `docs/03-services/core-services/customer-service.md` against the code:
-   **Dependencies**: Correct. Code uses `orderClient` (sync) and `eventbus` (async) for Order data.
-   **Path References**: Correct. `internal/biz/customer/auth.go` exists.
-   **Event Logic**: Correct. `internal/data/eventbus/order_consumer.go` exists to handle `order.completed`.

**Conclusion**: The `core-services` documentation is accurate and high-quality. The issue is purely with the stale duplicates.

### 3. Detailed Content Review (Order, Catalog, Warehouse)

A deep-dive review was conducted for three critical services to verify the accuracy of the documentation against the actual codebase.

### **Order Service** (`docs/03-services/core-services/order-service.md`)
*   **Status:** ✅ **Accurate**
*   **Verification:**
    *   **Data Structures:** The `Order`, `OrderItem`, and `OrderStatusHistory` structs in `internal/biz/order/types.go` match the documented data models.
    *   **Logic:** The order creation and status transition logic is consistent with the documentation.
    *   **Architecture:** The Clean Architecture layers and dependency injection patterns are correctly described.

### **Catalog Service** (`docs/03-services/core-services/catalog-service.md`)
*   **Status:** ✅ **Accurate**
*   **Verification:**
    *   **EAV System:** The product creation logic in `internal/biz/product/product_write.go` correctly implements the documented EAV (Entity-Attribute-Value) attribute validation and processing.
    *   **Event-Driven:** The documentation accurately reflects the use of the Transactional Outbox pattern for publishing `catalog.product.created` events and the asynchronous synchronization with Elasticsearch.
    *   **Concurrency:** The documentation's claims about race condition prevention (e.g., SKU checks inside transactions) are supported by the code (e.g., "P1-4 FIX" comments).

### **Warehouse Service** (`docs/03-services/core-services/warehouse-service.md`)
*   **Status:** ✅ **Accurate**
*   **Verification:**
    *   **Reservation System:** The `ReserveStock` and `ConfirmReservation` functions in `internal/biz/reservation/reservation.go` implement the documented concurrency controls (row-level locks) and transaction logic.
    *   **Inventory Management:** The optimistic locking mechanisms and expiration handling (for reservations) are implemented as described.
    *   **Background Processes:** The documentation details regarding background workers for reservation cleanup map correctly to the code structure.

## 4. Missing Developer Skills / Tools

During the review, we identified several gaps in the "Skills" available to the agent (and developers). These have been added to the `missing-functional-checklist.md`:

*   **Service Scaffolding:** `scaffold-new-service` to standardize new service creation.
*   **Secret Management:** `rotate-secrets` for easier security ops.
*   **Database Ops:** `database-backup` and `database-restore` for disaster recovery.
*   **Observability:** `check-logs` or `query-metrics` to quickly diagnose issues without leaving the terminal.

## 5. Action Plan

### **Completed**
- [x] **Cleanup:** Deleted stale documentation in `docs/03-services/operational-services`.
- [x] **Consolidation:** Consolidated duplicate files (e.g., `Payment`, `Promotion`).
- [x] **Organization:** Moved unique service docs to `core-services` or `platform-services`.
- [x] **Deep Review:** Verified `Order`, `Catalog`, and `Warehouse` documentation accuracy.

### **Next Steps**
- [ ] **Standardize Headers:** Ensure all Service docs have a standard header format (Title, Owner, Last Updated).
- [ ] **Link Documentation:** Update the main `README.md` and `docs/README.md` to point to the new file locations.
- [ ] **Implement Missing Skills:** Begin creating the missing skills identified above, starting with `scaffold-new-service`.
