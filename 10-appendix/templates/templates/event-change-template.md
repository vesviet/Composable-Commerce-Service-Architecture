# Event Contract Change Request

**Event Type:** `{service}.{domain}.{action}`  
**Change Type:** {New Event | Modified Event | Deprecated Event | Breaking Change}  
**Requested By:** {Name}  
**Date:** {YYYY-MM-DD}  
**Status:** {Draft | In Review | Approved | Rejected}

## Overview

{Brief description of the event change}

## Motivation

{Why is this change needed? What problem does it solve?}

## Proposed Changes

### Event Details

| Field | Current | Proposed | Breaking Change? |
|-------|---------|----------|-------------------|
| `{field-name}` | {current-value} | {proposed-value} | {Yes/No} |

### Schema Changes

```json
{
  "eventType": "{service}.{domain}.{action}",
  "version": "v{version}",
  "data": {
    "{new-field}": "{description}",
    "{modified-field}": "{description}"
  }
}
```

### Example Event

```json
{
  "specversion": "1.0",
  "type": "{service}.{domain}.{action}",
  "source": "https://api.company.com/services/{service-name}",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "time": "2025-11-17T10:00:00Z",
  "datacontenttype": "application/json",
  "data": {
    "{field-name}": "{example-value}"
  }
}
```

## Impact Analysis

### Publishers

| Service | Component | Impact | Action Required |
|---------|-----------|--------|-----------------|
| {Service Name} | {Component} | {High/Medium/Low} | {Action} |

### Subscribers

| Service | Handler | Impact | Action Required |
|---------|---------|--------|-----------------|
| {Service Name} | {Handler} | {High/Medium/Low} | {Action} |

### Migration Plan

{If breaking change, describe migration plan}

## Versioning Strategy

- **Current Version:** v{current-version}
- **New Version:** v{new-version}
- **Backward Compatibility:** {Yes/No}
- **Deprecation Timeline:** {If applicable}

## JSON Schema

- [ ] JSON Schema updated: `docs/json-schema/{event-type}.schema.json`
- [ ] Schema validated with JSON Schema validator
- [ ] Examples added
- [ ] Version updated in `$id`

## Testing

- [ ] Event publishing tested
- [ ] Event subscribing tested
- [ ] Schema validation tested
- [ ] Backward compatibility tested (if applicable)

## Dapr Subscription

- [ ] Dapr subscription configuration updated (if needed)
- [ ] Subscription tested

## Approval

- [ ] Service owner approval
- [ ] All affected service owners approval
- [ ] Architecture team approval (if major change)

## Related Documentation

- [Event Schema](../json-schema/{event-type}.schema.json)
- [Event Contract](../events/{event-type}.md)
- [ADR](../adr/{adr-name}.md) (if applicable)

