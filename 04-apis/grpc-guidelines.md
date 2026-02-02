# 🚀 gRPC Guidelines

**Purpose**: gRPC implementation standards, best practices, and conventions

---

## 📋 **Overview**

This document provides comprehensive guidelines for implementing gRPC services in our microservices architecture. It covers service definitions, protocol buffer standards, error handling, and integration patterns.

---

## 🏗️ **Service Definition Standards**

### **File Structure**
```
service-name/
├── api/
│   └── service-name/
│       └── v1/
│           ├── service_name.proto      # Main service definition
│           ├── service_name_types.proto # Shared types/enums
│           └── service_name_test.proto  # Test messages
├── cmd/
│   └── service-name/
│       └── main.go                     # gRPC server implementation
└── internal/
    ├── server/
    │   ├── grpc.go                     # gRPC server setup
    │   └── handlers.go                 # gRPC handlers
    └── service/
        └── service_name.go             # Business logic
```

### **Proto File Organization**
```protobuf
syntax = "proto3";

package api.service_name.v1;

import "google/api/annotations.proto";
import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";
import "validate/validate.proto";

option go_package = "github.com/organization/microservices/service-name/api/service-name/v1;service_name";
option java_multiple_files = true;
option java_package = "api.service_name.v1";
```

---

## 📝 **Naming Conventions**

### **Service Names**
```protobuf
// PascalCase with descriptive purpose
service OrderService {}
service PaymentService {}
service InventoryService {}
service NotificationService {}
```

### **RPC Methods**
```protobuf
// Use verb-noun pattern for clarity
rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse);
rpc GetOrder(GetOrderRequest) returns (GetOrderResponse);
rpc ListOrders(ListOrdersRequest) returns (ListOrdersResponse);
rpc UpdateOrderStatus(UpdateOrderStatusRequest) returns (UpdateOrderStatusResponse);
rpc CancelOrder(CancelOrderRequest) returns (CancelOrderResponse);
```

### **Message Names**
```protobuf
// Request/Response pairs
message CreateOrderRequest {}
message CreateOrderResponse {}

// Resource messages
message Order {}
message OrderItem {}
message Customer {}

// Shared types
message Address {}
message Money {}
message Pagination {}
```

### **Field Names**
```protobuf
// snake_case for all fields
message Order {
  string order_id = 1;
  string customer_id = 2;
  repeated OrderItem items = 3;
  OrderStatus status = 4;
  google.protobuf.Timestamp created_at = 5;
  google.protobuf.Timestamp updated_at = 6;
}
```

### **Enum Names**
```protobuf
// UPPER_SNAKE_CASE with type prefix
enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;  // Default value
  ORDER_STATUS_PENDING = 1;
  ORDER_STATUS_CONFIRMED = 2;
  ORDER_STATUS_FULFILLED = 3;
  ORDER_STATUS_CANCELLED = 4;
  ORDER_STATUS_REFUNDED = 5;
}
```

---

## 🔧 **Message Design Patterns**

### **Request Messages**
```protobuf
message CreateOrderRequest {
  // Required fields with validation
  string customer_id = 1 [(validate.rules).string.min_len = 1];
  repeated OrderItem items = 2 [(validate.rules).repeated.min_items = 1];
  Address shipping_address = 3 [(validate.rules).message.required = true];
  
  // Optional fields
  string payment_method_id = 4;
  string coupon_code = 5;
  
  // Metadata
  string request_id = 6;
  google.protobuf.Timestamp created_at = 7;
}

message GetOrderRequest {
  string order_id = 1 [(validate.rules).string.min_len = 1];
  
  // Field selection
  repeated string fields = 2;
  
  // Include related data
  bool include_items = 3;
  bool include_customer = 4;
}
```

### **Response Messages**
```protobuf
message CreateOrderResponse {
  Order order = 1;
  
  // Operation metadata
  string request_id = 2;
  google.protobuf.Timestamp processed_at = 3;
}

message ListOrdersResponse {
  repeated Order orders = 1;
  
  // Pagination metadata
  int32 total_count = 2;
  string next_page_token = 3;
  string prev_page_token = 4;
}
```

### **Resource Messages**
```protobuf
message Order {
  // Core fields
  string id = 1;
  string customer_id = 2;
  OrderStatus status = 3;
  
  // Financial data
  Money subtotal = 4;
  Money tax = 5;
  Money total = 6;
  
  // Timestamps
  google.protobuf.Timestamp created_at = 7;
  google.protobuf.Timestamp updated_at = 8;
  
  // Nested objects
  repeated OrderItem items = 9;
  Address shipping_address = 10;
  Address billing_address = 11;
}

message Money {
  string currency_code = 1;  // ISO 4217 currency code
  int64 units = 2;           // Whole units
  int32 nanos = 3;           // Nano units (1-999,999,999)
}
```

---

## 🚨 **Error Handling**

### **Standard Error Response**
```protobuf
// Use google.rpc.Status for rich error information
import "google/rpc/status.proto";
import "google/rpc/error_details.proto";

// In your gRPC service:
rpc GetOrder(GetOrderRequest) returns (GetOrderResponse) {
  option (google.api.http) = {
    get: "/v1/orders/{order_id}"
  };
}

// Error examples:
// 1. Resource not found
throw new StatusException(Status.NOT_FOUND.withDescription("Order not found")
    .withCause(new NotFoundException("Order " + orderId + " not found")));

// 2. Validation errors
throw new StatusException(Status.INVALID_ARGUMENT.withDescription("Invalid request")
    .withDetails(InvalidArgument.newBuilder()
        .addFieldViolations(FieldViolation.newBuilder()
            .setField("customer_id")
            .setDescription("Customer ID is required")
            .build())
        .build()));

// 3. Permission denied
throw new StatusException(Status.PERMISSION_DENIED.withDescription("Access denied")
    .withDetails(ErrorInfo.newBuilder()
        .setReason("INSUFFICIENT_PERMISSIONS")
        .addMetadata("required_permission", "orders:read")
        .build()));
```

### **Custom Error Types**
```protobuf
message ValidationError {
  string field = 1;
  string message = 2;
  string code = 3;
}

message BusinessError {
  string code = 1;
  string message = 2;
  map<string, string> details = 3;
}
```

---

## 🔍 **Validation**

### **Field Validation Rules**
```protobuf
import "validate/validate.proto";

message CreateCustomerRequest {
  // String validation
  string email = 1 [(validate.rules).string.email = true];
  string phone = 2 [(validate.rules).string.pattern = "^\\+?[1-9]\\d{1,14}$"];
  
  // Length validation
  string name = 3 [(validate.rules).string = {
    min_len: 2,
    max_len: 100
  }];
  
  // Numeric validation
  int32 age = 4 [(validate.rules).int32 = {
    gte: 18,
    lte: 120
  }];
  
  // Required fields
  Address address = 5 [(validate.rules).message.required = true];
  
  // Array validation
  repeated string tags = 6 [(validate.rules).repeated = {
    min_items: 1,
    max_items: 10,
    unique: true
  }];
}
```

### **Custom Validation**
```protobuf
message PaymentRequest {
  string card_number = 1;
  string expiry_month = 2;
  string expiry_year = 3;
  string cvv = 4;
  
  // Custom validation using validate.rules
  option (validate.rules).message.required = true;
}
```

---

## 📊 **Pagination & Filtering**

### **Pagination Pattern**
```protobuf
message ListRequest {
  // Pagination
  int32 page_size = 1 [(validate.rules).int32 = {gte: 1, lte: 100}];
  string page_token = 2;
  
  // Ordering
  string order_by = 3;  // "created_at desc", "name asc"
  
  // Filtering
  map<string, string> filter = 4;
}

message ListResponse {
  repeated items items = 1;
  
  // Pagination metadata
  int32 total_size = 2;
  string next_page_token = 3;
  bool has_next_page = 4;
}
```

### **Cursor-based Pagination**
```protobuf
message CursorPagination {
  string cursor = 1;
  int32 limit = 2 [(validate.rules).int32 = {gte: 1, lte: 100}];
  string order_by = 3;
}
```

---

## 🔄 **Streaming**

### **Server Streaming**
```protobuf
rpc StreamOrders(StreamOrdersRequest) returns (stream Order) {
  option (google.api.http) = {
    get: "/v1/orders:stream"
  };
}

message StreamOrdersRequest {
  string customer_id = 1;
  OrderStatus status_filter = 2;
  google.protobuf.Timestamp since = 3;
}
```

### **Client Streaming**
```protobuf
rpc BulkCreateOrders(stream CreateOrderRequest) returns (BulkCreateOrdersResponse) {}

message BulkCreateOrdersResponse {
  repeated Order created_orders = 1;
  repeated BulkError errors = 2;
  int32 total_processed = 3;
}
```

### **Bidirectional Streaming**
```protobuf
rpc OrderChat(stream OrderChatMessage) returns (stream OrderChatMessage) {}

message OrderChatMessage {
  oneof message {
    OrderRequest request = 1;
    OrderResponse response = 2;
    OrderUpdate update = 3;
  }
}
```

---

## 🔐 **Authentication & Security**

### **JWT Interceptor**
```go
// Server-side authentication
func authInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    metadata, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return nil, status.Error(codes.Unauthenticated, "missing metadata")
    }
    
    tokens := metadata.Get("authorization")
    if len(tokens) == 0 {
        return nil, status.Error(codes.Unauthenticated, "missing authorization token")
    }
    
    // Validate JWT token
    claims, err := validateJWT(tokens[0])
    if err != nil {
        return nil, status.Error(codes.Unauthenticated, "invalid token")
    }
    
    // Add user context
    ctx = context.WithValue(ctx, "user_id", claims.UserID)
    ctx = context.WithValue(ctx, "roles", claims.Roles)
    
    return handler(ctx, req)
}
```

### **TLS Configuration**
```go
// Server TLS setup
creds, err := credentials.NewServerTLSFromFile("server.crt", "server.key")
if err != nil {
    log.Fatal(err)
}

server := grpc.NewServer(
    grpc.Creds(creds),
    grpc.UnaryInterceptor(authInterceptor),
    grpc.StreamInterceptor(streamAuthInterceptor),
)
```

---

## 📈 **Performance Optimization**

### **Connection Pooling**
```go
// Client connection pool
func NewGRPCClientPool(address string, size int) []*grpc.ClientConn {
    pool := make([]*grpc.ClientConn, size)
    for i := 0; i < size; i++ {
        conn, err := grpc.Dial(address,
            grpc.WithInsecure(),
            grpc.WithKeepaliveParams(keepalive.ClientParameters{
                Time:                10 * time.Second,
                Timeout:             3 * time.Second,
                PermitWithoutStream: true,
            }),
        )
        if err != nil {
            log.Fatal(err)
        }
        pool[i] = conn
    }
    return pool
}
```

### **Compression**
```go
// Enable compression
server := grpc.NewServer(
    grpc.RPCCompressor(grpc.NewGZIPCompressor()),
    grpc.RPCDecompressor(grpc.NewGZIPDecompressor()),
)
```

---

## 🧪 **Testing**

### **Unit Tests**
```go
func TestOrderService_CreateOrder(t *testing.T) {
    // Setup
    service := NewOrderService(mockRepo)
    
    // Test request
    req := &pb.CreateOrderRequest{
        CustomerId: "cust_123",
        Items: []*pb.OrderItem{
            {
                ProductId: "prod_456",
                Quantity:  2,
                Price:     &pb.Money{Units: 29, Nanos: 990000000},
            },
        },
    }
    
    // Execute
    resp, err := service.CreateOrder(context.Background(), req)
    
    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, resp.Order)
    assert.Equal(t, "cust_123", resp.Order.CustomerId)
}
```

### **Integration Tests**
```go
func TestOrderService_Integration(t *testing.T) {
    // Setup test server
    server := grpc.NewServer()
    pb.RegisterOrderServiceServer(server, &orderService)
    
    lis, err := net.Listen("tcp", ":0")
    require.NoError(t, err)
    
    go server.Serve(lis)
    defer server.Stop()
    
    // Create client
    conn, err := grpc.Dial(lis.Addr().String(), grpc.WithInsecure())
    require.NoError(t, err)
    defer conn.Close()
    
    client := pb.NewOrderServiceClient(conn)
    
    // Test
    resp, err := client.CreateOrder(context.Background(), testReq)
    assert.NoError(t, err)
    assert.NotNil(t, resp.Order)
}
```

---

## 📚 **Code Generation**

### **Generate Go Code**
```bash
# Generate gRPC and gateway code
protoc \
  --go_out=. --go_opt=paths=source_relative \
  --go-grpc_out=. --go-grpc_opt=paths=source_relative \
  --grpc-gateway_out=. --grpc-gateway_opt=paths=source_relative \
  --validate_out=. --validate_opt=paths=source_relative \
  api/service_name/v1/service_name.proto
```

### **Generate Client SDKs**
```bash
# Generate TypeScript client
protoc \
  --plugin=protoc-gen-ts=./node_modules/.bin/protoc-gen-ts \
  --ts_out=grpc-js:./generated \
  api/service_name/v1/service_name.proto

# Generate Python client
python -m grpc_tools.protoc \
  --python_out=. \
  --grpc_python_out=. \
  api/service_name/v1/service_name.proto
```

---

## 🔗 **Related Documentation**

- **[API Standards](api-standards.md)** - General API design standards
- **[OpenAPI Specifications](openapi/)** - REST API specifications
- **[Event Schemas](event-schemas/)** - Event-driven API contracts
- **[Architecture](../01-architecture/)** - System architecture patterns

---

## 📋 **Checklist**

### **Before Implementation**
- [ ] Service name follows PascalCase convention
- [ ] Proto file includes proper imports
- [ ] Go package option is correctly set
- [ ] Field validation rules are defined
- [ ] Error handling strategy is planned

### **During Implementation**
- [ ] All RPC methods have proper request/response types
- [ ] Required fields use validation rules
- [ ] Timestamps use google.protobuf.Timestamp
- [ ] Monetary values use Money message type
- [ ] Pagination follows standard pattern

### **After Implementation**
- [ ] Code generation runs without errors
- [ ] Unit tests cover all RPC methods
- [ ] Integration tests validate end-to-end flow
- [ ] Documentation is updated
- [ ] Performance benchmarks meet requirements

---

**Last Updated**: February 2, 2026  
**Maintained By**: gRPC Team & Service Owners
