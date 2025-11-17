# Frontend Documentation

> 📱 Customer-facing applications for the e-commerce platform

---

## 📋 Overview

This directory contains documentation for all frontend applications in the e-commerce platform. Currently, we have one main customer-facing application with plans for mobile apps.

---

## 🎯 Applications

### 1. Web Storefront (Primary)
**Status**: ✅ Ready for Implementation  
**Technology**: Next.js 14+ with App Router  
**Purpose**: Main customer-facing e-commerce website

**Key Features**:
- Product browsing and search
- Shopping cart and checkout
- User account management
- Order tracking
- Content pages (CMS-driven)

**Documentation**:
- 📖 [Full Documentation](./web-storefront.md)
- 🚀 [Quick Start Guide](./QUICK_START_GUIDE.md)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend Layer                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Web Store    │  │ Mobile App   │  │ Admin Panel  │ │
│  │ (Next.js)    │  │ (Flutter)    │  │ (Separate)   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                  │                  │          │
└─────────┼──────────────────┼──────────────────┼─────────┘
          │                  │                  │
          └──────────────────┴──────────────────┘
                             │
                    ┌────────▼────────┐
                    │  API Gateway    │
                    │  (Port 8080)    │
                    └────────┬────────┘
                             │
          ┌──────────────────┴──────────────────┐
          │                                      │
    ┌─────▼─────┐                         ┌─────▼─────┐
    │ Catalog   │                         │ Order     │
    │ Service   │  ... (11 Services) ...  │ Service   │
    └───────────┘                         └───────────┘
```

---

## 🔌 API Integration

All frontend applications communicate with backend services through the API Gateway.

### API Gateway Endpoint
```
Production:  https://api.example.com
Staging:     https://staging-api.example.com
Development: http://localhost:8080
```

### Key Service Endpoints

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Catalog | `/v1/products` | Product data |
| Pricing | `/v1/pricing` | Price calculation |
| Cart | `/v1/cart` | Shopping cart |
| Order | `/v1/orders` | Order management |
| Customer | `/v1/customers` | Customer profiles |
| Auth | `/v1/auth` | Authentication |
| Payment | `/v1/payments` | Payment processing |
| Search | `/v1/search` | Product search |

---

## 🛠️ Technology Stack

### Web Storefront
- **Framework**: Next.js 14+ (React 18+)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **State**: Zustand + React Query
- **Forms**: React Hook Form + Zod
- **Testing**: Jest + Playwright

### Mobile App (Planned)
- **Framework**: Flutter
- **Language**: Dart
- **State**: Riverpod
- **Testing**: Flutter Test

---

## 📚 Documentation Index

### Getting Started
1. [Quick Start Guide](./QUICK_START_GUIDE.md) - Get up and running in 15 minutes
2. [Web Storefront Documentation](./web-storefront.md) - Complete technical documentation

### Key Sections
- **Architecture**: Technology stack and project structure
- **API Integration**: How to connect to backend services
- **Core Features**: Product listing, cart, checkout implementation
- **UI Components**: Reusable component library
- **Authentication**: User login and session management
- **Performance**: Optimization strategies
- **Testing**: Unit, integration, and E2E testing
- **Deployment**: Docker, Kubernetes, Vercel deployment

---

## 🚀 Quick Start

### For Web Storefront

```bash
# 1. Create project
npx create-next-app@latest web-storefront --typescript --tailwind --app

# 2. Install dependencies
cd web-storefront
npm install zustand axios @tanstack/react-query

# 3. Configure environment
cp .env.example .env.local
# Edit .env.local with your API URL

# 4. Run development server
npm run dev
```

See [Quick Start Guide](./QUICK_START_GUIDE.md) for detailed instructions.

---

## 📦 Project Structure

```
frontend/
├── web-storefront/              # Next.js web application
│   ├── src/
│   │   ├── app/                 # Next.js App Router pages
│   │   ├── components/          # React components
│   │   ├── lib/                 # Utilities and configs
│   │   └── styles/              # Global styles
│   ├── public/                  # Static assets
│   ├── tests/                   # Test files
│   └── package.json
│
├── mobile-app/                  # Flutter mobile app (planned)
│   ├── lib/
│   ├── test/
│   └── pubspec.yaml
│
└── shared/                      # Shared resources
    ├── types/                   # TypeScript type definitions
    ├── constants/               # Shared constants
    └── utils/                   # Shared utilities
```

---

## 🎨 Design System

### Colors
- **Primary**: Blue (#3B82F6)
- **Secondary**: Green (#10B981)
- **Accent**: Purple (#8B5CF6)
- **Error**: Red (#EF4444)
- **Warning**: Yellow (#F59E0B)
- **Success**: Green (#10B981)

### Typography
- **Headings**: Poppins
- **Body**: Inter
- **Monospace**: Fira Code

### Spacing
- Base unit: 4px
- Scale: 4, 8, 12, 16, 24, 32, 48, 64, 96

---

## 🧪 Testing Strategy

### Unit Tests
- Component testing with Jest + React Testing Library
- Utility function testing
- Store/state management testing

### Integration Tests
- API integration testing
- Form submission flows
- Multi-component interactions

### E2E Tests
- Complete user flows with Playwright
- Critical paths: Browse → Add to Cart → Checkout → Order
- Cross-browser testing

---

## 🚢 Deployment Options

### Option 1: Vercel (Recommended for Web)
- Zero-config deployment
- Automatic HTTPS
- Edge network CDN
- Preview deployments

### Option 2: Docker + Kubernetes
- Full control over infrastructure
- Scalable and portable
- Works with any cloud provider

### Option 3: Traditional Hosting
- Build static export
- Deploy to any web server
- CDN integration

---

## 📊 Performance Targets

### Core Web Vitals
- **LCP** (Largest Contentful Paint): < 2.5s
- **FID** (First Input Delay): < 100ms
- **CLS** (Cumulative Layout Shift): < 0.1

### Page Load Times
- **Homepage**: < 1s
- **Product Listing**: < 1.5s
- **Product Detail**: < 2s
- **Checkout**: < 2s

### Lighthouse Scores
- **Performance**: > 90
- **Accessibility**: > 95
- **Best Practices**: > 95
- **SEO**: > 95

---

## 🔒 Security Considerations

### Authentication
- JWT token-based authentication
- Secure token storage (httpOnly cookies)
- Automatic token refresh
- Session timeout handling

### Data Protection
- HTTPS only in production
- Content Security Policy (CSP)
- XSS protection
- CSRF protection

### API Security
- Rate limiting
- Request validation
- Error handling (no sensitive data in errors)

---

## 🐛 Troubleshooting

### Common Issues

**Issue**: API connection failed
```bash
# Check API Gateway is running
curl http://localhost:8080/health

# Verify environment variables
cat .env.local | grep API_URL
```

**Issue**: Build errors
```bash
# Clear cache and rebuild
rm -rf .next node_modules
npm install
npm run build
```

**Issue**: Styling not working
```bash
# Verify Tailwind config
# Check globals.css has Tailwind imports
```

---

## 📈 Roadmap

### Phase 1: Web Storefront (Current)
- [x] Architecture design
- [x] Documentation complete
- [ ] Implementation in progress
- [ ] Testing
- [ ] Production deployment

### Phase 2: Mobile App (Q1 2025)
- [ ] Architecture design
- [ ] Flutter setup
- [ ] Core features implementation
- [ ] App store deployment

### Phase 3: PWA Features (Q2 2025)
- [ ] Offline support
- [ ] Push notifications
- [ ] Install prompt
- [ ] Background sync

---

## 🤝 Contributing

### Development Workflow
1. Create feature branch from `main`
2. Implement feature with tests
3. Run linting and type checking
4. Submit pull request
5. Code review and merge

### Code Standards
- TypeScript strict mode
- ESLint + Prettier formatting
- Component documentation
- Test coverage > 80%

---

## 📞 Support

### Resources
- 📖 [Full Documentation](./web-storefront.md)
- 🚀 [Quick Start](./QUICK_START_GUIDE.md)
- 🔗 [API Documentation](../infrastructure/api-gateway.md)
- 💬 [GitHub Discussions](your-repo-url)

### Contact
- **Frontend Team**: frontend@example.com
- **Tech Lead**: lead@example.com
- **Slack**: #frontend-dev

---

**Last Updated**: November 7, 2024  
**Status**: Active Development  
**Version**: 1.0.0
