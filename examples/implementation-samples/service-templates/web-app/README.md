# Next.js Web Application Template - Kratos + Consul + Dapr Integration

## Overview
Production-ready Next.js web application template for the e-commerce platform with modern React patterns, TypeScript, and comprehensive features. Integrated with **Kratos + Consul + Dapr** backend microservices architecture.

## Tech Stack
- **Framework**: Next.js 14+ with App Router
- **Language**: TypeScript
- **State Management**: Zustand + React Query (TanStack Query)
- **UI Library**: Tailwind CSS + Headless UI + Radix UI
- **Authentication**: NextAuth.js with JWT + Kratos Auth Service
- **Backend Integration**: Kratos gRPC/HTTP services via Consul discovery
- **Real-time Communication**: Socket.io + Server-Sent Events
- **Testing**: Jest + React Testing Library + Playwright
- **Build Tool**: Turbopack
- **Deployment**: Vercel/Docker

## Project Structure
```
web-app/
├── src/
│   ├── app/                       # Next.js App Router
│   │   ├── (auth)/               # Auth route group
│   │   │   ├── login/
│   │   │   └── register/
│   │   ├── (shop)/               # Shop route group
│   │   │   ├── products/
│   │   │   ├── cart/
│   │   │   └── checkout/
│   │   ├── (account)/            # Account route group
│   │   │   ├── profile/
│   │   │   └── orders/
│   │   ├── api/                  # API routes
│   │   ├── globals.css
│   │   ├── layout.tsx
│   │   └── page.tsx
│   ├── components/               # Reusable components
│   │   ├── ui/                   # Base UI components
│   │   ├── forms/                # Form components
│   │   ├── layout/               # Layout components
│   │   └── features/             # Feature-specific components
│   ├── lib/                      # Utilities and configurations
│   │   ├── api/                  # API client + Consul integration
│   │   ├── auth/                 # Authentication
│   │   ├── store/                # State management
│   │   ├── utils/                # Utility functions
│   │   └── validations/          # Form validations
│   ├── hooks/                    # Custom React hooks
│   ├── types/                    # TypeScript types
│   └── constants/                # App constants
├── public/                       # Static assets
├── tests/                        # Test files
├── docs/                         # Documentation
├── package.json
├── next.config.js
├── tailwind.config.js
├── tsconfig.json
└── README.md
```

## Key Features

### 1. **Consul Service Discovery Integration**
- Dynamic service discovery for backend APIs
- Health check integration
- Load balancing across service instances
- Automatic failover and retry logic

### 2. **Kratos Authentication**
- JWT token management with secure storage
- Automatic token refresh
- Protected routes and middleware
- User session management

### 3. **Real-time Communication**
- WebSocket integration for live updates
- Server-Sent Events for notifications
- Real-time cart synchronization
- Live order status updates

### 4. **Performance Optimization**
- Code splitting and lazy loading
- Image optimization with Next.js
- Virtual scrolling for large lists
- Caching strategies with React Query

### 5. **Modern UI/UX**
- Responsive design with Tailwind CSS
- Accessible components with Radix UI
- Dark/light theme support
- Progressive Web App capabilities

This template provides a comprehensive foundation for building modern, scalable web applications that integrate seamlessly with the Kratos + Consul + Dapr backend architecture.