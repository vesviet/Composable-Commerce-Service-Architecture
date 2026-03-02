# 📋 Architecture Decision Records (ADR)

**Purpose**: Document major architectural and technical decisions  
**Format**: One ADR per decision with context, rationale, and consequences  
**Navigation**: [← Back to Main](../README.md) | [Architecture →](../01-architecture/README.md)

---

## 📖 What are ADRs?

Architecture Decision Records (ADRs) document significant architectural and technical decisions made during the development of the microservices platform. Each ADR captures:

- **Context**: Why the decision was needed
- **Decision**: What was decided and why
- **Consequences**: Trade-offs, benefits, and risks
- **Alternatives**: Other options considered and why they were rejected

---

## 📚 ADR Index

### 🏗️ Architecture & Design (ADR-001 to ADR-004)

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-001](ADR-001-event-driven-architecture.md) | Event-Driven Architecture for Transactional Events | 2025-11-17 | ✅ Accepted |
| [ADR-002](ADR-002-microservices-architecture.md) | Microservices Architecture | 2026-02-03 | ✅ Accepted |
| [ADR-003](ADR-003-dapr-vs-redis-streams.md) | Dapr vs Redis Streams | 2026-02-03 | ✅ Accepted |
| [ADR-004](ADR-004-database-per-service.md) | Database Per Service Pattern | 2026-02-03 | ✅ Accepted |

### 🛠️ Technology Stack (ADR-005 to ADR-007)

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-005](ADR-005-technology-stack-selection.md) | Technology Stack Selection (Go + go-kratos) | 2026-02-03 | ✅ Accepted |
| [ADR-006](ADR-006-service-discovery-consul.md) | Service Discovery with Consul | 2026-02-03 | ✅ Accepted |
| [ADR-007](ADR-007-container-strategy-docker.md) | Container Strategy with Docker | 2026-02-03 | ✅ Accepted |

### 🚀 Deployment & Operations (ADR-008 to ADR-010)

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-008](ADR-008-cicd-pipeline-gitlab-ci.md) | CI/CD Pipeline Architecture (GitLab CI) | 2026-02-03 | ✅ Accepted |
| [ADR-009](ADR-009-kubernetes-deployment-argocd.md) | Kubernetes Deployment Strategy (ArgoCD + K3d) | 2026-02-03 | ✅ Accepted |
| [ADR-010](ADR-010-observability-prometheus-jaeger.md) | Observability Stack (Prometheus + Jaeger) | 2026-02-03 | ✅ Accepted |

### 🔌 APIs & Integration (ADR-011 to ADR-013)

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-011](ADR-011-api-design-patterns-grpc-rest.md) | API Design Patterns (gRPC + REST) | 2026-02-03 | ✅ Accepted |
| [ADR-012](ADR-012-search-architecture-elasticsearch.md) | Search Architecture with Elasticsearch | 2026-02-03 | ✅ Accepted |
| [ADR-013](ADR-013-authentication-authorization-strategy.md) | Authentication & Authorization Strategy | 2026-02-03 | ✅ Accepted |

### ⚙️ Configuration & Data (ADR-014 to ADR-015)

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-014](ADR-014-configuration-management.md) | Configuration Management | 2026-02-03 | ✅ Accepted |
| [ADR-015](ADR-015-database-migration-strategy.md) | Database Migration Strategy | 2026-02-03 | ✅ Accepted |

### 💻 Frontend & Development (ADR-016 to ADR-020)

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-016](ADR-016-frontend-architecture-react.md) | Frontend Architecture (React + Next.js) | 2026-02-03 | ✅ Accepted |
| [ADR-017](ADR-017-common-library-architecture.md) | Common Library Architecture | 2026-02-03 | ✅ Accepted |
| [ADR-018](ADR-018-local-development-environment.md) | Local Development Environment | 2026-02-03 | ✅ Accepted |
| [ADR-019](ADR-019-logging-strategy.md) | Logging Strategy | 2026-02-03 | ✅ Accepted |
| [ADR-020](ADR-020-error-handling-resilience.md) | Error Handling & Resilience | 2026-02-03 | ✅ Accepted |

### 📦 Data & Domain (ADR-021 to ADR-024)

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| [ADR-021](ADR-021-price-stock-data-ownership.md) | Price & Stock Data Ownership | 2026-02-12 | ✅ Accepted |
| [ADR-022](ADR-022-dynamic-sql-pivoting-for-eav.md) | Dynamic SQL Pivoting for EAV | 2026-03-02 | ✅ Accepted |
| [ADR-023](ADR-023-standardized-caching-worker-patterns.md) | Standardized Caching and Worker Patterns | 2026-03-02 | ✅ Accepted |
| [ADR-024](ADR-024-inventory-data-ownership.md) | Inventory Data Ownership | 2026-03-02 | ✅ Accepted |

---

## 📊 ADR Statistics

- **Total ADRs**: 24
- **Accepted**: 24 (100%)
- **Proposed**: 0
- **Rejected**: 0
- **Superseded**: 0

### By Category
- **Architecture & Design**: 4 ADRs
- **Technology Stack**: 3 ADRs
- **Deployment & Operations**: 3 ADRs
- **APIs & Integration**: 3 ADRs
- **Configuration & Data**: 2 ADRs
- **Frontend & Development**: 5 ADRs
- **Data & Domain**: 4 ADRs

---

## 🎯 Key Architectural Decisions

### Core Technology Choices

1. **Language & Framework**: Go 1.25.3 + go-kratos v2
2. **Architecture Pattern**: Event-driven microservices
3. **Communication**: Dapr Pub/Sub with Redis Streams
4. **Database**: PostgreSQL per service + Redis for caching
5. **Service Discovery**: Consul
6. **Container Platform**: Docker + Kubernetes
7. **GitOps**: ArgoCD with Kustomize
8. **CI/CD**: GitLab CI with reusable templates
9. **Observability**: Prometheus + Grafana + Jaeger
10. **API Design**: gRPC + REST (dual protocol)

### Design Principles

- **Event-First**: Events as first-class citizens
- **Database Per Service**: Data isolation and autonomy
- **GitOps**: Git as single source of truth
- **Configuration as Code**: Declarative configuration
- **Observability Built-in**: Metrics, logs, traces from day one

---

## 📝 How to Create a New ADR

### Step 1: Copy Template
```bash
cp docs/08-architecture-decisions/ADR-template.md \
   docs/08-architecture-decisions/ADR-XXX-your-decision.md
```

### Step 2: Fill Required Sections

```markdown
# ADR-XXX: Title of Decision

**Date:** YYYY-MM-DD  
**Status:** Proposed  
**Deciders:** Team names

## Context
Why is this decision needed? What problems are we solving?

## Decision
What are we deciding? What solution did we choose?

## Consequences
What are the trade-offs, benefits, and risks?

## Alternatives Considered
What other options did we evaluate and why were they rejected?

## Implementation Guidelines
How should this decision be implemented?

## References
Links to relevant documentation and resources
```

### Step 3: Review Process

1. **Draft**: Create ADR with status "Proposed"
2. **Review**: Share with relevant teams for feedback
3. **Discussion**: Address concerns and questions
4. **Approval**: Get sign-off from principal engineer(s)
5. **Accept**: Update status to "Accepted" and merge
6. **Update Index**: Add to this README.md

### Step 4: Peer Review Requirements

- ✅ At least 1 principal engineer approval
- ✅ Relevant team leads consulted
- ✅ Security review (if applicable)
- ✅ Performance implications considered
- ✅ Cost implications documented

---

## 🔄 ADR Lifecycle

### Status Values

- **Proposed**: Under discussion, not yet decided
- **Accepted**: Decision made and approved
- **Rejected**: Considered but not chosen
- **Superseded**: Replaced by a newer ADR
- **Deprecated**: No longer applicable

### When to Create an ADR

Create an ADR when making decisions about:

- ✅ **Architecture Patterns**: Microservices, event-driven, CQRS
- ✅ **Technology Selection**: Languages, frameworks, databases
- ✅ **Infrastructure**: Kubernetes, cloud providers, networking
- ✅ **Security**: Authentication, authorization, encryption
- ✅ **Performance**: Caching strategies, optimization approaches
- ✅ **Integration**: API design, communication patterns
- ✅ **Development**: Build tools, testing strategies, workflows

### When NOT to Create an ADR

Don't create ADRs for:

- ❌ **Implementation Details**: Code-level decisions
- ❌ **Temporary Solutions**: Short-term workarounds
- ❌ **Obvious Choices**: Industry-standard practices
- ❌ **Reversible Decisions**: Easy to change later

---

## 📚 ADR Best Practices

### Writing Guidelines

1. **Be Concise**: Keep ADRs focused and readable
2. **Provide Context**: Explain why the decision was needed
3. **Document Alternatives**: Show what else was considered
4. **Include Trade-offs**: Be honest about consequences
5. **Add References**: Link to relevant documentation
6. **Use Examples**: Provide concrete examples where helpful

### Maintenance Guidelines

1. **Keep Updated**: Update ADRs when circumstances change
2. **Link Related ADRs**: Reference related decisions
3. **Supersede When Needed**: Create new ADR to replace old ones
4. **Archive Deprecated**: Mark old ADRs as superseded
5. **Review Regularly**: Quarterly review of all ADRs

---

## 🔗 Related Documentation

- **[Architecture Overview](../01-architecture/README.md)** - System architecture documentation
- **[GitOps Migration](../01-architecture/gitops-migration.md)** - GitOps migration guide
- **[Service Index](../SERVICE_INDEX.md)** - Complete service catalog
- **[Development Guide](../07-development/README.md)** - Development standards

---

## 📞 Support

### Questions About ADRs?

- **Architecture Team**: For architectural decisions
- **Platform Team**: For infrastructure and deployment decisions
- **Development Team**: For technology and framework decisions

### How to Propose a New ADR

1. Create a draft ADR using the template
2. Share in #architecture channel for discussion
3. Schedule architecture review meeting if needed
4. Get required approvals
5. Merge and update this index

---

## 📈 Recent Updates

### February 2026
- ✅ Updated ADR-009 for GitOps migration to Kustomize
- ✅ Standardized ADR format across all documents
- ✅ Added comprehensive ADR index and statistics
- ✅ Improved README with guidelines and best practices

### January 2026
- ✅ Created 20 initial ADRs covering core decisions
- ✅ Established ADR template and process
- ✅ Set up review and approval workflow

---

**Last Updated**: March 2, 2026  
**Total ADRs**: 24  
**Maintained By**: Architecture Team  
**Review Cycle**: Quarterly

## 📋 Template

See [ADR-template.md](ADR-template.md) for the standard ADR template.
