# Promotion Service

## Description
Service that handles promotions, discounts and promotional programs.

## Outbound Data
- Active promotion rules
- Promo conditions and requirements
- Discount strategies (by warehouse or customer segment)

## Consumers (Services that use this data)

### Order Service
- **Purpose**: Apply promotions during checkout process
- **Data Received**: Discount rules, promo codes, conditions

### Product Service
- **Purpose**: Update displayed discount price
- **Data Received**: Price adjustments, promotional pricing

### Customer Service
- **Purpose**: Enable personalized promotions
- **Data Received**: Customer-specific offers, loyalty discounts

## Data Sources
- **Customer Service**: Customer profile and segment data
- **Catalog Service**: Product SKU, category, brand information for targeted promotions
- **Warehouse & Inventory Service**: Warehouse-specific promotion rules and inventory levels

## Promotion Configuration
- **SKU-based Promotions**: Discounts configured per specific SKU
- **Warehouse-based Promotions**: Different promotions per warehouse/region
- **Category/Brand Promotions**: Promotions based on product categories or brands
- **Customer Segment Promotions**: Targeted offers based on customer groups

## Main APIs
- `GET /promotions/active` - Get active promotions
- `POST /promotions/validate` - Validate promo code
- `GET /promotions/customer/{id}` - Get promotions for customer
- `POST /promotions/apply` - Apply promotion to order