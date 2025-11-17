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

### Redis Cluster Setup
- **Cluster Mode**: Redis Cluster for high availability
- **Nodes**: 6 nodes (3 masters, 3 replicas)
- **Memory**: 16GB+ per node
- **Persistence**: RDB snapshots + AOF logging
- **Eviction**: LRU policy for memory management

### Performance Tuning
- **Connection Pooling**: Maintain persistent connections
- **Pipeline Operations**: Batch multiple commands
- **Compression**: Enable compression for large values
- **Memory Optimization**: Use appropriate data structures

### Monitoring & Alerts
- **Redis Metrics**: Memory usage, hit rates, connections
- **Performance Alerts**: Slow queries, high memory usage
- **Health Checks**: Continuous availability monitoring
- **Capacity Planning**: Proactive scaling based on usage

## Integration with Services

### Service-Specific Caching

#### Catalog Service Caching
```json
{
  "cache_keys": {
    "product_details": "catalog:product:{product_id}",
    "category_tree": "catalog:categories:tree",
    "brand_info": "catalog:brand:{brand_id}",
    "product_attributes": "catalog:product:{product_id}:attributes"
  },
  "ttl": {
    "product_details": 3600,
    "category_tree": 7200,
    "brand_info": 3600,
    "product_attributes": 1800
  }
}
```

#### Pricing Service Caching
```json
{
  "cache_keys": {
    "product_price": "pricing:product:{product_id}:warehouse:{warehouse_id}:customer:{customer_id}",
    "promotion_rules": "pricing:promotions:active",
    "customer_tier": "pricing:customer:{customer_id}:tier"
  },
  "ttl": {
    "product_price": 300,
    "promotion_rules": 600,
    "customer_tier": 1800
  }
}
```

#### Search Service Caching
```json
{
  "cache_keys": {
    "search_results": "search:query:{query_hash}:filters:{filter_hash}",
    "popular_searches": "search:popular:daily",
    "search_suggestions": "search:suggestions:{prefix}"
  },
  "ttl": {
    "search_results": 900,
    "popular_searches": 3600,
    "search_suggestions": 1800
  }
}
```

## Cache Invalidation Strategies

### Event-Driven Invalidation
```javascript
// Example: Product update invalidation
eventBus.on('catalog.product.updated', async (event) => {
  const productId = event.data.productId;
  
  // Invalidate related cache keys
  await cache.del([
    `catalog:product:${productId}`,
    `catalog:product:${productId}:attributes`,
    `pricing:product:${productId}:*`,
    `search:*` // Invalidate search results containing this product
  ]);
});
```

### Time-Based Invalidation
- **Short TTL**: Frequently changing data (pricing, inventory)
- **Medium TTL**: Moderately changing data (product details)
- **Long TTL**: Rarely changing data (categories, brands)

### Manual Invalidation
- **Admin Interface**: Manual cache clearing for specific keys
- **API Endpoints**: Programmatic cache invalidation
- **Bulk Operations**: Clear cache for multiple related keys