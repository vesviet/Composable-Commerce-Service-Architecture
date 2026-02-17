# Admin Service

> **Owner**: Platform Team  
> **Last Updated**: 2026-02-15  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: 3001

**Version**: 1.0.0  
**Last Updated**: 2026-02-10  
**Service Type**: Platform  
**Status**: ✅ **COMPLETED** - Production Ready

## Overview

The Admin Service is a comprehensive administrative panel built with React 18, Vite, and Ant Design. It provides a full-featured interface for managing all aspects of the e-commerce platform including products, orders, customers, inventory, pricing, promotions, and system settings. The service serves as the primary tool for administrators to manage daily operations and monitor business performance.

## Architecture

### Responsibilities
- Provide comprehensive administrative interface for e-commerce operations
- Manage product catalog (products, categories, brands, attributes)
- Handle order management and fulfillment workflows
- Manage customer accounts and support operations
- Control inventory and warehouse operations
- Configure pricing, promotions, and campaigns
- Manage user roles and system settings
- Provide analytics and reporting capabilities

### Dependencies
- **Upstream services**: API Gateway (aggregates all backend services)
- **Downstream services**: None (admin is the management interface)
- **External dependencies**: CDN, analytics services, payment gateways (read-only)

## API Contract

### HTTP Endpoints
- **Base URL**: `http://localhost:5173` (development), `https://admin.example.com` (production)
- **Key pages**:
  - `GET /` - Dashboard overview
  - `GET /products` - Product management
  - `GET /orders` - Order management
  - `GET /customers` - Customer management
  - `GET /inventory` - Inventory management
  - `GET /pricing` - Pricing configuration
  - `GET /settings` - System settings

### API Integration
- **Gateway URL**: Configured via environment variables
- **Authentication**: JWT Bearer tokens with CSRF protection
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Service Discovery**: Gateway handles routing to backend services

## Data Model

### Key Entities
- **Product**: Product information, variants, pricing
- **Order**: Order details, status, fulfillment
- **Customer**: Customer accounts, addresses, orders
- **Inventory**: Stock levels, movements, transfers
- **User**: Admin users, roles, permissions
- **Promotion**: Campaigns, coupons, discounts

### State Management
- **Global State**: Redux Toolkit for application state
- **Auth State**: User authentication and permissions
- **Dashboard State**: Metrics and analytics data
- **Form State**: Local component state with React Hook Form

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `VITE_API_GATEWAY_URL` | Yes | - | API Gateway endpoint |
| `VITE_APP_NAME` | No | `Admin Panel` | Application name |
| `VITE_API_TIMEOUT` | No | `30000` | API request timeout |

### Config Files
- **Location**: `admin/`
- **Key settings**: `vite.config.ts`, `.env.example`

## Deployment

### Docker
- **Image**: `registry-api.tanhdev.com/admin`
- **Ports**: 5173 (development), 80 (production)
- **Health check**: `GET /` (returns 200)

### Kubernetes
- **Namespace**: `admin-dev` (dev), `admin-prod` (production)
- **Resources**: CPU: 300m-1, Memory: 512Mi-2Gi
- **Scaling**: Min 1, Max 5 replicas

### Build Process
- **Development**: `npm run dev` - Hot reload with Vite
- **Production**: `npm run build` - Optimized build
- **Staging**: `npm run build:staging` - Staging build
- **Linting**: `npm run lint` - ESLint checks
- **Testing**: `npm run test` - Vitest unit tests

## Monitoring & Observability

### Metrics
- Page load times
- User interaction metrics
- API response times
- Error rates by feature
- User session analytics

### Logging
- Structured logging with context
- Error tracking with stack traces
- User action logging
- Performance metrics

### Performance
- Bundle size: ~2.8MB (gzipped: ~680KB)
- First Contentful Paint: < 2s
- Largest Contentful Paint: < 3s
- Cumulative Layout Shift: < 0.1

## Development

### Local Setup
1. Prerequisites: Node.js 18+, npm
2. Clone repo and install dependencies
3. Configure environment variables
4. Run `npm run dev` to start development server
5. Visit `http://localhost:5173`

### Testing
- Unit tests: `npm run test` (Vitest)
- Type checking: `npm run type-check`
- Linting: `npm run lint`
- Build verification: `npm run build`

### Code Quality
- TypeScript for type safety
- ESLint for code quality
- Prettier for code formatting
- Husky for pre-commit hooks

## Features

### Dashboard
- Overview metrics and KPIs
- Interactive charts and graphs
- Real-time data updates
- Performance indicators

### Product Management
- Product catalog management
- Category and brand organization
- Product variants and attributes
- Inventory integration
- Bulk operations

### Order Management
- Order listing and filtering
- Order detail views
- Fulfillment workflow
- Picklist generation
- Shipment tracking

### Customer Management
- Customer account management
- Order history
- Address management
- Support tools

### Inventory Management
- Stock level monitoring
- Stock movements and transfers
- Warehouse management
- Low stock alerts

### Pricing & Promotions
- Price configuration
- Tax rules management
- Campaign creation
- Coupon management
- Discount rules

### User Management
- Admin user accounts
- Role and permission management
- Activity logging
- Access control

## Troubleshooting

### Common Issues
- **Build failures**: Check TypeScript errors and dependencies
- **API errors**: Verify API Gateway URL and authentication
- **Performance issues**: Check bundle size and network requests
- **Memory issues**: Optimize large components and data fetching

### Debug Commands
```bash
# Check service logs
kubectl logs -f deployment/admin

# Test health endpoint
curl http://localhost:5173/

# Check build
npm run build

# Type checking
npm run type-check

# Linting
npm run lint
```

## Security

### Authentication
- JWT tokens with refresh mechanism
- CSRF protection for state-changing requests
- Secure token storage
- Role-based access control

### Data Protection
- HTTPS enforcement
- XSS protection
- Content Security Policy
- Input validation and sanitization

## Performance Optimization

### Bundle Optimization
- Code splitting by routes
- Manual chunking for large libraries
- Tree shaking for unused code
- Dynamic imports for heavy components

### Runtime Optimization
- React.memo for expensive components
- useMemo and useCallback for expensive operations
- Virtual scrolling for large lists
- Image optimization and lazy loading

## Changelog

- v1.0.0: Initial release with comprehensive admin functionality

## References

- [React Documentation](https://react.dev)
- [Vite Documentation](https://vite.dev)
- [Ant Design Documentation](https://ant.design)
- [API Gateway Documentation](../04-apis/api-gateway.md)
