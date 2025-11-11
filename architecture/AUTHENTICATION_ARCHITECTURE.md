# Authentication Architecture - Frontend vs Admin

## Tổng quan
Architecture cho authentication với 2 flows riêng biệt:
- **Frontend (Customer)**: Auth qua Customer Service
- **Admin (Internal User)**: Auth qua User Service

---

## 1. ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENTS                                  │
├──────────────────────────────┬──────────────────────────────────┤
│   Frontend (Next.js)         │   Admin (React/Vite)             │
│   - Customer Portal          │   - Internal Admin Panel         │
│   - Public Website           │   - Staff Management             │
└──────────────────────────────┴──────────────────────────────────┘
                 │                              │
                 │                              │
                 ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API GATEWAY                                 │
│  - Route based on path                                          │
│  - /api/customer/* → Customer Service                           │
│  - /api/admin/* → User Service                                  │
│  - JWT validation                                               │
│  - CORS handling                                                │
└─────────────────────────────────────────────────────────────────┘
                 │                              │
                 │                              │
                 ▼                              ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│   CUSTOMER SERVICE       │    │   USER SERVICE           │
│   Port: 8083             │    │   Port: 8082             │
│                          │    │                          │
│   - Customer Login       │    │   - Admin Login          │
│   - Customer Register    │    │   - User Management      │
│   - Customer Profile     │    │   - Role Management      │
│   - Password Reset       │    │   - Permission Check     │
└──────────────────────────┘    └──────────────────────────┘
                 │                              │
                 └──────────────┬───────────────┘
                                ▼
                    ┌───────────────────────┐
                    │   AUTH SERVICE        │
                    │   Port: 8081          │
                    │                       │
                    │   - JWT Generation    │
                    │   - Token Validation  │
                    │   - Session Mgmt      │
                    │   - Refresh Token     │
                    └───────────────────────┘
```

---

## 2. CUSTOMER AUTHENTICATION (Frontend)

### 2.1. Customer Login Flow

```
┌─────────┐      ┌─────────┐      ┌──────────┐      ┌──────┐
│Frontend │      │Gateway  │      │Customer  │      │Auth  │
│         │      │         │      │Service   │      │Svc   │
└────┬────┘      └────┬────┘      └────┬─────┘      └───┬──┘
     │                │                 │                │
     │ POST /login    │                 │                │
     │ email+password │                 │                │
     ├───────────────>│                 │                │
     │                │ Forward         │                │
     │                ├────────────────>│                │
     │                │                 │ Validate       │
     │                │                 │ Customer       │
     │                │                 │ (email+pwd)    │
     │                │                 │                │
     │                │                 │ Generate JWT   │
     │                │                 ├───────────────>│
     │                │                 │                │
     │                │                 │ JWT Tokens     │
     │                │                 │<───────────────┤
     │                │                 │                │
     │                │ Response        │                │
     │                │<────────────────┤                │
     │ JWT Tokens     │                 │                │
     │<───────────────┤                 │                │
     │                │                 │                │
     │ Store in       │                 │                │
     │ Cookie/Storage │                 │                │
     │                │                 │                │
```

### 2.2. Customer Service Endpoints


**Base URL**: `/api/customer/auth`

| Endpoint | Method | Description | Request | Response |
|----------|--------|-------------|---------|----------|
| `/login` | POST | Customer login | `{email, password}` | `{accessToken, refreshToken, customer}` |
| `/register` | POST | Customer register | `{email, password, firstName, lastName, phone}` | `{customerId, message}` |
| `/logout` | POST | Customer logout | `{sessionId}` | `{message}` |
| `/refresh` | POST | Refresh token | `{refreshToken}` | `{accessToken, refreshToken}` |
| `/forgot-password` | POST | Request reset | `{email}` | `{message}` |
| `/reset-password` | POST | Reset password | `{token, newPassword}` | `{message}` |
| `/verify-email` | POST | Verify email | `{token}` | `{message}` |
| `/me` | GET | Get profile | - | `{customer}` |

### 2.3. JWT Token Structure (Customer)

```json
{
  "sub": "customer_uuid",
  "email": "customer@example.com",
  "type": "customer",
  "firstName": "John",
  "lastName": "Doe",
  "customerType": "retail",
  "emailVerified": true,
  "iat": 1699999999,
  "exp": 1700003599
}
```

---

## 3. ADMIN AUTHENTICATION (Admin Panel)

### 3.1. Admin Login Flow

```
┌─────────┐      ┌─────────┐      ┌──────────┐      ┌──────┐
│Admin    │      │Gateway  │      │User      │      │Auth  │
│Panel    │      │         │      │Service   │      │Svc   │
└────┬────┘      └────┬────┘      └────┬─────┘      └───┬──┘
     │                │                 │                │
     │ POST /login    │                 │                │
     │ username+pwd   │                 │                │
     ├───────────────>│                 │                │
     │                │ Forward         │                │
     │                ├────────────────>│                │
     │                │                 │ Validate       │
     │                │                 │ User           │
     │                │                 │ (username+pwd) │
     │                │                 │                │
     │                │                 │ Get Roles &    │
     │                │                 │ Permissions    │
     │                │                 │                │
     │                │                 │ Generate JWT   │
     │                │                 ├───────────────>│
     │                │                 │                │
     │                │                 │ JWT Tokens     │
     │                │                 │<───────────────┤
     │                │                 │                │
     │                │ Response        │                │
     │                │<────────────────┤                │
     │ JWT Tokens     │                 │                │
     │<───────────────┤                 │                │
     │                │                 │                │
     │ Store in       │                 │                │
     │ LocalStorage   │                 │                │
     │                │                 │                │
```

### 3.2. User Service Endpoints

**Base URL**: `/api/admin/auth`

| Endpoint | Method | Description | Request | Response |
|----------|--------|-------------|---------|----------|
| `/login` | POST | Admin login | `{username, password}` | `{accessToken, refreshToken, user, roles, permissions}` |
| `/logout` | POST | Admin logout | `{sessionId}` | `{message}` |
| `/refresh` | POST | Refresh token | `{refreshToken}` | `{accessToken, refreshToken}` |
| `/change-password` | POST | Change password | `{currentPassword, newPassword}` | `{message}` |
| `/me` | GET | Get profile | - | `{user, roles, permissions}` |
| `/sessions` | GET | Get sessions | - | `{sessions[]}` |
| `/sessions/:id` | DELETE | Revoke session | - | `{message}` |

### 3.3. JWT Token Structure (Admin)

```json
{
  "sub": "user_uuid",
  "username": "admin.user",
  "email": "admin@company.com",
  "type": "admin",
  "firstName": "Admin",
  "lastName": "User",
  "department": "IT",
  "roles": ["admin", "product_manager"],
  "permissions": ["user.create", "user.update", "product.manage"],
  "iat": 1699999999,
  "exp": 1700003599
}
```

---

## 4. IMPLEMENTATION DETAILS

### 4.1. Frontend (Customer) - Next.js

#### File Structure:
```
frontend/src/
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   │   └── page.tsx
│   │   ├── register/
│   │   │   └── page.tsx
│   │   └── forgot-password/
│   │       └── page.tsx
│   └── (customer)/
│       ├── profile/
│       └── orders/
├── contexts/
│   └── AuthContext.tsx          # Customer auth context
├── lib/
│   ├── api/
│   │   └── customer-auth-api.ts # Customer auth API
│   └── auth/
│       ├── token-manager.ts     # Token storage
│       └── auth-guard.tsx       # Route protection
└── components/
    └── auth/
        └── ProtectedRoute.tsx
```

#### AuthContext.tsx (Customer)
```typescript
// frontend/src/contexts/AuthContext.tsx
import { createContext, useContext, useState, useEffect } from 'react';
import { customerAuthApi } from '@/lib/api/customer-auth-api';
import { setTokens, clearTokens, getToken } from '@/lib/auth/token-manager';

interface Customer {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  customerType: string;
  emailVerified: boolean;
}

interface AuthContextType {
  customer: Customer | null;
  loading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (data: RegisterData) => Promise<void>;
  logout: () => Promise<void>;
  refreshAuth: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check if user is logged in on mount
    const token = getToken();
    if (token) {
      loadCustomerProfile();
    } else {
      setLoading(false);
    }
  }, []);

  const loadCustomerProfile = async () => {
    try {
      const profile = await customerAuthApi.getProfile();
      setCustomer(profile);
    } catch (error) {
      clearTokens();
    } finally {
      setLoading(false);
    }
  };

  const login = async (email: string, password: string) => {
    const response = await customerAuthApi.login(email, password);
    setTokens(response.accessToken, response.refreshToken);
    setCustomer(response.customer);
  };

  const register = async (data: RegisterData) => {
    await customerAuthApi.register(data);
    // Optionally auto-login after registration
  };

  const logout = async () => {
    await customerAuthApi.logout();
    clearTokens();
    setCustomer(null);
  };

  const refreshAuth = async () => {
    await loadCustomerProfile();
  };

  return (
    <AuthContext.Provider value={{
      customer,
      loading,
      isAuthenticated: !!customer,
      login,
      register,
      logout,
      refreshAuth
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
};
```

#### customer-auth-api.ts
```typescript
// frontend/src/lib/api/customer-auth-api.ts
import axios from 'axios';

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

export const customerAuthApi = {
  login: async (email: string, password: string) => {
    const response = await axios.post(`${API_BASE}/api/customer/auth/login`, {
      email,
      password
    });
    return response.data;
  },

  register: async (data: {
    email: string;
    password: string;
    firstName: string;
    lastName: string;
    phone?: string;
  }) => {
    const response = await axios.post(`${API_BASE}/api/customer/auth/register`, data);
    return response.data;
  },

  logout: async () => {
    const response = await axios.post(`${API_BASE}/api/customer/auth/logout`);
    return response.data;
  },

  getProfile: async () => {
    const response = await axios.get(`${API_BASE}/api/customer/auth/me`);
    return response.data;
  },

  forgotPassword: async (email: string) => {
    const response = await axios.post(`${API_BASE}/api/customer/auth/forgot-password`, {
      email
    });
    return response.data;
  },

  resetPassword: async (token: string, newPassword: string) => {
    const response = await axios.post(`${API_BASE}/api/customer/auth/reset-password`, {
      token,
      newPassword
    });
    return response.data;
  }
};
```

---

### 4.2. Admin Panel - React/Vite

#### File Structure:
```
admin/src/
├── pages/
│   ├── Login.tsx
│   ├── Dashboard.tsx
│   └── Users/
├── store/
│   └── slices/
│       └── authSlice.ts         # Redux auth slice
├── lib/
│   ├── api/
│   │   └── admin-auth-api.ts    # Admin auth API
│   └── auth/
│       ├── token-manager.ts     # Token storage
│       └── PrivateRoute.tsx     # Route protection
└── hooks/
    └── useAuth.ts
```

#### authSlice.ts (Admin)
```typescript
// admin/src/store/slices/authSlice.ts
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { adminAuthApi } from '@/lib/api/admin-auth-api';
import { setTokens, clearTokens } from '@/lib/auth/token-manager';

interface User {
  id: string;
  username: string;
  email: string;
  firstName: string;
  lastName: string;
  department: string;
  roles: string[];
  permissions: string[];
}

interface AuthState {
  user: User | null;
  loading: boolean;
  error: string | null;
}

const initialState: AuthState = {
  user: null,
  loading: false,
  error: null
};

export const login = createAsyncThunk(
  'auth/login',
  async ({ username, password }: { username: string; password: string }) => {
    const response = await adminAuthApi.login(username, password);
    setTokens(response.accessToken, response.refreshToken);
    return response.user;
  }
);

export const logout = createAsyncThunk('auth/logout', async () => {
  await adminAuthApi.logout();
  clearTokens();
});

export const loadProfile = createAsyncThunk('auth/loadProfile', async () => {
  const response = await adminAuthApi.getProfile();
  return response.user;
});

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    }
  },
  extraReducers: (builder) => {
    builder
      .addCase(login.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(login.fulfilled, (state, action) => {
        state.loading = false;
        state.user = action.payload;
      })
      .addCase(login.rejected, (state, action) => {
        state.loading = false;
        state.error = action.error.message || 'Login failed';
      })
      .addCase(logout.fulfilled, (state) => {
        state.user = null;
      })
      .addCase(loadProfile.fulfilled, (state, action) => {
        state.user = action.payload;
      });
  }
});

export const { clearError } = authSlice.actions;
export default authSlice.reducer;
```

#### admin-auth-api.ts
```typescript
// admin/src/lib/api/admin-auth-api.ts
import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8080';

export const adminAuthApi = {
  login: async (username: string, password: string) => {
    const response = await axios.post(`${API_BASE}/api/admin/auth/login`, {
      username,
      password
    });
    return response.data;
  },

  logout: async () => {
    const response = await axios.post(`${API_BASE}/api/admin/auth/logout`);
    return response.data;
  },

  getProfile: async () => {
    const response = await axios.get(`${API_BASE}/api/admin/auth/me`);
    return response.data;
  },

  changePassword: async (currentPassword: string, newPassword: string) => {
    const response = await axios.post(`${API_BASE}/api/admin/auth/change-password`, {
      currentPassword,
      newPassword
    });
    return response.data;
  },

  getSessions: async () => {
    const response = await axios.get(`${API_BASE}/api/admin/auth/sessions`);
    return response.data;
  },

  revokeSession: async (sessionId: string) => {
    const response = await axios.delete(`${API_BASE}/api/admin/auth/sessions/${sessionId}`);
    return response.data;
  }
};
```

---

## 5. GATEWAY ROUTING CONFIGURATION

### gateway/configs/gateway-routes.yaml
```yaml
routes:
  # Customer routes
  - path: /api/customer/*
    service: customer-service
    port: 8083
    auth_required: false  # Some endpoints public (login, register)
    auth_type: customer
    
  # Admin routes
  - path: /api/admin/*
    service: user-service
    port: 8082
    auth_required: true   # All admin endpoints require auth
    auth_type: admin
    
  # Auth service (direct access)
  - path: /api/auth/*
    service: auth-service
    port: 8081
    auth_required: false
```

### Gateway Middleware Logic
```go
// gateway/internal/middleware/auth.go
func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        path := c.Request.URL.Path
        
        // Determine auth type based on path
        var authType string
        if strings.HasPrefix(path, "/api/customer/") {
            authType = "customer"
        } else if strings.HasPrefix(path, "/api/admin/") {
            authType = "admin"
        }
        
        // Extract token
        token := extractToken(c)
        if token == "" {
            c.JSON(401, gin.H{"error": "unauthorized"})
            c.Abort()
            return
        }
        
        // Validate token with auth service
        valid, claims := validateToken(token, authType)
        if !valid {
            c.JSON(401, gin.H{"error": "invalid token"})
            c.Abort()
            return
        }
        
        // Set user info in context
        c.Set("user_id", claims.Sub)
        c.Set("user_type", claims.Type)
        c.Set("permissions", claims.Permissions)
        
        c.Next()
    }
}
```

---

## 6. TOKEN STORAGE STRATEGY

### Frontend (Customer)
- **Access Token**: HTTP-only cookie (1 hour)
- **Refresh Token**: HTTP-only cookie (7 days)
- **Reason**: More secure, prevents XSS attacks

### Admin Panel
- **Access Token**: LocalStorage (8 hours)
- **Refresh Token**: LocalStorage (30 days)
- **Reason**: Easier development, admin users are trusted

---

## 7. SECURITY CONSIDERATIONS

### 7.1. CORS Configuration
```yaml
# Gateway CORS
cors:
  frontend:
    origins:
      - http://localhost:3000
      - https://shop.example.com
    credentials: true
    
  admin:
    origins:
      - http://localhost:5173
      - https://admin.example.com
    credentials: true
```

### 7.2. Token Refresh Strategy
```typescript
// Axios interceptor for auto token refresh
axios.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      
      try {
        const refreshToken = getRefreshToken();
        const response = await axios.post('/api/auth/refresh', {
          refreshToken
        });
        
        setTokens(response.data.accessToken, response.data.refreshToken);
        originalRequest.headers.Authorization = `Bearer ${response.data.accessToken}`;
        
        return axios(originalRequest);
      } catch (refreshError) {
        clearTokens();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }
    
    return Promise.reject(error);
  }
);
```

---

## 8. TESTING CHECKLIST

### Customer Auth:
- [ ] Customer can register
- [ ] Customer can login with email
- [ ] Customer can logout
- [ ] Token refresh works
- [ ] Password reset flow works
- [ ] Email verification works
- [ ] Protected routes redirect to login
- [ ] Token stored in HTTP-only cookie

### Admin Auth:
- [ ] Admin can login with username
- [ ] Admin can logout
- [ ] Token refresh works
- [ ] Password change works
- [ ] Session management works
- [ ] Role-based access control works
- [ ] Permission checks work
- [ ] Token stored in LocalStorage

---

## 9. MIGRATION PLAN

### Phase 1: Customer Service Auth (Week 1)
1. Implement customer login endpoint
2. Implement customer register endpoint
3. Integrate with auth service for JWT
4. Update frontend to use customer auth

### Phase 2: User Service Auth (Week 1)
1. Implement admin login endpoint
2. Add role/permission loading
3. Integrate with auth service for JWT
4. Update admin panel to use user auth

### Phase 3: Gateway Integration (Week 2)
1. Configure routing rules
2. Implement auth middleware
3. Add token validation
4. Test end-to-end flows

### Phase 4: Security Hardening (Week 2)
1. Configure CORS properly
2. Implement rate limiting
3. Add session management
4. Security audit

---

Generated: 2025-11-10
Ready for implementation!
