# ADR-015: Database Migration Strategy

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Database Team, DevOps Team, Development Team

## Context

With 21+ microservices, each with its own PostgreSQL database, we need:
- Consistent database schema management across all services
- Automated migration execution in CI/CD pipelines
- Rollback capabilities for failed migrations
- Zero-downtime deployment strategies
- Migration testing and validation
- Database change tracking and auditing

We evaluated several migration tools:
- **Goose**: Go-native migration tool, simple and reliable
- **Flyway**: Java-based, feature-rich but requires JVM
- **Liquibase**: Complex XML-based migrations
- **Custom Scripts**: Full control but high maintenance overhead

## Decision

We will use **Goose for database migrations** with **version-controlled migration files** and **automated execution in CI/CD**.

### Migration Architecture:
1. **Goose**: Primary migration tool for all services
2. **Migration Files**: Version-controlled SQL migration scripts
3. **CI/CD Integration**: Automated migration execution
4. **Rollback Strategy**: Downward migrations for rollback capability
5. **Migration Testing**: Validation in staging environments
6. **Database Locking**: Prevent concurrent migration execution

### Migration File Structure:
```
service/
├── migrations/
│   ├── 00001_create_users_table.sql
│   ├── 00002_add_email_index.sql
│   ├── 00003_create_orders_table.sql
│   └── ...
```

### Migration Workflow:
1. **Development**: Create migration file with descriptive name
2. **Testing**: Test migration in development environment
3. **Review**: Code review migration SQL scripts
4. **CI/CD**: Automated migration execution in staging
5. **Production**: Manual approval for production migrations
6. **Verification**: Post-migration validation and monitoring

### Migration Types:
- **Schema Changes**: Table creation, column additions, indexes
- **Data Migrations**: Data transformations, bulk updates
- **Constraint Changes**: Foreign keys, check constraints
- **Performance Optimizations**: Index additions, query optimizations

### Deployment Strategy:
- **Blue-Green**: Zero-downtime deployments with migration testing
- **Rolling Updates**: Gradual rollout with health checks
- **Canary Releases**: Test migrations with subset of traffic
- **Backward Compatibility**: Maintain compatibility during migrations

### Safety Measures:
- **Transaction Safety**: All migrations in transactions
- **Rollback Scripts**: Downward migrations for every change
- **Backup Strategy**: Pre-migration database backups
- **Validation Scripts**: Post-migration data validation
- **Monitoring**: Migration execution monitoring and alerting

## Consequences

### Positive:
- ✅ **Consistent**: Same migration tool across all services
- ✅ **Automated**: CI/CD integration reduces manual errors
- ✅ **Version Controlled**: Migration history tracked in Git
- ✅ **Rollback Ready**: Downward migrations for quick recovery
- ✅ **Testable**: Migrations tested before production
- ✅ **Go Native**: No additional runtime dependencies

### Negative:
- ⚠️ **Complexity**: Migration planning and coordination required
- ⚠️ **Downtime Risk**: Poorly planned migrations can cause downtime
- ⚠️ **Data Loss Risk**: Incorrect migrations can corrupt data
- ⚠️ **Testing Overhead**: Need comprehensive migration testing

### Risks:
- **Migration Failures**: Failed migrations leaving database in inconsistent state
- **Data Corruption**: Incorrect migration scripts damaging data
- **Performance Impact**: Large migrations affecting application performance
- **Rollback Complexity**: Complex rollback scenarios for data migrations

## Alternatives Considered

### 1. Flyway
- **Rejected**: Requires JVM, adds complexity to Go services
- **Pros**: Feature-rich, enterprise support, good UI tools
- **Cons**: Java dependency, heavier than needed

### 2. Liquibase
- **Rejected**: XML-based, complex syntax, steep learning curve
- **Pros**: Powerful, supports multiple database types
- **Cons**: Complex, verbose XML format

### 3. Custom Migration Scripts
- **Rejected**: High maintenance overhead, error-prone
- **Pros**: Full control, no dependencies
- **Cons**: Reinventing the wheel, inconsistent implementations

### 4. Database Vendor Tools
- **Rejected**: Vendor-specific, not portable across services
- **Pros**: Optimized for specific database
- **Cons**: Lock-in, inconsistent across different databases

## Implementation Guidelines

- Use semantic versioning for migration file naming
- Write idempotent migration scripts when possible
- Always include rollback migrations for destructive changes
- Test migrations in staging before production
- Use database transactions for migration atomicity
- Implement pre and post-migration validation scripts
- Monitor migration execution and database performance
- Maintain migration documentation and change logs

## References

- [Goose Migration Tool](https://github.com/pressly/goose)
- [Database Migration Best Practices](https://flywaydb.org/learnmore/bestpractices)
- [Zero-Downtime Database Migrations](https://www.braintreepayments.com/blog/zero-downtime-database-migrations)
- [Microservices Database Patterns](https://microservices.io/patterns/data/database-per-service.html)
