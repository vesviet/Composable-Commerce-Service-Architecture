# First Contribution Guide

**Purpose**: Step-by-step guide for making your first code contribution  
**Audience**: New developers, developers new to the codebase  
**Prerequisites**: Completed [Local Development Setup](./local-development-setup.md)  

---

## 🎯 Learning Objectives

By completing this guide, you will learn:
- ✅ Git workflow and branching strategy
- ✅ Code structure and organization
- ✅ Development, testing, and debugging process
- ✅ Code review and merge request process
- ✅ CI/CD pipeline and deployment

---

## 🚀 Your First Task: Add a Health Check Enhancement

We'll add a simple enhancement to improve the health check endpoint in the Auth Service.

### Task Overview
- **Service**: Auth Service (`auth/`)
- **Change**: Add version information to health check response
- **Files to modify**: `auth/internal/service/health.go`
- **Estimated time**: 30-45 minutes

---

## 📋 Step-by-Step Guide

### Step 1: Explore the Codebase

```bash
# Navigate to the project root
cd microservices

# Explore the auth service structure
tree auth -L 3
```

**Key Directories:**
- `auth/api/`: API definitions (proto files)
- `auth/internal/`: Internal implementation
- `auth/cmd/`: Application entry points
- `auth/configs/`: Configuration files

### Step 2: Create Feature Branch

```bash
# Create and switch to feature branch
git checkout -b feature/health-check-version

# Verify you're on the new branch
git branch
```

### Step 3: Understand Current Health Check

```bash
# Look at current health check implementation
cat auth/internal/service/health.go

# Test current health endpoint
curl http://localhost:8001/healthz
```

**Current Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-02-03T10:30:45Z"
}
```

### Step 4: Implement the Enhancement

```bash
# Edit the health service file
code auth/internal/service/health.go
```

**Add version information to the health check:**

```go
package service

import (
    "time"
    "gitlab.com/ta-microservices/common/config"
)

type HealthService struct {
    config *config.Config
}

func NewHealthService(cfg *config.Config) *HealthService {
    return &HealthService{
        config: cfg,
    }
}

type HealthResponse struct {
    Status    string    `json:"status"`
    Timestamp time.Time `json:"timestamp"`
    Version   string    `json:"version"`
    Service   string    `json:"service"`
}

func (s *HealthService) Check() *HealthResponse {
    return &HealthResponse{
        Status:    "healthy",
        Timestamp: time.Now(),
        Version:   "1.0.0", // You can make this configurable
        Service:   "auth-service",
    }
}
```

### Step 5: Test Your Changes

```bash
# Start the auth service
cd auth
go run cmd/auth/main.go -conf configs/config.yaml

# In another terminal, test the endpoint
curl http://localhost:8001/healthz

# Expected response:
# {
#   "status": "healthy",
#   "timestamp": "2026-02-03T10:30:45Z",
#   "version": "1.0.0",
#   "service": "auth-service"
# }
```

### Step 6: Write Tests

```bash
# Create test file
touch auth/internal/service/health_test.go

# Add tests
code auth/internal/service/health_test.go
```

**Test Implementation:**
```go
package service

import (
    "testing"
    "time"
    "gitlab.com/ta-microservices/common/config"
)

func TestHealthService_Check(t *testing.T) {
    cfg := &config.Config{}
    service := NewHealthService(cfg)
    
    response := service.Check()
    
    if response.Status != "healthy" {
        t.Errorf("Expected status 'healthy', got '%s'", response.Status)
    }
    
    if response.Version == "" {
        t.Error("Version should not be empty")
    }
    
    if response.Service != "auth-service" {
        t.Errorf("Expected service 'auth-service', got '%s'", response.Service)
    }
    
    if time.Since(response.Timestamp) > time.Second {
        t.Error("Timestamp should be recent")
    }
}
```

### Step 7: Run Tests

```bash
# Run tests for the health service
cd auth
go test ./internal/service/... -v

# Run all tests for the service
go test ./... -v

# Run with coverage
go test ./... -cover
```

### Step 8: Code Quality Checks

```bash
# Run linter
cd auth
golangci-lint run

# Format code
go fmt ./...
goimports -w .

# Check for any issues
go vet ./...
```

### Step 9: Commit Your Changes

```bash
# Stage your changes
git add auth/internal/service/health.go
git add auth/internal/service/health_test.go

# Check what will be committed
git status
git diff --staged

# Commit with proper message
git commit -m "feat(auth): add version and service info to health check

- Add version field to health response
- Add service name to health response  
- Add unit tests for health check
- Improve health check debugging information

Closes #TICKET-123"
```

### Step 10: Push and Create Merge Request

```bash
# Push your branch
git push origin feature/health-check-version

# Create merge request in GitLab UI
# Or use GitLab CLI if available
```

**Merge Request Template:**
```markdown
## Description
Enhanced the health check endpoint to include version and service information for better debugging and monitoring.

## Changes
- Added `version` field to health response
- Added `service` field to health response
- Added comprehensive unit tests
- Updated health check service structure

## Testing
- ✅ Unit tests pass
- ✅ Manual testing of health endpoint
- ✅ Code quality checks pass
- ✅ Service starts successfully

## Screenshots/Demo
Before:
```json
{"status": "healthy", "timestamp": "2026-02-03T10:30:45Z"}
```

After:
```json
{
  "status": "healthy", 
  "timestamp": "2026-02-03T10:30:45Z",
  "version": "1.0.0",
  "service": "auth-service"
}
```

## Checklist
- [ ] Code follows project standards
- [ ] Tests added and passing
- [ ] Documentation updated if needed
- [ ] Manual testing completed
```

---

## 🔍 Code Review Process

### What to Expect
1. **Automated Checks**: CI/CD pipeline runs automatically
2. **Peer Review**: Team member reviews your code
3. **Feedback**: Suggestions for improvements
4. **Approval**: Code approved and merged

### Review Criteria
- **Functionality**: Does the code work as intended?
- **Quality**: Is the code well-written and maintainable?
- **Tests**: Are tests comprehensive and passing?
- **Documentation**: Is the change well-documented?
- **Standards**: Does it follow project standards?

### Responding to Feedback
```bash
# Make requested changes
git checkout feature/health-check-version
# Make changes...
git add .
git commit -m "fix: address code review feedback

- Improve error handling
- Add missing test case
- Update documentation"
git push origin feature/health-check-version
```

---

## 🚀 Deployment Process

### CI/CD Pipeline
1. **Build**: Compiles Go code and builds Docker image
2. **Test**: Runs all tests and quality checks
3. **Security**: Scans for vulnerabilities
4. **Deploy**: Deploys to development environment

### Monitoring Deployment
```bash
# Check pipeline status in GitLab CI/CD
# Monitor deployment in ArgoCD
# Verify service in development environment
curl https://dev-api.example.com/healthz
```

---

## 🎉 Congratulations! 

You've successfully:
- ✅ Explored the codebase structure
- ✅ Made code changes following project patterns
- ✅ Written comprehensive tests
- ✅ Followed Git workflow and branching
- ✅ Created a merge request
- ✅ Understood the code review process

---

## 🔄 Next Steps

### Continue Learning
1. **Pick a Real Task**: Choose a small bug or feature from the backlog
2. **Explore Other Services**: Look at different service implementations
3. **Study Architecture**: Read [Architecture Documentation](../../01-architecture/README.md)
4. **Learn Standards**: Review [Development Standards](../standards/README.md)

### Practice More
1. **Add Another Enhancement**: Improve another endpoint
2. **Fix a Bug**: Pick a simple bug from issues
3. **Write Documentation**: Improve service documentation
4. **Help Others**: Review other developers' code

### Advanced Topics
1. **Event-Driven Development**: Add event publishing
2. **Database Changes**: Create database migrations
3. **API Development**: Add new REST/gRPC endpoints
4. **Performance Testing**: Add performance tests

---

## 📞 Getting Help

### Stuck on Something?
- **Slack #development-help**: Ask questions
- **Buddy/Mentor**: Your assigned mentor
- **Code Review**: Request help in MR comments
- **Documentation**: Check existing docs

### Common Issues
- **Build Failures**: Check Go version and dependencies
- **Test Failures**: Verify test setup and dependencies
- **Git Issues**: Check branch status and conflicts
- **Service Won't Start**: Check configuration and ports

---

**Last Updated**: February 3, 2026  
**Review Cycle**: Monthly or when development process changes  
**Maintained By**: Development Team
