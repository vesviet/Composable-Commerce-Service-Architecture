# Route Implementation Checklist

## Checklist for Adding New Routes

### ✅ Pre-implementation

- [ ] **Determine API version** (v1, v2, admin, external)
- [ ] **Determine HTTP method** (GET, POST, PUT, DELETE)
- [ ] **Design URL path** following RESTful convention
- [ ] **Define request/response schema**
- [ ] **Determine dependencies** (services, repositories)

### ✅ Proto Definition

- [ ] **Create/update proto file** in corresponding api directory
- [ ] **Import required dependencies**
  ```protobuf
  import "google/api/annotations.proto";
  import "google/protobuf/timestamp.proto";
  ```
- [ ] **Define service with HTTP annotations**
  ```protobuf
  service ProductService {
      rpc CreateProduct(CreateProductRequest) returns (Product) {
          option (google.api.http) = {
              post: "/api/v1/products"  // ✅ Use /api/v1/* pattern
              body: "*"
          };
      };
  }
  ```
  
  **Pattern Rules:**
  - ✅ Use `/api/v1/{service-resource}/*` for all endpoints
  - ✅ BFF best practice: `/api/` prefix for REST API namespace separation
  - ✅ Clear versioning: `/api/v1/catalog`, `/api/v2/catalog`
- [ ] **Define request/response messages**
- [ ] **Validate proto syntax**: `protoc --proto_path=./api --dry-run api/v1/service/service.proto`

### ✅ Code Generation

- [ ] **Run code generation**: `make api`
- [ ] **Verify generated files**:
  - [ ] `service_name.pb.go`
  - [ ] `service_name_grpc.pb.go` 
  - [ ] `service_name_http.pb.go`
- [ ] **Check for compilation errors**: `go build ./api/...`

### ✅ Service Implementation

- [ ] **Create service struct** in `internal/service/`
- [ ] **Implement interface methods**
- [ ] **Add proper error handling**
- [ ] **Add input validation**
- [ ] **Add logging/tracing**
- [ ] **Unit tests for service methods**

### ✅ Route Registration

- [ ] **Import generated package** in `internal/server/http.go`
- [ ] **Add service parameter** in `NewHTTPServer` function
- [ ] **Register service**: `serviceV1.RegisterServiceHTTPServer(srv, service)`
- [ ] **Update dependency injection** (wire.go, main.go)

### ✅ Testing

- [ ] **Unit tests** for service logic
- [ ] **Integration tests** for HTTP endpoints
- [ ] **Test with curl/Postman**:
  ```bash
  # GET request
  curl -X GET "http://localhost:8000/v1/products"
  
  # POST request
  curl -X POST "http://localhost:8000/v1/products" \
       -H "Content-Type: application/json" \
       -d '{"name": "test", "status": "active"}'
  ```
- [ ] **Verify OpenAPI documentation**: `http://localhost:8000/q/`

### ✅ Documentation

- [ ] **Update API documentation**
- [ ] **Add code comments**
- [ ] **Update README if needed**
- [ ] **Document breaking changes**

## Common Issues & Solutions

### 1. Proto Compilation Errors

**Issue**: `protoc: error while loading shared libraries`
```bash
# Solution: Install protoc dependencies
make init
```

**Issue**: `import "google/api/annotations.proto" was not found`
```bash
# Solution: Ensure third_party folder có đầy đủ dependencies
git submodule update --init --recursive
```

### 2. Route Registration Issues

**Issue**: Route not registered
```go
// ❌ Wrong: Missing service registration
func NewHTTPServer(...) *http.Server {
    srv := http.NewServer(opts...)
    // Missing: serviceV1.RegisterServiceHTTPServer(srv, service)
    return srv
}

// ✅ Correct: Proper registration
func NewHTTPServer(..., newService *service.NewService) *http.Server {
    srv := http.NewServer(opts...)
    serviceV1.RegisterServiceHTTPServer(srv, newService)
    return srv
}
```

### 3. HTTP Method Mismatch

**Issue**: Wrong HTTP method in proto
```protobuf
// ❌ Wrong: Using GET for data modification
rpc CreateProduct(CreateProductRequest) returns (Product) {
    option (google.api.http) = {
        get: "/v1/products"  // Should be POST
    };
}

// ✅ Correct: Proper HTTP method
rpc CreateProduct(CreateProductRequest) returns (Product) {
    option (google.api.http) = {
        post: "/v1/products"
        body: "*"
    };
}
```

### 4. Path Parameter Issues

**Issue**: Path parameter doesn't match message field
```protobuf
// ❌ Wrong: Field name mismatch
message GetProductRequest {
    string product_id = 1;  // Field name: product_id
}

rpc GetProduct(GetProductRequest) returns (Product) {
    option (google.api.http) = {
        get: "/v1/products/{id}"  // Path param: id
    };
}

// ✅ Correct: Matching field name
message GetProductRequest {
    string id = 1;  // Field name: id
}

rpc GetProduct(GetProductRequest) returns (Product) {
    option (google.api.http) = {
        get: "/v1/products/{id}"  // Path param: id
    };
}
```

## Quick Reference Commands

```bash
# Generate API code
make api

# Generate all code
make all

# Build project
make build

# Run linting
make lint

# Run tests
go test ./...

# Check proto syntax
protoc --proto_path=./api --dry-run api/v1/service/service.proto

# View generated routes
curl http://localhost:8000/q/openapi | jq '.paths'
```

## Route Testing Template

```bash
#!/bin/bash
# test_routes.sh

BASE_URL="http://localhost:8000"

echo "Testing GET /v1/products"
curl -X GET "$BASE_URL/v1/products" | jq '.'

echo "Testing POST /v1/products"
curl -X POST "$BASE_URL/v1/products" \
     -H "Content-Type: application/json" \
     -d '{"name": "Test Product", "status": "active"}' | jq '.'

echo "Testing GET /v1/products/{id}"
curl -X GET "$BASE_URL/v1/products/123" | jq '.'

echo "Testing PUT /v1/products/{id}"
curl -X PUT "$BASE_URL/v1/products/123" \
     -H "Content-Type: application/json" \
     -d '{"name": "Updated Product", "status": "inactive"}' | jq '.'
```

## Performance Considerations

- [ ] **Add pagination** for list endpoints
- [ ] **Implement caching** for frequently accessed data
- [ ] **Add rate limiting** if needed
- [ ] **Optimize database queries**
- [ ] **Add request/response compression**
- [ ] **Monitor endpoint performance**

## Security Checklist

- [ ] **Input validation** for all request parameters
- [ ] **Authentication/Authorization** middleware
- [ ] **SQL injection prevention**
- [ ] **XSS protection**
- [ ] **Rate limiting**
- [ ] **CORS configuration**
- [ ] **Sensitive data masking** in logs