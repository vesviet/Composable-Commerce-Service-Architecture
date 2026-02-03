# ADR-004: Database per Service Pattern

**Date:** 2025-11-17  
**Status:** Accepted  
**Deciders:** Architecture Team, Database Team

## Context

The platform consists of 15+ microservices, each managing different business domains. We need to decide on database strategy:
- Shared database (all services use same database)
- Database per service (each service has its own database)

Shared database creates:
- Tight coupling between services
- Schema conflicts
- Deployment coordination issues
- Performance bottlenecks
- Security concerns (all services access all data)

## Decision

We will use **Database per Service** pattern - each microservice has its own PostgreSQL database.

### Database Allocation:
- **Order Service**: `order_db`
- **Catalog Service**: `catalog_db`
- **Customer Service**: `customer_db`
- **Warehouse Service**: `warehouse_db`
- **Pricing Service**: `pricing_db`
- **Payment Service**: `payment_db`
- **Shipping Service**: `shipping_db`
- **User Service**: `user_db`
- **Auth Service**: `auth_db`
- ... (one database per service)

### Data Ownership:
- Each service **owns** its database schema
- Services **cannot** directly access other services' databases
- Cross-service data access via **APIs** or **Events**

### Data Consistency:
- **Strong Consistency**: Within service boundary (ACID transactions)
- **Eventual Consistency**: Across services (via events)
- **Saga Pattern**: For distributed transactions when needed

## Consequences

### Positive:
- ✅ **Service Autonomy**: Each team owns their database
- ✅ **Independent Deployment**: Deploy database changes without coordination
- ✅ **Technology Flexibility**: Can use different database types per service (currently all PostgreSQL)
- ✅ **Performance Isolation**: Database performance issues don't affect other services
- ✅ **Security**: Services can only access their own data
- ✅ **Scalability**: Scale databases independently based on load

### Negative:
- ⚠️ **Data Duplication**: Some data may be duplicated across services (acceptable for read models)
- ⚠️ **Distributed Transactions**: Cannot use ACID transactions across services (use Saga pattern)
- ⚠️ **Query Complexity**: Cannot join data across services (use API composition or events)
- ⚠️ **Infrastructure Cost**: More database instances to manage

### Risks:
- **Data Synchronization**: Mitigated via event-driven architecture
- **Transaction Management**: Use Saga pattern for distributed transactions
- **Data Consistency**: Accept eventual consistency for cross-service data

## Alternatives Considered

### 1. Shared Database
- **Rejected**: Creates tight coupling, schema conflicts, deployment issues

### 2. Database Sharding
- **Rejected**: Too complex for current scale, database per service provides better isolation

### 3. CQRS with Separate Read/Write Databases
- **Future Consideration**: May implement for high-read services (Catalog, Product)

## Implementation Guidelines

- Each service must have its own database schema
- Use migrations (Goose/Flyway) for schema versioning
- Never access another service's database directly
- Use events or APIs for cross-service data access
- Implement idempotency for event-driven data sync

## References

- [Microservices Patterns - Database per Service](https://microservices.io/patterns/data/database-per-service.html)
- [Saga Pattern](https://microservices.io/patterns/data/saga.html)

