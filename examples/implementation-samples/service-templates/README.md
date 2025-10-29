# Service Templates

## Overview
Ready-to-use service templates for different technology stacks, following microservices best practices and the e-commerce platform architecture.

## Available Templates

### 1. Node.js Service Template
- **Framework**: Express.js with TypeScript
- **Database**: PostgreSQL with Prisma ORM
- **Messaging**: Kafka integration
- **Caching**: Redis support
- **Monitoring**: Prometheus metrics, structured logging
- **Testing**: Jest with supertest
- **Documentation**: OpenAPI/Swagger

### 2. Java Service Template
- **Framework**: Spring Boot 3.x
- **Database**: PostgreSQL with JPA/Hibernate
- **Messaging**: Spring Kafka
- **Caching**: Redis with Spring Cache
- **Monitoring**: Micrometer metrics, Logback
- **Testing**: JUnit 5, TestContainers
- **Documentation**: SpringDoc OpenAPI

### 3. Python Service Template
- **Framework**: FastAPI
- **Database**: PostgreSQL with SQLAlchemy
- **Messaging**: aiokafka
- **Caching**: Redis with aioredis
- **Monitoring**: Prometheus client, structured logging
- **Testing**: pytest with httpx
- **Documentation**: FastAPI auto-generated docs

### 4. Go Service Template
- **Framework**: Gin HTTP framework
- **Database**: PostgreSQL with GORM
- **Messaging**: Sarama Kafka client
- **Caching**: go-redis
- **Monitoring**: Prometheus client, structured logging
- **Testing**: testify framework
- **Documentation**: Swagger with gin-swagger

## Template Structure

Each template follows this standard structure:
```
service-template/
├── src/                           # Source code
│   ├── controllers/               # HTTP controllers/handlers
│   ├── services/                  # Business logic
│   ├── repositories/              # Data access layer
│   ├── models/                    # Data models/entities
│   ├── events/                    # Event handlers
│   ├── middleware/                # HTTP middleware
│   └── utils/                     # Utility functions
├── tests/                         # Test files
│   ├── unit/                      # Unit tests
│   ├── integration/               # Integration tests
│   └── fixtures/                  # Test data
├── migrations/                    # Database migrations
├── docs/                          # Documentation
├── scripts/                       # Utility scripts
├── docker/                        # Docker configurations
├── k8s/                          # Kubernetes manifests
├── .github/workflows/             # GitHub Actions
├── Dockerfile                     # Container definition
├── docker-compose.yml             # Local development
├── README.md                      # Service documentation
└── package.json|pom.xml|requirements.txt|go.mod
```

## Common Features

All templates include:

### 1. Health Check Endpoints
```
GET /health      - Basic health check
GET /ready       - Readiness probe
GET /metrics     - Prometheus metrics
```

### 2. Configuration Management
- Environment-based configuration
- Secrets management
- Feature flags support
- Configuration validation

### 3. Database Integration
- Connection pooling
- Migration support
- Transaction management
- Query optimization

### 4. Event-Driven Architecture
- Kafka producer/consumer setup
- Event serialization/deserialization
- Dead letter queue handling
- Event replay capabilities

### 5. Observability
- Structured logging with correlation IDs
- Prometheus metrics collection
- Distributed tracing support
- Error tracking and alerting

### 6. Security
- JWT token validation
- Rate limiting
- Input validation and sanitization
- CORS configuration

### 7. Testing
- Unit test framework setup
- Integration test utilities
- Test database setup
- Mock service configurations

### 8. CI/CD Integration
- Build pipeline configuration
- Automated testing
- Container image building
- Deployment automation

## Usage Instructions

### Creating a New Service

1. **Choose Template**
```bash
# Copy the appropriate template
cp -r service-templates/nodejs-service my-catalog-service
cd my-catalog-service
```

2. **Customize Service**
```bash
# Run customization script
./scripts/customize.sh my-catalog-service

# Update configuration
vim config/default.json
```

3. **Install Dependencies**
```bash
# Node.js
npm install

# Java
mvn clean install

# Python
pip install -r requirements.txt

# Go
go mod tidy
```

4. **Setup Database**
```bash
# Run migrations
npm run migrate:up
# or
mvn flyway:migrate
# or
alembic upgrade head
# or
go run migrations/migrate.go up
```

5. **Start Development**
```bash
# Start in development mode
npm run dev
# or
mvn spring-boot:run
# or
uvicorn main:app --reload
# or
go run main.go
```

## Template Customization

### Environment Variables
Each template uses these standard environment variables:
```bash
# Service Configuration
SERVICE_NAME=catalog-service
SERVICE_VERSION=1.0.0
PORT=3000
NODE_ENV=development

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/catalog_db
DATABASE_POOL_SIZE=10

# Redis Cache
REDIS_URL=redis://localhost:6379
REDIS_TTL=300

# Kafka
KAFKA_BROKERS=localhost:9092
KAFKA_GROUP_ID=catalog-service-group

# Monitoring
LOG_LEVEL=info
METRICS_PORT=9090

# Security
JWT_SECRET=your-secret-key
CORS_ORIGINS=http://localhost:3000
```

### Database Configuration
Templates include database setup for common patterns:
- Connection pooling
- Read/write splitting
- Migration management
- Seed data loading

### Event Configuration
Event handling setup includes:
- Producer configuration
- Consumer group setup
- Error handling
- Retry policies
- Dead letter queues

## Best Practices Included

### 1. Code Organization
- Clean architecture principles
- Dependency injection
- Interface-based design
- Separation of concerns

### 2. Error Handling
- Centralized error handling
- Custom error types
- Error logging and monitoring
- Graceful degradation

### 3. Performance
- Connection pooling
- Caching strategies
- Async/await patterns
- Resource optimization

### 4. Security
- Input validation
- SQL injection prevention
- XSS protection
- Rate limiting

### 5. Monitoring
- Health checks
- Metrics collection
- Distributed tracing
- Log correlation

## Development Workflow

### 1. Local Development
```bash
# Start dependencies
docker-compose up -d postgres redis kafka

# Run migrations
npm run migrate:up

# Start service
npm run dev

# Run tests
npm test
```

### 2. Testing
```bash
# Unit tests
npm run test:unit

# Integration tests
npm run test:integration

# Load tests
npm run test:load

# Coverage report
npm run test:coverage
```

### 3. Building
```bash
# Build application
npm run build

# Build Docker image
docker build -t my-service:latest .

# Run container
docker run -p 3000:3000 my-service:latest
```

### 4. Deployment
```bash
# Deploy to Kubernetes
kubectl apply -f k8s/

# Check deployment
kubectl get pods -l app=my-service

# View logs
kubectl logs -f deployment/my-service
```

## Template Maintenance

Templates are regularly updated with:
- Security patches
- Dependency updates
- Best practice improvements
- New feature additions
- Performance optimizations

## Contributing

To contribute new templates or improvements:
1. Follow the standard template structure
2. Include comprehensive documentation
3. Add example usage
4. Provide test coverage
5. Update this README