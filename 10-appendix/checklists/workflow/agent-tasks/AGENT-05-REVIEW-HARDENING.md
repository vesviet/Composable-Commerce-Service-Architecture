# AGENT-05: Review Service Hardening

> **Created**: 2026-03-09
> **Priority**: P0 (Data Integrity & Trust)
> **Sprint**: Hardening Sprint
> **Services**: `review`
> **Estimated Effort**: 4-6 days
> **Source**: Review Service Multi-Agent Meeting Review (2026-03-09)

---

## 📋 Overview

The Review service requires hardening to prevent duplicate reviews and ensure the "Verified Purchase" status remains accurate throughout the order lifecycle (e.g., handling returns). Strategic improvements are also needed for moderation flexibility and rating aggregation accuracy.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Prevent Duplicate Reviews (Race Condition) ✅ IMPLEMENTED

**Files**: `migrations/005_fix_unique_review_constraint.sql`, `internal/data/postgres/review.go`
**Risk**: Data corruption leading to multiple reviews from one customer per product.
**Problem**: Application-level check is insufficient under high concurrency.
**Solution Applied**:
The unique partial index already existed in migration 005 (`idx_reviews_unique_customer_product_active`). The fix was in the repository's `Create` method which now detects PostgreSQL unique constraint violations (error code `23505`) and translates them into clean business errors (`ErrReviewAlreadyExistsForProduct` or `ErrReviewAlreadyExists`), ensuring proper gRPC status mapping.

```go
func (r *reviewRepo) Create(ctx context.Context, review *model.Review) error {
    if err := r.GetDB(ctx).Create(review).Error; err != nil {
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) && pgErr.Code == "23505" {
            if strings.Contains(pgErr.ConstraintName, "customer_product") {
                return bizReview.ErrReviewAlreadyExistsForProduct
            }
            if strings.Contains(pgErr.ConstraintName, "order") {
                return bizReview.ErrReviewAlreadyExists
            }
            return bizReview.ErrReviewAlreadyExistsForProduct
        }
        return err
    }
    return nil
}
```

**Validation**: `go build ./...` ✅, `go test ./...` ✅, `golangci-lint run ./...` ✅

---

### [x] Task 2: Dynamic "Un-verification" on Returns ✅ IMPLEMENTED

**Files**: `internal/biz/review/review.go`, `internal/server/events.go`, `internal/server/http.go`, `internal/worker/outbox_worker.go`
**Risk**: Customers keeping "Verified" badges on reviews for returned/refunded items.
**Problem**: Logic only checks verification at creation.
**Solution Applied**:
1. Added `UnverifyReviewForReturn(ctx, orderID)` method to `ReviewUsecase` — looks up review by order ID, sets `is_verified = false`, and saves a `review.unverified` outbox event for rating recalculation.
2. Created `ReturnProcessedHandler` HTTP handler for `POST /events/return-processed` (Dapr callback for `return.refund_processed` events).
3. Registered the handler in `NewHTTPServer` alongside the existing shipment.delivered handler.
4. Added `review.unverified` routing in the outbox event router.

```go
// UnverifyReviewForReturn strips the "Verified Purchase" badge
func (uc *ReviewUsecase) UnverifyReviewForReturn(ctx context.Context, orderID string) error {
    review, err := uc.repo.GetByOrderID(ctx, orderID)
    // ... idempotent: skips if no review or already unverified
    review.IsVerified = false
    // transactional update + outbox event
}
```

**Validation**: `go build ./...` ✅, `go test ./...` ✅, `golangci-lint run ./...` ✅

---

### [x] Task 3: Transactional Outbox Standardization ✅ IMPLEMENTED

**Files**: `internal/biz/moderation/moderation.go`, `internal/biz/moderation/outbox_helpers.go`, `internal/biz/rating/rating.go`, `internal/biz/rating/outbox_helpers.go`
**Risk**: Inconsistent event publishing.
**Problem**: Directly calling `outboxRepo.Create` with inline struct construction instead of using a standardized helper.
**Solution Applied**:
1. Created `outbox_helpers.go` in both `moderation` and `rating` packages with a reusable `saveOutboxEvent(ctx, aggregateType, aggregateID, eventType, payload)` helper.
2. Refactored `AutoModerate`, `ManualModerate` (moderation) and `RecalculateRating` (rating) to use the standardized helpers.
3. Fixed discarded `json.Marshal` errors (previously using `_ =` pattern) — errors now propagate properly.
4. Removed unused `encoding/json` and `uuid` imports from refactored files.

```go
// saveOutboxEvent standardized helper (moderation/rating packages)
func (uc *ModerationUsecase) saveOutboxEvent(ctx context.Context, aggregateType, aggregateID, eventType string, payload interface{}) error {
    payloadBytes, err := json.Marshal(payload)
    if err != nil { return err }
    return uc.outboxRepo.Create(ctx, &model.OutboxEvent{
        ID: uuid.New(), AggregateType: aggregateType,
        AggregateID: aggregateID, Type: eventType,
        Payload: string(payloadBytes), Status: "pending",
    })
}
```

**Validation**: `go build ./...` ✅, `go test ./...` ✅, `golangci-lint run ./...` ✅

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 4: Externalize Moderation Thresholds ✅ IMPLEMENTED

**Files**: `internal/biz/moderation/moderation.go`, `internal/config/config.go`, `configs/config.yaml`
**Problem**: Hardcoded scoring logic (base 50, -20 for length) is inflexible.
**Solution Applied**:
1. Added 6 configurable scoring weight fields to `ReviewModerationConfig`: `base_score`, `short_content_penalty`, `long_content_bonus`, `title_bonus`, `verified_bonus`, `extreme_rating_penalty`.
2. Injected `*conf.AppConfig` into `NewModerationUsecase` constructor with fallback to sensible defaults when config is nil.
3. Replaced all hardcoded values in `calculateModerationScore()` and threshold checks in `AutoModerate()` with config reads.
4. Updated `configs/config.yaml` with default values matching previous hardcoded behavior.

```yaml
# configs/config.yaml
moderation:
  auto_approve_threshold: 70.0
  auto_reject_threshold: 50.0
  base_score: 50.0
  short_content_penalty: 20.0
  long_content_bonus: 10.0
  title_bonus: 10.0
  verified_bonus: 20.0
  extreme_rating_penalty: 5.0
```

**Validation**: `go build ./...` ✅, `go test ./...` ✅, `golangci-lint run ./...` ✅

---

### [x] Task 5: Rating Aggregation Refinement ✅ IMPLEMENTED

**Files**: `internal/biz/rating/rating.go`, `internal/data/postgres/rating.go`
**Problem**: Raw SQL defines weighting (1.0 vs 0.7) as hardcoded literals.
**Solution Applied**:
1. Created `RatingWeights` struct with `VerifiedWeight` and `UnverifiedWeight` fields.
2. Added `DefaultRatingWeights()` constructor returning 1.0/0.7 defaults.
3. Updated `RatingRepo.AggregateByProductID` interface to accept `RatingWeights` parameter.
4. Modified SQL query to use parameterized bind variables (`?`) instead of hardcoded `1.0` and `0.7`.
5. Updated all test mocks to match the new interface signature.

```go
type RatingWeights struct {
    VerifiedWeight   float64
    UnverifiedWeight float64
}

// SQL now uses parameterized weights
COALESCE(SUM(rating * CASE WHEN is_verified THEN ? ELSE ? END), 0) AS weighted_sum,
COALESCE(SUM(CASE WHEN is_verified THEN ? ELSE ? END), 0)          AS total_weight
```

**Validation**: `go build ./...` ✅, `go test ./...` ✅, `golangci-lint run ./...` ✅

---

## 🔧 Pre-Commit Checklist

```bash
cd review && wire gen ./cmd/review/ ./cmd/worker/  # ✅ PASSED
cd review && go build ./...                        # ✅ PASSED
cd review && go test ./...                         # ✅ PASSED (all 7 test packages)
cd review && golangci-lint run ./...               # ✅ PASSED (zero warnings)
```

---

## 📝 Commit Format

```
fix(review): prevent duplicate reviews and handle return verification

- fix: add unique constraint error handling in review repo
- feat: implement return event listener to strip verified status
- refactor: use standardized outbox helper in moderation/rating logic
- chore: move moderation thresholds to configuration
- refactor: parameterize rating aggregation weights

Closes: AGENT-05
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| No duplicate reviews | Stress test with 10 parallel requests for same product/user | ✅ |
| Review un-verified on return | Publish `return_processed` event and check `is_verified` flag | ✅ |
| Outbox events stored | Check `outbox_events` table after moderation | ✅ |
| Configurable moderation | Change threshold in YAML and verify action changes | ✅ |
