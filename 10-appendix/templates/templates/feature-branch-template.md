# Feature Development Workflow

**Feature:** {Feature Name}  
**Branch:** `feature/{feature-name}`  
**Author:** {Your Name}  
**Date:** {YYYY-MM-DD}

## Overview

{Brief description of the feature}

## Prerequisites

- [ ] Design document reviewed and approved (if applicable)
- [ ] ADR created (if architectural decision required)
- [ ] API contract defined (OpenAPI spec)
- [ ] Event contracts defined (JSON Schema)
- [ ] Database migrations planned

## Development Steps

### 1. Create Feature Branch

```bash
git checkout -b feature/{feature-name}
```

### 2. Update Documentation

- [ ] Update service documentation
- [ ] Update OpenAPI spec (if API changes)
- [ ] Create/update event schemas (if event changes)
- [ ] Update runbook (if operational changes)

### 3. Implement Feature

- [ ] Database migrations
- [ ] Business logic
- [ ] API endpoints
- [ ] Event publishers/subscribers
- [ ] Unit tests
- [ ] Integration tests

### 4. Code Review Checklist

- [ ] Code follows project conventions
- [ ] All tests pass
- [ ] Documentation updated
- [ ] No breaking changes (or migration plan included)
- [ ] Security considerations addressed
- [ ] Performance impact assessed

### 5. Testing

- [ ] Unit tests written and passing
- [ ] Integration tests written and passing
- [ ] Manual testing completed
- [ ] Event publishing/subscribing tested
- [ ] Error handling tested

### 6. Submit for Review

```bash
# Push branch
git push origin feature/{feature-name}

# Create pull request
# Link to design doc, ADR, or related issues
```

## Review Process

1. **Peer Review:** At least one team member reviews code
2. **Documentation Review:** Documentation team reviews docs
3. **Architecture Review:** Architecture team reviews (if major change)
4. **QA Review:** QA team reviews test coverage

## Merge Checklist

- [ ] All reviews approved
- [ ] CI/CD pipeline passes
- [ ] Documentation merged
- [ ] Migration plan documented (if breaking changes)
- [ ] Rollback plan documented (if needed)

## Post-Merge

- [ ] Monitor service health after deployment
- [ ] Update runbook with any new operational procedures
- [ ] Communicate changes to stakeholders
- [ ] Update project status/docs

## Related Documentation

- [Design Doc](../design/{design-doc-name}.md)
- [ADR](../adr/{adr-name}.md)
- [API Spec](../openapi/{service-name}.openapi.yaml)
- [Event Contracts](../json-schema/)

