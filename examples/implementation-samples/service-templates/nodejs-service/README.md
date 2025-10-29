# Node.js Microservice Template

## Overview
Production-ready Node.js microservice template with TypeScript, following the e-commerce platform architecture patterns.

## Tech Stack
- **Runtime**: Node.js 18+
- **Language**: TypeScript
- **Framework**: Express.js
- **Database**: PostgreSQL with Prisma ORM
- **Messaging**: Kafka with KafkaJS
- **Caching**: Redis with ioredis
- **Monitoring**: Prometheus metrics, Winston logging
- **Testing**: Jest with Supertest
- **Documentation**: Swagger/OpenAPI

## Project Structure
```
nodejs-service/
├── src/
│   ├── controllers/               # HTTP route controllers
│   │   ├── health.controller.ts
│   │   ├── product.controller.ts
│   │   └── index.ts
│   ├── services/                  # Business logic services
│   │   ├── product.service.ts
│   │   ├── cache.service.ts
│   │   └── index.ts
│   ├── repositories/              # Data access layer
│   │   ├── product.repository.ts
│   │   └── index.ts
│   ├── models/                    # TypeScript interfaces/types
│   │   ├── product.model.ts
│   │   ├── api.model.ts
│   │   └── index.ts
│   ├── events/                    # Event handlers
│   │   ├── producers/
│   │   │   └── product.producer.ts
│   │   ├── consumers/
│   │   │   └── inventory.consumer.ts
│   │   └── index.ts
│   ├── middleware/                # Express middleware
│   │   ├── auth.middleware.ts
│   │   ├── validation.middleware.ts
│   │   ├── error.middleware.ts
│   │   └── index.ts
│   ├── utils/                     # Utility functions
│   │   ├── logger.ts
│   │   ├── metrics.ts
│   │   ├── database.ts
│   │   └── index.ts
│   ├── config/                    # Configuration
│   │   ├── database.ts
│   │   ├── kafka.ts
│   │   ├── redis.ts
│   │   └── index.ts
│   ├── app.ts                     # Express app setup
│   └── server.ts                  # Server entry point
├── tests/
│   ├── unit/                      # Unit tests
│   │   ├── services/
│   │   ├── controllers/
│   │   └── utils/
│   ├── integration/               # Integration tests
│   │   ├── api/
│   │   └── events/
│   ├── fixtures/                  # Test data
│   └── setup.ts                   # Test setup
├── prisma/                        # Database schema and migrations
│   ├── schema.prisma
│   ├── migrations/
│   └── seed.ts
├── docs/                          # Documentation
│   ├── api.md
│   └── deployment.md
├── scripts/                       # Utility scripts
│   ├── customize.sh
│   ├── migrate.sh
│   └── seed.sh
├── k8s/                          # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── secrets.yaml
├── .github/workflows/             # GitHub Actions
│   ├── ci.yml
│   └── cd.yml
├── Dockerfile
├── docker-compose.yml
├── package.json
├── tsconfig.json
├── jest.config.js
├── .env.example
└── README.md
```

## Quick Start

### 1. Setup
```bash
# Clone template
cp -r nodejs-service my-catalog-service
cd my-catalog-service

# Customize service name
./scripts/customize.sh my-catalog-service

# Install dependencies
npm install

# Copy environment file
cp .env.example .env
```

### 2. Database Setup
```bash
# Start PostgreSQL
docker-compose up -d postgres

# Generate Prisma client
npx prisma generate

# Run migrations
npx prisma migrate dev

# Seed data (optional)
npm run seed
```

### 3. Start Development
```bash
# Start all dependencies
docker-compose up -d

# Start in development mode
npm run dev

# Service will be available at http://localhost:3000
```

## Core Files

### Server Entry Point (src/server.ts)
```typescript
import { createServer } from 'http';
import app from './app';
import { logger } from './utils/logger';
import { connectDatabase } from './utils/database';
import { initializeKafka } from './events';
import { gracefulShutdown } from './utils/shutdown';

const PORT = process.env.PORT || 3000;

async function startServer() {
  try {
    // Initialize database connection
    await connectDatabase();
    logger.info('Database connected successfully');

    // Initialize Kafka
    await initializeKafka();
    logger.info('Kafka initialized successfully');

    // Start HTTP server
    const server = createServer(app);
    
    server.listen(PORT, () => {
      logger.info(`Server running on port ${PORT}`);
    });

    // Graceful shutdown
    process.on('SIGTERM', () => gracefulShutdown(server));
    process.on('SIGINT', () => gracefulShutdown(server));

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
```

### Express App Setup (src/app.ts)
```typescript
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { rateLimit } from 'express-rate-limit';

import { logger, requestLogger } from './utils/logger';
import { metricsMiddleware } from './utils/metrics';
import { errorHandler } from './middleware/error.middleware';
import { authMiddleware } from './middleware/auth.middleware';

// Import routes
import healthRoutes from './controllers/health.controller';
import productRoutes from './controllers/product.controller';

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP',
});
app.use(limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(compression());

// Logging and metrics
app.use(requestLogger);
app.use(metricsMiddleware);

// Health check routes (no auth required)
app.use('/health', healthRoutes);
app.use('/ready', healthRoutes);
app.use('/metrics', healthRoutes);

// API routes (with auth)
app.use('/api/v1/products', authMiddleware, productRoutes);

// Error handling
app.use(errorHandler);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
  });
});

export default app;
```

### Product Controller (src/controllers/product.controller.ts)
```typescript
import { Router, Request, Response, NextFunction } from 'express';
import { ProductService } from '../services/product.service';
import { validateRequest } from '../middleware/validation.middleware';
import { CreateProductDto, UpdateProductDto } from '../models/product.model';
import { logger } from '../utils/logger';
import { asyncHandler } from '../utils/async-handler';

const router = Router();
const productService = new ProductService();

// GET /api/v1/products
router.get('/', asyncHandler(async (req: Request, res: Response) => {
  const { page = 1, limit = 10, search, category } = req.query;
  
  const result = await productService.getProducts({
    page: Number(page),
    limit: Number(limit),
    search: search as string,
    category: category as string,
  });

  res.json({
    success: true,
    data: result.products,
    pagination: {
      page: result.page,
      limit: result.limit,
      total: result.total,
      pages: Math.ceil(result.total / result.limit),
    },
  });
}));

// GET /api/v1/products/:id
router.get('/:id', asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params;
  const customerId = req.user?.id;

  const product = await productService.getProductById(id, customerId);
  
  if (!product) {
    return res.status(404).json({
      success: false,
      error: 'Product not found',
    });
  }

  res.json({
    success: true,
    data: product,
  });
}));

// POST /api/v1/products
router.post('/', 
  validateRequest(CreateProductDto),
  asyncHandler(async (req: Request, res: Response) => {
    const productData = req.body;
    const userId = req.user?.id;

    const product = await productService.createProduct(productData, userId);

    res.status(201).json({
      success: true,
      data: product,
    });
  })
);

// PUT /api/v1/products/:id
router.put('/:id',
  validateRequest(UpdateProductDto),
  asyncHandler(async (req: Request, res: Response) => {
    const { id } = req.params;
    const updateData = req.body;
    const userId = req.user?.id;

    const product = await productService.updateProduct(id, updateData, userId);

    if (!product) {
      return res.status(404).json({
        success: false,
        error: 'Product not found',
      });
    }

    res.json({
      success: true,
      data: product,
    });
  })
);

// DELETE /api/v1/products/:id
router.delete('/:id', asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params;
  const userId = req.user?.id;

  const deleted = await productService.deleteProduct(id, userId);

  if (!deleted) {
    return res.status(404).json({
      success: false,
      error: 'Product not found',
    });
  }

  res.status(204).send();
}));

export default router;
```

### Product Service (src/services/product.service.ts)
```typescript
import { ProductRepository } from '../repositories/product.repository';
import { CacheService } from './cache.service';
import { ProductProducer } from '../events/producers/product.producer';
import { CreateProductDto, UpdateProductDto, Product } from '../models/product.model';
import { logger } from '../utils/logger';
import { AppError } from '../utils/errors';

export class ProductService {
  private productRepository: ProductRepository;
  private cacheService: CacheService;
  private productProducer: ProductProducer;

  constructor() {
    this.productRepository = new ProductRepository();
    this.cacheService = new CacheService();
    this.productProducer = new ProductProducer();
  }

  async getProducts(params: {
    page: number;
    limit: number;
    search?: string;
    category?: string;
  }) {
    const cacheKey = `products:${JSON.stringify(params)}`;
    
    // Try cache first
    const cached = await this.cacheService.get(cacheKey);
    if (cached) {
      logger.debug('Products retrieved from cache');
      return cached;
    }

    // Get from database
    const result = await this.productRepository.findMany(params);
    
    // Cache result
    await this.cacheService.set(cacheKey, result, 300); // 5 minutes
    
    logger.info(`Retrieved ${result.products.length} products`);
    return result;
  }

  async getProductById(id: string, customerId?: string): Promise<Product | null> {
    const cacheKey = `product:${id}:${customerId || 'anonymous'}`;
    
    // Try cache first
    const cached = await this.cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }

    // Get complete product data (with pricing, inventory, etc.)
    const product = await this.productRepository.findByIdComplete(id, customerId);
    
    if (product) {
      // Cache result
      await this.cacheService.set(cacheKey, product, 300);
      logger.info(`Product ${id} retrieved for customer ${customerId}`);
    }

    return product;
  }

  async createProduct(data: CreateProductDto, userId: string): Promise<Product> {
    try {
      // Create product
      const product = await this.productRepository.create({
        ...data,
        createdBy: userId,
      });

      // Publish event
      await this.productProducer.publishProductCreated(product);

      // Invalidate cache
      await this.cacheService.invalidatePattern('products:*');

      logger.info(`Product ${product.id} created by user ${userId}`);
      return product;

    } catch (error) {
      logger.error('Failed to create product:', error);
      throw new AppError('Failed to create product', 500);
    }
  }

  async updateProduct(id: string, data: UpdateProductDto, userId: string): Promise<Product | null> {
    try {
      const product = await this.productRepository.update(id, {
        ...data,
        updatedBy: userId,
      });

      if (product) {
        // Publish event
        await this.productProducer.publishProductUpdated(product);

        // Invalidate cache
        await this.cacheService.invalidatePattern(`product:${id}:*`);
        await this.cacheService.invalidatePattern('products:*');

        logger.info(`Product ${id} updated by user ${userId}`);
      }

      return product;

    } catch (error) {
      logger.error(`Failed to update product ${id}:`, error);
      throw new AppError('Failed to update product', 500);
    }
  }

  async deleteProduct(id: string, userId: string): Promise<boolean> {
    try {
      const deleted = await this.productRepository.delete(id);

      if (deleted) {
        // Publish event
        await this.productProducer.publishProductDeleted(id, userId);

        // Invalidate cache
        await this.cacheService.invalidatePattern(`product:${id}:*`);
        await this.cacheService.invalidatePattern('products:*');

        logger.info(`Product ${id} deleted by user ${userId}`);
      }

      return deleted;

    } catch (error) {
      logger.error(`Failed to delete product ${id}:`, error);
      throw new AppError('Failed to delete product', 500);
    }
  }
}
```

### Health Controller (src/controllers/health.controller.ts)
```typescript
import { Router, Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { register, collectDefaultMetrics } from 'prom-client';
import { redis } from '../config/redis';
import { kafka } from '../config/kafka';

const router = Router();
const prisma = new PrismaClient();

// Collect default metrics
collectDefaultMetrics();

// Health check endpoint
router.get('/health', async (req: Request, res: Response) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: process.env.SERVICE_NAME || 'nodejs-service',
    version: process.env.SERVICE_VERSION || '1.0.0',
    uptime: process.uptime(),
  };

  res.json(health);
});

// Readiness check endpoint
router.get('/ready', async (req: Request, res: Response) => {
  const checks = {
    database: false,
    redis: false,
    kafka: false,
  };

  try {
    // Check database
    await prisma.$queryRaw`SELECT 1`;
    checks.database = true;
  } catch (error) {
    // Database not ready
  }

  try {
    // Check Redis
    await redis.ping();
    checks.redis = true;
  } catch (error) {
    // Redis not ready
  }

  try {
    // Check Kafka
    const admin = kafka.admin();
    await admin.connect();
    await admin.listTopics();
    await admin.disconnect();
    checks.kafka = true;
  } catch (error) {
    // Kafka not ready
  }

  const allReady = Object.values(checks).every(check => check);
  const status = allReady ? 200 : 503;

  res.status(status).json({
    status: allReady ? 'ready' : 'not ready',
    checks,
    timestamp: new Date().toISOString(),
  });
});

// Metrics endpoint
router.get('/metrics', async (req: Request, res: Response) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

export default router;
```

### Package.json
```json
{
  "name": "nodejs-service-template",
  "version": "1.0.0",
  "description": "Node.js microservice template for e-commerce platform",
  "main": "dist/server.js",
  "scripts": {
    "dev": "nodemon src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "jest",
    "test:unit": "jest --testPathPattern=tests/unit",
    "test:integration": "jest --testPathPattern=tests/integration",
    "test:coverage": "jest --coverage",
    "test:watch": "jest --watch",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "migrate:dev": "prisma migrate dev",
    "migrate:deploy": "prisma migrate deploy",
    "migrate:reset": "prisma migrate reset",
    "generate": "prisma generate",
    "seed": "ts-node prisma/seed.ts",
    "docker:build": "docker build -t nodejs-service .",
    "docker:run": "docker run -p 3000:3000 nodejs-service"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "compression": "^1.7.4",
    "express-rate-limit": "^6.8.1",
    "@prisma/client": "^5.1.1",
    "kafkajs": "^2.2.4",
    "ioredis": "^5.3.2",
    "winston": "^3.10.0",
    "prom-client": "^14.2.0",
    "joi": "^17.9.2",
    "jsonwebtoken": "^9.0.1",
    "bcryptjs": "^2.4.3",
    "uuid": "^9.0.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "@types/node": "^20.4.5",
    "@types/express": "^4.17.17",
    "@types/cors": "^2.8.13",
    "@types/compression": "^1.7.2",
    "@types/jsonwebtoken": "^9.0.2",
    "@types/bcryptjs": "^2.4.2",
    "@types/uuid": "^9.0.2",
    "@types/jest": "^29.5.3",
    "@types/supertest": "^2.0.12",
    "typescript": "^5.1.6",
    "ts-node": "^10.9.1",
    "nodemon": "^3.0.1",
    "jest": "^29.6.1",
    "ts-jest": "^29.1.1",
    "supertest": "^6.3.3",
    "eslint": "^8.45.0",
    "@typescript-eslint/eslint-plugin": "^6.2.0",
    "@typescript-eslint/parser": "^6.2.0",
    "prisma": "^5.1.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### Dockerfile
```dockerfile
# Multi-stage build
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY prisma ./prisma/

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./
COPY --from=builder --chown=nodejs:nodejs /app/prisma ./prisma

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start application
CMD ["node", "dist/server.js"]
```

This Node.js service template provides a complete, production-ready foundation for building microservices in the e-commerce platform with all necessary features and best practices included.