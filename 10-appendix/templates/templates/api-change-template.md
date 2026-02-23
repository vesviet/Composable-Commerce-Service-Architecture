# API Change Request

**Service:** {Service Name}  
**Change Type:** {New Endpoint | Modified Endpoint | Deprecated Endpoint | Breaking Change}  
**Requested By:** {Name}  
**Date:** {YYYY-MM-DD}  
**Status:** {Draft | In Review | Approved | Rejected}

## Overview

{Brief description of the API change}

## Motivation

{Why is this change needed? What problem does it solve?}

## Proposed Changes

### Endpoint Details

| Method | Path | Description | Breaking Change? |
|--------|------|-------------|-------------------|
| {GET/POST/etc} | `/api/v1/{path}` | {Description} | {Yes/No} |

### Request/Response Schema

```yaml
# Request schema
{request-schema}

# Response schema
{response-schema}
```

### Example Request

```bash
curl -X {METHOD} http://localhost:{port}/api/v1/{path} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{request-body}'
```

### Example Response

```json
{response-body}
```

## Impact Analysis

### Affected Services

| Service | Impact | Action Required |
|---------|--------|-----------------|
| {Service Name} | {High/Medium/Low} | {Action} |

### Client Impact

- **Frontend:** {Impact description}
- **Mobile:** {Impact description}
- **Third-party:** {Impact description}

### Migration Plan

{If breaking change, describe migration plan}

## OpenAPI Spec

- [ ] OpenAPI spec updated: `docs/openapi/{service-name}.openapi.yaml`
- [ ] Changes validated with OpenAPI validator
- [ ] Examples added

## Testing

- [ ] Unit tests added
- [ ] Integration tests added
- [ ] Manual testing completed
- [ ] Backward compatibility tested (if applicable)

## Security Considerations

- [ ] Authentication required?
- [ ] Authorization checks added?
- [ ] Rate limiting considered?
- [ ] Input validation added?

## Performance Considerations

- [ ] Database queries optimized?
- [ ] Caching strategy considered?
- [ ] Response time acceptable?

## Approval

- [ ] Service owner approval
- [ ] Architecture team approval (if major change)
- [ ] Security team approval (if security-related)

## Related Documentation

- [OpenAPI Spec](../openapi/{service-name}.openapi.yaml)
- [Service Documentation](../services/{service-name}.md)
- [ADR](../adr/{adr-name}.md) (if applicable)

