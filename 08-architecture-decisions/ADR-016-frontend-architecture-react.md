# ADR-016: Frontend Architecture (React + Next.js)

**Date:** 2026-02-03
**Status:** Accepted
**Deciders:** Frontend Team, Architecture Team, UI/UX Team

## Context

The e-commerce platform requires two frontend applications:
- **Admin Dashboard**: Internal tool for order management, catalog management, analytics, system administration
- **Customer Frontend**: Customer-facing storefront with product browsing, cart, checkout, account management

Each has distinct requirements:
- **Admin**: Rich data tables, forms, RBAC, no SEO needed, SPA is sufficient
- **Customer**: SEO-critical, fast initial load, SSR/SSG beneficial, responsive mobile experience

We evaluated several frontend approaches:
- **React + TypeScript (Vite)**: Modern SPA, fast development
- **Next.js**: React-based with SSR/SSG, routing, and SEO
- **Vue.js**: Progressive framework, easier learning curve
- **Angular**: Full-featured framework, enterprise-grade

## Decision

We will use a **dual frontend architecture**:
1. **Admin Dashboard**: **React + TypeScript + Vite** (SPA)
2. **Customer Frontend**: **Next.js + React + TypeScript** (SSR/SSG)

### Admin Dashboard Architecture:
1. **React 18**: Modern React with concurrent features
2. **TypeScript**: Type safety and better developer experience
3. **Vite**: Fast build tool and development server
4. **React Router**: Client-side routing
5. **State Management**: React Context + useReducer for global state
6. **UI Components**: Custom component library

### Customer Frontend Architecture:
1. **Next.js**: Server-side rendering and static generation
2. **React 18**: Component-based UI
3. **TypeScript**: Type safety
4. **App Router**: File-based routing with layouts
5. **Server Components**: For SEO and initial load performance

### Project Structure:
```
admin/                          # Admin SPA (Vite)
├── src/
│   ├── components/
│   ├── pages/
│   ├── hooks/
│   ├── services/
│   ├── types/
│   └── contexts/

frontend/                       # Customer Frontend (Next.js)
├── app/                        # App Router pages
├── components/
├── hooks/
├── services/
├── types/
└── public/
```

### Key Features:
- **Responsive Design**: Mobile-first responsive layout
- **Real-time Updates**: WebSocket integration for live data
- **Data Tables**: Advanced sorting, filtering, pagination (Admin)
- **SSR/SSG**: Server-rendered pages for SEO (Customer)
- **Authentication**: JWT-based authentication with refresh tokens

### API Integration:
- **Service Layer**: Centralized API client with error handling
- **Type Safety**: Generated TypeScript types from API schemas
- **Caching**: React Query for server state management
- **Error Handling**: Global error boundary and user feedback

## Consequences

### Positive:
- ✅ **Right Tool for Job**: SPA for admin, SSR for customer — optimized for each use case
- ✅ **SEO**: Next.js provides server rendering for customer-facing pages
- ✅ **Performance**: Fast admin SPA + optimized customer SSR
- ✅ **Developer Experience**: Fast development with Vite (admin) and Next.js (customer)
- ✅ **Type Safety**: Full TypeScript coverage reduces runtime errors
- ✅ **Shared Code**: Common types and utilities between both apps

### Negative:
- ⚠️ **Two Apps**: Maintaining two separate frontend applications
- ⚠️ **Complexity**: Different build systems and deployment strategies
- ⚠️ **Learning Curve**: Team needs Next.js + Vite expertise
- ⚠️ **Bundle Size**: React applications can become large

### Risks:
- **Drift**: Admin and customer UIs diverging in patterns and shared components
- **Performance**: Poor optimization leading to slow loading
- **Maintenance**: Keeping dependencies updated and secure across both apps

## Alternatives Considered

### 1. Single Next.js App for Both
- **Rejected**: Admin dashboard doesn't need SSR overhead, and auth/routing requirements are very different
- **Pros**: Single codebase, shared components
- **Cons**: Unnecessary SSR complexity for admin, harder RBAC routing

### 2. Vue.js + TypeScript
- **Rejected**: Smaller ecosystem, fewer enterprise features
- **Pros**: Easier learning curve, good documentation
- **Cons**: Smaller ecosystem, fewer enterprise-grade features

### 3. Angular
- **Rejected**: Heavy framework, steep learning curve
- **Pros**: Enterprise-grade, comprehensive framework
- **Cons**: Complex, verbose, steep learning curve

### 4. React Only (No Next.js)
- **Rejected**: Customer frontend needs SSR for SEO and initial load performance
- **Pros**: Simpler, single framework approach
- **Cons**: No SSR, poor SEO, slower initial page loads

## Implementation Guidelines

- Use TypeScript for all new code in both apps
- Implement comprehensive error handling and user feedback
- Use React Query for server state management
- Implement proper loading states and skeletons
- Use semantic HTML and accessibility best practices
- Monitor bundle size and performance metrics
- Share common types and API client code between apps
- Use consistent coding standards and code reviews

## References

- [React Documentation](https://react.dev/)
- [Next.js Documentation](https://nextjs.org/docs)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Vite Documentation](https://vitejs.dev/)
- [React Query](https://tanstack.com/query/latest)
