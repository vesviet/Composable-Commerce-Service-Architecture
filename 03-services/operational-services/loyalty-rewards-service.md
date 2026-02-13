# 🎁 Loyalty-Rewards Service - Complete Documentation

**Service Name**: Loyalty-Rewards Service  
**Version**: 1.0.1
**Last Updated**: 2026-02-01
**Review Status**: ✅ Reviewed (see [loyalty-rewards_service_checklist_v3.md](../../10-appendix/checklists/v3/loyalty-rewards_service_checklist_v3.md))
**Production Ready**: 90% (Missing unit tests, architecture complete)  

---

## 📋 Table of Contents
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Multi-Domain APIs](#-multi-domain-apis)
- [Database Schema](#-database-schema)
- [Business Logic](#-business-logic)
- [Configuration](#-configuration)
- [Dependencies](#-dependencies)
- [Testing](#-testing)
- [Monitoring & Observability](#-monitoring--observability)
- [Known Issues & TODOs](#-known-issues--todos)
- [Development Guide](#-development-guide)

---

## 🎯 Overview

Loyalty-Rewards Service quản lý toàn bộ loyalty program trong e-commerce platform, bao gồm points system, tier management, rewards catalog, và referral programs.

### Core Capabilities
- **🏆 Points System**: Earn và redeem points từ purchases và activities
- **🎖️ Tier Management**: Progressive loyalty tiers với benefits
- **🎁 Rewards Catalog**: Manage available rewards và redemption options
- **👥 Referral Program**: Reward customers for successful referrals
- **📊 Analytics**: Comprehensive loyalty program analytics
- **⏰ Expiration Management**: Point expiration và notifications

### Business Value
- **Customer Retention**: Reward repeat purchases và engagement
- **Loyalty Programs**: Structured tier progression
- **Referral Marketing**: Viral growth through customer referrals
- **Data-Driven**: Analytics for loyalty program optimization

### Architecture Summary
- **Clean Architecture**: biz / data / service / client / events layers
- **Multi-Domain**: account, transaction, tier, reward, redemption, referral, campaign
- **Common Package**: Uses `gitlab.com/ta-microservices/common` (events, transaction, cache)
- **Repository Pattern**: Interfaces in `internal/repository`, implementations in `internal/data/postgres`
- **Event Publishing**: Dapr pub/sub via common/events; topic constants in `internal/constants`
- **Note**: `cmd/loyalty-rewards` (main.go, wire) may be in a separate repo or pending; Makefile expects it for build/run

---

## 🏗️ Architecture

### Current State (✅ IMPLEMENTED)
```
loyalty-rewards/
├── cmd/loyalty-rewards/           # Entry point (missing in repo; add main.go, wire.go)
├── internal/
│   ├── biz/                       # Business Logic Layer (7 domains)
│   │   ├── account/               # Account management domain
│   │   ├── transaction/           # Points transactions domain
│   │   ├── tier/                  # Tier management domain
│   │   ├── reward/                # Rewards catalog domain
│   │   ├── redemption/            # Redemption processing domain
│   │   ├── referral/              # Referral program domain
│   │   ├── campaign/              # Bonus campaigns domain
│   │   └── events/                # Event publishing (Dapr)
│   ├── data/                      # Data Access Layer
│   │   ├── postgres/              # PostgreSQL repositories
│   │   └── redis/                 # Redis client
│   ├── repository/                # Repository interfaces
│   ├── cache/                     # Account, reward, tier cache
│   ├── service/                   # gRPC/HTTP service layer
│   ├── server/                    # HTTP, gRPC, Consul
│   ├── client/                    # Order, customer, notification clients
│   ├── constants/                 # Status, types, event topics
│   ├── config/                    # Configuration
│   ├── observability/             # Metrics, tracing
│   └── jobs/                      # Points expiration job
├── api/loyalty/v1/                # Protocol Buffers
├── migrations/                    # Goose migrations
└── configs/                       # config.yaml, config-docker.yaml
```

### Checklist & Review
See [loyalty-rewards_service_checklist_v3.md](../../10-appendix/checklists/v3/loyalty-rewards_service_checklist_v3.md) for P0/P1/P2 issues, dependencies (no replace), lint/build status, and docs.

---

## 🏗️ Ports & Endpoints
- **HTTP API**: `:8013` - REST endpoints cho frontend/client apps
- **gRPC API**: `:9013` - Internal service communication
- **Health Check**: `/health`

### Service Dependencies

#### Internal Dependencies
- **Customer Service**: Customer profile data
- **Order Service**: Order data for point calculations
- **Notification Service**: Loyalty notifications

#### External Dependencies
- **PostgreSQL**: Primary data store (`loyalty_db`)
- **Redis**: Caching layer
- **Dapr**: Event-driven communication

---

## 🎯 Multi-Domain APIs

### 1. Account Service - Loyalty Account Management

#### Create Loyalty Account
```protobuf
rpc CreateAccount(CreateAccountRequest) returns (Account) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/accounts"
    body: "*"
  };
}
```

**Request**:
```json
{
  "customer_id": "customer-uuid",
  "initial_points": 0,
  "tier_id": "bronze-tier-uuid"
}
```

#### Get Account
```protobuf
rpc GetAccount(GetAccountRequest) returns (Account) {
  option (google.api.http) = {
    get: "/api/v1/loyalty/accounts/{customer_id}"
  };
}
```

### 2. Transaction Service - Points Management

#### Earn Points
```protobuf
rpc EarnPoints(EarnPointsRequest) returns (Transaction) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/points/earn"
    body: "*"
  };
}
```

**Request**:
```json
{
  "customer_id": "customer-uuid",
  "points": 100,
  "reason": "purchase",
  "reference_id": "order-123",
  "metadata": {
    "order_total": 1000.00,
    "multiplier": 1.0
  }
}
```

#### Redeem Points
```protobuf
rpc RedeemPoints(RedeemPointsRequest) returns (Transaction) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/points/redeem"
    body: "*"
  };
}
```

### 3. Tier Service - Loyalty Tiers

#### Get Customer Tier
```protobuf
rpc GetCustomerTier(GetCustomerTierRequest) returns (CustomerTier) {
  option (google.api.http) = {
    get: "/api/v1/loyalty/tiers/{customer_id}"
  };
}
```

#### Upgrade Tier
```protobuf
rpc UpgradeTier(UpgradeTierRequest) returns (CustomerTier) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/tiers/{customer_id}/upgrade"
    body: "*"
  };
}
```

### 4. Reward Service - Rewards Catalog

#### List Rewards
```protobuf
rpc ListRewards(ListRewardsRequest) returns (ListRewardsResponse) {
  option (google.api.http) = {
    get: "/api/v1/loyalty/rewards"
  };
}
```

#### Get Reward
```protobuf
rpc GetReward(GetRewardRequest) returns (Reward) {
  option (google.api.http) = {
    get: "/api/v1/loyalty/rewards/{id}"
  };
}
```

### 5. Redemption Service - Reward Redemption

#### Redeem Reward
```protobuf
rpc RedeemReward(RedeemRewardRequest) returns (Redemption) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/redemptions"
    body: "*"
  };
}
```

**Request**:
```json
{
  "customer_id": "customer-uuid",
  "reward_id": "reward-uuid",
  "points_cost": 500
}
```

### 6. Referral Service - Referral Program

#### Create Referral
```protobuf
rpc CreateReferral(CreateReferralRequest) returns (Referral) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/referrals"
    body: "*"
  };
}
```

#### Complete Referral
```protobuf
rpc CompleteReferral(CompleteReferralRequest) returns (Referral) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/referrals/{id}/complete"
    body: "*"
  };
}
```

### 7. Campaign Service - Bonus Campaigns

#### Create Campaign
```protobuf
rpc CreateCampaign(CreateCampaignRequest) returns (Campaign) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/campaigns"
    body: "*"
  };
}
```

#### Apply Campaign Bonus
```protobuf
rpc ApplyCampaignBonus(ApplyCampaignBonusRequest) returns (BonusApplication) {
  option (google.api.http) = {
    post: "/api/v1/loyalty/campaigns/{campaign_id}/apply"
    body: "*"
  };
}
```

---

## 🗄️ Database Schema

### Core Tables

#### loyalty_accounts
```sql
CREATE TABLE loyalty_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL UNIQUE,
  current_points INTEGER NOT NULL DEFAULT 0,
  total_earned_points INTEGER NOT NULL DEFAULT 0,
  total_redeemed_points INTEGER NOT NULL DEFAULT 0,
  tier_id UUID REFERENCES loyalty_tiers(id),
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### loyalty_transactions
```sql
CREATE TABLE loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES loyalty_accounts(customer_id),
  transaction_type VARCHAR(20) NOT NULL, -- 'earn', 'redeem', 'expire', 'bonus'
  points INTEGER NOT NULL,
  balance_after INTEGER NOT NULL,
  reason VARCHAR(100),
  reference_id VARCHAR(255), -- order_id, reward_id, etc.
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### loyalty_tiers
```sql
CREATE TABLE loyalty_tiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  description TEXT,
  min_points INTEGER NOT NULL DEFAULT 0,
  max_points INTEGER,
  benefits JSONB DEFAULT '{}',
  multiplier DECIMAL(3,2) DEFAULT 1.00,
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### loyalty_rewards
```sql
CREATE TABLE loyalty_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  points_cost INTEGER NOT NULL,
  reward_type VARCHAR(50) NOT NULL, -- 'discount', 'free_shipping', 'product', 'cashback'
  reward_value JSONB, -- discount_percentage, product_id, etc.
  max_redemptions INTEGER,
  current_redemptions INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### loyalty_redemptions
```sql
CREATE TABLE loyalty_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES loyalty_accounts(customer_id),
  reward_id UUID NOT NULL REFERENCES loyalty_rewards(id),
  points_used INTEGER NOT NULL,
  redemption_value JSONB,
  status VARCHAR(20) NOT NULL DEFAULT 'completed',
  redeemed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Additional Tables

#### referral_programs
```sql
CREATE TABLE referral_programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES loyalty_accounts(customer_id),
  referee_email VARCHAR(255) NOT NULL,
  referee_id UUID REFERENCES loyalty_accounts(customer_id),
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  bonus_points INTEGER NOT NULL DEFAULT 0,
  referee_bonus_points INTEGER NOT NULL DEFAULT 0,
  completed_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### bonus_campaigns
```sql
CREATE TABLE bonus_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  campaign_type VARCHAR(50) NOT NULL, -- 'multiplier', 'bonus_points', 'special_offer'
  conditions JSONB, -- eligibility criteria
  rewards JSONB, -- bonus configuration
  is_active BOOLEAN DEFAULT TRUE,
  starts_at TIMESTAMP WITH TIME ZONE,
  ends_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Indexes & Performance
```sql
-- Account lookups
CREATE UNIQUE INDEX idx_loyalty_accounts_customer_id ON loyalty_accounts(customer_id);
CREATE INDEX idx_loyalty_accounts_tier_id ON loyalty_accounts(tier_id);
CREATE INDEX idx_loyalty_accounts_status ON loyalty_accounts(status);

-- Transaction lookups
CREATE INDEX idx_loyalty_transactions_customer_id ON loyalty_transactions(customer_id);
CREATE INDEX idx_loyalty_transactions_type ON loyalty_transactions(transaction_type);
CREATE INDEX idx_loyalty_transactions_created_at ON loyalty_transactions(created_at DESC);

-- Tier management
CREATE UNIQUE INDEX idx_loyalty_tiers_name ON loyalty_tiers(name);
CREATE INDEX idx_loyalty_tiers_active ON loyalty_tiers(is_active, min_points);

-- Rewards
CREATE INDEX idx_loyalty_rewards_active ON loyalty_rewards(is_active, points_cost);
CREATE INDEX idx_loyalty_rewards_type ON loyalty_rewards(reward_type);

-- Redemptions
CREATE INDEX idx_loyalty_redemptions_customer ON loyalty_redemptions(customer_id, redeemed_at DESC);
CREATE INDEX idx_loyalty_redemptions_reward ON loyalty_redemptions(reward_id);

-- Referrals
CREATE INDEX idx_referral_programs_referrer ON referral_programs(referrer_id);
CREATE INDEX idx_referral_programs_referee_email ON referral_programs(referee_email);
CREATE UNIQUE INDEX idx_referral_programs_referee ON referral_programs(referee_id) WHERE referee_id IS NOT NULL;

---

## 🧠 Business Logic - Comprehensive E-Commerce Loyalty Program

### Core Principles
1. **Automatic Point Earning**: Event-driven points awarded for customer actions
2. **Tier-Based Rewards**: Progressive benefits through tier system
3. **Fraud Prevention**: Rate limiting, duplicate detection, validation
4. **Customer Engagement**: Multiple earning channels (purchase, review, referral, social, birthday)
5. **Transparent**: Clear earning/redemption rules, point expiration

---

## 1. Points Earning Rules

### 1.1 Order-Based Earning (Primary Channel)

**Trigger Event**: `order.completed` or `order.paid` from Order Service

**Calculation Formula**:
```
Base Points = Order Subtotal × Points Per Dollar
Tier Multiplier = Customer's Current Tier Multiplier (1.0 - 2.0x)
Campaign Bonus = Active Campaign Bonus (if applicable)

Total Earned = (Base Points × Tier Multiplier) + Campaign Bonus
```

**Rules**:
- ✅ **Only completed/paid orders** earn points
- ✅ **Subtotal only** (excluding tax, shipping, discounts already applied)
- ✅ **Tier multiplier** applied BEFORE campaign bonus
- ❌ **Cancelled orders**: Points reversed automatically
- ❌ **Returned orders**: Points deducted proportionally
- ❌ **Fraudulent orders**: Flagged and points withheld

**Configuration**:
```yaml
points:
  per_dollar: 1.0           # 1 point per $1 spent
  min_order_amount: 10.00   # Minimum order to earn points
  max_points_per_order: 5000  # Anti-abuse limit
```

**Example**:
```
Order Subtotal: $150.00
Customer Tier: Gold (1.5x multiplier)
Campaign: Double Points Weekend (+50 bonus)

Base Points: 150 × 1.0 = 150
With Tier: 150 × 1.5 = 225
Campaign Bonus: +50
Total Earned: 275 points
```

### 1.2 Customer Registration (Welcome Bonus)

**Trigger Event**: `customer.created` from Customer Service

**Rules**:
- ✅ **One-time** bonus on first registration
- ✅ **Immediate** credit (no waiting period)
- ❌ **Duplicate accounts**: Detect by email/phone, prevent fraud

**Configuration**:
```yaml
campaigns:
  welcome_bonus: 100  # Points awarded on registration
```

### 1.3 Product Review Earning

**Trigger Event**: `review.approved` from Review Service (future)

**Rules**:
- ✅ **Review submitted**: 50 points (pending approval)
- ✅ **Review approved**: Bonus 25 points (total 75)
- ✅ **Photo/video review**: Additional 50 points
- ❌ **Max 5 reviews per month** to prevent spam
- ❌ **Review rejected**: No points awarded

**Configuration**:
```yaml
campaigns:
  review_bonus: 50            # Points for approved review
  review_with_media_bonus: 50 # Additional for photo/video
  max_reviews_per_month: 5
```

### 1.4 Referral Program

**Trigger Events**: 
- `referral.created`: Referrer shares referral code
- `customer.registered_via_referral`: Referee signs up
- `order.completed`: Referee's first order

**Referrer Rewards**:
- Referee signs up: 100 points (pending)
- Referee completes first order: 400 points (total 500)

**Referee Rewards**:
- Signs up via referral: 200 points immediately
- First order: 10% discount code

**Rules**:
- ✅ **Max 10 successful referrals per month** per customer
- ❌ **Self-referral detected**: Both accounts flagged
- ❌ **Referee minimum first order**: $50 to trigger referrer bonus

**Configuration**:
```yaml
referral:
  referrer_bonus: 500  # Total for successful referral
  referee_bonus: 200   # Welcome bonus for referee
  max_referrals_per_month: 10
  referee_min_order_amount: 50.00
```

### 1.5 Birthday Bonus

**Trigger**: Cron job checks birthdays daily OR `customer.birthday` event

**Rules**:
- ✅ **Annual bonus** on customer's birthday
- ✅ **Valid for 30 days** from birthday
- ✅ **Auto-awarded** at midnight UTC on birthday

**Configuration**:
```yaml
campaigns:
  birthday_bonus: 250  # Points awarded on birthday
  birthday_validity_days: 30
```

### 1.6 Social Sharing (Future Enhancement)

**Trigger Events**: `social.product_shared`, `social.order_shared`

**Rules**:
- Product shared: 10 points per share (max 3/day)
- Order shared: 25 points (max 1/day)

---

## 2. Points Redemption Rules

### 2.1 Redemption Validation

```go
func (uc *RedemptionUsecase) ValidateRedemption(ctx context.Context, req *RedeemPointsRequest) error {
    // 1. Check minimum points threshold
    if req.Points < uc.config.MinRedemptionPoints {
        return ErrBelowMinimumRedemption
    }

    // 2. Check maximum points per redemption
    if req.Points > uc.config.MaxRedemptionPoints {
        return ErrExceedsMaximumRedemption
    }

    // 3. Check account has sufficient balance
    account, _ := uc.accountRepo.GetByCustomerID(ctx, req.CustomerID)
    if account.CurrentPoints < req.Points {
        return ErrInsufficientPoints
    }

    // 4. Check points not reserved for pending redemptions
    reserved := uc.getReservedPoints(ctx, req.CustomerID)
    available := account.CurrentPoints - reserved
    if available < req.Points {
        return ErrPointsReserved
    }

    // 5. Check account status
    if account.Status != "active" {
        return ErrAccountNotActive
    }

    return nil
}
```

### 2.2 Redemption Types

#### Discount Voucher
```
Redemption: 500 points → $5 discount code
Ratio: 100 points = $1
Valid: 90 days from redemption
Usage: Single use, any order over $25
```

#### Free Shipping
```
Redemption: 200 points → Free standard shipping
Valid: 60 days
Usage: Single use
```

#### Product Rewards
```
Redemption: Variable points based on product value
Example: 2000 points → Premium water bottle
Delivery: Same as regular order
```

#### Cashback
```
Redemption: 1000 points → $10 wallet credit
Ratio: 100 points = $1
Valid: 180 days
Usage: Multiple uses until depleted
```

### 2.3 Redemption Configuration

```yaml
redemption:
  min_points: 100           # Minimum points to redeem
  max_points: 10000         # Maximum points per transaction
  points_to_dollar_ratio: 100  # 100 points = $1
  
  voucher:
    validity_days: 90
    min_order_amount: 25.00
  
  free_shipping:
    cost_in_points: 200
    validity_days: 60
    shipping_methods: ["standard"]
  
  cashback:
    min_redemption: 1000
    max_redemption: 10000
    validity_days: 180
```

---

## 3. Tier System

### 3.1 Tier Levels

| Tier | Min Points | Multiplier | Benefits |
|------|------------|------------|----------|
| **Bronze** | 0 | 1.0x | Standard support, standard shipping rates |
| **Silver** | 1,000 | 1.2x | Priority support, free standard shipping on orders $50+ |
| **Gold** | 5,000 | 1.5x | VIP support, free standard shipping (all orders), exclusive offers, early access to sales |
| **Platinum** | 10,000 | 2.0x | Dedicated support, free express shipping, exclusive rewards, birthday gift, priority returns |

### 3.2 Tier Progression Logic

**Upgrade Triggers**:
- ✅ **Automatic** after points transaction (earn/redeem)
- ✅ **Evaluated immediately** (no delay)
- ✅ **Based on total_earned_points** (not current_points to prevent gaming via redemption)

**Implementation**:
```go
func (uc *TierUsecase) EvaluateTierUpgrade(ctx context.Context, customerID string) error {
    account, _ := uc.accountRepo.GetByCustomerID(ctx, customerID)
    
    // Check eligibility based on TOTAL earned (lifetime), not current balance
    nextTier, err := uc.tierRepo.GetEligibleTier(ctx, account.TotalEarnedPoints)
    if err != nil {
        return err
    }
    
    // Only upgrade, never downgrade (even if points redeemed)
    if nextTier.MinPoints > account.CurrentTier.MinPoints {
        // Upgrade tier
        account.TierID = nextTier.ID
        uc.accountRepo.Update(ctx, account)
        
        // Publish tier upgrade event → Notification service
        uc.eventPublisher.Publish(ctx, &events.TierUpgraded{
            CustomerID: customerID,
            OldTier: account.CurrentTier.Name,
            NewTier: nextTier.Name,
            TotalEarnedPoints: account.TotalEarnedPoints,
        })
        
        // Send congrats email/push notification
        uc.notificationClient.SendTierUpgradeNotification(ctx, customerID, nextTier)
    }
    
    return nil
}
```

**Rules**:
- ✅ **Tier Retention**: Once upgraded, tier is retained (no downgrade)
- ✅ **Based on lifetime points**: total_earned_points, NOT current_points
- ✅ **Immediate**: Upgrade happens in same transaction as points earning
- ✅ **Notification**: Customer notified immediately of upgrade

---

## 4. Campaign Management

### 4.1 Campaign Types

#### Welcome Bonus Campaign
```yaml
type: welcome_bonus
trigger: customer.created
bonus: 100 points (fixed)
duration: permanent (always active)
```

#### Birthday Campaign
```yaml
type: birthday_bonus
trigger: cron (daily check) OR customer.birthday event
bonus: 250 points (fixed)
validity: 30 days from birthday
duration: recurring (annual)
```

#### Double Points Weekend
```yaml
type: multiplier_campaign
trigger: time-based (Friday 00:00 - Sunday 23:59)
bonus: 2x points on all orders
min_order_amount: $50
duration: temporary (weekend only)
```

#### Flash Sale Bonus
```yaml
type: bonus_points
trigger: specific product category purchase  
bonus: +200 points (fixed)
conditions:
  - category: "Electronics"
  - min_amount: $200
duration: campaign.starts_at → campaign.ends_at
```

#### Referral Campaign
```yaml
type: referral_bonus
trigger: referral.completed
bonus: 
  referrer: 500 points
  referee: 200 points
conditions:
  - referee_min_first_order: $50
  - max_referrals_per_month: 10
duration: permanent
```

### 4.2 Campaign Application Logic

```go
func (uc *TransactionUsecase) ApplyCampaignBonus(ctx context.Context, req *EarnPointsRequest) int32 {
    // Get all active campaigns
    campaigns, _ := uc.campaignRepo.GetActiveCampaigns(ctx, time.Now())
    
    var totalBonus int32 = 0
    
    for _, campaign := range campaigns {
        // Check campaign eligibility
        if !uc.checkCampaignEligibility(ctx, campaign, req) {
            continue
        }
        
        switch campaign.Type {
        case "multiplier":
            // Apply multiplier to base points
            multiplier := campaign.BonusConfig["multiplier"].(float64)
            totalBonus += int32(float64(req.BasePoints) * (multiplier - 1.0))
            
        case "fixed_bonus":
            // Add fixed bonus
            totalBonus += campaign.BonusConfig["bonus_points"].(int32)
            
        case "tiered_bonus":
            // Bonus based on order amount tiers
            totalBonus += uc.calculateTieredBonus(ctx, campaign, req)
        }
    }
    
    return totalBonus
}
```

---

## 5. Fraud Prevention & Rate Limiting

### 5.1 Anti-Abuse Rules

**Daily Limits**:
```yaml
limits:
  max_points_per_day: 10000      # Per customer
  max_transactions_per_day: 50   # Prevent spam
```

**Weekly/Monthly Limits**:
```yaml
limits:
  max_points_per_week: 50000
  max_points_per_month: 150000
```

**Specific Activity Limits**:
```yaml
referral:
  max_per_month: 10              # Prevent referral farming
review:
  max_per_month: 5               # Prevent review spam
social_sharing:
  max_shares_per_day: 3          # Prevent social spam
```

### 5.2 Fraud Detection

**Duplicate Detection**:
```go
func (uc *TransactionUsecase) CheckDuplicateTransaction(ctx context.Context, req *EarnPointsRequest) error {
    // Idempotency check using source + source_id
    exists, _ := uc.repo.TransactionExists(ctx, req.Source, req.SourceID)
    if exists {
        return ErrDuplicateTransaction
    }
    return nil
}
```

**Suspicious Pattern Detection**:
- Multiple accounts from same IP/device
- Rapid succession of referrals
- Unusual earning patterns (too many points too fast)
- Self-referral attempts (same email/phone)

**Actions on Fraud**:
1. ⚠️ **Warning**: Flag account for manual review
2. 🚫 **Suspend**: Temporarily disable earning for 7-30 days
3. ❌ **Ban**: Permanent account/points freeze

---

## 6. Points Expiration

### 6.1 Expiration Rules

**Configuration**:
```yaml
points:
  expiry_months: 12              # Points expire 12 months after earning
  expiration_grace_period_days: 7  # 7-day warning before expiration
  min_points_to_expire: 10       # Don't expire if < 10 points
```

**Expiration Logic**:
- ✅ **FIFO (First In, First Out)**: Oldest points expire first
- ✅ **Granular**: Track expiration per transaction, not account-level
- ✅ **Notifications**: 7 days, 3 days, 1 day before expiration
- ✅ **Cron Job**: Daily job at 00:00 UTC processes expirations

**Implementation**:
```go
func (j *PointsExpirationJob) ExpirePoints(ctx context.Context) error {
    // Find transactions with expired points
    expiredTxs, _ := j.transactionRepo.FindExpired(ctx, time.Now())
    
    for _, tx := range expiredTxs {
        // Create expiration transaction
        expirationTx := &model.LoyaltyTransaction{
            CustomerID: tx.CustomerID,
            TransactionType: "expire",
            Points: -tx.Points,  // Deduct points
            Source: "expiration",
            SourceID: tx.ID,
            Description: fmt.Sprintf("Points expired from transaction %s", tx.ID),
        }
        
        // Deduct from account
        account, _ := j.accountRepo.GetByCustomerID(ctx, tx.CustomerID)
        account.CurrentPoints -= tx.Points
        j.accountRepo.Update(ctx, account)
        
        // Record expiration transaction
        j.transactionRepo.Create(ctx, expirationTx)
        
        // Publish expiration event → Notification service
        j.eventPublisher.Publish(ctx, &events.PointsExpired{
            CustomerID: tx.CustomerID,
            Points: tx.Points,
            ExpiredAt: time.Now(),
        })
    }
    
    return nil
}
```

### 6.2 Expiration Notifications

**Notification Schedule**:
```go
Notification Triggers:
- 7 days before: "⚠️ You have 500 points expiring on Jan 15"
- 3 days before: "⏰ Reminder: 500 points expire in 3 days"
- 1 day before: "🔔 Last chance! 500 points expire tomorrow"
- On expiration: "😔 500 points expired. Earn more by shopping!"
```

---

## 7. Event-Driven Architecture

### 7.1 Events Consumed (by Worker)

Worker subscribes to these events via Dapr PubSub:

#### From Customer Service
```yaml
topic: customer.created
payload:
  customer_id: string
  email: string
  created_at: timestamp

action:
  - Create loyalty account
  - Award welcome bonus (100 points)
  - Source: "welcome_bonus"
```

```yaml
topic: customer.birthday
payload:
  customer_id: string
  birthday: date

action:
  - Award birthday bonus (250 points)
  - Source: "birthday_bonus"
  - Valid for 30 days
```

#### From Order Service
```yaml
topic: order.completed
payload:
  order_id: string
  customer_id: string
  subtotal: decimal
  status: string
  completed_at: timestamp

action:
  - Calculate points (subtotal × 1.0 × tier_multiplier + campaigns)
  - Award points
  - Source: "order"
  - SourceID: order_id
  - Check tier upgrade
```

```yaml
topic: order.cancelled
payload:
  order_id: string
  customer_id: string

action:
  - Find transaction by source="order", source_id=order_id
  - Reverse points (create "deduct" transaction)
  - Recheck tier (should not downgrade, but update balance)
```

```yaml
topic: order.returned
payload:
  order_id: string
  customer_id: string
  return_amount: decimal  # Partial return possible

action:
  - Calculate points to deduct (return_amount × points_ratio)
  - Create "return_deduction" transaction
  - Update balance
```

#### From Review Service (Future)
```yaml
topic: review.approved
payload:
  review_id: string
  customer_id: string
  product_id: string
  has_media: boolean

action:
  - Award base review bonus (50 points)
  - If has_media: +50 bonus points
  - Source: "review"
  - SourceID: review_id
  - Check monthly limit (max 5 reviews)
```

### 7.2 Events Published (by Main Service + Worker)

Loyalty service publishes events for other services:

```yaml
topic: loyalty.account.created
payload:
  customer_id: string
  tier_id: string
  created_at: timestamp
consumers: [analytics, notification]
```

```yaml
topic: loyalty.points.earned
payload:
  customer_id: string
  points: int
  source: string
  balance_after: int
consumers: [analytics, notification]
```

```yaml
topic: loyalty.tier.upgraded
payload:
  customer_id: string
  old_tier: string
  new_tier: string
  total_earned_points: int
consumers: [customer, notification, analytics]
```

```yaml
topic: loyalty.points.redeemed
payload:
  customer_id: string
  points: int
  reward_type: string
  reward_id: string
consumers: [order, promotion, analytics]
action: "Apply discount/reward to order"
```

```yaml
topic: loyalty.points.expired
payload:
  customer_id: string
  points: int
  expired_at: timestamp
consumers: [notification, analytics]
```

### 7.3 Event Flow Examples

#### Order Completion Flow
```mermaid
sequenceDiagram
    participant Order as Order Service
    participant Dapr as Dapr PubSub
    participant LoyaltyWorker as Loyalty Worker
    participant LoyaltyDB as Loyalty DB
    participant Notification as Notification Service

    Order->>Dapr: Publish order.completed
    Dapr->>LoyaltyWorker: Deliver event
    LoyaltyWorker->>LoyaltyWorker: Calculate points (subtotal × tier × campaigns)
    LoyaltyWorker->>LoyaltyDB: Create transaction + update account
    LoyaltyWorker->>LoyaltyWorker: Check tier upgrade eligibility
    alt Tier Upgraded
        LoyaltyWorker->>LoyaltyDB: Update account tier
        LoyaltyWorker->>Dapr: Publish loyalty.tier.upgraded
        Dapr->>Notification: Send tier upgrade email/push
    end
    LoyaltyWorker->>Dapr: Publish loyalty.points.earned
    Dapr->>Notification: Send points earned notification
```

#### Referral Completion Flow
```mermaid
sequenceDiagram
    participant Referee as Referee
    participant Customer as Customer Service
    participant Dapr as Dapr PubSub
    participant LoyaltyWorker as Loyalty Worker
    participant Order as Order Service

    Referee->>Customer: Register via referral code
    Customer->>Dapr: Publish customer.registered_via_referral
    Dapr->>LoyaltyWorker: Deliver event
    LoyaltyWorker->>LoyaltyWorker: Award referee 200 points
    LoyaltyWorker->>LoyaltyWorker: Create pending referral record
    
    Referee->>Order: Complete first order ($50+)
    Order->>Dapr: Publish order.completed (first_order=true)
    Dapr->>LoyaltyWorker: Deliver event
    LoyaltyWorker->>LoyaltyWorker: Check referral record
    LoyaltyWorker->>LoyaltyWorker: Award referrer 500 points
    LoyaltyWorker->>Dapr: Publish loyalty.referral.completed
```

---

## 8. Implementation Checklist (Worker Events)

### Phase 1: Core Event Consumers (PRIORITY)
- [ ] `customer.created` → Welcome bonus
- [ ] `order.completed` → Points earning
- [ ] `order.cancelled` → Points reversal
- [ ] Tier upgrade logic after earning
- [ ] Event idempotency (prevent duplicates)

### Phase 2: Advanced Events
- [ ] `order.returned` → Partial points deduction
- [ ] `customer.birthday` → Birthday bonus  
- [ ] `referral.completed` → Referral bonuses

### Phase 3: Future Events
- [ ] `review.approved` → Review points
- [ ] `social.shared` → Social points
- [ ] Campaign-triggered bonuses

---

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
LOYALTY_DATABASE_DSN=postgres://loyalty_user:loyalty_pass@postgres:5432/loyalty_db?sslmode=disable

# Redis
LOYALTY_REDIS_ADDR=redis:6379
LOYALTY_REDIS_DB=2

# Service Ports
LOYALTY_HTTP_PORT=8013
LOYALTY_GRPC_PORT=9013

# Points Configuration
LOYALTY_POINTS_PER_DOLLAR=1.0
LOYALTY_POINTS_EXPIRY_MONTHS=12
LOYALTY_REFERRAL_BONUS_POINTS=500
LOYALTY_MAX_DAILY_POINTS=10000
LOYALTY_MAX_WEEKLY_POINTS=50000
LOYALTY_MAX_MONTHLY_POINTS=150000

# Tier Configuration
LOYALTY_DEFAULT_TIER=bronze
LOYALTY_AUTO_TIER_UPGRADE=true

# External Services
LOYALTY_CUSTOMER_SERVICE_ADDR=customer-service:9003
LOYALTY_ORDER_SERVICE_ADDR=order-service:9004
LOYALTY_NOTIFICATION_SERVICE_ADDR=notification-service:9005

# Features
LOYALTY_ENABLE_REFERRALS=true
LOYALTY_ENABLE_CAMPAIGNS=true
LOYALTY_ENABLE_ANALYTICS=true
```

### Configuration Files
```yaml
# configs/config.yaml
app:
  name: loyalty-rewards-service
  version: 1.0.0

database:
  dsn: ${LOYALTY_DATABASE_DSN}
  max_open_conns: 25
  max_idle_conns: 25
  conn_max_lifetime: 5m

redis:
  addr: ${LOYALTY_REDIS_ADDR}
  db: ${LOYALTY_REDIS_DB}
  dial_timeout: 5s

server:
  http:
    addr: 0.0.0.0
    port: ${LOYALTY_HTTP_PORT}
  grpc:
    addr: 0.0.0.0
    port: ${LOYALTY_GRPC_PORT}

points:
  per_dollar: ${LOYALTY_POINTS_PER_DOLLAR}
  expiry_months: ${LOYALTY_POINTS_EXPIRY_MONTHS}
  referral_bonus: ${LOYALTY_REFERRAL_BONUS_POINTS}
  limits:
    daily: ${LOYALTY_MAX_DAILY_POINTS}
    weekly: ${LOYALTY_MAX_WEEKLY_POINTS}
    monthly: ${LOYALTY_MAX_MONTHLY_POINTS}

tiers:
  default: ${LOYALTY_DEFAULT_TIER}
  auto_upgrade: ${LOYALTY_AUTO_TIER_UPGRADE}

external_services:
  customer_service: ${LOYALTY_CUSTOMER_SERVICE_ADDR}
  order_service: ${LOYALTY_ORDER_SERVICE_ADDR}
  notification_service: ${LOYALTY_NOTIFICATION_SERVICE_ADDR}

features:
  referrals: ${LOYALTY_ENABLE_REFERRALS}
  campaigns: ${LOYALTY_ENABLE_CAMPAIGNS}
  analytics: ${LOYALTY_ENABLE_ANALYTICS}
```

---

## 🔗 Dependencies

### Go Modules
```go
module gitlab.com/ta-microservices/loyalty-rewards

go 1.24

require (
    // MISSING: gitlab.com/ta-microservices/common v1.0.14
    github.com/go-kratos/kratos/v2 v2.9.1
    github.com/redis/go-redis/v9 v9.5.1
    gorm.io/gorm v1.25.10
    // MISSING: github.com/dapr/go-sdk v1.11.0
    google.golang.org/protobuf v1.34.2
    github.com/google/uuid v1.6.0
)
```

### Service Mesh Integration
```yaml
# Dapr pub/sub subscriptions
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: loyalty-service-events
spec:
  topic: order.created
  route: /events/order-created
  pubsubname: pubsub
---
apiVersion: dapr.io/v1alpha1
kind: Subscription
metadata:
  name: loyalty-customer-events
spec:
  topic: customer.created
  route: /events/customer-created
  pubsubname: pubsub
```

---

## 🧪 Testing

### Current Test Status: ❌ NONE
- **Unit Tests**: 0% coverage
- **Integration Tests**: 0% coverage
- **E2E Tests**: 0% coverage

### Required Test Implementation

#### Unit Tests Needed
```go
func TestTransactionUsecase_CalculateEarnedPoints(t *testing.T) {
    // Test points calculation with different order amounts
    // Test tier multipliers
    // Test campaign bonuses
    // Test earning limits
}

func TestTierUsecase_EvaluateTierUpgrade(t *testing.T) {
    // Test tier upgrade logic
    // Test tier downgrade prevention
    // Test event publishing
}

func TestReferralUsecase_CompleteReferral(t *testing.T) {
    // Test referral completion
    // Test bonus point awarding
    // Test duplicate prevention
}
```

#### Integration Tests Needed
```go
func TestLoyaltyAccountLifecycle(t *testing.T) {
    // Create account → Earn points → Redeem points → Check balance
    // Verify database consistency
    // Verify event publishing
}

func TestReferralProgramEndToEnd(t *testing.T) {
    // Create referral → Complete referral → Verify bonuses
    // Test notification sending
    // Test analytics updates
}
```

### Test Infrastructure Setup Required
```bash
# Test database setup
make test-db-setup

# Run tests with coverage
make test-coverage

# Integration tests
make test-integration

# Load testing
make test-load
```

---

## 📊 Monitoring & Observability

### Key Metrics (Prometheus)

#### Loyalty Metrics
```go
# Account metrics
loyalty_accounts_total 15420
loyalty_accounts_active_total 12345

# Points metrics
loyalty_points_earned_total 4567890
loyalty_points_redeemed_total 1234567
loyalty_points_expired_total 89012

# Tier metrics
loyalty_tier_upgrades_total{tier="gold"} 2340
loyalty_customers_per_tier{tier="platinum"} 567

# Referral metrics
loyalty_referrals_created_total 8901
loyalty_referrals_completed_total 5678
loyalty_referral_bonus_points_awarded_total 2839000
```

#### Performance Metrics
```go
# API response times
loyalty_api_request_duration_seconds{endpoint="/api/v1/loyalty/accounts", quantile="0.95"} 0.045
loyalty_api_request_duration_seconds{endpoint="/api/v1/loyalty/points/earn", quantile="0.95"} 0.078

# Points calculation performance
loyalty_points_calculation_duration_seconds{quantile="0.95"} 0.023

# Cache hit rates
loyalty_cache_hit_ratio{cache="accounts"} 0.91
loyalty_cache_hit_ratio{cache="tiers"} 0.97
loyalty_cache_hit_ratio{cache="rewards"} 0.88
```

### Health Checks
```go
# Application health
GET /health

# Dependencies health
GET /health/dependencies

# Database connectivity
# Redis connectivity
# External services (customer, order, notification)
```

### Distributed Tracing (OpenTelemetry)

#### Points Earning Flow
```
Order Service → Loyalty Service
├── Receive order.created event
├── Calculate earned points
├── Check earning limits
├── Create transaction record (Database)
├── Update account balance (Database)
├── Publish points.earned event (Dapr)
└── Cache invalidation (Redis)
```

#### Reward Redemption Flow
```
Client → Loyalty Service
├── Validate reward availability
├── Check customer points balance
├── Create redemption record (Database)
├── Deduct points from account (Database)
├── Publish reward.redeemed event (Dapr)
└── Trigger fulfillment workflow
```

---

## 🚨 Known Issues & TODOs

### P0 - Critical Architecture Issues

1. **Missing Common Package Integration** 🚨
   - **Issue**: Service not using `gitlab.com/ta-microservices/common`
   - **Impact**: Missing standardized patterns, utilities, events
   - **Location**: `go.mod`, entire codebase
   - **Fix**: Import common package and refactor to use standard patterns

2. **No Repository Layer** 🚨
   - **Issue**: Direct database access without abstraction
   - **Impact**: Tight coupling, hard to test, no interface segregation
   - **Location**: `internal/data/postgres/`
   - **Fix**: Implement repository pattern with interfaces

3. **Missing Service Layer** 🚨
   - **Issue**: Business logic directly exposed without service abstraction
   - **Impact**: No clear API boundaries, hard to maintain
   - **Location**: `internal/biz/` directly called
   - **Fix**: Add gRPC/HTTP service layer

4. **Monolithic Structure** 🚨
   - **Issue**: Single service instead of multi-domain architecture
   - **Impact**: Hard to maintain, scale individual domains
   - **Location**: Single `cmd/loyalty-rewards/`
   - **Fix**: Split into 7 domain services

### P1 - High Priority Development Issues

5. **Zero Test Coverage** 🟡
   - **Issue**: No unit tests, integration tests, or E2E tests
   - **Impact**: No confidence in code changes, regression risks
   - **Location**: Missing `*_test.go` files
   - **Fix**: Implement comprehensive test suite (target 80% coverage)

6. **No Wire Dependency Injection** 🟡
   - **Issue**: Manual dependency injection
   - **Impact**: Error-prone, hard to maintain
   - **Location**: `cmd/loyalty-rewards/main.go`
   - **Fix**: Implement Google Wire for DI

7. **Missing Cache Layer** 🟡
   - **Issue**: No Redis caching implementation
   - **Impact**: Database load, slow response times
   - **Location**: Missing `internal/cache/`
   - **Fix**: Implement multi-level caching

### P2 - Medium Priority Features

8. **Incomplete Event System** 🔵
   - **Issue**: Basic event publishing, missing event handling
   - **Impact**: Limited inter-service communication
   - **Location**: `internal/biz/events/`
   - **Fix**: Complete event-driven architecture

9. **Missing Analytics** 🔵
   - **Issue**: No comprehensive loyalty analytics
   - **Impact**: Cannot measure program effectiveness
   - **Location**: Missing analytics domain
   - **Fix**: Implement loyalty analytics dashboard

10. **No Background Workers** 🔵
    - **Issue**: No cron jobs for point expiration, tier evaluation
    - **Impact**: Manual processes, delayed updates
    - **Location**: Missing `cmd/worker/`
    - **Fix**: Implement background job processing

---

## 🚀 Development Guide

### Current State Assessment
Service hiện tại **không thể production-ready** do missing critical architectural components.

### Immediate Refactoring Plan (2-3 weeks)

#### Phase 1: Foundation (Week 1)
```bash
# 1. Import common package
go get gitlab.com/ta-microservices/common@v1.0.14

# 2. Create repository interfaces
# internal/repository/
# ├── account_repository.go
# ├── transaction_repository.go
# ├── tier_repository.go
# ├── reward_repository.go
# ├── redemption_repository.go
# ├── referral_repository.go
# └── campaign_repository.go

# 3. Implement repository pattern
# internal/data/postgres/
# ├── account_repo.go
# ├── transaction_repo.go
# └── ...

# 4. Add service layer
# internal/service/
# ├── account_service.go
# ├── transaction_service.go
# └── ...
```

#### Phase 2: Architecture (Week 2)
```bash
# 1. Implement multi-domain structure
# internal/biz/
# ├── account/
# │   ├── usecase.go
# │   └── usecase_test.go
# ├── transaction/
# │   ├── usecase.go
# │   └── usecase_test.go
# └── ...

# 2. Add Wire dependency injection
# cmd/loyalty-rewards/
# ├── wire.go
# └── wire_gen.go

# 3. Implement cache layer
# internal/cache/
# ├── account_cache.go
# ├── reward_cache.go
# └── tier_cache.go
```

#### Phase 3: Testing & Polish (Week 3)
```bash
# 1. Add comprehensive tests
# internal/biz/*/usecase_test.go
# internal/service/*_test.go

# 2. Implement event system
# internal/biz/events/
# ├── publisher.go
# ├── subscriber.go
# └── types.go

# 3. Add background workers
# cmd/worker/
# ├── main.go
# ├── point_expiration.go
# └── tier_evaluation.go
```

### Local Development Setup (Post-Refactor)
```bash
# Clone and setup
git clone git@gitlab.com:ta-microservices/loyalty-rewards.git
cd loyalty-rewards

# Start dependencies
docker-compose up -d postgres redis

# Install dependencies
go mod download

# Run migrations
make migrate-up

# Generate protobuf code
make api

# Generate wire dependencies
make wire

# Run service
make run

# Test loyalty operations
curl -X POST http://localhost:8013/api/v1/loyalty/accounts \
  -H "Content-Type: application/json" \
  -d '{"customer_id": "test-customer-id"}'
```

### Code Generation
```bash
# Generate protobuf code
make api

# Generate wire dependency injection
make wire

# Generate mocks for testing
make mocks
```

### Database Operations
```bash
# Create new migration
make migrate-create NAME="add_loyalty_analytics"

# Apply migrations
make migrate-up

# Check status
make migrate-status

# Rollback (development only)
make migrate-down
```

---

## 📈 Performance Benchmarks (Target)

### API Response Times (P95)
- **Create Account**: 45ms
- **Earn Points**: 67ms
- **Redeem Reward**: 89ms
- **Get Account**: 23ms

### Throughput Targets
- **Read Operations**: 500 req/sec sustained
- **Points Operations**: 200 req/sec sustained
- **Redemption Operations**: 100 req/sec sustained

### Database Performance
- **Account Queries**: <15ms average
- **Transaction Inserts**: <25ms average
- **Complex Analytics**: <100ms average

---

## 🔐 Security Considerations

### Data Protection
- **Points Validation**: Prevent negative balances, fraud detection
- **Rate Limiting**: Per-customer limits on operations
- **Audit Trail**: Complete transaction logging
- **Data Encryption**: Sensitive data encryption at rest

### Access Control
- **Customer Isolation**: Customers can only access their own data
- **Admin Permissions**: Separate admin APIs for management
- **Service Authentication**: Internal service-to-service auth

---

## 🎯 Future Roadmap

### Phase 1 (Q2 2026) - Complete Refactor
- [ ] Import common package
- [ ] Implement repository pattern
- [ ] Add service layer
- [ ] Implement multi-domain architecture
- [ ] Add comprehensive testing

### Phase 2 (Q3 2026) - Advanced Features
- [ ] Real-time analytics dashboard
- [ ] Machine learning for personalization
- [ ] Advanced referral tracking
- [ ] Multi-brand loyalty programs
- [ ] Mobile app integration

### Phase 3 (Q4 2026) - Scale & Intelligence
- [ ] Database sharding for high-volume
- [ ] Advanced fraud detection
- [ ] Predictive churn analysis
- [ ] Dynamic pricing based on loyalty

---

## 📞 Support & Contact

### Development Team
- **Tech Lead**: Loyalty Service Team
- **Repository**: `gitlab.com/ta-microservices/loyalty-rewards`
- **Documentation**: This file
- **Issues**: GitLab Issues

### On-Call Support
- **Production Issues**: #loyalty-service-alerts
- **Security Issues**: #security-incidents
- **Performance Issues**: #loyalty-service-performance
- **Points Issues**: #loyalty-points

### Monitoring Dashboards
- **Application Metrics**: `https://grafana.tanhdev.com/d/loyalty-service`
- **Points Analytics**: `https://grafana.tanhdev.com/d/loyalty-points`
- **Tier Analytics**: `https://grafana.tanhdev.com/d/loyalty-tiers`
- **Business Metrics**: `https://grafana.tanhdev.com/d/loyalty-business`
