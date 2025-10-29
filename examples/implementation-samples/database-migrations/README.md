# Database Migrations

## Overview
Comprehensive database migration system for all microservices in the e-commerce platform. Each service manages its own database schema with version-controlled migrations, rollback capabilities, and environment-specific configurations.

## Migration Tools by Technology

### Node.js Services
- **Prisma Migrate**: Schema-first migrations with automatic generation
- **Knex.js**: Query builder with migration support
- **Sequelize**: ORM with migration capabilities

### Java Services
- **Flyway**: Database migration tool with version control
- **Liquibase**: Database schema change management

### Python Services
- **Alembic**: Database migration tool for SQLAlchemy
- **Django Migrations**: Built-in migration system

### Go Services
- **golang-migrate**: Database migration library
- **Goose**: Database migration tool

## Directory Structure

```
database-migrations/
├── catalog-service/               # Catalog & CMS Service migrations
│   ├── prisma/                    # Prisma migrations (Node.js)
│   │   ├── schema.prisma
│   │   ├── migrations/
│   │   └── seed.ts
│   ├── flyway/                    # Flyway migrations (Java)
│   │   ├── sql/
│   │   └── flyway.conf
│   └── scripts/
│       ├── migrate.sh
│       └── rollback.sh
├── order-service/                 # Order Service migrations
│   ├── alembic/                   # Alembic migrations (Python)
│   │   ├── versions/
│   │   ├── alembic.ini
│   │   └── env.py
│   └── scripts/
├── customer-service/              # Customer Service migrations
│   ├── golang-migrate/            # Go migrations
│   │   ├── migrations/
│   │   └── migrate.go
│   └── scripts/
├── payment-service/               # Payment Service migrations
├── pricing-service/               # Pricing Service migrations
├── inventory-service/             # Inventory Service migrations
├── auth-service/                  # Auth Service migrations
├── notification-service/          # Notification Service migrations
├── search-service/                # Search Service migrations
├── review-service/                # Review Service migrations
├── analytics-service/             # Analytics Service migrations
├── loyalty-service/               # Loyalty Service migrations
├── shipping-service/              # Shipping Service migrations
└── shared/                        # Shared utilities and scripts
    ├── scripts/
    │   ├── migrate-all.sh
    │   ├── rollback-all.sh
    │   └── backup-all.sh
    ├── templates/
    └── docs/
```

## Catalog Service Migrations (Prisma)

### Schema Definition (catalog-service/prisma/schema.prisma)
```prisma
// This is your Prisma schema file,
// learn more about it in the docs: https://pris.ly/d/prisma-schema

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Product {
  id          String   @id @default(cuid())
  sku         String   @unique
  name        String
  description String?
  slug        String   @unique
  
  // Category relationship
  categoryId  String
  category    Category @relation(fields: [categoryId], references: [id])
  
  // Brand relationship
  brandId     String
  brand       Brand    @relation(fields: [brandId], references: [id])
  
  // Product attributes (JSON)
  attributes  Json     @default("{}")
  
  // SEO fields
  metaTitle       String?
  metaDescription String?
  metaKeywords    String?
  
  // Status and visibility
  status      ProductStatus @default(DRAFT)
  isVisible   Boolean       @default(false)
  isFeatured  Boolean       @default(false)
  
  // Timestamps
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  publishedAt DateTime?
  
  // Audit fields
  createdBy   String
  updatedBy   String?
  
  // Relations
  media       ProductMedia[]
  variants    ProductVariant[]
  reviews     ProductReview[]
  
  @@map("products")
}

model Category {
  id          String    @id @default(cuid())
  name        String
  slug        String    @unique
  description String?
  
  // Hierarchy
  parentId    String?
  parent      Category? @relation("CategoryHierarchy", fields: [parentId], references: [id])
  children    Category[] @relation("CategoryHierarchy")
  
  // SEO fields
  metaTitle       String?
  metaDescription String?
  
  // Display settings
  sortOrder   Int       @default(0)
  isVisible   Boolean   @default(true)
  
  // Timestamps
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  
  // Relations
  products    Product[]
  
  @@map("categories")
}

model Brand {
  id          String   @id @default(cuid())
  name        String   @unique
  slug        String   @unique
  description String?
  logoUrl     String?
  websiteUrl  String?
  
  // Status
  isActive    Boolean  @default(true)
  
  // Timestamps
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  // Relations
  products    Product[]
  
  @@map("brands")
}

model ProductVariant {
  id        String @id @default(cuid())
  productId String
  product   Product @relation(fields: [productId], references: [id], onDelete: Cascade)
  
  // Variant identification
  sku       String @unique
  name      String
  
  // Variant attributes (color, size, etc.)
  attributes Json   @default("{}")
  
  // Pricing (base price, actual pricing handled by Pricing Service)
  basePrice  Decimal @db.Decimal(10, 2)
  
  // Status
  isActive   Boolean @default(true)
  
  // Timestamps
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt
  
  @@map("product_variants")
}

model ProductMedia {
  id        String @id @default(cuid())
  productId String
  product   Product @relation(fields: [productId], references: [id], onDelete: Cascade)
  
  // Media details
  type      MediaType
  url       String
  altText   String?
  title     String?
  
  // Display settings
  sortOrder Int       @default(0)
  isPrimary Boolean   @default(false)
  
  // Timestamps
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt
  
  @@map("product_media")
}

model ProductReview {
  id        String @id @default(cuid())
  productId String
  product   Product @relation(fields: [productId], references: [id], onDelete: Cascade)
  
  // Review details
  customerId String
  rating     Int    @db.SmallInt // 1-5 stars
  title      String?
  content    String?
  
  // Status
  status     ReviewStatus @default(PENDING)
  
  // Timestamps
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt
  
  @@map("product_reviews")
}

// CMS Models
model Page {
  id          String   @id @default(cuid())
  title       String
  slug        String   @unique
  content     String   // Rich text content
  excerpt     String?
  
  // SEO fields
  metaTitle       String?
  metaDescription String?
  metaKeywords    String?
  
  // Status and visibility
  status      PageStatus @default(DRAFT)
  isVisible   Boolean    @default(false)
  
  // Timestamps
  createdAt   DateTime   @default(now())
  updatedAt   DateTime   @updatedAt
  publishedAt DateTime?
  
  // Audit fields
  createdBy   String
  updatedBy   String?
  
  @@map("pages")
}

model BlogPost {
  id          String   @id @default(cuid())
  title       String
  slug        String   @unique
  content     String   // Rich text content
  excerpt     String?
  featuredImage String?
  
  // SEO fields
  metaTitle       String?
  metaDescription String?
  metaKeywords    String?
  
  // Categorization
  tags        String[] @default([])
  
  // Status and visibility
  status      PostStatus @default(DRAFT)
  isVisible   Boolean    @default(false)
  isFeatured  Boolean    @default(false)
  
  // Timestamps
  createdAt   DateTime   @default(now())
  updatedAt   DateTime   @updatedAt
  publishedAt DateTime?
  
  // Audit fields
  createdBy   String
  updatedBy   String?
  
  @@map("blog_posts")
}

// Enums
enum ProductStatus {
  DRAFT
  ACTIVE
  INACTIVE
  DISCONTINUED
}

enum MediaType {
  IMAGE
  VIDEO
  DOCUMENT
}

enum ReviewStatus {
  PENDING
  APPROVED
  REJECTED
}

enum PageStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}

enum PostStatus {
  DRAFT
  PUBLISHED
  ARCHIVED
}
```

### Migration Script (catalog-service/scripts/migrate.sh)
```bash
#!/bin/bash

set -e

COMMAND=${1:-up}
ENVIRONMENT=${2:-development}

echo "🗄️ Running Catalog Service migrations..."
echo "Command: $COMMAND"
echo "Environment: $ENVIRONMENT"

# Load environment variables
if [ -f ".env.$ENVIRONMENT" ]; then
    export $(cat .env.$ENVIRONMENT | xargs)
fi

case $COMMAND in
    "up"|"deploy")
        echo "📈 Running migrations..."
        if [ "$ENVIRONMENT" = "production" ]; then
            npx prisma migrate deploy
        else
            npx prisma migrate dev
        fi
        
        echo "🔄 Generating Prisma client..."
        npx prisma generate
        
        if [ "$COMMAND" = "up" ] && [ "$ENVIRONMENT" != "production" ]; then
            echo "🌱 Seeding database..."
            npx prisma db seed
        fi
        ;;
        
    "down"|"rollback")
        STEPS=${3:-1}
        echo "📉 Rolling back $STEPS migration(s)..."
        
        # Get migration history
        MIGRATIONS=$(npx prisma migrate status --json | jq -r '.migrations[] | select(.status == "Applied") | .name' | tail -n $STEPS)
        
        for migration in $MIGRATIONS; do
            echo "Rolling back migration: $migration"
            # Note: Prisma doesn't have built-in rollback, need custom implementation
            # This would require maintaining down migration files
        done
        ;;
        
    "reset")
        echo "🔄 Resetting database..."
        npx prisma migrate reset --force
        ;;
        
    "status")
        echo "📊 Migration status..."
        npx prisma migrate status
        ;;
        
    "generate")
        echo "🔄 Generating Prisma client..."
        npx prisma generate
        ;;
        
    *)
        echo "Usage: $0 {up|down|reset|status|generate} [environment] [steps]"
        echo "Commands:"
        echo "  up       - Run pending migrations"
        echo "  deploy   - Deploy migrations (production)"
        echo "  down     - Rollback migrations"
        echo "  reset    - Reset database"
        echo "  status   - Show migration status"
        echo "  generate - Generate Prisma client"
        exit 1
        ;;
esac

echo "✅ Catalog Service migration completed!"
```

### Seed Data (catalog-service/prisma/seed.ts)
```typescript
import { PrismaClient, ProductStatus, MediaType } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding Catalog Service database...');

  // Create brands
  const brands = await Promise.all([
    prisma.brand.upsert({
      where: { slug: 'audiotech' },
      update: {},
      create: {
        name: 'AudioTech',
        slug: 'audiotech',
        description: 'Premium audio equipment manufacturer',
        websiteUrl: 'https://audiotech.example.com',
        isActive: true,
      },
    }),
    prisma.brand.upsert({
      where: { slug: 'techgear' },
      update: {},
      create: {
        name: 'TechGear',
        slug: 'techgear',
        description: 'Innovative technology accessories',
        websiteUrl: 'https://techgear.example.com',
        isActive: true,
      },
    }),
  ]);

  // Create categories
  const electronicsCategory = await prisma.category.upsert({
    where: { slug: 'electronics' },
    update: {},
    create: {
      name: 'Electronics',
      slug: 'electronics',
      description: 'Electronic devices and accessories',
      isVisible: true,
      sortOrder: 1,
    },
  });

  const audioCategory = await prisma.category.upsert({
    where: { slug: 'audio' },
    update: {},
    create: {
      name: 'Audio',
      slug: 'audio',
      description: 'Audio equipment and accessories',
      parentId: electronicsCategory.id,
      isVisible: true,
      sortOrder: 1,
    },
  });

  const headphonesCategory = await prisma.category.upsert({
    where: { slug: 'headphones' },
    update: {},
    create: {
      name: 'Headphones',
      slug: 'headphones',
      description: 'Headphones and earphones',
      parentId: audioCategory.id,
      isVisible: true,
      sortOrder: 1,
    },
  });

  // Create products
  const products = await Promise.all([
    prisma.product.upsert({
      where: { sku: 'SKU-HEADPHONES-001' },
      update: {},
      create: {
        sku: 'SKU-HEADPHONES-001',
        name: 'Premium Wireless Headphones',
        slug: 'premium-wireless-headphones',
        description: 'High-quality wireless headphones with noise cancellation and 30-hour battery life.',
        categoryId: headphonesCategory.id,
        brandId: brands[0].id,
        attributes: {
          color: 'Black',
          connectivity: 'Bluetooth 5.0',
          batteryLife: '30 hours',
          weight: '250g',
          noiseCancellation: true,
        },
        metaTitle: 'Premium Wireless Headphones - AudioTech',
        metaDescription: 'Experience superior sound quality with our premium wireless headphones featuring active noise cancellation.',
        status: ProductStatus.ACTIVE,
        isVisible: true,
        isFeatured: true,
        createdBy: 'seed-script',
        publishedAt: new Date(),
      },
    }),
    prisma.product.upsert({
      where: { sku: 'SKU-EARBUDS-001' },
      update: {},
      create: {
        sku: 'SKU-EARBUDS-001',
        name: 'True Wireless Earbuds',
        slug: 'true-wireless-earbuds',
        description: 'Compact true wireless earbuds with premium sound quality and long battery life.',
        categoryId: headphonesCategory.id,
        brandId: brands[1].id,
        attributes: {
          color: 'White',
          connectivity: 'Bluetooth 5.2',
          batteryLife: '8 hours + 24 hours case',
          weight: '5g each',
          waterResistance: 'IPX4',
        },
        metaTitle: 'True Wireless Earbuds - TechGear',
        metaDescription: 'Enjoy freedom of movement with our true wireless earbuds featuring crystal clear sound.',
        status: ProductStatus.ACTIVE,
        isVisible: true,
        createdBy: 'seed-script',
        publishedAt: new Date(),
      },
    }),
  ]);

  // Create product variants
  await Promise.all([
    prisma.productVariant.create({
      data: {
        productId: products[0].id,
        sku: 'SKU-HEADPHONES-001-BLACK',
        name: 'Premium Wireless Headphones - Black',
        attributes: { color: 'Black' },
        basePrice: 299.99,
      },
    }),
    prisma.productVariant.create({
      data: {
        productId: products[0].id,
        sku: 'SKU-HEADPHONES-001-WHITE',
        name: 'Premium Wireless Headphones - White',
        attributes: { color: 'White' },
        basePrice: 299.99,
      },
    }),
  ]);

  // Create product media
  await Promise.all([
    prisma.productMedia.create({
      data: {
        productId: products[0].id,
        type: MediaType.IMAGE,
        url: 'https://cdn.example.com/products/headphones-001/main.jpg',
        altText: 'Premium Wireless Headphones - Main View',
        isPrimary: true,
        sortOrder: 1,
      },
    }),
    prisma.productMedia.create({
      data: {
        productId: products[0].id,
        type: MediaType.IMAGE,
        url: 'https://cdn.example.com/products/headphones-001/side.jpg',
        altText: 'Premium Wireless Headphones - Side View',
        sortOrder: 2,
      },
    }),
  ]);

  // Create sample reviews
  await Promise.all([
    prisma.productReview.create({
      data: {
        productId: products[0].id,
        customerId: 'customer-1',
        rating: 5,
        title: 'Excellent sound quality!',
        content: 'These headphones have amazing sound quality and the noise cancellation works perfectly.',
        status: 'APPROVED',
      },
    }),
    prisma.productReview.create({
      data: {
        productId: products[0].id,
        customerId: 'customer-2',
        rating: 4,
        title: 'Great headphones',
        content: 'Very comfortable to wear for long periods. Battery life is as advertised.',
        status: 'APPROVED',
      },
    }),
  ]);

  // Create CMS pages
  await prisma.page.create({
    data: {
      title: 'About Us',
      slug: 'about-us',
      content: '<h1>About Our Company</h1><p>We are a leading e-commerce platform...</p>',
      excerpt: 'Learn more about our company and mission.',
      metaTitle: 'About Us - E-commerce Platform',
      metaDescription: 'Learn about our company, mission, and values.',
      status: 'PUBLISHED',
      isVisible: true,
      createdBy: 'seed-script',
      publishedAt: new Date(),
    },
  });

  // Create blog posts
  await prisma.blogPost.create({
    data: {
      title: 'The Future of Audio Technology',
      slug: 'future-of-audio-technology',
      content: '<h1>The Future of Audio Technology</h1><p>Audio technology is evolving rapidly...</p>',
      excerpt: 'Explore the latest trends and innovations in audio technology.',
      tags: ['technology', 'audio', 'innovation'],
      metaTitle: 'The Future of Audio Technology - Blog',
      metaDescription: 'Discover the latest trends and innovations shaping the future of audio technology.',
      status: 'PUBLISHED',
      isVisible: true,
      isFeatured: true,
      createdBy: 'seed-script',
      publishedAt: new Date(),
    },
  });

  console.log('✅ Catalog Service database seeded successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

## Order Service Migrations (Alembic/Python)

### Alembic Configuration (order-service/alembic/alembic.ini)
```ini
# A generic, single database configuration.

[alembic]
# path to migration scripts
script_location = alembic

# template used to generate migration file names; The default value is %%(rev)s_%%(slug)s
file_template = %%(year)d%%(month).2d%%(day).2d_%%(hour).2d%%(minute).2d_%%(rev)s_%%(slug)s

# sys.path path, will be prepended to sys.path if present.
prepend_sys_path = .

# timezone to use when rendering the date within the migration file
# as well as the filename.
timezone = UTC

# max length of characters to apply to the "slug" field
truncate_slug_length = 40

# set to 'true' to run the environment during
# the 'revision' command, regardless of autogenerate
revision_environment = false

# set to 'true' to allow .pyc and .pyo files without
# a source .py file to be detected as revisions in the
# versions/ directory
sourceless = false

# version path separator; As mentioned above, this is the character used to split
# version_locations. The default within new alembic.ini files is "os", which uses
# os.pathsep. If this key is omitted entirely, it falls back to the legacy
# behavior of splitting on spaces and/or commas.
version_path_separator = :

# set to 'true' to search source files recursively
# in each "version_locations" directory
recursive_version_locations = false

# the output encoding used when revision files
# are written from script.py.mako
output_encoding = utf-8

sqlalchemy.url = postgresql://order_user:order_pass@localhost:5432/order_db

[post_write_hooks]
# post_write_hooks defines scripts or Python functions that are run
# on newly generated revision scripts.  See the documentation for further
# detail and examples

# format using "black" - use the console_scripts runner, against the "black" entrypoint
hooks = black
black.type = console_scripts
black.entrypoint = black
black.options = -l 79 REVISION_SCRIPT_FILENAME

# Logging configuration
[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

### Migration Environment (order-service/alembic/env.py)
```python
import os
from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
from app.models import Base  # Import your SQLAlchemy models

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# add your model's MetaData object here
# for 'autogenerate' support
target_metadata = Base.metadata

def get_database_url():
    """Get database URL from environment or config"""
    return os.getenv('DATABASE_URL') or config.get_main_option("sqlalchemy.url")

def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = get_database_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    configuration = config.get_section(config.config_ini_section)
    configuration["sqlalchemy.url"] = get_database_url()
    
    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, 
            target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

### Sample Migration (order-service/alembic/versions/20241029_1430_001_create_orders_table.py)
```python
"""Create orders table

Revision ID: 001
Revises: 
Create Date: 2024-10-29 14:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # Create order status enum
    order_status_enum = postgresql.ENUM(
        'PENDING_PAYMENT',
        'CONFIRMED',
        'PROCESSING',
        'FULFILLMENT_STARTED',
        'PICKED',
        'PACKAGED',
        'SHIPPED',
        'DELIVERED',
        'CANCELLED',
        'REFUNDED',
        name='orderstatus'
    )
    order_status_enum.create(op.get_bind())

    # Create orders table
    op.create_table(
        'orders',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('order_number', sa.String(50), nullable=False),
        sa.Column('customer_id', sa.String(), nullable=False),
        sa.Column('status', order_status_enum, nullable=False),
        sa.Column('subtotal', sa.Numeric(10, 2), nullable=False),
        sa.Column('total_discounts', sa.Numeric(10, 2), nullable=False, default=0),
        sa.Column('shipping_cost', sa.Numeric(10, 2), nullable=False, default=0),
        sa.Column('tax_amount', sa.Numeric(10, 2), nullable=False, default=0),
        sa.Column('total_amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('currency', sa.String(3), nullable=False, default='USD'),
        sa.Column('shipping_address', sa.JSON(), nullable=False),
        sa.Column('billing_address', sa.JSON(), nullable=False),
        sa.Column('payment_method', sa.JSON(), nullable=True),
        sa.Column('transaction_id', sa.String(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('confirmed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('shipped_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('delivered_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('order_number')
    )

    # Create order items table
    op.create_table(
        'order_items',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('order_id', sa.String(), nullable=False),
        sa.Column('product_id', sa.String(), nullable=False),
        sa.Column('sku', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('unit_price', sa.Numeric(10, 2), nullable=False),
        sa.Column('total_price', sa.Numeric(10, 2), nullable=False),
        sa.Column('warehouse_id', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='CASCADE')
    )

    # Create order discounts table
    op.create_table(
        'order_discounts',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('order_id', sa.String(), nullable=False),
        sa.Column('type', sa.String(50), nullable=False),  # promotion, loyalty, coupon
        sa.Column('code', sa.String(), nullable=True),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('percentage', sa.Numeric(5, 2), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='CASCADE')
    )

    # Create indexes
    op.create_index('idx_orders_customer_id', 'orders', ['customer_id'])
    op.create_index('idx_orders_status', 'orders', ['status'])
    op.create_index('idx_orders_created_at', 'orders', ['created_at'])
    op.create_index('idx_order_items_order_id', 'order_items', ['order_id'])
    op.create_index('idx_order_items_product_id', 'order_items', ['product_id'])
    op.create_index('idx_order_discounts_order_id', 'order_discounts', ['order_id'])

def downgrade() -> None:
    # Drop indexes
    op.drop_index('idx_order_discounts_order_id')
    op.drop_index('idx_order_items_product_id')
    op.drop_index('idx_order_items_order_id')
    op.drop_index('idx_orders_created_at')
    op.drop_index('idx_orders_status')
    op.drop_index('idx_orders_customer_id')

    # Drop tables
    op.drop_table('order_discounts')
    op.drop_table('order_items')
    op.drop_table('orders')

    # Drop enum
    sa.Enum(name='orderstatus').drop(op.get_bind())
```

## Shared Migration Utilities

### Master Migration Script (shared/scripts/migrate-all.sh)
```bash
#!/bin/bash

set -e

COMMAND=${1:-up}
ENVIRONMENT=${2:-development}
SERVICES=${3:-"all"}

echo "🗄️ Running migrations for all services..."
echo "Command: $COMMAND"
echo "Environment: $ENVIRONMENT"
echo "Services: $SERVICES"

# Define all services
ALL_SERVICES=(
    "catalog-service"
    "order-service"
    "customer-service"
    "payment-service"
    "pricing-service"
    "inventory-service"
    "auth-service"
    "notification-service"
    "search-service"
    "review-service"
    "analytics-service"
    "loyalty-service"
    "shipping-service"
)

# Determine which services to migrate
if [ "$SERVICES" = "all" ]; then
    SERVICES_TO_MIGRATE=("${ALL_SERVICES[@]}")
else
    IFS=',' read -ra SERVICES_TO_MIGRATE <<< "$SERVICES"
fi

# Function to run migration for a service
migrate_service() {
    local service=$1
    local service_dir="../$service"
    
    if [ ! -d "$service_dir" ]; then
        echo "⚠️ Service directory not found: $service_dir"
        return 1
    fi
    
    echo "📦 Migrating $service..."
    
    cd "$service_dir"
    
    if [ -f "scripts/migrate.sh" ]; then
        ./scripts/migrate.sh "$COMMAND" "$ENVIRONMENT"
    elif [ -f "migrate.sh" ]; then
        ./migrate.sh "$COMMAND" "$ENVIRONMENT"
    else
        echo "⚠️ No migration script found for $service"
        return 1
    fi
    
    cd - > /dev/null
    echo "✅ $service migration completed"
}

# Run migrations for each service
failed_services=()
successful_services=()

for service in "${SERVICES_TO_MIGRATE[@]}"; do
    if migrate_service "$service"; then
        successful_services+=("$service")
    else
        failed_services+=("$service")
    fi
done

# Report results
echo ""
echo "📊 Migration Summary:"
echo "✅ Successful: ${#successful_services[@]} services"
for service in "${successful_services[@]}"; do
    echo "  - $service"
done

if [ ${#failed_services[@]} -gt 0 ]; then
    echo "❌ Failed: ${#failed_services[@]} services"
    for service in "${failed_services[@]}"; do
        echo "  - $service"
    done
    exit 1
else
    echo "🎉 All migrations completed successfully!"
fi
```

### Database Backup Script (shared/scripts/backup-all.sh)
```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-development}
BACKUP_DIR=${2:-"./backups/$(date +%Y%m%d_%H%M%S)"}

echo "💾 Creating database backups..."
echo "Environment: $ENVIRONMENT"
echo "Backup directory: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Load environment variables
if [ -f ".env.$ENVIRONMENT" ]; then
    export $(cat .env.$ENVIRONMENT | xargs)
fi

# Database configurations
declare -A DATABASES=(
    ["catalog"]="postgresql://catalog_user:catalog_pass@localhost:5432/catalog_db"
    ["order"]="postgresql://order_user:order_pass@localhost:5433/order_db"
    ["customer"]="postgresql://customer_user:customer_pass@localhost:5434/customer_db"
    ["payment"]="postgresql://payment_user:payment_pass@localhost:5435/payment_db"
    ["pricing"]="postgresql://pricing_user:pricing_pass@localhost:5436/pricing_db"
    ["inventory"]="postgresql://inventory_user:inventory_pass@localhost:5437/inventory_db"
    ["auth"]="postgresql://auth_user:auth_pass@localhost:5438/auth_db"
    ["notification"]="postgresql://notification_user:notification_pass@localhost:5439/notification_db"
)

# Function to backup a database
backup_database() {
    local db_name=$1
    local db_url=$2
    local backup_file="$BACKUP_DIR/${db_name}_backup.sql"
    
    echo "📦 Backing up $db_name database..."
    
    pg_dump "$db_url" > "$backup_file"
    
    if [ $? -eq 0 ]; then
        echo "✅ $db_name backup completed: $backup_file"
        
        # Compress backup
        gzip "$backup_file"
        echo "🗜️ Compressed: ${backup_file}.gz"
    else
        echo "❌ Failed to backup $db_name"
        return 1
    fi
}

# Backup all databases
failed_backups=()
successful_backups=()

for db_name in "${!DATABASES[@]}"; do
    if backup_database "$db_name" "${DATABASES[$db_name]}"; then
        successful_backups+=("$db_name")
    else
        failed_backups+=("$db_name")
    fi
done

# Create backup manifest
cat > "$BACKUP_DIR/manifest.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment": "$ENVIRONMENT",
  "successful_backups": [$(printf '"%s",' "${successful_backups[@]}" | sed 's/,$//')]
  "failed_backups": [$(printf '"%s",' "${failed_backups[@]}" | sed 's/,$//')]
}
EOF

# Report results
echo ""
echo "📊 Backup Summary:"
echo "✅ Successful: ${#successful_backups[@]} databases"
echo "❌ Failed: ${#failed_backups[@]} databases"
echo "📁 Backup location: $BACKUP_DIR"

if [ ${#failed_backups[@]} -gt 0 ]; then
    exit 1
else
    echo "🎉 All backups completed successfully!"
fi
```

## Migration Best Practices

### 1. Version Control
- All migrations are version controlled
- Sequential numbering or timestamp-based naming
- Never modify existing migrations in production

### 2. Rollback Strategy
- Always provide rollback scripts
- Test rollbacks in staging environment
- Document rollback procedures

### 3. Data Safety
- Always backup before migrations
- Use transactions where possible
- Test migrations on production-like data

### 4. Environment Management
- Separate configurations per environment
- Environment-specific migration scripts
- Automated deployment pipelines

### 5. Monitoring
- Log all migration activities
- Monitor migration performance
- Alert on migration failures

This comprehensive migration system ensures safe, reliable database schema management across all microservices in the e-commerce platform.