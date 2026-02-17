# 💻 Frontend Service - Complete Documentation

> **Owner**: Platform Team  
> **Last Updated**: 2026-02-15  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: 3000

**Service Name**: Frontend Service
**Version**: 1.0.1
**Last Updated**: 2026-02-10
**Review Status**: ✅ **COMPLETED** - Production Ready
**Production Ready**: ✅ 100%

## Overview

The Frontend Service is a modern e-commerce web storefront built with Next.js 14+, TypeScript, and Tailwind CSS. It provides a comprehensive customer-facing interface for the e-commerce platform, integrating with microservices backend via API Gateway. The service implements the latest React patterns with Server Components, proper state management, and responsive design.

## Architecture

### Responsibilities
- Provide customer-facing e-commerce interface
- Handle user authentication and session management
- Manage shopping cart and checkout flow
- Display product catalog and search functionality
- Process payments with multiple providers
- Real-time updates via WebSocket connections
- Admin interface for customer and order management

### Dependencies
- **Upstream services**: API Gateway (aggregates all backend services)
- **Downstream services**: None (frontend is the client-facing layer)
- **External dependencies**: CDN, payment gateways (Stripe, PayPal), analytics

## API Contract

### HTTP Endpoints
- **Base URL**: `http://localhost:3000` (development), `https://store.example.com` (production)
- **Key pages**:
  - `GET /` - Home page
  - `GET /products` - Product listing
  - `GET /products/{id}` - Product details
  - `GET /cart` - Shopping cart
  - `GET /checkout` - Checkout process
  - `GET /account` - User account
  - `GET /orders` - Order history

### API Integration
- **Gateway URL**: Configured via `API_GATEWAY_URL` environment variable
- **Authentication**: JWT Bearer tokens with refresh mechanism
- **Error Handling**: Comprehensive error handling with user-friendly messages

## Data Model

### Key Entities
- **Product**: Product information, pricing, inventory
- **Cart**: Shopping cart with items and quantities
- **Order**: Order details and status
- **User**: Customer account information
- **Payment**: Payment processing and status

### State Management
- **Client State**: Zustand for UI state, form state
- **Server State**: React Query for API data, caching
- **Form State**: React Hook Form with Zod validation

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `API_GATEWAY_URL` | Yes | - | API Gateway endpoint |
| `NEXTAUTH_SECRET` | Yes | - | JWT secret for authentication |
| `STRIPE_PUBLIC_KEY` | Yes | - | Stripe publishable key |
| `PAYPAL_CLIENT_ID` | Yes | - | PayPal client ID |
| `NODE_ENV` | No | `development` | Environment mode |

### Config Files
- **Location**: `frontend/`
- **Key settings**: `next.config.js`, `tailwind.config.js`, `.env.local`

## Deployment

### Docker
- **Image**: `registry-api.tanhdev.com/frontend`
- **Ports**: 3000 (HTTP)
- **Health check**: `GET /api/health`

### Kubernetes
- **Namespace**: `frontend-dev` (dev), `frontend-prod` (production)
- **Resources**: CPU: 200m-1, Memory: 512Mi-2Gi
- **Scaling**: Min 2, Max 10 replicas

### Build Process
- **Development**: `npm run dev` - Hot reload with webpack
- **Production**: `npm run build` - Optimized build
- **Linting**: `npm run lint` - ESLint checks
- **Testing**: `npm run test` - Vitest unit tests

## Monitoring & Observability

### Metrics
- Page load times
- Core Web Vitals (LCP, FID, CLS)
- API response times
- Error rates by component
- User interaction metrics

### Logging
- Structured logging with context
- Error tracking with stack traces
- Performance metrics
- User action logging

### Tracing
- Next.js built-in performance monitoring
- API request tracing
- User journey tracking

## Development

### Local Setup
1. Prerequisites: Node.js 18+, npm/yarn
2. Clone repo and install dependencies
3. Configure environment variables
4. Run `npm run dev` to start development server
5. Visit `http://localhost:3000`

### Testing
- Unit tests: `npm run test` (Vitest)
- E2E tests: `npm run test:e2e` (Playwright)
- Type checking: `npm run type-check`
- Linting: `npm run lint`

### Code Quality
- TypeScript for type safety
- ESLint for code quality
- Prettier for code formatting
- Husky for pre-commit hooks

## Troubleshooting

### Common Issues
- **Build failures**: Check TypeScript errors and dependencies
- **API errors**: Verify API Gateway URL and authentication
- **Permission issues**: Check file ownership and permissions
- **Memory issues**: Increase Node.js memory limit

### Debug Commands
```bash
# Check service logs
kubectl logs -f deployment/frontend

# Test health endpoint
curl http://localhost:3000/api/health

# Check build
npm run build

# Type checking
npm run type-check
```

## Performance

### Optimization
- Next.js Image optimization
- Code splitting by routes
- Static generation for static pages
- Client-side caching with React Query
- Bundle analysis with next-bundle-analyzer

### Core Web Vitals
- LCP: < 2.5s (Largest Contentful Paint)
- FID: < 100ms (First Input Delay)
- CLS: < 0.1 (Cumulative Layout Shift)

## Security

### Authentication
- JWT tokens with refresh mechanism
- Secure token storage
- Automatic token refresh
- Logout functionality

### Data Protection
- HTTPS enforcement
- CSRF protection
- XSS prevention
- Content Security Policy

## Changelog

- v1.0.1: Current version with e-commerce features
- v1.0.0: Initial release with basic storefront

## References

- [Next.js Documentation](https://nextjs.org/docs)
- [React Documentation](https://react.dev)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [API Gateway Documentation](../04-apis/api-gateway.md)
