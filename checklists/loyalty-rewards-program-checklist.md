# 🎖️ Loyalty & Rewards Program Checklist

**Service:** Loyalty Service  
**Created:** 2025-11-19  
**Priority:** 🟡 **Medium**

---

## 🎯 Overview

Loyalty programs increase customer retention by 5-10% và average order value by 15-20%.

---

## 1. Points Earning

### Requirements

- [ ] **R1.1** Points on purchase (1 point per $1 spent)
- [ ] **R1.2** Points on registration (100 welcome points)
- [ ] **R1.3** Points on referral (500 points per successful referral)
- [ ] **R1.4** Points on review submission (50 points)
- [ ] **R1.5** Points on social sharing (25 points)
- [ ] **R1.6** Birthday points (200 points)
- [ ] **R1.7** Bonus points campaigns
- [ ] **R1.8** Points multiplier events

### Implementation

```go
type PointsTransaction struct {
    ID              string
    CustomerID      string
    Type            string  // "earn", "redeem", "expire"
    Amount          int
    Reason          string
    ReferenceID     string  // Order ID, Review ID, etc.
    Balance         int     // Balance after transaction
    ExpiresAt       *time.Time
    CreatedAt       time.Time
}

func (uc *LoyaltyUseCase) AwardPoints(ctx context.Context, req *AwardPointsRequest) error {
    // Get customer
    customer, _ := uc.customerClient.GetCustomer(ctx, req.CustomerID)
    
    // Calculate points
    points := req.Amount
    
    // Apply multiplier if active
    multiplier := uc.getActiveMultiplier(customer.Tier)
    points = int(float64(points) * multiplier)
    
    // Create transaction
    txn := &PointsTransaction{
        ID:          uuid.New().String(),
        CustomerID:  req.CustomerID,
        Type:        "earn",
        Amount:      points,
        Reason:      req.Reason,
        ReferenceID: req.ReferenceID,
        ExpiresAt:   timePtr(time.Now().Add(365 * 24 * time.Hour)),  // 1 year
        CreatedAt:   time.Now(),
    }
    
    // Update balance
    newBalance := uc.getPointsBalance(req.CustomerID) + points
    txn.Balance = newBalance
    
    uc.repo.CreateTransaction(ctx, txn)
    uc.repo.UpdateBalance(ctx, req.CustomerID, newBalance)
    
    // Notify customer
    uc.notifyPointsEarned(ctx, req.CustomerID, points)
    
    // Check tier upgrade
    uc.CheckTierUpgrade(ctx, req.CustomerID)
    
    return nil
}

func (uc *LoyaltyUseCase) HandleOrderPlaced(ctx context.Context, order *Order) error {
    // Award points for purchase
    points := int(order.Total)  // 1 point per $1
    
    return uc.AwardPoints(ctx, &AwardPointsRequest{
        CustomerID:  order.CustomerID,
        Amount:      points,
        Reason:      "purchase",
        ReferenceID: order.ID,
    })
}
```

---

## 2. Points Redemption

### Requirements

- [ ] **R2.1** Redeem for discount
- [ ] **R2.2** Redeem for products
- [ ] **R2.3** Redeem for gift cards
- [ ] **R2.4** Redeem for free shipping
- [ ] **R2.5** Minimum redemption threshold (e.g., 500 points)
- [ ] **R2.6** Points-to-cash conversion (100 points = $1)
- [ ] **R2.7** Redemption limits

### Implementation

```go
type RedemptionOption struct {
    ID              string
    Name            string
    PointsCost      int
    Value           float64
    Type            string  // "discount", "product", "gift_card", "free_shipping"
    MinimumPoints   int
    MaxRedemptions  int     // Per customer
}

func (uc *LoyaltyUseCase) RedeemPoints(ctx context.Context, req *RedeemPointsRequest) error {
    // Get current balance
    balance := uc.getPointsBalance(req.CustomerID)
    
    if balance < req.Points {
        return ErrInsufficientPoints
    }
    
    // Get redemption option
    option, _ := uc.repo.GetRedemptionOption(ctx, req.OptionID)
    
    if req.Points < option.MinimumPoints {
        return ErrBelowMinimumRedemption
    }
    
    // Create transaction
    txn := &PointsTransaction{
        ID:          uuid.New().String(),
        CustomerID:  req.CustomerID,
        Type:        "redeem",
        Amount:      -req.Points,
        Reason:      fmt.Sprintf("Redeemed for %s", option.Name),
        ReferenceID: req.OptionID,
        CreatedAt:   time.Now(),
    }
    
    newBalance := balance - req.Points
    txn.Balance = newBalance
    
    uc.repo.CreateTransaction(ctx, txn)
    uc.repo.UpdateBalance(ctx, req.CustomerID, newBalance)
    
    // Generate reward (coupon, gift card, etc.)
    reward := uc.generateReward(option, req.Points)
    
    // Notify customer
    uc.notifyRedemption(ctx, req.CustomerID, reward)
    
    return nil
}
```

---

## 3. Tier System

### Requirements

- [ ] **R3.1** Bronze tier (0-999 points)
- [ ] **R3.2** Silver tier (1000-4999 points)
- [ ] **R3.3** Gold tier (5000-9999 points)
- [ ] **R3.4** Platinum tier (10000+ points)
- [ ] **R3.5** Tier-specific benefits
- [ ] **R3.6** Tier upgrade rewards
- [ ] **R3.7** Tier downgrade handling
- [ ] **R3.8** Annual tier reset

### Implementation

```go
type LoyaltyTier struct {
    Name            string
    MinPoints       int
    MaxPoints       int
    Benefits        []TierBenefit
    PointsMultier   float64
}

type TierBenefit struct {
    Description     string
    Type            string  // "discount", "free_shipping", "early_access"
    Value           interface{}
}

var TierLevels = []LoyaltyTier{
    {
        Name:          "Bronze",
        MinPoints:     0,
        MaxPoints:     999,
        PointsMultier: 1.0,
        Benefits: []TierBenefit{
            {Description: "Earn 1 point per $1", Type: "points", Value: 1.0},
        },
    },
    {
        Name:          "Silver",
        MinPoints:     1000,
        MaxPoints:     4999,
        PointsMultier: 1.25,
        Benefits: []TierBenefit{
            {Description: "1.25x points on purchases", Type: "points", Value: 1.25},
            {Description: "Free shipping on orders $50+", Type: "free_shipping", Value: 50.0},
        },
    },
    {
        Name:          "Gold",
        MinPoints:     5000,
        MaxPoints:     9999,
        PointsMultier: 1.5,
        Benefits: []TierBenefit{
            {Description: "1.5x points on purchases", Type: "points", Value: 1.5},
            {Description: "Free shipping on all orders", Type: "free_shipping", Value: 0.0},
            {Description: "Early access to sales", Type: "early_access", Value: true},
        },
    },
    {
        Name:          "Platinum",
        MinPoints:     10000,
        MaxPoints:     999999,
        PointsMultier: 2.0,
        Benefits: []TierBenefit{
            {Description: "2x points on purchases", Type: "points", Value: 2.0},
            {Description: "Free shipping + free returns", Type: "free_shipping", Value: 0.0},
            {Description: "Exclusive products", Type: "exclusive_access", Value: true},
            {Description: "Dedicated support", Type: "priority_support", Value: true},
        },
    },
}

func (uc *LoyaltyUseCase) CheckTierUpgrade(ctx context.Context, customerID string) error {
    balance := uc.getPointsBalance(customerID)
    currentTier := uc.getCurrentTier(customerID)
    newTier := uc.calculateTier(balance)
    
    if newTier.Name != currentTier.Name {
        // Tier changed
        uc.repo.UpdateTier(ctx, customerID, newTier.Name)
        
        // Award upgrade bonus
        if newTier.MinPoints > currentTier.MinPoints {
            // Upgrade - give bonus
            bonusPoints := newTier.MinPoints / 10  // 10% bonus
            uc.AwardPoints(ctx, &AwardPointsRequest{
                CustomerID: customerID,
                Amount:     bonusPoints,
                Reason:     fmt.Sprintf("Tier upgrade to %s", newTier.Name),
            })
        }
        
        // Notify customer
        uc.notifyTierChange(ctx, customerID, currentTier, newTier)
    }
    
    return nil
}
```

---

## 4. Referral Program

### Requirements

- [ ] **R4.1** Generate referral code
- [ ] **R4.2** Track referrals
- [ ] **R4.3** Referrer rewards (500 points)
- [ ] **R4.4** Referee rewards (100 points)
- [ ] **R4.5** Referral fraud detection
- [ ] **R4.6** Referral limits

### Implementation

```go
type Referral struct {
    ID              string
    ReferrerID      string
    RefereeID       string
    ReferralCode    string
    Status          string  // "pending", "completed", "cancelled"
    ReferrerReward  int
    RefereeReward   int
    CompletedAt     *time.Time
    CreatedAt       time.Time
}

func (uc *LoyaltyUseCase) GenerateReferralCode(ctx context.Context, customerID string) (string, error) {
    customer, _ := uc.customerClient.GetCustomer(ctx, customerID)
    
    // Generate unique code
    code := fmt.Sprintf("%s%04d", strings.ToUpper(customer.FirstName[:3]), rand.Intn(10000))
    
    uc.repo.SaveReferralCode(ctx, customerID, code)
    
    return code, nil
}

func (uc *LoyaltyUseCase) ApplyReferralCode(ctx context.Context, refereeID, code string) error {
    // Get referrer
    referrerID, err := uc.repo.GetReferrerByCode(ctx, code)
    if err != nil {
        return ErrInvalidReferralCode
    }
    
    // Validate not self-referral
    if referrerID == refereeID {
        return ErrSelfReferralNotAllowed
    }
    
    // Create referral record
    referral := &Referral{
        ID:            uuid.New().String(),
        ReferrerID:    referrerID,
        RefereeID:     refereeID,
        ReferralCode:  code,
        Status:        "pending",
        ReferrerReward: 500,
        RefereeReward:  100,
        CreatedAt:     time.Now(),
    }
    
    return uc.repo.CreateReferral(ctx, referral)
}

func (uc *LoyaltyUseCase) CompleteReferral(ctx context.Context, referralID string) error {
    referral, _ := uc.repo.GetReferral(ctx, referralID)
    
    if referral.Status != "pending" {
        return nil
    }
    
    // Award points to referrer
    uc.AwardPoints(ctx, &AwardPointsRequest{
        CustomerID: referral.ReferrerID,
        Amount:     referral.ReferrerReward,
        Reason:     "referral_reward",
        ReferenceID: referralID,
    })
    
    // Award points to referee
    uc.AwardPoints(ctx, &AwardPointsRequest{
        CustomerID: referral.RefereeID,
        Amount:     referral.RefereeReward,
        Reason:     "referral_signup",
        ReferenceID: referralID,
    })
    
    // Update referral status
    referral.Status = "completed"
    referral.CompletedAt = timePtr(time.Now())
    
    uc.repo.UpdateReferral(ctx, referral)
    
    return nil
}
```

---

## 5. Points Management

### Requirements

- [ ] **R5.1** Points balance tracking
- [ ] **R5.2** Points expiration (1 year)
- [ ] **R5.3** Points history
- [ ] **R5.4** Points adjustment (admin)
- [ ] **R5.5** Points reversal (order return)
- [ ] **R5.6** Prevent negative balance

### Implementation

```go
func (uc *LoyaltyUseCase) GetPointsBalance(ctx context.Context, customerID string) (*PointsBalance, error) {
    balance := uc.getPointsBalance(customerID)
    expiringPoints := uc.getExpiringPoints(customerID, 30)  // Next 30 days
    
    return &PointsBalance{
        Available:       balance,
        ExpiringS oon:    expiringPoints,
        Lifetime:        uc.getLifetimePoints(customerID),
    }, nil
}

func (uc *LoyaltyUseCase) HandleOrderReturn(ctx context.Context, orderID string) error {
    // Find original points transaction
    txn, _ := uc.repo.GetTransactionByReference(ctx, orderID)
    
    if txn == nil || txn.Type != "earn" {
        return nil
    }
    
    // Reverse points
    reversalTxn := &PointsTransaction{
        ID:          uuid.New().String(),
        CustomerID:  txn.CustomerID,
        Type:        "reversal",
        Amount:      -txn.Amount,
        Reason:      "order_return",
        ReferenceID: orderID,
        CreatedAt:   time.Now(),
    }
    
    balance := uc.getPointsBalance(txn.CustomerID)
    newBalance := max(0, balance - txn.Amount)  // Don't go negative
    reversalTxn.Balance = newBalance
    
    uc.repo.CreateTransaction(ctx, reversalTxn)
    uc.repo.UpdateBalance(ctx, txn.CustomerID, newBalance)
    
    return nil
}

// Cron job to expire points
func (uc *LoyaltyUseCase) ExpirePoints(ctx context.Context) {
    expiredTxns, _ := uc.repo.GetExpiredTransactions(ctx)
    
    for _, txn := range expiredTxns {
        balance := uc.getPointsBalance(txn.CustomerID)
        newBalance := balance - txn.Amount
        
        // Create expiration transaction
        expirationTxn := &PointsTransaction{
            ID:          uuid.New().String(),
            CustomerID:  txn.CustomerID,
            Type:        "expire",
            Amount:      -txn.Amount,
            Reason:      "points_expired",
            ReferenceID: txn.ID,
            CreatedAt:   time.Now(),
        }
        
        uc.repo.CreateTransaction(ctx, expirationTxn)
        uc.repo.UpdateBalance(ctx, txn.CustomerID, newBalance)
        
        // Notify customer
        uc.notifyPointsExpired(ctx, txn.CustomerID, txn.Amount)
    }
}
```

---

## 📊 Success Criteria

- [ ] ✅ Program enrollment rate >40%
- [ ] ✅ Points redemption rate >20%
- [ ] ✅ Referral conversion rate >10%
- [ ] ✅ Tier distribution balanced
- [ ] ✅ Points liability managed

---

**Status:** Ready for Implementation
