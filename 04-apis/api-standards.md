
        "street": "123 Main St",
        "city": "San Francisco",
        "state": "CA",
        "zip": "94105"
      }
    }
  }
}

// Success Response Format
{
  "data": {
    "type": "order",
    "id": "ord_789",
    "attributes": {
      "status": "confirmed",
      "total": 59.98,
      "created_at": "2026-01-26T10:30:00Z"
    }
  },
  "meta": {
    "request_id": "req_abc123",
    "timestamp": "2026-01-26T10:30:00Z"
  }
}

// Error Response Format
{
  "errors": [
    {
      "code": "INVALID_PAYMENT_METHOD",
      "message": "The provided payment method is invalid",
      "details": {
        "field": "payment_method",
        "value": "invalid_card"
      }
    }
  ],
  "meta": {
    "request_id": "req_abc123",
    "timestamp": "2026-01-26T10:30:00Z"
  }
}
```

### **Status Codes**
```
Success Codes:
200 OK          - Successful GET, PUT, PATCH
201 Created     - Successful POST (resource created)
202 Accepted    - Async operation accepted
204 No Content  - Successful DELETE

Client Error Codes:
400 Bad Request     - Invalid request format
401 Unauthorized    - Authentication required
403 Forbidden       - Access denied
404 Not Found       - Resource not found
409 Conflict        - Resource conflict
422 Unprocessable   - Validation errors
429 Too Many Requests - Rate limit exceeded

Server Error Codes:
500 Internal Server Error - Unexpected server error
502 Bad Gateway          - Upstream service error
503 Service Unavailable  - Service temporarily down
504 Gateway Timeout      - Upstream service timeout
```

## ⚡ **gRPC API Standards**

### **Service Definition**
```protobuf
syntax = "proto3";

package api.order.v1;

import "google/api/annotations.proto";
import "google/protobuf/timestamp.proto";
import "validate/validate.proto";

// Order service definition
service OrderService {
  // Create a new order
  rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse) {
    option (google.api.http) = {
      post: "/v1/orders"
      body: "*"
    };
  }
  
  // Get order by ID
  rpc GetOrder(GetOrderRequest) returns (GetOrderResponse) {
    option (google.api.http) = {
      get: "/v1/orders/{order_id}"
    };
  }
  
  // List orders with pagination
  rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse) {
    option (google.api.http) = {
      get: "/v1/orders"
    };
  }
}

// Request/Response messages
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

// RPC names: PascalCase verbs
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

### **API Key Authentication**
```http
X-API-Key: ak_live_1234567890abcdef

// For service-to-service communication
X-Service-Key: sk_internal_abcdef1234567890
```

### **Role-Based Access Control**
```yaml
# RBAC Configuration
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

## 📊 **Pagination & Filtering**

### **Pagination**
```http
GET /api/v1/orders?page=2&limit=20&sort=created_at:desc

Response:
{
  "data": [...],
  "pagination": {
    "page": 2,
    "limit": 20,
    "total": 150,
    "pages": 8,
    "has_next": true,
    "has_prev": true
  }
}
```

### **Filtering**
```http
GET /api/v1/orders?status=confirmed&customer_id=cust_123&created_after=2026-01-01

// Complex filters
GET /api/v1/products?category=electronics&price_min=100&price_max=500&in_stock=true
```

### **Field Selection**
```http
GET /api/v1/orders?fields=id,status,total,created_at

Response:
{
  "data": [
    {
      "id": "ord_123",
      "status": "confirmed",
      "total": 99.99,
      "created_at": "2026-01-26T10:30:00Z"
    }
  ]
}
```

## ⚡ **Performance Standards**

### **Response Time Targets**
- **Simple Queries**: < 100ms (95th percentile)
- **Complex Queries**: < 500ms (95th percentile)
- **Write Operations**: < 200ms (95th percentile)
- **Bulk Operations**: < 2s (95th percentile)

### **Caching Strategy**
```http
// Cache headers
Cache-Control: public, max-age=300
ETag: "abc123def456"
Last-Modified: Wed, 26 Jan 2026 10:30:00 GMT

// Conditional requests
If-None-Match: "abc123def456"
If-Modified-Since: Wed, 26 Jan 2026 10:30:00 GMT
```

### **Rate Limiting**
```http
// Rate limit headers
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1643723400

// Rate limit exceeded
HTTP/1.1 429 Too Many Requests
Retry-After: 60
```

## 🔍 **API Versioning**

### **URL Versioning**
```
/api/v1/orders    # Version 1
/api/v2/orders    # Version 2
```

### **Header Versioning**
```http
Accept: application/vnd.api+json;version=1
API-Version: 2026-01-26
```

### **Deprecation Strategy**
```http
// Deprecation headers
Deprecation: true
Sunset: Wed, 26 Jul 2026 10:30:00 GMT
Link: </api/v2/orders>; rel="successor-version"
```

## 📚 **Documentation Standards**

### **OpenAPI Specification**
```yaml
openapi: 3.0.3
info:
  title: Order Service API
  version: 1.0.0
  description: Order management API
  contact:
    name: API Support
    email: api-support@example.com
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.example.com/v1
    description: Production server
  - url: https://staging-api.example.com/v1
    description: Staging server

paths:
  /orders:
    post:
      summary: Create a new order
      description: Creates a new order for the authenticated customer
      operationId: createOrder
      tags:
        - Orders
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateOrderRequest'
            examples:
              simple_order:
                summary: Simple order example
                value:
                  customer_id: "cust_123"
                  items:
                    - product_id: "prod_456"
                      quantity: 2
                      price: 29.99
      responses:
        '201':
          description: Order created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Order'
        '400':
          description: Invalid request
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
```

## 🧪 **Testing Standards**

### **API Contract Testing**
```javascript
// Contract test example
describe('Order API Contract', () => {
  test('POST /orders should create order', async () => {
    const response = await request(app)
      .post('/api/v1/orders')
      .send({
        customer_id: 'cust_123',
        items: [{ product_id: 'prod_456', quantity: 2 }]
      })
      .expect(201);
    
    expect(response.body).toMatchSchema(orderSchema);
    expect(response.body.data.id).toBeDefined();
    expect(response.body.data.attributes.status).toBe('pending');
  });
});
```

### **Load Testing**
```yaml
# K6 load test configuration
scenarios:
  create_orders:
    executor: ramping-vus
    startVUs: 0
    stages:
      - duration: 2m
        target: 100
      - duration: 5m
        target: 100
      - duration: 2m
        target: 0
    gracefulRampDown: 30s

thresholds:
  http_req_duration:
    - p(95)<500
  http_req_failed:
    - rate<0.01
```

## 🔗 **Related Documentation**

- **[gRPC Guidelines](grpc-guidelines.md)** - Detailed gRPC implementation guidelines
- **[OpenAPI Specifications](openapi/)** - Complete API specifications
- **[Event Schemas](event-schemas/)** - Event-driven API contracts
- **[Architecture](../01-architecture/)** - System architecture context

---

**Last Updated**: January 26, 2026  
**Maintained By**: API Team