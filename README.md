# 📚 Project Documentation Home

> **Generated: Nov 2025. Welcome to the new docs ecosystem, designed for enterprise e-commerce best practice (Shopify, Amazon, PayPal standards).**

## 🚀 Where to Find What (Index)

- **API Contract (OpenAPI):** [`./openapi/`](./openapi/) – REST/gRPC/GraphQL API for each service. One OpenAPI file per service.
- **Event Contracts (JSON Schema):** [`./json-schema/`](./json-schema/) – All event message schemas, validated automatically, used for codegen/testing.
- **Architecture Decisions (ADR):** [`./adr/`](./adr/) – Major technical decisions, rationale, alternatives, consequences. Follow [ADR format](https://adr.github.io/).
- **Technical Design Docs:** [`./design/`](./design/) – Feature/service design, RFC style (Google/Shopify), discuss/review here before implementation!
- **SRE Runbooks:** [`./sre-runbooks/`](./sre-runbooks/) – All ops/on-call/resilience guides, instant troubleshooting.
- **Domain-Driven-Design (DDD), Context Map:** [`./ddd/`](./ddd/) – Full domain maps, bounded contexts, glossary.
- **Glossary:** [`./glossary.md`](./glossary.md) – Shared terms, enum values, event types, domain definitions.
- **Templates:** [`./templates/`](./templates/) – Standardized templates for all documentation types (services, events, workflows).
- **Business Processes:** [`./processes/`](./processes/) – E-commerce business process documentation with event flows, flowcharts, and service interactions.

---

## 📝 How to Use and Contribute

1. **New Service:** Use templates from [`templates/`](./templates/) to create service documentation, OpenAPI spec, and runbook.
2. **API Change:** Add/edit OpenAPI spec and PR. Validate with CI. Use [API change template](./templates/api-change-template.md).
3. **Event Change:** Add/edit JSON schema, update handlers/contracts. Use [event change template](./templates/event-change-template.md).
4. **Major Technical Choice:** Write an ADR and PR. Use [ADR template](./adr/ADR-template.md).
5. **Feature:** Submit a Design Doc (Google RFC style) in `design/` before starting work. Use [design template](./design/feature-design-template.md).
6. **Domain Change:** Update Context Map or DDD docs.
7. **Ops/Prod:** Always update runbook after incident/root cause analysis. Use [runbook template](./templates/service-runbook-template.md).
8. **Glossary:** Update when a new term/event/domain/entity is named across teams.

---

## 🏛️ Best Practices
- **Use Templates:** Always start from templates in [`templates/`](./templates/) directory.
- **Review:** All docs must be reviewed by at least one peer before merge.
- **Version:** Always date or version files for easy audit.
- **DO NOT** remove anything from `/backup-YYYY-MM-DD/` without approve.
- **Keep all API/Event contracts machine readable (YAML/JSON).**
- **Quick Reference:** See [`templates/QUICK_REFERENCE.md`](./templates/QUICK_REFERENCE.md) for copy-paste commands.

---

**For detailed standards, see Shopify/Amazon/Pan-PayPal architecture guides, or ask principal engineers for mentoring.**
