# Development Review Checklist

**Version**: 1.0  
**Last Updated**: 2026-01-27  
**Domain**: Development Standards  
**Audience**: Senior Engineers, Code Reviewers

## 🎯 Overview

This checklist ensures consistent, high-quality code reviews and maintains project integrity across all microservices. Follow this guide when reviewing pull requests, conducting architecture reviews, or auditing existing code.

## 📋 Review Process

### 1. Pre-Review Setup

- [ ] **Pull latest changes** from main branch
- [ ] **Run tests locally** to ensure baseline functionality
- [ ] **Check CI/CD status** - all pipelines should be green
- [ ] **Review linked issues/tickets** for context

### 2. Issue Status Management

#### 🚩 Identify and Categorize Issues

**Priority Levels:**
- 🔴 **Critical**: Security vulnerabilities, data corruption, service outages
- 🟠 **High**: Performance issues, major bugs, architectural problems
- 🟡 **Medium**: Code quality, maintainability, minor bugs
- 🟢 **Low**: Documentation, formatting, optimization opportunities

#### Issue Tracking Format:

```markdown
## 🚩 PENDING ISSUES (Unfixed)
- [CRITICAL] [Issue ID]: Brief description + Required action
- [HIGH] [Issue ID]: Brief description + Required action
- [MEDIUM] [Issue ID]: Brief description + Required action

## 🆕 NEWLY DISCOVERED ISSUES
- [Category] [Issue Title]: Why it's a problem + Suggested fix

## ✅ RESOLVED / FIXED
- [FIXED ✅] [Issue Title]: Summary of the fix applied
```

---

## 🔍 Code Review Criteria

### Go-Specific Standards

#### Error Handling
- [ ] **Proper error wrapping** using `fmt.Errorf()` or `errors.Wrap()`
- [ ] **Context propagation** - all functions accept `context.Context` as first parameter
- [ ] **Error classification** - use common/errors package for structured errors
- [ ] **No panic in production code** - handle all error cases gracefully

```go
// ✅ Good
func (s *Service) GetUser(ctx context.Context, id string) (*User, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("failed to get user %s: %w", id, err)
    }
    return user, nil
}

// ❌ Bad
func (s *Service) GetUser(id string) *User {
    user, _ := s.repo.FindByID(context.Background(), id)
    return user
}
```

#### Concurrency & Goroutines
- [ ] **No goroutine leaks** - all goroutines have proper cleanup
- [ ] **Context cancellation** respected in long-running operations
- [ ] **Proper channel usage** - channels are closed by sender
- [ ] **Race condition checks** - use `go run -race` for testing

```go
// ✅ Good
func (w *Worker) Start(ctx context.Context) error {
    ticker := time.NewTicker(w.interval)
    defer ticker.Stop()
    
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-ticker.C:
            if err := w.process(ctx); err != nil {
                log.Errorf("Worker process failed: %v", err)
            }
        }
    }
}
```

#### Interface Design
- [ ] **Interface segregation** - small, focused interfaces
- [ ] **Accept interfaces, return structs** principle followed
- [ ] **Dependency injection** used for testability
- [ ] **Mock interfaces** available for testing

```go
// ✅ Good
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
}

type UserService struct {
    repo UserRepository // Interface dependency
}
```

### Architecture & Design

#### Maintainability
- [ ] **Dynamic scaling support** - avoid hardcoded service lists
- [ ] **Configuration externalized** - no hardcoded values
- [ ] **Common package usage** - leverage shared utilities
- [ ] **Proper separation of concerns** - clear layer boundaries

```go
// ✅ Good - Dynamic service discovery
services := config.GetEnabledServices()
for _, service := range services {
    client := factory.CreateClient(service)
    // ...
}

// ❌ Bad - Hardcoded service list
clients := []Client{
    authClient,
    userClient,
    orderClient, // Manual addition required for new services
}
```

#### Security
- [ ] **Input validation** using common/validation package
- [ ] **Authentication/Authorization** properly implemented
- [ ] **Sensitive data masking** in logs
- [ ] **SQL injection prevention** - use parameterized queries
- [ ] **Rate limiting** implemented for public endpoints

```go
// ✅ Good
func (s *Service) CreateUser(ctx context.Context, req *CreateUserRequest) error {
    if err := validation.NewValidator().
        Required("email", req.Email).
        Email("email", req.Email).
        Validate(); err != nil {
        return commonErrors.NewValidationError(err.Error())
    }
    // ...
}
```

#### Performance
- [ ] **Database queries optimized** - proper indexing, avoid N+1
- [ ] **Caching strategy** implemented where appropriate
- [ ] **Connection pooling** configured
- [ ] **Memory leaks prevented** - proper resource cleanup
- [ ] **Pagination** implemented for list endpoints

### Testing Standards

#### Unit Tests
- [ ] **Test coverage > 80%** for business logic
- [ ] **Table-driven tests** for multiple scenarios
- [ ] **Mock dependencies** properly configured
- [ ] **Error cases tested** - not just happy path

```go
// ✅ Good
func TestUserService_CreateUser(t *testing.T) {
    tests := []struct {
        name    string
        request *CreateUserRequest
        mockFn  func(*mocks.UserRepository)
        wantErr bool
    }{
        {
            name: "success",
            request: &CreateUserRequest{Email: "test@example.com"},
            mockFn: func(m *mocks.UserRepository) {
                m.On("Create", mock.Anything, mock.Anything).Return(nil)
            },
            wantErr: false,
        },
        // ... more test cases
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test implementation
        })
    }
}
```

#### Integration Tests
- [ ] **API endpoints tested** with real HTTP calls
- [ ] **Database integration** tested with test containers
- [ ] **Event publishing/consuming** tested
- [ ] **Circuit breaker behavior** tested

### DevOps & Kubernetes

#### Deployment
- [ ] **Health checks** implemented (`/health/live`, `/health/ready`)
- [ ] **Graceful shutdown** handling SIGTERM signals
- [ ] **Resource limits** defined in K8s manifests
- [ ] **Environment-specific configs** properly managed

```yaml
# ✅ Good K8s deployment
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: service
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
```

#### Observability
- [ ] **Structured logging** with proper log levels
- [ ] **Metrics collection** using Prometheus
- [ ] **Distributed tracing** configured
- [ ] **Error tracking** and alerting setup

#### Git & CI/CD
- [ ] **Conventional Commits** format followed
- [ ] **Branch protection** rules enforced
- [ ] **Automated testing** in CI pipeline
- [ ] **Security scanning** enabled

```bash
# ✅ Good commit messages
feat(auth): add JWT token refresh endpoint
fix(order): resolve race condition in status updates
docs(api): update OpenAPI specification
```

---

## 🛠️ Debugging & Troubleshooting

### Local Development
```bash
# Run tests with race detection
go test -race ./...

# Check for goroutine leaks
go test -v -run TestName -timeout 30s

# Profile memory usage
go test -memprofile=mem.prof -bench=.
go tool pprof mem.prof
```

### Kubernetes Debugging
```bash
# Check pod status and logs
kubectl get pods -n namespace
kubectl logs -f pod-name -n namespace

# Debug container issues
kubectl describe pod pod-name -n namespace
kubectl exec -it pod-name -n namespace -- /bin/sh

# Port forward for local debugging
kubectl port-forward pod-name 8080:8080 -n namespace

# Stream logs from multiple pods
stern service-name -n namespace
```

### Database Debugging
```bash
# Check database connections
kubectl exec -it postgres-pod -- psql -U user -d database -c "SELECT * FROM pg_stat_activity;"

# Monitor slow queries
kubectl logs postgres-pod | grep "slow query"

# Check Redis connections
kubectl exec -it redis-pod -- redis-cli info clients
```

---

## 📝 Review Checklist Template

Use this template when conducting reviews:

```markdown
## Code Review: [PR Title]

### 🔍 Review Summary
- **Reviewer**: [Your Name]
- **Date**: [Date]
- **Branch**: [feature/branch-name]
- **Files Changed**: [Number]

### 🚩 PENDING ISSUES (Unfixed)
- [ ] [CRITICAL] [Issue]: Description + Action required
- [ ] [HIGH] [Issue]: Description + Action required

### 🆕 NEWLY DISCOVERED ISSUES
- [ ] [Security] [Issue]: Problem description + Suggested fix
- [ ] [Performance] [Issue]: Problem description + Suggested fix

### ✅ RESOLVED / FIXED
- [FIXED ✅] [Previous Issue]: Fix description

### 📊 Review Metrics
- **Test Coverage**: [X]%
- **Performance Impact**: [None/Low/Medium/High]
- **Security Risk**: [None/Low/Medium/High]
- **Breaking Changes**: [Yes/No]

### 🎯 Recommendation
- [ ] **Approve** - Ready to merge
- [ ] **Request Changes** - Issues must be addressed
- [ ] **Comment** - Suggestions for improvement
```

---

## 🎯 Best Practices

### Code Quality
1. **Follow SOLID principles** - especially Single Responsibility and Dependency Inversion
2. **Use common package utilities** - avoid reinventing the wheel
3. **Write self-documenting code** - clear variable and function names
4. **Keep functions small** - ideally under 50 lines
5. **Avoid deep nesting** - use early returns and guard clauses

### Review Process
1. **Review small PRs** - aim for < 400 lines changed
2. **Focus on logic first** - then style and formatting
3. **Test the changes locally** - don't just read the code
4. **Consider the bigger picture** - how does this fit the architecture?
5. **Be constructive** - suggest solutions, not just problems

### Documentation
1. **Update documentation** with code changes
2. **Include examples** in API documentation
3. **Document breaking changes** clearly
4. **Keep README files current**
5. **Add inline comments** for complex business logic

---

## 🚨 Red Flags

Watch out for these common issues:

### Code Smells
- **God objects** - classes/structs doing too much
- **Duplicate code** - should use common utilities
- **Magic numbers** - use named constants
- **Long parameter lists** - consider using structs
- **Nested conditionals** - refactor for readability

### Security Issues
- **Hardcoded secrets** - use environment variables
- **SQL injection** - use parameterized queries
- **Unvalidated input** - always validate user input
- **Missing authentication** - secure all endpoints
- **Information leakage** - don't expose internal errors

### Performance Issues
- **N+1 queries** - use eager loading or batching
- **Memory leaks** - ensure proper cleanup
- **Blocking operations** - use context for cancellation
- **Inefficient algorithms** - consider time complexity
- **Missing caching** - cache expensive operations

---

## 📚 Resources

### Internal Documentation
- [Common Package Usage Guide](./common-package-usage.md)
- [API Design Standards](./api-design-standards.md)
- [Security Guidelines](./security-guidelines.md)

### External Resources
- [Effective Go](https://golang.org/doc/effective_go.html)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

**Remember**: The goal is to maintain high code quality while fostering a collaborative development environment. Be thorough but constructive in your reviews.

**Last Updated**: 2026-01-27