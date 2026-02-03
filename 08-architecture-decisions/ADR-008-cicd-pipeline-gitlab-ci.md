# ADR-008: CI/CD Pipeline Architecture (GitLab CI + Templates)

**Date:** 2026-02-03  
**Status:** Accepted  
**Deciders:** DevOps Team, Development Team, QA Team

## Context

With 21+ microservices, we need a CI/CD strategy that provides:
- Consistent build and deployment across all services
- Efficient pipeline execution and resource usage
- Proper testing and quality gates
- Environment promotion (dev → staging → production)
- Automated dependency management
- Rollback capabilities

We evaluated several CI/CD solutions:
- **GitLab CI**: Integrated with our GitLab instance, YAML-based pipelines
- **GitHub Actions**: External CI/CD, would require migration
- **Jenkins**: Self-hosted, high maintenance overhead
- **CircleCI**: External service, additional cost

## Decision

We will use **GitLab CI with reusable templates** for all microservices CI/CD pipelines.

### Pipeline Architecture:
1. **GitLab CI**: Primary CI/CD platform integrated with GitLab
2. **Reusable Templates**: Common pipeline definitions in `gitlab-ci-templates/`
3. **Service-Specific**: Individual `.gitlab-ci.yml` per service
4. **Environment Promotion**: Automated promotion through environments
5. **Docker Registry**: GitLab Container Registry for image storage

### Template Structure:
```
gitlab-ci-templates/
├── templates/
│   ├── build-image.yaml          # Docker build and push
│   ├── lint-test.yaml            # Code quality and testing
│   ├── security-scan.yaml        # Security vulnerability scanning
│   ├── deploy-k8s.yaml           # Kubernetes deployment
│   └── update-image-tag.yaml     # GitOps updates
└── .gitlab-ci.yml               # Template composition
```

### Pipeline Stages:
1. **🔍 Validate**: Lint, code quality, security scanning
2. **🏗️ Build**: Compile Go code, build Docker images
3. **🧪 Test**: Unit tests, integration tests, contract tests
4. **📦 Package**: Push Docker images to registry
5. **🚀 Deploy**: Deploy to environments (dev/staging/prod)
6. **🔗 Update**: Update GitOps repositories with new image tags

### Key Features:
- **Template Reuse**: Common patterns defined once, used by all services
- **Parallel Execution**: Multiple services can build simultaneously
- **Resource Optimization**: Docker-in-Docker with proper caching
- **Security Integration**: Automated security scanning and dependency checks
- **GitOps Integration**: Automatic ArgoCD application updates

## Consequences

### Positive:
- ✅ **Consistency**: All services use same pipeline patterns
- ✅ **Efficiency**: Template reuse reduces duplication and maintenance
- ✅ **Integration**: Native GitLab integration with our existing setup
- ✅ **Scalability**: Can handle 21+ services with parallel execution
- ✅ **Security**: Built-in security scanning and dependency checks
- ✅ **GitOps Ready**: Automatic updates to deployment manifests

### Negative:
- ⚠️ **GitLab Dependency**: Tied to GitLab platform
- ⚠️ **Runner Management**: Need to maintain GitLab runners
- ⚠️ **Pipeline Complexity**: Multiple stages and templates add complexity
- ⚠️ **Resource Usage**: CI/CD can consume significant resources

### Risks:
- **Runner Bottlenecks**: Too many concurrent builds can overwhelm runners
- **Pipeline Failures**: Template changes can affect all services
- **Security Scanning**: False positives/negatives in security scans
- **GitOps Conflicts**: Concurrent updates to deployment manifests

## Alternatives Considered

### 1. GitHub Actions
- **Rejected**: Would require migration from GitLab, additional cost
- **Pros**: Large marketplace, good UI, external runners
- **Cons**: Migration effort, additional licensing costs

### 2. Jenkins with Shared Libraries
- **Rejected**: High maintenance overhead, complex setup
- **Pros**: Highly customizable, large plugin ecosystem
- **Cons**: Groovy-based, maintenance burden, security concerns

### 3. CircleCI
- **Rejected**: External service, additional cost, less integration
- **Pros**: Fast execution, good UI, Docker support
- **Cons**: Additional licensing, less control over infrastructure

### 4. Spinnaker
- **Rejected**: Overkill for current needs, complex setup
- **Pros**: Advanced deployment strategies, multi-cloud support
- **Cons**: Complex, resource-intensive, steep learning curve

## Implementation Guidelines

- All services must include the base template from `gitlab-ci-templates/`
- Use semantic versioning for Docker image tags
- Implement proper caching for Go modules and Docker layers
- Configure environment-specific variables and secrets
- Use GitLab protected environments for production deployments
- Implement manual approval gates for production deployments
- Monitor pipeline performance and optimize runner allocation
- Regularly update templates and dependencies

## References

- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab CI Templates](https://docs.gitlab.com/ee/ci/yaml/#includefile)
- [GitOps with GitLab and ArgoCD](https://docs.gitlab.com/ee/ci/examples/gitops/)
- [CI/CD Best Practices](https://about.gitlab.com/topics/ci-cd/)
