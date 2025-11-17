# Product Domain - Domain Model

**Bounded Context:** Product Context  
**Service:** Catalog Service  
**Last Updated:** 2025-11-17

## Domain Overview

The Product domain manages the product catalog, including products, categories, brands, manufacturers, and content management (CMS).

## Core Entities

### Product
**Description:** Represents a sellable product in the catalog  
**Attributes:**
- `id` (UUID): Unique product identifier
- `sku` (string): Stock Keeping Unit (unique)
- `name` (string): Product name
- `description` (text): Product description
- `category_id` (UUID): Category reference
- `brand_id` (UUID, nullable): Brand reference
- `manufacturer_id` (UUID, nullable): Manufacturer reference
- `status` (enum): ACTIVE, INACTIVE, DRAFT
- `stock_quantity` (integer): Current stock (synced from Warehouse)
- `created_at` (timestamp)
- `updated_at` (timestamp)

**Business Rules:**
- SKU must be unique across all products
- Product must belong to a category
- Stock quantity synced from Warehouse Service (event-driven)
- Product cannot be deleted if referenced by orders (soft delete)

### Category
**Description:** Product category hierarchy  
**Attributes:**
- `id` (UUID): Unique category identifier
- `name` (string): Category name
- `slug` (string): URL-friendly identifier
- `parent_id` (UUID, nullable): Parent category (for hierarchy)
- `level` (integer): Depth in hierarchy (0 = root)
- `description` (text, nullable)
- `is_active` (boolean)

**Business Rules:**
- Category hierarchy max depth: 5 levels
- Slug must be unique
- Cannot delete category with products

### Brand
**Description:** Product brand  
**Attributes:**
- `id` (UUID): Unique brand identifier
- `name` (string): Brand name
- `slug` (string): URL-friendly identifier
- `logo_url` (string, nullable)
- `description` (text, nullable)

**Business Rules:**
- Brand name must be unique
- Slug must be unique

### Manufacturer
**Description:** Product manufacturer  
**Attributes:**
- `id` (UUID): Unique manufacturer identifier
- `name` (string): Manufacturer name
- `country` (string): Country of origin
- `website` (string, nullable)

## Value Objects

### ProductStatus
**Values:** ACTIVE, INACTIVE, DRAFT  
**Rules:**
- ACTIVE: Product visible and purchasable
- INACTIVE: Product hidden but not deleted
- DRAFT: Product not yet published

### StockLevel
**Value Object:** Represents stock information  
**Attributes:**
- `quantity` (integer): Available quantity
- `warehouse_id` (UUID): Warehouse location
- `reserved` (integer): Reserved quantity
- `available` (integer): Available = quantity - reserved

## Domain Services

### ProductCatalogService
**Responsibility:** Manage product catalog operations  
**Operations:**
- `SearchProducts(query, filters)`: Search products
- `ListProductsByCategory(categoryId)`: List products in category
- `GetProductWithStock(productId)`: Get product with stock levels

### StockSyncService
**Responsibility:** Sync stock from Warehouse Service  
**Operations:**
- `SyncStock(event)`: Update stock from warehouse event
- `GetStockForProduct(productId, warehouseId)`: Get stock level

## Aggregates

### Product Aggregate
**Root:** Product  
**Children:** ProductAttribute, ProductImage  
**Invariants:**
- Product must have valid SKU
- Product must belong to valid category
- Stock quantity >= 0

### Category Aggregate
**Root:** Category  
**Children:** (none, but references products)  
**Invariants:**
- Category hierarchy depth <= 5
- Slug must be unique

## Domain Events

### ProductCreated
**Published:** When new product is created  
**Payload:** Product ID, SKU, Name, Category ID

### ProductUpdated
**Published:** When product is updated  
**Payload:** Product ID, Changed Fields

### ProductDeleted
**Published:** When product is soft-deleted  
**Payload:** Product ID, SKU

### StockUpdated
**Consumed:** From Warehouse Service  
**Payload:** SKU, Warehouse ID, Quantity, Change Type

## Repository Interfaces

### ProductRepository
```go
type ProductRepository interface {
    Create(ctx context.Context, product *Product) (*Product, error)
    GetByID(ctx context.Context, id string) (*Product, error)
    GetBySKU(ctx context.Context, sku string) (*Product, error)
    Update(ctx context.Context, product *Product) error
    Delete(ctx context.Context, id string) error
    List(ctx context.Context, filters *ProductFilters) ([]*Product, *Pagination, error)
    Search(ctx context.Context, query string) ([]*Product, error)
}
```

### CategoryRepository
```go
type CategoryRepository interface {
    Create(ctx context.Context, category *Category) (*Category, error)
    GetByID(ctx context.Context, id string) (*Category, error)
    GetTree(ctx context.Context) (*CategoryTree, error)
    Update(ctx context.Context, category *Category) error
    Delete(ctx context.Context, id string) error
}
```

## Use Cases

### CreateProduct
1. Validate SKU uniqueness
2. Validate category exists
3. Create product with DRAFT status
4. Publish ProductCreated event

### UpdateStock
1. Receive StockUpdated event from Warehouse
2. Update product stock quantity
3. Update cache (Redis)
4. Publish ProductUpdated event (if stock changed significantly)

### SearchProducts
1. Parse search query
2. Search in product name, description, SKU
3. Apply filters (category, brand, price range)
4. Return paginated results

## References

- Catalog Service README: `/catalog/README.md`
- Event Schema: `/docs/json-schema/stock.updated.schema.json`
- API Spec: `/docs/openapi/catalog.openapi.yaml`

