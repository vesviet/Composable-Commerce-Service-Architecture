# ⭐ Product Review & Rating Checklist

**Service:** Review Service  
**Created:** 2025-11-19  
**Priority:** 🟡 **Medium**

---

## 🎯 Overview

Product reviews drive conversions (increase by 18-25%) and provide valuable feedback for product improvement.

---

## 1. Review Submission

### Requirements

- [ ] **R1.1** Verified purchase requirement
- [ ] **R1.2** One review per product per customer
- [ ] **R1.3** Rating (1-5 stars)
- [ ] **R1.4** Review title & text (min/max length)
- [ ] **R1.5** Photo/video upload (up to 5)
- [ ] **R1.6** Pros/cons fields
- [ ] **R1.7** Recommend product (yes/no)
- [ ] **R1.8** Anonymous option

### Implementation

```go
type Review struct {
    ID              string
    ProductID       string
    CustomerID      string
    OrderID         string  // For verified purchase
    
    // Content
    Rating          int     // 1-5
    Title           string
    Text            string
    Pros            string
    Cons            string
    Recommended     bool
    
    // Media
    Photos          []string
    Videos          []string
    
    // Status
    Status          string  // "pending", "approved", "rejected"
    IsVerified      bool    // Verified purchase
    IsAnonymous     bool
    
    // Moderation
    ModerationNotes string
    ModeratedBy     string
    ModeratedAt     *time.Time
    
    // Engagement
    HelpfulCount    int
    ReportCount     int
    
    // Visibility
    IsPublished     bool
    PublishedAt     *time.Time
    
    CreatedAt       time.Time
    UpdatedAt       time.Time
}

func (uc *ReviewUseCase) SubmitReview(ctx context.Context, req *SubmitReviewRequest) (*Review, error) {
    // 1. Verify purchase
    order, err := uc.orderClient.GetOrder(ctx, req.OrderID)
    if err != nil || order.CustomerID != req.CustomerID {
        return nil, ErrOrderNotFound
    }
    
    // Check if product in order
    hasProduct := false
    for _, item := range order.Items {
        if item.ProductID == req.ProductID {
            hasProduct = true
            break
        }
    }
    
    if !hasProduct {
        return nil, ErrProductNotInOrder
    }
    
    // 2. Check for existing review
    existing, _ := uc.repo.GetReview(ctx, req.CustomerID, req.ProductID)
    if existing != nil {
        return nil, ErrReviewAlreadyExists
    }
    
    // 3. Validate review content
    if len(req.Text) < 20 {
        return nil, ErrReviewTooShort
    }
    
    if len(req.Text) > 5000 {
        return nil, ErrReviewTooLong
    }
    
    // 4. Create review
    review := &Review{
        ID:          uuid.New().String(),
        ProductID:   req.ProductID,
        CustomerID:  req.CustomerID,
        OrderID:     req.OrderID,
        Rating:      req.Rating,
        Title:       req.Title,
        Text:        req.Text,
        Pros:        req.Pros,
        Cons:        req.Cons,
        Recommended: req.Recommended,
        Photos:      req.Photos,
        Videos:      req.Videos,
        Status:      "pending",
        IsVerified:  true,
        IsAnonymous: req.IsAnonymous,
        IsPublished: false,
        CreatedAt:   time.Now(),
    }
    
    // 5. Auto-moderation
    moderationResult := uc.moderator.Check(review)
    if moderationResult.AutoApprove {
        review.Status = "approved"
        review.IsPublished = true
        review.PublishedAt = timePtr(time.Now())
    }
    
    if err := uc.repo.CreateReview(ctx, review); err != nil {
        return nil, err
    }
    
    // 6. Update product rating
    go uc.UpdateProductRating(context.Background(), req.ProductID)
    
    // 7. Notify customer
    uc.notifyReviewSubmitted(ctx, review)
    
    return review, nil
}
```

---

## 2. Review Moderation

### Requirements

- [ ] **R2.1** Auto-moderation (profanity filter)
- [ ] **R2.2** Manual review queue
- [ ] **R2.3** Approval workflow
- [ ] **R2.4** Rejection with reason
- [ ] **R2.5** Spam detection
- [ ] **R2.6** Fake review detection
- [ ] **R2.7** Edit suggestions

### Implementation

```go
type Moderator struct {
    profanityFilter *ProfanityFilter
    spamDetector    *SpamDetector
}

func (m *Moderator) Check(review *Review) *ModerationResult {
    result := &ModerationResult{
        AutoApprove: false,
        Flags:       []string{},
    }
    
    // 1. Profanity check
    if m.profanityFilter.Contains(review.Text) || m.profanityFilter.Contains(review.Title) {
        result.Flags = append(result.Flags, "profanity_detected")
        return result
    }
    
    // 2. Spam detection
    if m.spamDetector.IsSpam(review.Text) {
        result.Flags = append(result.Flags, "spam_detected")
        return result
    }
    
    // 3. Content quality
    if len(review.Text) < 50 {
        result.Flags = append(result.Flags, "low_quality")
    }
    
    // 4. Auto-approve if passes all checks
    if len(result.Flags) == 0 {
        result.AutoApprove = true
    }
    
    return result
}

func (uc *ReviewUseCase) ApproveReview(ctx context.Context, reviewID, moderatorID string) error {
    review, _ := uc.repo.GetReview(ctx, reviewID)
    
    review.Status = "approved"
    review.IsPublished = true
    review.PublishedAt = timePtr(time.Now())
    review.ModeratedBy = moderatorID
    review.ModeratedAt = timePtr(time.Now())
    
    uc.repo.UpdateReview(ctx, review)
    
    // Update product rating
    uc.UpdateProductRating(ctx, review.ProductID)
    
    // Notify customer
    uc.notifyReviewApproved(ctx, review)
    
    return nil
}

func (uc *ReviewUseCase) RejectReview(ctx context.Context, reviewID, moderatorID, reason string) error {
    review, _ := uc.repo.GetReviewByID(ctx, reviewID)
    
    review.Status = "rejected"
    review.ModerationNotes = reason
    review.ModeratedBy = moderatorID
    review.ModeratedAt = timePtr(time.Now())
    
    uc.repo.UpdateReview(ctx, review)
    
    // Notify customer
    uc.notifyReviewRejected(ctx, review, reason)
    
    return nil
}
```

---

## 3. Review Display

### Requirements

- [ ] **R3.1** Sort by (helpful, recent, rating high/low)
- [ ] **R3.2** Filter by rating
- [ ] **R3.3** Filter by verified purchase
- [ ] **R3.4** Show reviewer name (or anonymous)
- [ ] **R3.5** Show purchase date
- [ ] **R3.6** Display photos/videos
- [ ] **R3.7** Helpful votes
- [ ] **R3.8** Seller response
- [ ] **R3.9** Pagination

### Implementation

```go
func (uc *ReviewUseCase) GetProductReviews(ctx context.Context, productID string, opts *ReviewOptions) (*ReviewList, error) {
    reviews, total, err := uc.repo.GetProductReviews(ctx, &GetReviewsQuery{
        ProductID:      productID,
        Status:         "approved",
        IsPublished:    true,
        MinRating:      opts.MinRating,
        MaxRating:      opts.MaxRating,
        VerifiedOnly:   opts.VerifiedOnly,
        SortBy:         opts.SortBy,  // "helpful", "recent", "rating_high", "rating_low"
        Page:           opts.Page,
        PageSize:       opts.PageSize,
    })
    
    if err != nil {
        return nil, err
    }
    
    // Enrich with customer data
    for i := range reviews {
        review := &reviews[i]
        
        if !review.IsAnonymous {
            customer, _ := uc.customerClient.GetCustomer(ctx, review.CustomerID)
            review.ReviewerName = customer.FirstName
        } else {
            review.ReviewerName = "Anonymous"
        }
    }
    
    return &ReviewList{
        Reviews:    reviews,
        Total:      total,
        Page:       opts.Page,
        PageSize:   opts.PageSize,
        TotalPages: (total + opts.PageSize - 1) / opts.PageSize,
    }, nil
}
```

---

## 4. Rating Aggregation

### Requirements

- [ ] **R4.1** Average rating calculation
- [ ] **R4.2** Rating distribution (5-star histogram)
- [ ] **R4.3** Review count
- [ ] **R4.4** Weighted ratings (verified vs unverified)
- [ ] **R4.5** Time-decay for old reviews
- [ ] **R4.6** Real-time updates

### Implementation

```go
type ProductRating struct {
    ProductID           string
    AverageRating       float64  // 4.3
    TotalReviews        int
    RatingDistribution  map[int]int  // {5: 120, 4: 45, 3: 10, 2: 3, 1: 2}
    VerifiedReviews     int
    RecommendationRate  float64  // % who recommend
    UpdatedAt           time.Time
}

func (uc *ReviewUseCase) UpdateProductRating(ctx context.Context, productID string) error {
    // Get all approved reviews
    reviews, _ := uc.repo.GetProductReviews(ctx, &GetReviewsQuery{
        ProductID:   productID,
        Status:      "approved",
        IsPublished: true,
    })
    
    if len(reviews) == 0 {
        return nil
    }
    
    // Calculate average rating
    totalRating := 0.0
    distribution := make(map[int]int)
    verifiedCount := 0
    recommendCount := 0
    
    for _, review := range reviews {
        // Apply weight (verified = 1.0, unverified = 0.7)
        weight := 0.7
        if review.IsVerified {
            weight = 1.0
            verifiedCount++
        }
        
        totalRating += float64(review.Rating) * weight
        distribution[review.Rating]++
        
        if review.Recommended {
            recommendCount++
        }
    }
    
    avgRating := totalRating / float64(len(reviews))
    recommendRate := float64(recommendCount) / float64(len(reviews)) * 100
    
    // Update product rating
    rating := &ProductRating{
        ProductID:          productID,
        AverageRating:      math.Round(avgRating*10) / 10,  // Round to 1 decimal
        TotalReviews:       len(reviews),
        RatingDistribution: distribution,
        VerifiedReviews:    verifiedCount,
        RecommendationRate: math.Round(recommendRate*10) / 10,
        UpdatedAt:          time.Now(),
    }
    
    // Save to database
    uc.repo.UpdateProductRating(ctx, rating)
    
    // Update catalog service
    uc.catalogClient.UpdateProductRating(ctx, productID, avgRating, len(reviews))
    
    return nil
}
```

---

## 5. Review Engagement

### Requirements

- [ ] **R5.1** Mark review as helpful
- [ ] **R5.2** Report inappropriate review
- [ ] **R5.3** Seller response to review
- [ ] **R5.4** Customer can update review
- [ ] **R5.5** Review voting analytics

### Implementation

```go
func (uc *ReviewUseCase) MarkHelpful(ctx context.Context, reviewID, customerID string) error {
    // Check if already voted
    if uc.hasVoted(reviewID, customerID) {
        return ErrAlreadyVoted
    }
    
    // Record vote
    vote := &ReviewVote{
        ReviewID:   reviewID,
        CustomerID: customerID,
        VoteType:   "helpful",
        CreatedAt:  time.Now(),
    }
    
    uc.repo.CreateVote(ctx, vote)
    
    // Increment helpful count
    uc.repo.IncrementHelpfulCount(ctx, reviewID)
    
    return nil
}

func (uc *ReviewUseCase) ReportReview(ctx context.Context, reviewID, reporterID, reason string) error {
    report := &ReviewReport{
        ReviewID:   reviewID,
        ReporterID: reporterID,
        Reason:     reason,
        Status:     "pending",
        CreatedAt:  time.Now(),
    }
    
    uc.repo.CreateReport(ctx, report)
    
    // Increment report count
    uc.repo.IncrementReportCount(ctx, reviewID)
    
    // Auto-hide if report count > 5
    review, _ := uc.repo.GetReviewByID(ctx, reviewID)
    if review.ReportCount >= 5 {
        review.IsPublished = false
        uc.repo.UpdateReview(ctx, review)
    }
    
    return nil
}

func (uc *ReviewUseCase) AddSellerResponse(ctx context.Context, reviewID, response string) error {
    review, _ := uc.repo.GetReviewByID(ctx, reviewID)
    
    review.SellerResponse = response
    review.SellerRespondedAt = timePtr(time.Now())
    
    uc.repo.UpdateReview(ctx, review)
    
    // Notify customer
    uc.notifySellerResponse(ctx, review)
    
    return nil
}
```

---

## 📊 Success Criteria

- [ ] ✅ Review submission rate >15%
- [ ] ✅ Auto-moderation accuracy >90%
- [ ] ✅ Manual review SLA <24h
- [ ] ✅ Review helpful rate >5%
- [ ] ✅ Spam detection rate >95%

---

**Status:** Ready for Implementation
