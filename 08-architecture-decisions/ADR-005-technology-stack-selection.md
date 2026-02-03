# ADR-005: Technology Stack Selection (Go + go-kratos)

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** Architecture Team, CTO, Development Leads

## Context

The e-commerce platform requires a technology stack that supports:
- High concurrency (10,000+ orders/day)
- Microservices architecture (21+ services)
- Performance requirements (<100ms API response)
- Team productivity and maintainability
- Cloud-native deployment

We evaluated multiple language/framework combinations:
- **Go + go-kratos**: Native microservices support, high performance
- **Node.js + Express/Fastify**: Fast development, but single-threaded limitations
- **Java + Spring Boot**: Mature ecosystem, but higher memory footprint
- **Python + FastAPI**: Rapid development, but performance limitations

## Decision

We will use **Go 1.25.3 + go-kratos v2** as the primary technology stack for all microservices.

### Key Components:
1. **Go 1.25.3**: Core language with latest features and performance improvements
2. **go-kratos v2**: Microservices framework with built-in patterns
3. **gRPC + REST**: Dual API support via go-kratos
4. **Wire**: Dependency injection for clean architecture
5. **GORM**: ORM for database operations
6. **Gin**: HTTP framework for REST endpoints

### Technology Selection Criteria:
- **Performance**: Go's goroutines and channels for high concurrency
- **Memory Efficiency**: Lower memory footprint compared to JVM-based solutions
- **Development Speed**: Strong typing with fast compilation
- **Ecosystem**: Rich libraries for microservices patterns
- **Team Skills**: Existing Go expertise in the team
- **Deployment**: Single binary deployment, no runtime dependencies

## Consequences

### Positive:
- ✅ **High Performance**: Native concurrency with goroutines
- ✅ **Low Memory Usage**: ~50MB per service vs ~200MB for Java
- ✅ **Fast Compilation**: Quick build times for CI/CD
- ✅ **Single Binary**: Easy containerization and deployment
- ✅ **Strong Typing**: Compile-time error detection
- ✅ **Microservices Ready**: go-kratos provides built-in patterns

### Negative:
- ⚠️ **Learning Curve**: Team needs Go expertise (mitigated by training)
- ⚠️ **Ecosystem Maturity**: Fewer libraries compared to Java/Node.js
- ⚠️ **Error Handling**: Verbose error handling patterns
- ⚠️ **Generic Support**: Recent addition, not all libraries support generics

### Risks:
- **Talent Availability**: Go developers less common than Java/Node.js
- **Library Stability**: Some microservices libraries less mature
- **Debugging Complexity**: Concurrent debugging can be challenging

## Alternatives Considered

### 1. Node.js + TypeScript
- **Rejected**: Single-threaded event loop limitations for CPU-intensive tasks
- **Pros**: Fast development, large ecosystem, JavaScript familiarity
- **Cons**: Memory leaks, callback hell, performance limitations

### 2. Java + Spring Boot
- **Rejected**: Higher memory footprint, slower startup times
- **Pros**: Mature ecosystem, enterprise support, extensive libraries
- **Cons**: Complex configuration, slower development cycle

### 3. Python + FastAPI
- **Rejected**: Performance limitations for high-throughput services
- **Pros**: Rapid development, easy to learn, great for ML integration
- **Cons**: GIL limitations, higher memory usage, slower execution

## Implementation Guidelines

- All services must use Go 1.25.3 (specified in go.mod)
- Use go-kratos v2 for microservices patterns (gRPC + HTTP)
- Follow Go project layout standards
- Implement proper error handling with structured logging
- Use dependency injection (Wire) for testability
- Write comprehensive unit and integration tests

## References

- [Go Documentation](https://golang.org/doc/)
- [go-kratos Framework](https://go-kratos.dev/)
- [Go vs Node.js Performance Comparison](https://benchmarksgame.alioth.debian.org/)
- [Microservices in Go](https://microservices.io/patterns/languages/go.html)
