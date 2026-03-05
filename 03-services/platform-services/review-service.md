# ⭐ Review Service - Product Reviews & Moderation

> **Owner**: Platform Team  
> **Last Updated**: 2026-03-05  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: 8016/9016

**Service Name**: Review Service
**Version**: 1.2.0
**Last Updated**: 2026-03-05
**Review Status**: ✅ Production Ready
**Production Ready**: 98%  
**Common Package**: v1.23.1  

---

## 🎯 Overview

Review Service quản lý product reviews, ratings, và content moderation cho e-commerce platform. Service này cung cấp review submission, validation, moderation workflow, và review analytics.

### Core Capabilities
- **⭐ Review Management**: Submit, edit, delete product reviews
- **📊 Rating System**: 1-5 star ratings với aggregated statistics
- **🛡️ Content Moderation**: Automated và manual review moderation
- **👍 Helpful Votes**: User voting system cho review quality
- **📈 Review Analytics**: Review performance và sentiment analysis
- **🚨 Abuse Detection**: Spam detection và fraudulent review prevention
- **🌍 Multi-Language**: Support for multiple languages và character sets
- **📱 Media Support**: Photo/video reviews

### Business Value
- **Trust Building**: Authentic customer reviews tăng credibility
- **Product Insights**: Customer feedback cho product improvement
- **SEO Benefits**: Rich review content improves search rankings
- **Conversion Optimization**: Social proof tăng purchase confidence

---

## 🏗️ Architecture

### Service Architecture
```
review/
├── cmd/review/                  # Main service entry point
├── cmd/worker/                  # Worker binary (outbox, cron, events)
├── internal/
│   ├── biz/                      # Business logic domains
│   │   ├── review/              # Review CRUD operations
│   │   ├── rating/              # Rating calculations
│   │   ├── moderation/          # Content moderation
│   │   ├── helpful/             # Helpful vote system
│   │   └── analytics/           # Review analytics
│   ├── data/                     # Data access (PostgreSQL + Redis)
│   ├── service/                  # gRPC/HTTP API layer
│   ├── server/                   # Server setup
│   ├── middleware/               # HTTP middleware
│   ├── config/                   # Configuration
│   └── observability/            # Metrics, tracing
├── api/review/v1/                # Protocol buffers
├── migrations/                   # Database schema
└── configs/                      # Configuration files
```

### Ports & Dependencies
- **HTTP API**: `:8016` - REST endpoints
- **gRPC API**: `:9016` - Internal communication
- **Database**: PostgreSQL (`review_db`) + Redis (caching)
- **External Services**: Customer Service, Product Service, Notification Service

---

## 🔄 Business Flow

### Review Submission & Moderation Workflow

```mermaid
graph TD
    A[User Submits Review] --> B[Initial Validation]
    B --> C[Spam Detection]
    C --> D[Auto Moderation]
    D --> E[Manual Review Queue]
    E --> F[Approved/Rejected]
    F --> G[Published/Archived]
    G --> H[Analytics Update]
```

### Detailed Review Process

#### 1. Review Submission & Validation
```
User Input → Review Validation
├── Authenticate user (must have purchased product)
├── Validate review content (length, format, profanity)
├── Check duplicate reviews (one review per product per customer)
├── Verify purchase history
├── Extract rating và text content
└── Queue for processing
```

#### 2. Content Moderation
```
Validated Review → Moderation
├── Automated spam detection (AI/ML models)
├── Profanity và content filtering
├── Sentiment analysis
├── Image validation (if media included)
├── Business rule checks (minimum length, etc.)
└── Route to manual review if borderline
```

#### 3. Review Publishing & Aggregation
```
Approved Review → Publishing
├── Publish review to product page
├── Update product aggregate rating
├── Recalculate review statistics
├── Trigger notification to product owner
├── Index for search engines
└── Update review analytics
```

#### 4. User Interaction & Analytics
```
Published Review → User Engagement
├── Track view counts và helpful votes
├── Monitor user interactions
├── Calculate review quality scores
├── Update review rankings
└── Generate review insights
```

---

## 🔌 Key APIs

### Review Management
```protobuf
// Submit product review
rpc SubmitReview(SubmitReviewRequest) returns (SubmitReviewResponse) {
  option (google.api.http) = {
    post: "/api/v1/reviews"
    body: "*"
  };
}

// Get product reviews
rpc GetProductReviews(GetProductReviewsRequest) returns (GetProductReviewsResponse) {
  option (google.api.http) = {
    get: "/api/v1/products/{product_id}/reviews"
  };
}

// Update review
rpc UpdateReview(UpdateReviewRequest) returns (UpdateReviewResponse) {
  option (google.api.http) = {
    put: "/api/v1/reviews/{review_id}"
    body: "*"
  };
}
```

**Submit Review Request:**
```json
{
  "product_id": "product-uuid",
  "customer_id": "customer-uuid",
  "order_id": "order-uuid",
  "rating": 5,
  "title": "Excellent product!",
  "content": "This product exceeded my expectations...",
  "images": ["image1.jpg", "image2.jpg"],
  "is_verified_purchase": true,
  "metadata": {
    "source": "website",
    "device": "mobile"
  }
}
```

### Rating & Statistics
```protobuf
// Get product rating summary
rpc GetProductRatingSummary(GetProductRatingSummaryRequest) returns (RatingSummary) {
  option (google.api.http) = {
    get: "/api/v1/products/{product_id}/rating-summary"
  };
}

// Get customer review history
rpc GetCustomerReviews(GetCustomerReviewsRequest) returns (GetCustomerReviewsResponse) {
  option (google.api.http) = {
    get: "/api/v1/customers/{customer_id}/reviews"
  };
}
```

### Moderation APIs
```protobuf
// Moderate review content
rpc ModerateReview(ModerateReviewRequest) returns (ModerateReviewResponse) {
  option (google.api.http) = {
    post: "/api/v1/moderation/reviews/{review_id}"
    body: "*"
  };
}

// Get moderation queue
rpc GetModerationQueue(GetModerationQueueRequest) returns (GetModerationQueueResponse) {
  option (google.api.http) = {
    get: "/api/v1/moderation/queue"
  };
}
```

### Helpful Vote System
```protobuf
// Vote on review helpfulness
rpc VoteReviewHelpful(VoteReviewHelpfulRequest) returns (VoteReviewHelpfulResponse) {
  option (google.api.http) = {
    post: "/api/v1/reviews/{review_id}/helpful"
    body: "*"
  };
}

// Get review helpful statistics
rpc GetReviewHelpfulStats(GetReviewHelpfulStatsRequest) returns (HelpfulStats) {
  option (google.api.http) = {
    get: "/api/v1/reviews/{review_id}/helpful-stats"
  };
}
```

---

## 🛡️ Content Moderation

### Automated Moderation Rules
- **Spam Detection**: AI-powered spam identification
- **Profanity Filtering**: Multi-language profanity detection
- **Duplicate Detection**: Prevent duplicate reviews
- **Sentiment Analysis**: Validate review authenticity
- **Length Validation**: Minimum/maximum content length
- **Image Validation**: Check for inappropriate content

### Manual Moderation Workflow
```go
func processManualModeration(review Review, moderator Moderator) ModerationResult {
    // 1. Load review with full context
    fullReview := loadReviewWithContext(review.ID)

    // 2. Apply moderation guidelines
    violations := checkModerationGuidelines(fullReview)

    // 3. Calculate risk score
    riskScore := calculateReviewRiskScore(fullReview, violations)

    // 4. Determine moderation action
    action := determineModerationAction(riskScore, moderator.Level)

    // 5. Apply moderation decision
    result := applyModerationAction(review, action, moderator)

    // 6. Log moderation activity
    logModerationActivity(review, action, moderator)

    return result
}
```

### Risk-Based Moderation
```go
func calculateReviewRiskScore(review Review, violations []Violation) float64 {
    score := 0.0

    // Content-based factors
    if containsProfanity(review.Content) {
        score += 30
    }
    if isSpam(review.Content) {
        score += 50
    }
    if hasLowQuality(review.Content) {
        score += 20
    }

    // Behavioral factors
    if isFirstReview(review.CustomerID) {
        score += 10
    }
    if hasManyRecentReviews(review.CustomerID) {
        score += 15
    }
    if review.Rating == 5 && sentimentAnalysis(review.Content) == "negative" {
        score += 25 // Rating-content mismatch
    }

    // External factors
    if fromHighRiskIP(review.IPAddress) {
        score += 20
    }

    return math.Min(score, 100) // Cap at 100
}
```

---

## 🔗 Integration Points

### Catalog Service Integration
- **Consumes**: Product information, category data
- **Provides**: Review data cho product pages
- **Data Flow**: Product reviews → Product rating updates → Search indexing

### Customer Service Integration
- **Consumes**: Customer profiles, purchase history
- **Provides**: Customer review history
- **Data Flow**: Purchase verification → Review eligibility → Review publishing

### Order Service Integration
- **Consumes**: Order data for purchase verification
- **Provides**: Post-purchase review triggers
- **Data Flow**: Order completion → Review request → Review submission

### Notification Service Integration
- **Provides**: Review notifications (review approved, replied to, etc.)
- **Events**: Review published, moderation decisions
- **Templates**: Review confirmation, moderation updates

---

## 🎯 Business Logic

### Review Submission & Validation
```go
func submitProductReview(req SubmitReviewRequest) (*Review, error) {
    // 1. Authenticate user
    customer, err := authenticateCustomer(req.CustomerID)
    if err != nil {
        return nil, err
    }

    // 2. Verify purchase eligibility
    eligible, err := verifyPurchaseEligibility(req.ProductID, req.CustomerID, req.OrderID)
    if err != nil || !eligible {
        return nil, errors.New("customer not eligible to review this product")
    }

    // 3. Check duplicate reviews
    existing, err := checkExistingReview(req.ProductID, req.CustomerID)
    if err != nil {
        return nil, err
    }
    if existing != nil {
        return nil, errors.New("customer already reviewed this product")
    }

    // 4. Validate review content
    validationResult := validateReviewContent(req)
    if !validationResult.IsValid {
        return nil, fmt.Errorf("invalid review content: %s", validationResult.Reason)
    }

    // 5. Create review record
    review := createReviewRecord(req, customer)

    // 6. Queue for moderation
    queueForModeration(review)

    // 7. Publish review submitted event
    publishReviewEvent("review.submitted", review)

    return review, nil
}
```

### Rating Aggregation & Statistics
```go
func updateProductRatingStats(productID string) error {
    // 1. Get all approved reviews for product
    reviews, err := getApprovedReviews(productID)
    if err != nil {
        return err
    }

    // 2. Calculate aggregate statistics
    stats := calculateRatingStatistics(reviews)

    // 3. Update product rating summary
    err = updateProductRatingSummary(productID, stats)
    if err != nil {
        return err
    }

    // 4. Update rating distribution
    err = updateRatingDistribution(productID, reviews)
    if err != nil {
        return err
    }

    // 5. Recalculate review quality scores
    err = updateReviewQualityScores(reviews)
    if err != nil {
        return err
    }

    // 6. Publish rating updated event
    publishRatingEvent("product.rating.updated", productID, stats)

    return nil
}

func calculateRatingStatistics(reviews []Review) RatingStats {
    totalReviews := len(reviews)
    if totalReviews == 0 {
        return RatingStats{}
    }

    sum := 0
    distribution := make(map[int]int)

    for _, review := range reviews {
        sum += review.Rating
        distribution[review.Rating]++
    }

    averageRating := float64(sum) / float64(totalReviews)

    return RatingStats{
        TotalReviews: totalReviews,
        AverageRating: averageRating,
        RatingDistribution: distribution,
        LastUpdated: time.Now(),
    }
}
```

### Helpful Vote System
```go
func voteReviewHelpful(reviewID string, customerID string, vote VoteType) error {
    // 1. Validate vote eligibility
    eligible, err := checkVoteEligibility(reviewID, customerID)
    if err != nil {
        return err
    }
    if !eligible {
        return errors.New("customer not eligible to vote on this review")
    }

    // 2. Check existing vote
    existingVote, err := getExistingVote(reviewID, customerID)
    if err != nil {
        return err
    }

    if existingVote != nil {
        // Update existing vote
        if existingVote.VoteType == vote {
            // Same vote, remove it
            return removeVote(existingVote.ID)
        } else {
            // Change vote
            return updateVote(existingVote.ID, vote)
        }
    } else {
        // Create new vote
        return createVote(reviewID, customerID, vote)
    }
}

func updateHelpfulStats(reviewID string) error {
    // 1. Count helpful votes
    helpfulCount, err := countHelpfulVotes(reviewID)
    if err != nil {
        return err
    }

    // 2. Count total votes
    totalCount, err := countTotalVotes(reviewID)
    if err != nil {
        return err
    }

    // 3. Calculate helpful percentage
    helpfulPercentage := float64(helpfulCount) / float64(totalCount) * 100

    // 4. Update review helpful stats
    return updateReviewStats(reviewID, helpfulCount, totalCount, helpfulPercentage)
}
```

---

## 📊 Event-Driven Architecture

### Published Events
- `review.submitted` - Review submitted for moderation
- `review.approved` - Review approved and published
- `review.rejected` - Review rejected by moderation
- `review.updated` - Review content updated
- `review.helpful_voted` - Helpful vote cast
- `product.rating.updated` - Product rating statistics updated

### Consumed Events
- `shipping.shipment.delivered` - Mark order eligible for review (90-day window)
- `product.updated` - Handle product changes affecting reviews

---

## 🚀 Development Guide

### Quick Start
```bash
# Setup
cd review
go mod download
make migrate-up
make api
make wire

# Run
make run
```

### Configuration
```yaml
# configs/config.yaml
database:
  dsn: postgres://review_user:review_pass@postgres:5432/review_db

redis:
  addr: redis:6379
  db: 6

server:
  http:
    addr: 0.0.0.0:8016
  grpc:
    addr: 0.0.0.0:9016

moderation:
  auto_approve_threshold: 0.8
  manual_review_threshold: 0.3
  spam_detection_enabled: true
  profanity_filter_enabled: true

reviews:
  min_content_length: 10
  max_content_length: 2000
  max_images_per_review: 5
  duplicate_check_window_days: 365
```

---

**Service Status**: Production Ready (98%)  
**Critical Path**: Review submission và product rating display  
**Performance Target**: <200ms review submission, <50ms rating queries  
**Review Volume**: Support 10,000+ reviews/month with moderation

---

## 📋 Code Review Status

**Last Review**: March 5, 2026  
**Review Checklist**: `docs/10-appendix/workflow/review-review-checklist.md`

### ✅ Completed Actions (2026-03-05)
- **P0 Fixed**: Outbox TX bypass → uses `transaction.ExtractTx(ctx)` for atomicity
- **P0 Fixed**: External calls (order/catalog) moved outside DB transaction
- **P0 Fixed**: `IsVerified` removed from client request mapping (security)
- **P1 Fixed**: Rating N+1 → SQL aggregate query (`AggregateByProductID`)
- **P1 Fixed**: Auto-moderation offset drift → always-fetch-page-1 pattern
- **P1 Fixed**: OpenTelemetry tracing spans added to all key biz operations
- **P1 Fixed**: Outbox status case mismatch standardized to lowercase
- **P2 Fixed**: Duplicate import, division-by-zero guard, default pageSize
- **Dependencies**: Updated to `common@v1.23.1`, `catalog@v1.3.9`, `order@v1.1.9`, `user@v1.0.14`
- **Linting**: ✅ golangci-lint 0 warnings
- **Wire**: ✅ Regenerated for both review and worker binaries
- **Replace Directives**: ✅ None

See full review checklist for detailed information.