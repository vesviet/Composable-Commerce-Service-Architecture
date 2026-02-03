# Local Development Setup

**Purpose**: Complete guide to set up local development environment  
**Audience**: New developers, developers setting up new machines  
**Prerequisites**: Git, Docker Desktop, basic command line knowledge  

---

## 🚀 Quick Start

### System Requirements
- **OS**: macOS 10.15+, Ubuntu 20.04+, or Windows 10+ with WSL2
- **RAM**: 16GB+ recommended (8GB minimum)
- **Storage**: 20GB+ free disk space
- **CPU**: 4+ cores recommended

### One-Command Setup
```bash
# Clone and setup everything
git clone https://gitlab.com/ta-microservices/microservices.git
cd microservices
chmod +x scripts/setup-dev.sh
./scripts/setup-dev.sh
```

---

## 📋 Detailed Setup Steps

### 1. Install Required Tools

#### Go Development Environment
```bash
# Install Go 1.25.3
# macOS
brew install go@1.25

# Ubuntu
wget https://go.dev/dl/go1.25.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.25.3.linux-amd64.tar.gz

# Add to ~/.bashrc or ~/.zshrc
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
```

#### Docker and Docker Compose
```bash
# macOS
brew install --cask docker

# Ubuntu
sudo apt update
sudo apt install docker.io docker-compose
sudo usermod -aG docker $USER

# Windows
# Install Docker Desktop from https://docker.com/products/docker-desktop
```

#### Development Tools
```bash
# Essential Go tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
go install github.com/air-verse/air@latest
go install github.com/swaggo/swag/cmd/swag@latest

# Node.js (for frontend)
# macOS
brew install node

# Ubuntu
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Clone and Configure Repository

```bash
# Clone the repository
git clone https://gitlab.com/ta-microservices/microservices.git
cd microservices

# Configure Git (if not already configured)
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"

# Create development environment file
cp .env.example .env.local
```

### 3. Start Development Infrastructure

```bash
# Start shared services (databases, Redis, etc.)
docker-compose up -d

# Wait for services to be ready (2-3 minutes)
docker-compose ps

# Initialize databases
./scripts/init-databases.sh
```

### 4. Start Development Services

```bash
# Using Tilt for hot reload (recommended)
cd k8s-local
tilt up

# Or start services manually
./scripts/start-dev-services.sh
```

---

## 🔧 Development Environment Configuration

### Environment Variables (.env.local)
```bash
# Database Configuration
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=ecommerce_user
POSTGRES_PASSWORD=ecommerce_pass
POSTGRES_DB=ecommerce_db

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Service Ports
AUTH_SERVICE_PORT=8001
USER_SERVICE_PORT=8002
GATEWAY_PORT=8000

# Development Settings
LOG_LEVEL=debug
ENVIRONMENT=development
ENABLE_HOT_RELOAD=true
```

### IDE Configuration

#### VS Code Setup
1. Install extensions:
   - Go (golang.go)
   - Docker (ms-azuretools.vscode-docker)
   - YAML (redhat.vscode-yaml)
   - GitLens (eamodio.gitlens)

2. Configure settings (`.vscode/settings.json`):
```json
{
  "go.useLanguageServer": true,
  "go.formatTool": "goimports",
  "go.lintTool": "golangci-lint",
  "go.testFlags": ["-v"],
  "files.exclude": {
    "**/vendor": true,
    "**/bin": true
  }
}
```

#### GoLand Setup
1. Configure Go SDK to point to Go 1.25.3
2. Enable Go Modules integration
3. Configure file watchers for hot reload
4. Set up Docker integration

---

## 🏃‍♂️ Running Services

### Option 1: Using Tilt (Recommended)
```bash
cd k8s-local
tilt up
# Open http://localhost:10350 to see Tilt UI
```

### Option 2: Manual Service Startup
```bash
# Start core services
./scripts/start-core-services.sh

# Start individual services
cd auth
go run cmd/auth/main.go -conf configs/config.yaml

# Or use Air for hot reload
cd auth
air -c .air.toml
```

### Option 3: Docker Compose Development
```bash
# Start all services with Docker Compose
docker-compose -f docker-compose.dev.yml up

# Start specific service
docker-compose -f docker-compose.dev.yml up auth
```

---

## 🧪 Testing Your Setup

### Health Check
```bash
# Check all services are running
curl http://localhost:8000/healthz

# Check individual services
curl http://localhost:8001/healthz  # Auth Service
curl http://localhost:8002/healthz  # User Service
```

### Run Basic Tests
```bash
# Run tests for a specific service
cd auth
go test ./...

# Run all tests
./scripts/run-tests.sh
```

### Verify Database Connections
```bash
# Connect to PostgreSQL
docker exec -it source_postgres psql -U ecommerce_user -d ecommerce_db

# Connect to Redis
docker exec -it source_redis redis-cli
```

---

## 🔍 Common Issues & Solutions

### Port Conflicts
```bash
# Check what's using ports
lsof -i :8000
lsof -i :5432

# Kill processes using ports
kill -9 <PID>
```

### Docker Issues
```bash
# Reset Docker environment
docker system prune -a
docker-compose down -v
docker-compose up -d
```

### Go Module Issues
```bash
# Clean module cache
go clean -modcache
go mod download
go mod tidy
```

### Permission Issues
```bash
# Fix Docker permissions (Linux)
sudo usermod -aG docker $USER
# Then logout and login again

# Fix file permissions
sudo chown -R $USER:$USER .
chmod +x scripts/*.sh
```

---

## 📚 Development Workflow

### Making Changes
1. **Edit Code**: Make changes to service files
2. **Hot Reload**: Tilt/Air automatically restarts services
3. **Test**: Run tests to verify changes
4. **Commit**: Commit changes with proper messages
5. **Push**: Push to feature branch for review

### Debugging
```bash
# Use Go debugger
dlv debug ./cmd/auth/main.go

# Or add debug flags
go run -tags=debug ./cmd/auth/main.go -conf configs/config.yaml

# Check logs
docker-compose logs -f auth
tilt logs auth
```

### Database Development
```bash
# Run migrations
cd auth
go run cmd/migrate/main.go up

# Create new migration
go run cmd/migrate/main.go create add_user_field

# Rollback migration
go run cmd/migrate/main.go down
```

---

## 🎯 Next Steps

1. **Explore Services**: Browse through different service directories
2. **Read Architecture**: Review `docs/01-architecture/`
3. **Study Standards**: Read `docs/07-development/standards/`
4. **Make First Change**: Try making a small change and testing
5. **Join Team**: Set up code review and collaboration tools

---

## 📞 Getting Help

### Documentation
- **Architecture**: `docs/01-architecture/README.md`
- **Services**: `docs/03-services/README.md`
- **Standards**: `docs/07-development/standards/`

### Team Support
- **Slack**: #development-help
- **Issues**: Create GitLab issue for bugs
- **Code Review**: Request review in GitLab MR

### Troubleshooting Resources
- **Common Issues**: `docs/10-appendix/troubleshooting/`
- **FAQ**: `docs/10-appendix/faq/`
- **Logs**: Check service logs for errors

---

**Last Updated**: February 3, 2026  
**Review Cycle**: Monthly or when tools change  
**Maintained By**: Platform Engineering Team
