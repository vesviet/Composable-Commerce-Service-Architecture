# 🎯 Promotion Service Feature Checklist
## Based on Magento 2 Cart Price Rules + Amasty Special Promotions

> **Generated:** 2025-11-19  
> **Current Status:** 🟡 **Partial Implementation (60%)**  
> **Target:** Feature parity with Magento 2 + Amasty Special Promotions

---

## 📋 Table of Contents
1. [Current Implementation Status](#current-implementation-status)
2. [Core Architecture](#core-architecture)
3. [Promotion Rule Types](#promotion-rule-types)
4. [Discount Actions](#discount-actions)
5. [Rule Conditions](#rule-conditions)
6. [Customer Targeting](#customer-targeting)
7. [Coupon Management](#coupon-management)
8. [Advanced Features](#advanced-features)
9. [Integration & Performance](#integration--performance)
10. [Implementation Priority](#implementation-priority)

---

## 📊 Current Implementation Status

### Overall Progress: **60%** Complete

| Category | Magento + Amasty | Current | Status | Priority |
|----------|------------------|---------|--------|----------|
| **Rule Structure** | ✅ Full | 🟡 Basic | 60% | 🔴 High |
| **Discount Actions** | ✅ 20+ types | 🟡 4 types | 20% | 🔴 High |
| **Conditions** | ✅ Advanced | 🟡 Basic | 40% | 🔴 High |
| **Cart Price Rules** | ✅ Full | 🟡 Partial | 60% | 🔴 High |
| **Catalog Price Rules** | ✅ Full | ❌ Missing | 0% | 🔴 High |
| **Buy X Get Y** | ✅ Full | ❌ Missing | 0% | 🔴 High |
| **Tiered Discounts** | ✅ Full | ❌ Missing | 0% | 🔴 High |
| **Free Shipping** | ✅ Full | ❌ Missing | 0% | 🟡 Medium |
| **Coupon System** | ✅ Full | ✅ Complete | 100% | ✅ Done |
| **Customer Segments** | ✅ Full | ✅ Complete | 100% | ✅ Done |
| **Priority System** | ✅ Full | ✅ Complete | 100% | ✅ Done |
| **Stacking Rules** | ✅ Full | ✅ Complete | 100% | ✅ Done |
| **Analytics** | ✅ Full | 🟡 Basic | 60% | 🟡 Medium |

---

## 🏗️ Core Architecture

### 1. Rule Type Separation

#### ❌ **MISSING: Separate Cart & Catalog Rules**

**Current State:**
```go
// Current - No distinction
type Promotion struct {
    PromotionType string  // Generic "discount", "bogo", etc.
}
```

**Required:**
```go
// ✅ REQUIRED: Add rule type
type RuleType string

const (
    RuleTypeCart    RuleType = "cart"     // Apply at checkout
    RuleTypeCatalog RuleType = "catalog"  // Apply to product prices
)

type Promotion struct {
    RuleType           RuleType           // ⭐ NEW
    
    // Cart-specific
    CartConditions     *CartConditions    // ⭐ NEW
    CartActions        *CartActions       // ⭐ NEW
    
    // Catalog-specific
    CatalogConditions  *CatalogConditions // ⭐ NEW
    CatalogActions     *CatalogActions    // ⭐ NEW
}
```

**Implementation Tasks:**
- [ ] Add `rule_type` enum field to database
- [ ] Create separate condition structures for cart vs catalog
- [ ] Create separate action structures for cart vs catalog
- [ ] Update business logic to handle both rule types
- [ ] Add migration to update existing rules

**Dependencies:** None  
**Estimated Time:** 2-3 days  
**Priority:** 🔴 **Critical**

---

### 2. Catalog Price Indexing System

#### ❌ **MISSING: Price Index for Catalog Rules**

**Current State:**
- No price indexing
- All calculations happen in real-time
- Poor performance for catalog-wide promotions

**Required:**
```sql
-- ✅ REQUIRED: Catalog price index table
CREATE TABLE catalog_price_index (
    product_id UUID NOT NULL,
    customer_group VARCHAR(50) NOT NULL,
    website_id VARCHAR(50) DEFAULT 'default',
    rule_id UUID,
    rule_price DECIMAL(10,2) NOT NULL,
    original_price DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) NOT NULL,
    discount_percent DECIMAL(5,2),
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_to TIMESTAMP WITH TIME ZONE NOT NULL,
    indexed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    PRIMARY KEY (product_id, customer_group, website_id),
    FOREIGN KEY (rule_id) REFERENCES promotions(id) ON DELETE CASCADE
);

CREATE INDEX idx_catalog_price_product ON catalog_price_index(product_id);
CREATE INDEX idx_catalog_price_rule ON catalog_price_index(rule_id);
CREATE INDEX idx_catalog_price_valid ON catalog_price_index(valid_from, valid_to);
CREATE INDEX idx_catalog_price_group ON catalog_price_index(customer_group);
```

**Implementation Tasks:**
- [ ] Create catalog_price_index table
- [ ] Implement price indexing worker
- [ ] Create reindex API endpoint
- [ ] Schedule periodic reindexing (cron job)
- [ ] Integrate with Catalog service for price display
- [ ] Add cache layer for indexed prices

**Dependencies:** Catalog service integration  
**Estimated Time:** 4-5 days  
**Priority:** 🔴 **Critical**

---

## 💰 Discount Actions

### 3. Buy X Get Y (BOGO)

#### ❌ **MISSING: Buy X Get Y Promotion**

**Magento + Amasty Examples:**
- Buy 2 Get 1 Free
- Buy 3 Get 20% off on 4th item
- Buy $100 worth, Get $20 product free
- Buy X from Category A, Get Y from Category B with discount

**Required Structure:**
```go
// ✅ REQUIRED: Buy X Get Y action
type BuyXGetYAction struct {
    // X products (buy these)
    BuyQuantity          int                    // Minimum quantity to buy
    BuyProducts          []string               // Specific products
    BuyCategories        []string               // Or from categories
    BuyBrands            []string               // Or from brands
    BuyMinAmount         *float64               // Or minimum spend amount
    
    // Y products (get these)
    GetQuantity          int                    // Quantity of Y items
    GetDiscountType      string                 // "percentage", "fixed_amount", "free"
    GetDiscountAmount    float64                // Discount on Y items
    GetMaxQuantity       int                    // Max Y items to discount
    GetSameAsX           bool                   // Y must be same as X?
    GetProducts          []string               // Specific Y products
    GetCategories        []string               // Or Y from categories
    GetCheapest          bool                   // Apply to cheapest items
    GetMostExpensive     bool                   // Apply to most expensive items
    
    // Limits
    MaxApplications      *int                   // Max times to apply in cart
    SkipSpecialPrice     bool                   // Skip products with special price
}

// Examples of actions field JSON:
{
  "buy_x_get_y": {
    "buy_quantity": 2,
    "buy_categories": ["electronics"],
    "get_quantity": 1,
    "get_discount_type": "free",
    "get_same_as_x": true,
    "get_cheapest": true
  }
}
```

**Implementation Tasks:**
- [ ] Add BuyXGetYAction struct
- [ ] Implement BOGO calculation logic
- [ ] Handle "cheapest/most expensive" logic
- [ ] Support cross-category BOGO
- [ ] Add validation for BOGO rules
- [ ] Create unit tests for all BOGO scenarios

**Test Scenarios:**
- [ ] Buy 2 Get 1 Free (same product)
- [ ] Buy 3 Get 20% off 4th item
- [ ] Buy from Cat A, Get from Cat B
- [ ] Buy $100, Get specific product free
- [ ] BOGO with cheapest item free
- [ ] BOGO with max quantity limit

**Dependencies:** Cart service integration  
**Estimated Time:** 3-4 days  
**Priority:** 🔴 **Critical**

---

### 4. Tiered/Progressive Discounts

#### ❌ **MISSING: Quantity-Based Tiered Discounts**

**Magento + Amasty Examples:**
- Buy 3-5 items: 10% off
- Buy 6-10 items: 15% off
- Buy 11+ items: 20% off
- Each 3rd item: 50% off
- Spend $100-$200: $10 off, $200-$500: $30 off, $500+: $100 off

**Required Structure:**
```go
// ✅ REQUIRED: Tiered discount action
type TieredDiscountAction struct {
    BasedOn              string                 // "quantity", "amount"
    ApplyTo              string                 // "cart", "each_item"
    Tiers                []DiscountTier
    DiscountStep         *int                   // Each Nth item (e.g., every 3rd item)
}

type DiscountTier struct {
    MinQuantity          *int                   // Min qty for this tier
    MaxQuantity          *int                   // Max qty for this tier
    MinAmount            *float64               // Min amount for this tier
    MaxAmount            *float64               // Max amount for this tier
    DiscountType         string                 // "percentage", "fixed_amount"
    DiscountValue        float64                // Discount value
}

// Examples:
{
  "tiered_discount": {
    "based_on": "quantity",
    "apply_to": "cart",
    "tiers": [
      {"min_quantity": 3, "max_quantity": 5, "discount_type": "percentage", "discount_value": 10},
      {"min_quantity": 6, "max_quantity": 10, "discount_type": "percentage", "discount_value": 15},
      {"min_quantity": 11, "discount_type": "percentage", "discount_value": 20}
    ]
  }
}

// Each Nth item example:
{
  "tiered_discount": {
    "based_on": "quantity",
    "discount_step": 3,  // Every 3rd item
    "tiers": [
      {"discount_type": "percentage", "discount_value": 50}
    ]
  }
}
```

**Implementation Tasks:**
- [ ] Add TieredDiscountAction struct
- [ ] Implement tier matching logic
- [ ] Support quantity-based tiers
- [ ] Support amount-based tiers
- [ ] Implement "each Nth item" logic
- [ ] Add tier validation
- [ ] Create comprehensive test suite

**Test Scenarios:**
- [ ] Quantity tiers: 3-5 (10%), 6-10 (15%), 11+ (20%)
- [ ] Amount tiers: $100-$200 ($10), $200+ ($30)
- [ ] Each 3rd item: 50% off
- [ ] Overlapping tiers handling
- [ ] Multiple products with different qtys

**Dependencies:** None  
**Estimated Time:** 2-3 days  
**Priority:** 🔴 **High**

---

### 5. Cheapest/Most Expensive Item Discounts

#### ❌ **MISSING: Cheapest/Most Expensive Item Logic**

**Amasty Examples:**
- 50% off cheapest item in cart
- Free most expensive item when buying 3+
- $10 off each of 2 cheapest items

**Required Structure:**
```go
// ✅ REQUIRED: Item selection for discounts
type ItemSelectionAction struct {
    SelectionMode        string                 // "cheapest", "most_expensive"
    ItemCount            int                    // How many items to select
    DiscountType         string                 // "percentage", "fixed_amount", "free"
    DiscountValue        float64                // Discount value
    ApplyToCategories    []string               // Limit to categories
    ApplyToProducts      []string               // Limit to products
    MinCartQuantity      *int                   // Min cart qty to trigger
    SkipSpecialPrice     bool                   // Skip items with special price
}

// Examples:
{
  "item_selection": {
    "selection_mode": "cheapest",
    "item_count": 1,
    "discount_type": "free",
    "min_cart_quantity": 3
  }
}
```

**Implementation Tasks:**
- [ ] Add ItemSelectionAction struct
- [ ] Implement cheapest item selection
- [ ] Implement most expensive item selection
- [ ] Support selecting N items
- [ ] Handle special price exclusions
- [ ] Add validation and tests

**Test Scenarios:**
- [ ] Cheapest item free
- [ ] Most expensive 50% off
- [ ] 2 cheapest items $10 off each
- [ ] Only when cart has 3+ items

**Dependencies:** None  
**Estimated Time:** 1-2 days  
**Priority:** 🟡 **Medium**

---

### 6. Free Shipping Actions

#### ❌ **MISSING: Free Shipping Promotions**

**Magento Examples:**
- Free shipping on all orders over $100
- Free shipping for specific products
- Free shipping for VIP customers
- Free specific shipping method (e.g., Standard Shipping)

**Required Structure:**
```go
// ✅ REQUIRED: Free shipping action
type FreeShippingAction struct {
    Enabled              bool                   // Enable free shipping
    ShippingMethods      []string               // Specific methods (empty = all)
    MaxShippingAmount    *float64               // Max shipping discount
    ApplyToProducts      []string               // Free shipping for these products
    ApplyToCategories    []string               // Free shipping for these categories
}

// Add to CartActions:
type CartActions struct {
    // ... existing fields ...
    FreeShipping         *FreeShippingAction   // ⭐ NEW
}
```

**Implementation Tasks:**
- [ ] Add FreeShippingAction struct
- [ ] Integrate with Shipping service
- [ ] Support method-specific free shipping
- [ ] Support max discount amount
- [ ] Add product/category filtering
- [ ] Create integration tests with shipping

**Test Scenarios:**
- [ ] Free shipping over $100
- [ ] Free standard shipping only
- [ ] Free shipping for electronics
- [ ] Partial shipping discount (max $10)

**Dependencies:** Shipping service integration  
**Estimated Time:** 2-3 days  
**Priority:** 🟡 **Medium**

---

### 7. Gift/Free Product Actions

#### ❌ **MISSING: Free Gift Promotions**

**Amasty Examples:**
- Free product when spending $100+
- Free gift with purchase of specific product
- Choose 1 free gift from selection

**Required Structure:**
```go
// ✅ REQUIRED: Free gift action
type FreeGiftAction struct {
    GiftProducts         []GiftProduct          // Available gifts
    SelectionMode        string                 // "auto", "customer_choice"
    MaxGiftQuantity      int                    // Max qty of gifts
    RequiresMininumSpend *float64               // Min spend for gift
    RequiresMininumQty   *int                   // Min qty for gift
}

type GiftProduct struct {
    ProductID            string
    Quantity             int
    Priority             int                    // For auto-selection
}
```

**Implementation Tasks:**
- [ ] Add FreeGiftAction struct
- [ ] Implement auto gift selection
- [ ] Implement customer choice logic
- [ ] Integrate with Cart service
- [ ] Handle gift inventory
- [ ] Add gift display in cart

**Test Scenarios:**
- [ ] Auto gift when spending $100+
- [ ] Customer chooses 1 from 3 gifts
- [ ] Multiple gifts with conditions

**Dependencies:** Cart service, Catalog service  
**Estimated Time:** 2-3 days  
**Priority:** 🟡 **Medium**

---

## 🎯 Rule Conditions

### 8. Advanced Cart Conditions

#### 🟡 **PARTIAL: Cart-Level Conditions**

**Current State:**
```go
// ✅ Implemented
- MinimumOrderAmount
- ApplicableProducts
- ApplicableCategories
- CustomerSegments

// ❌ Missing
- Cart weight conditions
- Cart item quantity
- Shipping conditions
- Payment method conditions
- Geographic conditions
```

**Required Structure:**
```go
// ✅ REQUIRED: Detailed cart conditions
type CartConditions struct {
    // Cart totals
    SubtotalMin          *float64               // ⭐ NEW
    SubtotalMax          *float64               // ⭐ NEW
    TotalItemsQtyMin     *int                   // ⭐ NEW
    TotalItemsQtyMax     *int                   // ⭐ NEW
    TotalWeightMin       *float64               // ⭐ NEW
    TotalWeightMax       *float64               // ⭐ NEW
    
    // Shipping conditions
    ShippingMethods      []string               // ⭐ NEW
    ShippingCountry      []string               // ⭐ NEW
    ShippingRegion       []string               // ⭐ NEW
    ShippingPostcode     string                 // ⭐ NEW (regex pattern)
    
    // Payment conditions
    PaymentMethods       []string               // ⭐ NEW
    
    // Product conditions
    ProductConditions    *ProductConditions
    
    // Logical operators
    CombineConditions    string                 // "all" (AND) or "any" (OR)
}
```

**Implementation Tasks:**
- [ ] Add cart total conditions (subtotal, qty, weight)
- [ ] Add shipping method conditions
- [ ] Add geographic conditions (country, region, postcode)
- [ ] Add payment method conditions
- [ ] Implement AND/OR logic combination
- [ ] Create validation for all conditions

**Test Scenarios:**
- [ ] Cart subtotal between $100-$500
- [ ] Cart has 5-10 items
- [ ] Cart weight over 5kg
- [ ] Shipping to US only
- [ ] Payment by Credit Card
- [ ] Combined conditions (AND/OR)

**Dependencies:** Shipping service, Order service  
**Estimated Time:** 3-4 days  
**Priority:** 🔴 **High**

---

### 9. Product Attribute Conditions

#### ❌ **MISSING: Product Attribute Conditions**

**Amasty Examples:**
- Products with attribute Color = Red
- Products with Size = XL
- Products with custom attribute matching

**Required Structure:**
```go
// ✅ REQUIRED: Product attribute conditions
type ProductConditions struct {
    // Basic filters (existing)
    Categories           []string
    Products             []string
    Brands               []string
    
    // ⭐ NEW: Attribute conditions
    Attributes           []AttributeCondition   // ⭐ NEW
    
    // Price conditions
    PriceMin             *float64               // ⭐ NEW
    PriceMax             *float64               // ⭐ NEW
    SpecialPriceOnly     bool                   // ⭐ NEW
    ExcludeSpecialPrice  bool                   // ⭐ NEW
    
    // Quantity/Weight
    QuantityMin          *int                   // ⭐ NEW
    QuantityMax          *int                   // ⭐ NEW
    WeightMin            *float64               // ⭐ NEW
    WeightMax            *float64               // ⭐ NEW
    
    // Operators
    CategoryOperator     string                 // "in", "not_in"
    ProductOperator      string                 // "in", "not_in"
}

type AttributeCondition struct {
    AttributeCode        string                 // e.g., "color", "size"
    Operator             string                 // "eq", "neq", "in", "not_in", "contains", "gt", "lt"
    Value                interface{}            // Attribute value(s)
}

// Example JSON:
{
  "product_conditions": {
    "attributes": [
      {"attribute_code": "color", "operator": "in", "value": ["red", "blue"]},
      {"attribute_code": "size", "operator": "eq", "value": "XL"}
    ],
    "price_min": 50.00,
    "price_max": 200.00,
    "exclude_special_price": true
  }
}
```

**Implementation Tasks:**
- [ ] Add AttributeCondition struct
- [ ] Integrate with Catalog service for attributes
- [ ] Implement attribute value matching
- [ ] Support multiple attribute conditions
- [ ] Add price range conditions
- [ ] Add special price handling
- [ ] Create comprehensive tests

**Test Scenarios:**
- [ ] Color = Red
- [ ] Size = XL
- [ ] Price between $50-$200
- [ ] Exclude products with special price
- [ ] Multiple attributes (AND logic)

**Dependencies:** Catalog service integration  
**Estimated Time:** 3-4 days  
**Priority:** 🔴 **High**

---

### 10. Customer History Conditions

#### ❌ **MISSING: Customer Order History Conditions**

**Amasty Examples:**
- First-time customers only
- Customers with 5+ orders
- Customers who spent $1000+ lifetime
- Customers registered 30+ days ago

**Required Structure:**
```go
// ✅ REQUIRED: Customer history conditions
type CustomerHistoryConditions struct {
    IsNewCustomer        *bool                  // ⭐ NEW (first order)
    OrderCountMin        *int                   // ⭐ NEW
    OrderCountMax        *int                   // ⭐ NEW
    LifetimeSpentMin     *float64               // ⭐ NEW
    LifetimeSpentMax     *float64               // ⭐ NEW
    DaysSinceRegistration *int                  // ⭐ NEW (min days)
    DaysSinceLastOrder   *int                   // ⭐ NEW
    HasPurchasedProducts []string               // ⭐ NEW (bought these before)
    HasNotPurchasedProducts []string            // ⭐ NEW (never bought these)
}
```

**Implementation Tasks:**
- [ ] Add CustomerHistoryConditions struct
- [ ] Integrate with Customer service for history
- [ ] Integrate with Order service for order data
- [ ] Implement new customer detection
- [ ] Implement order count conditions
- [ ] Implement lifetime value conditions
- [ ] Add purchase history conditions

**Test Scenarios:**
- [ ] First-time customer discount
- [ ] Loyalty discount (5+ orders)
- [ ] VIP discount ($1000+ spent)
- [ ] Win-back campaign (30+ days since last order)

**Dependencies:** Customer service, Order service  
**Estimated Time:** 3-4 days  
**Priority:** 🟡 **Medium**

---

## 👥 Customer Targeting

### 11. Customer Attributes Conditions

#### ❌ **MISSING: Customer Attribute Conditions**

**Amasty Examples:**
- Birthday promotions (DOB this month)
- Gender-specific promotions
- Age-based promotions
- Customer group promotions

**Required Structure:**
```go
// ✅ REQUIRED: Customer attribute conditions
type CustomerAttributeConditions struct {
    Gender               *string                // ⭐ NEW
    AgeMin               *int                   // ⭐ NEW
    AgeMax               *int                   // ⭐ NEW
    BirthdayThisMonth    bool                   // ⭐ NEW
    BirthdayThisWeek     bool                   // ⭐ NEW
    CustomerGroups       []string               // Existing (already implemented ✅)
    CustomerTier         *string                // ⭐ NEW (Bronze, Silver, Gold)
    MembershipDaysMin    *int                   // ⭐ NEW (days since registration)
}
```

**Implementation Tasks:**
- [ ] Add CustomerAttributeConditions struct
- [ ] Integrate with Customer service for attributes
- [ ] Implement birthday detection logic
- [ ] Implement age calculation
- [ ] Add customer tier handling
- [ ] Create attribute matching logic

**Test Scenarios:**
- [ ] Birthday promotion (DOB this month)
- [ ] Women's day promotion (Gender = Female)
- [ ] Senior discount (Age 60+)
- [ ] Gold tier exclusive discount

**Dependencies:** Customer service integration  
**Estimated Time:** 2-3 days  
**Priority:** 🟡 **Medium**

---

##🎫 Coupon Management

### 12. Coupon System

#### ✅ **IMPLEMENTED: Core Coupon Features**

**Current Implementation:**
- ✅ Coupon code generation
- ✅ Bulk coupon generation (up to 10,000)
- ✅ Coupon validation
- ✅ Usage limits (per customer, total)
- ✅ Expiration dates
- ✅ Customer-specific coupons
- ✅ Customer segment targeting

**Status:** **100% Complete** 🎉

---

### 13. Advanced Coupon Features

#### 🟡 **PARTIAL: Advanced Coupon Management**

**Amasty Features:**
- ❌ Auto-apply coupons (best coupon)
- ❌ Coupon display on checkout
- ❌ Coupon code import/export
- ❌ Conditional coupon display
- ❌ Multi-coupon support (apply multiple)

**Required Implementation:**
```go
// ✅ REQUIRED: Auto-apply coupon logic
type CouponAutoApply struct {
    Enabled              bool
    SelectBest           bool                   // Auto-select best discount
    ShowAvailable        bool                   // Show available coupons to customer
    MaxCouponsPerOrder   int                    // Allow multiple coupons
}

// API endpoints needed:
- GET /api/v1/promotion/coupons/available?customer_id={id}&cart_amount={amount}
- POST /api/v1/promotion/coupons/auto-apply
- GET /api/v1/promotion/coupons/export?format=csv
- POST /api/v1/promotion/coupons/import
```

**Implementation Tasks:**
- [ ] Implement auto-apply best coupon logic
- [ ] Create available coupons API
- [ ] Add coupon import/export functionality
- [ ] Support multiple coupons per order
- [ ] Show available coupons in checkout
- [ ] Add coupon stacking rules

**Test Scenarios:**
- [ ] Auto-apply best of 3 coupons
- [ ] Display 5 available coupons
- [ ] Apply 2 stackable coupons
- [ ] Import 1000 coupons from CSV

**Dependencies:** Order/Cart service integration  
**Estimated Time:** 2-3 days  
**Priority:** 🟡 **Medium**

---

## 🚀 Advanced Features

### 14. Rule Priority & Stop Processing

#### ✅ **IMPLEMENTED: Priority System**

**Current Implementation:**
- ✅ Campaign priority
- ✅ Stackable vs non-stackable rules
- ✅ Best discount selection

**Status:** **100% Complete** ✅

---

### 15. Stop Rules Processing

#### ❌ **MISSING: Stop Processing Flag**

**Magento Feature:**
- Stop further rules from being processed after this one applies
- Prevents rule stacking when desired

**Required:**
```go
// ✅ REQUIRED: Add to actions
type CartActions struct {
    // ... existing fields ...
    StopRulesProcessing  bool                   // ⭐ NEW
}

type CatalogActions struct {
    // ... existing fields ...
    StopRulesProcessing  bool                   // ⭐ NEW
}
```

**Implementation Tasks:**
- [ ] Add StopRulesProcessing field
- [ ] Implement processing halt logic
- [ ] Update rule evaluation engine
- [ ] Add tests for rule cascading

**Dependencies:** None  
**Estimated Time:** 0.5 day  
**Priority:** 🟢 **Low**

---

### 16. Promotion Labels & Messages

#### ❌ **MISSING: Promotion Banners/Labels**

**Amasty Features:**
- Product labels ("20% OFF!", "SALE!")
- Promotional banners
- Custom messages on product/cart
- Highlight promotions visually

**Required Structure:**
```go
// ✅ REQUIRED: Promotion display settings
type PromotionDisplay struct {
    ShowLabel            bool                   // ⭐ NEW
    LabelText            string                 // ⭐ NEW (e.g., "20% OFF")
    LabelColor           string                 // ⭐ NEW (hex color)
    LabelPosition        string                 // ⭐ NEW ("product", "cart", "both")
    BannerText           string                 // ⭐ NEW
    BannerImageURL       string                 // ⭐ NEW
    HighlightPromotion   bool                   // ⭐ NEW
}

// Add to Promotion:
type Promotion struct {
    // ... existing fields ...
    Display              *PromotionDisplay      // ⭐ NEW
}
```

**Implementation Tasks:**
- [ ] Add PromotionDisplay struct
- [ ] Store label/banner configuration
- [ ] Create API to fetch promotion displays
- [ ] Integrate with frontend
- [ ] Support custom styling

**Test Scenarios:**
- [ ] Show "50% OFF" label on product
- [ ] Display banner in cart
- [ ] Custom color labels
- [ ] Multiple promotions with labels

**Dependencies:** Frontend integration  
**Estimated Time:** 2 days  
**Priority:** 🟢 **Low**

---

### 17. A/B Testing for Promotions

#### 🟡 **PARTIAL: A/B Testing Support**

**Current State:**
- Config mentions A/B testing enabled
- No actual implementation

**Required:**
```go
// ✅ REQUIRED: A/B testing configuration
type ABTestConfig struct {
    Enabled              bool
    VariantA             *Promotion             // Control
    VariantB             *Promotion             // Test
    TrafficSplit         int                    // % for variant B (0-100)
    StartDate            time.Time
    EndDate              time.Time
    WinnerCriteria       string                 // "conversion", "revenue", "usage"
}

type ABTestMetrics struct {
    VariantID            string
    Impressions          int64
    Conversions          int64
    Revenue              float64
    ConversionRate       float64
    AverageOrderValue    float64
}
```

**Implementation Tasks:**
- [ ] Implement traffic splitting logic
- [ ] Track metrics per variant
- [ ] Create A/B test creation API
- [ ] Build analytics for A/B tests
- [ ] Auto-declare winner based on criteria

**Dependencies:** Analytics system  
**Estimated Time:** 4-5 days  
**Priority:** 🟢 **Low**

---

### 18. Promotion Schedules & Recurrence

#### 🟡 **PARTIAL: Time-Based Promotions**

**Current State:**
- ✅ Start/End dates
- ❌ Recurring promotions
- ❌ Time-of-day restrictions
- ❌ Day-of-week restrictions

**Required:**
```go
// ✅ REQUIRED: Scheduling configuration
type PromotionSchedule struct {
    StartDate            time.Time              // ✅ Existing
    EndDate              time.Time              // ✅ Existing
    
    // ⭐ NEW: Recurring schedule
    IsRecurring          bool                   // ⭐ NEW
    RecurrenceType       string                 // ⭐ NEW ("daily", "weekly", "monthly")
    RecurrenceDays       []string               // ⭐ NEW (["monday", "friday"])
    RecurrenceWeeks      []int                  // ⭐ NEW ([1, 3] = 1st and 3rd week)
    
    // ⭐ NEW: Time restrictions
    TimeOfDayStart       *string                // ⭐ NEW ("09:00")
    TimeOfDayEnd         *string                // ⭐ NEW ("17:00")
    Timezone             string                 // ⭐ NEW ("America/New_York")
    
    // ⭐ NEW: Exclusions
    ExcludeDates         []time.Time            // ⭐ NEW (exclude specific dates)
}
```

**Examples:**
- Every Monday 9AM-5PM
- First week of every month
- Weekends only
- Exclude holidays

**Implementation Tasks:**
- [ ] Add scheduling fields to database
- [ ] Implement recurrence logic
- [ ] Implement time-of-day restrictions
- [ ] Handle timezone conversions
- [ ] Add holiday exclusions
- [ ] Create schedule validation

**Test Scenarios:**
- [ ] Happy Hour: Daily 5PM-7PM
- [ ] Weekend Flash Sale: Sat-Sun only
- [ ] Monthly Sale: 1st-5th of each month
- [ ] Exclude Black Friday from regular discount

**Dependencies:** None  
**Estimated Time:** 2-3 days  
**Priority:** 🟡 **Medium**

---

## 📊 Analytics & Reporting

### 19. Enhanced Analytics

#### 🟡 **PARTIAL: Analytics Features**

**Current Implementation:**
- ✅ Campaign analytics (basic)
- ✅ Promotion usage stats
- ✅ Coupon usage tracking

**Missing:**
- ❌ ROI calculation
- ❌ Conversion funnel tracking
- ❌ Customer lifetime value impact
- ❌ Promotion performance comparison
- ❌ Export reports

**Required APIs:**
```go
// ✅ REQUIRED: Enhanced analytics
type PromotionROI struct {
    PromotionID          string
    Revenue              float64                // Revenue from promotion
    DiscountGiven        float64                // Total discount amount
    OrderCount           int64                  // Orders with promotion
    CustomerCount        int64                  // Unique customers
    ROI                  float64                // (Revenue - Discount) / Discount
    AverageOrderValue    float64
    ConversionRate       float64
    AttachRate           float64                // % of orders using promotion
}

// New endpoints:
- GET /api/v1/promotion/analytics/roi?promotion_id={id}
- GET /api/v1/promotion/analytics/comparison?ids={id1},{id2}
- GET /api/v1/promotion/analytics/export?format=csv&type=roi
```

**Implementation Tasks:**
- [ ] Implement ROI calculation
- [ ] Track conversion funnel
- [ ] Add customer LTV impact tracking
- [ ] Create comparison API
- [ ] Add export functionality (CSV, PDF)
- [ ] Build dashboard summary

**Dependencies:** Order service, Customer service  
**Estimated Time:** 3-4 days  
**Priority:** 🟡 **Medium**

---

## 🔗 Integration & Performance

### 20. Service Integration

#### 🟡 **PARTIAL: External Service Integration**

**Current Integrations:**
- ❌ Catalog service (product info)
- ❌ Pricing service (price calculation)
- ❌ Customer service (customer data)
- ❌ Order service (order application)
- ❌ Shipping service (free shipping)

**Required Clients:**
```go
// ✅ REQUIRED: Service clients
type CatalogClient interface {
    GetProduct(ctx context.Context, id string) (*Product, error)
    GetProducts(ctx context.Context, ids []string) ([]*Product, error)
    GetProductsByCategory(ctx context.Context, categoryID string) ([]*Product, error)
    GetProductAttributes(ctx context.Context, productID string) (map[string]interface{}, error)
}

type PricingClient interface {
    GetPrice(ctx context.Context, productID, customerGroup string) (*Price, error)
    ApplyCatalogRule(ctx context.Context, productID, ruleID string) (*Price, error)
}

type CustomerClient interface {
    GetCustomer(ctx context.Context, id string) (*Customer, error)
    GetCustomerOrderHistory(ctx context.Context, id string) (*OrderHistory, error)
    GetCustomerSegments(ctx context.Context, id string) ([]string, error)
}

type OrderClient interface {
    ApplyPromotion(ctx context.Context, orderID, promotionID string) error
    ValidatePromotionEligibility(ctx context.Context, orderID string, promo *Promotion) (bool, error)
}

type ShippingClient interface {
    ApplyFreeShipping(ctx context.Context, orderID string, method string) error
    GetShippingMethods(ctx context.Context, orderID string) ([]*ShippingMethod, error)
}
```

**Implementation Tasks:**
- [ ] Implement Catalog client (gRPC)
- [ ] Implement Pricing client (gRPC)
- [ ] Implement Customer client (gRPC)
- [ ] Implement Order client (gRPC)
- [ ] Implement Shipping client (gRPC)
- [ ] Add circuit breakers
- [ ] Add retry logic
- [ ] Add caching layer

**Dependencies:** All microservices  
**Estimated Time:** 5-6 days  
**Priority:** 🔴 **Critical**

---

### 21. Caching Strategy

#### 🟡 **PARTIAL: Redis Caching**

**Current State:**
- Redis configured
- Basic caching implemented
- Cache TTL: 300s (5 minutes)

**Improvements Needed:**
```go
// ✅ REQUIRED: Multi-layer caching
type CacheStrategy struct {
    // L1: In-memory cache (fastest)
    MemoryCache          *sync.Map
    MemoryCacheTTL       time.Duration          // 1 minute
    
    // L2: Redis cache
    RedisCache           *redis.Client
    RedisCacheTTL        time.Duration          // 5 minutes
    
    // Cache keys
    ActivePromotionsCacheKey    string
    CatalogPriceIndexCacheKey   string
    CouponValidationCacheKey    string
}

// Cache invalidation strategies:
- Invalidate on promotion update
- Invalidate on promotion activation/deactivation
- Scheduled cache refresh
- Event-driven invalidation (Dapr pub/sub)
```

**Implementation Tasks:**
- [ ] Implement multi-layer caching
- [ ] Add cache warming on startup
- [ ] Implement cache invalidation strategies
- [ ] Add cache metrics (hit/miss rate)
- [ ] Optimize cache TTLs per use case
- [ ] Event-driven cache invalidation

**Dependencies:** Redis  
**Estimated Time:** 2-3 days  
**Priority:** 🟡 **Medium**

---

### 22. Performance Optimization

#### 🟡 **PARTIAL: Performance Features**

**Current State:**
- Database indexes exist
- Basic query optimization

**Required Optimizations:**
```sql
-- ✅ REQUIRED: Additional indexes
CREATE INDEX idx_promotions_active_priority ON promotions(is_active, priority DESC) 
    WHERE is_active = TRUE;

CREATE INDEX idx_promotions_dates_active ON promotions(starts_at, ends_at, is_active) 
    WHERE is_active = TRUE;

CREATE INDEX idx_coupons_code_active ON coupons(code, is_active, expires_at) 
    WHERE is_active = TRUE;

-- Partial indexes for common queries
CREATE INDEX idx_promotions_cart_rules ON promotions(rule_type, is_active) 
    WHERE rule_type = 'cart' AND is_active = TRUE;

CREATE INDEX idx_promotions_catalog_rules ON promotions(rule_type, is_active) 
    WHERE rule_type = 'catalog' AND is_active = TRUE;
```

**Implementation Tasks:**
- [ ] Add optimized database indexes
- [ ] Implement query result caching
- [ ] Optimize JSONB queries
- [ ] Add database connection pooling
- [ ] Implement read replicas support
- [ ] Add query performance monitoring

**Dependencies:** PostgreSQL  
**Estimated Time:** 2 days  
**Priority:** 🟡 **Medium**

---

## 📋 Implementation Priority

### 🔴 **Phase 1: Critical Features (Weeks 1-4)**

**Must-have for production:**

1. **Cart & Catalog Rule Separation** (Week 1)
   - [ ] Add RuleType field
   - [ ] Implement CartConditions
   - [ ] Implement CatalogConditions
   - **Time:** 3 days

2. **Catalog Price Indexing** (Week 1-2)
   - [ ] Create price index table
   - [ ] Implement indexing engine
   - [ ] Integrate with Catalog service
   - **Time:** 5 days

3. **Buy X Get Y** (Week 2)
   - [ ] Implement BOGO logic
   - [ ] Support all BOGO variants
   - **Time:** 4 days

4. **Tiered Discounts** (Week 3)
   - [ ] Implement quantity tiers
   - [ ] Implement amount tiers
   - [ ] Each Nth item logic
   - **Time:** 3 days

5. **Advanced Cart Conditions** (Week 3)
   - [ ] Cart totals conditions
   - [ ] Shipping/geographic conditions
   - **Time:** 3 days

6. **Product Attribute Conditions** (Week 4)
   - [ ] Attribute matching
   - [ ] Price range conditions
   - **Time:** 4 days

7. **Service Integration** (Week 4)
   - [ ] All service clients
   - [ ] Circuit breakers, retries
   - **Time:** 5 days

**Total: ~27 days (4 weeks with parallel work)**

---

### 🟡 **Phase 2: Important Features (Weeks 5-7)**

**Should-have for better features:**

8. **Free Shipping Actions** (Week 5)
   - **Time:** 3 days

9. **Customer History Conditions** (Week 5)
   - **Time:** 4 days

10. **Customer Attribute Conditions** (Week 6)
    - **Time:** 3 days

11. **Cheapest/Most Expensive Logic** (Week 6)
    - **Time:** 2 days

12. **Free Gift Actions** (Week 6)
    - **Time:** 3 days

13. **Advanced Coupon Features** (Week 7)
    - **Time:** 3 days

14. **Promotion Schedules** (Week 7)
    - **Time:** 3 days

15. **Enhanced Analytics** (Week 7)
    - **Time:** 4 days

**Total: ~25 days (3 weeks with parallel work)**

---

### 🟢 **Phase 3: Nice-to-Have (Weeks 8-9)**

**Good-to-have for completeness:**

16. **A/B Testing** (Week 8)
    - **Time:** 5 days

17. **Promotion Labels/Banners** (Week 8)
    - **Time:** 2 days

18. **Stop Rules Processing** (Week 9)
    - **Time:** 1 day

19. **Performance Optimization** (Week 9)
    - **Time:** 2 days

20. **Advanced Caching** (Week 9)
    - **Time:** 3 days

**Total: ~13 days (2 weeks)**

---

## 📊 Summary

### Overall Timeline: **9 weeks**

- **Phase 1 (Critical):** 4 weeks
- **Phase 2 (Important):** 3 weeks
- **Phase 3 (Nice-to-have):** 2 weeks

### Resource Requirements:

- **Backend Developers:** 2-3 engineers
- **QA Engineers:** 1 engineer
- **DevOps:** 0.5 engineer (part-time)

### Success Criteria:

- [ ] Feature parity with Magento 2 Cart Price Rules (90%+)
- [ ] Feature parity with Magento 2 Catalog Price Rules (80%+)
- [ ] Feature parity with Amasty Special Promotions (70%+)
- [ ] Performance: Promotion validation \u003c 100ms (p99)
- [ ] Catalog price index update \u003c 5 minutes
- [ ] Support 1000+ concurrent promotion validations
- [ ] Test coverage \u003e 80%

---

## 🎯 Quick Wins (Can Start Immediately)

These features can be implemented quickly for immediate value:

1. **Stop Rules Processing** - 0.5 day
2. **Item Selection (Cheapest/Most Expensive)** - 1-2 days
3. **Enhanced Indexes** - 0.5 day
4. **Basic Tiered Discounts** - 2 days

---

**Generated:** 2025-11-19  
**Status:** Ready for Implementation  
**Next Steps:** Review \u0026 Prioritize with stakeholders
