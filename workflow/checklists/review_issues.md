# Review Service Flow - Code Review Issues

**Last Updated**: 2026-01-19

This document lists issues found during the review service flow review, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🔎 Re-review (2026-01-19) - Unfixed & New Issues (Moved to Top)

### Unfixed Issues
- None (first pass on this checklist).

### New Issues
- **REV-P0-01 (New)**: Order verification uses stub client, enabling fake “verified” flow or blocking verified reviews.
    - **Location**: `review/internal/client/order_client.go`, `review/internal/biz/review/review.go`
    - **Impact**: Purchase verification is not reliable; verified reviews can be bypassed or fail incorrectly.
    - **Recommendation**: Implement real gRPC calls to Order service and enforce purchase verification for verified reviews.

- **REV-P0-02 (New)**: Missing ownership checks for `UpdateReview` and `AddSellerResponse`.
    - **Location**: `review/internal/service/review_service.go`, `review/internal/biz/review/review.go`
    - **Impact**: Any caller can update another user’s review or spoof seller responses.
    - **Recommendation**: Enforce auth (customer/seller ID) from context and validate ownership in biz layer.

- **REV-P0-03 (New)**: Moderation and helpful/report endpoints trust request IDs without auth.
    - **Location**: `review/internal/service/moderation_service.go`, `review/internal/service/helpful_service.go`
    - **Impact**: Unauthenticated users can moderate, report, or vote as arbitrary users.
    - **Recommendation**: Require admin guard for moderation endpoints and extract `user_id` from context for helpful/report flows.


## P1 - Data Integrity / Consistency

- **Issue**: `CreateReport` and `UpdateReportCount` are not transactional. [NOT FIXED]
    - **Location**: `review/internal/biz/moderation/moderation.go`
    - **Impact**: Report records can be created without updating `report_count` (or vice versa).
    - **Recommendation**: Wrap both operations in a DB transaction.

- **Issue**: Helpful votes update count without a transaction. [NOT FIXED]
    - **Location**: `review/internal/biz/helpful/helpful.go`
    - **Impact**: `helpful_count` can drift if write/update fails mid-flow.
    - **Recommendation**: Use a transaction for vote write + count update.

## P1 - Correctness / Pagination

- **Issue**: Pagination defaults can result in negative offsets or unbounded queries. [NOT FIXED]
    - **Location**: `review/internal/service/review_service.go`, `review/internal/data/postgres/review.go`
    - **Impact**: Page=0 or PageSize=0 can lead to unexpected results or heavy queries.
    - **Recommendation**: Normalize page/pageSize defaults (e.g., page=1, pageSize=10) before querying.

## P1 - Event Reliability

- **Issue**: Review events are published without an outbox. [NOT FIXED]
    - **Location**: `review/internal/biz/review/review.go`, `review/internal/biz/events/publisher.go`
    - **Impact**: Events can be lost if the service crashes after DB write and before publish.
    - **Recommendation**: Use transactional outbox for review/rating events.

## P2 - Performance

- **Issue**: Cache layer exists but is unused in read paths. [NOT FIXED]
    - **Location**: `review/internal/cache/cache.go`, `review/internal/service/review_service.go`, `review/internal/service/rating_service.go`
    - **Impact**: High read load on DB for review/rating queries.
    - **Recommendation**: Add cache-aside for `GetReview`/`GetRating` and invalidate on update.

- **Issue**: Rating aggregation uses fixed page size of 10,000. [NOT FIXED]
    - **Location**: `review/internal/biz/rating/rating.go`
    - **Impact**: Products with >10k reviews will produce inaccurate aggregates.
    - **Recommendation**: Use aggregation queries in SQL or stream/paginate reviews.

## P2 - Observability / Ops

- **Issue**: Moderation/analytics workers are TODO stubs. [NOT FIXED]
    - **Location**: `review/internal/service/moderation_service.go`, `review/internal/service/rating_service.go`, `review/internal/worker/analytics_worker.go`
    - **Impact**: Auto-moderation and analytics processing are incomplete.
    - **Recommendation**: Implement worker logic and schedule periodic aggregation.
