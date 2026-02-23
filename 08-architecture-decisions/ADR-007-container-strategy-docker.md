# ADR-007: Container Strategy (Multi-stage Docker builds)

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** DevOps Team, Security Team, Development Team

## Context

With 21+ microservices to containerize, we need a strategy that addresses:
- Build optimization and speed
- Security and minimal attack surface
- Image size and storage efficiency
- Consistency across all services
- CI/CD pipeline integration
- Development and production parity

We evaluated several containerization approaches:
- **Multi-stage Docker builds**: Separate build and runtime stages
- **Single-stage builds**: Build and run in same container
- **Build systems**: Bazel, Pants, or other build tools
- **Base images**: Alpine, Ubuntu, Distinctless, Scratch

## Decision

We will use **multi-stage Docker builds with Alpine Linux base** for all microservices.

### Build Strategy:
1. **Builder Stage**: Golang 1.25.3 with build tools and dependencies
2. **Runtime Stage**: Alpine Linux minimal base with compiled binaries
3. **Optimization**: Static linking, binary stripping, layer optimization

### Dockerfile Pattern:
```dockerfile
# Build stage
FROM golang:1.25.3-alpine AS builder
# Install build dependencies, compile Go binaries

# Runtime stage  
FROM alpine:latest
# Copy only compiled binaries and essential files
```

### Key Optimizations:
- **Static Compilation**: CGO_ENABLED=0 for single binary deployment
- **Binary Stripping**: `-ldflags "-w -s"` to reduce binary size
- **Layer Caching**: Optimize COPY order for better Docker layer caching
- **Security**: Minimal Alpine base with only required packages
- **Multi-architecture**: Support for amd64, arm64 if needed

### Build Targets:
- **Main Binary**: Primary service binary (e.g., `auth`, `order`)
- **Migration Binary**: Database migration tool (`migrate`)
- **Worker Binary**: Background job processor (`worker`) if applicable

## Consequences

### Positive:
- ✅ **Small Image Size**: ~20MB runtime vs ~200MB for full build environment
- ✅ **Security**: Minimal attack surface with Alpine base
- ✅ **Fast Deployment**: Smaller images = faster pulls and deployments
- ✅ **Consistency**: Standardized pattern across all services
- ✅ **Development Efficiency**: Fast iteration with layer caching
- ✅ **Production Ready**: Optimized for production deployment

### Negative:
- ⚠️ **Build Complexity**: Multi-stage adds complexity to Dockerfiles
- ⚠️ **Debugging Limitations**: No build tools in runtime container
- ⚠️ **Alpine Compatibility**: Some libraries require glibc (musl vs glibc)
- ⚠️ **Build Time**: Initial build takes longer due to multiple stages

### Risks:
- **Alpine Issues**: Musl libc compatibility problems with some Go packages
- **Debugging Difficulty**: Cannot debug in runtime container
- **Build Failures**: Multi-stage builds can fail at different stages

## Alternatives Considered

### 1. Single-stage Docker builds
- **Rejected**: Larger images, security risks, build tools in production
- **Pros**: Simpler Dockerfiles, easier debugging
- **Cons**: Larger image size, security vulnerabilities, slower deployment

### 2. Ubuntu-based images
- **Rejected**: Larger size (~100MB+), more security vulnerabilities
- **Pros**: Better compatibility, easier debugging
- **Cons**: Larger attack surface, slower deployment

### 3. Scratch images
- **Rejected**: Too minimal, no CA certificates, debugging impossible
- **Pros**: Smallest possible image size
- **Cons**: No shell, no package manager, difficult troubleshooting

### 4. Build systems (Bazel/Pants)
- **Rejected**: Too complex for current team size and needs
- **Pros**: Advanced caching, reproducible builds
- **Cons**: Steep learning curve, overkill for our scale

## Implementation Guidelines

- Use multi-stage Dockerfiles for all services
- Base runtime on Alpine Linux latest stable
- Enable static compilation with CGO_ENABLED=0
- Strip binaries to reduce size (`-ldflags "-w -s"`)
- Optimize layer caching (COPY dependencies first)
- Include health checks in Docker images
- Use specific image tags (not `latest`) for reproducibility
- Implement security scanning in CI/CD pipeline
- Document any special Alpine compatibility requirements

## References

- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Alpine Linux Best Practices](https://wiki.alpinelinux.org/wiki/Alpine_Linux:FAQ)
- [Go Docker Best Practices](https://github.com/golang/go/wiki/Docker)
- [Container Security Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
