# 📚 Appendix & Reference Materials

**Purpose**: Templates, checklists, references, deployment guides, and legacy documentation.

---

## � Contents

### 🚀 Deployment & Operations

| File | Description |
|------|-------------|
| **[SERVICE_DEPLOY_ORDER.md](SERVICE_DEPLOY_ORDER.md)** | **Deployment order index** — sorted wave-by-wave based on go.mod dependency graph. Use this when replacing local `replace` directives with published imports or planning a fresh cluster rollout. |

---

### 📋 Checklists

Process and quality assurance checklists in **[checklists/](checklists/)**.

| Checklist | Purpose |
|-----------|---------|
| `production-readiness.md` | Verify service is ready for production |
| `deployment-checklist.md` | Safe deployment verification steps |
| `security-checklist.md` | Security review gate |
| `code-review-checklist.md` | Code review quality standards |
| `performance-checklist.md` | Performance validation |
| `incident-response-checklist.md` | Incident response procedures |

---

### 📝 Templates

Document and process templates in **[templates/](templates/)**.

| Template | Purpose |
|----------|---------|
| `service-documentation.md` | Template for new service documentation |
| `runbook-template.md` | SRE runbook template |
| `adr-template.md` | Architecture Decision Record (ADR) template |
| `workflow-template.md` | Business workflow documentation template |
| `api-specification-template.yaml` | OpenAPI spec template |
| `event-schema-template.json` | Dapr event schema template |

---

### � References

External and industry references in **[references/](references/)**.

| Reference | Purpose |
|-----------|---------|
| `industry-standards.md` | Microservices, API design, security frameworks |
| `technology-stack.md` | Complete technology stack documentation |

---

### �️ Legacy & Archive

Historical documentation kept for context.

| Directory | Contents |
|-----------|----------|
| **[legacy/](legacy/)** | Migration notes and deprecated docs |
| **[archive/](archive/)** | Archived reference materials |

---

## � Related Docs

| Section | Link |
|---------|------|
| Architecture | [../01-architecture/](../01-architecture/) |
| Services | [../03-services/](../03-services/) |
| Operations | [../06-operations/](../06-operations/) |
| Development | [../07-development/](../07-development/) |

---

**Last Updated**: 2026-02-19
**Maintained By**: Platform Team