# Review Service Flow - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review service flow review, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- [Critical] [NEW ISSUE 🆕] REV-P0-01 Order verification uses stub client. Required: implement real Order gRPC verification and fail-closed. See `review/internal/client/order_client.go` and `review/internal/biz/review/review.go`.
- [Critical] [NEW ISSUE 🆕] REV-P0-02 Missing ownership checks for `UpdateReview` and `AddSellerResponse`. Required: enforce auth/ownership in service + biz. See `review/internal/service/review_service.go` and `review/internal/biz/review/review.go`.
- [Critical] [NEW ISSUE 🆕] REV-P0-03 Moderation/helpful/report endpoints trust request IDs. Required: admin guard for moderation; use `user_id` from context for helpful/report. See `review/internal/service/moderation_service.go` and `review/internal/service/helpful_service.go`.
- [High] REV-P1-01 `CreateReport` + `UpdateReportCount` not transactional. Required: wrap in DB transaction. See `review/internal/biz/moderation/moderation.go`.
- [High] REV-P1-02 Helpful votes update count without transaction. Required: transaction for vote write + count update. See `review/internal/biz/helpful/helpful.go`.
- [High] REV-P1-03 Pagination defaults allow negative offsets/unbounded queries. Required: normalize page/pageSize defaults. See `review/internal/service/review_service.go` and `review/internal/data/postgres/review.go`.
- [High] REV-P1-04 Review events published without outbox. Required: transactional outbox for review/rating events. See `review/internal/biz/review/review.go` and `review/internal/biz/events/publisher.go`.
- [Medium] REV-P2-01 Cache layer unused in read paths. Required: cache-aside for GetReview/GetRating + invalidation. See `review/internal/cache/cache.go` and service read paths.
- [Medium] REV-P2-02 Rating aggregation fixed page size (10k). Required: SQL aggregation or paginated aggregation. See `review/internal/biz/rating/rating.go`.
- [Medium] REV-P2-03 Moderation/analytics workers are TODO stubs. Required: implement worker logic + scheduling. See `review/internal/service/moderation_service.go`, `review/internal/service/rating_service.go`, `review/internal/worker/analytics_worker.go`.

## 🆕 NEWLY DISCOVERED ISSUES
- [Security] [NEW ISSUE 🆕] REV-P0-01 Order verification stub enables fake “verified” reviews.
- [Security] [NEW ISSUE 🆕] REV-P0-02 Missing ownership checks for review update/response.
- [Security] [NEW ISSUE 🆕] REV-P0-03 Moderation/helpful/report endpoints lack auth guard.

## ✅ RESOLVED / FIXED
- None


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
