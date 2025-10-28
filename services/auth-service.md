# Auth Service (IAM)

## Description
Service that handles authentication, authorization, token management, and identity access management.

## Core Responsibilities
- User authentication (login/logout)
- Authorization and role-based access control (RBAC)
- JWT token generation and validation
- OAuth2 and SSO integration
- Password management and security
- Session management
- API key management

## Outbound Data
- JWT tokens and refresh tokens
- User authentication status
- Authorization permissions
- User roles and permissions
- Session information

## Consumers (Services that use this data)

### All Services
- **Purpose**: Validate user authentication and authorization
- **Data Received**: JWT tokens, user permissions, role information

### Customer Service
- **Purpose**: User profile management
- **Data Received**: User authentication events, login history

### Notification Service
- **Purpose**: Send security alerts and notifications
- **Data Received**: Login attempts, security events

## Data Sources

### Customer Service
- **Purpose**: Get user profile information
- **Data Received**: User details, contact information

## Main APIs
- `POST /auth/login` - User authentication
- `POST /auth/logout` - User logout
- `POST /auth/refresh` - Refresh JWT token
- `POST /auth/register` - User registration
- `POST /auth/forgot-password` - Password reset request
- `GET /auth/validate` - Validate token
- `GET /auth/permissions/{userId}` - Get user permissions
- `POST /auth/oauth/callback` - OAuth callback handling

## Security Features
- Multi-factor authentication (MFA)
- Rate limiting for login attempts
- Password complexity requirements
- Account lockout policies
- Audit logging for security events
- Token blacklisting for logout