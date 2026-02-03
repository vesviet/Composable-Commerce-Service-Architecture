# Testing Guide

**Purpose**: Comprehensive testing standards and practices for microservices  
**Audience**: All developers, QA engineers, tech leads  

---

## 🎯 Testing Philosophy

Our testing strategy ensures:
- **Quality**: High code quality and reliability
- **Confidence**: Safe deployments and changes
- **Speed**: Fast feedback and iteration
- **Maintainability**: Easy to understand and maintain tests
- **Coverage**: Comprehensive test coverage

---

## 📋 Testing Pyramid

```
    /\
   /E2E\     <- Few, slow, high-value tests
  /______\
 /Integration\ <- Moderate number, medium speed
/______________\
/   Unit Tests   \ <- Many, fast, foundational
/________________\
```

### **Unit Tests (70%)**
- **Purpose**: Test individual functions and methods
- **Speed**: Fast (< 1 second per test)
- **Isolation**: No external dependencies
- **Coverage**: 80%+ of business logic

### **Integration Tests (20%)**
- **Purpose**: Test component interactions
- **Speed**: Medium (1-10 seconds per test)
- **Dependencies**: Real databases, external services
- **Coverage**: Critical integration paths

### **End-to-End Tests (10%)**
- **Purpose**: Test complete user workflows
- **Speed**: Slow (10-60 seconds per test)
- **Environment**: Production-like setup
- **Coverage**: Critical business workflows

---

## 🧪 Unit Testing

### **Standards & Best Practices**

#### **Test Structure**
```go
package service

import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    "github.com/stretchr/testify/require"
)

func TestUserService_CreateUser(t *testing.T) {
    // Arrange
    tests := []struct {
        name        string
        input       *CreateUserRequest
        setupMocks  func(*MockRepository)
        want        *User
        wantErr     error
    }{
        {
            name:  "valid user creation",
            input: &CreateUserRequest{Name: "John", Email: "john@example.com"},
            setupMocks: func(m *MockRepository) {
                m.EXPECT().CreateUser(gomock.Any()).Return(&User{ID: "123", Name: "John"}, nil)
            },
            want: &User{ID: "123", Name: "John"},
        },
        {
            name:  "duplicate email",
            input: &CreateUserRequest{Name: "John", Email: "john@example.com"},
            setupMocks: func(m *MockRepository) {
                m.EXPECT().CreateUser(gomock.Any()).Return(nil, ErrDuplicateEmail)
            },
            wantErr: ErrDuplicateEmail,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()
            
            mockRepo := NewMockRepository(ctrl)
            tt.setupMocks(mockRepo)
            
            service := NewUserService(mockRepo)
            
            // Act
            got, err := service.CreateUser(tt.input)
            
            // Assert
            if tt.wantErr != nil {
                assert.Error(t, err)
                assert.Equal(t, tt.wantErr, err)
            } else {
                assert.NoError(t, err)
                assert.Equal(t, tt.want, got)
            }
        })
    }
}
```

#### **Test Naming Convention**
```go
// Format: Test[FunctionName]_[Scenario]_[ExpectedResult]
func TestUserService_CreateUser_ValidInput_ReturnsUser(t *testing.T)
func TestUserService_CreateUser_DuplicateEmail_ReturnsError(t *testing.T)
func TestUserService_CreateUser_EmptyName_ReturnsValidationError(t *testing.T)
```

#### **Assertion Guidelines**
```go
// Use require for fatal assertions (stops test on failure)
require.NoError(t, err)
require.NotNil(t, result)

// Use assert for non-fatal assertions (continues test)
assert.Equal(t, expected, actual)
assert.True(t, condition)
assert.Contains(t, slice, item)
```

### **Mocking & Test Doubles**

#### **Using Testify Mock**
```go
//go:generate mockgen -source=repository.go -destination=mocks/repository_mock.go

type MockRepository struct {
    mock.Mock
}

func (m *MockRepository) CreateUser(user *User) error {
    args := m.Called(user)
    return args.Error(0)
}
```

#### **Using Test Doubles**
```go
// In-memory implementation for testing
type InMemoryUserRepository struct {
    users map[string]*User
}

func (r *InMemoryUserRepository) CreateUser(user *User) error {
    if _, exists := r.users[user.Email]; exists {
        return ErrDuplicateEmail
    }
    r.users[user.Email] = user
    return nil
}
```

---

## 🔗 Integration Testing

### **Database Integration**

#### **Test Database Setup**
```go
package integration

import (
    "database/sql"
    "testing"
    "github.com/ory/dockertest"
    _ "github.com/lib/pq"
)

func setupTestDB(t *testing.T) *sql.DB {
    pool, err := dockertest.NewPool("")
    require.NoError(t, err)

    resource, err := pool.Run("postgres", "15-alpine", []string{
        "POSTGRES_PASSWORD=postgres",
        "POSTGRES_DB=testdb",
    })
    require.NoError(t, err)
    t.Cleanup(func() {
        resource.Close()
    })

    var db *sql.DB
    err = pool.Retry(func() error {
        var err error
        db, err = sql.Open("postgres", 
            "postgres://postgres:postgres@localhost:"+resource.GetPort("5432/tcp")+"/testdb?sslmode=disable")
        if err != nil {
            return err
        }
        return db.Ping()
    })
    require.NoError(t, err)

    // Run migrations
    err = runMigrations(db)
    require.NoError(t, err)

    return db
}
```

#### **Repository Integration Tests**
```go
func TestUserRepository_CreateUser_Integration(t *testing.T) {
    db := setupTestDB(t)
    defer db.Close()

    repo := NewUserRepository(db)
    
    user := &User{
        Name:  "Test User",
        Email: "test@example.com",
    }

    err := repo.CreateUser(user)
    require.NoError(t, err)
    assert.NotEmpty(t, user.ID)

    // Verify user was created
    found, err := repo.GetUserByID(user.ID)
    require.NoError(t, err)
    assert.Equal(t, user.Name, found.Name)
    assert.Equal(t, user.Email, found.Email)
}
```

### **Service Integration**

#### **HTTP API Testing**
```go
func TestUserService_CreateUser_API_Integration(t *testing.T) {
    // Setup test server
    db := setupTestDB(t)
    defer db.Close()

    userRepo := NewUserRepository(db)
    userService := NewUserService(userRepo)
    
    server := httptest.NewServer(NewUserHandler(userService))
    defer server.Close()

    // Test API call
    payload := map[string]interface{}{
        "name":  "Test User",
        "email": "test@example.com",
    }

    resp, err := http.Post(
        server.URL+"/users",
        "application/json",
        bytes.NewBuffer(mustMarshalJSON(t, payload)),
    )
    require.NoError(t, err)
    defer resp.Body.Close()

    assert.Equal(t, http.StatusCreated, resp.StatusCode)

    var response map[string]interface{}
    err = json.NewDecoder(resp.Body).Decode(&response)
    require.NoError(t, err)
    
    assert.Equal(t, "Test User", response["name"])
    assert.Equal(t, "test@example.com", response["email"])
}
```

---

## 🌐 End-to-End Testing

### **E2E Test Framework**

#### **Test Setup**
```go
package e2e

import (
    "context"
    "testing"
    "time"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/wait"
)

type E2ETestSuite struct {
    ctx      context.Context
    cancel   context.CancelFunc
    services map[string]testcontainers.Container
    clients  map[string]*http.Client
}

func NewE2ETestSuite(t *testing.T) *E2ETestSuite {
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
    
    suite := &E2ETestSuite{
        ctx:      ctx,
        cancel:   cancel,
        services: make(map[string]testcontainers.Container),
        clients:  make(map[string]*http.Client),
    }
    
    // Setup all services
    suite.setupServices(t)
    
    t.Cleanup(func() {
        suite.cleanup()
    })
    
    return suite
}
```

#### **User Journey Tests**
```go
func TestE2E_UserRegistrationAndLogin(t *testing.T) {
    suite := NewE2ETestSuite(t)
    
    // Step 1: Register user
    registerReq := map[string]interface{}{
        "name":     "John Doe",
        "email":    "john@example.com",
        "password": "securePassword123",
    }
    
    resp := suite.makeRequest(t, "POST", "/auth/register", registerReq)
    assert.Equal(t, http.StatusCreated, resp.StatusCode)
    
    var registerResp map[string]interface{}
    json.NewDecoder(resp.Body).Decode(&registerResp)
    userID := registerResp["user_id"].(string)
    
    // Step 2: Login with credentials
    loginReq := map[string]interface{}{
        "email":    "john@example.com",
        "password": "securePassword123",
    }
    
    resp = suite.makeRequest(t, "POST", "/auth/login", loginReq)
    assert.Equal(t, http.StatusOK, resp.StatusCode)
    
    var loginResp map[string]interface{}
    json.NewDecoder(resp.Body).Decode(&loginResp)
    token := loginResp["token"].(string)
    
    // Step 3: Access protected resource
    headers := map[string]string{
        "Authorization": "Bearer " + token,
    }
    
    resp = suite.makeRequestWithHeaders(t, "GET", "/users/"+userID, nil, headers)
    assert.Equal(t, http.StatusOK, resp.StatusCode)
    
    var userResp map[string]interface{}
    json.NewDecoder(resp.Body).Decode(&userResp)
    assert.Equal(t, "John Doe", userResp["name"])
    assert.Equal(t, "john@example.com", userResp["email"])
}
```

---

## 🔧 Testing Tools & Frameworks

### **Core Testing Libraries**
```go
// go.mod testing dependencies
require (
    github.com/stretchr/testify v1.8.4
    github.com/golang/mock v1.6.0
    github.com/ory/dockertest v3.10.0+incompatible
    github.com/testcontainers/testcontainers-go v0.25.0
    github.com/gavv/httpexpect/v2 v2.15.0
)
```

### **Testing Utilities**

#### **Test Helpers**
```go
package testutils

import (
    "testing"
    "github.com/stretchr/testify/require"
)

// MustMarshalJSON marshals JSON and fails test on error
func MustMarshalJSON(t *testing.T, v interface{}) []byte {
    data, err := json.Marshal(v)
    require.NoError(t, err)
    return data
}

// MustUnmarshalJSON unmarshals JSON and fails test on error
func MustUnmarshalJSON(t *testing.T, data []byte, v interface{}) {
    err := json.Unmarshal(data, v)
    require.NoError(t, err)
}

// AssertHTTPError asserts HTTP error response
func AssertHTTPError(t *testing.T, resp *http.Response, expectedStatus int) {
    assert.Equal(t, expectedStatus, resp.StatusCode)
    
    var errorResp map[string]interface{}
    json.NewDecoder(resp.Body).Decode(&errorResp)
    assert.Contains(t, errorResp, "error")
}
```

#### **Test Data Factory**
```go
package factory

import (
    "github.com/brianvoe/gofakeit/v6"
    "gitlab.com/ta-microservices/common/types"
)

type UserFactory struct{}

func (f *UserFactory) Create() *types.User {
    return &types.User{
        ID:        gofakeit.UUID(),
        Name:      gofakeit.Name(),
        Email:     gofakeit.Email(),
        CreatedAt: gofakeit.Date(),
        UpdatedAt: gofakeit.Date(),
    }
}

func (f *UserFactory) CreateWithEmail(email string) *types.User {
    user := f.Create()
    user.Email = email
    return user
}
```

---

## 📊 Test Coverage

### **Coverage Standards**
```bash
# Run tests with coverage
go test ./... -coverprofile=coverage.out

# Generate HTML coverage report
go tool cover -html=coverage.out -o coverage.html

# Check coverage by package
go test ./... -coverprofile=coverage.out
go tool cover -func=coverage.out
```

### **Coverage Requirements**
- **Business Logic**: 90%+ coverage
- **Service Layer**: 85%+ coverage
- **Repository Layer**: 80%+ coverage
- **Overall**: 80%+ coverage

### **Coverage Exclusions**
```go
//go:build !integration
// +build !integration

package main

// Exclude main functions from coverage
func main() {
    // Application entry point
}
```

---

## 🚀 Performance Testing

### **Load Testing with hey**
```bash
# Install hey
go install github.com/rakyll/hey@latest

# Run load test
hey -n 1000 -c 10 -m POST -d '{"name":"Test","email":"test@example.com"}' \
    -T "application/json" http://localhost:8001/users
```

### **Benchmark Testing**
```go
func BenchmarkUserService_CreateUser(b *testing.B) {
    service := setupUserService(b)
    req := &CreateUserRequest{Name: "Test", Email: "test@example.com"}
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, err := service.CreateUser(req)
        if err != nil {
            b.Fatal(err)
        }
    }
}
```

---

## 📋 Testing Checklist

### **Before Submitting Code**
- [ ] **Unit Tests**: All new functions have unit tests
- [ ] **Coverage**: Test coverage meets requirements
- [ ] **Integration Tests**: Critical paths tested
- [ ] **Edge Cases**: Error conditions tested
- [ ] **Mocking**: External dependencies mocked
- [ ] **Clean Tests**: Tests are independent and isolated

### **Before Release**
- [ ] **E2E Tests**: Critical user journeys tested
- [ ] **Performance Tests**: Load testing completed
- [ ] **Security Tests**: Security scenarios tested
- [ ] **Compatibility Tests**: Backward compatibility tested
- [ ] **Environment Tests**: Multiple environments tested

---

## 🔍 Test Organization

### **Directory Structure**
```
service/
├── internal/
│   ├── service/
│   │   ├── user_service.go
│   │   └── user_service_test.go      # Unit tests
│   ├── repository/
│   │   ├── user_repository.go
│   │   └── user_repository_test.go   # Unit tests
├── tests/
│   ├── integration/
│   │   ├── user_integration_test.go  # Integration tests
│   │   └── api_integration_test.go
│   ├── e2e/
│   │   └── user_journey_test.go      # E2E tests
│   └── testutils/
│       ├── factory.go                # Test factories
│       └── helpers.go                # Test helpers
```

---

## 🆘 Common Testing Issues

### **Test Isolation**
```go
// Bad: Tests sharing state
var globalUser *User

func TestA(t *testing.T) {
    globalUser = &User{Name: "Test"}
}

func TestB(t *testing.T) {
    // Depends on TestA running first
    assert.Equal(t, "Test", globalUser.Name)
}

// Good: Each test is isolated
func TestA(t *testing.T) {
    user := &User{Name: "Test"}
    assert.Equal(t, "Test", user.Name)
}

func TestB(t *testing.T) {
    user := &User{Name: "Another"}
    assert.Equal(t, "Another", user.Name)
}
```

### **Race Conditions**
```bash
# Run tests with race detector
go test ./... -race
```

### **Flaky Tests**
```go
// Use retry for flaky tests
func TestFlakyOperation(t *testing.T) {
    for i := 0; i < 3; i++ {
        t.Run(fmt.Sprintf("attempt_%d", i), func(t *testing.T) {
            if testOperation(t) {
                return // Success
            }
            t.Log("Attempt failed, retrying...")
        })
    }
}
```

---

**Last Updated**: February 3, 2026  
**Review Cycle**: Monthly or when testing practices change  
**Maintained By**: Development Team & QA Team
