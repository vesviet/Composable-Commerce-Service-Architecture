# Loyalty & Rewards Service

## Description
Service that manages customer loyalty programs, points accumulation, tier management, and rewards redemption to enhance customer retention and engagement.

## Core Responsibilities
- Customer loyalty program management
- Points accumulation and redemption system
- Tier-based benefits and privileges
- Reward catalog management
- Loyalty campaign orchestration
- Partner program integration

## Outbound Data
- Customer loyalty status and tier information
- Points balance and transaction history
- Available rewards and redemption options
- Tier benefits and privileges
- Loyalty campaign eligibility
- Partner program benefits

## Consumers (Services that use this data)

### Customer Service
- **Purpose**: Display loyalty status and benefits
- **Data Received**: Loyalty tier, points balance, tier benefits

### Pricing Service
- **Purpose**: Apply tier-based pricing and discounts
- **Data Received**: Customer tier, loyalty discounts, tier pricing

### Promotion Service
- **Purpose**: Create tier-specific promotions
- **Data Received**: Customer segments, loyalty status, tier eligibility

### Order Service
- **Purpose**: Apply loyalty discounts and earn points
- **Data Received**: Points earning rates, redemption values, tier benefits

### Notification Service
- **Purpose**: Send loyalty-related communications
- **Data Received**: Tier changes, points earned, reward availability

## Data Sources

### Order Service
- **Purpose**: Track purchase behavior for points earning
- **Data Received**: Order details, purchase amounts, product categories

### Customer Service
- **Purpose**: Customer profile and engagement data
- **Data Received**: Customer information, registration date, activity history

### Payment Service
- **Purpose**: Validate transactions for points earning
- **Data Received**: Payment confirmations, transaction amounts

## Loyalty Program Structure

### Tier System
```json
{
  "loyalty_tiers": {
    "bronze": {
      "name": "Bronze Member",
      "requirements": {
        "min_spend": 0,
        "min_orders": 0
      },
      "benefits": {
        "points_multiplier": 1.0,
        "free_shipping_threshold": 75.00,
        "birthday_discount": 10,
        "early_access": false
      }
    },
    "silver": {
      "name": "Silver Member",
      "requirements": {
        "min_spend": 500.00,
        "min_orders": 5
      },
      "benefits": {
        "points_multiplier": 1.25,
        "free_shipping_threshold": 50.00,
        "birthday_discount": 15,
        "early_access": true,
        "priority_support": true
      }
    },
    "gold": {
      "name": "Gold Member",
      "requirements": {
        "min_spend": 1500.00,
        "min_orders": 15
      },
      "benefits": {
        "points_multiplier": 1.5,
        "free_shipping_threshold": 25.00,
        "birthday_discount": 20,
        "early_access": true,
        "priority_support": true,
        "exclusive_products": true
      }
    },
    "platinum": {
      "name": "Platinum Member",
      "requirements": {
        "min_spend": 5000.00,
        "min_orders": 50
      },
      "benefits": {
        "points_multiplier": 2.0,
        "free_shipping_threshold": 0.00,
        "birthday_discount": 25,
        "early_access": true,
        "priority_support": true,
        "exclusive_products": true,
        "personal_shopper": true,
        "concierge_service": true
      }
    }
  }
}
```

### Points System
```json
{
  "points_earning": {
    "purchase": {
      "rate": "1 point per $1 spent",
      "bonus_categories": {
        "electronics": 2.0,
        "fashion": 1.5,
        "home": 1.25
      }
    },
    "activities": {
      "account_creation": 100,
      "first_purchase": 200,
      "product_review": 25,
      "referral": 500,
      "social_share": 10,
      "birthday": 100
    },
    "campaigns": {
      "double_points_weekend": 2.0,
      "category_bonus": 3.0,
      "new_product_launch": 5.0
    }
  },
  "points_redemption": {
    "value": "100 points = $1",
    "minimum_redemption": 500,
    "maximum_per_order": "50% of order value",
    "expiration": "24 months from earning date"
  }
}
```

## Reward Catalog

### Reward Types
```json
{
  "reward_catalog": {
    "discounts": [
      {
        "id": "REWARD-001",
        "name": "$5 Off Next Purchase",
        "type": "discount",
        "value": 5.00,
        "points_cost": 500,
        "minimum_order": 25.00,
        "expiration_days": 30
      },
      {
        "id": "REWARD-002",
        "name": "Free Shipping",
        "type": "shipping",
        "value": 0.00,
        "points_cost": 200,
        "minimum_order": 0.00,
        "expiration_days": 60
      }
    ],
    "products": [
      {
        "id": "REWARD-101",
        "name": "Exclusive Branded Mug",
        "type": "product",
        "points_cost": 1000,
        "stock_quantity": 500,
        "shipping_required": true
      }
    ],
    "experiences": [
      {
        "id": "REWARD-201",
        "name": "VIP Shopping Experience",
        "type": "experience",
        "points_cost": 5000,
        "description": "Personal shopping session with style consultant",
        "availability": "by_appointment"
      }
    ]
  }
}
```

### Reward Redemption Process
```javascript
// Reward redemption workflow
class RewardRedemption {
  async redeemReward(customerId, rewardId, quantity = 1) {
    // 1. Validate customer and reward
    const customer = await this.getCustomer(customerId);
    const reward = await this.getReward(rewardId);
    
    // 2. Check points balance
    const totalCost = reward.points_cost * quantity;
    if (customer.points_balance < totalCost) {
      throw new Error('Insufficient points balance');
    }
    
    // 3. Check reward availability
    if (reward.stock_quantity && reward.stock_quantity < quantity) {
      throw new Error('Reward out of stock');
    }
    
    // 4. Process redemption
    const redemption = await this.createRedemption({
      customerId,
      rewardId,
      quantity,
      points_cost: totalCost,
      status: 'pending'
    });
    
    // 5. Deduct points
    await this.deductPoints(customerId, totalCost, {
      type: 'redemption',
      reference: redemption.id
    });
    
    // 6. Update reward stock
    if (reward.stock_quantity) {
      await this.updateRewardStock(rewardId, -quantity);
    }
    
    // 7. Process reward delivery
    await this.processRewardDelivery(redemption);
    
    return redemption;
  }
}
```

## Loyalty Campaigns

### Campaign Types
```json
{
  "campaign_types": {
    "points_multiplier": {
      "name": "Double Points Weekend",
      "description": "Earn 2x points on all purchases",
      "multiplier": 2.0,
      "duration": "48 hours",
      "frequency": "monthly"
    },
    "tier_challenge": {
      "name": "Tier Up Challenge",
      "description": "Spend $500 in 30 days to advance tier",
      "target_amount": 500.00,
      "duration": "30 days",
      "reward": "tier_advancement"
    },
    "category_bonus": {
      "name": "Fashion Week Bonus",
      "description": "3x points on fashion items",
      "category": "fashion",
      "multiplier": 3.0,
      "duration": "7 days"
    },
    "referral_campaign": {
      "name": "Refer a Friend",
      "description": "Earn 500 points for each successful referral",
      "reward_points": 500,
      "friend_bonus": 200,
      "duration": "ongoing"
    }
  }
}
```

### Campaign Management
```javascript
// Campaign management system
class LoyaltyCampaign {
  async createCampaign(campaignData) {
    const campaign = {
      id: this.generateId(),
      name: campaignData.name,
      type: campaignData.type,
      rules: campaignData.rules,
      start_date: campaignData.start_date,
      end_date: campaignData.end_date,
      target_segments: campaignData.target_segments,
      status: 'active'
    };
    
    await this.saveCampaign(campaign);
    await this.notifyEligibleCustomers(campaign);
    
    return campaign;
  }
  
  async evaluateCampaignEligibility(customerId, campaignId) {
    const customer = await this.getCustomer(customerId);
    const campaign = await this.getCampaign(campaignId);
    
    // Check tier eligibility
    if (campaign.target_segments && 
        !campaign.target_segments.includes(customer.tier)) {
      return false;
    }
    
    // Check campaign-specific rules
    return this.evaluateRules(customer, campaign.rules);
  }
}
```

## Customer Loyalty Profile

### Loyalty Status
```json
{
  "customer_loyalty": {
    "customerId": "CUST-12345",
    "tier": "gold",
    "points_balance": 2500,
    "tier_progress": {
      "current_spend": 1750.00,
      "next_tier": "platinum",
      "spend_needed": 3250.00,
      "orders_needed": 35
    },
    "benefits": {
      "points_multiplier": 1.5,
      "free_shipping_threshold": 25.00,
      "birthday_discount": 20,
      "early_access": true,
      "priority_support": true
    },
    "activity": {
      "last_points_earned": "2024-08-10T14:30:00Z",
      "last_redemption": "2024-08-05T10:15:00Z",
      "tier_anniversary": "2024-03-15T00:00:00Z"
    }
  }
}
```

### Points Transaction History
```json
{
  "points_transactions": [
    {
      "id": "TXN-001",
      "type": "earned",
      "points": 150,
      "description": "Purchase order ORD-789012",
      "reference": "ORD-789012",
      "timestamp": "2024-08-10T14:30:00Z"
    },
    {
      "id": "TXN-002",
      "type": "bonus",
      "points": 50,
      "description": "Product review bonus",
      "reference": "REV-456789",
      "timestamp": "2024-08-09T16:45:00Z"
    },
    {
      "id": "TXN-003",
      "type": "redeemed",
      "points": -500,
      "description": "$5 discount reward",
      "reference": "REWARD-001",
      "timestamp": "2024-08-08T12:20:00Z"
    }
  ]
}
```

## Main APIs

### Loyalty Management APIs
- `GET /loyalty/customer/{id}` - Get customer loyalty status
- `POST /loyalty/points/earn` - Award points to customer
- `POST /loyalty/points/redeem` - Redeem points for rewards
- `GET /loyalty/points/history/{customerId}` - Get points transaction history
- `PUT /loyalty/tier/update/{customerId}` - Update customer tier

### Rewards APIs
- `GET /rewards/catalog` - Get available rewards
- `GET /rewards/customer/{id}/available` - Get rewards available to customer
- `POST /rewards/redeem` - Redeem reward
- `GET /rewards/redemptions/{customerId}` - Get redemption history

### Campaign APIs
- `GET /campaigns/active` - Get active loyalty campaigns
- `GET /campaigns/customer/{id}/eligible` - Get campaigns eligible for customer
- `POST /campaigns/participate` - Participate in campaign
- `GET /campaigns/{id}/progress/{customerId}` - Get campaign progress

## Integration with Other Services

### Order Service Integration
```javascript
// Points earning on order completion
eventBus.on('order.completed', async (event) => {
  const order = event.data;
  const customer = await customerService.getCustomer(order.customerId);
  
  // Calculate points based on tier multiplier
  const basePoints = Math.floor(order.totalAmount);
  const tierMultiplier = await loyaltyService.getTierMultiplier(customer.tier);
  const earnedPoints = basePoints * tierMultiplier;
  
  // Award points
  await loyaltyService.awardPoints(order.customerId, earnedPoints, {
    type: 'purchase',
    reference: order.orderId,
    description: `Purchase order ${order.orderNumber}`
  });
  
  // Check for tier advancement
  await loyaltyService.checkTierAdvancement(order.customerId);
});
```

### Pricing Service Integration
```javascript
// Apply tier-based pricing
class TierPricingCalculator {
  async calculateTierDiscount(customerId, orderAmount) {
    const loyaltyStatus = await loyaltyService.getCustomerLoyalty(customerId);
    const tierBenefits = await loyaltyService.getTierBenefits(loyaltyStatus.tier);
    
    if (tierBenefits.tier_discount) {
      const discountAmount = orderAmount * (tierBenefits.tier_discount / 100);
      return {
        discount_amount: discountAmount,
        discount_type: 'tier_benefit',
        tier: loyaltyStatus.tier
      };
    }
    
    return null;
  }
}
```

## Performance & Scalability

### Points Calculation Optimization
```sql
-- Optimized points balance calculation
CREATE MATERIALIZED VIEW customer_points_balance AS
SELECT 
  customer_id,
  SUM(CASE WHEN transaction_type = 'earned' THEN points ELSE -points END) as balance,
  MAX(updated_at) as last_updated
FROM points_transactions 
WHERE expiration_date > NOW() OR expiration_date IS NULL
GROUP BY customer_id;

-- Refresh materialized view on points transactions
CREATE OR REPLACE FUNCTION refresh_points_balance()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY customer_points_balance;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

### Caching Strategy
```yaml
caching:
  customer_loyalty_status:
    ttl: "1 hour"
    invalidate_on: ["points_transaction", "tier_change"]
    
  reward_catalog:
    ttl: "6 hours"
    invalidate_on: ["reward_update", "stock_change"]
    
  tier_benefits:
    ttl: "24 hours"
    invalidate_on: ["tier_config_change"]
```