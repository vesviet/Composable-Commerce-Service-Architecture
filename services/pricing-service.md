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