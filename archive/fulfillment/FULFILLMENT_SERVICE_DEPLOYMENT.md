# Fulfillment Service - Deployment Guide

> **Container:** Docker + Docker Compose  
> **Orchestration:** Dapr Sidecar  
> **Status:** 🔴 Not Deployed

---

## Docker Configuration

### Dockerfile

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -o /fulfillment ./cmd/fulfillment

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copy binary from builder
COPY --from=builder /fulfillment .
COPY --from=builder /app/configs ./configs

EXPOSE 8010 9010

CMD ["./fulfillment", "-conf", "./configs/config.yaml"]
```

---

## Docker Compose

### fulfillment/docker-compose.yml

```yaml
services:
  fulfillment:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: source_fulfillment
    ports:
      - "8010:8010"  # HTTP
      - "9010:9010"  # gRPC
    environment:
      - HTTP_PORT=8010
      - GRPC_PORT=9010
      - DATABASE_URL=postgres://ecommerce_user:ecommerce_pass@postgres:5432/fulfillment_db?sslmode=disable
      - REDIS_URL=redis://redis:6379/5
      - CONSUL_ADDRESS=consul:8500
      - DAPR_HTTP_PORT=3510
      - DAPR_GRPC_PORT=50010
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      consul:
        condition: service_healthy
    networks:
      - microservices
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8010/health"]
      interval: 10s
      timeout: 3s
      retries: 3

  fulfillment-dapr:
    image: daprio/daprd:1.12.0
    container_name: source_fulfillment_dapr
    command: [
      "./daprd",
      "-app-id", "fulfillment-service",
      "-app-port", "8010",
      "-dapr-http-port", "3510",
      "-dapr-grpc-port", "50010",
      "-placement-host-address", "dapr-placement:50006",
      "-components-path", "/components",
      "-config", "/config/config.yaml"
    ]
    volumes:
      - ../dapr/components:/components
      - ../dapr/config:/config
    depends_on:
      - fulfillment
    network_mode: "service:fulfillment"

networks:
  microservices:
    external: true
    name: source_microservices
```

---

## Dapr Components

### dapr/components/fulfillment-pubsub.yaml

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: redis:6379
  - name: redisPassword
    value: ""
```


---

## Makefile

```makefile
.PHONY: build run docker-build docker-run migrate-up migrate-down

# Build binary
build:
	go build -o bin/fulfillment ./cmd/fulfillment

# Run locally
run:
	go run ./cmd/fulfillment -conf ./configs/config.yaml

# Docker build
docker-build:
	docker build -t fulfillment-service:latest .

# Docker run
docker-run:
	docker-compose up -d

# Migrations
migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down

# Generate code
api:
	buf generate

wire:
	wire ./cmd/fulfillment

# Tests
test:
	go test -v ./...

# Clean
clean:
	rm -rf bin/
	docker-compose down
```

---

## Deployment Steps

### 1. Build Service
```bash
cd fulfillment/
make build
```

### 2. Run Migrations
```bash
export DATABASE_URL="postgres://ecommerce_user:ecommerce_pass@localhost:5432/fulfillment_db?sslmode=disable"
make migrate-up
```

### 3. Start with Docker Compose
```bash
docker-compose up -d
```

### 4. Verify Service
```bash
# Health check
curl http://localhost:8010/health

# Check Consul registration
curl http://localhost:8500/v1/catalog/service/fulfillment-service
```

---

## Summary

**Ports:**
- 8010: HTTP API
- 9010: gRPC API
- 3510: Dapr HTTP
- 50010: Dapr gRPC

**Dependencies:**
- PostgreSQL (fulfillment_db)
- Redis (pub/sub)
- Consul (service discovery)
- Dapr (sidecar)
