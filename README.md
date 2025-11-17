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

---

## 📝 How to Use and Contribute

1. **API Change:** Add/edit OpenAPI spec and PR. Validate with CI.
2. **Event Change:** Add/edit JSON schema, update handlers/contracts.
3. **Major Technical Choice:** Write an ADR and PR. Example file in [adr/](./adr/).
4. **Feature:** Submit a Design Doc (Google RFC style) in `design/` before starting work.
5. **Domain Change:** Update Context Map or DDD docs.
6. **Ops/Prod:** Always update runbook after incident/root cause analysis.
7. **Glossary:** Update when a new term/event/domain/entity is named across teams.

---

## 🏛️ Best Practices
- **Review:** All docs must be reviewed by at least one peer before merge.
- **Version:** Always date or version files for easy audit.
- **DO NOT** remove anything from `/backup-YYYY-MM-DD/` without approve.
- **Keep all API/Event contracts machine readable (YAML/JSON).**
- See example template inside each relevant directory for quick-start.

---

**For detailed standards, see Shopify/Amazon/Pan-PayPal architecture guides, or ask principal engineers for mentoring.**
