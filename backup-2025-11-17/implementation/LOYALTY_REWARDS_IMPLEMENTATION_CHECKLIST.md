# 📋 LOYALTY-REWARDS SERVICE IMPLEMENTATION CHECKLIST

**Service**: Loyalty & Rewards Management Service  
**Current Status**: 20% (Basic structure + migrations)  
**Target**: Production-ready loyalty program system  
**Estimated Time**: 5-6 weeks (200-240 hours)  
**Team Size**: 2-3 developers  
**Last Updated**: November 12, 2025

---

## 📊 OVERALL STATUS: 20% COMPLETE

### ✅ COMPLETED (20%)
- Basic project structure
- Database migrations (8 tables)
- Proto file definition (partial)
- README documentation
- Basic domain entities

### 🔴 MISSING (80%)
- Multi-domain structure (0%)
- Core business logic (10%)
- Repository layer (0%)
- Service layer (0%)
- Event integration (0%)
- Testing (0%)
- Monitoring (0%)

---

## 🎯 PHASE 1: REFACTOR TO MULTI-DOMAIN STRUCTURE (Week 1)

### 1.1. Restructure to Multi-Domain (Day 1-2 - 8 hours)

**Status**: ❌ Not Started (0%)

**Current Structure**:
```
internal/biz/
  ├── biz.go
  └── loyalty.go  (monolithic)
```

**Target Multi-Domain Structure** (like Catalog):
```
internal/
├── biz/
│   ├── account/              # NEW - Loyalty Account domain
│   │   ├── account.go
│   │   ├── dto.go
│   │   ├── errors.go
│   │   └── provider.go
│   ├── tier/                 # NEW - Tier Management domain
│   │   ├── tier.go
│   │   ├── dto.go
│   │   ├── errors.go
│   │   └── provider.go
│   ├── transaction/          # NEW - Points Transaction domain
│   │   ├── transaction.go
│   │   ├── dto.go
│   │   ├── errors.go
│   │   └── provider.go
│   ├── reward/               # NEW - Rewards Catalog domain
│   │   ├── reward.go
│   │   ├── dto.go
│   │   ├── errors.go
│   │   └── provider.go
│   ├── redemption/           # NEW - Redemption domain
│   │   ├── redemption.go
│   │   ├── dto.go
│   │   ├── errors.go
│   │   └── provider.go
│   ├── referral/             # NEW - Referral Program domain
│   │   ├── referral.go
│   │   ├── dto.go
│   │   ├── errors.go
│   │   └── provider.go
│   ├── campaign/             # NEW - Bonus Campaign domain
│   │   ├── campaign.go
│   │   ├── dto.go
│   │   ├── errors.go
│   │   └── provider.go
│   ├── events/               # NEW - Event publishing
│   │   ├── publisher.go
│   │   └── events.go
│   └── biz.go
├── repository/               # NEW - Repository layer
│   ├── account/
│   │   ├── account.go
│   │   └── provider.go
│   ├── tier/
│   │   ├── tier.go
│   │   └── provider.go
│   ├── transaction/
│   │   ├── transaction.go
│   │   └── provider.go
│   ├── reward/
│   │   ├── reward.go
│   │   └── provider.go
│   ├── redemption/
│   │   ├── redemption.go
│   │   └── provider.go
│   ├── referral/
│   │   ├── referral.go
│   │   └── provider.go
│   └── campaign/
│       ├── campaign.go
│       └── provider.go
├── client/                   # NEW - External service clients
│   ├── order_client.go
│   ├── customer_client.go
│   └── notification_client.go
├── cache/                    # NEW - Cache service
│   └── cache.go
├── model/                    # NEW - Database models
│   ├── loyalty_account.go
│   ├── loyalty_tier.go
│   ├── loyalty_transaction.go
│   ├── loyalty_reward.go
│   ├── loyalty_redemption.go
│   ├── referral_program.go
│   └── bonus_campaign.go
├── constants/                # NEW - Constants
│   └── constants.go
└── observability/            # NEW - Metrics & tracing
    ├── metrics.go
    └── tracing.go
```

**Tasks**:
- [ ] Create multi-domain directory structure
- [ ] Split monolithic loyalty.go into domains
- [ ] Create repository layer
- [ ] Create client layer
- [ ] Create cache layer
- [ ] Update wire providers

**Estimated Effort**: 8 hours



### 1.2. Account Domain Implementation (Day 2-3 - 10 hours)

**Status**: 🟡 Partial (10%)

**Domain Responsibilities**:
- Manage loyalty accounts
- Track points balance
- Handle tier progression
- Generate referral codes

**Files to Create/Update**:

**`internal/biz/account/account.go`**:
```go
package account

import (
    "context"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/events"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    repoAccount "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/account"
    repoTier "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/tier"
)

// AccountRepo interface - use from repository package
type AccountRepo = repoAccount.AccountRepo

// TierRepo interface - use from repository package
type TierRepo = repoTier.TierRepo

// AccountUsecase handles loyalty account business logic
type AccountUsecase struct {
    repo           AccountRepo
    tierRepo       TierRepo
    eventPublisher events.EventPublisher
    log            *log.Helper
}

func NewAccountUsecase(
    repo AccountRepo,
    tierRepo TierRepo,
    eventPublisher events.EventPublisher,
    logger log.Logger,
) *AccountUsecase {
    return &AccountUsecase{
        repo:           repo,
        tierRepo:       tierRepo,
        eventPublisher: eventPublisher,
        log:            log.NewHelper(logger),
    }
}

func (uc *AccountUsecase) CreateAccount(ctx context.Context, customerID string, referredBy string) (*model.LoyaltyAccount, error) {
    // 1. Check if account exists
    existing, _ := uc.repo.GetByCustomerID(ctx, customerID)
    if existing != nil {
        return nil, ErrAccountAlreadyExists
    }
    
    // 2. Generate referral code
    referralCode := uc.generateReferralCode(customerID)
    
    // 3. Get default tier
    defaultTier, err := uc.tierRepo.GetDefaultTier(ctx)
    if err != nil {
        return nil, err
    }
    
    // 4. Create account
    account := &model.LoyaltyAccount{
        CustomerID:   customerID,
        CurrentPoints: 0,
        LifetimePoints: 0,
        CurrentTier:  defaultTier.Name,
        ReferralCode: referralCode,
        ReferredBy:   referredBy,
        Status:       "active",
        CreatedAt:    time.Now(),
        UpdatedAt:    time.Now(),
    }
    
    if err := uc.repo.Create(ctx, account); err != nil {
        return nil, err
    }
    
    // 5. Award referral bonus if applicable
    if referredBy != "" {
        go uc.awardReferralBonus(context.Background(), referredBy)
    }
    
    // 6. Publish event
    uc.publishAccountCreated(ctx, account)
    
    return account, nil
}

func (uc *AccountUsecase) GetAccount(ctx context.Context, customerID string) (*model.LoyaltyAccount, error) {
    account, err := uc.repo.GetByCustomerID(ctx, customerID)
    if err != nil {
        return nil, err
    }
    
    // Calculate tier progress
    uc.calculateTierProgress(ctx, account)
    
    return account, nil
}

func (uc *AccountUsecase) calculateTierProgress(ctx context.Context, account *model.LoyaltyAccount) {
    // Get current tier
    currentTier, err := uc.tierRepo.GetByName(ctx, account.CurrentTier)
    if err != nil {
        return
    }
    
    // Get next tier
    nextTier, err := uc.tierRepo.GetNextTier(ctx, currentTier.MinPoints)
    if err != nil || nextTier == nil {
        account.NextTier = ""
        account.PointsToNextTier = 0
        return
    }
    
    account.NextTier = nextTier.Name
    account.PointsToNextTier = nextTier.MinPoints - account.LifetimePoints
    account.TierProgress = int32(float64(account.LifetimePoints-currentTier.MinPoints) / 
        float64(nextTier.MinPoints-currentTier.MinPoints) * 100)
}
```

**`internal/biz/account/dto.go`**:
```go
package account

type CreateAccountRequest struct {
    CustomerID string
    ReferredBy string
}

type GetAccountResponse struct {
    Account      *model.LoyaltyAccount
    TierBenefits []string
}

type UpdateAccountRequest struct {
    CustomerID string
    Status     string
}
```

**`internal/biz/account/errors.go`**:
```go
package account

import "errors"

var (
    ErrAccountAlreadyExists = errors.New("loyalty account already exists")
    ErrAccountNotFound      = errors.New("loyalty account not found")
    ErrAccountSuspended     = errors.New("loyalty account is suspended")
    ErrInsufficientPoints   = errors.New("insufficient points")
)
```

**Estimated Effort**: 10 hours



### 1.3. Transaction Domain Implementation (Day 3-4 - 10 hours)

**Status**: ❌ Not Started (0%)

**Domain Responsibilities**:
- Handle point earning
- Handle point redemption
- Track transaction history
- Apply earning rules

**`internal/biz/transaction/transaction.go`**:
```go
package transaction

import (
    "context"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/events"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    repoAccount "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/account"
    repoTransaction "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/transaction"
    repoTier "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/tier"
)

type TransactionUsecase struct {
    repo         repoTransaction.TransactionRepo
    accountRepo  repoAccount.AccountRepo
    tierRepo     repoTier.TierRepo
    eventPublisher events.EventPublisher
    log          *log.Helper
}

func (uc *TransactionUsecase) EarnPoints(ctx context.Context, req *EarnPointsRequest) (*model.LoyaltyTransaction, error) {
    // 1. Get account
    account, err := uc.accountRepo.GetByCustomerID(ctx, req.CustomerID)
    if err != nil {
        return nil, err
    }
    
    if account.Status != "active" {
        return nil, ErrAccountNotActive
    }
    
    // 2. Calculate points with tier multiplier
    points := uc.calculatePoints(ctx, account, req)
    
    // 3. Create transaction
    tx := &model.LoyaltyTransaction{
        CustomerID:      req.CustomerID,
        TransactionType: "earn",
        Points:          points,
        BalanceBefore:   account.CurrentPoints,
        BalanceAfter:    account.CurrentPoints + points,
        Source:          req.Source,
        SourceID:        req.SourceID,
        Description:     req.Description,
        ExpiresAt:       uc.calculateExpiration(time.Now()),
        CreatedAt:       time.Now(),
    }
    
    if err := uc.repo.Create(ctx, tx); err != nil {
        return nil, err
    }
    
    // 4. Update account balance
    account.CurrentPoints += points
    account.LifetimePoints += points
    
    if err := uc.accountRepo.Update(ctx, account); err != nil {
        return nil, err
    }
    
    // 5. Check tier upgrade
    uc.checkTierUpgrade(ctx, account)
    
    // 6. Publish event
    uc.publishPointsEarned(ctx, tx)
    
    return tx, nil
}

func (uc *TransactionUsecase) RedeemPoints(ctx context.Context, req *RedeemPointsRequest) (*model.LoyaltyTransaction, error) {
    // 1. Get account
    account, err := uc.accountRepo.GetByCustomerID(ctx, req.CustomerID)
    if err != nil {
        return nil, err
    }
    
    // 2. Check balance
    if account.CurrentPoints < req.Points {
        return nil, ErrInsufficientPoints
    }
    
    // 3. Create transaction
    tx := &model.LoyaltyTransaction{
        CustomerID:      req.CustomerID,
        TransactionType: "redeem",
        Points:          -req.Points,
        BalanceBefore:   account.CurrentPoints,
        BalanceAfter:    account.CurrentPoints - req.Points,
        Source:          req.Source,
        SourceID:        req.SourceID,
        Description:     req.Description,
        CreatedAt:       time.Now(),
    }
    
    if err := uc.repo.Create(ctx, tx); err != nil {
        return nil, err
    }
    
    // 4. Update account balance
    account.CurrentPoints -= req.Points
    
    if err := uc.accountRepo.Update(ctx, account); err != nil {
        return nil, err
    }
    
    // 5. Publish event
    uc.publishPointsRedeemed(ctx, tx)
    
    return tx, nil
}

func (uc *TransactionUsecase) calculatePoints(ctx context.Context, account *model.LoyaltyAccount, req *EarnPointsRequest) int32 {
    basePoints := req.BasePoints
    
    // Apply tier multiplier
    tier, err := uc.tierRepo.GetByName(ctx, account.CurrentTier)
    if err == nil {
        multiplier := tier.PointMultiplier.InexactFloat64()
        basePoints = int32(float64(basePoints) * multiplier)
    }
    
    // Apply campaign bonus if applicable
    // TODO: Check active campaigns
    
    return basePoints
}

func (uc *TransactionUsecase) checkTierUpgrade(ctx context.Context, account *model.LoyaltyAccount) {
    // Get next tier
    currentTier, err := uc.tierRepo.GetByName(ctx, account.CurrentTier)
    if err != nil {
        return
    }
    
    nextTier, err := uc.tierRepo.GetNextTier(ctx, currentTier.MinPoints)
    if err != nil || nextTier == nil {
        return
    }
    
    // Check if eligible for upgrade
    if account.LifetimePoints >= nextTier.MinPoints {
        account.CurrentTier = nextTier.Name
        uc.accountRepo.Update(ctx, account)
        
        // Publish tier upgrade event
        uc.publishTierUpgraded(ctx, account, nextTier.Name)
    }
}
```

**`internal/biz/transaction/dto.go`**:
```go
package transaction

type EarnPointsRequest struct {
    CustomerID  string
    BasePoints  int32
    Source      string  // order, review, referral, etc.
    SourceID    string
    Description string
}

type RedeemPointsRequest struct {
    CustomerID  string
    Points      int32
    Source      string  // reward_redemption, discount, etc.
    SourceID    string
    Description string
}

type TransactionFilter struct {
    CustomerID      string
    TransactionType string
    Source          string
    StartDate       time.Time
    EndDate         time.Time
    Page            int
    PageSize        int
}
```

**Estimated Effort**: 10 hours

---

### 1.4. Repository Layer Implementation (Day 4-5 - 10 hours)

**Status**: ❌ Not Started (0%)

**`internal/repository/account/account.go`**:
```go
package account

import (
    "context"
    
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    "gorm.io/gorm"
)

type AccountRepo interface {
    Create(ctx context.Context, account *model.LoyaltyAccount) error
    Update(ctx context.Context, account *model.LoyaltyAccount) error
    GetByID(ctx context.Context, id string) (*model.LoyaltyAccount, error)
    GetByCustomerID(ctx context.Context, customerID string) (*model.LoyaltyAccount, error)
    GetByReferralCode(ctx context.Context, code string) (*model.LoyaltyAccount, error)
    List(ctx context.Context, filter *AccountFilter) ([]*model.LoyaltyAccount, int64, error)
}

type accountRepo struct {
    db *gorm.DB
}

func NewAccountRepo(db *gorm.DB) AccountRepo {
    return &accountRepo{db: db}
}

func (r *accountRepo) Create(ctx context.Context, account *model.LoyaltyAccount) error {
    return r.db.WithContext(ctx).Create(account).Error
}

func (r *accountRepo) Update(ctx context.Context, account *model.LoyaltyAccount) error {
    return r.db.WithContext(ctx).Save(account).Error
}

func (r *accountRepo) GetByCustomerID(ctx context.Context, customerID string) (*model.LoyaltyAccount, error) {
    var account model.LoyaltyAccount
    if err := r.db.WithContext(ctx).
        Where("customer_id = ?", customerID).
        First(&account).Error; err != nil {
        return nil, err
    }
    return &account, nil
}

func (r *accountRepo) List(ctx context.Context, filter *AccountFilter) ([]*model.LoyaltyAccount, int64, error) {
    var accounts []*model.LoyaltyAccount
    var total int64
    
    query := r.db.WithContext(ctx).Model(&model.LoyaltyAccount{})
    
    // Apply filters
    if filter.Tier != "" {
        query = query.Where("current_tier = ?", filter.Tier)
    }
    if filter.Status != "" {
        query = query.Where("status = ?", filter.Status)
    }
    
    // Count total
    query.Count(&total)
    
    // Apply pagination
    offset := (filter.Page - 1) * filter.PageSize
    query = query.Offset(offset).Limit(filter.PageSize)
    
    if err := query.Find(&accounts).Error; err != nil {
        return nil, 0, err
    }
    
    return accounts, total, nil
}
```

**`internal/repository/transaction/transaction.go`**:
```go
package transaction

import (
    "context"
    
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    "gorm.io/gorm"
)

type TransactionRepo interface {
    Create(ctx context.Context, tx *model.LoyaltyTransaction) error
    GetByID(ctx context.Context, id string) (*model.LoyaltyTransaction, error)
    List(ctx context.Context, filter *TransactionFilter) ([]*model.LoyaltyTransaction, int64, error)
    GetExpiredPoints(ctx context.Context, customerID string) (int32, error)
}

type transactionRepo struct {
    db *gorm.DB
}

func NewTransactionRepo(db *gorm.DB) TransactionRepo {
    return &transactionRepo{db: db}
}

func (r *transactionRepo) Create(ctx context.Context, tx *model.LoyaltyTransaction) error {
    return r.db.WithContext(ctx).Create(tx).Error
}

func (r *transactionRepo) List(ctx context.Context, filter *TransactionFilter) ([]*model.LoyaltyTransaction, int64, error) {
    var transactions []*model.LoyaltyTransaction
    var total int64
    
    query := r.db.WithContext(ctx).Model(&model.LoyaltyTransaction{})
    
    // Apply filters
    if filter.CustomerID != "" {
        query = query.Where("customer_id = ?", filter.CustomerID)
    }
    if filter.TransactionType != "" {
        query = query.Where("transaction_type = ?", filter.TransactionType)
    }
    if filter.Source != "" {
        query = query.Where("source = ?", filter.Source)
    }
    if !filter.StartDate.IsZero() {
        query = query.Where("created_at >= ?", filter.StartDate)
    }
    if !filter.EndDate.IsZero() {
        query = query.Where("created_at <= ?", filter.EndDate)
    }
    
    // Count total
    query.Count(&total)
    
    // Apply pagination and sorting
    offset := (filter.Page - 1) * filter.PageSize
    query = query.Order("created_at DESC").Offset(offset).Limit(filter.PageSize)
    
    if err := query.Find(&transactions).Error; err != nil {
        return nil, 0, err
    }
    
    return transactions, total, nil
}
```

**Estimated Effort**: 10 hours

**PHASE 1 TOTAL**: 38 hours (Week 1)



## 🎯 PHASE 2: REWARD & REDEMPTION DOMAINS (Week 2)

### 2.1. Reward Domain Implementation (Day 1-2 - 10 hours)

**Status**: ❌ Not Started (0%)

**Domain Responsibilities**:
- Manage rewards catalog
- Define reward types (discount, product, voucher)
- Track reward availability
- Handle reward expiration

**`internal/biz/reward/reward.go`**:
```go
package reward

import (
    "context"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    repoReward "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/reward"
)

type RewardUsecase struct {
    repo repoReward.RewardRepo
    log  *log.Helper
}

func (uc *RewardUsecase) CreateReward(ctx context.Context, req *CreateRewardRequest) (*model.LoyaltyReward, error) {
    reward := &model.LoyaltyReward{
        Name:             req.Name,
        Description:      req.Description,
        RewardType:       req.RewardType,
        PointsCost:       req.PointsCost,
        Value:            req.Value,
        Stock:            req.Stock,
        MaxRedemptions:   req.MaxRedemptions,
        ValidFrom:        req.ValidFrom,
        ValidUntil:       req.ValidUntil,
        RequiredTier:     req.RequiredTier,
        IsActive:         true,
        CreatedAt:        time.Now(),
    }
    
    if err := uc.repo.Create(ctx, reward); err != nil {
        return nil, err
    }
    
    return reward, nil
}

func (uc *RewardUsecase) ListAvailableRewards(ctx context.Context, customerID string, tier string) ([]*model.LoyaltyReward, error) {
    return uc.repo.ListAvailable(ctx, tier, time.Now())
}

func (uc *RewardUsecase) GetReward(ctx context.Context, id string) (*model.LoyaltyReward, error) {
    return uc.repo.GetByID(ctx, id)
}
```

**Estimated Effort**: 10 hours

---

### 2.2. Redemption Domain Implementation (Day 2-3 - 10 hours)

**Status**: ❌ Not Started (0%)

**Domain Responsibilities**:
- Handle reward redemption
- Validate redemption eligibility
- Track redemption history
- Generate redemption codes

**`internal/biz/redemption/redemption.go`**:
```go
package redemption

import (
    "context"
    "fmt"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/events"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    repoAccount "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/account"
    repoRedemption "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/redemption"
    repoReward "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/reward"
    repoTransaction "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/transaction"
)

type RedemptionUsecase struct {
    repo            repoRedemption.RedemptionRepo
    rewardRepo      repoReward.RewardRepo
    accountRepo     repoAccount.AccountRepo
    transactionRepo repoTransaction.TransactionRepo
    eventPublisher  events.EventPublisher
    log             *log.Helper
}

func (uc *RedemptionUsecase) RedeemReward(ctx context.Context, req *RedeemRewardRequest) (*model.LoyaltyRedemption, error) {
    // 1. Get reward
    reward, err := uc.rewardRepo.GetByID(ctx, req.RewardID)
    if err != nil {
        return nil, err
    }
    
    // 2. Validate reward availability
    if err := uc.validateReward(ctx, reward); err != nil {
        return nil, err
    }
    
    // 3. Get account
    account, err := uc.accountRepo.GetByCustomerID(ctx, req.CustomerID)
    if err != nil {
        return nil, err
    }
    
    // 4. Validate eligibility
    if err := uc.validateEligibility(ctx, account, reward); err != nil {
        return nil, err
    }
    
    // 5. Check points balance
    if account.CurrentPoints < reward.PointsCost {
        return nil, ErrInsufficientPoints
    }
    
    // 6. Create redemption
    redemption := &model.LoyaltyRedemption{
        CustomerID:     req.CustomerID,
        RewardID:       req.RewardID,
        PointsSpent:    reward.PointsCost,
        RedemptionCode: uc.generateRedemptionCode(),
        Status:         "pending",
        ExpiresAt:      reward.ValidUntil,
        CreatedAt:      time.Now(),
    }
    
    if err := uc.repo.Create(ctx, redemption); err != nil {
        return nil, err
    }
    
    // 7. Deduct points (create transaction)
    _, err = uc.transactionRepo.Create(ctx, &model.LoyaltyTransaction{
        CustomerID:      req.CustomerID,
        TransactionType: "redeem",
        Points:          -reward.PointsCost,
        BalanceBefore:   account.CurrentPoints,
        BalanceAfter:    account.CurrentPoints - reward.PointsCost,
        Source:          "reward_redemption",
        SourceID:        redemption.ID,
        Description:     fmt.Sprintf("Redeemed: %s", reward.Name),
        CreatedAt:       time.Now(),
    })
    if err != nil {
        return nil, err
    }
    
    // 8. Update account balance
    account.CurrentPoints -= reward.PointsCost
    uc.accountRepo.Update(ctx, account)
    
    // 9. Update reward stock
    if reward.Stock > 0 {
        reward.Stock--
        uc.rewardRepo.Update(ctx, reward)
    }
    
    // 10. Publish event
    uc.publishRewardRedeemed(ctx, redemption)
    
    return redemption, nil
}

func (uc *RedemptionUsecase) validateReward(ctx context.Context, reward *model.LoyaltyReward) error {
    if !reward.IsActive {
        return ErrRewardNotActive
    }
    
    now := time.Now()
    if reward.ValidFrom.After(now) {
        return ErrRewardNotYetValid
    }
    
    if reward.ValidUntil.Before(now) {
        return ErrRewardExpired
    }
    
    if reward.Stock == 0 {
        return ErrRewardOutOfStock
    }
    
    return nil
}

func (uc *RedemptionUsecase) validateEligibility(ctx context.Context, account *model.LoyaltyAccount, reward *model.LoyaltyReward) error {
    // Check tier requirement
    if reward.RequiredTier != "" {
        // TODO: Compare tier levels
    }
    
    // Check max redemptions per customer
    if reward.MaxRedemptions > 0 {
        count, _ := uc.repo.CountByCustomerAndReward(ctx, account.CustomerID, reward.ID)
        if count >= int64(reward.MaxRedemptions) {
            return ErrMaxRedemptionsReached
        }
    }
    
    return nil
}

func (uc *RedemptionUsecase) generateRedemptionCode() string {
    // Generate unique code (e.g., RDM-XXXX-XXXX)
    return fmt.Sprintf("RDM-%s", generateRandomCode(8))
}
```

**Estimated Effort**: 10 hours

---

### 2.3. Tier Domain Implementation (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

**`internal/biz/tier/tier.go`**:
```go
package tier

import (
    "context"
    
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    repoTier "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/tier"
)

type TierUsecase struct {
    repo repoTier.TierRepo
    log  *log.Helper
}

func (uc *TierUsecase) CreateTier(ctx context.Context, req *CreateTierRequest) (*model.LoyaltyTier, error) {
    tier := &model.LoyaltyTier{
        Name:            req.Name,
        DisplayName:     req.DisplayName,
        MinPoints:       req.MinPoints,
        MaxPoints:       req.MaxPoints,
        PointMultiplier: req.PointMultiplier,
        Benefits:        req.Benefits,
        Color:           req.Color,
        IconURL:         req.IconURL,
        Description:     req.Description,
        IsActive:        true,
        SortOrder:       req.SortOrder,
    }
    
    return tier, uc.repo.Create(ctx, tier)
}

func (uc *TierUsecase) ListTiers(ctx context.Context) ([]*model.LoyaltyTier, error) {
    return uc.repo.ListActive(ctx)
}

func (uc *TierUsecase) GetTierBenefits(ctx context.Context, tierName string) ([]string, error) {
    tier, err := uc.repo.GetByName(ctx, tierName)
    if err != nil {
        return nil, err
    }
    
    // Parse benefits JSON
    var benefits []string
    // TODO: Parse tier.Benefits JSON string
    
    return benefits, nil
}
```

**Estimated Effort**: 8 hours

---

### 2.4. Model Layer (Day 4-5 - 6 hours)

**Status**: 🟡 Partial (50%)

**`internal/model/loyalty_account.go`**:
```go
package model

import "time"

type LoyaltyAccount struct {
    ID               string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    CustomerID       string    `gorm:"uniqueIndex;not null"`
    CurrentPoints    int32     `gorm:"default:0"`
    LifetimePoints   int32     `gorm:"default:0"`
    CurrentTier      string    `gorm:"default:'bronze'"`
    TierProgress     int32     `gorm:"default:0"`
    NextTier         string
    PointsToNextTier int32     `gorm:"default:0"`
    ReferralCode     string    `gorm:"uniqueIndex"`
    ReferredBy       string
    Status           string    `gorm:"default:'active'"`
    CreatedAt        time.Time
    UpdatedAt        time.Time
}

func (LoyaltyAccount) TableName() string {
    return "loyalty_accounts"
}
```

**Similar models for**:
- `loyalty_tier.go`
- `loyalty_transaction.go`
- `loyalty_reward.go`
- `loyalty_redemption.go`
- `referral_program.go`
- `bonus_campaign.go`

**Estimated Effort**: 6 hours

**PHASE 2 TOTAL**: 34 hours (Week 2)



## 🎯 PHASE 3: REFERRAL & CAMPAIGN DOMAINS (Week 3)

### 3.1. Referral Domain Implementation (Day 1-2 - 10 hours)

**Status**: ❌ Not Started (0%)

**Domain Responsibilities**:
- Manage referral programs
- Track referral conversions
- Award referral bonuses
- Generate referral links

**`internal/biz/referral/referral.go`**:
```go
package referral

import (
    "context"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/events"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    repoAccount "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/account"
    repoReferral "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/referral"
    repoTransaction "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/transaction"
)

type ReferralUsecase struct {
    repo            repoReferral.ReferralRepo
    accountRepo     repoAccount.AccountRepo
    transactionRepo repoTransaction.TransactionRepo
    eventPublisher  events.EventPublisher
    log             *log.Helper
}

func (uc *ReferralUsecase) TrackReferral(ctx context.Context, referrerCode string, refereeCustomerID string) error {
    // 1. Get referrer account
    referrer, err := uc.accountRepo.GetByReferralCode(ctx, referrerCode)
    if err != nil {
        return err
    }
    
    // 2. Get referee account
    referee, err := uc.accountRepo.GetByCustomerID(ctx, refereeCustomerID)
    if err != nil {
        return err
    }
    
    // 3. Create referral record
    referral := &model.ReferralProgram{
        ReferrerID:   referrer.CustomerID,
        RefereeID:    referee.CustomerID,
        Status:       "pending",
        ReferralCode: referrerCode,
        CreatedAt:    time.Now(),
    }
    
    return uc.repo.Create(ctx, referral)
}

func (uc *ReferralUsecase) CompleteReferral(ctx context.Context, refereeCustomerID string, orderID string) error {
    // 1. Get referral record
    referral, err := uc.repo.GetByReferee(ctx, refereeCustomerID)
    if err != nil {
        return err
    }
    
    if referral.Status != "pending" {
        return ErrReferralAlreadyCompleted
    }
    
    // 2. Get active referral program
    program, err := uc.repo.GetActiveProgram(ctx)
    if err != nil {
        return err
    }
    
    // 3. Award points to referrer
    _, err = uc.transactionRepo.Create(ctx, &model.LoyaltyTransaction{
        CustomerID:      referral.ReferrerID,
        TransactionType: "earn",
        Points:          program.ReferrerBonus,
        Source:          "referral",
        SourceID:        referral.ID,
        Description:     "Referral bonus",
        CreatedAt:       time.Now(),
    })
    if err != nil {
        return err
    }
    
    // 4. Award points to referee
    _, err = uc.transactionRepo.Create(ctx, &model.LoyaltyTransaction{
        CustomerID:      referral.RefereeID,
        TransactionType: "earn",
        Points:          program.RefereeBonus,
        Source:          "referral",
        SourceID:        referral.ID,
        Description:     "Welcome bonus",
        CreatedAt:       time.Now(),
    })
    if err != nil {
        return err
    }
    
    // 5. Update referral status
    referral.Status = "completed"
    referral.CompletedAt = time.Now()
    uc.repo.Update(ctx, referral)
    
    // 6. Update account balances
    uc.updateAccountBalances(ctx, referral, program)
    
    // 7. Publish event
    uc.publishReferralCompleted(ctx, referral)
    
    return nil
}

func (uc *ReferralUsecase) GetReferralStats(ctx context.Context, customerID string) (*ReferralStats, error) {
    total, _ := uc.repo.CountByReferrer(ctx, customerID)
    completed, _ := uc.repo.CountCompletedByReferrer(ctx, customerID)
    
    return &ReferralStats{
        TotalReferrals:     total,
        CompletedReferrals: completed,
        PendingReferrals:   total - completed,
    }, nil
}
```

**Estimated Effort**: 10 hours

---

### 3.2. Campaign Domain Implementation (Day 2-3 - 10 hours)

**Status**: ❌ Not Started (0%)

**Domain Responsibilities**:
- Manage bonus campaigns
- Apply point multipliers
- Track campaign performance
- Handle campaign expiration

**`internal/biz/campaign/campaign.go`**:
```go
package campaign

import (
    "context"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/model"
    repoCampaign "gitlab.com/ta-microservices/loyalty-rewards/internal/repository/campaign"
)

type CampaignUsecase struct {
    repo repoCampaign.CampaignRepo
    log  *log.Helper
}

func (uc *CampaignUsecase) CreateCampaign(ctx context.Context, req *CreateCampaignRequest) (*model.BonusCampaign, error) {
    campaign := &model.BonusCampaign{
        Name:            req.Name,
        Description:     req.Description,
        CampaignType:    req.CampaignType,
        BonusMultiplier: req.BonusMultiplier,
        BonusPoints:     req.BonusPoints,
        MinPurchase:     req.MinPurchase,
        TargetTier:      req.TargetTier,
        StartDate:       req.StartDate,
        EndDate:         req.EndDate,
        IsActive:        true,
        CreatedAt:       time.Now(),
    }
    
    return campaign, uc.repo.Create(ctx, campaign)
}

func (uc *CampaignUsecase) GetActiveCampaigns(ctx context.Context, tier string) ([]*model.BonusCampaign, error) {
    now := time.Now()
    return uc.repo.ListActive(ctx, tier, now)
}

func (uc *CampaignUsecase) ApplyCampaignBonus(ctx context.Context, customerTier string, basePoints int32) int32 {
    campaigns, err := uc.GetActiveCampaigns(ctx, customerTier)
    if err != nil || len(campaigns) == 0 {
        return basePoints
    }
    
    // Apply highest multiplier
    maxMultiplier := 1.0
    for _, campaign := range campaigns {
        if campaign.BonusMultiplier.InexactFloat64() > maxMultiplier {
            maxMultiplier = campaign.BonusMultiplier.InexactFloat64()
        }
    }
    
    return int32(float64(basePoints) * maxMultiplier)
}
```

**Estimated Effort**: 10 hours

---

### 3.3. Event Publishing Layer (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

**`internal/biz/events/publisher.go`**:
```go
package events

import (
    "context"
    "encoding/json"
    
    "github.com/go-kratos/kratos/v2/log"
    commonEvents "gitlab.com/ta-microservices/common/events"
)

type EventPublisher interface {
    PublishAccountCreated(ctx context.Context, event *AccountCreatedEvent) error
    PublishPointsEarned(ctx context.Context, event *PointsEarnedEvent) error
    PublishPointsRedeemed(ctx context.Context, event *PointsRedeemedEvent) error
    PublishTierUpgraded(ctx context.Context, event *TierUpgradedEvent) error
    PublishRewardRedeemed(ctx context.Context, event *RewardRedeemedEvent) error
    PublishReferralCompleted(ctx context.Context, event *ReferralCompletedEvent) error
}

type eventPublisher struct {
    helper *commonEvents.EventHelper
    log    *log.Helper
}

func NewEventPublisher(helper *commonEvents.EventHelper, logger log.Logger) EventPublisher {
    return &eventPublisher{
        helper: helper,
        log:    log.NewHelper(logger),
    }
}

func (p *eventPublisher) PublishPointsEarned(ctx context.Context, event *PointsEarnedEvent) error {
    data, _ := json.Marshal(event)
    return p.helper.PublishEvent(ctx, "loyalty.points.earned", data)
}

func (p *eventPublisher) PublishTierUpgraded(ctx context.Context, event *TierUpgradedEvent) error {
    data, _ := json.Marshal(event)
    return p.helper.PublishEvent(ctx, "loyalty.tier.upgraded", data)
}
```

**`internal/biz/events/events.go`**:
```go
package events

import "time"

type AccountCreatedEvent struct {
    CustomerID   string    `json:"customer_id"`
    ReferralCode string    `json:"referral_code"`
    Tier         string    `json:"tier"`
    CreatedAt    time.Time `json:"created_at"`
}

type PointsEarnedEvent struct {
    CustomerID  string    `json:"customer_id"`
    Points      int32     `json:"points"`
    Source      string    `json:"source"`
    SourceID    string    `json:"source_id"`
    NewBalance  int32     `json:"new_balance"`
    CreatedAt   time.Time `json:"created_at"`
}

type TierUpgradedEvent struct {
    CustomerID string    `json:"customer_id"`
    OldTier    string    `json:"old_tier"`
    NewTier    string    `json:"new_tier"`
    UpgradedAt time.Time `json:"upgraded_at"`
}

type RewardRedeemedEvent struct {
    CustomerID     string    `json:"customer_id"`
    RewardID       string    `json:"reward_id"`
    RewardName     string    `json:"reward_name"`
    PointsSpent    int32     `json:"points_spent"`
    RedemptionCode string    `json:"redemption_code"`
    RedeemedAt     time.Time `json:"redeemed_at"`
}
```

**Estimated Effort**: 8 hours

---

### 3.4. Client Layer (Day 4-5 - 8 hours)

**Status**: ❌ Not Started (0%)

**`internal/client/order_client.go`**:
```go
package client

import (
    "context"
    
    "github.com/go-kratos/kratos/v2/log"
    "google.golang.org/grpc"
)

type OrderClient interface {
    GetOrder(ctx context.Context, orderID string) (*Order, error)
    GetOrdersByCustomer(ctx context.Context, customerID string) ([]*Order, error)
}

type orderClient struct {
    conn *grpc.ClientConn
    log  *log.Helper
}

func NewOrderClient(consulAddr string, logger log.Logger) (OrderClient, error) {
    // Service discovery via Consul
    conn, err := grpc.Dial("consul://"+consulAddr+"/order-service", 
        grpc.WithInsecure())
    if err != nil {
        return nil, err
    }
    
    return &orderClient{
        conn: conn,
        log:  log.NewHelper(logger),
    }, nil
}
```

**Similar clients**:
- `customer_client.go`
- `notification_client.go`

**Estimated Effort**: 8 hours

**PHASE 3 TOTAL**: 36 hours (Week 3)



## 🎯 PHASE 4: SERVICE LAYER & INTEGRATION (Week 4)

### 4.1. gRPC Service Implementation (Day 1-2 - 12 hours)

**Status**: ❌ Not Started (0%)

**`internal/service/account_service.go`**:
```go
package service

import (
    "context"
    
    pb "gitlab.com/ta-microservices/loyalty-rewards/api/loyalty/v1"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/account"
    
    "github.com/go-kratos/kratos/v2/log"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

type AccountService struct {
    pb.UnimplementedAccountServiceServer
    
    accountUC *account.AccountUsecase
    log       *log.Helper
}

func NewAccountService(accountUC *account.AccountUsecase, logger log.Logger) *AccountService {
    return &AccountService{
        accountUC: accountUC,
        log:       log.NewHelper(logger),
    }
}

func (s *AccountService) CreateAccount(ctx context.Context, req *pb.CreateAccountRequest) (*pb.CreateAccountResponse, error) {
    account, err := s.accountUC.CreateAccount(ctx, req.CustomerId, req.ReferredBy)
    if err != nil {
        return nil, status.Error(codes.Internal, err.Error())
    }
    
    return &pb.CreateAccountResponse{
        Account: s.transformAccount(account),
    }, nil
}

func (s *AccountService) GetAccount(ctx context.Context, req *pb.GetAccountRequest) (*pb.GetAccountResponse, error) {
    account, err := s.accountUC.GetAccount(ctx, req.CustomerId)
    if err != nil {
        return nil, status.Error(codes.NotFound, err.Error())
    }
    
    return &pb.GetAccountResponse{
        Account: s.transformAccount(account),
    }, nil
}
```

**`internal/service/transaction_service.go`**:
```go
package service

import (
    "context"
    
    pb "gitlab.com/ta-microservices/loyalty-rewards/api/loyalty/v1"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/transaction"
    
    "github.com/go-kratos/kratos/v2/log"
)

type TransactionService struct {
    pb.UnimplementedTransactionServiceServer
    
    transactionUC *transaction.TransactionUsecase
    log           *log.Helper
}

func (s *TransactionService) EarnPoints(ctx context.Context, req *pb.EarnPointsRequest) (*pb.EarnPointsResponse, error) {
    tx, err := s.transactionUC.EarnPoints(ctx, &transaction.EarnPointsRequest{
        CustomerID:  req.CustomerId,
        BasePoints:  req.Points,
        Source:      req.Source,
        SourceID:    req.SourceId,
        Description: req.Description,
    })
    if err != nil {
        return nil, err
    }
    
    return &pb.EarnPointsResponse{
        Transaction: s.transformTransaction(tx),
    }, nil
}

func (s *TransactionService) RedeemPoints(ctx context.Context, req *pb.RedeemPointsRequest) (*pb.RedeemPointsResponse, error) {
    tx, err := s.transactionUC.RedeemPoints(ctx, &transaction.RedeemPointsRequest{
        CustomerID:  req.CustomerId,
        Points:      req.Points,
        Source:      req.Source,
        SourceID:    req.SourceId,
        Description: req.Description,
    })
    if err != nil {
        return nil, err
    }
    
    return &pb.RedeemPointsResponse{
        Transaction: s.transformTransaction(tx),
    }, nil
}
```

**Similar services**:
- `reward_service.go`
- `redemption_service.go`
- `referral_service.go`
- `campaign_service.go`

**Estimated Effort**: 12 hours

---

### 4.2. HTTP API Implementation (Day 2-3 - 8 hours)

**Status**: ❌ Not Started (0%)

**`internal/server/http.go`**:
```go
package server

import (
    "github.com/gin-gonic/gin"
    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/account"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/transaction"
)

type HTTPServer struct {
    accountUC     *account.AccountUsecase
    transactionUC *transaction.TransactionUsecase
    log           *log.Helper
}

func (s *HTTPServer) RegisterRoutes(r *gin.Engine) {
    v1 := r.Group("/api/v1")
    {
        // Public endpoints
        v1.GET("/loyalty/tiers", s.ListTiers)
        v1.GET("/loyalty/rewards", s.ListRewards)
        
        // Authenticated endpoints
        auth := v1.Group("", s.AuthMiddleware())
        {
            // Account
            auth.GET("/loyalty/account", s.GetMyAccount)
            auth.GET("/loyalty/transactions", s.GetMyTransactions)
            
            // Rewards
            auth.POST("/loyalty/rewards/:id/redeem", s.RedeemReward)
            auth.GET("/loyalty/redemptions", s.GetMyRedemptions)
            
            // Referral
            auth.GET("/loyalty/referral/stats", s.GetReferralStats)
        }
        
        // Admin endpoints
        admin := v1.Group("/admin", s.AdminMiddleware())
        {
            admin.POST("/loyalty/tiers", s.CreateTier)
            admin.POST("/loyalty/rewards", s.CreateReward)
            admin.POST("/loyalty/campaigns", s.CreateCampaign)
            admin.GET("/loyalty/analytics", s.GetAnalytics)
        }
    }
}

func (s *HTTPServer) GetMyAccount(c *gin.Context) {
    customerID := c.GetString("customer_id")
    
    account, err := s.accountUC.GetAccount(c.Request.Context(), customerID)
    if err != nil {
        c.JSON(404, gin.H{"error": err.Error()})
        return
    }
    
    c.JSON(200, gin.H{"account": account})
}
```

**Estimated Effort**: 8 hours

---

### 4.3. Order Service Integration (Day 3-4 - 8 hours)

**Status**: ❌ Not Started (0%)

**Event Handlers**:
```go
// internal/service/event_handler.go
type EventHandler struct {
    transactionUC *transaction.TransactionUsecase
    referralUC    *referral.ReferralUsecase
    log           *log.Helper
}

func (h *EventHandler) HandleOrderCompleted(ctx context.Context, event *OrderCompletedEvent) error {
    // 1. Calculate points based on order amount
    points := h.calculatePointsFromOrder(event.TotalAmount)
    
    // 2. Award points to customer
    _, err := h.transactionUC.EarnPoints(ctx, &transaction.EarnPointsRequest{
        CustomerID:  event.CustomerID,
        BasePoints:  points,
        Source:      "order",
        SourceID:    event.OrderID,
        Description: fmt.Sprintf("Purchase: Order #%s", event.OrderID),
    })
    if err != nil {
        return err
    }
    
    // 3. Check if this is first order (complete referral)
    h.referralUC.CompleteReferral(ctx, event.CustomerID, event.OrderID)
    
    return nil
}

func (h *EventHandler) calculatePointsFromOrder(amount float64) int32 {
    // 1 point per $1 spent
    return int32(amount)
}
```

**Estimated Effort**: 8 hours

---

### 4.4. Cache Layer Implementation (Day 4 - 6 hours)

**Status**: ❌ Not Started (0%)

**`internal/cache/cache.go`**:
```go
package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"
    
    "github.com/redis/go-redis/v9"
)

type CacheService struct {
    redis *redis.Client
}

func NewCacheService(redis *redis.Client) *CacheService {
    return &CacheService{redis: redis}
}

func (c *CacheService) GetAccount(ctx context.Context, customerID string) (*model.LoyaltyAccount, error) {
    key := fmt.Sprintf("loyalty:account:%s", customerID)
    data, err := c.redis.Get(ctx, key).Bytes()
    if err != nil {
        return nil, err
    }
    
    var account model.LoyaltyAccount
    if err := json.Unmarshal(data, &account); err != nil {
        return nil, err
    }
    
    return &account, nil
}

func (c *CacheService) SetAccount(ctx context.Context, account *model.LoyaltyAccount, ttl time.Duration) error {
    key := fmt.Sprintf("loyalty:account:%s", account.CustomerID)
    data, _ := json.Marshal(account)
    return c.redis.Set(ctx, key, data, ttl).Err()
}

func (c *CacheService) InvalidateAccount(ctx context.Context, customerID string) error {
    key := fmt.Sprintf("loyalty:account:%s", customerID)
    return c.redis.Del(ctx, key).Err()
}
```

**Estimated Effort**: 6 hours

---

### 4.5. Wire DI Setup (Day 5 - 4 hours)

**Status**: ❌ Not Started (0%)

**`cmd/loyalty-rewards/wire.go`**:
```go
//go:build wireinject
// +build wireinject

package main

import (
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/account"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/campaign"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/events"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/redemption"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/referral"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/reward"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/tier"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/biz/transaction"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/cache"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/client"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/conf"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/repository"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/server"
    "gitlab.com/ta-microservices/loyalty-rewards/internal/service"
    
    "github.com/go-kratos/kratos/v2"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/google/wire"
)

func wireApp(*conf.Server, *conf.Data, log.Logger) (*kratos.App, func(), error) {
    panic(wire.Build(
        // Repository layer
        repository.ProviderSet,
        
        // Business logic layer
        account.ProviderSet,
        transaction.ProviderSet,
        tier.ProviderSet,
        reward.ProviderSet,
        redemption.ProviderSet,
        referral.ProviderSet,
        campaign.ProviderSet,
        events.ProviderSet,
        
        // Client layer
        client.ProviderSet,
        
        // Cache layer
        cache.ProviderSet,
        
        // Service layer
        service.ProviderSet,
        
        // Server layer
        server.ProviderSet,
        
        newApp,
    ))
}
```

**Estimated Effort**: 4 hours

**PHASE 4 TOTAL**: 38 hours (Week 4)



## 🎯 PHASE 5: TESTING & QUALITY (Week 5)

### 5.1. Unit Tests (Day 1-2 - 12 hours)

**Status**: ❌ Not Started (0%)

**Test Files to Create**:
```
internal/biz/account/account_test.go
internal/biz/transaction/transaction_test.go
internal/biz/reward/reward_test.go
internal/biz/redemption/redemption_test.go
internal/biz/referral/referral_test.go
internal/biz/campaign/campaign_test.go
internal/repository/account/account_test.go
internal/repository/transaction/transaction_test.go
internal/service/account_service_test.go
internal/service/transaction_service_test.go
```

**Example Test**:
```go
// internal/biz/transaction/transaction_test.go
func TestEarnPoints(t *testing.T) {
    // Setup
    mockAccountRepo := &MockAccountRepo{}
    mockTransactionRepo := &MockTransactionRepo{}
    mockTierRepo := &MockTierRepo{}
    
    uc := NewTransactionUsecase(mockTransactionRepo, mockAccountRepo, mockTierRepo, nil, nil)
    
    // Mock data
    account := &model.LoyaltyAccount{
        CustomerID:     "customer-1",
        CurrentPoints:  100,
        LifetimePoints: 100,
        CurrentTier:    "silver",
        Status:         "active",
    }
    
    tier := &model.LoyaltyTier{
        Name:            "silver",
        PointMultiplier: decimal.NewFromFloat(1.5),
    }
    
    mockAccountRepo.On("GetByCustomerID", mock.Anything, "customer-1").Return(account, nil)
    mockTierRepo.On("GetByName", mock.Anything, "silver").Return(tier, nil)
    mockTransactionRepo.On("Create", mock.Anything, mock.Anything).Return(nil)
    mockAccountRepo.On("Update", mock.Anything, mock.Anything).Return(nil)
    
    // Execute
    tx, err := uc.EarnPoints(context.Background(), &EarnPointsRequest{
        CustomerID:  "customer-1",
        BasePoints:  100,
        Source:      "order",
        SourceID:    "order-1",
        Description: "Purchase",
    })
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, tx)
    assert.Equal(t, int32(150), tx.Points) // 100 * 1.5 multiplier
    assert.Equal(t, int32(100), tx.BalanceBefore)
    assert.Equal(t, int32(250), tx.BalanceAfter)
    
    mockAccountRepo.AssertExpectations(t)
    mockTransactionRepo.AssertExpectations(t)
}

func TestRedeemPoints_InsufficientBalance(t *testing.T) {
    // Test insufficient points scenario
    mockAccountRepo := &MockAccountRepo{}
    uc := NewTransactionUsecase(nil, mockAccountRepo, nil, nil, nil)
    
    account := &model.LoyaltyAccount{
        CustomerID:    "customer-1",
        CurrentPoints: 50,
    }
    
    mockAccountRepo.On("GetByCustomerID", mock.Anything, "customer-1").Return(account, nil)
    
    _, err := uc.RedeemPoints(context.Background(), &RedeemPointsRequest{
        CustomerID: "customer-1",
        Points:     100,
    })
    
    assert.Error(t, err)
    assert.Equal(t, ErrInsufficientPoints, err)
}
```

**Estimated Effort**: 12 hours

---

### 5.2. Integration Tests (Day 2-3 - 10 hours)

**Status**: ❌ Not Started (0%)

**Integration Test**:
```go
func TestLoyaltyFlowIntegration(t *testing.T) {
    // Setup test database
    db := setupTestDB(t)
    defer cleanupTestDB(t, db)
    
    customerID := "test-customer-1"
    
    // 1. Create account
    account, err := createAccount(t, db, customerID, "")
    assert.NoError(t, err)
    assert.Equal(t, int32(0), account.CurrentPoints)
    assert.Equal(t, "bronze", account.CurrentTier)
    
    // 2. Earn points
    tx, err := earnPoints(t, db, customerID, 500, "order", "order-1")
    assert.NoError(t, err)
    assert.Equal(t, int32(500), tx.Points)
    
    // 3. Check account updated
    account, _ = getAccount(t, db, customerID)
    assert.Equal(t, int32(500), account.CurrentPoints)
    
    // 4. Earn more points to trigger tier upgrade
    earnPoints(t, db, customerID, 500, "order", "order-2")
    
    account, _ = getAccount(t, db, customerID)
    assert.Equal(t, int32(1000), account.CurrentPoints)
    assert.Equal(t, "silver", account.CurrentTier) // Upgraded
    
    // 5. Redeem reward
    reward := createReward(t, db, "Test Reward", 300)
    redemption, err := redeemReward(t, db, customerID, reward.ID)
    assert.NoError(t, err)
    
    // 6. Check points deducted
    account, _ = getAccount(t, db, customerID)
    assert.Equal(t, int32(700), account.CurrentPoints)
}
```

**Estimated Effort**: 10 hours

---

### 5.3. Performance Testing (Day 3-4 - 6 hours)

**Status**: ❌ Not Started (0%)

**Load Test**:
```bash
# Using k6
k6 run - <<EOF
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  // Test get account
  let res = http.get('http://localhost:8008/api/v1/loyalty/account', {
    headers: { 'Authorization': 'Bearer test-token' },
  });
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
}
EOF
```

**Estimated Effort**: 6 hours

---

### 5.4. Security Testing (Day 4 - 4 hours)

**Status**: ❌ Not Started (0%)

- [ ] Test authentication
- [ ] Test authorization
- [ ] Test rate limiting
- [ ] Test input validation
- [ ] Test SQL injection prevention

**Estimated Effort**: 4 hours

**PHASE 5 TOTAL**: 32 hours (Week 5)

---

## 🎯 PHASE 6: MONITORING & DEPLOYMENT (Week 6)

### 6.1. Observability (Day 1-2 - 8 hours)

**Status**: ❌ Not Started (0%)

**`internal/observability/metrics.go`**:
```go
package observability

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    PointsEarned = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "loyalty_points_earned_total",
            Help: "Total points earned",
        },
        []string{"source"},
    )
    
    PointsRedeemed = promauto.NewCounter(
        prometheus.CounterOpts{
            Name: "loyalty_points_redeemed_total",
            Help: "Total points redeemed",
        },
    )
    
    TierUpgrades = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "loyalty_tier_upgrades_total",
            Help: "Total tier upgrades",
        },
        []string{"from_tier", "to_tier"},
    )
    
    RewardRedemptions = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "loyalty_reward_redemptions_total",
            Help: "Total reward redemptions",
        },
        []string{"reward_type"},
    )
    
    TransactionDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "loyalty_transaction_duration_seconds",
            Help:    "Transaction processing duration",
            Buckets: []float64{.005, .01, .025, .05, .1, .25, .5, 1},
        },
        []string{"type"},
    )
)
```

**Estimated Effort**: 8 hours

---

### 6.2. Health Checks (Day 2 - 2 hours)

**Status**: ❌ Not Started (0%)

**Health Check**:
```go
func (h *HealthHandler) Check(c *gin.Context) {
    health := map[string]interface{}{
        "status": "healthy",
        "checks": map[string]interface{}{},
    }
    
    // Check database
    if err := h.db.Ping(); err != nil {
        health["checks"]["database"] = "unhealthy"
        health["status"] = "unhealthy"
    } else {
        health["checks"]["database"] = "healthy"
    }
    
    // Check Redis
    if err := h.redis.Ping(c.Request.Context()).Err(); err != nil {
        health["checks"]["redis"] = "unhealthy"
        health["status"] = "unhealthy"
    } else {
        health["checks"]["redis"] = "healthy"
    }
    
    statusCode := 200
    if health["status"] == "unhealthy" {
        statusCode = 503
    }
    
    c.JSON(statusCode, health)
}
```

**Estimated Effort**: 2 hours

---

### 6.3. Docker & Deployment (Day 2-3 - 6 hours)

**Status**: 🟡 Partial (50%)

**Update Dockerfile**:
```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /loyalty-rewards ./cmd/loyalty-rewards

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/

COPY --from=builder /loyalty-rewards .
COPY --from=builder /app/configs ./configs

EXPOSE 8008 9008

CMD ["./loyalty-rewards", "-conf", "./configs"]
```

**Update docker-compose.yml**:
```yaml
services:
  loyalty-rewards:
    build: .
    ports:
      - "8008:8008"
      - "9008:9008"
    environment:
      - DATABASE_URL=postgres://user:pass@postgres:5432/loyalty_db
      - REDIS_ADDR=redis:6379
      - CONSUL_ADDR=consul:8500
    depends_on:
      - postgres
      - redis
      - consul
```

**Estimated Effort**: 6 hours

---

### 6.4. Documentation (Day 3-4 - 6 hours)

**Status**: 🟡 Partial (40%)

**Update README.md**:
```markdown
# Loyalty-Rewards Service

## Multi-Domain Architecture

### Domains
- **Account**: Loyalty account management
- **Transaction**: Points earning and redemption
- **Tier**: Tier management and progression
- **Reward**: Rewards catalog
- **Redemption**: Reward redemption
- **Referral**: Referral program
- **Campaign**: Bonus campaigns

### API Endpoints

#### Account Management
- `POST /api/v1/loyalty/account` - Create account
- `GET /api/v1/loyalty/account` - Get my account
- `GET /api/v1/loyalty/transactions` - Get my transactions

#### Rewards
- `GET /api/v1/loyalty/rewards` - List available rewards
- `POST /api/v1/loyalty/rewards/:id/redeem` - Redeem reward
- `GET /api/v1/loyalty/redemptions` - Get my redemptions

#### Referral
- `GET /api/v1/loyalty/referral/stats` - Get referral stats

### Events Published
- `loyalty.account.created`
- `loyalty.points.earned`
- `loyalty.points.redeemed`
- `loyalty.tier.upgraded`
- `loyalty.reward.redeemed`
- `loyalty.referral.completed`

### Events Consumed
- `order.completed` - Award points for purchases
- `review.created` - Award points for reviews
```

**Estimated Effort**: 6 hours

---

### 6.5. Final Testing & Launch (Day 4-5 - 6 hours)

**Status**: ❌ Not Started (0%)

**Launch Checklist**:
- [ ] Service starts successfully
- [ ] All health checks pass
- [ ] Database migrations applied
- [ ] Accounts can be created
- [ ] Points can be earned
- [ ] Points can be redeemed
- [ ] Tier upgrades work
- [ ] Rewards can be redeemed
- [ ] Referrals work
- [ ] Campaigns work
- [ ] Events are published
- [ ] Metrics are collected
- [ ] Logs are structured
- [ ] API documentation is accurate

**Estimated Effort**: 6 hours

**PHASE 6 TOTAL**: 28 hours (Week 6)

---

## 📊 SUMMARY

### Time Estimation
- **Phase 1**: Refactor to Multi-Domain - 38 hours (Week 1)
- **Phase 2**: Reward & Redemption Domains - 34 hours (Week 2)
- **Phase 3**: Referral & Campaign Domains - 36 hours (Week 3)
- **Phase 4**: Service Layer & Integration - 38 hours (Week 4)
- **Phase 5**: Testing & Quality - 32 hours (Week 5)
- **Phase 6**: Monitoring & Deployment - 28 hours (Week 6)

**TOTAL**: 206 hours (~5-6 weeks with 2-3 developers)

### Multi-Domain Structure Benefits
✅ **Separation of Concerns**: Each domain has clear responsibilities  
✅ **Scalability**: Easy to scale individual domains  
✅ **Maintainability**: Easier to understand and modify  
✅ **Testability**: Each domain can be tested independently  
✅ **Reusability**: Domains can be reused across services  
✅ **Team Collaboration**: Multiple developers can work on different domains  

### Key Features
✅ Points earning system with tier multipliers  
✅ Multi-tier loyalty program (Bronze, Silver, Gold, Platinum)  
✅ Rewards catalog with multiple types  
✅ Reward redemption with validation  
✅ Referral program with bonuses  
✅ Bonus campaigns with multipliers  
✅ Point expiration management  
✅ Transaction history tracking  
✅ Event-driven integration  
✅ Real-time tier progression  

### Dependencies
- Order Service (point earning on purchases)
- Customer Service (customer information)
- Notification Service (loyalty notifications)
- PostgreSQL 15
- Redis 7
- Consul (service discovery)

### Success Criteria
- [ ] Account creation < 200ms (p95)
- [ ] Point transaction < 300ms (p95)
- [ ] Reward redemption < 500ms (p95)
- [ ] Support 1000+ concurrent requests
- [ ] 99.9% uptime
- [ ] 80%+ test coverage
- [ ] Zero-downtime deployments

---

**Next Steps**:
1. Start with Phase 1: Refactor to multi-domain structure
2. Implement core domains in Phase 2-3
3. Build service layer and integrations in Phase 4
4. Comprehensive testing in Phase 5
5. Production deployment in Phase 6

**Priority**: Medium (after Order, Payment, Shipping)

---

*Generated: November 12, 2025*
*Status: Ready for refactoring and implementation*
*Architecture: Multi-Domain (following Catalog pattern)*
