# ADR-002: Microservices Architecture with Domain-Driven Design

**Date:** 2025-11-17  
**Status:** Accepted  
**Deciders:** Architecture Team, CTO

## Context

The platform started as a monolithic application but needs to scale to:
- 10,000+ SKUs
- 20+ warehouses
- 10,000+ orders/day
- Multiple teams working in parallel
- Independent service deployment

We need an architecture that:
- Allows teams to work independently
- Enables independent scaling
- Supports technology diversity
- Provides clear service boundaries
- Maintains data consistency

## Decision

We will adopt **Microservices Architecture with Domain-Driven Design (DDD)** principles.

### Architecture Principles:
1. **Bounded Contexts**: Each service owns a specific business domain
2. **Data Ownership**: Each service has its own database
3. **API-First**: All services expose REST + gRPC APIs
4. **Event-Driven**: Services communicate via events for async operations
5. **Service Discovery**: Consul for dynamic service registration
6. **API Gateway**: Single entry point for external clients

### Service Boundaries (Bounded Contexts):
- **Order Context**: Order & Cart Service (order lifecycle, cart management)
- **Product Context**: Catalog Service (products, categories, brands)
- **Inventory Context**: Warehouse Service (stock, inventory, warehouses)
- **Pricing Context**: Pricing Service (prices, discounts, taxes)
- **Customer Context**: Customer Service (profiles, addresses, segments)
- **Payment Context**: Payment Service (transactions, gateways)
- **Shipping Context**: Shipping Service (fulfillment, carriers, tracking)
- **User Context**: User Service (internal users, roles, permissions)
- **Auth Context**: Auth Service (authentication, JWT, sessions)

### Technology Stack:
- **Framework**: go-kratos v2 (Go microservices framework)
- **Database**: PostgreSQL 15 (one per service)
- **Cache**: Redis 7 (shared cache layer)
- **Messaging**: Dapr Pub/Sub (event-driven)
- **Service Discovery**: Consul
- **API Gateway**: Custom Gateway Service (Gin-based)

## Consequences

### Positive:
- ✅ **Team Autonomy**: Teams can work on services independently
- ✅ **Technology Flexibility**: Can use different tech stacks per service (currently all Go)
- ✅ **Independent Scaling**: Scale services based on load
- ✅ **Fault Isolation**: Service failures don't cascade
- ✅ **Clear Ownership**: Each team owns a bounded context

### Negative:
- ⚠️ **Distributed Complexity**: Harder to debug, requires distributed tracing
- ⚠️ **Data Consistency**: Eventual consistency challenges (solved via events)
- ⚠️ **Network Latency**: Inter-service calls add latency (mitigated with caching)
- ⚠️ **Deployment Complexity**: More services to deploy and monitor

### Risks:
- **Service Explosion**: Mitigated by clear domain boundaries and DDD principles
- **Data Duplication**: Acceptable for read models, single source of truth for writes
- **Transaction Management**: Use Saga pattern for distributed transactions

## Alternatives Considered

### 1. Monolithic Architecture
- **Rejected**: Doesn't scale for multiple teams, hard to deploy independently

### 2. Modular Monolith
- **Rejected**: Still requires coordinated deployments, doesn't solve scaling issues

### 3. Service-Oriented Architecture (SOA)
- **Rejected**: Too heavyweight, microservices provide better isolation

## Implementation Guidelines

- Each service must have clear domain boundaries (see DDD context map)
- Services should not share databases
- Use events for cross-service communication
- API Gateway routes external requests to appropriate services
- All services must implement health checks and metrics

## References

- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html)
- [Microservices Patterns](https://microservices.io/patterns/index.html)
- [go-kratos Framework](https://go-kratos.dev/)

