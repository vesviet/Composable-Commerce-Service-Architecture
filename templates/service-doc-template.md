# Service Documentation Template

> Use this template when creating or standardizing service documentation.
> Copy this file and replace all `{{placeholders}}` with actual values.

---

```markdown
# {{emoji}} {{Service Name}} Service

> **Owner**: Platform Team
> **Last Updated**: {{YYYY-MM-DD}}
> **Architecture**: [Clean Architecture](../../01-architecture/clean-architecture.md) · [Service Map](../../SERVICE_INDEX.md)

| | |
|---|---|
| **Version** | {{version}} |
| **HTTP Port** | {{http_port}} |
| **gRPC Port** | {{grpc_port}} |
| **Status** | ✅ Production Ready / 🔄 In Review / ⚠️ Pending |
| **Common Lib** | v{{common_version}} |

---

## Overview

{{One paragraph describing what business problem this service solves.}}

## Architecture

### Responsibilities
- {{responsibility 1}}
- {{responsibility 2}}

### Dependencies
| Direction | Service | Protocol | Purpose |
|-----------|---------|----------|---------|
| Upstream | {{service}} | gRPC | {{purpose}} |
| Downstream | {{service}} | Dapr PubSub | {{purpose}} |
| External | PostgreSQL | TCP | Primary data store |

## API Contract

### gRPC Service
- **Proto**: `{{service}}/api/{{service}}/v1/`
- **Key Methods**:
  - `MethodName(Request) → Response` — {{description}}

### HTTP Endpoints
- `POST /api/v1/{{service}}/{{resource}}` — {{description}}

## Data Model

### Database Tables
| Table | Purpose |
|-------|---------|
| {{table_name}} | {{purpose}} |

## Configuration

### Key Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | - | PostgreSQL connection |

## Monitoring

### Key Metrics
- {{metric 1}}
- {{metric 2}}

## Development

### Quick Start
```bash
cd {{service}}
make build && make run
make test
```

## References
- [Service Index](../../SERVICE_INDEX.md)
- [API Documentation](../../04-apis/)
```
