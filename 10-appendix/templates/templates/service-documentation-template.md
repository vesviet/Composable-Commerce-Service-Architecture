# {Service Name} Service Documentation

**Service:** {Service Name}  
**Port:** {HTTP Port} (HTTP), {gRPC Port} (gRPC)  
**Health Check:** `GET /health`  
**Repository:** `{service-name}/`  
**Last Updated:** {YYYY-MM-DD}

## Overview

{Brief description of the service's purpose and responsibilities}

## Architecture

### Service Boundaries (Bounded Context)

{Describe the domain/bounded context this service owns}

### Key Responsibilities

- {Responsibility 1}
- {Responsibility 2}
- {Responsibility 3}

### Technology Stack

- **Framework:** go-kratos/kratos v2
- **Database:** PostgreSQL {version}
- **Cache:** Redis {version}
- **Event Messaging:** Dapr Pub/Sub (Redis Streams)
- **Service Discovery:** Consul

## API Endpoints

### REST API

See OpenAPI specification: [`openapi/{service-name}.openapi.yaml`](../openapi/{service-name}.openapi.yaml)

**Base URL:** `http://localhost:{http-port}/api/v1`

#### Key Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/api/v1/{resource}` | {Description} |
| POST | `/api/v1/{resource}` | {Description} |

### gRPC API

**Service:** `api.{service-name}.v1.{ServiceName}Service`  
**Port:** `{grpc-port}`

See proto definitions: `{service-name}/api/{service-name}/v1/*.proto`

## Events

### Published Events

| Event Type | Topic | Description | Schema |
|------------|-------|-------------|--------|
| `{service}.{domain}.{action}` | `{event-type}` | {Description} | [`json-schema/{event-type}.schema.json`](../json-schema/{event-type}.schema.json) |

### Subscribed Events

| Event Type | Topic | Handler | Purpose |
|------------|-------|---------|---------|
| `{service}.{domain}.{action}` | `{event-type}` | `{HandlerName}` | {Description} |

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `{table_name}` | {Description} |

### Migrations

Location: `{service-name}/migrations/`

```bash
# Run migrations
make migrate-up

# Rollback
make migrate-down
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `{VAR_NAME}` | {Description} | `{default}` | {Yes/No} |

### Configuration File

Location: `{service-name}/configs/config.yaml`

```yaml
server:
  http:
    addr: 0.0.0.0:{http-port}
  grpc:
    addr: 0.0.0.0:{grpc-port}

data:
  database:
    driver: postgres
    source: host=postgres port=5432 user={user} password={pass} dbname={dbname} sslmode=disable
  redis:
    addr: redis:6379
    password: ""
    db: {db-number}

consul:
  address: consul:8500
  service:
    name: {service-name}
    tags:
      - http
      - grpc

dapr:
  httpPort: 3500
  grpcPort: 50001
  subscriptions:
    - pubsubName: pubsub-redis
      topic: {event-type}
      route: /api/v1/events/{event-type}
```

## Development

### Prerequisites

- Go 1.25+
- Docker & Docker Compose
- Make

### Local Development

```bash
# Start infrastructure (Consul, PostgreSQL, Redis, Dapr)
cd /home/user/microservices
docker compose up -d consul postgres redis dapr-placement

# Run service locally
cd {service-name}
make run

# Or via Docker
docker compose up -d {service-name}-service
```

### Running Tests

```bash
# Unit tests
make test

# Integration tests
make test-integration

# All tests
make test-all
```

### Code Generation

```bash
# Generate proto code
make api

# Generate wire dependency injection
make wire
```

## Deployment

### Docker

```bash
# Build image
docker compose build {service-name}-service

# Start service
docker compose up -d {service-name}-service

# View logs
docker compose logs -f {service-name}-service
```

### Kubernetes

See deployment manifests: `{service-name}/deployments/`

## Monitoring

### Metrics

- **Prometheus Endpoint:** `http://localhost:{http-port}/metrics`
- **Key Metrics:**
  - `{metric_name}` - {Description}

### Logging

- **Log Format:** JSON
- **Log Level:** Configurable via `LOG_LEVEL` env var
- **Distributed Tracing:** Jaeger (via OpenTelemetry)

### Health Checks

```bash
# HTTP health check
curl http://localhost:{http-port}/health

# Expected response:
# {"status":"ok","service":"{service-name}","version":"1.0.0"}
```

## Troubleshooting

See SRE Runbook: [`sre-runbooks/{service-name}-runbook.md`](../sre-runbooks/{service-name}-runbook.md)

### Common Issues

1. **{Issue Name}**
   - **Symptoms:** {Symptoms}
   - **Solution:** {Solution}

## Related Documentation

- [OpenAPI Spec](../openapi/{service-name}.openapi.yaml)
- [SRE Runbook](../sre-runbooks/{service-name}-runbook.md)
- [Event Contracts](../json-schema/)
- [Architecture Decision Records](../adr/)

## Team Contacts

- **Service Owner:** {Name/Team}
- **On-Call:** {Contact Info}
- **Slack Channel:** `#{service-name}-service`

