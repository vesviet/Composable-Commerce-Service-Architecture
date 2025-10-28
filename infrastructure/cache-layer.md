# Cache Layer (Redis)

## Description
Distributed caching system that improves performance by storing frequently accessed data in memory.

## Core Responsibilities
- Cache frequently accessed data
- Session storage
- Rate limiting counters
- Temporary data storage
- Pub/Sub messaging
- Distributed locking

## Cached Data Types

### Product Data
- Product details and attributes
- Product availability status
- Category hierarchies
- Product images and media URLs

### Pricing Data
- Calculated product prices
- Promotional pricing
- Customer-specific pricing
- Price calculation results

### Customer Data
- Customer profiles
- Shopping cart contents
- Customer preferences
- Authentication tokens

### Search Data
- Search results
- Popular search queries
- Search suggestions
- Faceted search filters

## Cache Strategies

### Cache-Aside Pattern
- Application manages cache explicitly
- Used for product and customer data
- TTL: 1-24 hours depending on data type

### Write-Through Pattern
- Data written to cache and database simultaneously
- Used for critical data like inventory
- Ensures data consistency

### Write-Behind Pattern
- Data written to cache immediately, database later
- Used for high-frequency updates
- Better performance, eventual consistency

## Configuration
- **Cluster Mode**: Redis Cluster for high availability
- **Memory**: 16GB+ per node
- **Persistence**: RDB snapshots + AOF logging
- **Eviction**: LRU policy for memory management
- **Monitoring**: Redis metrics and alerts