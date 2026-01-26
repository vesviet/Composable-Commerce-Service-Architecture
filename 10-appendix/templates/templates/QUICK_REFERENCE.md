# Templates Quick Reference

Quick copy-paste commands for common documentation tasks.

## 🚀 Service Documentation

### Create Complete Service Documentation

```bash
SERVICE_NAME="my-service"
HTTP_PORT="8000"
GRPC_PORT="9000"

# Service documentation
cp templates/service-documentation-template.md docs/services/${SERVICE_NAME}.md
sed -i "s/{Service Name}/${SERVICE_NAME^}/g" docs/services/${SERVICE_NAME}.md
sed -i "s/{service-name}/${SERVICE_NAME}/g" docs/services/${SERVICE_NAME}.md
sed -i "s/{HTTP Port}/${HTTP_PORT}/g" docs/services/${SERVICE_NAME}.md
sed -i "s/{gRPC Port}/${GRPC_PORT}/g" docs/services/${SERVICE_NAME}.md

# OpenAPI spec
cp templates/service-openapi-template.yaml docs/openapi/${SERVICE_NAME}.openapi.yaml
sed -i "s/{Service Name}/${SERVICE_NAME^}/g" docs/openapi/${SERVICE_NAME}.openapi.yaml
sed -i "s/{service-name}/${SERVICE_NAME}/g" docs/openapi/${SERVICE_NAME}.openapi.yaml
sed -i "s/{http-port}/${HTTP_PORT}/g" docs/openapi/${SERVICE_NAME}.openapi.yaml

# Runbook
cp templates/service-runbook-template.md docs/sre-runbooks/${SERVICE_NAME}-runbook.md
sed -i "s/{Service Name}/${SERVICE_NAME^}/g" docs/sre-runbooks/${SERVICE_NAME}-runbook.md
sed -i "s/{service-name}/${SERVICE_NAME}/g" docs/sre-runbooks/${SERVICE_NAME}-runbook.md
sed -i "s/{HTTP Port}/${HTTP_PORT}/g" docs/sre-runbooks/${SERVICE_NAME}-runbook.md
sed -i "s/{gRPC Port}/${GRPC_PORT}/g" docs/sre-runbooks/${SERVICE_NAME}-runbook.md
```

## 📨 Event Contract

### Create New Event Contract

```bash
EVENT_TYPE="order.created"
SERVICE_NAME="order"
DOMAIN="order"
ACTION="created"
VERSION="1.0.0"

# Event schema (CloudEvents format)
cp templates/event-schema-template.json docs/json-schema/${EVENT_TYPE}.schema.json
sed -i "s/{event-name}/${EVENT_TYPE}/g" docs/json-schema/${EVENT_TYPE}.schema.json
sed -i "s/{version}/${VERSION}/g" docs/json-schema/${EVENT_TYPE}.schema.json
sed -i "s/{service}.{domain}.{action}/${SERVICE_NAME}.${DOMAIN}.${ACTION}/g" docs/json-schema/${EVENT_TYPE}.schema.json
sed -i "s/{service-name}/${SERVICE_NAME}/g" docs/json-schema/${EVENT_TYPE}.schema.json

# Event contract documentation
cp templates/event-contract-template.md docs/events/${EVENT_TYPE}.md
sed -i "s/{event-type}/${EVENT_TYPE}/g" docs/events/${EVENT_TYPE}.md
sed -i "s/{version}/${VERSION}/g" docs/events/${EVENT_TYPE}.md
sed -i "s/{service}.{domain}.{action}/${SERVICE_NAME}.${DOMAIN}.${ACTION}/g" docs/events/${EVENT_TYPE}.md

# Dapr subscription
cp templates/dapr-subscription-template.yaml ${SERVICE_NAME}/components/${EVENT_TYPE}-subscription.yaml
sed -i "s/{service-name}/${SERVICE_NAME}/g" ${SERVICE_NAME}/components/${EVENT_TYPE}-subscription.yaml
sed -i "s/{event-type}/${EVENT_TYPE}/g" ${SERVICE_NAME}/components/${EVENT_TYPE}-subscription.yaml
```

## 🏗️ Architecture Decision

### Create New ADR

```bash
ADR_NUMBER="005"
DECISION_NAME="use-redis-cluster"
DATE=$(date +%Y-%m-%d)

cp docs/adr/ADR-template.md docs/adr/ADR-${ADR_NUMBER}-${DECISION_NAME}.md
sed -i "s/{number}/${ADR_NUMBER}/g" docs/adr/ADR-${ADR_NUMBER}-${DECISION_NAME}.md
sed -i "s/{decision-name}/${DECISION_NAME}/g" docs/adr/ADR-${ADR_NUMBER}-${DECISION_NAME}.md
sed -i "s/{YYYY-MM-DD}/${DATE}/g" docs/adr/ADR-${ADR_NUMBER}-${DECISION_NAME}.md
```

## 📋 Feature Design

### Create Feature Design Document

```bash
FEATURE_NAME="new-checkout-flow"
DATE=$(date +%Y-%m)

cp docs/design/feature-design-template.md docs/design/${DATE}-${FEATURE_NAME}-design.md
sed -i "s/{Feature Name}/${FEATURE_NAME^}/g" docs/design/${DATE}-${FEATURE_NAME}-design.md
```

## 🐛 Bug Report

### Create Bug Report

```bash
BUG_NAME="payment-timeout"
DATE=$(date +%Y-%m-%d)
SERVICE_NAME="payment"

cp templates/bug-report-template.md docs/bugs/${DATE}-${BUG_NAME}.md
sed -i "s/{Service Name}/${SERVICE_NAME^}/g" docs/bugs/${DATE}-${BUG_NAME}.md
```

## 📝 API Change Request

### Create API Change Request

```bash
API_NAME="order-api"
DATE=$(date +%Y-%m-%d)
SERVICE_NAME="order"

cp templates/api-change-template.md docs/api-changes/${DATE}-${API_NAME}-change.md
sed -i "s/{Service Name}/${SERVICE_NAME^}/g" docs/api-changes/${DATE}-${API_NAME}-change.md
```

## 🔄 Event Change Request

### Create Event Change Request

```bash
EVENT_TYPE="order.created"
DATE=$(date +%Y-%m-%d)

cp templates/event-change-template.md docs/event-changes/${DATE}-${EVENT_TYPE}-change.md
sed -i "s/{service}.{domain}.{action}/${EVENT_TYPE}/g" docs/event-changes/${DATE}-${EVENT_TYPE}-change.md
```

## 📚 Common Service Templates

### Order Service
```bash
cp templates/order-service-template.md docs/services/order-service.md
```

### Payment Service
```bash
cp templates/payment-service-template.md docs/services/payment-service.md
```

### Shipping Service
```bash
cp templates/shipping-service-template.md docs/services/shipping-service.md
```

### Warehouse Service
```bash
cp templates/warehouse-service-template.md docs/services/warehouse-service.md
```

### Catalog Service
```bash
cp templates/catalog-service-template.md docs/services/catalog-service.md
```

### Customer Service
```bash
cp templates/customer-service-template.md docs/services/customer-service.md
```

### Pricing Service
```bash
cp templates/pricing-service-template.md docs/services/pricing-service.md
```

### Fulfillment Service
```bash
cp templates/fulfillment-service-template.md docs/services/fulfillment-service.md
```

## ✅ Checklist

After creating documentation, verify:

- [ ] All placeholders replaced
- [ ] All required sections filled
- [ ] Examples provided
- [ ] Links work correctly
- [ ] Formatting correct
- [ ] Peer review requested

