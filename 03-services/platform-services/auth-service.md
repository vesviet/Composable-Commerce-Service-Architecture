# Auth Service

**Version**: 1.0.0
**Last Updated**: 2026-01-31
**Service Type**: Platform
**Status**: Active

## Overview

The Auth Service provides comprehensive authentication and authorization functionality for the microservices platform. It handles JWT token management, OAuth2 integration, multi-factor authentication, and secure user session management.

### Responsibilities
- JWT-based authentication with access and refresh tokens
- OAuth2 social login integration (Google, Facebook, GitHub)
- Multi-factor authentication using TOTP
- Password security with bcrypt hashing
- Token management including blacklist and revocation
- Redis-based session storage
- Rate limiting for login attempts
- Account security features (brute force protection, lockout)
- Secure password reset flow with email verification
- Complete authentication audit logging

### Dependencies
- **Upstream services**: User service, Customer service
- **Downstream services**: All services requiring authentication
- **External dependencies**: PostgreSQL, Redis, Email service

## Architecture

### Responsibilities
- **Authentication**: User login, token generation, validation
- **Authorization**: Role-based access control, permission checking
- **Session Management**: Session creation, validation, expiration
- **Security**: Password hashing, token security, rate limiting
- **Integration**: OAuth2 providers, MFA, email notifications

### Dependencies
- **Upstream services**: user, customer
- **Downstream services**: All authenticated services
- **External dependencies**: PostgreSQL (auth_db), Redis, Email service

## API Contract

### gRPC Services
- **Service**: `api.auth.v1.AuthService`
- **Proto location**: `auth/api/auth/v1/`
- **Key methods**:
  - `Login(LoginRequest) → LoginResponse` - User authentication
  - `RefreshToken(RefreshTokenRequest) → RefreshTokenResponse` - Token refresh
  - `ValidateToken(ValidateTokenRequest) → ValidateTokenResponse` - Token validation
  - `Logout(LogoutRequest) → LogoutResponse` - User logout
  - `RegisterUser(RegisterUserRequest) → RegisterUserResponse` - User registration

### HTTP Endpoints
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Token refresh
- `POST /api/v1/auth/validate` - Token validation
- `POST /api/v1/auth/logout` - User logout
- `POST /api/v1/auth/register` - User registration

## Data Model

### Database Tables
- **users**: User account information
- **user_sessions**: Active user sessions
- **token_blacklist**: Revoked tokens
- **login_attempts**: Failed login tracking
- **mfa_secrets**: Multi-factor authentication secrets

### Key Entities
- **User**: Core user entity with authentication data
- **Session**: User session with metadata
- **Token**: JWT token information
- **LoginAttempt**: Failed login tracking for security

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | - | PostgreSQL connection string |
| `REDIS_URL` | Yes | - | Redis connection string |
| `JWT_SECRET` | Yes | - | JWT signing secret |
| `JWT_ACCESS_EXPIRY` | No | `15m` | Access token expiry |
| `JWT_REFRESH_EXPIRY` | No | `24h` | Refresh token expiry |

### Config Files
- **Location**: `auth/configs/`
- **Key settings**: Database, Redis, JWT, OAuth2 provider configs

## Deployment

### Docker
- **Image**: `registry/ta-microservices/auth`
- **Ports**: 8000 (HTTP), 9000 (gRPC)
- **Health check**: `GET /health`

### Kubernetes
- **Namespace**: `ta-microservices`
- **Resources**: CPU: 500m-1000m, Memory: 512Mi-1Gi
- **Scaling**: Min: 2, Max: 10 replicas

## Monitoring & Observability

### Metrics
- Authentication success/failure rates
- Token validation performance
- Session management metrics
- Rate limiting events

### Logging
- Authentication events with user context
- Security incidents (failed logins, suspicious activity)
- Token operations (issuance, validation, revocation)

### Tracing
- Authentication flow tracing
- Token validation spans
- Session management operations

## Development

### Local Setup
1. Start PostgreSQL and Redis containers
2. Configure environment variables
3. Run database migrations
4. Start the service

### Testing
- Unit tests for authentication logic
- Integration tests with database
- API contract tests
- Security testing for authentication flows

## Troubleshooting

### Common Issues
- **Token validation failures**: Check JWT secret configuration
- **Database connection issues**: Verify PostgreSQL connectivity
- **Redis connection errors**: Check Redis service availability
- **Rate limiting**: Review login attempt configurations

### Debug Commands
```bash
# Check service health
curl http://localhost:8000/health

# View service logs
docker logs auth-service

# Check database connections
kubectl exec -it auth-pod -- psql -h postgres -U auth
```

## Changelog

- **v1.0.0**: Initial release with JWT authentication, OAuth2, MFA support

## References

- [API Documentation](../04-apis/auth-api.md)
- [User Service](./core-services/user-service.md)
- [Customer Service](./core-services/customer-service.md)</content>
<parameter name="filePath">/Users/tuananh/Desktop/myproject/microservice/docs/03-services/platform-services/auth-service.md