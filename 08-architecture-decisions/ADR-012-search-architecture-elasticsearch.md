# ADR-012: Search Architecture (Elasticsearch + Kibana)

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Architecture Team, Search Team, Data Team

## Context

The e-commerce platform requires robust search capabilities for:
- Product catalog search (10,000+ SKUs)
- Full-text search across product descriptions
- Faceted search (categories, brands, price ranges)
- Search analytics and insights
- Real-time search indexing
- Performance requirements (<100ms search response)

We evaluated several search solutions:
- **Elasticsearch + Kibana**: Full-featured search and analytics
- **Solr**: Apache Lucene-based search server
- **Algolia**: Cloud-based search service
- **Database Full-text Search**: PostgreSQL built-in search

## Decision

We will use **Elasticsearch cluster with Kibana** for search and analytics capabilities.

### Search Architecture:
1. **Elasticsearch**: Primary search engine and analytics
2. **Kibana**: Search visualization and management
3. **Search Service**: Dedicated microservice for search operations
4. **Data Pipeline**: Event-driven indexing from Catalog Service
5. **Search API**: RESTful search endpoints via API Gateway

### Elasticsearch Configuration:
- **Cluster**: 3-node cluster for high availability
- **Sharding**: Proper shard distribution for performance
- **Replication**: Replica shards for fault tolerance
- **Mapping**: Optimized field mappings for search relevance
- **Analysis**: Custom analyzers for Vietnamese language support

### Search Indexing Strategy:
- **Event-Driven**: Catalog updates trigger search reindexing
- **Bulk Operations**: Efficient bulk indexing for performance
- **Real-time Updates**: Near real-time search index updates
- **Data Synchronization**: Consistent data between catalog and search
- **Error Handling**: Retry and dead letter queue for failed indexing

### Search Features:
- **Full-text Search**: Product name, description, specifications
- **Faceted Search**: Category, brand, price, rating filters
- **Auto-complete**: Real-time search suggestions
- **Relevance Tuning**: Custom relevance scoring algorithms
- **Search Analytics**: Popular searches, click-through rates

### Data Flow:
```
Catalog Service → Event → Search Service → Elasticsearch → Kibana
```

## Consequences

### Positive:
- ✅ **Performance**: Sub-100ms search response times
- ✅ **Scalability**: Horizontal scaling with cluster architecture
- ✅ **Features**: Rich search capabilities (faceting, suggestions, analytics)
- ✅ **Analytics**: Built-in search analytics and insights
- ✅ **Real-time**: Near real-time indexing and search
- ✅ **Ecosystem**: Rich ecosystem of plugins and integrations

### Negative:
- ⚠️ **Complexity**: Additional infrastructure component to maintain
- ⚠️ **Resource Usage**: Elasticsearch requires significant memory and CPU
- ⚠️ **Data Synchronization**: Need to keep search index in sync with catalog
- ⚠️ **Learning Curve**: Team needs to learn Elasticsearch and Kibana

### Risks:
- **Cluster Management**: Elasticsearch cluster operations complexity
- **Data Consistency**: Search index becoming out of sync with catalog
- **Performance Degradation**: Poor query performance without proper optimization
- **Resource Exhaustion**: Memory-intensive operations affecting cluster stability

## Alternatives Considered

### 1. PostgreSQL Full-text Search
- **Rejected**: Limited search features, performance limitations at scale
- **Pros**: No additional infrastructure, ACID compliance
- **Cons**: Limited search capabilities, performance issues with large datasets

### 2. Apache Solr
- **Rejected**: Elasticsearch has better ecosystem and community support
- **Pros Mature**: Battle-tested, good performance
- **Cons**: Complex configuration, less active community than Elasticsearch

### 3. Algolia
- **Rejected**: High cost, vendor lock-in, limited control
- **Pros**: Excellent performance, easy implementation, great UI
- **Cons**: Expensive, vendor dependency, limited customization

### 4. Database Search + Caching
- **Rejected**: Performance limitations, complex caching logic
- **Pros**: Single source of truth, simpler architecture
- **Cons**: Performance issues, complex cache invalidation

## Implementation Guidelines

- Deploy Elasticsearch cluster with proper resource allocation
- Implement proper field mappings and analyzers for Vietnamese text
- Use event-driven indexing from Catalog Service updates
- Implement search relevance tuning based on user behavior
- Monitor Elasticsearch cluster health and performance
- Use Kibana for search analytics and management
- Implement proper backup and disaster recovery procedures
- Regularly optimize search queries and index performance

## References

- [Elasticsearch Documentation](https://www.elastic.co/guide/)
- [Elasticsearch Best Practices](https://www.elastic.co/guide/en/elasticsearch/guide/current/index.html)
- [Search Architecture Patterns](https://martinfowler.com/articles/search-server.html)
- [E-commerce Search Best Practices](https://www.elastic.co/blog/e-commerce-search-best-practices)
