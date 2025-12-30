# Platform Engineering

**Last Updated**: 2025-12-30  
**Purpose**: Technical debt, infrastructure, and platform standardization tasks  
**Total Files**: 22 checklists

## 📋 Overview

This directory contains checklists and guides for infrastructure improvements, common code migration, gRPC standardization, and platform engineering tasks. These are technical debt items and standardization work separate from business logic implementation.

## 🎯 Main Focus Areas

### 1. **Common Code Consolidation**
Migrating services to use shared common packages and reducing code duplication.

- [common-code-consolidation-checklist.md](./common-code-consolidation-checklist.md)
- [common-module-consolidation-plan.md](./common-module-consolidation-plan.md)
- [common-module-standardization.md](./common-module-standardization.md)
- [common-modules-migration-guide.md](./common-modules-migration-guide.md)
- [COMMON_STANDARDIZATION_CHECKLIST.md](./COMMON_STANDARDIZATION_CHECKLIST.md)
- [COMMON_UTILS_CONSOLIDATION_ANALYSIS.md](./COMMON_UTILS_CONSOLIDATION_ANALYSIS.md)
- [COMMON_UTILS_CONSOLIDATION_IMPLEMENTATION_PLAN.md](./COMMON_UTILS_CONSOLIDATION_IMPLEMENTATION_PLAN.md)

### 2. **gRPC Migration & Standardization**
Systematic migration from HTTP to gRPC for internal service communication.

- [http-to-grpc-migration.md](./http-to-grpc-migration.md) - Comprehensive migration guide
- [grpc-client-implementation-checklist.md](./grpc-client-implementation-checklist.md) - Client implementation standards
- [grpc-client-standardization-checklist.md](./grpc-client-standardization-checklist.md) - Standardization requirements

### 3. **Infrastructure & DevOps**

- [ARGOCD_STANDARDIZATION_IMPLEMENTATION_CHECKLIST.md](./ARGOCD_STANDARDIZATION_IMPLEMENTATION_CHECKLIST.md)
- [I18N_NOTIFICATION_MIGRATION_CHECKLIST.md](./I18N_NOTIFICATION_MIGRATION_CHECKLIST.md) (79KB - comprehensive)
- [middleware-requirements-review.md](./middleware-requirements-review.md)
- [validation-framework-migration-plan.md](./validation-framework-migration-plan.md)

### 4. **Service Reviews & Testing**

- [module-path-and-tag-review.md](./module-path-and-tag-review.md)
- [service-dependencies-review.md](./service-dependencies-review.md)
- [service-specific-migration-guides.md](./service-specific-migration-guides.md)
- [common-code-testing-checklist.md](./common-code-testing-checklist.md)

### 5. **Progress Tracking**

- [consolidation-progress-review.md](./consolidation-progress-review.md)
- [progress-review-detailed.md](./progress-review-detailed.md)

### 6. **Deployment**

- [2025-12-15-deployment-ml-ranking-week1.md](./2025-12-15-deployment-ml-ranking-week1.md)

## 🗓️ Workflow

### Weekly Tasks
1. **Monday**: Review service dependencies and module paths
2. **Wednesday**: gRPC migration progress check
3. **Friday**: Consolidation progress review and sprint planning

### Monthly Tasks
1. Common code version updates
2. Full infrastructure audit
3. Performance benchmarking
4. Security review

## 🚀 Getting Started

### For New Team Members
1. Read [README.md](./README.md) (this file)
2. Review [common-modules-migration-guide.md](./common-modules-migration-guide.md)
3. Check [service-dependencies-review.md](./service-dependencies-review.md)

### For Active Development
1. Follow [http-to-grpc-migration.md](./http-to-grpc-migration.md) for ongoing migrations
2. Use [grpc-client-implementation-checklist.md](./grpc-client-implementation-checklist.md) for new clients
3. Track progress with [consolidation-progress-review.md](./consolidation-progress-review.md)

## 📊 Current Status

- **Common Code Migration**: ~70% complete
- **gRPC Migration**: ~60% complete (customer service critical path)
- **ArgoCD Standardization**: In progress
- **I18N Notifications**: Planning phase

## 🔧 Tools Required

- **Git** - Version control and tagging
- **Go** - Service development (1.21+)
- **Protocol Buffers** - gRPC definitions
- **buf** - Proto management
- **grpcurl** - gRPC testing
- **Docker** - Containerization
- **kubectl** - Kubernetes management

## 📞 Questions?

- **Technical Debt**: Platform Engineering Team
-**gRPC Migration**: Architecture Team
- **Common Code**: Backend Team Leads

---

**Last Updated:** 2025-12-30  
**Maintained By:** Platform Engineering Team  
**Review Frequency:** Weekly