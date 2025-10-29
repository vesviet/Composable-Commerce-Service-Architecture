# Search Service

## Description
Service that provides fast product, price, and promotion search capabilities using Elasticsearch.

## Core Responsibilities
- Product catalog indexing and search
- Real-time search suggestions and autocomplete
- Faceted search and filtering
- Search analytics and optimization
- Personalized search results
- Search performance monitoring

## Outbound Data
- Search results and rankings
- Search suggestions and autocomplete
- Faceted search filters
- Search analytics data
- Personalized recommendations

## Consumers (Services that use this data)

### Frontend/API Gateway
- **Purpose**: Provide search functionality to users
- **Data Received**: Search results, filters, suggestions

### Product Service
- **Purpose**: Get search analytics for product optimization
- **Data Received**: Search trends, popular products

## Data Sources

### Product Service
- **Purpose**: Index product catalog data
- **Data Received**: Product details, attributes, categories, availability

### Pricing Service
- **Purpose**: Index current pricing information
- **Data Received**: Product prices, promotional prices

### Promotion Service
- **Purpose**: Index active promotions and offers
- **Data Received**: Promotion details, discount information

### Warehouse & Inventory Service
- **Purpose**: Index stock availability
- **Data Received**: Stock levels, availability status

### Customer Service
- **Purpose**: Personalize search results
- **Data Received**: Customer preferences, purchase history

## Main APIs
- `GET /search/products` - Search products with filters
- `GET /search/suggest` - Get search suggestions
- `GET /search/autocomplete` - Autocomplete search queries
- `POST /search/index` - Index new/updated products
- `DELETE /search/index/{id}` - Remove from index
- `GET /search/analytics` - Get search analytics

## Search Features
- Full-text search with relevance scoring
- Faceted search (category, price, brand, etc.)
- Geo-location based search
- Voice search support
- Visual search capabilities
- Machine learning-powered recommendations

## Performance Optimization
- Elasticsearch cluster management
- Search result caching
- Query optimization
- Index management and maintenance
- Real-time data synchronization