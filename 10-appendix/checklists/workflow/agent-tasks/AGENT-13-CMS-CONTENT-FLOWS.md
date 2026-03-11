# AGENT TASK - CMS & CONTENT FLOWS (AGENT-13)

## STATUS
**State:** [ ] Not Started | [ ] In Progress | [ ] In Review | [x] Done

## ASSIGNMENT
**Focus Area:** Caching and Content Event Distribution
**Primary Services:** `catalog`
**Priority:** High (P1 Performance Risk)

## 📌 P1: Homepage DB Meltdown Risk (Lack of Cache)
**Risk:** The `GetActiveBanners` and `GetPageBySlug`/`ListPages` API endpoints in the `catalog` service directly query the PostgreSQL database without any caching. This is highly problematic since Homepage Banners are hit by every incoming user session. During a Flash Sale event (e.g., 11.11), the database will quickly exhaust connections and crash, bringing down the entire store.
**Location:** `catalog/internal/data/postgres/cms_repo.go`, `catalog/internal/service/cms_service.go`

### Implementation Plan
1.  **Implement Redis Caching for Read-Heavy Endpoints:**
    *   Create a `redis` storage package for CMS or inject Redis directly into `cms_repo.go`.
    *   `GetActiveBanners(placement)`: Read from `cms:banners:active:{placement}`. If miss, query Postgres, set JSON to Redis with `TTL` (e.g., 5 mins).
    *   `GetPageBySlug(slug)`: Read from `cms:page:{slug}`. If miss, query Postgres, set with `TTL`.

### 🔍 Verification Steps
*   Run tests: `go test -v ./catalog/internal/data/postgres/...`
*   Ensure the Redis instance intercepts read logic.

---

## 📌 P2: No Outbox Events for CMS Mutations (Stale Content)
**Risk:** CMS creation, updates, and deletion methods in `biz/cms/cms.go` perform database saves directly using `gorm` operations without wrapping them inside a Transactional Outbox. Without emitted events (like `cms.banner.updated`), downstream systems like Frontend (Next.js ISR) and Search clusters cannot be asynchronously notified to invalidate their caches. This leaves the system with stale content relying solely on TTL expiration.
**Location:** `catalog/internal/biz/cms/cms.go`

### Implementation Plan
1.  **Transactional Outbox implementation:**
    *   Inject `TransactionManager` (already present in the codebase) and `OutboxRepo` into `CMSUsecase`.
    *   Wrap `CreatePage`, `UpdatePage`, `DeletePage`, `PublishPage`, and `UnpublishPage` in `uc.tm.InTx(ctx, ...)`.
    *   After a successful DB mutation, emit the corresponding event (e.g., `cms.page.published` or `cms.banner.updated`) along with the JSON payload of the Page/Banner struct into the `outbox_events` table within the same transaction.

### 🔍 Verification Steps
*   Run tests: `go test -v ./catalog/internal/biz/cms/...`
*   Verify Mock behaviors expect Outbox insertion.

---

## 💬 Pre-Commit Instructions (Format for Git)
```bash
git add catalog/internal/biz/cms/
git add catalog/internal/data/postgres/

git commit -m "feat(catalog): implement redis caching and outbox events for cms

# Agent-13 Fixes based on 250-Round Meeting Review
# P1: Added Redis caching for active banners and slug lookups
# P2: Integrated TransactionManager & Outbox to emit cms.* events"
```
