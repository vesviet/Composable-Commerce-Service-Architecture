# {ServiceName} Service

Brief service description.

## Quick Start

### Prerequisites
- Go 1.25+
- Docker & Docker Compose
- PostgreSQL (or required database)

### Local Development
```bash
# Clone and setup
git clone <repo>
cd {serviceName}
cp .env.example .env

# Install dependencies
go mod download

# Run database migrations
make migrate-up

# Start service
make run
```

### Docker Development
```bash
# Build and run with docker-compose
docker-compose up --build
```

## Configuration

### Environment Variables
Key environment variables (link to full list in service docs).

### Database Setup
Database connection and migration instructions.

## API

### gRPC
- **Port**: 9000 (or service-specific port)
- **Proto**: `api/{servicename}/v1/`
- **Health check**: `grpc_health_probe -addr=:9000`

### HTTP (if applicable)
- **Port**: 8000 (or service-specific port)
- **Health check**: `GET /health`

## Testing

```bash
# Run unit tests
make test

# Run integration tests
make test-integration

# Generate coverage report
make coverage
```

## Build & Deploy

```bash
# Build binary
make build

# Build Docker image
make docker-build

# Deploy to staging
make deploy-staging
```

## Troubleshooting

### Common Issues
- Connection issues
- Configuration problems
- Performance issues

### Debug Commands
Useful commands for local debugging.

## Documentation

- [Service Documentation](../docs/03-services/<group>/{servicename}-service.md)
- [API Reference](../docs/04-apis/{servicename}-api.md)
