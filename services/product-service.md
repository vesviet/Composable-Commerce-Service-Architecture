# Catalog Service

## Description
Service that manages product catalog, categories, brands, and product information (excluding pricing).

## Outbound Data
- Product information and attributes
- Category hierarchies and classifications
- Brand information and metadata
- Product specifications and descriptions
- Product media (images, videos)
- Warehouse mapping for products

## Consumers (Services that use this data)

### Pricing Service
- **Purpose**: Get product information for price calculation
- **Data Received**: Product SKU, attributes, category information

### Promotion Service
- **Purpose**: Apply promotion rules based on product attributes
- **Data Received**: Product info, category, brand information

### Order Service  
- **Purpose**: Validate product information and specifications
- **Data Received**: Product details, attributes, specifications

### Warehouse & Inventory Service
- **Purpose**: Map products to warehouse locations
- **Data Received**: Product mapping, warehouse assignments

### Search Service
- **Purpose**: Index products for fast catalog queries
- **Data Received**: Product attributes, categories, brands, searchable fields

## Main APIs
- `GET /catalog/products/{id}` - Get product information
- `GET /catalog/products/search` - Search products by attributes
- `GET /catalog/categories` - Get category hierarchy
- `GET /catalog/brands` - Get brand information
- `GET /catalog/products/{id}/attributes` - Get product attributes
- `GET /catalog/products/category/{categoryId}` - Get products by category