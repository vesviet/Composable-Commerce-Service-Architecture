# Route Definition Guide - Catalog & Shop Services

## Overview

Both `catalog-main` and `shop-main` services use **Kratos framework** with **Protocol Buffers (protobuf)** to define HTTP routes. Routes are automatically generated from proto files through Google API annotations.

## Route Definition Architecture

### 1. API Directory Structure

#### Catalog-main:
```
catalog-main/api/
├── admin/          # Admin APIs
├── external/       # External APIs  
├── v1/            # Version 1 APIs
└── v2/            # Version 2 APIs
```

#### Shop-main:
```
shop-main/api/
├── v1/            # Version 1 APIs
└── v2/            # Version 2 APIs
```

### 2. Proto File Structure

Each service is defined in a proto file with the following structure:

```protobuf
syntax = "proto3";
import "google/api/annotations.proto";

package api.v1.service_name;

option go_package = "gitlab.com/vigo-tech/project/api/v1/service_name";

service ServiceName {
    rpc MethodName(RequestMessage) returns (ResponseMessage) {
        option (google.api.http) = {
            get|post|put|delete: "/v1/path"
            body: "*"  // Only for POST/PUT
        };
    };
}
```

## How to Define Routes

### 1. HTTP Method Mapping

```protobuf
// GET request
rpc ListProducts(ListProductRequest) returns (ListProductReply) {
    option (google.api.http) = {
        get: "/v1/products"
    };
}

// POST request
rpc CreateProduct(CreateProductRequest) returns (Product) {
    option (google.api.http) = {
        post: "/v1/products"
        body: "*"
    };
}

// PUT request with path parameter
rpc UpdateProduct(UpdateProductRequest) returns (Product) {
    option (google.api.http) = {
        put: "/v1/products/{id}"
        body: "*"
    };
}

// DELETE request
rpc DeleteProduct(DeleteProductRequest) returns (DeleteProductReply) {
    option (google.api.http) = {
        delete: "/v1/products/{id}"
    };
}
```

### 2. Path Parameters

```protobuf
// Single parameter
get: "/v1/products/{id}"

// Multiple parameters  
get: "/v1/products/{id}/histories/{history_id}"

// Nested resources
get: "/v1/products/{id}/sync-vtp"
put: "/v1/products/{id}/statuses"
```

### 3. Query Parameters

Query parameters are defined in the request message:

```protobuf
message ListProductRequest {
    int64 page = 1;
    int64 perPage = 2;
    string status = 3;
    repeated string categoryIDs = 4;
}
```

## Route Registration Process

### 1. Code Generation

Routes are generated from proto files using the command:

```bash
# Generate API code
make api

# Or in detail:
protoc --proto_path=./api \
       --proto_path=./third_party \
       --go_out=paths=source_relative:./api \
       --go-http_out=paths=source_relative:./api \
       --go-grpc_out=paths=source_relative:./api \
       --openapi_out=fq_schema_naming=true,default_response=false:. \
       $(API_PROTO_FILES)
```

### 2. Generated Files

Each proto file will generate:
- `service_name.pb.go` - Message definitions
- `service_name_grpc.pb.go` - gRPC server/client code  
- `service_name_http.pb.go` - HTTP route handlers

### 3. Route Registration

Routes are registered in `internal/server/http.go`:

#### Catalog-main example:
```go
func NewHTTPServer(
    c *config.Server,
    category *service.CategoryService,
    product *service.ProductService,
    // ... other services
    logger log.Logger,
) *http.Server {
    srv := http.NewServer(opts...)
    
    // Register routes
    categoryV1.RegisterCategoryServiceHTTPServer(srv, category)
    productV1.RegisterProductServiceHTTPServer(srv, product)
    // ... register other services
    
    return srv
}
```

#### Shop-main example:
```go
func NewHTTPServer(
    c *config.Server,
    logger log.Logger,
    product *service.ProductService,
    productV2 *serviceV2.ProductService,
    warehouse *service.WarehouseService,
) *http.Server {
    srv := http.NewServer(opts...)
    
    // Register routes
    productAPIV1.RegisterProductServiceHTTPServer(srv, product)
    productAPIV2.RegisterProductServiceHTTPServer(srv, productV2)
    warehouseAPIV1.RegisterWarehouseServiceHTTPServer(srv, warehouse)
    
    return srv
}
```

## Best Practices

### 1. Route Naming Convention

```
# Resource-based URLs
GET    /v1/products           # List products
POST   /v1/products           # Create product  
GET    /v1/products/{id}      # Get product
PUT    /v1/products/{id}      # Update product
DELETE /v1/products/{id}      # Delete product

# Action-based URLs for special operations
GET    /v1/products/{id}/sync-vtp
PUT    /v1/products/{id}/statuses
GET    /v1/products/search
```

### 2. Versioning Strategy

```
/v1/products    # Version 1
/v2/products    # Version 2
/external/v1/banners  # External API
/admin/v1/banners     # Admin API
```

### 3. Request/Response Messages

```protobuf
// Request naming: {Action}{Resource}Request
message CreateProductRequest { ... }
message UpdateProductRequest { ... }
message ListProductRequest { ... }

// Response naming: {Resource} or {Action}{Resource}Reply
message Product { ... }
message ListProductReply { ... }
```

## Workflow for Adding New Routes

### Step 1: Define Proto Service

```protobuf
service NewService {
    rpc CreateItem(CreateItemRequest) returns (Item) {
        option (google.api.http) = {
            post: "/v1/items"
            body: "*"
        };
    };
    
    rpc GetItem(GetItemRequest) returns (Item) {
        option (google.api.http) = {
            get: "/v1/items/{id}"
        };
    };
}
```

### Step 2: Define Messages

```protobuf
message CreateItemRequest {
    string name = 1;
    string description = 2;
}

message GetItemRequest {
    string id = 1;
}

message Item {
    string id = 1;
    string name = 2;
    string description = 3;
}
```

### Step 3: Generate Code

```bash
make api
```

### Step 4: Implement Service

```go
type NewService struct {
    // dependencies
}

func (s *NewService) CreateItem(ctx context.Context, req *v1.CreateItemRequest) (*v1.Item, error) {
    // implementation
}

func (s *NewService) GetItem(ctx context.Context, req *v1.GetItemRequest) (*v1.Item, error) {
    // implementation  
}
```

### Step 5: Register Route

Add to `internal/server/http.go`:

```go
func NewHTTPServer(
    // ... existing params
    newService *service.NewService,
) *http.Server {
    // ... existing code
    
    newServiceV1.RegisterNewServiceHTTPServer(srv, newService)
    
    return srv
}
```

### Step 6: Update Dependency Injection

Add service to wire.go and main.go to inject dependencies.

## Debugging Routes

### 1. View OpenAPI Documentation

```
GET /q/openapi     # OpenAPI spec
GET /q/            # Swagger UI
```

### 2. Log HTTP Requests

Routes use middleware to log requests:

```go
http.Middleware(
    recovery.Recovery(),
    metadata.Server(),
    newrelic.Server(),
)
```

## Catalog vs Shop Comparison

| Aspect | Catalog-main | Shop-main |
|--------|-------------|-----------|
| **Complexity** | High (20+ services) | Low (3 services) |
| **API Structure** | admin/, external/, v1/, v2/ | v1/, v2/ |
| **Route Count** | 100+ routes | 10+ routes |
| **Dependencies** | Many external services | Few dependencies |
| **Versioning** | Multi-version support | Simple versioning |

## Conclusion

Both services follow the same pattern:
1. **Proto-first approach** - Define API in proto files
2. **Code generation** - Generate HTTP handlers from proto
3. **Centralized registration** - Register all routes in http.go
4. **Middleware support** - Recovery, logging, tracing
5. **OpenAPI integration** - Automatically generate API documentation

This pattern ensures consistency, type safety and easy maintenance for the entire team.