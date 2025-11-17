# Pricing Service

## Description
Service that calculates final product prices by applying promotion rules, discounts, and dynamic pricing strategies.

## Core Responsibilities
- Calculate final product prices in real-time
- Apply promotion rules and discount logic
- Handle dynamic pricing based on inventory, demand, or customer segments
- Manage price tiers and bulk pricing
- Process tax calculations

## Outbound Data
- Final calculated prices
- Applied discount amounts
- Tax calculations
- Price breakdown details
- Pricing history and audit trail

## Consumers (Services that use this data)

### Order Service
- **Purpose**: Get final prices during checkout process
- **Data Received**: Calculated prices, applied discounts, tax amounts

### Product Service
- **Purpose**: Display current prices on product pages
- **Data Received**: Real-time pricing, promotional prices

### Customer Service
- **Purpose**: Show personalized pricing based on customer tier
- **Data Received**: Customer-specific pricing, loyalty discounts

## Data Sources

### Catalog Service
- **Purpose**: Get product SKU and attribute information
- **Data Received**: Product SKU, category, brand, attributes

### Promotion Service
- **Purpose**: Get active promotion rules and discount conditions
- **Data Received**: Promotion rules, discount percentages, coupon codes

### Customer Service
- **Purpose**: Apply customer-specific pricing
- **Data Received**: Customer segments, loyalty tiers, purchase history

### Warehouse & Inventory Service
- **Purpose**: Get warehouse-specific pricing configuration
- **Data Received**: Warehouse locations, regional pricing, stock levels

## 📡 API Specification

### Base URL
```
Production: https://api.domain.com/v1/pricing
Staging: https://staging-api.domain.com/v1/pricing
Local: http://localhost:8002/v1/pricing
```

### Authentication
- **Type**: JWT Bearer Token
- **Required Scopes**: `pricing:read`, `pricing:write`
- **Rate Limiting**: 2000 requests/minute per user

### Core Pricing APIs

#### POST /calculate
**Purpose**: Calculate final price for products with all applicable discounts

**Request**:
```http
POST /v1/pricing/calculate
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "items": [
    {
      "productId": "prod_123",
      "sku": "LAPTOP-001",
      "quantity": 2,
      "warehouseId": "WH001"
    },
    {
      "productId": "prod_124", 
      "sku": "MOUSE-001",
      "quantity": 1,
      "warehouseId": "WH001"
    }
  ],
  "customerId": "cust_456",
  "customerTier": "premium",
  "couponCode": "SAVE20",
  "context": {
    "channel": "web",
    "region": "US",
    "currency": "USD"
  }
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "pricing": {
      "items": [
        {
          "productId": "prod_123",
          "sku": "LAPTOP-001",
          "quantity": 2,
          "basePrice": 1299.99,
          "unitPrice": 1299.99,
          "discounts": [
            {
              "type": "customer_tier",
              "name": "Premium Customer Discount",
              "amount": 130.00,
              "percentage": 10
            },
            {
              "type": "bulk_discount",
              "name": "Buy 2+ Laptops",
              "amount": 50.00,
              "percentage": null
            }
          ],
          "finalUnitPrice": 1119.99,
          "totalPrice": 2239.98,
          "tax": {
            "rate": 8.25,
            "amount": 184.80
          }
        },
        {
          "productId": "prod_124",
          "sku": "MOUSE-001", 
          "quantity": 1,
          "basePrice": 49.99,
          "unitPrice": 49.99,
          "discounts": [],
          "finalUnitPrice": 49.99,
          "totalPrice": 49.99,
          "tax": {
            "rate": 8.25,
            "amount": 4.12
          }
        }
      ],
      "summary": {
        "subtotal": 2289.97,
        "totalDiscounts": 180.00,
        "subtotalAfterDiscounts": 2289.97,
        "totalTax": 188.92,
        "grandTotal": 2478.89,
        "currency": "USD"
      },
      "appliedPromotions": [
        {
          "id": "promo_001",
          "name": "Premium Customer Discount",
          "type": "customer_tier"
        }
      ],
      "appliedCoupons": [],
      "validUntil": "2024-01-15T11:00:00Z"
    }
  },
  "meta": {
    "requestId": "req_pricing_123",
    "timestamp": "2024-01-15T10:30:00Z",
    "processingTime": "45ms"
  }
}
```

#### GET /products/{productId}/price
**Purpose**: Get current price for a specific product

**Request**:
```http
GET /v1/pricing/products/prod_123/price?warehouseId=WH001&customerId=cust_456&quantity=1
Authorization: Bearer {jwt_token}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "pricing": {
      "productId": "prod_123",
      "sku": "LAPTOP-001",
      "basePrice": 1299.99,
      "finalPrice": 1169.99,
      "discounts": [
        {
          "type": "customer_tier",
          "amount": 130.00,
          "percentage": 10
        }
      ],
      "currency": "USD",
      "warehouseId": "WH001",
      "validUntil": "2024-01-15T11:00:00Z"
    }
  }
}
```

#### POST /bulk-calculate
**Purpose**: Calculate prices for multiple products efficiently

#### GET /price-history/{productId}
**Purpose**: Get pricing history for analytics

### Price Management APIs

#### GET /base-prices
**Purpose**: Get base prices for products

#### POST /base-prices
**Purpose**: Set base prices for products

**Request**:
```http
POST /v1/pricing/base-prices
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "prices": [
    {
      "productId": "prod_123",
      "sku": "LAPTOP-001",
      "warehouseId": "WH001",
      "basePrice": 1299.99,
      "currency": "USD",
      "effectiveFrom": "2024-01-15T00:00:00Z",
      "effectiveTo": null
    }
  ]
}
```

#### PUT /base-prices/{priceId}
**Purpose**: Update base price

#### DELETE /base-prices/{priceId}
**Purpose**: Deactivate base price

### Customer Tier Pricing APIs

#### GET /customer-tiers
**Purpose**: Get customer tier configurations

#### POST /customer-tiers
**Purpose**: Create customer tier pricing rules

### Dynamic Pricing APIs

#### GET /dynamic-rules
**Purpose**: Get dynamic pricing rules

#### POST /dynamic-rules
**Purpose**: Create dynamic pricing rules

## 🗄️ Database Schema

### Primary Database: PostgreSQL

#### base_prices
```sql
CREATE TABLE base_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    sku VARCHAR(100) NOT NULL,
    warehouse_id VARCHAR(50) NOT NULL,
    base_price DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    effective_from TIMESTAMP WITH TIME ZONE NOT NULL,
    effective_to TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    
    -- Constraints
    CONSTRAINT unique_product_warehouse_effective UNIQUE (product_id, warehouse_id, effective_from),
    
    -- Indexes
    INDEX idx_base_prices_product (product_id),
    INDEX idx_base_prices_sku (sku),
    INDEX idx_base_prices_warehouse (warehouse_id),
    INDEX idx_base_prices_effective (effective_from, effective_to),
    INDEX idx_base_prices_status (status)
);
```

#### customer_tier_pricing
```sql
CREATE TABLE customer_tier_pricing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tier_name VARCHAR(50) NOT NULL,
    product_id UUID,
    category_id UUID,
    brand_id UUID,
    warehouse_id VARCHAR(50),
    discount_type VARCHAR(20) NOT NULL, -- percentage, fixed_amount
    discount_value DECIMAL(10,2) NOT NULL,
    min_quantity INTEGER DEFAULT 1,
    max_quantity INTEGER,
    effective_from TIMESTAMP WITH TIME ZONE NOT NULL,
    effective_to TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_customer_tier_tier (tier_name),
    INDEX idx_customer_tier_product (product_id),
    INDEX idx_customer_tier_effective (effective_from, effective_to)
);
```

#### dynamic_pricing_rules
```sql
CREATE TABLE dynamic_pricing_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    rule_type VARCHAR(50) NOT NULL, -- inventory_based, demand_based, time_based
    conditions JSONB NOT NULL,
    actions JSONB NOT NULL,
    priority INTEGER DEFAULT 0,
    product_id UUID,
    category_id UUID,
    warehouse_id VARCHAR(50),
    effective_from TIMESTAMP WITH TIME ZONE NOT NULL,
    effective_to TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_dynamic_rules_type (rule_type),
    INDEX idx_dynamic_rules_priority (priority),
    INDEX idx_dynamic_rules_effective (effective_from, effective_to)
);
```

#### pricing_history
```sql
CREATE TABLE pricing_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
    sku VARCHAR(100) NOT NULL,
    warehouse_id VARCHAR(50) NOT NULL,
    customer_id UUID,
    base_price DECIMAL(10,2) NOT NULL,
    final_price DECIMAL(10,2) NOT NULL,
    discounts JSONB DEFAULT '[]',
    context JSONB DEFAULT '{}',
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_pricing_history_product (product_id),
    INDEX idx_pricing_history_customer (customer_id),
    INDEX idx_pricing_history_calculated (calculated_at),
    
    -- Partitioning by month for performance
    PARTITION BY RANGE (calculated_at)
);
```

### Cache Schema (Redis)
```
# Product price cache
Key: pricing:product:{product_id}:{warehouse_id}:{customer_tier}
TTL: 300 seconds (5 minutes)
Value: JSON serialized price data

# Bulk pricing cache
Key: pricing:bulk:{hash_of_request}
TTL: 180 seconds (3 minutes)
Value: JSON serialized bulk pricing response

# Customer tier cache
Key: pricing:customer_tier:{customer_id}
TTL: 3600 seconds (1 hour)
Value: Customer tier information

# Dynamic rules cache
Key: pricing:dynamic_rules:{product_id}:{warehouse_id}
TTL: 600 seconds (10 minutes)
Value: Applicable dynamic pricing rules
```

## 🧮 Pricing Calculation Logic

### Core Calculation Flow
```
1. Get Base Price (SKU + Warehouse)
   ↓
2. Apply Customer Tier Discounts
   ↓
3. Apply Bulk/Quantity Discounts
   ↓
4. Apply Dynamic Pricing Rules
   ↓
5. Apply Promotion Discounts
   ↓
6. Apply Coupon Discounts
   ↓
7. Calculate Tax
   ↓
8. Return Final Price
```

### Pricing Rules Priority
1. **Base Price** (Highest Priority)
2. **Customer Tier Pricing**
3. **Bulk/Quantity Discounts**
4. **Dynamic Pricing Rules** (by priority order)
5. **Promotion Discounts**
6. **Coupon Discounts** (Lowest Priority)

### Dynamic Pricing Examples

#### Inventory-Based Pricing
```json
{
  "rule_type": "inventory_based",
  "conditions": {
    "stock_level": {"operator": "lt", "value": 10},
    "warehouse_id": "WH001"
  },
  "actions": {
    "price_adjustment": {
      "type": "percentage_increase",
      "value": 5
    }
  }
}
```

#### Demand-Based Pricing
```json
{
  "rule_type": "demand_based", 
  "conditions": {
    "view_count_24h": {"operator": "gt", "value": 1000},
    "conversion_rate": {"operator": "gt", "value": 0.05}
  },
  "actions": {
    "price_adjustment": {
      "type": "percentage_increase",
      "value": 3
    }
  }
}
```

#### Time-Based Pricing
```json
{
  "rule_type": "time_based",
  "conditions": {
    "time_range": {
      "start": "18:00",
      "end": "22:00"
    },
    "days": ["friday", "saturday"]
  },
  "actions": {
    "price_adjustment": {
      "type": "percentage_decrease", 
      "value": 10
    }
  }
}
```

## 📨 Event Schemas

### Published Events

#### PriceCalculated
**Topic**: `pricing.price.calculated`
**Version**: 1.0

```json
{
  "eventId": "evt_pricing_123",
  "eventType": "PriceCalculated",
  "version": "1.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "source": "pricing-service",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "warehouseId": "WH001",
    "customerId": "cust_456",
    "basePrice": 1299.99,
    "finalPrice": 1169.99,
    "discounts": [
      {
        "type": "customer_tier",
        "amount": 130.00
      }
    ],
    "currency": "USD",
    "calculatedAt": "2024-01-15T10:30:00Z"
  },
  "metadata": {
    "correlationId": "corr_789",
    "processingTime": "45ms"
  }
}
```

#### BasePriceUpdated
**Topic**: `pricing.base_price.updated`
**Version**: 1.0

```json
{
  "eventId": "evt_price_update_124",
  "eventType": "BasePriceUpdated", 
  "version": "1.0",
  "timestamp": "2024-01-15T10:35:00Z",
  "source": "pricing-service",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "warehouseId": "WH001",
    "oldPrice": 1199.99,
    "newPrice": 1299.99,
    "currency": "USD",
    "effectiveFrom": "2024-01-16T00:00:00Z",
    "updatedBy": "user_456"
  }
}
```

### Subscribed Events

#### ProductCreated
**Topic**: `catalog.product.created`
**Source**: catalog-cms-service

#### InventoryUpdated  
**Topic**: `inventory.stock.updated`
**Source**: warehouse-inventory-service

#### CustomerTierChanged
**Topic**: `customer.tier.changed`
**Source**: customer-service

## ⚡ Performance Optimizations

### Caching Strategy
- **L1 Cache**: In-memory cache for frequently accessed prices (5 minutes TTL)
- **L2 Cache**: Redis cache for calculated prices (5 minutes TTL)
- **L3 Cache**: Database query result cache (10 minutes TTL)

### Bulk Processing
- Process multiple price calculations in parallel
- Batch database queries for base prices
- Cache customer tier information

### Price Calculation Optimization
- Pre-calculate prices for common scenarios
- Use materialized views for complex pricing rules
- Implement price calculation result caching

## Pricing Configuration
- **SKU-based Pricing**: Base prices configured per SKU
- **Warehouse-based Pricing**: Different prices per warehouse/region
- **Dynamic Pricing**: Real-time price adjustments based on demand/inventory
- **Tier Pricing**: Volume-based pricing tiers

## Pricing Calculation Flow
```
1. Get product SKU and attributes from Catalog Service
2. Retrieve base price configuration for SKU + Warehouse combination
3. Fetch applicable promotions from Promotion Service (based on SKU + Warehouse)
4. Apply customer-specific discounts from Customer Service
5. Consider warehouse-specific pricing rules and inventory adjustments
6. Calculate taxes and fees based on warehouse location
7. Return final price breakdown with applied rules
```

## Main APIs
- `POST /pricing/calculate` - Calculate price for products
- `GET /pricing/product/{id}` - Get current price for product
- `POST /pricing/bulk-calculate` - Calculate prices for multiple products
- `GET /pricing/customer/{id}/product/{productId}` - Get personalized pricing
- `POST /pricing/validate-discount` - Validate discount application
- `GET /pricing/history/{productId}` - Get pricing history

## Pricing Rules Engine
- Rule-based pricing logic
- Support for complex pricing conditions
- A/B testing for pricing strategies
- Time-based pricing (flash sales, seasonal pricing)
- Geographic pricing variations

## Performance Considerations
- Caching frequently requested prices
- Batch processing for bulk price calculations
- Real-time price updates via events
- Price calculation optimization algorithms