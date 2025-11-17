# Development Workflow Guide

This guide outlines the standard development workflow for the microservices platform.

## Workflow Overview

```
1. Design/Planning → 2. Development → 3. Testing → 4. Review → 5. Deploy
```

## Step-by-Step Workflow

### 1. Planning & Design

#### For New Features

1. **Create Design Document** (if major feature)
   ```bash
   cp docs/design/feature-design-template.md docs/design/2025-11-{feature-name}-design.md
   ```
   - Fill in design document
   - Get architecture team review
   - Get approval before starting development

2. **Create ADR** (if architectural decision required)
   ```bash
   cp docs/adr/ADR-template.md docs/adr/ADR-{number}-{decision-name}.md
   ```
   - Document decision, context, alternatives
   - Get team review and approval

#### For API Changes

1. **Create API Change Request**
   ```bash
   cp templates/api-change-template.md docs/api-changes/{date}-{api-name}-change.md
   ```
   - Document proposed changes
   - Get service owner approval
   - Update OpenAPI spec

#### For Event Changes

1. **Create Event Change Request**
   ```bash
   cp templates/event-change-template.md docs/event-changes/{date}-{event-name}-change.md
   ```
   - Document proposed changes
   - Get all affected service owners approval
   - Update JSON Schema

### 2. Development

#### Create Feature Branch

```bash
git checkout -b feature/{feature-name}
# or
git checkout -b fix/{bug-name}
# or
git checkout -b refactor/{refactor-name}
```

#### Update Documentation

- [ ] Service documentation (if service changes)
- [ ] OpenAPI spec (if API changes)
- [ ] Event schemas (if event changes)
- [ ] Runbook (if operational changes)

#### Implement Code

1. **Database Migrations** (if needed)
   ```bash
   # Create migration
   make migrate-create NAME={migration-name}
   
   # Test migration
   make migrate-up
   make migrate-down
   ```

2. **Business Logic**
   - Follow 4-layer architecture (Presentation → Application → Infrastructure → Platform)
   - Write unit tests
   - Follow Go best practices

3. **API Endpoints**
   - Implement REST/gRPC handlers
   - Add input validation
   - Add error handling
   - Write integration tests

4. **Event Publishing/Subscribing**
   - Implement event publishers
   - Implement event handlers
   - Test event flow
   - Update event schemas

### 3. Testing

#### Unit Tests

```bash
# Run unit tests
make test

# Run with coverage
make test-coverage
```

#### Integration Tests

```bash
# Run integration tests
make test-integration

# Test with Docker
docker compose up -d
make test-integration
```

#### Manual Testing

- [ ] Test API endpoints
- [ ] Test event publishing/subscribing
- [ ] Test error scenarios
- [ ] Test edge cases

### 4. Code Review

#### Pre-Review Checklist

- [ ] All tests pass
- [ ] Code follows project conventions
- [ ] Documentation updated
- [ ] No breaking changes (or migration plan included)
- [ ] Security considerations addressed
- [ ] Performance impact assessed

#### Submit for Review

```bash
# Push branch
git push origin feature/{feature-name}

# Create pull request
# - Link to design doc/ADR (if applicable)
# - Link to API/Event change requests (if applicable)
# - Add reviewers
# - Add labels
```

#### Review Process

1. **Peer Review** - At least one team member reviews
2. **Documentation Review** - Documentation team reviews
3. **Architecture Review** - Architecture team reviews (if major change)
4. **Security Review** - Security team reviews (if security-related)

### 5. Deployment

#### Merge to Main

- [ ] All reviews approved
- [ ] CI/CD pipeline passes
- [ ] Documentation merged
- [ ] Migration plan documented (if breaking changes)

#### Post-Deployment

- [ ] Monitor service health
- [ ] Check metrics/logs
- [ ] Update runbook (if needed)
- [ ] Communicate changes to stakeholders

## Template Usage

### Creating New Service Documentation

```bash
# Copy templates
cp templates/service-documentation-template.md docs/services/{service-name}.md
cp templates/service-openapi-template.yaml docs/openapi/{service-name}.openapi.yaml
cp templates/service-runbook-template.md docs/sre-runbooks/{service-name}-runbook.md

# Or use service-specific template
cp templates/{service-name}-service-template.md docs/services/{service-name}.md
```

### Creating New Event Contract

```bash
# Copy event schema template
cp templates/event-schema-template.json docs/json-schema/{event-type}.schema.json

# Copy event contract template
cp templates/event-contract-template.md docs/events/{event-type}.md

# Create Dapr subscription
cp templates/dapr-subscription-template.yaml {service-name}/components/{event-type}-subscription.yaml
```

### Reporting Bugs

```bash
# Copy bug report template
cp templates/bug-report-template.md docs/bugs/{date}-{bug-name}.md
```

## Best Practices

1. **Always use templates** - Don't create docs from scratch
2. **Update docs with code** - Documentation is part of the code
3. **Review before merge** - All docs must be peer-reviewed
4. **Version control** - All docs are versioned in git
5. **Keep docs up-to-date** - Update docs when code changes

## Related Templates

- [Feature Branch Template](./feature-branch-template.md)
- [API Change Template](./api-change-template.md)
- [Event Change Template](./event-change-template.md)
- [Bug Report Template](./bug-report-template.md)

