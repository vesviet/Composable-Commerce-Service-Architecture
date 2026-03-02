# ADR-022: Dynamic SQL Pivoting for EAV Grid Representations

**Date:** 2026-03-02
**Status:** Accepted
**Deciders:** Architecture Team, Development Team

## Context
Our platform utilizes the **Entity-Attribute-Value (EAV)** pattern for flexible data models in services such as `catalog` (product attributes) and `customer` (custom segments). 

While EAV provides flexibility, it introduces significant challenges for Admin Grids (List views):
1. **N+1 Query Problem**: Fetching entities followed by N queries for their attributes.
2. **Pagination Breakage**: Filtering or sorting by an EAV attribute is impossible using standard SQL `JOIN` without complex subqueries, often leading to incorrect record counts.
3. **Performance**: Hydrating objects in the application layer after multiple DB roundtrips is inefficient for high-volume grids.

## Decision
We will standardize the use of **SQL Pivot Queries** using the `MAX(CASE WHEN...)` pattern at the repository layer to flatten EAV data into a tabular format within a single SQL statement.

### implementation Pattern
Repositories should construct queries following this structure:
```sql
SELECT 
    e.id, 
    e.name,
    MAX(CASE WHEN va.attribute_code = 'color' THEN va.value_string END) AS color,
    MAX(CASE WHEN va.attribute_code = 'size' THEN va.value_string END) AS size
FROM entities e
LEFT JOIN entity_values va ON e.id = va.entity_id
GROUP BY e.id, e.name
ORDER BY color DESC
LIMIT 20 OFFSET 0;
```

For Go/Kratos services using GORM:
- Use `.Select()` with literal SQL or a query builder to define the pivot columns.
- Use `.Group()` to aggregate by the primary entity ID.

## Consequences
- **Positive**: Single-database roundtrip for full grid data.
- **Positive**: Native SQL support for `ORDER BY` and `WHERE` on pivot-virtual columns.
- **Positive**: Standard `LIMIT/OFFSET` (or Keyset/Cursor) pagination works correctly on the aggregated results.
- **Negative**: Increased complexity in the `internal/data` layer for building dynamic SQL strings.
- **Negative**: Database performance may degrade if pivoting across 50+ attributes simultaneously (recommend selecting only visible grid columns).

## Alternatives
- **App-level Hydration**: Fetch entities first, then attributes. *Rejected* because it makes cross-attribute sorting and efficient pagination impossible.
- **JSONB Transformation**: Migrating EAV to PostgreSQL JSONB. *Considered* for future phases, but rejected for now to maintain compatibility with existing EAV schema and reporting tools.
- **Materialized Views**: Specific views for grids. *Rejected* due to data staleness and maintenance overhead for highly dynamic EAV schemas.
