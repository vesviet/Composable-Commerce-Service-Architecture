# Authentication Architecture - Technical Design Document

**Author:** Security Team, Platform Team  
**Stakeholders:** Frontend Team, Admin Team, DevOps  
**Created:** 2025-11-17  
**Status:** Implemented ✅

## 1. Goals / Non-Goals

### Goals
- Separate authentication flows for Customer (Frontend) and Admin (Internal)
- JWT-based stateless authentication
- Support for refresh tokens
- Role-based access control (RBAC)
- Service-to-service authentication
- OAuth2/OIDC ready (future)

### Non-Goals
- Social login (future work)
- Multi-factor authentication (future work)
- SAML integration (future work)

## 2. Background / Current State

### Problem Statement
Need to support two distinct user types:
1. **Customers**: Public users accessing frontend
2. **Admins**: Internal staff accessing admin panel

Both need different authentication flows, permissions, and token lifetimes.

### Current Architecture
- Single Auth Service handles both flows
- Customer Service handles customer authentication
- User Service handles admin authentication
- Gateway validates JWT tokens

## 3. Proposal / Architecture

### Architecture Diagram

```
┌─────────────┐         ┌─────────────┐
│  Frontend   │         │    Admin    │
│  (Customer) │         │   Panel     │
└──────┬──────┘         └──────┬──────┘
       │                       │
       │ Customer Login        │ Admin Login
       ▼                       ▼
┌─────────────────────────────────────┐
│         API GATEWAY                 │
│  - Route: /api/customer/*           │
│  - Route: /api/admin/*              │
│  - JWT Validation                   │
└──────┬──────────────────┬───────────┘
       │                  │
       ▼                  ▼
┌─────────────┐    ┌─────────────┐
│  Customer   │    │    User     │
│  Service    │    │   Service   │
└──────┬──────┘    └──────┬──────┘
       │                  │
       └──────────┬───────┘
                  ▼
         ┌─────────────┐
         │ Auth Service│
         │ - JWT Gen   │
         │ - Validate  │
         └─────────────┘
```

### Key Components

1. **Auth Service**
   - JWT token generation (customer + admin)
   - Token validation
   - Refresh token management
   - Session management

2. **Customer Service**
   - Customer registration/login
   - Password reset
   - Customer profile management

3. **User Service**
   - Admin user management
   - Role/permission management
   - Admin authentication

4. **Gateway**
   - JWT validation middleware
   - Route-based authentication
   - Header injection (X-User-ID, X-Client-Type)

### Token Structure

**Customer Token:**
```json
{
  "user_id": "customer-uuid",
  "client_type": "customer",
  "roles": ["customer"],
  "exp": 1699977600
}
```

**Admin Token:**
```json
{
  "user_id": "admin-uuid",
  "client_type": "admin",
  "roles": ["admin", "customer_manager"],
  "permissions": ["read:customers", "write:customers"],
  "exp": 1699920000
}
```

### Authentication Flows

**Customer Login:**
1. Frontend → POST /api/customer/auth/login
2. Gateway → Customer Service
3. Customer Service → Auth Service (generate JWT)
4. Return JWT to Frontend

**Admin Login:**
1. Admin Panel → POST /api/admin/auth/login
2. Gateway → User Service
3. User Service → Auth Service (generate JWT)
4. Return JWT to Admin Panel

## 4. APIs / Events Affected

### New Endpoints
- `POST /api/customer/auth/login` - Customer login
- `POST /api/customer/auth/register` - Customer registration
- `POST /api/admin/auth/login` - Admin login
- `POST /api/auth/validate` - Token validation
- `POST /api/auth/refresh` - Refresh token

### Events
- `user.registered` - When new customer registers
- `user.logged_in` - When user logs in (audit)

## 5. Security / Privacy / Compliance

- **JWT Secret**: 32+ character secret, rotated quarterly
- **Token Expiry**: Customer (24h), Admin (8h)
- **HTTPS Only**: All tokens transmitted over HTTPS
- **Rate Limiting**: Login endpoints rate limited (10 req/min)
- **Password Hashing**: bcrypt with salt (cost factor 10)

## 6. Alternatives

### Alternative 1: Session-Based Auth
- **Rejected**: Requires session storage, not stateless

### Alternative 2: OAuth2 Only
- **Rejected**: Too complex for current needs, can add later

### Alternative 3: API Keys
- **Rejected**: Not suitable for user authentication

## 7. Rollout Plan / Migration

### Phase 1: Auth Service (Week 1)
- ✅ JWT generation/validation
- ✅ Token refresh mechanism

### Phase 2: Customer Flow (Week 2)
- ✅ Customer Service integration
- ✅ Frontend integration

### Phase 3: Admin Flow (Week 3)
- ✅ User Service integration
- ✅ Admin panel integration

### Phase 4: Gateway Integration (Week 4)
- ✅ JWT validation middleware
- ✅ Route protection

## 8. Open Questions / Appendix

### Token Storage
- **Frontend**: localStorage (customer), httpOnly cookie (admin) - future improvement
- **Refresh Tokens**: Stored in database with expiry

### Monitoring
- Prometheus: `auth_requests_total`, `auth_failures_total`
- Alert on high failure rate (>5%)

### References
- See `/docs/backup-2025-11-17/architecture/AUTHENTICATION_ARCHITECTURE.md`
- JWT Library: github.com/golang-jwt/jwt/v5

