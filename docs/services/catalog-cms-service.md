# Catalog & CMS Service

## Description
Service that manages product catalog, categories, brands, product information, and content management system functionality (excluding pricing). 

**Architecture**: Implements **Hybrid EAV + Flat Table** approach for optimal performance and flexibility with 100+ product attributes.

## 🏗️ Hybrid Architecture Strategy

### Three-Tier Attribute Management

#### **Tier 1: Flat Table (Hot Attributes)**
- **Purpose**: Maximum performance for frequently queried attributes
- **Storage**: Direct columns in `products` table
- **Attributes**: Brand, category, color, size, material, weight, dimensions
- **Performance**: Sub-10ms queries with proper indexing
- **Use Cases**: Search filters, product listing, basic product info

#### **Tier 2: EAV System (Flexible Attributes)**  
- **Purpose**: Searchable/filterable attributes that vary by category
- **Storage**: Typed EAV tables (`product_attribute_varchar`, `product_attribute_int`, etc.)
- **Attributes**: Warranty, origin country, fabric type, certifications
- **Performance**: 50-200ms queries with optimized joins
- **Use Cases**: Advanced filtering, product specifications, category-specific attributes

#### **Tier 3: JSON Storage (Display Attributes)**
- **Purpose**: Display-only attributes that don't require search/filter
- **Storage**: JSON columns in `products` table
- **Attributes**: Technical specifications, marketing copy, media metadata
- **Performance**: Fast retrieval, no query overhead
- **Use Cases**: Product detail pages, technical documentation, rich content

### Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Product Data Flow                        │
├─────────────────────────────────────────────────────────────┤
│  Write Path:                                               │
│  1. Core attributes → products table (Tier 1)             │
│  2. Searchable attributes → EAV tables (Tier 2)           │
│  3. Display attributes → JSON columns (Tier 3)            │
│  4. Async sync → Elasticsearch + Cache invalidation       │
├─────────────────────────────────────────────────────────────┤
│  Read Path:                                                │
│  1. Product List/Search → Materialized view + Cache       │
│  2. Product Detail → Multi-layer cache → Database         │
│  3. Admin Operations → Direct database access             │
└─────────────────────────────────────────────────────────────┘
```

## Outbound Data

### Product Catalog Data
- Product information and attributes
- Category hierarchies and classifications
- Brand information and metadata
- Product specifications and descriptions
- Product media (images, videos)
- Warehouse mapping for products

### Content Management Data
- Landing page content and layouts
- Blog posts and articles
- Banner and promotional content
- SEO metadata and content
- Multi-language content
- Dynamic page templates

## Consumers (Services that use this data)

### Pricing Service
- **Purpose**: Get product information for price calculation
- **Data Received**: Product SKU, attributes, category information

### Promotion Service
- **Purpose**: Apply promotion rules based on product attributes
- **Data Received**: Product info, category, brand information

### Order Service  
- **Purpose**: Validate product information and specifications
- **Data Received**: Product details, attributes, specifications

### Warehouse & Inventory Service
- **Purpose**: Map products to warehouse locations
- **Data Received**: Product mapping, warehouse assignments

### Search Service
- **Purpose**: Index products and content for fast catalog queries
- **Data Received**: Product attributes, categories, brands, searchable fields, CMS content

### Frontend/API Gateway
- **Purpose**: Serve dynamic content and pages
- **Data Received**: Page content, blog posts, banners, SEO metadata

## 📡 API Specification

### Base URL
```
Production: https://api.domain.com/v1/catalog
Staging: https://staging-api.domain.com/v1/catalog
Local: http://localhost:8001/v1/catalog
```

### Authentication
- **Type**: JWT Bearer Token
- **Required Scopes**: `catalog:read`, `catalog:write`, `cms:read`, `cms:write`
- **Rate Limiting**: 1000 requests/minute per user

### Product Management APIs

#### GET /products
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
| brand | string | No | Filter by brand | apple |
| status | string | No | Filter by status (active/inactive) | active |
| search | string | No | Search in name/description | laptop |

**Response**:
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "id": 123,
        "sku": "LAPTOP-001",
        "name": "Gaming Laptop Pro",
        "description": "High-performance gaming laptop with RTX graphics",
        
        // Tier 1: Flat Table Attributes (Hot/Performance Critical)
        "brand": {
          "id": 1,
          "name": "TechBrand",
          "slug": "techbrand"
        },
        "category": {
          "id": 10,
          "name": "Electronics",
          "slug": "electronics"
        },
        "color": "Black",
        "size": "17-inch",
        "material": "Aluminum",
        "gender": "unisex",
        "weight": 2.8,
        "dimensions": {
          "length": 39.6,
          "width": 26.2,
          "height": 2.4
        },
        
        // Tier 2: EAV Attributes (Searchable/Filterable)
        "attributes": {
          "warranty_months": 24,
          "origin_country": "Taiwan",
          "fabric_type": null,
          "is_eco_friendly": false,
          "is_waterproof": true,
          "care_instructions": "Clean with dry cloth only"
        },
        
        // Tier 3: JSON Attributes (Display Only)
        "specifications": {
          "processor": "Intel Core i9-12900H",
          "graphics": "NVIDIA RTX 4080",
          "memory": "32GB DDR5",
          "storage": "1TB NVMe SSD",
          "display": "17.3\" 4K OLED",
          "model_number": "TL-GP-2024-001"
        },
        "marketing_attributes": {
          "selling_points": ["High Performance", "Gaming Ready", "Professional Grade"],
          "target_audience": "Gamers and Professionals",
          "key_features": ["RTX Graphics", "Fast SSD", "Premium Display"]
        },
        "media": {
          "images": [
            {
              "url": "https://cdn.domain.com/products/laptop-001-1.jpg",
              "alt": "Gaming Laptop Pro - Front View",
              "type": "primary",
              "order": 1
            }
          ],
          "videos": []
        },
        "seo": {
          "title": "Gaming Laptop Pro - High Performance",
          "description": "Best gaming laptop for professionals",
          "keywords": ["gaming", "laptop", "high-performance"]
        },
        
        "warehouse": "WH001",
        "status": "active",
        "createdAt": "2024-01-15T10:30:00Z",
        "updatedAt": "2024-01-15T10:30:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "totalPages": 8,
      "hasNext": true,
      "hasPrev": false
    }
  },
  "meta": {
    "requestId": "req_abc123",
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "1.0",
    "performance": {
      "query_time_ms": 45,
      "cache_hit": true,
      "data_sources": ["cache", "materialized_view"]
    }
  }
}
```

#### GET /products/{productId}
**Purpose**: Get detailed product information

**Request**:
```http
GET /v1/catalog/products/prod_123
Authorization: Bearer {jwt_token}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "product": {
      "id": "prod_123",
      "sku": "LAPTOP-001",
      "name": "Gaming Laptop Pro",
      "description": "High-performance gaming laptop with RTX graphics",
      "longDescription": "Detailed product description with specifications...",
      "category": {
        "id": "cat_001",
        "name": "Electronics",
        "slug": "electronics",
        "breadcrumb": ["Home", "Electronics", "Laptops"]
      },
      "brand": {
        "id": "brand_001",
        "name": "TechBrand",
        "slug": "techbrand",
        "logo": "https://cdn.domain.com/brands/techbrand-logo.png"
      },
      "specifications": {
        "processor": "Intel Core i9-12900H",
        "graphics": "NVIDIA RTX 4080",
        "memory": "32GB DDR5",
        "storage": "1TB NVMe SSD",
        "display": "17.3\" 4K OLED",
        "weight": "2.8kg"
      },
      "attributes": {
        "color": "Black",
        "warranty": "2 years",
        "origin": "Taiwan"
      },
      "media": {
        "images": [
          {
            "url": "https://cdn.domain.com/products/laptop-001-1.jpg",
            "alt": "Gaming Laptop Pro - Front View",
            "type": "primary",
            "order": 1
          },
          {
            "url": "https://cdn.domain.com/products/laptop-001-2.jpg",
            "alt": "Gaming Laptop Pro - Side View",
            "type": "gallery",
            "order": 2
          }
        ],
        "videos": [
          {
            "url": "https://cdn.domain.com/products/laptop-001-demo.mp4",
            "title": "Product Demo",
            "duration": 120
          }
        ]
      },
      "seo": {
        "title": "Gaming Laptop Pro - High Performance Gaming",
        "description": "Best gaming laptop for professionals and gamers",
        "keywords": ["gaming", "laptop", "high-performance", "rtx"],
        "slug": "gaming-laptop-pro"
      },
      "warehouse": "WH001",
      "status": "active",
      "createdAt": "2024-01-15T10:30:00Z",
      "updatedAt": "2024-01-15T10:30:00Z"
    }
  }
}
```

#### POST /products
**Purpose**: Create a new product

**Request**:
```http
POST /v1/catalog/products
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "sku": "LAPTOP-002",
  "name": "Business Laptop Pro",
  "description": "Professional laptop for business use",
  "longDescription": "Detailed description...",
  "categoryId": "cat_001",
  "brandId": "brand_001",
  "specifications": {
    "processor": "Intel Core i7",
    "memory": "16GB",
    "storage": "512GB SSD"
  },
  "attributes": {
    "color": "Silver",
    "warranty": "3 years"
  },
  "media": {
    "images": [
      {
        "url": "https://cdn.domain.com/products/laptop-002-1.jpg",
        "alt": "Business Laptop Pro",
        "type": "primary"
      }
    ]
  },
  "seo": {
    "title": "Business Laptop Pro",
    "description": "Professional laptop for business",
    "keywords": ["business", "laptop", "professional"]
  },
  "warehouse": "WH001",
  "status": "active"
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
      "name": "Business Laptop Pro",
      "status": "active",
      "createdAt": "2024-01-15T10:35:00Z"
    }
  }
}
```

#### PUT /products/{productId}
**Purpose**: Update existing product

**Request**:
```http
PUT /v1/catalog/products/prod_123
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "name": "Gaming Laptop Pro Max",
  "description": "Updated description",
  "specifications": {
    "processor": "Intel Core i9-13900H",
    "memory": "64GB"
  }
}
```

#### DELETE /products/{productId}
**Purpose**: Soft delete a product

**Request**:
```http
DELETE /v1/catalog/products/prod_123
Authorization: Bearer {jwt_token}
```

### Category Management APIs

#### GET /categories
**Purpose**: Get category hierarchy

**Response**:
```json
{
  "success": true,
  "data": {
    "categories": [
      {
        "id": "cat_001",
        "name": "Electronics",
        "slug": "electronics",
        "description": "Electronic devices and accessories",
        "parentId": null,
        "level": 1,
        "children": [
          {
            "id": "cat_002",
            "name": "Laptops",
            "slug": "laptops",
            "parentId": "cat_001",
            "level": 2,
            "productCount": 45
          }
        ],
        "productCount": 150,
        "status": "active"
      }
    ]
  }
}
```

#### POST /categories
**Purpose**: Create new category

### Brand Management APIs

#### GET /brands
**Purpose**: Get all brands

#### POST /brands
**Purpose**: Create new brand

### Content Management APIs

#### GET /pages
**Purpose**: Get CMS pages

**Response**:
```json
{
  "success": true,
  "data": {
    "pages": [
      {
        "id": "page_001",
        "title": "About Us",
        "slug": "about-us",
        "content": "HTML content...",
        "type": "page",
        "status": "published",
        "seo": {
          "title": "About Us - Company",
          "description": "Learn about our company"
        },
        "publishedAt": "2024-01-15T10:30:00Z"
      }
    ]
  }
}
```

#### GET /blogs
**Purpose**: Get blog posts

#### GET /banners
**Purpose**: Get promotional banners

## 🗄️ Database Schema - Hybrid EAV + Flat Table Architecture

### Primary Database: PostgreSQL

#### Core Products Table (Flat - Tier 1 Hot Attributes)
```sql
CREATE TABLE products (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    sku VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(500) NOT NULL,
    description TEXT,
    long_description TEXT,
    
    -- Business Critical (Tier 1 - Hot Attributes)
    brand_id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    manufacturer_id BIGINT,
    status ENUM('active', 'inactive', 'draft') DEFAULT 'draft',
    
    -- Search/Filter Critical (Tier 1 - Performance Optimized)
    color VARCHAR(50),
    size VARCHAR(50),
    material VARCHAR(100),
    gender ENUM('male', 'female', 'unisex'),
    age_group ENUM('adult', 'teen', 'child', 'baby'),
    
    -- Physical Attributes (Tier 1 - Frequently Queried)
    weight DECIMAL(8,3),
    length DECIMAL(8,2),
    width DECIMAL(8,2),
    height DECIMAL(8,2),
    
    -- Display Attributes (JSON - Tier 3)
    specifications JSON,           -- Technical specs, model numbers, etc.
    marketing_attributes JSON,     -- Selling points, target audience, etc.
    media JSON,                   -- Images, videos, documents
    seo JSON,                     -- SEO metadata, keywords, etc.
    
    -- Warehouse & Logistics
    warehouse_id VARCHAR(50),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by BIGINT,
    updated_by BIGINT,
    
    -- Indexes for Flat Attributes (High Performance)
    INDEX idx_sku (sku),
    INDEX idx_brand_category (brand_id, category_id),
    INDEX idx_status_brand (status, brand_id),
    INDEX idx_search_attrs (color, size, material),
    INDEX idx_physical_dims (weight, length, width, height),
    INDEX idx_warehouse (warehouse_id),
    INDEX idx_created_at (created_at),
    
    -- JSON Indexes for Specific Queries
    INDEX idx_specs_warranty ((JSON_EXTRACT(specifications, '$.warranty_months'))),
    INDEX idx_marketing_target ((JSON_EXTRACT(marketing_attributes, '$.target_audience'))),
    
    -- Full-text search
    FULLTEXT INDEX idx_products_search (name, description),
    
    -- Foreign Keys
    FOREIGN KEY (brand_id) REFERENCES brands(id),
    FOREIGN KEY (category_id) REFERENCES categories(id),
    FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id)
);
```

#### EAV System for Flexible Attributes (Tier 2)

##### Attribute Definitions
```sql
CREATE TABLE product_attributes (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    data_type ENUM('string', 'integer', 'decimal', 'boolean', 'date', 'text'),
    input_type ENUM('text', 'select', 'multiselect', 'textarea', 'date', 'checkbox'),
    is_searchable BOOLEAN DEFAULT FALSE,
    is_filterable BOOLEAN DEFAULT FALSE,
    is_required BOOLEAN DEFAULT FALSE,
    sort_order INT DEFAULT 0,
    
    -- Validation rules
    validation_rules JSON, -- {"min": 0, "max": 100, "options": ["S", "M", "L"]}
    
    -- Category-specific attributes
    category_id BIGINT NULL, -- NULL = global attribute
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_code (code),
    INDEX idx_searchable (is_searchable),
    INDEX idx_filterable (is_filterable),
    INDEX idx_category (category_id),
    
    FOREIGN KEY (category_id) REFERENCES categories(id)
);
```

##### Typed EAV Value Tables (Performance Optimized)
```sql
-- String/Varchar attributes (most common)
CREATE TABLE product_attribute_varchar (
    product_id BIGINT,
    attribute_id BIGINT,
    value VARCHAR(255),
    
    PRIMARY KEY (product_id, attribute_id),
    INDEX idx_attribute_value (attribute_id, value),
    INDEX idx_product (product_id),
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (attribute_id) REFERENCES product_attributes(id)
);

-- Text attributes (long descriptions, instructions)
CREATE TABLE product_attribute_text (
    product_id BIGINT,
    attribute_id BIGINT,
    value TEXT,
    
    PRIMARY KEY (product_id, attribute_id),
    INDEX idx_attribute (attribute_id),
    FULLTEXT INDEX idx_value (value),
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (attribute_id) REFERENCES product_attributes(id)
);

-- Integer attributes (warranty months, quantity, etc.)
CREATE TABLE product_attribute_int (
    product_id BIGINT,
    attribute_id BIGINT,
    value BIGINT,
    
    PRIMARY KEY (product_id, attribute_id),
    INDEX idx_attribute_value (attribute_id, value),
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (attribute_id) REFERENCES product_attributes(id)
);

-- Decimal attributes (dimensions, weights, ratings)
CREATE TABLE product_attribute_decimal (
    product_id BIGINT,
    attribute_id BIGINT,
    value DECIMAL(15,4),
    
    PRIMARY KEY (product_id, attribute_id),
    INDEX idx_attribute_value (attribute_id, value),
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (attribute_id) REFERENCES product_attributes(id)
);

-- Boolean attributes (features, certifications)
CREATE TABLE product_attribute_boolean (
    product_id BIGINT,
    attribute_id BIGINT,
    value BOOLEAN,
    
    PRIMARY KEY (product_id, attribute_id),
    INDEX idx_attribute_value (attribute_id, value),
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (attribute_id) REFERENCES product_attributes(id)
);

-- Date attributes (manufacture date, expiry, etc.)
CREATE TABLE product_attribute_date (
    product_id BIGINT,
    attribute_id BIGINT,
    value DATE,
    
    PRIMARY KEY (product_id, attribute_id),
    INDEX idx_attribute_value (attribute_id, value),
    
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (attribute_id) REFERENCES product_attributes(id)
);
```

#### Master Data Tables

##### Brands Table (Enhanced)
```sql
CREATE TABLE brands (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    display_name VARCHAR(200),
    description TEXT,
    logo_url VARCHAR(500),
    website_url VARCHAR(500),
    
    -- SEO & Marketing
    slug VARCHAR(100) UNIQUE,
    meta_title VARCHAR(200),
    meta_description TEXT,
    
    -- Business Info
    country_code CHAR(2),
    founded_year YEAR,
    
    -- Status & Hierarchy
    status ENUM('active', 'inactive', 'pending') DEFAULT 'active',
    parent_brand_id BIGINT NULL,
    sort_order INT DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_code (code),
    INDEX idx_slug (slug),
    INDEX idx_status (status),
    INDEX idx_parent (parent_brand_id),
    
    FOREIGN KEY (parent_brand_id) REFERENCES brands(id) ON DELETE SET NULL
);
```

##### Manufacturers Table
```sql
CREATE TABLE manufacturers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    display_name VARCHAR(200),
    description TEXT,
    
    -- Contact & Address
    email VARCHAR(200),
    phone VARCHAR(50),
    website_url VARCHAR(500),
    country_code CHAR(2) NOT NULL,
    
    -- Business Info
    certifications JSON,
    production_capacity JSON,
    specializations JSON,
    
    -- Status
    status ENUM('active', 'inactive', 'pending', 'suspended') DEFAULT 'active',
    verification_status ENUM('verified', 'pending', 'rejected') DEFAULT 'pending',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_code (code),
    INDEX idx_status (status),
    INDEX idx_country (country_code),
    INDEX idx_verification (verification_status)
);
```

##### Categories Table (Enhanced Hierarchy)
```sql
CREATE TABLE categories (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    parent_id BIGINT NULL,
    level INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    
    -- Media & SEO
    image_url VARCHAR(500),
    icon_url VARCHAR(500),
    seo JSON,
    
    -- Category-specific attribute templates
    attribute_template JSON, -- Default attributes for products in this category
    
    -- Status
    status ENUM('active', 'inactive', 'draft') DEFAULT 'active',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_parent (parent_id),
    INDEX idx_slug (slug),
    INDEX idx_status (status),
    INDEX idx_level (level),
    INDEX idx_sort_order (sort_order),
    
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
);
```

#### CMS Pages Table
```sql
CREATE TABLE cms_pages (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    content TEXT,
    excerpt TEXT,
    type ENUM('page', 'blog', 'banner', 'landing') DEFAULT 'page',
    template VARCHAR(100),
    
    -- SEO & Meta
    seo JSON,
    meta_data JSON,
    
    -- Status & Publishing
    status ENUM('draft', 'published', 'archived') DEFAULT 'draft',
    published_at TIMESTAMP NULL,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by BIGINT,
    updated_by BIGINT,
    
    INDEX idx_slug (slug),
    INDEX idx_type (type),
    INDEX idx_status (status),
    INDEX idx_published_at (published_at),
    FULLTEXT INDEX idx_content_search (title, content, excerpt)
);
```

### Performance Optimization Views

#### Materialized View for Product Search (Hot Path)
```sql
CREATE MATERIALIZED VIEW product_search_view AS
SELECT 
    p.id, p.sku, p.name, p.description,
    p.brand_id, p.category_id, p.status,
    p.color, p.size, p.material, p.gender, p.age_group,
    p.weight, p.length, p.width, p.height,
    
    -- Brand info (denormalized)
    b.name as brand_name,
    b.slug as brand_slug,
    
    -- Category info (denormalized)  
    c.name as category_name,
    c.slug as category_slug,
    
    -- Common EAV attributes (pre-computed)
    MAX(CASE WHEN pa.code = 'warranty_months' THEN pai.value END) as warranty_months,
    MAX(CASE WHEN pa.code = 'origin_country' THEN pav.value END) as origin_country,
    MAX(CASE WHEN pa.code = 'is_eco_friendly' THEN pab.value END) as is_eco_friendly,
    MAX(CASE WHEN pa.code = 'fabric_type' THEN pav2.value END) as fabric_type,
    
    -- JSON extracted fields (commonly queried)
    JSON_EXTRACT(p.specifications, '$.model_number') as model_number,
    JSON_EXTRACT(p.marketing_attributes, '$.target_audience') as target_audience,
    
    p.created_at, p.updated_at
    
FROM products p
LEFT JOIN brands b ON p.brand_id = b.id
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN product_attribute_int pai ON p.id = pai.product_id
LEFT JOIN product_attribute_varchar pav ON p.id = pav.product_id  
LEFT JOIN product_attribute_varchar pav2 ON p.id = pav2.product_id
LEFT JOIN product_attribute_boolean pab ON p.id = pab.product_id
LEFT JOIN product_attributes pa ON (
    pai.attribute_id = pa.id OR 
    pav.attribute_id = pa.id OR 
    pav2.attribute_id = pa.id OR
    pab.attribute_id = pa.id
)
WHERE p.status = 'active'
GROUP BY p.id, b.id, c.id;

-- Refresh strategy (can be automated)
-- REFRESH MATERIALIZED VIEW product_search_view;
```

#### Sample Attribute Data
```sql
-- Insert common product attributes
INSERT INTO product_attributes (code, name, data_type, input_type, is_searchable, is_filterable, validation_rules) VALUES
-- Searchable/Filterable attributes (EAV Tier 2)
('warranty_months', 'Warranty (Months)', 'integer', 'text', TRUE, TRUE, '{"min": 0, "max": 120}'),
('origin_country', 'Country of Origin', 'string', 'select', TRUE, TRUE, '{"options": ["Vietnam", "China", "USA", "Germany", "Japan"]}'),
('fabric_type', 'Fabric Type', 'string', 'select', TRUE, TRUE, '{"options": ["Cotton", "Polyester", "Silk", "Wool", "Blend"]}'),
('care_instructions', 'Care Instructions', 'text', 'textarea', TRUE, FALSE, NULL),
('is_eco_friendly', 'Eco Friendly', 'boolean', 'checkbox', TRUE, TRUE, NULL),
('is_waterproof', 'Waterproof', 'boolean', 'checkbox', TRUE, TRUE, NULL),
('thread_count', 'Thread Count', 'integer', 'text', FALSE, TRUE, '{"min": 50, "max": 2000}'),
('gsm_weight', 'GSM Weight', 'decimal', 'text', FALSE, TRUE, '{"min": 50.0, "max": 1000.0}'),

-- Display-only attributes (could be JSON instead)
('model_number', 'Model Number', 'string', 'text', FALSE, FALSE, NULL),
('barcode', 'Barcode', 'string', 'text', FALSE, FALSE, NULL),
('assembly_required', 'Assembly Required', 'boolean', 'checkbox', FALSE, FALSE, NULL);
```

### Multi-Layer Cache Strategy (Redis)

#### L1 Cache - Hot Products (In-Memory)
```
# Most frequently accessed products (top 1000)
Key: catalog:hot:product:{product_id}
TTL: 30 minutes
Value: Complete product data (flat + EAV + JSON)
Storage: Application memory (BigCache/FreeCache)
```

#### L2 Cache - Warm Products (Redis)
```
# Product core data (flat attributes only)
Key: catalog:product:core:{product_id}
TTL: 2 hours
Value: {id, sku, name, brand_id, category_id, color, size, material, weight, etc.}

# Product EAV attributes
Key: catalog:product:eav:{product_id}
TTL: 1 hour  
Value: {warranty_months: 24, origin_country: "Vietnam", fabric_type: "Cotton", etc.}

# Product JSON attributes
Key: catalog:product:json:{product_id}
TTL: 1 hour
Value: {specifications: {...}, marketing_attributes: {...}, media: {...}}

# Complete product (assembled)
Key: catalog:product:full:{product_id}
TTL: 1 hour
Value: Complete product object (flat + EAV + JSON combined)
```

#### L3 Cache - Search & Lists
```
# Product search results
Key: catalog:search:{hash_of_search_params}
TTL: 15 minutes
Value: Array of product IDs + pagination info

# Category product lists
Key: catalog:category:{category_id}:products:{page}:{limit}
TTL: 30 minutes
Value: Product list with basic info

# Brand product lists  
Key: catalog:brand:{brand_id}:products:{page}:{limit}
TTL: 30 minutes
Value: Product list with basic info

# Materialized view cache
Key: catalog:search_view:refresh_time
TTL: 5 minutes
Value: Last refresh timestamp for materialized view
```

#### Master Data Cache
```
# Category hierarchy (rarely changes)
Key: catalog:categories:tree
TTL: 4 hours
Value: Complete category tree with parent-child relationships

# Brand list (stable data)
Key: catalog:brands:active
TTL: 2 hours  
Value: All active brands with basic info

# Manufacturer list
Key: catalog:manufacturers:active
TTL: 2 hours
Value: All active manufacturers

# Attribute definitions (very stable)
Key: catalog:attributes:definitions
TTL: 24 hours
Value: All product attribute definitions with validation rules
```

#### Cache Invalidation Strategy
```
# Product update events
Event: product.updated -> Invalidate:
- catalog:product:*:{product_id}
- catalog:hot:product:{product_id}  
- catalog:search:* (pattern-based cleanup)
- catalog:category:{category_id}:products:*

# Attribute update events  
Event: attribute.updated -> Invalidate:
- catalog:product:eav:* (all EAV caches)
- catalog:attributes:definitions

# Brand/Category updates
Event: brand.updated -> Invalidate:
- catalog:brands:active
- catalog:brand:{brand_id}:products:*
```

## Main APIs

### Product Catalog APIs
- `GET /catalog/products/{id}` - Get product information
- `GET /catalog/products/search` - Search products by attributes
- `GET /catalog/categories` - Get category hierarchy
- `GET /catalog/brands` - Get brand information
- `GET /catalog/products/{id}/attributes` - Get product attributes
- `GET /catalog/products/category/{categoryId}` - Get products by category

### Content Management APIs
- `GET /cms/pages/{slug}` - Get page content by slug
- `GET /cms/pages` - List all pages
- `POST /cms/pages` - Create new page
- `PUT /cms/pages/{id}` - Update page content
- `GET /cms/blogs/{slug}` - Get blog post
- `GET /cms/banners/active` - Get active banners
- `GET /cms/seo/{path}` - Get SEO metadata for path

## Content Management Features

### Page Management
```json
{
  "pageId": "PAGE-001",
  "slug": "about-us",
  "title": "About Our Company",
  "content": {
    "blocks": [
      {
        "type": "hero",
        "data": {
          "title": "Welcome to Our Store",
          "subtitle": "Quality products since 1990",
          "backgroundImage": "https://cdn.example.com/hero-bg.jpg"
        }
      },
      {
        "type": "text",
        "data": {
          "content": "<p>Our company story...</p>"
        }
      }
    ]
  },
  "seo": {
    "metaTitle": "About Us - Company Name",
    "metaDescription": "Learn about our company history and values",
    "keywords": ["about", "company", "history"]
  },
  "status": "published",
  "publishedAt": "2024-08-10T14:30:00Z"
}
```

### Blog Management
```json
{
  "blogId": "BLOG-001",
  "slug": "summer-fashion-trends",
  "title": "Top Summer Fashion Trends 2024",
  "excerpt": "Discover the hottest fashion trends for summer",
  "content": "<p>Summer fashion content...</p>",
  "author": "Fashion Editor",
  "tags": ["fashion", "summer", "trends"],
  "featuredImage": "https://cdn.example.com/blog/summer-trends.jpg",
  "publishedAt": "2024-08-10T14:30:00Z",
  "status": "published"
}
```

### Banner Management
```json
{
  "bannerId": "BANNER-001",
  "name": "Summer Sale Banner",
  "type": "promotional",
  "content": {
    "title": "Summer Sale - Up to 50% Off",
    "subtitle": "Limited time offer",
    "ctaText": "Shop Now",
    "ctaLink": "/sale",
    "backgroundImage": "https://cdn.example.com/banners/summer-sale.jpg"
  },
  "placement": ["homepage", "category-pages"],
  "schedule": {
    "startDate": "2024-08-01T00:00:00Z",
    "endDate": "2024-08-31T23:59:59Z"
  },
  "targeting": {
    "customerSegments": ["all"],
    "geoLocation": ["US", "CA"]
  },
  "status": "active"
}
```

### Multi-language Support
```json
{
  "contentId": "CONTENT-001",
  "translations": {
    "en": {
      "title": "Welcome to Our Store",
      "content": "English content..."
    },
    "es": {
      "title": "Bienvenido a Nuestra Tienda",
      "content": "Spanish content..."
    },
    "fr": {
      "title": "Bienvenue dans Notre Magasin",
      "content": "French content..."
    }
  }
}
```

## 📊 Performance Optimization & SLA

### Performance Targets

| Operation | Target | Cache Strategy | Data Source |
|-----------|--------|----------------|-------------|
| Product Detail (Hot) | < 10ms | L1 In-Memory | Application Cache |
| Product Detail (Warm) | < 50ms | L2 Redis | Multi-layer Cache |
| Product Detail (Cold) | < 200ms | Database | Optimized Queries |
| Product List/Search | < 100ms | Materialized View | Pre-computed Data |
| Advanced Filtering | < 500ms | EAV + Cache | Hybrid Queries |
| Bulk Operations | < 5s/1000 items | Batch Processing | Direct Database |

### Query Optimization Strategies

#### Hot Path Queries (Tier 1 - Flat Table)
```sql
-- Optimized for sub-10ms performance
SELECT id, sku, name, brand_id, category_id, color, size, material, weight
FROM products 
WHERE status = 'active' 
  AND brand_id = ? 
  AND category_id = ?
  AND color IN (?, ?, ?)
ORDER BY created_at DESC
LIMIT 20;

-- Uses: idx_status_brand, idx_search_attrs
```

#### Warm Path Queries (Tier 2 - EAV + Flat)
```sql
-- Combined flat + EAV query (50-200ms)
SELECT p.*, 
       pav1.value as warranty_months,
       pav2.value as origin_country
FROM products p
LEFT JOIN product_attribute_int pav1 ON p.id = pav1.product_id AND pav1.attribute_id = 1
LEFT JOIN product_attribute_varchar pav2 ON p.id = pav2.product_id AND pav2.attribute_id = 2
WHERE p.status = 'active'
  AND p.brand_id = ?
  AND pav1.value >= 12; -- warranty >= 12 months

-- Uses: Materialized view for better performance
```

#### Cold Path Queries (Tier 3 - Full Product)
```sql
-- Complete product assembly (used for cache warming)
SELECT p.*,
       JSON_OBJECT(
         'warranty_months', pai.warranty,
         'origin_country', pav.origin,
         'fabric_type', pav.fabric
       ) as eav_attributes
FROM products p
LEFT JOIN (
  SELECT product_id,
         MAX(CASE WHEN attribute_id = 1 THEN value END) as warranty,
  FROM product_attribute_int GROUP BY product_id
) pai ON p.id = pai.product_id
LEFT JOIN (
  SELECT product_id,
         MAX(CASE WHEN attribute_id = 2 THEN value END) as origin,
         MAX(CASE WHEN attribute_id = 3 THEN value END) as fabric
  FROM product_attribute_varchar GROUP BY product_id  
) pav ON p.id = pav.product_id
WHERE p.id = ?;
```

### Elasticsearch Integration

#### Index Structure
```json
{
  "mappings": {
    "properties": {
      // Flat attributes (fast filtering)
      "id": {"type": "long"},
      "sku": {"type": "keyword"},
      "name": {"type": "text", "analyzer": "standard"},
      "brand_id": {"type": "long"},
      "category_id": {"type": "long"},
      "color": {"type": "keyword"},
      "size": {"type": "keyword"},
      "material": {"type": "keyword"},
      "weight": {"type": "double"},
      
      // EAV attributes (nested for complex queries)
      "eav_attributes": {
        "type": "nested",
        "properties": {
          "code": {"type": "keyword"},
          "value": {"type": "text"},
          "numeric_value": {"type": "double"},
          "boolean_value": {"type": "boolean"}
        }
      },
      
      // JSON attributes (flattened for simple access)
      "specifications": {"type": "flattened"},
      "marketing_attributes": {"type": "flattened"}
    }
  }
}
```

### Cache Warming Strategy

#### Startup Cache Warming
```
1. Load top 1000 hot products into L1 cache
2. Pre-compute materialized view
3. Warm Redis with category/brand lists
4. Index recent products in Elasticsearch
```

#### Runtime Cache Management
```
1. Cache-aside pattern for product details
2. Write-through for product updates
3. TTL-based expiration with refresh-ahead
4. Circuit breaker for database protection
```

## Integration with Other Services

### Search Service Integration
- **Real-time Indexing**: Product changes trigger Elasticsearch updates
- **Faceted Search**: EAV attributes provide dynamic facets
- **Performance**: Search results return product IDs, details fetched from cache

### Pricing Service Integration
- **Product Validation**: Verify SKU exists and is active
- **Attribute Access**: Provide product attributes for pricing rules
- **Performance**: Use flat table attributes for fast validation

### Order Service Integration
- **Product Verification**: Validate product availability and specifications
- **Attribute Snapshot**: Capture product state at order time
- **Performance**: Cache product essentials for order processing

### Analytics Service Integration
- **Product Performance**: Track views, searches, conversions by attribute
- **Attribute Analytics**: Monitor which EAV attributes drive engagement
- **Cache Metrics**: Track cache hit rates and query performance