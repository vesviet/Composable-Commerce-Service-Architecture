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