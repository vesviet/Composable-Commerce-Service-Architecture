# 📋 Documentation Templates

This directory contains standardized templates for all documentation types in the project.

## 📁 Template Structure

### Service Documentation Templates
- **`service-documentation-template.md`** - Complete service documentation template
- **`service-openapi-template.yaml`** - OpenAPI 3.0 template for service APIs
- **`service-runbook-template.md`** - SRE runbook template for operations

### Event Contract Templates
- **`event-schema-template.json`** - JSON Schema template for events (CloudEvents format, Dapr Pub/Sub)
- **`kafka-event-template.json`** - JSON Schema template for Kafka events (with partition key)
- **`event-contract-template.md`** - Event contract documentation template
- **`dapr-subscription-template.yaml`** - Dapr subscription configuration template

### Development Workflow Templates
- **`feature-branch-template.md`** - Feature development workflow
- **`api-change-template.md`** - API change request template
- **`event-change-template.md`** - Event contract change template
- **`bug-report-template.md`** - Bug report template
- **`kafka-event-template.json`** - Kafka event schema template (alternative to Dapr)

### Service-Specific Templates
- **`order-service-template.md`** - Order service documentation template
- **`payment-service-template.md`** - Payment service documentation template
- **`shipping-service-template.md`** - Shipping service documentation template
- **`warehouse-service-template.md`** - Warehouse/Inventory service documentation template
- **`catalog-service-template.md`** - Catalog service documentation template
- **`customer-service-template.md`** - Customer service documentation template
- **`pricing-service-template.md`** - Pricing service documentation template
- **`promotion-service-template.md`** - Promotion service documentation template
- **`fulfillment-service-template.md`** - Fulfillment service documentation template
- **`auth-service-template.md`** - Auth service documentation template
- **`user-service-template.md`** - User service documentation template
- **`notification-service-template.md`** - Notification service documentation template
- **`search-service-template.md`** - Search service documentation template
- **`review-service-template.md`** - Review service documentation template
- **`loyalty-rewards-service-template.md`** - Loyalty Rewards service documentation template

## 🚀 Quick Start

1. **Creating a new service documentation:**
   ```bash
   cp templates/service-documentation-template.md docs/services/my-service.md
   cp templates/service-openapi-template.yaml docs/openapi/my-service.openapi.yaml
   cp templates/service-runbook-template.md docs/sre-runbooks/my-service-runbook.md
   ```

2. **Creating a new event contract:**
   ```bash
   cp templates/event-schema-template.json docs/json-schema/my-event.schema.json
   cp templates/event-contract-template.md docs/events/my-event.md
   ```

3. **Creating a feature design:**
   ```bash
   cp docs/design/feature-design-template.md docs/design/2025-11-my-feature-design.md
   ```

## 📝 Usage Guidelines

- **Always use templates** when creating new documentation
- **Fill in all required sections** marked with `[REQUIRED]`
- **Remove placeholder text** marked with `[PLACEHOLDER]`
- **Follow naming conventions** as specified in each template
- **Review before committing** - all docs must be peer-reviewed

## 🔗 Related Documentation

- [Main Documentation Index](../README.md)
- [OpenAPI Guidelines](../openapi/README.md)
- [Event Contract Guidelines](../json-schema/README.md)
- [ADR Guidelines](../adr/README.md)
- [Design Doc Guidelines](../design/README.md)
- [SRE Runbook Guidelines](../sre-runbooks/README.md)

