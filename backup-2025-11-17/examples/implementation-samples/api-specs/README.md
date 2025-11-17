# API Specifications

This directory contains OpenAPI 3.0 specifications for all microservices in the e-commerce platform.

## 📋 Available Specifications

### Core Services
- [`catalog-service-openapi.yaml`](./catalog-service-openapi.yaml) - Product catalog, brands, categories, CMS
- `pricing-service-openapi.yaml` - Dynamic pricing and promotions *(Coming Soon)*
- `order-service-openapi.yaml` - Order management and lifecycle *(Coming Soon)*
- `payment-service-openapi.yaml` - Payment processing *(Coming Soon)*
- `shipping-service-openapi.yaml` - Fulfillment and logistics *(Coming Soon)*

### Infrastructure Services
- `auth-service-openapi.yaml` - Authentication and authorization *(Coming Soon)*
- `user-service-openapi.yaml` - User management *(Coming Soon)*
- `search-service-openapi.yaml` - Product search and indexing *(Coming Soon)*
- `notification-service-openapi.yaml` - Multi-channel notifications *(Coming Soon)*

## 🛠️ Usage

### View Specifications

#### Swagger UI (Recommended)
```bash
# Install swagger-ui-serve
npm install -g swagger-ui-serve

# Serve catalog service API docs
swagger-ui-serve catalog-service-openapi.yaml

# Open http://localhost:3000
```

#### Redoc
```bash
# Install redoc-cli
npm install -g redoc-cli

# Generate HTML documentation
redoc-cli build catalog-service-openapi.yaml --output catalog-service-docs.html

# Open catalog-service-docs.html in browser
```

#### VS Code
Install the "OpenAPI (Swagger) Editor" extension and open any `.yaml` file.

### Generate API Clients

#### TypeScript/JavaScript
```bash
npx @openapitools/openapi-generator-cli generate \
  -i catalog-service-openapi.yaml \
  -g typescript-axios \
  -o ./generated/typescript/catalog-client \
  --additional-properties=npmName=@company/catalog-client
```

#### Python
```bash
openapi-generator generate \
  -i catalog-service-openapi.yaml \
  -g python \
  -o ./generated/python/catalog-client \
  --additional-properties=packageName=catalog_client
```

#### Go
```bash
openapi-generator generate \
  -i catalog-service-openapi.yaml \
  -g go \
  -o ./generated/go/catalog-client \
  --additional-properties=packageName=catalogclient
```

#### Java
```bash
openapi-generator generate \
  -i catalog-service-openapi.yaml \
  -g java \
  -o ./generated/java/catalog-client \
  --additional-properties=groupId=com.company,artifactId=catalog-client
```

### Validate Specifications

#### Using Swagger Editor
```bash
# Install swagger-editor-dist
npm install -g swagger-editor-dist

# Validate specification
swagger-editor-dist --file catalog-service-openapi.yaml
```

#### Using OpenAPI CLI
```bash
# Install @apidevtools/swagger-cli
npm install -g @apidevtools/swagger-cli

# Validate specification
swagger-cli validate catalog-service-openapi.yaml
```

## 📚 Architecture Integration

### Hybrid EAV + Flat Table (Catalog Service)

The Catalog Service OpenAPI spec reflects the **Hybrid EAV + Flat Table** architecture:

#### **Tier 1: Flat Table Attributes**
- **Fast Filtering**: `brand_id`, `category_id`, `color`, `size`, `material`
- **Performance**: Sub-10ms queries with proper indexing
- **Query Parameters**: Direct filter parameters in API

#### **Tier 2: EAV Attributes**
- **Flexible Filtering**: `warranty_months`, `origin_country`, `is_eco_friendly`
- **Performance**: 50-200ms queries with optimized joins
- **API Structure**: Nested in `attributes` object

#### **Tier 3: JSON Attributes**
- **Display Only**: `specifications`, `marketing_attributes`, `media`
- **Performance**: Fast retrieval, no query overhead
- **API Structure**: Separate objects for different purposes

### Performance Metadata

All responses include performance metadata:
```json
{
  "meta": {
    "performance": {
      "query_time_ms": 45,
      "cache_hit": true,
      "data_sources": ["cache", "materialized_view"]
    }
  }
}
```

### Authentication & Authorization

All services use JWT Bearer tokens with scope-based permissions:
- `catalog:read` - Read access to catalog data
- `catalog:write` - Write access to catalog data
- `cms:read` - Read access to CMS content
- `cms:write` - Write access to CMS content

## 🔄 Generation Workflow

### From Service Code
```bash
# Generate OpenAPI from Go service (using swag)
cd ../../service-templates/go-service
make swagger

# Copy generated spec
cp docs/swagger.yaml ../../../api-specs/catalog-service-openapi.yaml
```

### From Protobuf
```bash
# Generate OpenAPI from protobuf definitions
protoc --openapi_out=fq_schema_naming=true,default_response=false:. \
  api/catalog/v1/catalog.proto

# Output: openapi.yaml
```

### Manual Updates
1. Edit the YAML file directly
2. Validate using `swagger-cli validate`
3. Test with Swagger UI
4. Regenerate clients if needed

## 📖 Best Practices

### Specification Design
- **Consistent Naming**: Use snake_case for properties, kebab-case for paths
- **Proper HTTP Status Codes**: 200, 201, 400, 401, 404, 409, 500
- **Comprehensive Examples**: Include realistic example data
- **Error Responses**: Standardized error format across all services
- **Pagination**: Consistent pagination parameters and response format

### Performance Documentation
- **Query Complexity**: Document expected response times
- **Caching Strategy**: Indicate which endpoints are cached
- **Rate Limiting**: Document rate limits and quotas
- **Bulk Operations**: Specify batch size limits

### Security Documentation
- **Authentication**: Clear auth requirements
- **Authorization**: Required scopes/permissions
- **Input Validation**: Parameter constraints and formats
- **Data Privacy**: Sensitive data handling

## 🔗 Related Documentation

- [Service Templates](../service-templates/README.md) - Implementation templates
- [API Clients](../api-clients/README.md) - Generated client libraries
- [Architecture Overview](../../../docs/architecture/overview.md) - System architecture
- [Security Overview](../../../docs/security/security-overview.md) - Security patterns

## 📝 Contributing

### Adding New Service Specs
1. Create `{service-name}-openapi.yaml`
2. Follow the catalog service as a template
3. Include performance and architecture notes
4. Add to this README
5. Generate and test client libraries

### Updating Existing Specs
1. Make changes to YAML file
2. Validate with `swagger-cli validate`
3. Test with Swagger UI
4. Update version number
5. Regenerate affected client libraries
6. Update changelog

### Specification Standards
- **OpenAPI 3.0.3** or later
- **Comprehensive schemas** with examples
- **Proper error handling** with standard error format
- **Performance metadata** in responses
- **Security requirements** clearly documented