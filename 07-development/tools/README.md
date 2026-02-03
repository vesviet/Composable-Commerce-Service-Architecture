# Development Tools

**Purpose**: Essential tools and utilities for microservices development  
**Audience**: All developers working on the microservices platform  

---

## 🚀 Quick Navigation

### **Core Tools**
- **[IDE & Tools Setup](./ide-setup.md)** - VS Code/GoLand configuration
- **[Debugging Tools](./debugging-tools.md)** - Debugging techniques and tools
- **[Testing Tools](./testing-tools.md)** - Testing frameworks and utilities
- **[API Development Tools](./api-tools.md)** - API design and testing tools

### **Productivity Tools**
- **[Productivity Tools](./productivity-tools.md)** - Tools to boost developer productivity
- **[Code Generation](./code-generation.md)** - Protobuf, OpenAPI, and code generation
- **[Performance Tools](./performance-tools.md)** - Performance analysis and optimization

---

## 🎯 Tool Categories

### **Development Environment**
- **IDEs**: VS Code, GoLand
- **Terminals**: iTerm2, Windows Terminal
- **Shells**: Zsh, Bash, PowerShell
- **Package Managers**: Go modules, Homebrew, Snap

### **Build & Development**
- **Build Tools**: Go build, Make, Tilt
- **Code Quality**: golangci-lint, SonarQube
- **Code Generation**: protoc, swag, mockgen
- **Hot Reload**: Air, Tilt

### **Testing & Quality**
- **Unit Testing**: Go testing, Testify
- **Integration Testing**: Docker Compose, Testcontainers
- **API Testing**: Postman, Insomnia, REST Client
- **Load Testing**: hey, wrk, k6

### **Database & Storage**
- **Databases**: PostgreSQL, Redis, Elasticsearch
- **Database Tools**: TablePlus, DBeaver, pgAdmin
- **Migration Tools**: Goose, Flyway
- **Data Visualization**: Grafana, Kibana

### **Container & Orchestration**
- **Containers**: Docker, Docker Compose
- **Orchestration**: Kubernetes, k3d
- **Service Mesh**: Dapr, Istio
- **CI/CD**: GitLab CI, ArgoCD

### **Monitoring & Debugging**
- **Metrics**: Prometheus, Grafana
- **Tracing**: Jaeger, Zipkin
- **Logging**: ELK Stack, Fluentd
- **Debugging**: Delve, IDE debuggers

---

## 🛠️ Required Tools Installation

### **One-Command Setup**
```bash
# Run the setup script
./scripts/setup-dev-tools.sh

# Or install manually following guides below
```

### **Manual Installation Checklist**

#### ✅ **Go Development**
```bash
# Go 1.25.3+
go version

# Essential Go tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/air-verse/air@latest
go install github.com/swaggo/swag/cmd/swag@latest
```

#### ✅ **Container Tools**
```bash
# Docker & Docker Compose
docker --version
docker-compose --version

# Kubernetes tools
kubectl version --client
helm version
```

#### ✅ **IDE Setup**
```bash
# VS Code with extensions
code --version
code --list-extensions | grep golang.go

# Or GoLand
# Install from https://www.jetbrains.com/go/
```

#### ✅ **API Testing**
```bash
# Postman or Insomnia
# Install from respective websites
```

#### ✅ **Database Tools**
```bash
# TablePlus or DBeaver
# Install from respective websites
```

---

## 🎨 Tool Configuration

### **VS Code Extensions**
```bash
# Core development
code --install-extension golang.go
code --install-extension eamodio.gitlens
code --install-extension ms-azuretools.vscode-docker

# API and testing
code --install-extension humao.rest-client
code --install-extension ms-vscode.thunder-client

# Productivity
code --install-extension redhat.vscode-yaml
code --install-extension ms-vscode.vscode-json
```

### **Go Tools Configuration**
```bash
# golangci-lint configuration
cat > .golangci.yml << EOF
run:
  timeout: 5m
  tests: true

linters:
  enable:
    - gofmt
    - goimports
    - govet
    - errcheck
    - staticcheck
    - unused
    - gosimple
    - structcheck
    - varcheck
    - ineffassign
    - deadcode
    - typecheck
    - gosec
    - misspell
    - unconvert
    - dupl
    - goconst
    - gocyclo

linters-settings:
  goimports:
    local-prefixes: gitlab.com/ta-microservices
  gocyclo:
    min-complexity: 15
  dupl:
    threshold: 100
  goconst:
    min-len: 3
    min-occurrences: 3
EOF
```

### **Docker Configuration**
```bash
# Docker Compose for development
cat > docker-compose.dev.yml << EOF
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ecommerce_db
      POSTGRES_USER: ecommerce_user
      POSTGRES_PASSWORD: ecommerce_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
EOF
```

---

## 🔧 Tool Integration

### **IDE Integration**
- **Git**: Integrated version control
- **Docker**: Container management
- **Database**: Database connections and queries
- **Terminal**: Integrated terminal for commands
- **Debugging**: Built-in debugger integration

### **CI/CD Integration**
- **GitLab CI**: Automated builds and tests
- **Docker Registry**: Image storage and distribution
- **ArgoCD**: GitOps deployment
- **Prometheus**: Metrics collection
- **Jaeger**: Distributed tracing

### **Monitoring Integration**
- **Health Checks**: Service health monitoring
- **Metrics**: Performance metrics collection
- **Logging**: Structured logging with correlation
- **Alerting**: Automated alerting on issues

---

## 📊 Tool Performance

### **Development Environment**
- **Startup Time**: < 30 seconds for full environment
- **Memory Usage**: 8-16GB RAM recommended
- **Storage**: 20GB+ free space required
- **CPU**: 4+ cores recommended

### **Build Performance**
- **Go Build**: < 10 seconds for typical service
- **Docker Build**: < 2 minutes for service image
- **Test Execution**: < 1 minute for unit tests
- **Linting**: < 30 seconds for full codebase

### **Debugging Performance**
- **Hot Reload**: < 5 seconds for changes
- **Breakpoint Response**: < 1 second
- **Variable Inspection**: Real-time
- **Memory Profiling**: Minimal overhead

---

## 🎯 Best Practices

### **Tool Management**
- **Version Control**: Keep tool versions consistent
- **Documentation**: Document tool configurations
- **Automation**: Automate tool setup and updates
- **Security**: Regular security updates for tools

### **Development Workflow**
- **Consistent Environment**: Use same tools across team
- **IDE Standards**: Standardize IDE configurations
- **Code Quality**: Use linting and formatting tools
- **Testing**: Comprehensive testing toolchain

### **Performance Optimization**
- **Resource Management**: Monitor tool resource usage
- **Caching**: Use build and dependency caching
- **Parallel Execution**: Run tests and builds in parallel
- **Incremental Builds**: Only rebuild changed components

---

## 🆘 Troubleshooting

### **Common Issues**

#### **Go Tools Not Working**
```bash
# Check Go installation
go version
go env

# Reinstall tools
go clean -modcache
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

#### **Docker Issues**
```bash
# Reset Docker daemon
docker system prune -a
docker-compose down -v
docker-compose up -d
```

#### **IDE Extension Issues**
```bash
# VS Code: Reload and reinstall extensions
code --disable-extensions
code --install-extension golang.go

# GoLand: Invalidate caches and restart
# File → Invalidate Caches / Restart
```

#### **Performance Issues**
```bash
# Check resource usage
docker stats
top -p $(pgrep -f "go run")
```

---

## 📚 Learning Resources

### **Tool Documentation**
- [VS Code Documentation](https://code.visualstudio.com/docs)
- [GoLand Documentation](https://www.jetbrains.com/go/documentation/)
- [Docker Documentation](https://docs.docker.com/)
- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)

### **Tutorials & Guides**
- [Go Development Tools](https://golang.org/doc/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [VS Code Go Tutorial](https://code.visualstudio.com/docs/go/get-started)

### **Community Resources**
- [Go Community](https://golang.org/community/)
- [Docker Community](https://www.docker.com/community/)
- [VS Code Community](https://code.visualstudio.com/docs/supporting/community)

---

## 🔄 Updates & Maintenance

### **Regular Updates**
- **Go**: Update to latest stable version
- **IDE Extensions**: Update monthly
- **Docker**: Update quarterly
- **Tools**: Update as needed for security

### **Maintenance Tasks**
- **Clean Caches**: Regular cleanup of build caches
- **Update Dependencies**: Keep Go modules updated
- **Review Tools**: Evaluate new tools quarterly
- **Documentation**: Keep tool documentation current

---

**Last Updated**: February 3, 2026  
**Review Cycle**: Monthly or when tools change  
**Maintained By**: Development Team
