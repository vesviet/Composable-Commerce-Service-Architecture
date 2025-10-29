# Docker Compose Development Environment

## Overview
This directory contains Docker Compose configurations for local development of the microservices e-commerce platform.

## Structure
```
docker-compose/
├── docker-compose.yml              # Main services
├── docker-compose.infrastructure.yml # Infrastructure services
├── docker-compose.monitoring.yml   # Monitoring stack
├── docker-compose.override.yml     # Development overrides
├── .env.example                    # Environment variables template
├── scripts/
│   ├── setup.sh                    # Initial setup script
│   ├── seed-data.sh               # Seed test data
│   └── cleanup.sh                 # Cleanup script
└── configs/
    ├── kafka/
    ├── redis/
    ├── elasticsearch/
    └── nginx/
```

## Quick Start

### 1. Setup Environment
```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env

# Run setup script
./scripts/setup.sh
```

### 2. Start Infrastructure Services
```bash
docker-compose -f docker-compose.infrastructure.yml up -d
```

### 3. Start Application Services
```bash
docker-compose up -d
```

### 4. Seed Test Data
```bash
./scripts/seed-data.sh
```

## Main Docker Compose Configuration

### docker-compose.yml
```yaml
version: '3.8'

services:
  # API Gateway
  api-gateway:
    image: kong:3.3
    container_name: api-gateway
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/declarative/kong.yml
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    volumes:
      - ./configs/kong/kong.yml:/kong/declarative/kong.yml
    ports:
      - "8000:8000"
      - "8001:8001"
    depends_on:
      - catalog-service
      - order-service
      - payment-service
    networks:
      - ecommerce-network

  # Catalog & CMS Service
  catalog-service:
    build:
      context: ../../services/catalog-service
      dockerfile: Dockerfile.dev
    container_name: catalog-service
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgresql://catalog_user:catalog_pass@catalog-db:5432/catalog_db
      - REDIS_URL=redis://redis:6379
      - KAFKA_BROKERS=kafka:9092
      - ELASTICSEARCH_URL=http://elasticsearch:9200
    volumes:
      - ../../services/catalog-service:/app
      - /app/node_modules
    ports:
      - "3001:3000"
    depends_on:
      - catalog-db
      - redis
      - kafka
      - elasticsearch
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Order Service
  order-service:
    build:
      context: ../../services/order-service
      dockerfile: Dockerfile.dev
    container_name: order-service
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgresql://order_user:order_pass@order-db:5432/order_db
      - REDIS_URL=redis://redis:6379
      - KAFKA_BROKERS=kafka:9092
      - JWT_SECRET=${JWT_SECRET}
    volumes:
      - ../../services/order-service:/app
      - /app/node_modules
    ports:
      - "3002:3000"
    depends_on:
      - order-db
      - redis
      - kafka
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Payment Service
  payment-service:
    build:
      context: ../../services/payment-service
      dockerfile: Dockerfile.dev
    container_name: payment-service
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgresql://payment_user:payment_pass@payment-db:5432/payment_db
      - REDIS_URL=redis://redis:6379
      - KAFKA_BROKERS=kafka:9092
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}
      - PAYPAL_CLIENT_ID=${PAYPAL_CLIENT_ID}
      - PAYPAL_CLIENT_SECRET=${PAYPAL_CLIENT_SECRET}
    volumes:
      - ../../services/payment-service:/app
      - /app/node_modules
    ports:
      - "3003:3000"
    depends_on:
      - payment-db
      - redis
      - kafka
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Customer Service
  customer-service:
    build:
      context: ../../services/customer-service
      dockerfile: Dockerfile.dev
    container_name: customer-service
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgresql://customer_user:customer_pass@customer-db:5432/customer_db
      - REDIS_URL=redis://redis:6379
      - KAFKA_BROKERS=kafka:9092
    volumes:
      - ../../services/customer-service:/app
      - /app/node_modules
    ports:
      - "3004:3000"
    depends_on:
      - customer-db
      - redis
      - kafka
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Pricing Service
  pricing-service:
    build:
      context: ../../services/pricing-service
      dockerfile: Dockerfile.dev
    container_name: pricing-service
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgresql://pricing_user:pricing_pass@pricing-db:5432/pricing_db
      - REDIS_URL=redis://redis:6379
      - KAFKA_BROKERS=kafka:9092
    volumes:
      - ../../services/pricing-service:/app
      - /app/node_modules
    ports:
      - "3005:3000"
    depends_on:
      - pricing-db
      - redis
      - kafka
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Inventory Service
  inventory-service:
    build:
      context: ../../services/inventory-service
      dockerfile: Dockerfile.dev
    container_name: inventory-service
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgresql://inventory_user:inventory_pass@inventory-db:5432/inventory_db
      - REDIS_URL=redis://redis:6379
      - KAFKA_BROKERS=kafka:9092
    volumes:
      - ../../services/inventory-service:/app
      - /app/node_modules
    ports:
      - "3006:3000"
    depends_on:
      - inventory-db
      - redis
      - kafka
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Auth Service
  auth-service:
    build:
      context: ../../services/auth-service
      dockerfile: Dockerfile.dev
    container_name: auth-service
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgresql://auth_user:auth_pass@auth-db:5432/auth_db
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
      - JWT_EXPIRES_IN=24h
    volumes:
      - ../../services/auth-service:/app
      - /app/node_modules
    ports:
      - "3007:3000"
    depends_on:
      - auth-db
      - redis
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Notification Service
  notification-service:
    build:
      context: ../../services/notification-service
      dockerfile: Dockerfile.dev
    container_name: notification-service
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgresql://notification_user:notification_pass@notification-db:5432/notification_db
      - REDIS_URL=redis://redis:6379
      - KAFKA_BROKERS=kafka:9092
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASS=${SMTP_PASS}
      - TWILIO_ACCOUNT_SID=${TWILIO_ACCOUNT_SID}
      - TWILIO_AUTH_TOKEN=${TWILIO_AUTH_TOKEN}
    volumes:
      - ../../services/notification-service:/app
      - /app/node_modules
    ports:
      - "3008:3000"
    depends_on:
      - notification-db
      - redis
      - kafka
    networks:
      - ecommerce-network
    restart: unless-stopped

networks:
  ecommerce-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

## Infrastructure Services

### docker-compose.infrastructure.yml
```yaml
version: '3.8'

services:
  # PostgreSQL Databases
  catalog-db:
    image: postgres:15-alpine
    container_name: catalog-db
    environment:
      POSTGRES_DB: catalog_db
      POSTGRES_USER: catalog_user
      POSTGRES_PASSWORD: catalog_pass
    volumes:
      - catalog_db_data:/var/lib/postgresql/data
      - ./configs/postgres/init-catalog.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - ecommerce-network
    restart: unless-stopped

  order-db:
    image: postgres:15-alpine
    container_name: order-db
    environment:
      POSTGRES_DB: order_db
      POSTGRES_USER: order_user
      POSTGRES_PASSWORD: order_pass
    volumes:
      - order_db_data:/var/lib/postgresql/data
      - ./configs/postgres/init-order.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5433:5432"
    networks:
      - ecommerce-network
    restart: unless-stopped

  payment-db:
    image: postgres:15-alpine
    container_name: payment-db
    environment:
      POSTGRES_DB: payment_db
      POSTGRES_USER: payment_user
      POSTGRES_PASSWORD: payment_pass
    volumes:
      - payment_db_data:/var/lib/postgresql/data
    ports:
      - "5434:5432"
    networks:
      - ecommerce-network
    restart: unless-stopped

  customer-db:
    image: postgres:15-alpine
    container_name: customer-db
    environment:
      POSTGRES_DB: customer_db
      POSTGRES_USER: customer_user
      POSTGRES_PASSWORD: customer_pass
    volumes:
      - customer_db_data:/var/lib/postgresql/data
    ports:
      - "5435:5432"
    networks:
      - ecommerce-network
    restart: unless-stopped

  pricing-db:
    image: postgres:15-alpine
    container_name: pricing-db
    environment:
      POSTGRES_DB: pricing_db
      POSTGRES_USER: pricing_user
      POSTGRES_PASSWORD: pricing_pass
    volumes:
      - pricing_db_data:/var/lib/postgresql/data
    ports:
      - "5436:5432"
    networks:
      - ecommerce-network
    restart: unless-stopped

  inventory-db:
    image: postgres:15-alpine
    container_name: inventory-db
    environment:
      POSTGRES_DB: inventory_db
      POSTGRES_USER: inventory_user
      POSTGRES_PASSWORD: inventory_pass
    volumes:
      - inventory_db_data:/var/lib/postgresql/data
    ports:
      - "5437:5432"
    networks:
      - ecommerce-network
    restart: unless-stopped

  auth-db:
    image: postgres:15-alpine
    container_name: auth-db
    environment:
      POSTGRES_DB: auth_db
      POSTGRES_USER: auth_user
      POSTGRES_PASSWORD: auth_pass
    volumes:
      - auth_db_data:/var/lib/postgresql/data
    ports:
      - "5438:5432"
    networks:
      - ecommerce-network
    restart: unless-stopped

  notification-db:
    image: postgres:15-alpine
    container_name: notification-db
    environment:
      POSTGRES_DB: notification_db
      POSTGRES_USER: notification_user
      POSTGRES_PASSWORD: notification_pass
    volumes:
      - notification_db_data:/var/lib/postgresql/data
    ports:
      - "5439:5432"
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
      - ./configs/redis/redis.conf:/usr/local/etc/redis/redis.conf
    ports:
      - "6379:6379"
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Kafka & Zookeeper
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    container_name: zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    volumes:
      - zookeeper_data:/var/lib/zookeeper/data
      - zookeeper_logs:/var/lib/zookeeper/log
    ports:
      - "2181:2181"
    networks:
      - ecommerce-network
    restart: unless-stopped

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    container_name: kafka
    depends_on:
      - zookeeper
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:29092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: true
    volumes:
      - kafka_data:/var/lib/kafka/data
    ports:
      - "29092:29092"
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Kibana
  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    container_name: kibana
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - ecommerce-network
    restart: unless-stopped

volumes:
  catalog_db_data:
  order_db_data:
  payment_db_data:
  customer_db_data:
  pricing_db_data:
  inventory_db_data:
  auth_db_data:
  notification_db_data:
  redis_data:
  zookeeper_data:
  zookeeper_logs:
  kafka_data:
  elasticsearch_data:

networks:
  ecommerce-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

## Monitoring Stack

### docker-compose.monitoring.yml
```yaml
version: '3.8'

services:
  # Prometheus
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    volumes:
      - ./configs/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Grafana
  grafana:
    image: grafana/grafana:10.0.0
    container_name: grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./configs/grafana/provisioning:/etc/grafana/provisioning
      - ./configs/grafana/dashboards:/var/lib/grafana/dashboards
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Jaeger (Distributed Tracing)
  jaeger:
    image: jaegertracing/all-in-one:1.47
    container_name: jaeger
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    ports:
      - "16686:16686"
      - "14268:14268"
      - "14250:14250"
    networks:
      - ecommerce-network
    restart: unless-stopped

  # Node Exporter
  node-exporter:
    image: prom/node-exporter:v1.6.0
    container_name: node-exporter
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    ports:
      - "9100:9100"
    networks:
      - ecommerce-network
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:

networks:
  ecommerce-network:
    external: true
```

## Environment Configuration

### .env.example
```bash
# Database Configuration
POSTGRES_PASSWORD=postgres123
REDIS_PASSWORD=redis123

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-here

# Payment Gateways
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
PAYPAL_CLIENT_ID=your_paypal_client_id
PAYPAL_CLIENT_SECRET=your_paypal_client_secret

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# SMS Configuration
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token

# External APIs
ELASTICSEARCH_URL=http://elasticsearch:9200
KAFKA_BROKERS=kafka:9092
REDIS_URL=redis://redis:6379

# Development Settings
NODE_ENV=development
LOG_LEVEL=debug
```

## Setup Scripts

### scripts/setup.sh
```bash
#!/bin/bash

echo "🚀 Setting up E-commerce Microservices Development Environment"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✅ Please edit .env file with your configuration"
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p logs
mkdir -p data/postgres
mkdir -p data/redis
mkdir -p data/elasticsearch
mkdir -p data/kafka

# Pull all required images
echo "📦 Pulling Docker images..."
docker-compose -f docker-compose.infrastructure.yml pull
docker-compose -f docker-compose.monitoring.yml pull

# Start infrastructure services
echo "🏗️ Starting infrastructure services..."
docker-compose -f docker-compose.infrastructure.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check if Kafka is ready
echo "🔍 Checking Kafka readiness..."
docker-compose -f docker-compose.infrastructure.yml exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Create Kafka topics
echo "📋 Creating Kafka topics..."
./scripts/create-kafka-topics.sh

# Start monitoring services
echo "📊 Starting monitoring services..."
docker-compose -f docker-compose.monitoring.yml up -d

echo "✅ Infrastructure setup complete!"
echo ""
echo "🌐 Access URLs:"
echo "  - Kafka UI: http://localhost:8080"
echo "  - Elasticsearch: http://localhost:9200"
echo "  - Kibana: http://localhost:5601"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/admin123)"
echo "  - Jaeger: http://localhost:16686"
echo ""
echo "🚀 Ready to start application services with:"
echo "  docker-compose up -d"
```

### scripts/create-kafka-topics.sh
```bash
#!/bin/bash

echo "📋 Creating Kafka topics..."

KAFKA_CONTAINER="kafka"
TOPICS=(
    "order.created"
    "order.updated"
    "order.cancelled"
    "payment.processed"
    "payment.failed"
    "inventory.updated"
    "product.created"
    "product.updated"
    "customer.created"
    "customer.updated"
    "notification.email"
    "notification.sms"
    "fulfillment.created"
    "fulfillment.updated"
    "fulfillment.completed"
)

for topic in "${TOPICS[@]}"; do
    echo "Creating topic: $topic"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --create \
        --bootstrap-server localhost:9092 \
        --replication-factor 1 \
        --partitions 3 \
        --topic $topic \
        --if-not-exists
done

echo "✅ Kafka topics created successfully!"
```

### scripts/seed-data.sh
```bash
#!/bin/bash

echo "🌱 Seeding test data..."

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Seed catalog data
echo "📦 Seeding catalog data..."
curl -X POST http://localhost:3001/api/v1/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Premium Wireless Headphones",
    "description": "High-quality wireless headphones with noise cancellation",
    "category": "Electronics",
    "brand": "AudioTech",
    "sku": "SKU-HEADPHONES-001",
    "attributes": {
      "color": "Black",
      "connectivity": "Bluetooth 5.0",
      "batteryLife": "30 hours"
    }
  }'

# Seed pricing data
echo "💰 Seeding pricing data..."
curl -X POST http://localhost:3005/api/v1/pricing \
  -H "Content-Type: application/json" \
  -d '{
    "sku": "SKU-HEADPHONES-001",
    "warehouseId": "US-WEST-01",
    "basePrice": 299.99,
    "currency": "USD"
  }'

# Seed inventory data
echo "📦 Seeding inventory data..."
curl -X POST http://localhost:3006/api/v1/inventory \
  -H "Content-Type: application/json" \
  -d '{
    "sku": "SKU-HEADPHONES-001",
    "warehouseId": "US-WEST-01",
    "quantity": 100,
    "reservedQuantity": 0
  }'

echo "✅ Test data seeded successfully!"
```

## Development Workflow

### Starting Services
```bash
# Start infrastructure
docker-compose -f docker-compose.infrastructure.yml up -d

# Start monitoring
docker-compose -f docker-compose.monitoring.yml up -d

# Start application services
docker-compose up -d

# View logs
docker-compose logs -f catalog-service
```

### Testing APIs
```bash
# Test catalog service
curl http://localhost:3001/api/v1/products

# Test order service
curl http://localhost:3002/api/v1/orders

# Test through API Gateway
curl http://localhost:8000/api/v1/products
```

### Debugging
```bash
# Access service container
docker exec -it catalog-service sh

# View service logs
docker-compose logs -f catalog-service

# Check service health
curl http://localhost:3001/health
```

### Cleanup
```bash
# Stop all services
docker-compose down
docker-compose -f docker-compose.infrastructure.yml down
docker-compose -f docker-compose.monitoring.yml down

# Remove volumes (careful - this deletes data!)
docker-compose down -v
```

This Docker Compose setup provides a complete local development environment that mirrors the production Kubernetes deployment while being easy to use for development and testing.