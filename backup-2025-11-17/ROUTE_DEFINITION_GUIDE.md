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

## Admin BFF (Backend for Frontend) Pattern

### Overview

The Admin BFF pattern provides a unified API gateway for admin dashboard requests. All admin requests go through `/admin/v1/*` endpoints, which are routed to the appropriate microservices with admin-specific middleware (authentication, audit logging, rate limiting).

### Route Pattern

**Admin Request Format:**
```
/admin/v1/{service-resource}/{action}
```

**Service Endpoint Format:**
```
/api/v1/{service}/{resource}/{action}
```

### Why Use `/api/v1/*` Pattern?

1. **BFF là API Gateway thu nhỏ**: Dùng `/api/` để phân tách rõ ràng namespace cho REST API
2. **Ngăn chặn route conflict**: Nếu frontend/static content deploy chung domain, `/api/` giữ route API tách biệt
3. **Chuẩn hóa versioning**: `/api/v1/catalog`, `/api/v2/catalog` rõ ràng hơn `/v1/catalog`
4. **Best practice của BFF**: Hầu hết BFF implementations dùng `/api/` prefix

**Namespace Separation:**
- `/api/*` → REST API endpoints
- `/ws/*` → WebSocket endpoints
- `/auth/*` → Login SSO, OAuth callbacks
- `/internal/*` → Internal routes
- `/metrics/*` → Prometheus metrics

### Service Mapping Examples

| Admin Route | Service Route | Service Name |
|-------------|---------------|--------------|
| `/admin/v1/products` | `/api/v1/catalog/products` | `catalog` |
| `/admin/v1/orders` | `/api/v1/orders` | `order` |
| `/admin/v1/pricing/discounts` | `/api/v1/pricing/discounts` | `pricing` |
| `/admin/v1/users` | `/api/v1/users` | `user` |
| `/admin/v1/warehouses` | `/api/v1/warehouses` | `warehouse` |

### Implementation Steps for New Services

#### Step 1: Update Service Proto

Define endpoints using `/api/v1/{service-name}/*` pattern:

```protobuf
service OrderService {
  rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse) {
    option (google.api.http) = {
      get: "/api/v1/orders"  // ✅ Correct pattern
    };
  }
  
  // ✅ Use: /api/v1/orders
  // ❌ Avoid: /v1/orders (missing /api/ prefix)
}
```

**Pattern Rules:**
- ✅ Use `/api/v1/{service-resource}/*` for all endpoints
- ✅ Follow BFF best practice: `/api/v1/catalog/products`
- ✅ Keep service name in path: `/api/v1/pricing/discounts`, `/api/v1/orders`
- ✅ Clear namespace separation: `/api/` for REST API, `/ws/` for WebSocket, etc.

#### Step 2: Regenerate Proto Code

```bash
cd /home/tuananh/microservices/{service-name}
make api
```

#### Step 3: Update Gateway Routing

Add service mapping in `gateway/internal/router/kratos_router.go`:

```go
func (rm *RouteManager) handleBFFAdminInternal(w http.ResponseWriter, r *http.Request, path string) {
    // ... existing code ...
    
    // Determine service name from path
    switch serviceName {
    case "catalog":
        // /admin/v1/products -> /api/v1/catalog/products
        if strings.HasPrefix(remainingPath, "cms/") {
            targetPath = "/api/v1/" + remainingPath
        } else if strings.HasPrefix(remainingPath, "catalog/") {
            targetPath = "/api/v1/" + remainingPath
        } else {
            targetPath = "/api/v1/catalog/" + remainingPath
        }
    case "order":
        // /admin/v1/orders -> /api/v1/orders
        targetPath = "/api/v1/" + remainingPath
    case "pricing":
        // /admin/v1/pricing/* -> /api/v1/pricing/*
        targetPath = "/api/v1/" + remainingPath
    case "your-service":
        // /admin/v1/your-resource -> /api/v1/your-service/your-resource
        targetPath = "/api/v1/" + remainingPath  // or "/api/v1/your-service/" + remainingPath
    default:
        // Default: /admin/v1/* -> /api/v1/*
        targetPath = "/api/v1/" + remainingPath
    }
}
```

**Service Name Detection:**

The gateway determines service name from the first path segment after `/admin/v1/`:

```go
// Extract service name from path
// /admin/v1/orders -> serviceName = "orders" -> maps to "order" service
// /admin/v1/products -> serviceName = "products" -> maps to "catalog" service
// /admin/v1/pricing/discounts -> serviceName = "pricing" -> maps to "pricing" service

parts := strings.Split(strings.TrimPrefix(path, "/admin/v1/"), "/")
firstSegment := parts[0]

switch firstSegment {
case "products", "categories", "brands", "attributes", "catalog", "cms":
    serviceName = "catalog"
case "orders", "order":
    serviceName = "order"
case "pricing":
    serviceName = "pricing"
case "users", "user":
    serviceName = "user"
case "warehouses", "warehouse", "inventory":
    serviceName = "warehouse"
case "your-resource":
    serviceName = "your-service"
}
```

#### Step 4: Gateway Features

The Admin BFF handler automatically provides:

1. **Authentication**: Validates admin JWT tokens
2. **Audit Logging**: Logs all admin actions
3. **Rate Limiting**: Protects against abuse
4. **Context Headers**: Forwards `X-User-ID`, `X-Client-Type`, etc.
5. **CORS Handling**: Proper CORS headers for admin dashboard

**Context Headers Forwarding:**
```go
// Gateway automatically forwards these headers:
// - X-User-ID: Admin user ID
// - X-Client-Type: "admin"
// - X-MD-*: Metadata headers
// - Authorization: Bearer token
rm.copyContextHeadersKratos(r, proxyReq)
```

#### Step 5: Query Parameter Handling

Query parameters are automatically forwarded. For special cases, add transformation:

```go
if serviceName == "catalog" {
    // Transform query params if needed
    // Example: page -> page, perPage -> limit
}
```

#### Step 6: Testing

Test the routing:

```bash
# Test admin BFF endpoint
curl 'http://localhost:8080/admin/v1/orders?page=1&page_size=10' \
  -H 'Authorization: Bearer {admin_token}'

# Should route to: order service at /api/v1/orders
```

### Complete Example: Adding a New Service

**Example: Adding "Notification" Service**

1. **Update Proto** (`notification/api/notification/v1/notification.proto`):
```protobuf
service NotificationService {
  rpc ListNotifications(ListNotificationsRequest) returns (ListNotificationsResponse) {
    option (google.api.http) = {
      get: "/api/v1/notifications"  // ✅ Use /api/v1/notifications
    };
  }
}
```

2. **Regenerate Code**:
```bash
cd /home/tuananh/microservices/notification
make api
```

3. **Update Gateway** (`gateway/internal/router/kratos_router.go`):
```go
// In service name detection
case "notifications", "notification":
    serviceName = "notification"

// In target path mapping
case "notification":
    // /admin/v1/notifications -> /api/v1/notifications
    targetPath = "/api/v1/" + remainingPath
```

4. **Test**:
```bash
curl 'http://localhost:8080/admin/v1/notifications?page=1' \
  -H 'Authorization: Bearer {admin_token}'
```

### Best Practices

1. **Consistent Path Pattern**: Always use `/api/v1/{service-resource}/*` in proto
2. **Namespace Separation**: Use `/api/` prefix for REST API, `/ws/` for WebSocket, etc.
3. **Service Name Mapping**: Map admin path to service name clearly
4. **No Query Transformation**: Forward query params as-is unless special case
5. **Context Headers**: Always forward context headers for service-to-service calls
6. **Error Handling**: Gateway handles errors consistently
7. **Logging**: Add debug logging for troubleshooting

### Migration Checklist

When migrating a service to Admin BFF pattern:

- [ ] Update proto endpoints to `/api/v1/{service}/*` pattern
- [ ] Regenerate proto code (`make api`)
- [ ] Update gateway routing logic to map to `/api/v1/*`
- [ ] Add service name detection mapping
- [ ] Add target path mapping
- [ ] Test admin BFF endpoint
- [ ] Update frontend API client to use `/admin/v1/*`
- [ ] Update documentation

## Conclusion

Both services follow the same pattern:
1. **Proto-first approach** - Define API in proto files
2. **Code generation** - Generate HTTP handlers from proto
3. **Centralized registration** - Register all routes in http.go
4. **Middleware support** - Recovery, logging, tracing
5. **OpenAPI integration** - Automatically generate API documentation
6. **Admin BFF pattern** - Unified admin API gateway with consistent routing

This pattern ensures consistency, type safety and easy maintenance for the entire team.