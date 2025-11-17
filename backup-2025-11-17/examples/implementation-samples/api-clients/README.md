# API Client Libraries

## Overview
Generated API client libraries for consuming microservices APIs in different programming languages. These clients provide type-safe, consistent interfaces for service communication.

## Available Clients

### 1. JavaScript/TypeScript Client
- **Framework**: Axios-based HTTP client
- **Features**: TypeScript definitions, automatic retry, error handling
- **Usage**: Frontend applications, Node.js services
- **Authentication**: JWT token support

### 2. Python Client
- **Framework**: httpx-based async client
- **Features**: Type hints, async/await support, retry logic
- **Usage**: Python services, data processing scripts
- **Authentication**: JWT and API key support

### 3. Java Client
- **Framework**: OkHttp-based client
- **Features**: Reactive streams, circuit breaker, metrics
- **Usage**: Java Spring Boot services
- **Authentication**: JWT token and OAuth2 support

### 4. Go Client
- **Framework**: Native net/http with enhancements
- **Features**: Context support, connection pooling, tracing
- **Usage**: Go microservices
- **Authentication**: JWT token support

## Client Structure

Each client library includes:
```
language-client/
├── src/                           # Source code
│   ├── clients/                   # Service-specific clients
│   │   ├── catalog-client.ts
│   │   ├── order-client.ts
│   │   └── payment-client.ts
│   ├── models/                    # Data models/types
│   │   ├── product.model.ts
│   │   ├── order.model.ts
│   │   └── common.model.ts
│   ├── auth/                      # Authentication handlers
│   │   ├── jwt-auth.ts
│   │   └── api-key-auth.ts
│   ├── interceptors/              # Request/response interceptors
│   │   ├── retry.interceptor.ts
│   │   ├── logging.interceptor.ts
│   │   └── metrics.interceptor.ts
│   ├── utils/                     # Utility functions
│   │   ├── http-client.ts
│   │   ├── error-handler.ts
│   │   └── config.ts
│   └── index.ts                   # Main export
├── tests/                         # Test files
├── examples/                      # Usage examples
├── docs/                          # Documentation
├── scripts/                       # Generation scripts
│   └── generate.sh
├── package.json|requirements.txt|pom.xml|go.mod
└── README.md
```

## JavaScript/TypeScript Client

### Installation
```bash
npm install @ecommerce/api-client
```

### Usage Example
```typescript
import { 
  CatalogClient, 
  OrderClient, 
  PaymentClient,
  ApiClientConfig 
} from '@ecommerce/api-client';

// Configure client
const config: ApiClientConfig = {
  baseURL: 'https://api.ecommerce.com',
  timeout: 30000,
  retries: 3,
  auth: {
    type: 'jwt',
    token: 'your-jwt-token'
  }
};

// Initialize clients
const catalogClient = new CatalogClient(config);
const orderClient = new OrderClient(config);
const paymentClient = new PaymentClient(config);

// Use catalog client
async function getProduct(productId: string) {
  try {
    const product = await catalogClient.getProduct(productId);
    console.log('Product:', product);
    return product;
  } catch (error) {
    console.error('Failed to get product:', error);
    throw error;
  }
}

// Use order client
async function createOrder(orderData: CreateOrderRequest) {
  try {
    const order = await orderClient.createOrder(orderData);
    console.log('Order created:', order);
    return order;
  } catch (error) {
    console.error('Failed to create order:', error);
    throw error;
  }
}

// Use payment client
async function processPayment(paymentData: ProcessPaymentRequest) {
  try {
    const result = await paymentClient.processPayment(paymentData);
    console.log('Payment processed:', result);
    return result;
  } catch (error) {
    console.error('Payment failed:', error);
    throw error;
  }
}
```

### Catalog Client Implementation
```typescript
// src/clients/catalog-client.ts
import { BaseClient } from '../utils/base-client';
import { 
  Product, 
  ProductListResponse, 
  CreateProductRequest,
  UpdateProductRequest,
  ProductQuery 
} from '../models/product.model';

export class CatalogClient extends BaseClient {
  private readonly basePath = '/api/v1/products';

  async getProducts(query?: ProductQuery): Promise<ProductListResponse> {
    return this.get<ProductListResponse>(this.basePath, { params: query });
  }

  async getProduct(id: string, customerId?: string): Promise<Product> {
    const params = customerId ? { customerId } : undefined;
    return this.get<Product>(`${this.basePath}/${id}`, { params });
  }

  async createProduct(data: CreateProductRequest): Promise<Product> {
    return this.post<Product>(this.basePath, data);
  }

  async updateProduct(id: string, data: UpdateProductRequest): Promise<Product> {
    return this.put<Product>(`${this.basePath}/${id}`, data);
  }

  async deleteProduct(id: string): Promise<void> {
    return this.delete(`${this.basePath}/${id}`);
  }

  async searchProducts(query: string, filters?: Record<string, any>): Promise<ProductListResponse> {
    return this.get<ProductListResponse>(`${this.basePath}/search`, {
      params: { q: query, ...filters }
    });
  }
}
```

### Base Client with Retry Logic
```typescript
// src/utils/base-client.ts
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios';
import { ApiClientConfig, ApiError } from '../models/common.model';
import { RetryInterceptor } from '../interceptors/retry.interceptor';
import { LoggingInterceptor } from '../interceptors/logging.interceptor';
import { MetricsInterceptor } from '../interceptors/metrics.interceptor';

export abstract class BaseClient {
  protected client: AxiosInstance;

  constructor(config: ApiClientConfig) {
    this.client = axios.create({
      baseURL: config.baseURL,
      timeout: config.timeout || 30000,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': `ecommerce-api-client/${config.version || '1.0.0'}`,
      },
    });

    // Add interceptors
    this.setupInterceptors(config);
  }

  private setupInterceptors(config: ApiClientConfig) {
    // Request interceptors
    this.client.interceptors.request.use(
      (request) => {
        // Add authentication
        if (config.auth?.type === 'jwt' && config.auth.token) {
          request.headers.Authorization = `Bearer ${config.auth.token}`;
        } else if (config.auth?.type === 'api-key' && config.auth.apiKey) {
          request.headers['X-API-Key'] = config.auth.apiKey;
        }

        return request;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptors
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        const apiError: ApiError = {
          message: error.message,
          status: error.response?.status,
          code: error.response?.data?.code,
          details: error.response?.data?.details,
        };
        return Promise.reject(apiError);
      }
    );

    // Add retry interceptor
    if (config.retries && config.retries > 0) {
      new RetryInterceptor(this.client, config.retries);
    }

    // Add logging interceptor
    if (config.logging) {
      new LoggingInterceptor(this.client);
    }

    // Add metrics interceptor
    if (config.metrics) {
      new MetricsInterceptor(this.client);
    }
  }

  protected async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.get<T>(url, config);
    return response.data;
  }

  protected async post<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.post<T>(url, data, config);
    return response.data;
  }

  protected async put<T>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.put<T>(url, data, config);
    return response.data;
  }

  protected async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.delete<T>(url, config);
    return response.data;
  }
}
```

## Python Client

### Installation
```bash
pip install ecommerce-api-client
```

### Usage Example
```python
import asyncio
from ecommerce_api_client import CatalogClient, OrderClient, PaymentClient, ApiClientConfig

# Configure client
config = ApiClientConfig(
    base_url="https://api.ecommerce.com",
    timeout=30.0,
    retries=3,
    auth={
        "type": "jwt",
        "token": "your-jwt-token"
    }
)

# Initialize clients
catalog_client = CatalogClient(config)
order_client = OrderClient(config)
payment_client = PaymentClient(config)

async def main():
    # Get product
    try:
        product = await catalog_client.get_product("prod-123")
        print(f"Product: {product}")
    except Exception as error:
        print(f"Failed to get product: {error}")

    # Create order
    try:
        order_data = {
            "customer_id": "cust-456",
            "items": [
                {
                    "product_id": "prod-123",
                    "quantity": 2,
                    "price": 29.99
                }
            ]
        }
        order = await order_client.create_order(order_data)
        print(f"Order created: {order}")
    except Exception as error:
        print(f"Failed to create order: {error}")

    # Process payment
    try:
        payment_data = {
            "order_id": order["id"],
            "amount": 59.98,
            "payment_method": "credit_card",
            "card_token": "card-token-123"
        }
        result = await payment_client.process_payment(payment_data)
        print(f"Payment processed: {result}")
    except Exception as error:
        print(f"Payment failed: {error}")

if __name__ == "__main__":
    asyncio.run(main())
```

### Python Catalog Client
```python
# src/clients/catalog_client.py
from typing import Optional, Dict, Any, List
from ..utils.base_client import BaseClient
from ..models.product import Product, ProductListResponse, CreateProductRequest, UpdateProductRequest

class CatalogClient(BaseClient):
    def __init__(self, config):
        super().__init__(config)
        self.base_path = "/api/v1/products"

    async def get_products(self, query: Optional[Dict[str, Any]] = None) -> ProductListResponse:
        """Get list of products with optional filtering"""
        return await self.get(self.base_path, params=query)

    async def get_product(self, product_id: str, customer_id: Optional[str] = None) -> Product:
        """Get product by ID with optional customer context"""
        params = {"customer_id": customer_id} if customer_id else None
        return await self.get(f"{self.base_path}/{product_id}", params=params)

    async def create_product(self, data: CreateProductRequest) -> Product:
        """Create new product"""
        return await self.post(self.base_path, data)

    async def update_product(self, product_id: str, data: UpdateProductRequest) -> Product:
        """Update existing product"""
        return await self.put(f"{self.base_path}/{product_id}", data)

    async def delete_product(self, product_id: str) -> None:
        """Delete product"""
        await self.delete(f"{self.base_path}/{product_id}")

    async def search_products(self, query: str, filters: Optional[Dict[str, Any]] = None) -> ProductListResponse:
        """Search products with query and filters"""
        params = {"q": query}
        if filters:
            params.update(filters)
        return await self.get(f"{self.base_path}/search", params=params)
```

## Java Client

### Maven Dependency
```xml
<dependency>
    <groupId>com.ecommerce</groupId>
    <artifactId>api-client</artifactId>
    <version>1.0.0</version>
</dependency>
```

### Usage Example
```java
import com.ecommerce.client.CatalogClient;
import com.ecommerce.client.OrderClient;
import com.ecommerce.client.PaymentClient;
import com.ecommerce.client.config.ApiClientConfig;
import com.ecommerce.client.model.*;

public class EcommerceClientExample {
    public static void main(String[] args) {
        // Configure client
        ApiClientConfig config = ApiClientConfig.builder()
            .baseUrl("https://api.ecommerce.com")
            .timeout(Duration.ofSeconds(30))
            .retries(3)
            .auth(JwtAuth.builder().token("your-jwt-token").build())
            .build();

        // Initialize clients
        CatalogClient catalogClient = new CatalogClient(config);
        OrderClient orderClient = new OrderClient(config);
        PaymentClient paymentClient = new PaymentClient(config);

        try {
            // Get product
            Product product = catalogClient.getProduct("prod-123").block();
            System.out.println("Product: " + product);

            // Create order
            CreateOrderRequest orderData = CreateOrderRequest.builder()
                .customerId("cust-456")
                .items(List.of(
                    OrderItem.builder()
                        .productId("prod-123")
                        .quantity(2)
                        .price(new BigDecimal("29.99"))
                        .build()
                ))
                .build();
            
            Order order = orderClient.createOrder(orderData).block();
            System.out.println("Order created: " + order);

            // Process payment
            ProcessPaymentRequest paymentData = ProcessPaymentRequest.builder()
                .orderId(order.getId())
                .amount(new BigDecimal("59.98"))
                .paymentMethod("credit_card")
                .cardToken("card-token-123")
                .build();
            
            PaymentResult result = paymentClient.processPayment(paymentData).block();
            System.out.println("Payment processed: " + result);

        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
        }
    }
}
```

## Go Client

### Installation
```bash
go get github.com/ecommerce/api-client-go
```

### Usage Example
```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"

    "github.com/ecommerce/api-client-go/client"
    "github.com/ecommerce/api-client-go/config"
    "github.com/ecommerce/api-client-go/models"
)

func main() {
    // Configure client
    cfg := &config.ApiClientConfig{
        BaseURL: "https://api.ecommerce.com",
        Timeout: 30 * time.Second,
        Retries: 3,
        Auth: &config.JwtAuth{
            Token: "your-jwt-token",
        },
    }

    // Initialize clients
    catalogClient := client.NewCatalogClient(cfg)
    orderClient := client.NewOrderClient(cfg)
    paymentClient := client.NewPaymentClient(cfg)

    ctx := context.Background()

    // Get product
    product, err := catalogClient.GetProduct(ctx, "prod-123", nil)
    if err != nil {
        log.Printf("Failed to get product: %v", err)
        return
    }
    fmt.Printf("Product: %+v\n", product)

    // Create order
    orderData := &models.CreateOrderRequest{
        CustomerID: "cust-456",
        Items: []models.OrderItem{
            {
                ProductID: "prod-123",
                Quantity:  2,
                Price:     29.99,
            },
        },
    }

    order, err := orderClient.CreateOrder(ctx, orderData)
    if err != nil {
        log.Printf("Failed to create order: %v", err)
        return
    }
    fmt.Printf("Order created: %+v\n", order)

    // Process payment
    paymentData := &models.ProcessPaymentRequest{
        OrderID:       order.ID,
        Amount:        59.98,
        PaymentMethod: "credit_card",
        CardToken:     "card-token-123",
    }

    result, err := paymentClient.ProcessPayment(ctx, paymentData)
    if err != nil {
        log.Printf("Payment failed: %v", err)
        return
    }
    fmt.Printf("Payment processed: %+v\n", result)
}
```

## Client Generation

### Generate All Clients
```bash
# Generate from OpenAPI specs
./scripts/generate-all-clients.sh

# Generate specific client
./scripts/generate-client.sh typescript catalog-service
./scripts/generate-client.sh python order-service
./scripts/generate-client.sh java payment-service
./scripts/generate-client.sh go customer-service
```

### Generation Script Example
```bash
#!/bin/bash
# scripts/generate-client.sh

LANGUAGE=$1
SERVICE=$2

if [ -z "$LANGUAGE" ] || [ -z "$SERVICE" ]; then
    echo "Usage: $0 <language> <service>"
    echo "Languages: typescript, python, java, go"
    echo "Services: catalog-service, order-service, payment-service, etc."
    exit 1
fi

# Download OpenAPI spec
curl -s "https://api.ecommerce.com/${SERVICE}/openapi.json" > "/tmp/${SERVICE}-openapi.json"

# Generate client based on language
case $LANGUAGE in
    "typescript")
        npx @openapitools/openapi-generator-cli generate \
            -i "/tmp/${SERVICE}-openapi.json" \
            -g typescript-axios \
            -o "./javascript/src/clients/${SERVICE}" \
            --additional-properties=npmName="@ecommerce/${SERVICE}-client"
        ;;
    "python")
        openapi-generator generate \
            -i "/tmp/${SERVICE}-openapi.json" \
            -g python \
            -o "./python/src/clients/${SERVICE}" \
            --additional-properties=packageName="ecommerce_${SERVICE//-/_}_client"
        ;;
    "java")
        openapi-generator generate \
            -i "/tmp/${SERVICE}-openapi.json" \
            -g java \
            -o "./java/src/main/java/com/ecommerce/client/${SERVICE}" \
            --additional-properties=groupId="com.ecommerce",artifactId="${SERVICE}-client"
        ;;
    "go")
        openapi-generator generate \
            -i "/tmp/${SERVICE}-openapi.json" \
            -g go \
            -o "./go/clients/${SERVICE}" \
            --additional-properties=packageName="${SERVICE//-/}"
        ;;
    *)
        echo "Unsupported language: $LANGUAGE"
        exit 1
        ;;
esac

echo "Client generated for $SERVICE in $LANGUAGE"
```

## Features

### Common Features Across All Clients
- **Type Safety**: Strong typing for all API models and responses
- **Authentication**: JWT token and API key support
- **Retry Logic**: Configurable retry with exponential backoff
- **Error Handling**: Structured error responses with proper error types
- **Logging**: Request/response logging with correlation IDs
- **Metrics**: Client-side metrics collection
- **Circuit Breaker**: Fail-fast pattern for resilience
- **Connection Pooling**: Efficient connection management
- **Timeout Management**: Configurable timeouts per request
- **Caching**: Optional response caching
- **Rate Limiting**: Client-side rate limiting
- **Tracing**: Distributed tracing support

### Language-Specific Features
- **TypeScript**: Full IntelliSense support, async/await
- **Python**: Type hints, async/await, context managers
- **Java**: Reactive streams, Spring integration, metrics
- **Go**: Context support, channels, goroutine-safe

### Dart/Flutter Client

### Installation
```yaml
dependencies:
  ecommerce_api_client: ^1.0.0
```

### Usage Example
```dart
import 'package:ecommerce_api_client/ecommerce_api_client.dart';

void main() async {
  // Configure client
  final config = ApiClientConfig(
    baseUrl: 'https://api.ecommerce.com',
    timeout: Duration(seconds: 30),
    retries: 3,
    auth: JwtAuth(token: 'your-jwt-token'),
  );

  // Initialize clients
  final catalogClient = CatalogClient(config);
  final orderClient = OrderClient(config);
  final paymentClient = PaymentClient(config);

  try {
    // Get product
    final product = await catalogClient.getProduct('prod-123');
    print('Product: $product');

    // Create order
    final orderData = CreateOrderRequest(
      customerId: 'cust-456',
      items: [
        OrderItem(
          productId: 'prod-123',
          quantity: 2,
          price: 29.99,
        ),
      ],
    );

    final order = await orderClient.createOrder(orderData);
    print('Order created: $order');

    // Process payment
    final paymentData = ProcessPaymentRequest(
      orderId: order.id,
      amount: 59.98,
      paymentMethod: 'credit_card',
      cardToken: 'card-token-123',
    );

    final result = await paymentClient.processPayment(paymentData);
    print('Payment processed: $result');

  } catch (e) {
    print('Error: $e');
  }
}
```

### Dart Catalog Client Implementation
```dart
// lib/src/clients/catalog_client.dart
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../models/product_list_response.dart';
import '../utils/base_client.dart';

class CatalogClient extends BaseClient {
  CatalogClient(super.config);

  static const String _basePath = '/api/v1/products';

  Future<ProductListResponse> getProducts({
    int page = 1,
    int limit = 10,
    String? search,
    String? category,
  }) async {
    final response = await get<Map<String, dynamic>>(
      _basePath,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null) 'search': search,
        if (category != null) 'category': category,
      },
    );

    return ProductListResponse.fromJson(response);
  }

  Future<Product> getProduct(String id, {String? customerId}) async {
    final response = await get<Map<String, dynamic>>(
      '$_basePath/$id',
      queryParameters: {
        if (customerId != null) 'customer_id': customerId,
      },
    );

    return Product.fromJson(response['data']);
  }

  Future<Product> createProduct(CreateProductRequest request) async {
    final response = await post<Map<String, dynamic>>(
      _basePath,
      data: request.toJson(),
    );

    return Product.fromJson(response['data']);
  }

  Future<Product> updateProduct(String id, UpdateProductRequest request) async {
    final response = await put<Map<String, dynamic>>(
      '$_basePath/$id',
      data: request.toJson(),
    );

    return Product.fromJson(response['data']);
  }

  Future<void> deleteProduct(String id) async {
    await delete('$_basePath/$id');
  }

  Future<ProductListResponse> searchProducts(
    String query, {
    Map<String, dynamic>? filters,
  }) async {
    final response = await get<Map<String, dynamic>>(
      '$_basePath/search',
      queryParameters: {
        'q': query,
        if (filters != null) ...filters,
      },
    );

    return ProductListResponse.fromJson(response);
  }
}
```

These API clients provide a consistent, reliable way to interact with the e-commerce microservices from any application or service, including mobile apps built with Flutter.