# Event Schemas

## Overview
Comprehensive event schema definitions for the e-commerce platform's event-driven architecture. These schemas ensure consistency, type safety, and backward compatibility across all microservices.

## Schema Formats

### 1. Avro Schemas
- **Binary serialization** for high performance
- **Schema evolution** with backward/forward compatibility
- **Compact format** for network efficiency
- **Strong typing** with code generation

### 2. JSON Schema
- **Human-readable** format
- **Wide language support**
- **Easy validation** and documentation
- **REST API integration**

### 3. Protocol Buffers (Protobuf)
- **High performance** binary format
- **Cross-language** compatibility
- **Efficient serialization**
- **gRPC integration**

## Event Categories

### Business Events
- Order lifecycle events
- Product catalog events
- Customer events
- Payment events
- Inventory events
- Shipping events

### System Events
- Service health events
- Configuration changes
- Error events
- Audit events

## Schema Structure

```
event-schemas/
├── avro/                          # Avro schema definitions
│   ├── business/
│   │   ├── order-events.avsc
│   │   ├── product-events.avsc
│   │   ├── customer-events.avsc
│   │   ├── payment-events.avsc
│   │   ├── inventory-events.avsc
│   │   └── shipping-events.avsc
│   ├── system/
│   │   ├── health-events.avsc
│   │   ├── audit-events.avsc
│   │   └── error-events.avsc
│   └── common/
│       ├── base-event.avsc
│       ├── metadata.avsc
│       └── enums.avsc
├── json-schema/                   # JSON Schema definitions
│   ├── business/
│   ├── system/
│   └── common/
├── protobuf/                      # Protocol Buffer definitions
│   ├── business/
│   ├── system/
│   └── common/
├── generated/                     # Generated code
│   ├── typescript/
│   ├── java/
│   ├── python/
│   └── go/
└── scripts/
    ├── generate-code.sh
    ├── validate-schemas.sh
    └── publish-schemas.sh
```

## Avro Schemas

### Base Event Schema (avro/common/base-event.avsc)
```json
{
  "type": "record",
  "name": "BaseEvent",
  "namespace": "com.ecommerce.events",
  "doc": "Base event structure for all events in the system",
  "fields": [
    {
      "name": "eventId",
      "type": "string",
      "doc": "Unique identifier for this event"
    },
    {
      "name": "eventType",
      "type": "string",
      "doc": "Type of event (e.g., order.created, product.updated)"
    },
    {
      "name": "eventVersion",
      "type": "string",
      "default": "1.0",
      "doc": "Schema version for backward compatibility"
    },
    {
      "name": "timestamp",
      "type": "long",
      "logicalType": "timestamp-millis",
      "doc": "Event timestamp in milliseconds since epoch"
    },
    {
      "name": "source",
      "type": "string",
      "doc": "Service that generated this event"
    },
    {
      "name": "correlationId",
      "type": ["null", "string"],
      "default": null,
      "doc": "Correlation ID for tracing related events"
    },
    {
      "name": "causationId",
      "type": ["null", "string"],
      "default": null,
      "doc": "ID of the event that caused this event"
    },
    {
      "name": "metadata",
      "type": {
        "type": "map",
        "values": "string"
      },
      "default": {},
      "doc": "Additional metadata for the event"
    }
  ]
}
```

### Order Events Schema (avro/business/order-events.avsc)
```json
{
  "type": "record",
  "name": "OrderEvents",
  "namespace": "com.ecommerce.events.order",
  "doc": "Order-related events",
  "fields": [
    {
      "name": "OrderCreated",
      "type": {
        "type": "record",
        "name": "OrderCreatedEvent",
        "fields": [
          {
            "name": "baseEvent",
            "type": "com.ecommerce.events.BaseEvent"
          },
          {
            "name": "data",
            "type": {
              "type": "record",
              "name": "OrderCreatedData",
              "fields": [
                {
                  "name": "orderId",
                  "type": "string",
                  "doc": "Unique order identifier"
                },
                {
                  "name": "orderNumber",
                  "type": "string",
                  "doc": "Human-readable order number"
                },
                {
                  "name": "customerId",
                  "type": "string",
                  "doc": "Customer who placed the order"
                },
                {
                  "name": "status",
                  "type": {
                    "type": "enum",
                    "name": "OrderStatus",
                    "symbols": [
                      "PENDING_PAYMENT",
                      "CONFIRMED",
                      "PROCESSING",
                      "SHIPPED",
                      "DELIVERED",
                      "CANCELLED",
                      "REFUNDED"
                    ]
                  },
                  "doc": "Current order status"
                },
                {
                  "name": "items",
                  "type": {
                    "type": "array",
                    "items": {
                      "type": "record",
                      "name": "OrderItem",
                      "fields": [
                        {
                          "name": "productId",
                          "type": "string"
                        },
                        {
                          "name": "sku",
                          "type": "string"
                        },
                        {
                          "name": "name",
                          "type": "string"
                        },
                        {
                          "name": "quantity",
                          "type": "int"
                        },
                        {
                          "name": "unitPrice",
                          "type": {
                            "type": "bytes",
                            "logicalType": "decimal",
                            "precision": 10,
                            "scale": 2
                          }
                        },
                        {
                          "name": "totalPrice",
                          "type": {
                            "type": "bytes",
                            "logicalType": "decimal",
                            "precision": 10,
                            "scale": 2
                          }
                        },
                        {
                          "name": "warehouse",
                          "type": "string"
                        }
                      ]
                    }
                  },
                  "doc": "Items in the order"
                },
                {
                  "name": "totals",
                  "type": {
                    "type": "record",
                    "name": "OrderTotals",
                    "fields": [
                      {
                        "name": "subtotal",
                        "type": {
                          "type": "bytes",
                          "logicalType": "decimal",
                          "precision": 10,
                          "scale": 2
                        }
                      },
                      {
                        "name": "discounts",
                        "type": {
                          "type": "bytes",
                          "logicalType": "decimal",
                          "precision": 10,
                          "scale": 2
                        }
                      },
                      {
                        "name": "shipping",
                        "type": {
                          "type": "bytes",
                          "logicalType": "decimal",
                          "precision": 10,
                          "scale": 2
                        }
                      },
                      {
                        "name": "tax",
                        "type": {
                          "type": "bytes",
                          "logicalType": "decimal",
                          "precision": 10,
                          "scale": 2
                        }
                      },
                      {
                        "name": "total",
                        "type": {
                          "type": "bytes",
                          "logicalType": "decimal",
                          "precision": 10,
                          "scale": 2
                        }
                      },
                      {
                        "name": "currency",
                        "type": "string",
                        "default": "USD"
                      }
                    ]
                  }
                },
                {
                  "name": "customer",
                  "type": {
                    "type": "record",
                    "name": "CustomerInfo",
                    "fields": [
                      {
                        "name": "id",
                        "type": "string"
                      },
                      {
                        "name": "email",
                        "type": "string"
                      },
                      {
                        "name": "tier",
                        "type": ["null", "string"],
                        "default": null
                      }
                    ]
                  }
                },
                {
                  "name": "addresses",
                  "type": {
                    "type": "record",
                    "name": "OrderAddresses",
                    "fields": [
                      {
                        "name": "shipping",
                        "type": {
                          "type": "record",
                          "name": "Address",
                          "fields": [
                            {"name": "street", "type": "string"},
                            {"name": "city", "type": "string"},
                            {"name": "state", "type": "string"},
                            {"name": "zipCode", "type": "string"},
                            {"name": "country", "type": "string"}
                          ]
                        }
                      },
                      {
                        "name": "billing",
                        "type": "Address"
                      }
                    ]
                  }
                },
                {
                  "name": "payment",
                  "type": {
                    "type": "record",
                    "name": "PaymentInfo",
                    "fields": [
                      {
                        "name": "method",
                        "type": "string"
                      },
                      {
                        "name": "transactionId",
                        "type": ["null", "string"],
                        "default": null
                      }
                    ]
                  }
                },
                {
                  "name": "loyalty",
                  "type": ["null", {
                    "type": "record",
                    "name": "LoyaltyInfo",
                    "fields": [
                      {
                        "name": "pointsEarned",
                        "type": "int"
                      },
                      {
                        "name": "pointsUsed",
                        "type": "int"
                      }
                    ]
                  }],
                  "default": null
                }
              ]
            }
          }
        ]
      }
    }
  ]
}
```

### Product Events Schema (avro/business/product-events.avsc)
```json
{
  "type": "record",
  "name": "ProductEvents",
  "namespace": "com.ecommerce.events.product",
  "doc": "Product-related events",
  "fields": [
    {
      "name": "ProductCreated",
      "type": {
        "type": "record",
        "name": "ProductCreatedEvent",
        "fields": [
          {
            "name": "baseEvent",
            "type": "com.ecommerce.events.BaseEvent"
          },
          {
            "name": "data",
            "type": {
              "type": "record",
              "name": "ProductCreatedData",
              "fields": [
                {
                  "name": "productId",
                  "type": "string"
                },
                {
                  "name": "sku",
                  "type": "string"
                },
                {
                  "name": "name",
                  "type": "string"
                },
                {
                  "name": "description",
                  "type": ["null", "string"],
                  "default": null
                },
                {
                  "name": "category",
                  "type": {
                    "type": "record",
                    "name": "Category",
                    "fields": [
                      {"name": "id", "type": "string"},
                      {"name": "name", "type": "string"},
                      {"name": "path", "type": "string"}
                    ]
                  }
                },
                {
                  "name": "brand",
                  "type": {
                    "type": "record",
                    "name": "Brand",
                    "fields": [
                      {"name": "id", "type": "string"},
                      {"name": "name", "type": "string"}
                    ]
                  }
                },
                {
                  "name": "attributes",
                  "type": {
                    "type": "map",
                    "values": "string"
                  },
                  "default": {}
                },
                {
                  "name": "status",
                  "type": {
                    "type": "enum",
                    "name": "ProductStatus",
                    "symbols": ["DRAFT", "ACTIVE", "INACTIVE", "DISCONTINUED"]
                  }
                },
                {
                  "name": "createdBy",
                  "type": "string"
                },
                {
                  "name": "createdAt",
                  "type": "long",
                  "logicalType": "timestamp-millis"
                }
              ]
            }
          }
        ]
      }
    },
    {
      "name": "ProductUpdated",
      "type": {
        "type": "record",
        "name": "ProductUpdatedEvent",
        "fields": [
          {
            "name": "baseEvent",
            "type": "com.ecommerce.events.BaseEvent"
          },
          {
            "name": "data",
            "type": {
              "type": "record",
              "name": "ProductUpdatedData",
              "fields": [
                {
                  "name": "productId",
                  "type": "string"
                },
                {
                  "name": "changes",
                  "type": {
                    "type": "map",
                    "values": {
                      "type": "record",
                      "name": "FieldChange",
                      "fields": [
                        {"name": "oldValue", "type": ["null", "string"], "default": null},
                        {"name": "newValue", "type": ["null", "string"], "default": null}
                      ]
                    }
                  }
                },
                {
                  "name": "updatedBy",
                  "type": "string"
                },
                {
                  "name": "updatedAt",
                  "type": "long",
                  "logicalType": "timestamp-millis"
                }
              ]
            }
          }
        ]
      }
    }
  ]
}
```

## JSON Schema Examples

### Order Created Event (json-schema/business/order-created.json)
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://schemas.ecommerce.com/events/order-created.json",
  "title": "Order Created Event",
  "description": "Event published when a new order is created",
  "type": "object",
  "required": ["eventId", "eventType", "timestamp", "source", "data"],
  "properties": {
    "eventId": {
      "type": "string",
      "format": "uuid",
      "description": "Unique identifier for this event"
    },
    "eventType": {
      "type": "string",
      "const": "order.created",
      "description": "Type of event"
    },
    "eventVersion": {
      "type": "string",
      "default": "1.0",
      "description": "Schema version"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "Event timestamp in ISO 8601 format"
    },
    "source": {
      "type": "string",
      "description": "Service that generated this event"
    },
    "correlationId": {
      "type": ["string", "null"],
      "format": "uuid",
      "description": "Correlation ID for tracing"
    },
    "causationId": {
      "type": ["string", "null"],
      "format": "uuid",
      "description": "ID of the event that caused this event"
    },
    "metadata": {
      "type": "object",
      "additionalProperties": {
        "type": "string"
      },
      "description": "Additional metadata"
    },
    "data": {
      "type": "object",
      "required": ["orderId", "orderNumber", "customerId", "status", "items", "totals"],
      "properties": {
        "orderId": {
          "type": "string",
          "format": "uuid"
        },
        "orderNumber": {
          "type": "string",
          "pattern": "^ORD-[0-9]{4}-[0-9]{6}$"
        },
        "customerId": {
          "type": "string",
          "format": "uuid"
        },
        "status": {
          "type": "string",
          "enum": ["PENDING_PAYMENT", "CONFIRMED", "PROCESSING", "SHIPPED", "DELIVERED", "CANCELLED", "REFUNDED"]
        },
        "items": {
          "type": "array",
          "minItems": 1,
          "items": {
            "type": "object",
            "required": ["productId", "sku", "name", "quantity", "unitPrice", "totalPrice", "warehouse"],
            "properties": {
              "productId": {"type": "string", "format": "uuid"},
              "sku": {"type": "string"},
              "name": {"type": "string"},
              "quantity": {"type": "integer", "minimum": 1},
              "unitPrice": {"type": "number", "minimum": 0},
              "totalPrice": {"type": "number", "minimum": 0},
              "warehouse": {"type": "string"}
            }
          }
        },
        "totals": {
          "type": "object",
          "required": ["subtotal", "discounts", "shipping", "tax", "total", "currency"],
          "properties": {
            "subtotal": {"type": "number", "minimum": 0},
            "discounts": {"type": "number", "minimum": 0},
            "shipping": {"type": "number", "minimum": 0},
            "tax": {"type": "number", "minimum": 0},
            "total": {"type": "number", "minimum": 0},
            "currency": {"type": "string", "pattern": "^[A-Z]{3}$"}
          }
        },
        "customer": {
          "type": "object",
          "required": ["id", "email"],
          "properties": {
            "id": {"type": "string", "format": "uuid"},
            "email": {"type": "string", "format": "email"},
            "tier": {"type": ["string", "null"]}
          }
        },
        "addresses": {
          "type": "object",
          "required": ["shipping", "billing"],
          "properties": {
            "shipping": {"$ref": "#/$defs/address"},
            "billing": {"$ref": "#/$defs/address"}
          }
        },
        "payment": {
          "type": "object",
          "required": ["method"],
          "properties": {
            "method": {"type": "string"},
            "transactionId": {"type": ["string", "null"]}
          }
        },
        "loyalty": {
          "type": ["object", "null"],
          "properties": {
            "pointsEarned": {"type": "integer", "minimum": 0},
            "pointsUsed": {"type": "integer", "minimum": 0}
          }
        }
      }
    }
  },
  "$defs": {
    "address": {
      "type": "object",
      "required": ["street", "city", "state", "zipCode", "country"],
      "properties": {
        "street": {"type": "string"},
        "city": {"type": "string"},
        "state": {"type": "string"},
        "zipCode": {"type": "string"},
        "country": {"type": "string", "pattern": "^[A-Z]{2}$"}
      }
    }
  }
}
```

## Protocol Buffer Definitions

### Order Events (protobuf/business/order_events.proto)
```protobuf
syntax = "proto3";

package com.ecommerce.events.order;

import "google/protobuf/timestamp.proto";
import "common/base_event.proto";

// Order Created Event
message OrderCreatedEvent {
  com.ecommerce.events.BaseEvent base_event = 1;
  OrderCreatedData data = 2;
}

message OrderCreatedData {
  string order_id = 1;
  string order_number = 2;
  string customer_id = 3;
  OrderStatus status = 4;
  repeated OrderItem items = 5;
  OrderTotals totals = 6;
  CustomerInfo customer = 7;
  OrderAddresses addresses = 8;
  PaymentInfo payment = 9;
  optional LoyaltyInfo loyalty = 10;
}

enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;
  ORDER_STATUS_PENDING_PAYMENT = 1;
  ORDER_STATUS_CONFIRMED = 2;
  ORDER_STATUS_PROCESSING = 3;
  ORDER_STATUS_SHIPPED = 4;
  ORDER_STATUS_DELIVERED = 5;
  ORDER_STATUS_CANCELLED = 6;
  ORDER_STATUS_REFUNDED = 7;
}

message OrderItem {
  string product_id = 1;
  string sku = 2;
  string name = 3;
  int32 quantity = 4;
  double unit_price = 5;
  double total_price = 6;
  string warehouse = 7;
}

message OrderTotals {
  double subtotal = 1;
  double discounts = 2;
  double shipping = 3;
  double tax = 4;
  double total = 5;
  string currency = 6;
}

message CustomerInfo {
  string id = 1;
  string email = 2;
  optional string tier = 3;
}

message OrderAddresses {
  Address shipping = 1;
  Address billing = 2;
}

message Address {
  string street = 1;
  string city = 2;
  string state = 3;
  string zip_code = 4;
  string country = 5;
}

message PaymentInfo {
  string method = 1;
  optional string transaction_id = 2;
}

message LoyaltyInfo {
  int32 points_earned = 1;
  int32 points_used = 2;
}
```

## Code Generation

### Generate TypeScript Types
```bash
#!/bin/bash
# scripts/generate-typescript.sh

echo "Generating TypeScript types from Avro schemas..."

# Generate from Avro schemas
for schema in avro/business/*.avsc; do
    avro-typescript "$schema" --output "generated/typescript/$(basename "$schema" .avsc).ts"
done

for schema in avro/system/*.avsc; do
    avro-typescript "$schema" --output "generated/typescript/$(basename "$schema" .avsc).ts"
done

# Generate from JSON schemas
for schema in json-schema/business/*.json; do
    json2ts "$schema" --output "generated/typescript/$(basename "$schema" .json).ts"
done

echo "TypeScript types generated successfully!"
```

### Generate Java Classes
```bash
#!/bin/bash
# scripts/generate-java.sh

echo "Generating Java classes from Avro schemas..."

# Generate from Avro schemas
java -jar avro-tools.jar compile schema avro/ generated/java/

# Generate from Protocol Buffers
protoc --java_out=generated/java/ protobuf/business/*.proto protobuf/system/*.proto

echo "Java classes generated successfully!"
```

### Generate Python Classes
```bash
#!/bin/bash
# scripts/generate-python.sh

echo "Generating Python classes from schemas..."

# Generate from Avro schemas
for schema in avro/business/*.avsc avro/system/*.avsc; do
    avro-python3 -s "$schema" -o "generated/python/$(basename "$schema" .avsc).py"
done

# Generate from Protocol Buffers
protoc --python_out=generated/python/ protobuf/business/*.proto protobuf/system/*.proto

echo "Python classes generated successfully!"
```

## Schema Registry Integration

### Confluent Schema Registry
```bash
# Register Avro schemas
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data @avro/business/order-events.avsc \
  http://schema-registry:8081/subjects/order.created-value/versions

# Get schema by ID
curl http://schema-registry:8081/schemas/ids/1

# List all subjects
curl http://schema-registry:8081/subjects
```

### Schema Evolution Rules
1. **Backward Compatibility**: New schema can read data written with old schema
2. **Forward Compatibility**: Old schema can read data written with new schema
3. **Full Compatibility**: Both backward and forward compatible
4. **Breaking Changes**: Require new major version

### Schema Versioning Strategy
- **Major Version**: Breaking changes (e.g., 1.0 → 2.0)
- **Minor Version**: Backward compatible additions (e.g., 1.0 → 1.1)
- **Patch Version**: Bug fixes and clarifications (e.g., 1.0.0 → 1.0.1)

## Validation and Testing

### Schema Validation
```bash
# Validate Avro schemas
avro-tools validate avro/business/order-events.avsc

# Validate JSON schemas
ajv validate -s json-schema/business/order-created.json -d test-data/order-created-sample.json

# Validate Protocol Buffers
protoc --proto_path=protobuf/ --error_format=gcc protobuf/business/order_events.proto
```

### Event Testing
```javascript
// Example event validation in TypeScript
import { OrderCreatedEvent } from '../generated/typescript/order-events';
import Ajv from 'ajv';

const ajv = new Ajv();
const schema = require('../json-schema/business/order-created.json');
const validate = ajv.compile(schema);

function validateOrderCreatedEvent(event: any): event is OrderCreatedEvent {
  const valid = validate(event);
  if (!valid) {
    console.error('Validation errors:', validate.errors);
    return false;
  }
  return true;
}

// Test event
const testEvent = {
  eventId: "evt-123",
  eventType: "order.created",
  timestamp: new Date().toISOString(),
  source: "order-service",
  data: {
    orderId: "ord-456",
    orderNumber: "ORD-2024-001234",
    customerId: "cust-789",
    status: "CONFIRMED",
    // ... rest of the event data
  }
};

if (validateOrderCreatedEvent(testEvent)) {
  console.log('Event is valid!');
} else {
  console.log('Event validation failed!');
}
```

These event schemas provide a robust foundation for the event-driven architecture, ensuring consistency, type safety, and evolution capabilities across all microservices.