# Catalog & CMS Service

## Description
Service that manages product catalog, categories, brands, product information, and content management system functionality (excluding pricing).

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
        "id": "prod_123",
        "sku": "LAPTOP-001",
        "name": "Gaming Laptop Pro",
        "description": "High-performance gaming laptop with RTX graphics",
        "category": {
          "id": "cat_001",
          "name": "Electronics",
          "slug": "electronics"
        },
        "brand": {
          "id": "brand_001",
          "name": "TechBrand",
          "slug": "techbrand"
        },
        "attributes": {
          "color": "Black",
          "storage": "1TB SSD",
          "ram": "32GB",
          "processor": "Intel i9"
        },
        "media": {
          "images": [
            {
              "url": "https://cdn.domain.com/products/laptop-001-1.jpg",
              "alt": "Gaming Laptop Pro - Front View",
              "type": "primary"
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
    "version": "1.0"
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

## 🗄️ Database Schema

### Primary Database: PostgreSQL

#### products
```sql
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    long_description TEXT,
    category_id UUID REFERENCES categories(id),
    brand_id UUID REFERENCES brands(id),
    specifications JSONB DEFAULT '{}',
    attributes JSONB DEFAULT '{}',
    media JSONB DEFAULT '{}',
    seo JSONB DEFAULT '{}',
    warehouse_id VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Indexes
    INDEX idx_products_sku (sku),
    INDEX idx_products_category (category_id),
    INDEX idx_products_brand (brand_id),
    INDEX idx_products_warehouse (warehouse_id),
    INDEX idx_products_status (status),
    INDEX idx_products_created_at (created_at),
    
    -- Full-text search
    INDEX idx_products_search USING gin(to_tsvector('english', name || ' ' || description))
);
```

#### categories
```sql
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES categories(id),
    level INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    image_url VARCHAR(500),
    seo JSONB DEFAULT '{}',
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_categories_parent (parent_id),
    INDEX idx_categories_slug (slug),
    INDEX idx_categories_status (status),
    INDEX idx_categories_level (level)
);
```

#### brands
```sql
CREATE TABLE brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    logo_url VARCHAR(500),
    website_url VARCHAR(500),
    seo JSONB DEFAULT '{}',
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    INDEX idx_brands_slug (slug),
    INDEX idx_brands_status (status)
);
```

#### cms_pages
```sql
CREATE TABLE cms_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    content TEXT,
    excerpt TEXT,
    type VARCHAR(50) DEFAULT 'page', -- page, blog, banner
    template VARCHAR(100),
    seo JSONB DEFAULT '{}',
    meta_data JSONB DEFAULT '{}',
    status VARCHAR(20) DEFAULT 'draft', -- draft, published, archived
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    
    -- Indexes
    INDEX idx_cms_pages_slug (slug),
    INDEX idx_cms_pages_type (type),
    INDEX idx_cms_pages_status (status),
    INDEX idx_cms_pages_published_at (published_at)
);
```

### Cache Schema (Redis)
```
# Product cache
Key: catalog:product:{product_id}
TTL: 3600 seconds (1 hour)
Value: JSON serialized product data

# Product list cache
Key: catalog:products:list:{hash_of_query_params}
TTL: 300 seconds (5 minutes)
Value: JSON serialized product list with pagination

# Category cache
Key: catalog:categories:tree
TTL: 7200 seconds (2 hours)
Value: JSON serialized category hierarchy

# Brand cache
Key: catalog:brands:list
TTL: 3600 seconds (1 hour)
Value: JSON serialized brand list
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

## Integration with Other Services

### Search Service Integration
- Index CMS content for site-wide search
- SEO content optimization
- Content recommendations

### User Service Integration
- Content access permissions
- Author management
- Content approval workflows

### Analytics Service Integration
- Content performance tracking
- Page view analytics
- Content engagement metrics