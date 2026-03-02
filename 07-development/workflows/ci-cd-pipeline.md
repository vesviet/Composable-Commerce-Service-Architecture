# CI/CD Pipeline Flow

**Purpose**: Detail the automated quality, security, and deployment pipelines.  
**Audience**: Developers and DevOps engineers.

---

## 🚀 Overview

Our CI/CD process is fully automated via **GitLab CI/CD**. There is strict segregation between code integration (pushing to branches) and deployment (managed by ArgoCD).

The pipeline enforces the rules laid out in the [Development Review Checklist](../standards/development-review-checklist.md) and [Coding Standards](../standards/coding-standards.md).

---

## 🛠️ Pipeline Stages

A standard run on a feature branch (`feature/*`) or `develop` / `main` triggers the following stages:

### Stage 1: Validation & Linting (`.pre`)
- **Action**: Runs `golangci-lint run` and validates `go.mod`.
- **Criteria**: **Zero warnings allowed.** Any failing linter check breaks the build immediately.
- **Action (Proto)**: Checks if `make api` and `wire` were run. If there are uncommitted auto-generated files, the build fails.

### Stage 2: Unit Testing (`test`)
- **Action**: Runs `go test ./... -coverprofile=coverage.out` using Testcontainers for DB dependencies.
- **Criteria**: Code coverage must be **>= 80%** for business logic (`internal/biz`). If coverage drops below the threshold, the pipeline fails.

### Stage 3: Security Scanning (`security`)
- **Action**: Runs static application security testing (SAST) via `gosec` and dependency scanning via `govulncheck`.
- **Criteria**: Fails if **High** or **Critical** vulnerabilities are found.

### Stage 4: Docker Build & Push (`build`)
*(Only triggers on Merge to `develop`, Merge to `main`, or Tagged Releases)*
- **Action**: Builds the Docker image for the service using the multistage Dockerfile.
- **Action**: Tags the image with the short Git commit SHA (e.g., `abc1234`) or the SemVer tag (`v1.x.y`).
- **Action**: Pushes the image to the remote container registry.

### Stage 5: GitOps Trigger (`deploy`)
*(Only triggers after successful `build`)*
- **Action**: The CI pipeline clones the `gitops` repository.
- **Action**: Runs Kustomize commands or `sed` to update the `newTag` value in `gitops/apps/<service>/overlays/<env>/kustomization.yaml` to match the newly built Docker tag.
- **Action**: Commits and pushes the change to the `gitops` repository.
- **Result**: **ArgoCD** detects the change in the `gitops` repository and handles the rolling update in the Kubernetes cluster automatically.

---

## 🚦 Pipeline Triggers

| Event | Pipeline Stages Executed | Target Environment |
|-------|--------------------------|--------------------|
| **Push to `feature/*`** | Lint, Test, Security | None (Validates MR) |
| **Merge to `develop`**  | Lint, Test, Security, Build, GitOps Trigger | Staging (`dev` cluster) |
| **Merge to `main`**     | Lint, Test, Security | None (Prepares for Tag/Release) |
| **Push Tag `v*.*.*`**   | Lint, Test, Security, Build, GitOps Trigger | Production (`prod` cluster) |

## 🔗 Related Workflows
- [Git Workflow](./git-workflow.md)
- [Release Process](./release-process.md)
