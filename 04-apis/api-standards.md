# 📋 API Design Standards

**Purpose**: API design standards and best practices for all microservices

---

## 📋 **Overview**

This document defines the API design standards that all microservices must follow. It ensures consistency, developer experience, and interoperability across 20+ services.

---

## 🌐 **REST API Standards**

### **URL Structure**
```
/api/v{version}/{service}/{resource}
/api/v{version}/{service}/{resource}/{id}
/api/v{version}/{service}/{resource}/{id}/{sub-resource}
```

### **HTTP Methods**
```
GET     - Retrieve resource(s)
POST    - Create resource or trigger action
PUT     - Full resource update
PATCH   - Partial resource update
DELETE  - Remove resource
```

### **Resource Naming**
- Use **plural nouns** for resources: `/orders`, `/products`, `/customers`
- Use **kebab-case** for multi-word resources: `/order-items`, `/payment-methods`
- Nest sub-resources under parent: `/orders/{id}/payments`
- Use verbs only for actions: `/orders/{id}/cancel`, `/cart/checkout`

### **Path Parameters**
- Use `{id}` for primary identifiers
- Use descriptive names for clarity: `{orderId}`, `{customerId}`
- All IDs are strings (UUIDs)

---

## 📦 **Request/Response Format**

### **Request Format**
```json
// POST /api/v1/orders
{
  "customerId": "cust_123",
  "items": [
    {
      "productSku": "WIDGET-BLUE-M",
      "quantity": 2,
      "warehouseId": "wh_01"
    }
  ],
  "shippingAddress": {
    "addressLine1": "123 Main St",
    "city": "Ho Chi Minh",
    "stateProvince": "HCM",
    "postalCode": "70000",
    "countryCode": "VN"
  }
}
```

### **Success Response Format**
```json
// Single resource
{
  "order": {
    "id": "ord_789",
    "status": "PENDING",
    "totalAmount": 1499000,
    "currency": "VND",
    "createdAt": "2026-01-26T10:30:00Z"
  }
}

// List response (with pagination)
{
  "orders": [...],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "total": 150
  }
}
```

### **Error Response Format**
```json
{
  "code": 400,
  "reason": "INVALID_PAYMENT_METHOD",
  "message": "The provided payment method is invalid",
  "metadata": {
    "field": "paymentMethod",
    "value": "invalid_card"
  }
}
```

> **Note**: Error responses follow the Kratos error format (`code`, `reason`, `message`, `metadata`).

---

## 📊 **Status Codes**

### **Success Codes**
```
200 OK          - Successful GET, PUT, PATCH
201 Created     - Successful POST (resource created)
202 Accepted    - Async operation accepted
204 No Content  - Successful DELETE
```

### **Client Error Codes**
```
400 Bad Request     - Invalid request format
401 Unauthorized    - Authentication required
403 Forbidden       - Access denied
404 Not Found       - Resource not found
409 Conflict        - Resource conflict
422 Unprocessable   - Validation errors
429 Too Many Requests - Rate limit exceeded
```

### **Server Error Codes**
```
500 Internal Server Error - Unexpected server error
502 Bad Gateway          - Upstream service error
503 Service Unavailable  - Service temporarily down
504 Gateway Timeout      - Upstream service timeout
```

---

## ⚡ **gRPC API Standards**

### **Service Definition**
```protobuf
syntax = "proto3";

package api.order.v1;

import "google/api/annotations.proto";
import "google/protobuf/timestamp.proto";
import "validate/validate.proto";

service OrderService {
  rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse) {
    option (google.api.http) = {
      post: "/v1/orders"
      body: "*"
    };
  }

  rpc GetOrder(GetOrderRequest) returns (GetOrderResponse) {
    option (google.api.http) = {
      get: "/v1/orders/{order_id}"
    };
  }

  rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse) {
    option (google.api.http) = {
      get: "/v1/orders"
    };
  }
}
```

### **Request/Response Messages**
```protobuf
message CreateOrderRequest {
  string customer_id = 1 [(validate.rules).string.min_len = 1];
  repeated OrderItem items = 2 [(validate.rules).repeated.min_items = 1];
  Address shipping_address = 3 [(validate.rules).message.required = true];
  string payment_method = 4 [(validate.rules).string.min_len = 1];
}

message CreateOrderResponse {
  Order order = 1;
}

message Order {
  string id = 1;
  string customer_id = 2;
  repeated OrderItem items = 3;
  OrderStatus status = 4;
  double total = 5;
  google.protobuf.Timestamp created_at = 6;
  google.protobuf.Timestamp updated_at = 7;
}

enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;
  ORDER_STATUS_PENDING = 1;
  ORDER_STATUS_CONFIRMED = 2;
  ORDER_STATUS_FULFILLED = 3;
  ORDER_STATUS_CANCELLED = 4;
}
```

### **Naming Conventions**
```protobuf
// Service names: PascalCase with "Service" suffix
service OrderService {}
service PaymentService {}

// RPC names: PascalCase Verb-Noun
rpc CreateOrder() {}
rpc GetOrder() {}
rpc ListOrders() {}
rpc UpdateOrder() {}
rpc DeleteOrder() {}

// Message names: PascalCase nouns
message Order {}
message CreateOrderRequest {}
message CreateOrderResponse {}

// Field names: snake_case
message Order {
  string order_id = 1;
  string customer_id = 2;
  google.protobuf.Timestamp created_at = 3;
}

// Enum names: UPPER_SNAKE_CASE with type prefix
enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;
  ORDER_STATUS_PENDING = 1;
  ORDER_STATUS_CONFIRMED = 2;
}
```

---

## 🔒 **Authentication & Authorization**

### **JWT Authentication**
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

// JWT Payload
{
  "sub": "user_123",
  "iss": "auth-service",
  "aud": ["api-gateway"],
  "exp": 1643723400,
  "iat": 1643719800,
  "roles": ["customer"],
  "permissions": ["orders:read", "orders:create"]
}
```

### **Service-to-Service Authentication**
```http
// For internal gRPC calls via Consul service discovery
// mTLS handled by Dapr sidecar
X-Service-Key: sk_internal_abcdef1234567890
```

### **Role-Based Access Control**
```yaml
roles:
  customer:
    permissions:
      - orders:read:own
      - orders:create
      - profile:read:own
      - profile:update:own

  admin:
    permissions:
      - orders:read:all
      - orders:update:all
      - users:read:all
      - analytics:read:all

  service:
    permissions:
      - orders:read:all
      - orders:update:all
      - inventory:read:all
      - inventory:update:all
```

---

## 📊 **Pagination**

### **Offset-Based Pagination (REST)**
```http
GET /api/v1/orders?page=2&pageSize=20&sort=created_at:desc

Response:
{
  "data": [...],
  "pagination": {
    "page": 2,
    "pageSize": 20,
    "total": 150
  }
}
```

### **Cursor-Based Pagination (gRPC)**
```protobuf
message ListRequest {
  int32 page_size = 1 [(validate.rules).int32 = {gte: 1, lte: 100}];
  string page_token = 2;
  string order_by = 3;
}

message ListResponse {
  repeated Item items = 1;
  int32 total_size = 2;
  string next_page_token = 3;
}
```

> **Standard**: REST uses offset-based (`page`/`pageSize`). gRPC internal APIs use cursor-based (`page_token`/`page_size`) for better performance at scale.

### **Filtering**
```http
GET /api/v1/orders?status=confirmed&customerId=cust_123&startDate=2026-01-01
GET /api/v1/products?category=electronics&brand=samsung&minPrice=100000
```

---

## 🔑 **Idempotency**

### **Write Operation Idempotency**
All POST (create) and PUT (update) endpoints MUST support idempotency:

```http
// Client sends unique idempotency key
POST /api/v1/orders
Idempotency-Key: "idem_550e8400-e29b-41d4-a716"

// Server deduplicates within 24-hour window
// If same key received again, return original response
```

**Rules:**
- `Idempotency-Key` header is REQUIRED for all POST endpoints
- Server maintains a 24-hour deduplication window
- Duplicate requests return the original response with `200 OK`
- Keys are scoped per-user to prevent cross-user conflicts

---

## ⚡ **Performance Standards**

### **Response Time Targets**
- **Simple Queries**: < 100ms (95th percentile)
- **Complex Queries**: < 500ms (95th percentile)
- **Write Operations**: < 200ms (95th percentile)
- **Bulk Operations**: < 2s (95th percentile)

### **Caching Strategy**
```http
Cache-Control: public, max-age=300
ETag: "abc123def456"
Last-Modified: Wed, 26 Jan 2026 10:30:00 GMT

// Conditional requests
If-None-Match: "abc123def456"
If-Modified-Since: Wed, 26 Jan 2026 10:30:00 GMT
```

### **Rate Limiting**
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1643723400

// Rate limit exceeded
HTTP/1.1 429 Too Many Requests
Retry-After: 60
```

---

## 🔍 **API Versioning**

### **URL Versioning** (Primary)
```
/api/v1/orders    # Version 1
/api/v2/orders    # Version 2
```

### **Deprecation Strategy**
```http
Deprecation: true
Sunset: Wed, 26 Jul 2026 10:30:00 GMT
Link: </api/v2/orders>; rel="successor-version"
```

---

## 🧪 **Testing Standards**

### **API Contract Testing**
```go
func TestCreateOrder(t *testing.T) {
    req := &pb.CreateOrderRequest{
        CustomerId: "cust_123",
        Items: []*pb.OrderItem{
            {ProductSku: "WIDGET-BLUE-M", Quantity: 2},
        },
    }

    resp, err := client.CreateOrder(ctx, req)
    assert.NoError(t, err)
    assert.NotNil(t, resp.Order)
    assert.Equal(t, "cust_123", resp.Order.CustomerId)
}
```

---

## 🔗 **Related Documentation**

- **[gRPC Guidelines](grpc-guidelines.md)** - Detailed gRPC implementation guidelines
- **[OpenAPI Specifications](openapi/)** - Complete API specifications (proto-generated)
- **[Event Schemas](event-schemas/)** - Event-driven API contracts

---

**Last Updated**: March 2, 2026
**Maintained By**: API Team