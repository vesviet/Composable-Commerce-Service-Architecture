# 🔄 Migration Guides

**Purpose**: Migration procedures, platform consolidation, and Magento migration documentation  
**Last Updated**: 2026-03-02

---

## 📋 Overview

This section contains migration guides for the microservices platform — how to migrate **from Magento** and how to consolidate/standardize services with the **common library**.

---

## 📚 Available Guides

### 🛍️ Magento Migration (3-Phase)
Complete guide for migrating from Magento to microservices with zero-downtime.

- **[Magento Migration Overview](./magento-migration/)** — Strategy, timeline, architecture
- **[Phase 1: Read-Only](./magento-migration/phase-1-read-only.md)** — Gateway routing, CDC sync
- **[Phase 2: Read-Write](./magento-migration/phase-2-read-write.md)** — Dual-write with Dapr PubSub
- **[Phase 3: Full Cutover](./magento-migration/phase-3-full-cutover.md)** — Complete migration
- **[Data Migration Guide](./magento-migration/data-migration-guide.md)** — EAV extraction, ID mapping
- **[Sync Service](./magento-migration/sync-service-implementation.md)** — CDC engine implementation
- **[Step-by-Step](./magento-migration/step-by-step-migration.md)** — Detailed procedures

### 🔧 Platform Consolidation
- **[Consolidation Implementation Guide](./CONSOLIDATION_IMPLEMENTATION_GUIDE.md)** — Common library patterns (health checks, DB connections, config, HTTP clients, event publishing)

### ☸️ Kubernetes
- **[K8S Migration Quick Guide](./K8S_MIGRATION_QUICK_GUIDE.md)** — k3d config standardization templates

---

## 🔗 Related Documentation

- **[Architecture](../01-architecture/README.md)** — System architecture
- **[Operations](../06-operations/README.md)** — Platform operations  
- **[Development](../07-development/README.md)** — Development standards
- **[Services](../03-services/README.md)** — Individual service documentation

---

**Last Updated**: March 2, 2026  
**Maintained By**: Platform Engineering Team