# [Service Name] Service

> **Template Version**: 1.0  
> **Last Updated**: [Date]  
> **Status**: [Draft/Review/Complete]

---

## 📋 Service Overview

### Description
[Brief description of what this service does and its main responsibilities]

### Business Context
[Why this service exists and how it fits into the overall business flow]

### Key Responsibilities
- [Responsibility 1]
- [Responsibility 2]
- [Responsibility 3]

---

## 🏗️ Architecture

### Service Type
- [ ] Application Service (Business Logic)
- [ ] Infrastructure Service (Supporting)
- [ ] Gateway Service (API Gateway/BFF)

### Technology Stack
- **Framework**: [e.g., go-kratos/kratos, Node.js/Express, Spring Boot]
- **Database**: [e.g., PostgreSQL, MongoDB, Redis]
- **Message Queue**: [e.g., Dapr Pub/Sub with Redis Streams]
- **Cache**: [e.g., Redis, In-memory]
- **External APIs**: [List any external service dependencies]

### Deployment
- **Container**: Docker
- **Orchestration**: Kubernetes with Dapr
- **Service Discovery**: Consul
- **Load Balancer**: [Type and configuration]

---

## 📡 API Specification

### Base URL
```
Production: https://api.domain.com/v1/[service-name]
Staging: https://staging-api.domain.com/v1/[service-name]
Local: http://localhost:[port]/v1/[service-name]
```

### Authentication
- **Type**: [JWT Bearer Token / API Key / OAuth2]
- **Required Scopes**: [List required permissions]
- **Rate Limiting**: [Requests per minute/hour]

### Core Endpoints

#### [Endpoint Group 1 - e.g., Product Management]

##### GET /products
**Purpose**: Retrieve product list with filtering and pagination

**Request**:
```http
GET /v1/catalog/products?page=1&limit=20&category=electronics&warehouse=WH001
Authorization: Bearer {jwt_token}
```

**Query Parameters**:
| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| page | integer | No | Page number (default: 1) | 1 |
| limit | integer | No | Items per page (default: 20, max: 100) | 20 |
| category | string | No | Filter by category | electronics |
| warehouse | string | No | Filter by warehouse | WH001 |

**Response**:
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "id": "prod_123",
        "sku": "LAPTOP-001",
        "name": "Gaming Laptop",
        "category": "electronics",
        "price": {
          "amount": 1299.99,
          "currency": "USD"
        },
        "warehouse": "WH001",
        "createdAt": "2024-01-15T10:30:00Z",
        "updatedAt": "2024-01-15T10:30:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "totalPages": 8
    }
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "1.0"
  }
}
```

**Error Responses**:
```json
// 400 Bad Request
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMETERS",
    "message": "Invalid query parameters",
    "details": {
      "limit": "Must be between 1 and 100"
    }
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}

// 401 Unauthorized
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired token"
  }
}

// 500 Internal Server Error
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred"
  }
}
```

##### POST /products
**Purpose**: Create a new product

**Request**:
```http
POST /v1/catalog/products
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "sku": "LAPTOP-002",
  "name": "Business Laptop",
  "description": "High-performance laptop for business use",
  "category": "electronics",
  "brand": "TechBrand",
  "attributes": {
    "color": "Silver",
    "storage": "512GB SSD",
    "ram": "16GB"
  },
  "warehouse": "WH001"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "product": {
      "id": "prod_124",
      "sku": "LAPTOP-002",
      "name": "Business Laptop",
      "status": "active",
      "createdAt": "2024-01-15T10:35:00Z"
    }
  }
}
```

### [Additional Endpoint Groups...]

---

## 🗄️ Database Schema

### Primary Database
**Type**: [PostgreSQL/MongoDB/etc.]  
**Connection**: [Connection details/environment variables]

### Tables/Collections

#### products
```sql
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    brand VARCHAR(100),
    attributes JSONB,
    warehouse_id VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_products_sku (sku),
    INDEX idx_products_category (category),
    INDEX idx_products_warehouse (warehouse_id),
    INDEX idx_products_status (status)
);
```

#### [Additional tables...]

### Cache Schema (Redis)
```
Key Pattern: service:products:{product_id}
TTL: 3600 seconds (1 hour)
Value: JSON serialized product data

Key Pattern: service:products:list:{hash}
TTL: 300 seconds (5 minutes)
Value: JSON serialized product list with pagination
```

---

## 📨 Event Schemas

### Published Events

#### ProductCreated
**Topic**: `catalog.product.created`  
**Version**: 1.0

```json
{
  "eventId": "evt_123",
  "eventType": "ProductCreated",
  "version": "1.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "source": "catalog-service",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "name": "Gaming Laptop",
    "category": "electronics",
    "warehouse": "WH001",
    "createdBy": "user_456"
  },
  "metadata": {
    "correlationId": "corr_789",
    "causationId": "cause_101"
  }
}
```

#### ProductUpdated
**Topic**: `catalog.product.updated`  
**Version**: 1.0

```json
{
  "eventId": "evt_124",
  "eventType": "ProductUpdated",
  "version": "1.0",
  "timestamp": "2024-01-15T10:35:00Z",
  "source": "catalog-service",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "changes": {
      "name": {
        "old": "Gaming Laptop",
        "new": "Gaming Laptop Pro"
      },
      "price": {
        "old": 1199.99,
        "new": 1299.99
      }
    },
    "updatedBy": "user_456"
  }
}
```

### Subscribed Events

#### InventoryUpdated
**Topic**: `inventory.stock.updated`  
**Source**: warehouse-inventory-service

```json
{
  "eventType": "InventoryUpdated",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "warehouse": "WH001",
    "quantity": 45,
    "reserved": 5,
    "available": 40
  }
}
```

---

## 🔗 Service Dependencies

### Upstream Dependencies (Services this service calls)

#### [Dependency Service Name]
- **Purpose**: [Why this service is called]
- **Endpoints Used**: [List of endpoints]
- **Fallback Strategy**: [What happens if service is down]
- **SLA Requirements**: [Response time, availability]

### Downstream Dependencies (Services that call this service)

#### [Consumer Service Name]
- **Purpose**: [What data they get from this service]
- **Endpoints Used**: [List of endpoints they call]
- **Usage Pattern**: [Frequency, peak times]

---

## ⚙️ Configuration

### Environment Variables
```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/catalog_db
DATABASE_MAX_CONNECTIONS=20
DATABASE_TIMEOUT=30s

# Redis Cache
REDIS_URL=redis://localhost:6379
REDIS_TTL=3600

# Service Discovery
CONSUL_URL=http://localhost:8500
SERVICE_NAME=catalog-service
SERVICE_PORT=8080

# Dapr
DAPR_HTTP_PORT=3500
DAPR_GRPC_PORT=50001

# Monitoring
PROMETHEUS_PORT=9090
JAEGER_ENDPOINT=http://localhost:14268/api/traces

# Security
JWT_SECRET=your-secret-key
JWT_EXPIRY=24h
```

### Feature Flags
```yaml
features:
  enable_caching: true
  enable_search_indexing: true
  enable_audit_logging: true
  max_products_per_request: 100
```

---

## 🚨 Error Handling

### Error Codes
| Code | HTTP Status | Description | Retry Strategy |
|------|-------------|-------------|----------------|
| INVALID_PARAMETERS | 400 | Invalid request parameters | No retry |
| UNAUTHORIZED | 401 | Invalid or expired token | Refresh token |
| FORBIDDEN | 403 | Insufficient permissions | No retry |
| NOT_FOUND | 404 | Resource not found | No retry |
| CONFLICT | 409 | Resource already exists | No retry |
| RATE_LIMITED | 429 | Too many requests | Exponential backoff |
| INTERNAL_ERROR | 500 | Internal server error | Retry with backoff |
| SERVICE_UNAVAILABLE | 503 | Service temporarily unavailable | Retry with backoff |

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": {
      "field": "Additional error details"
    }
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z",
    "traceId": "trace_xyz789"
  }
}
```

---

## 📊 Performance & SLAs

### Performance Targets
- **Response Time**: 
  - P50: < 100ms
  - P95: < 300ms
  - P99: < 500ms
- **Throughput**: 1000 requests/second
- **Availability**: 99.9% uptime
- **Error Rate**: < 0.1%

### Resource Requirements
- **CPU**: 2 cores minimum, 4 cores recommended
- **Memory**: 2GB minimum, 4GB recommended
- **Storage**: 10GB minimum for logs and cache
- **Network**: 1Gbps

### Scaling Strategy
- **Horizontal Scaling**: Auto-scale based on CPU/Memory usage
- **Database**: Read replicas for read-heavy operations
- **Cache**: Redis cluster for high availability
- **Load Balancing**: Round-robin with health checks

---

## 🔒 Security

### Authentication & Authorization
- **Authentication**: JWT Bearer tokens
- **Authorization**: Role-based access control (RBAC)
- **Token Validation**: Validate signature and expiry
- **Permissions**: [List required permissions for each endpoint]

### Data Protection
- **Encryption at Rest**: Database encryption enabled
- **Encryption in Transit**: TLS 1.3 for all communications
- **Sensitive Data**: PII data encrypted with AES-256
- **Audit Logging**: All operations logged with user context

### Security Headers
```http
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
```

---

## 🧪 Testing Strategy

### Unit Tests
- **Coverage Target**: > 80%
- **Framework**: [Testing framework used]
- **Mock Strategy**: Mock external dependencies
- **Test Data**: Use factories for test data generation

### Integration Tests
- **Database Tests**: Test with real database (testcontainers)
- **API Tests**: Test all endpoints with various scenarios
- **Event Tests**: Test event publishing and consumption
- **Cache Tests**: Test cache behavior and invalidation

### Performance Tests
- **Load Testing**: Test with expected production load
- **Stress Testing**: Test beyond normal capacity
- **Endurance Testing**: Test for extended periods
- **Tools**: [Load testing tools used]

### Test Examples
```go
// Unit test example
func TestCreateProduct(t *testing.T) {
    // Test implementation
}

// Integration test example
func TestCreateProductAPI(t *testing.T) {
    // API test implementation
}
```

---

## 📈 Monitoring & Observability

### Metrics (Prometheus)
```yaml
# Business Metrics
products_created_total: Counter of products created
products_updated_total: Counter of products updated
products_deleted_total: Counter of products deleted

# Technical Metrics
http_requests_total: HTTP request counter
http_request_duration_seconds: HTTP request duration
database_connections_active: Active database connections
cache_hits_total: Cache hit counter
cache_misses_total: Cache miss counter
```

### Logging
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "service": "catalog-service",
  "traceId": "trace_123",
  "spanId": "span_456",
  "message": "Product created successfully",
  "data": {
    "productId": "prod_123",
    "sku": "LAPTOP-001",
    "userId": "user_456"
  }
}
```

### Distributed Tracing
- **Tool**: Jaeger
- **Trace Context**: Propagate trace context across service calls
- **Span Tags**: Include relevant business context
- **Sampling**: 10% sampling rate in production

### Health Checks
```http
GET /health
{
  "status": "healthy",
  "checks": {
    "database": "healthy",
    "cache": "healthy",
    "external_apis": "healthy"
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 🚀 Deployment

### Container Configuration
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o service ./cmd/server

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/service .
EXPOSE 8080
CMD ["./service"]
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: catalog-service
  template:
    metadata:
      labels:
        app: catalog-service
    spec:
      containers:
      - name: catalog-service
        image: catalog-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: catalog-secrets
              key: database-url
```

### Helm Values
```yaml
replicaCount: 3
image:
  repository: catalog-service
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
  hosts:
    - host: api.domain.com
      paths:
        - path: /v1/catalog
          pathType: Prefix
```

---

## 🔧 Troubleshooting

### Common Issues

#### High Response Times
**Symptoms**: API responses taking > 1 second
**Possible Causes**:
- Database connection pool exhausted
- Cache misses causing database queries
- External service timeouts

**Investigation Steps**:
1. Check database connection metrics
2. Review cache hit/miss ratios
3. Check external service response times
4. Review application logs for errors

**Solutions**:
- Increase database connection pool size
- Optimize cache strategy
- Implement circuit breakers for external services
- Add database query optimization

#### Memory Leaks
**Symptoms**: Memory usage continuously increasing
**Investigation Steps**:
1. Monitor memory metrics over time
2. Check for goroutine leaks (Go services)
3. Review object allocation patterns
4. Use profiling tools

### Debugging Commands
```bash
# Check service health
curl http://localhost:8080/health

# View service logs
kubectl logs -f deployment/catalog-service

# Check metrics
curl http://localhost:9090/metrics

# Database connection test
psql $DATABASE_URL -c "SELECT 1"

# Redis connection test
redis-cli -u $REDIS_URL ping
```

### Runbook Links
- [Service Restart Procedure](./runbooks/restart-procedure.md)
- [Database Migration Guide](./runbooks/database-migration.md)
- [Incident Response](./runbooks/incident-response.md)

---

## 📚 Additional Resources

### Documentation Links
- [API Documentation (Swagger)](https://api.domain.com/docs/catalog)
- [Architecture Decision Records](./adrs/)
- [Database Schema Documentation](./database/)
- [Event Schema Registry](./events/)

### Development Resources
- [Local Development Setup](./development/setup.md)
- [Code Style Guide](./development/style-guide.md)
- [Contributing Guidelines](./development/contributing.md)
- [Testing Guidelines](./development/testing.md)

### Operations Resources
- [Deployment Guide](./operations/deployment.md)
- [Monitoring Playbook](./operations/monitoring.md)
- [Backup and Recovery](./operations/backup-recovery.md)
- [Security Checklist](./operations/security-checklist.md)

---

## 📝 Change Log

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2024-01-15 | Initial service documentation | [Author Name] |
| 1.1 | 2024-01-20 | Added event schemas and error handling | [Author Name] |

---

## 👥 Team & Ownership

### Service Owner
- **Primary**: [Team/Person responsible]
- **Secondary**: [Backup contact]

### Development Team
- **Tech Lead**: [Name]
- **Developers**: [List of developers]
- **DevOps**: [DevOps contact]

### On-Call Rotation
- **Primary**: [Current on-call person]
- **Escalation**: [Escalation contact]
- **Schedule**: [Link to on-call schedule]

---

**Document Status**: [Draft/Review/Approved]  
**Next Review Date**: [Date]  
**Approved By**: [Approver Name and Date]