# Makefile Standards & Best Practices

This guide documents the standardized Makefile patterns used across all microservices, following the **shop-main** and **catalog-main** implementations.

## 🎯 Overview

All services follow a **consistent Makefile pattern** that provides:
- **Cross-platform compatibility** (Windows/Unix)
- **Protobuf-first development** workflow
- **OpenAPI generation** from protobuf definitions
- **Database migration** management with Goose
- **Docker integration** for containerization
- **Development workflow** optimization

## 📁 Standard Makefile Structure

### **Template Structure (All Services)**
```makefile
# Service Makefile (Following shop-main/catalog-main pattern)
GOHOSTOS:=$(shell go env GOHOSTOS)
GOPATH:=$(shell go env GOPATH)
VERSION=$(shell git describe --tags --always)

# Handle Windows vs Unix find command
ifeq ($(GOHOSTOS), windows)
	Git_Bash=$(subst \,/,$(subst cmd\,bin\bash.exe,$(dir $(shell where git))))
	INTERNAL_PROTO_FILES=$(shell $(Git_Bash) -c "find internal -name *.proto")
	API_PROTO_FILES=$(shell $(Git_Bash) -c "find api -name *.proto")
	CLIENT_PROTO_FILES=$(shell $(Git_Bash) -c "find internal/data -name *.proto")
else
	INTERNAL_PROTO_FILES=$(shell find internal -name *.proto)
	API_PROTO_FILES=$(shell find api -name *.proto)
	CLIENT_PROTO_FILES=$(shell find internal/data -name *.proto)
endif

# Standard targets follow...
```

## 🔧 Standard Targets

### **1. Development Environment**

#### **init** - Initialize development environment
```makefile
.PHONY: init
# Initialize development environment
init:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/go-kratos/kratos/cmd/kratos/v2@latest
	go install github.com/go-kratos/kratos/cmd/protoc-gen-go-http/v2@latest
	go install github.com/google/gnostic/cmd/protoc-gen-openapi@latest
	go install github.com/google/wire/cmd/wire@latest
```

**Usage:**
```bash
# First-time setup
make init
```

### **2. Code Generation**

#### **api** - Generate API code and OpenAPI specification
```makefile
.PHONY: api
# Generate API proto and OpenAPI specification
api:
	protoc --proto_path=./api \
	       --proto_path=./third_party \
 	       --go_out=paths=source_relative:./api \
 	       --go-http_out=paths=source_relative:./api \
 	       --go-grpc_out=paths=source_relative:./api \
	       --openapi_out=fq_schema_naming=true,default_response=false:. \
	       $(API_PROTO_FILES)
```

#### **config** - Generate internal proto
```makefile
.PHONY: config
# Generate internal proto
config:
	protoc --proto_path=./internal \
	       --proto_path=./third_party \
 	       --go_out=paths=source_relative:./internal \
	       $(INTERNAL_PROTO_FILES)
```

#### **client** - Generate client proto (for services with external dependencies)
```makefile
.PHONY: client
# Generate client proto
client:
	protoc --proto_path=./internal/data \
  	       --proto_path=./third_party \
	       --go_out=paths=source_relative:./internal/data \
	       --go-http_out=paths=source_relative:./internal/data \
	       $(CLIENT_PROTO_FILES)
```

**Usage:**
```bash
# Generate API code and OpenAPI spec
make api

# Generate internal configuration
make config

# Generate client code (if needed)
make client

# Generate everything
make all
```

### **3. Validation & Quality**

#### **validate** - Validate proto files
```makefile
.PHONY: validate
# Validate proto files
validate:
	@echo "Validating proto files..."
	@for file in $(API_PROTO_FILES); do \
		echo "Validating $$file"; \
		protoc --proto_path=./api --proto_path=./third_party --descriptor_set_out=/dev/null $$file; \
	done
```

#### **validate-openapi** - Validate OpenAPI specification
```makefile
.PHONY: validate-openapi
# Validate OpenAPI spec
validate-openapi:
	@if command -v swagger-parser >/dev/null 2>&1; then \
		swagger-parser validate openapi.yaml; \
	else \
		echo "swagger-parser not found. Install with: npm install -g swagger-parser"; \
	fi
```

#### **lint** - Run linter
```makefile
.PHONY: lint
# Run linter
lint:
	golangci-lint run --timeout 10m
```

**Usage:**
```bash
# Validate protobuf files
make validate

# Validate OpenAPI specification
make validate-openapi

# Run code linter
make lint
```

### **4. Testing**

#### **test** - Run tests
```makefile
.PHONY: test
# Run tests
test:
	go test -v ./... -cover
```

#### **test-coverage** - Run tests with coverage
```makefile
.PHONY: test-coverage
# Run tests with coverage
test-coverage:
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out
```

**Usage:**
```bash
# Run tests
make test

# Run tests with coverage report
make test-coverage
```

### **5. Build & Run**

#### **build** - Build the service
```makefile
.PHONY: build
# Build the service
build:
	mkdir -p bin/ && go build -ldflags "-X main.Version=$(VERSION)" -o ./bin/ ./...
```

#### **run** - Run the service
```makefile
.PHONY: run
# Run the service
run:
	kratos run
```

#### **generate** - Generate all code
```makefile
.PHONY: generate
# Generate all code
generate:
	go mod tidy
	go get github.com/google/wire/cmd/wire@latest
	go generate ./...
```

#### **wire** - Generate wire dependency injection
```makefile
.PHONY: wire
# Generate wire dependency injection
wire:
	cd cmd/service-name && wire
```

**Usage:**
```bash
# Build the service
make build

# Run the service
make run

# Generate dependency injection
make wire

# Generate all code
make generate
```

### **6. Documentation**

#### **swagger** - Generate and serve Swagger UI
```makefile
.PHONY: swagger
# Generate and serve Swagger UI
swagger: api
	@echo "✓ OpenAPI specification generated: openapi.yaml"
	@echo "  Serve with: swagger-ui-serve openapi.yaml"
	@echo "  Or access via service: http://localhost:PORT/swagger"
```

**Usage:**
```bash
# Generate OpenAPI and show Swagger info
make swagger

# Serve Swagger UI locally
swagger-ui-serve openapi.yaml
```

### **7. Docker Integration**

#### **docker-build** - Build Docker image
```makefile
.PHONY: docker-build
# Build Docker image
docker-build:
	docker build -t service-name:$(VERSION) .
```

#### **docker-run** - Run Docker container
```makefile
.PHONY: docker-run
# Run Docker container
docker-run:
	docker run -p HTTP_PORT:HTTP_PORT -p GRPC_PORT:GRPC_PORT service-name:$(VERSION)
```

**Usage:**
```bash
# Build Docker image
make docker-build

# Run Docker container
make docker-run
```

### **8. Database Migration (Goose)**

#### **migrate-up** - Apply all pending migrations
```makefile
.PHONY: migrate-up
# Apply all pending migrations
migrate-up:
	@if [ -z "$(DATABASE_URL)" ]; then \
		echo "Error: DATABASE_URL is required. Example: make migrate-up DATABASE_URL=postgres://user:pass@localhost:5432/db?sslmode=disable"; \
		exit 1; \
	fi
	DATABASE_URL=$(DATABASE_URL) go run ./cmd/migrate -command up
```

#### **migrate-down** - Rollback last migration
```makefile
.PHONY: migrate-down
# Rollback last migration
migrate-down:
	@if [ -z "$(DATABASE_URL)" ]; then \
		echo "Error: DATABASE_URL is required"; \
		exit 1; \
	fi
	DATABASE_URL=$(DATABASE_URL) go run ./cmd/migrate -command down
```

#### **migrate-status** - Check migration status
```makefile
.PHONY: migrate-status
# Check migration status
migrate-status:
	@if [ -z "$(DATABASE_URL)" ]; then \
		echo "Error: DATABASE_URL is required"; \
		exit 1; \
	fi
	DATABASE_URL=$(DATABASE_URL) go run ./cmd/migrate -command status
```

#### **migrate-create** - Create new migration
```makefile
.PHONY: migrate-create
# Create new migration
migrate-create:
	@if [ -z "$(NAME)" ]; then \
		echo "Error: NAME is required. Example: make migrate-create NAME=add_user_table"; \
		exit 1; \
	fi
	@if [ -z "$(DATABASE_URL)" ]; then \
		echo "Error: DATABASE_URL is required"; \
		exit 1; \
	fi
	DATABASE_URL=$(DATABASE_URL) go run ./cmd/migrate -command create -name $(NAME) -type sql
```

**Usage:**
```bash
# Apply migrations
make migrate-up DATABASE_URL="postgres://user:pass@localhost:5432/db?sslmode=disable"

# Check migration status
make migrate-status DATABASE_URL="postgres://user:pass@localhost:5432/db?sslmode=disable"

# Create new migration
make migrate-create NAME=add_products_table DATABASE_URL="postgres://..."

# Rollback last migration
make migrate-down DATABASE_URL="postgres://..."
```

### **9. Utility Targets**

#### **clean** - Clean generated files
```makefile
.PHONY: clean
# Clean generated files
clean:
	find ./api -name "*.pb.go" -delete 2>/dev/null || true
	find ./api -name "*_grpc.pb.go" -delete 2>/dev/null || true
	find ./api -name "*_http.pb.go" -delete 2>/dev/null || true
	find ./internal -name "*.pb.go" -delete 2>/dev/null || true
	rm -f openapi.yaml
```

#### **all** - Generate everything
```makefile
.PHONY: all
# Generate everything
all:
	make api
	make config
	make client
	make generate
```

#### **help** - Show help
```makefile
.PHONY: help
# Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo ' make [target]'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
	helpMessage = match(lastLine, /^# (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 2, RLENGTH); \
			printf "\033[36m%-22s\033[0m %s\n", helpCommand,helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
```

**Usage:**
```bash
# Clean generated files
make clean

# Generate everything
make all

# Show help
make help
```

## 🚀 Service-Specific Variations

### **Auth Service Additions**
```makefile
.PHONY: swagger
# Generate Swagger documentation (swag-based)
swagger:
	swag init -g cmd/auth/main.go -o ./docs

.PHONY: run-launcher
# Run with launcher pattern
run-launcher: build
	USE_LAUNCHER=true ./bin/auth

.PHONY: run-swagger
# Run with swagger UI
run-swagger: build swagger
	ENABLE_SWAGGER=true USE_LAUNCHER=true ./bin/auth
```

### **Catalog Service Additions**
```makefile
# Additional proto paths for external dependencies
api:
	protoc --proto_path=./api \
	       --proto_path=./third_party \
	       --proto_path=./vendor/gitlab.com/vigo-tech/commission/api \
		   --proto_path=./vendor/gitlab.com/vigo-tech/promotion/api \
 	       --go_out=paths=source_relative:./api \
 	       --go-http_out=paths=source_relative:./api \
 	       --go-grpc_out=paths=source_relative:./api \
	       --openapi_out=fq_schema_naming=true,default_response=false:. \
	       $(API_PROTO_FILES)
```

### **Shop Service Additions**
```makefile
.PHONY: client
# Generate client proto with external dependencies
client:
	protoc --proto_path=./internal/data \
        --proto_path=./third_party \
		--proto_path=./vendor/gitlab.com/vigo-tech/clients \
		--proto_path=./vendor/gitlab.com/vigo-tech/catalog/api \
		--proto_path=./vendor/gitlab.com/vigo-tech/commission/api \
		--proto_path=./vendor/gitlab.com/vigo-tech/promotion/api \
		--go_out=paths=source_relative:./internal/data \
		--go-http_out=paths=source_relative:./internal/data \
		$(CLIENT_PROTO_FILES)
```

## 📊 Port Allocation Standards

### **Standard Port Assignments**
```makefile
# Service-specific ports (update per service)
# auth-service:     HTTP 8000, gRPC 9000
# user-service:     HTTP 8001, gRPC 9001
# catalog-service:  HTTP 8001, gRPC 9001  # Note: Conflict with user-service
# pricing-service:  HTTP 8002, gRPC 9002
# promotion-service: HTTP 8003, gRPC 9003
# order-service:    HTTP 8004, gRPC 9004
# payment-service:  HTTP 8005, gRPC 9005
# shipping-service: HTTP 8006, gRPC 9006
# customer-service: HTTP 8007, gRPC 9007
# warehouse-inventory: HTTP 8008, gRPC 9008
# notification-service: HTTP 8009, gRPC 9009
# search-service:   HTTP 8010, gRPC 9010
# review-service:   HTTP 8011, gRPC 9011
# loyalty-rewards:  HTTP 8013, gRPC 9013
# gateway-service:  HTTP 8080 (HTTP only)
```

## 🔄 Development Workflow

### **1. Initial Setup**
```bash
# Clone service repository
git clone <service-repo>
cd <service-name>

# Initialize development environment
make init

# Generate all code
make all
```

### **2. Daily Development**
```bash
# After modifying .proto files
make api

# After modifying internal config
make config

# Run tests
make test

# Build and run
make build
make run
```

### **3. Database Development**
```bash
# Create new migration
make migrate-create NAME=add_new_feature DATABASE_URL="postgres://..."

# Apply migrations
make migrate-up DATABASE_URL="postgres://..."

# Check status
make migrate-status DATABASE_URL="postgres://..."
```

### **4. Documentation**
```bash
# Generate OpenAPI spec
make api

# Validate OpenAPI spec
make validate-openapi

# Serve Swagger UI
make swagger
swagger-ui-serve openapi.yaml
```

### **5. Docker Development**
```bash
# Build Docker image
make docker-build

# Run in container
make docker-run
```

## 🎯 Best Practices

### **1. Makefile Organization**
- **Consistent target names** across all services
- **Clear documentation** for each target
- **Error handling** with helpful messages
- **Cross-platform compatibility** (Windows/Unix)

### **2. Proto File Management**
- **Automatic discovery** of proto files
- **Proper path configuration** for dependencies
- **Validation** before generation
- **Clean separation** of API, internal, and client protos

### **3. Version Management**
- **Git-based versioning** with `git describe --tags --always`
- **Version injection** into binaries
- **Consistent tagging** across Docker images

### **4. Error Handling**
- **Required parameter validation** (DATABASE_URL, NAME, etc.)
- **Helpful error messages** with examples
- **Graceful fallbacks** for missing tools

### **5. Documentation**
- **Self-documenting** help target
- **Clear usage examples** in comments
- **Service-specific** port and configuration notes

## 🔍 Troubleshooting

### **Common Issues**

#### **1. Proto Generation Fails**
```bash
# Check protoc installation
which protoc

# Reinstall Go plugins
make init

# Validate proto files
make validate
```

#### **2. OpenAPI Generation Issues**
```bash
# Check protoc-gen-openapi installation
which protoc-gen-openapi

# Reinstall plugin
go install github.com/google/gnostic/cmd/protoc-gen-openapi@latest

# Validate generated spec
make validate-openapi
```

#### **3. Migration Issues**
```bash
# Check database connection
psql "$DATABASE_URL" -c "SELECT 1;"

# Check migration status
make migrate-status DATABASE_URL="$DATABASE_URL"

# Reset if needed (caution!)
make migrate-reset DATABASE_URL="$DATABASE_URL"
```

#### **4. Cross-Platform Issues**
```bash
# Windows: Ensure Git Bash is available
where git

# Unix: Check find command
which find

# Verify proto file discovery
make validate
```

## 📚 Additional Resources

### **Tools & Dependencies**
- **protoc**: https://grpc.io/docs/protoc-installation/
- **Go plugins**: Installed via `make init`
- **golangci-lint**: https://golangci-lint.run/usage/install/
- **swagger-parser**: `npm install -g swagger-parser`
- **swagger-ui-serve**: `npm install -g swagger-ui-serve`

### **Related Documentation**
- [OpenAPI & Swagger Generation Guide](../api-specs/README.md)
- [Service Templates](../service-templates/README.md)
- [Migration Patterns](../../MIGRATION_STATUS_REPORT.md)

This standardized Makefile approach ensures consistency across all microservices while providing the flexibility needed for service-specific requirements.