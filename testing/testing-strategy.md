# Testing Strategy

## Testing Pyramid

### Testing Levels
```
┌─────────────────────────────────────────────────────────────┐
│                    Testing Pyramid                          │
├─────────────────────────────────────────────────────────────┤
│  E2E Tests (10%) - Full system integration                 │
│  Integration Tests (20%) - Service interactions            │
│  Unit Tests (70%) - Individual components                  │
└─────────────────────────────────────────────────────────────┘
```

## Unit Testing

### Testing Standards
- **Coverage Target**: 80% code coverage minimum
- **Test Framework**: Jest (Node.js), JUnit (Java), pytest (Python)
- **Mocking Strategy**: Mock external dependencies
- **Test Isolation**: Each test should be independent

### Example Unit Test Structure
```javascript
// Order Service Unit Test Example
describe('OrderService', () => {
  let orderService;
  let mockPricingService;
  let mockInventoryService;
  
  beforeEach(() => {
    mockPricingService = {
      calculatePrice: jest.fn()
    };
    mockInventoryService = {
      checkAvailability: jest.fn(),
      reserveStock: jest.fn()
    };
    
    orderService = new OrderService(mockPricingService, mockInventoryService);
  });
  
  describe('createOrder', () => {
    it('should create order successfully with valid data', async () => {
      // Arrange
      const orderData = {
        customerId: 'CUST-123',
        items: [{ productId: 'PROD-456', quantity: 2 }]
      };
      
      mockPricingService.calculatePrice.mockResolvedValue({ total: 299.99 });
      mockInventoryService.checkAvailability.mockResolvedValue(true);
      mockInventoryService.reserveStock.mockResolvedValue('RES-789');
      
      // Act
      const result = await orderService.createOrder(orderData);
      
      // Assert
      expect(result.orderId).toBeDefined();
      expect(result.status).toBe('CONFIRMED');
      expect(result.total).toBe(299.99);
      expect(mockInventoryService.reserveStock).toHaveBeenCalledWith(
        'PROD-456', 2
      );
    });
    
    it('should throw error when product is out of stock', async () => {
      // Arrange
      const orderData = {
        customerId: 'CUST-123',
        items: [{ productId: 'PROD-456', quantity: 2 }]
      };
      
      mockInventoryService.checkAvailability.mockResolvedValue(false);
      
      // Act & Assert
      await expect(orderService.createOrder(orderData))
        .rejects.toThrow('Product PROD-456 is out of stock');
    });
  });
});
```

## Integration Testing

### Service Integration Tests
```javascript
// Integration Test Example
describe('Order Creation Integration', () => {
  let testContainer;
  
  beforeAll(async () => {
    // Start test containers
    testContainer = await new GenericContainer('postgres:13')
      .withExposedPorts(5432)
      .withEnv('POSTGRES_DB', 'test_db')
      .withEnv('POSTGRES_USER', 'test_user')
      .withEnv('POSTGRES_PASSWORD', 'test_pass')
      .start();
      
    // Initialize test database
    await initializeTestDatabase();
  });
  
  afterAll(async () => {
    await testContainer.stop();
  });
  
  it('should create order with real database', async () => {
    // Test with actual database connection
    const orderService = new OrderService(realDatabaseConnection);
    const result = await orderService.createOrder(validOrderData);
    
    expect(result.orderId).toBeDefined();
    
    // Verify data was persisted
    const savedOrder = await orderService.getOrder(result.orderId);
    expect(savedOrder.status).toBe('CONFIRMED');
  });
});
```

### Contract Testing
```yaml
# Pact Contract Testing Example
consumer: order-service
provider: pricing-service

interactions:
  - description: "get product price"
    request:
      method: POST
      path: /pricing/calculate
      headers:
        Content-Type: application/json
      body:
        productId: "PROD-123"
        customerId: "CUST-456"
        warehouseId: "WH-789"
    response:
      status: 200
      headers:
        Content-Type: application/json
      body:
        finalPrice: 299.99
        currency: "USD"
        discounts:
          - type: "customer_tier"
            amount: 30.00
```

## End-to-End Testing

### E2E Test Scenarios
```javascript
// E2E Test using Playwright
describe('Complete Order Flow', () => {
  let page;
  
  beforeEach(async () => {
    page = await browser.newPage();
    await page.goto('http://localhost:3000');
  });
  
  it('should complete full order journey', async () => {
    // 1. Search for product
    await page.fill('[data-testid="search-input"]', 'wireless headphones');
    await page.click('[data-testid="search-button"]');
    
    // 2. Select product
    await page.click('[data-testid="product-card"]:first-child');
    
    // 3. Add to cart
    await page.click('[data-testid="add-to-cart"]');
    
    // 4. Go to checkout
    await page.click('[data-testid="cart-icon"]');
    await page.click('[data-testid="checkout-button"]');
    
    // 5. Fill shipping information
    await page.fill('[data-testid="shipping-address"]', '123 Test St');
    await page.fill('[data-testid="shipping-city"]', 'Test City');
    
    // 6. Select payment method
    await page.click('[data-testid="payment-card"]');
    await page.fill('[data-testid="card-number"]', '4111111111111111');
    
    // 7. Place order
    await page.click('[data-testid="place-order"]');
    
    // 8. Verify order confirmation
    await expect(page.locator('[data-testid="order-confirmation"]'))
      .toBeVisible();
    
    const orderNumber = await page.textContent('[data-testid="order-number"]');
    expect(orderNumber).toMatch(/ORD-\d+/);
  });
});
```

## Performance Testing

### Load Testing Strategy
```yaml
load_testing:
  tools: [k6, JMeter, Artillery]
  
  scenarios:
    normal_load:
      users: 100
      duration: 10m
      ramp_up: 2m
      
    peak_load:
      users: 500
      duration: 5m
      ramp_up: 1m
      
    stress_test:
      users: 1000
      duration: 15m
      ramp_up: 3m
      
    spike_test:
      users: 2000
      duration: 2m
      ramp_up: 30s
```

### Performance Test Example
```javascript
// k6 Performance Test
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 200 }, // Ramp up to 200
    { duration: '5m', target: 200 }, // Stay at 200 users
    { duration: '2m', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
    http_req_failed: ['rate<0.1'],    // Error rate under 10%
  },
};

export default function() {
  // Test product search
  let searchResponse = http.get('http://api.example.com/search?q=headphones');
  check(searchResponse, {
    'search status is 200': (r) => r.status === 200,
    'search response time < 200ms': (r) => r.timings.duration < 200,
  });
  
  // Test product details
  let productResponse = http.get('http://api.example.com/products/123');
  check(productResponse, {
    'product status is 200': (r) => r.status === 200,
    'product response time < 300ms': (r) => r.timings.duration < 300,
  });
  
  sleep(1);
}
```

## Security Testing

### Security Test Categories
```yaml
security_testing:
  static_analysis:
    tools: [SonarQube, Checkmarx, Veracode]
    frequency: "on every commit"
    
  dynamic_analysis:
    tools: [OWASP ZAP, Burp Suite]
    frequency: "weekly"
    
  dependency_scanning:
    tools: [Snyk, WhiteSource, npm audit]
    frequency: "daily"
    
  penetration_testing:
    frequency: "quarterly"
    scope: "full application"
```

### Security Test Examples
```javascript
// Security Test Example
describe('Security Tests', () => {
  it('should prevent SQL injection', async () => {
    const maliciousInput = "'; DROP TABLE users; --";
    
    const response = await request(app)
      .get(`/api/products?search=${maliciousInput}`)
      .expect(400);
      
    expect(response.body.error).toContain('Invalid input');
  });
  
  it('should require authentication for protected endpoints', async () => {
    await request(app)
      .post('/api/orders')
      .send(validOrderData)
      .expect(401);
  });
  
  it('should validate input parameters', async () => {
    const invalidOrder = {
      customerId: '', // Empty customer ID
      items: []       // Empty items array
    };
    
    await request(app)
      .post('/api/orders')
      .set('Authorization', 'Bearer valid-token')
      .send(invalidOrder)
      .expect(400);
  });
});
```

## Test Data Management

### Test Data Strategy
```yaml
test_data:
  approach: "data_builder_pattern"
  
  builders:
    customer_builder:
      default_values:
        name: "Test Customer"
        email: "test@example.com"
        status: "active"
      
    product_builder:
      default_values:
        name: "Test Product"
        price: 99.99
        category: "electronics"
        
    order_builder:
      default_values:
        status: "pending"
        currency: "USD"
```

### Test Data Builder Example
```javascript
class OrderBuilder {
  constructor() {
    this.order = {
      customerId: 'CUST-123',
      items: [],
      status: 'pending',
      currency: 'USD'
    };
  }
  
  withCustomer(customerId) {
    this.order.customerId = customerId;
    return this;
  }
  
  withItem(productId, quantity = 1, price = 99.99) {
    this.order.items.push({ productId, quantity, price });
    return this;
  }
  
  withStatus(status) {
    this.order.status = status;
    return this;
  }
  
  build() {
    return { ...this.order };
  }
}

// Usage in tests
const testOrder = new OrderBuilder()
  .withCustomer('CUST-456')
  .withItem('PROD-789', 2, 149.99)
  .withStatus('confirmed')
  .build();
```

## Test Environment Management

### Environment Configuration
```yaml
test_environments:
  unit_tests:
    database: "in-memory"
    external_services: "mocked"
    
  integration_tests:
    database: "test_database"
    external_services: "test_doubles"
    
  e2e_tests:
    database: "staging_database"
    external_services: "staging_services"
    
  performance_tests:
    database: "performance_database"
    external_services: "production_like"
```

### Test Automation Pipeline
```yaml
test_pipeline:
  triggers:
    - on_pull_request
    - on_merge_to_main
    - nightly_schedule
    
  stages:
    1_unit_tests:
      parallel: true
      timeout: 10m
      
    2_integration_tests:
      depends_on: unit_tests
      timeout: 20m
      
    3_contract_tests:
      depends_on: integration_tests
      timeout: 15m
      
    4_e2e_tests:
      depends_on: contract_tests
      timeout: 30m
      
    5_performance_tests:
      trigger: nightly
      timeout: 60m
```

## Quality Gates

### Test Quality Metrics
```yaml
quality_gates:
  unit_tests:
    coverage: ">= 80%"
    pass_rate: "100%"
    
  integration_tests:
    pass_rate: "100%"
    execution_time: "< 20 minutes"
    
  e2e_tests:
    pass_rate: ">= 95%"
    execution_time: "< 30 minutes"
    
  performance_tests:
    response_time_p95: "< 500ms"
    error_rate: "< 1%"
    throughput: ">= baseline"
```