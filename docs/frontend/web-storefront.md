# Web Storefront - E-Commerce Frontend

> **Service Type**: Frontend Application (Customer-Facing)  
> **Architecture**: Next.js 14+ with App Router  
> **Last Updated**: November 7, 2024  
> **Status**: Architecture Finalized - Ready for Implementation

---

## 📋 Overview

### Description
Modern, high-performance e-commerce storefront built with Next.js 14+, providing seamless shopping experience for customers. Features server-side rendering (SSR), static site generation (SSG), and optimized performance for SEO and conversion.

### Business Context
The Web Storefront is the primary customer touchpoint for the e-commerce platform. It must deliver:
- **Fast Performance**: Sub-second page loads, optimized Core Web Vitals
- **SEO Excellence**: Server-side rendering for search engine visibility
- **Mobile-First**: Responsive design, progressive web app (PWA) capabilities
- **Conversion Optimized**: Streamlined checkout, personalized experiences

### Key Features
- **Product Discovery**: Browse, search, filter products with rich media
- **Shopping Cart**: Real-time cart management with inventory validation
- **Checkout Flow**: Multi-step checkout with payment integration
- **User Account**: Order history, wishlist, address management
- **Personalization**: Recommendations, recently viewed, customer segments
- **Content Pages**: CMS-driven pages, blogs, landing pages

---

## 🏗️ Architecture

### Technology Stack

#### Core Framework
- **Next.js 14+**: React framework with App Router
- **React 18+**: UI library with Server Components
- **TypeScript**: Type-safe development
- **Tailwind CSS**: Utility-first CSS framework

#### State Management
- **Zustand**: Lightweight state management for client state
- **React Query (TanStack Query)**: Server state management and caching
- **Context API**: Global app state (theme, locale, user)

#### API Integration
- **Axios**: HTTP client with interceptors
- **SWR**: Alternative for data fetching (optional)
- **GraphQL Client**: Apollo Client (if using GraphQL gateway)

#### UI Components
- **Headless UI**: Accessible UI components
- **Radix UI**: Primitive components
- **Framer Motion**: Animations and transitions
- **React Hook Form**: Form management with validation

#### Performance & SEO
- **Next.js Image**: Optimized image loading
- **Next.js Font**: Font optimization
- **next-seo**: SEO meta tags management
- **@vercel/analytics**: Performance monitoring

#### Payment Integration
- **Stripe Elements**: Payment UI components
- **PayPal SDK**: PayPal integration
- **Payment Request API**: Apple Pay, Google Pay

#### Development Tools
- **ESLint**: Code linting
- **Prettier**: Code formatting
- **Husky**: Git hooks
- **Jest + React Testing Library**: Unit testing
- **Playwright**: E2E testing


---

## 📁 Project Structure

```
web-storefront/
├── src/
│   ├── app/                          # Next.js App Router
│   │   ├── (auth)/                   # Auth group routes
│   │   │   ├── login/
│   │   │   ├── register/
│   │   │   └── forgot-password/
│   │   ├── (shop)/                   # Main shop routes
│   │   │   ├── page.tsx              # Homepage
│   │   │   ├── products/
│   │   │   │   ├── page.tsx          # Product listing
│   │   │   │   ├── [slug]/           # Product detail
│   │   │   │   └── category/[slug]/  # Category pages
│   │   │   ├── cart/
│   │   │   ├── checkout/
│   │   │   └── search/
│   │   ├── (account)/                # Customer account
│   │   │   ├── profile/
│   │   │   ├── orders/
│   │   │   ├── addresses/
│   │   │   └── wishlist/
│   │   ├── (content)/                # CMS pages
│   │   │   ├── about/
│   │   │   ├── contact/
│   │   │   └── blog/
│   │   ├── layout.tsx                # Root layout
│   │   ├── error.tsx                 # Error boundary
│   │   ├── loading.tsx               # Loading UI
│   │   └── not-found.tsx             # 404 page
│   ├── components/                   # React components
│   │   ├── ui/                       # Base UI components
│   │   │   ├── button.tsx
│   │   │   ├── input.tsx
│   │   │   ├── card.tsx
│   │   │   └── modal.tsx
│   │   ├── layout/                   # Layout components
│   │   │   ├── header.tsx
│   │   │   ├── footer.tsx
│   │   │   ├── navigation.tsx
│   │   │   └── sidebar.tsx
│   │   ├── product/                  # Product components
│   │   │   ├── product-card.tsx
│   │   │   ├── product-grid.tsx
│   │   │   ├── product-detail.tsx
│   │   │   └── product-gallery.tsx
│   │   ├── cart/                     # Cart components
│   │   │   ├── cart-item.tsx
│   │   │   ├── cart-summary.tsx
│   │   │   └── mini-cart.tsx
│   │   └── checkout/                 # Checkout components
│   │       ├── checkout-steps.tsx
│   │       ├── shipping-form.tsx
│   │       └── payment-form.tsx
│   ├── lib/                          # Utilities and configs
│   │   ├── api/                      # API clients
│   │   │   ├── client.ts             # Axios instance
│   │   │   ├── catalog.ts            # Catalog API
│   │   │   ├── cart.ts               # Cart API
│   │   │   ├── order.ts              # Order API
│   │   │   ├── customer.ts           # Customer API
│   │   │   └── auth.ts               # Auth API
│   │   ├── hooks/                    # Custom React hooks
│   │   │   ├── use-cart.ts
│   │   │   ├── use-auth.ts
│   │   │   ├── use-products.ts
│   │   │   └── use-checkout.ts
│   │   ├── store/                    # State management
│   │   │   ├── cart-store.ts         # Cart state (Zustand)
│   │   │   ├── auth-store.ts         # Auth state
│   │   │   └── ui-store.ts           # UI state
│   │   ├── utils/                    # Helper functions
│   │   │   ├── format.ts             # Formatters
│   │   │   ├── validation.ts         # Validators
│   │   │   └── constants.ts          # Constants
│   │   └── types/                    # TypeScript types
│   │       ├── product.ts
│   │       ├── cart.ts
│   │       ├── order.ts
│   │       └── customer.ts
│   ├── styles/                       # Global styles
│   │   ├── globals.css               # Global CSS
│   │   └── tailwind.css              # Tailwind imports
│   └── middleware.ts                 # Next.js middleware
├── public/                           # Static assets
│   ├── images/
│   ├── icons/
│   └── fonts/
├── tests/                            # Test files
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── .env.local                        # Environment variables
├── .env.example                      # Example env file
├── next.config.js                    # Next.js config
├── tailwind.config.js                # Tailwind config
├── tsconfig.json                     # TypeScript config
├── package.json
└── README.md
```


---

## 🔌 API Integration

### API Gateway Configuration

```typescript
// src/lib/api/client.ts
import axios from 'axios';

const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor - Add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('auth_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor - Handle errors
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      // Redirect to login
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default apiClient;
```

### Service Endpoints

```typescript
// src/lib/api/endpoints.ts
export const API_ENDPOINTS = {
  // Catalog Service
  CATALOG: {
    PRODUCTS: '/v1/products',
    PRODUCT_DETAIL: (slug: string) => `/v1/products/${slug}`,
    CATEGORIES: '/v1/categories',
    SEARCH: '/v1/products/search',
  },
  
  // Pricing Service
  PRICING: {
    GET_PRICE: '/v1/pricing/calculate',
    BULK_PRICES: '/v1/pricing/bulk',
  },
  
  // Cart Service (Order Service)
  CART: {
    GET: '/v1/cart',
    ADD_ITEM: '/v1/cart/items',
    UPDATE_ITEM: (itemId: string) => `/v1/cart/items/${itemId}`,
    REMOVE_ITEM: (itemId: string) => `/v1/cart/items/${itemId}`,
    CLEAR: '/v1/cart/clear',
  },
  
  // Order Service
  ORDER: {
    CREATE: '/v1/orders',
    GET: (orderId: string) => `/v1/orders/${orderId}`,
    LIST: '/v1/orders',
    CANCEL: (orderId: string) => `/v1/orders/${orderId}/cancel`,
  },
  
  // Customer Service
  CUSTOMER: {
    PROFILE: '/v1/customers/me',
    UPDATE: '/v1/customers/me',
    ADDRESSES: '/v1/customers/me/addresses',
    ORDERS: '/v1/customers/me/orders',
  },
  
  // Auth Service
  AUTH: {
    LOGIN: '/v1/auth/login',
    REGISTER: '/v1/auth/register',
    LOGOUT: '/v1/auth/logout',
    REFRESH: '/v1/auth/refresh',
    FORGOT_PASSWORD: '/v1/auth/forgot-password',
    RESET_PASSWORD: '/v1/auth/reset-password',
  },
  
  // Payment Service
  PAYMENT: {
    CREATE_INTENT: '/v1/payments/intent',
    CONFIRM: '/v1/payments/confirm',
    METHODS: '/v1/payments/methods',
  },
  
  // Shipping Service
  SHIPPING: {
    CALCULATE: '/v1/shipping/calculate',
    METHODS: '/v1/shipping/methods',
  },
  
  // Review Service
  REVIEW: {
    LIST: (productId: string) => `/v1/reviews/product/${productId}`,
    CREATE: '/v1/reviews',
    UPDATE: (reviewId: string) => `/v1/reviews/${reviewId}`,
  },
  
  // Search Service
  SEARCH: {
    PRODUCTS: '/v1/search/products',
    SUGGESTIONS: '/v1/search/suggestions',
  },
};
```


---

## 🛒 Core Features Implementation

### 1. Product Listing Page

```typescript
// src/app/(shop)/products/page.tsx
import { Suspense } from 'react';
import { ProductGrid } from '@/components/product/product-grid';
import { ProductFilters } from '@/components/product/product-filters';
import { getProducts } from '@/lib/api/catalog';

export default async function ProductsPage({
  searchParams,
}: {
  searchParams: { category?: string; page?: string; sort?: string };
}) {
  const products = await getProducts({
    category: searchParams.category,
    page: parseInt(searchParams.page || '1'),
    sort: searchParams.sort,
  });

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex gap-8">
        <aside className="w-64">
          <ProductFilters />
        </aside>
        <main className="flex-1">
          <Suspense fallback={<ProductGridSkeleton />}>
            <ProductGrid products={products} />
          </Suspense>
        </main>
      </div>
    </div>
  );
}
```

### 2. Product Detail Page

```typescript
// src/app/(shop)/products/[slug]/page.tsx
import { notFound } from 'next/navigation';
import { ProductGallery } from '@/components/product/product-gallery';
import { ProductInfo } from '@/components/product/product-info';
import { AddToCartButton } from '@/components/product/add-to-cart-button';
import { getProductBySlug } from '@/lib/api/catalog';
import { getProductPrice } from '@/lib/api/pricing';

export async function generateMetadata({ params }: { params: { slug: string } }) {
  const product = await getProductBySlug(params.slug);
  
  return {
    title: product.name,
    description: product.description,
    openGraph: {
      images: [product.images[0]],
    },
  };
}

export default async function ProductDetailPage({
  params,
}: {
  params: { slug: string };
}) {
  const product = await getProductBySlug(params.slug);
  
  if (!product) {
    notFound();
  }

  const pricing = await getProductPrice(product.sku);

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <ProductGallery images={product.images} />
        <div>
          <ProductInfo product={product} pricing={pricing} />
          <AddToCartButton product={product} />
        </div>
      </div>
    </div>
  );
}
```

### 3. Shopping Cart

```typescript
// src/lib/store/cart-store.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface CartItem {
  id: string;
  sku: string;
  name: string;
  price: number;
  quantity: number;
  image: string;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  updateQuantity: (id: string, quantity: number) => void;
  clearCart: () => void;
  total: () => number;
}

export const useCartStore = create<CartStore>()(
  persist(
    (set, get) => ({
      items: [],
      
      addItem: (item) => {
        set((state) => {
          const existingItem = state.items.find((i) => i.id === item.id);
          
          if (existingItem) {
            return {
              items: state.items.map((i) =>
                i.id === item.id
                  ? { ...i, quantity: i.quantity + item.quantity }
                  : i
              ),
            };
          }
          
          return { items: [...state.items, item] };
        });
      },
      
      removeItem: (id) => {
        set((state) => ({
          items: state.items.filter((i) => i.id !== id),
        }));
      },
      
      updateQuantity: (id, quantity) => {
        set((state) => ({
          items: state.items.map((i) =>
            i.id === id ? { ...i, quantity } : i
          ),
        }));
      },
      
      clearCart: () => set({ items: [] }),
      
      total: () => {
        return get().items.reduce(
          (sum, item) => sum + item.price * item.quantity,
          0
        );
      },
    }),
    {
      name: 'cart-storage',
    }
  )
);
```

### 4. Checkout Flow

```typescript
// src/app/(shop)/checkout/page.tsx
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { CheckoutSteps } from '@/components/checkout/checkout-steps';
import { ShippingForm } from '@/components/checkout/shipping-form';
import { PaymentForm } from '@/components/checkout/payment-form';
import { OrderSummary } from '@/components/checkout/order-summary';
import { useCartStore } from '@/lib/store/cart-store';
import { createOrder } from '@/lib/api/order';

export default function CheckoutPage() {
  const router = useRouter();
  const { items, clearCart } = useCartStore();
  const [step, setStep] = useState(1);
  const [shippingData, setShippingData] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleShippingSubmit = (data) => {
    setShippingData(data);
    setStep(2);
  };

  const handlePaymentSubmit = async (paymentData) => {
    setLoading(true);
    
    try {
      const order = await createOrder({
        items,
        shipping: shippingData,
        payment: paymentData,
      });
      
      clearCart();
      router.push(`/order-confirmation/${order.id}`);
    } catch (error) {
      console.error('Order creation failed:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <CheckoutSteps currentStep={step} />
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mt-8">
        <div className="lg:col-span-2">
          {step === 1 && (
            <ShippingForm onSubmit={handleShippingSubmit} />
          )}
          {step === 2 && (
            <PaymentForm
              onSubmit={handlePaymentSubmit}
              loading={loading}
            />
          )}
        </div>
        
        <div>
          <OrderSummary items={items} />
        </div>
      </div>
    </div>
  );
}
```


---

## 🎨 UI Components Library

### Base Components

```typescript
// src/components/ui/button.tsx
import { ButtonHTMLAttributes, forwardRef } from 'react';
import { cn } from '@/lib/utils';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'primary', size = 'md', loading, children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(
          'inline-flex items-center justify-center rounded-md font-medium transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
          'disabled:pointer-events-none disabled:opacity-50',
          {
            'bg-primary text-white hover:bg-primary/90': variant === 'primary',
            'bg-secondary text-white hover:bg-secondary/90': variant === 'secondary',
            'border border-input bg-background hover:bg-accent': variant === 'outline',
            'hover:bg-accent hover:text-accent-foreground': variant === 'ghost',
            'h-9 px-3 text-sm': size === 'sm',
            'h-10 px-4': size === 'md',
            'h-11 px-8 text-lg': size === 'lg',
          },
          className
        )}
        disabled={loading}
        {...props}
      >
        {loading && <Spinner className="mr-2" />}
        {children}
      </button>
    );
  }
);
```

### Product Card Component

```typescript
// src/components/product/product-card.tsx
import Image from 'next/image';
import Link from 'next/link';
import { Product } from '@/lib/types/product';
import { formatPrice } from '@/lib/utils/format';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/store/cart-store';

interface ProductCardProps {
  product: Product;
}

export function ProductCard({ product }: ProductCardProps) {
  const addItem = useCartStore((state) => state.addItem);

  const handleAddToCart = (e: React.MouseEvent) => {
    e.preventDefault();
    addItem({
      id: product.id,
      sku: product.sku,
      name: product.name,
      price: product.price,
      quantity: 1,
      image: product.images[0],
    });
  };

  return (
    <Link href={`/products/${product.slug}`} className="group">
      <div className="bg-white rounded-lg shadow-sm hover:shadow-md transition-shadow">
        <div className="relative aspect-square overflow-hidden rounded-t-lg">
          <Image
            src={product.images[0]}
            alt={product.name}
            fill
            className="object-cover group-hover:scale-105 transition-transform"
          />
          {product.badge && (
            <span className="absolute top-2 right-2 bg-red-500 text-white px-2 py-1 text-xs rounded">
              {product.badge}
            </span>
          )}
        </div>
        
        <div className="p-4">
          <h3 className="font-semibold text-lg mb-2 line-clamp-2">
            {product.name}
          </h3>
          
          <div className="flex items-center gap-2 mb-3">
            <span className="text-2xl font-bold text-primary">
              {formatPrice(product.price)}
            </span>
            {product.originalPrice && (
              <span className="text-sm text-gray-500 line-through">
                {formatPrice(product.originalPrice)}
              </span>
            )}
          </div>
          
          <Button
            onClick={handleAddToCart}
            className="w-full"
            size="sm"
          >
            Add to Cart
          </Button>
        </div>
      </div>
    </Link>
  );
}
```


---

## ⚙️ Configuration Files

### Environment Variables

```bash
# .env.example

# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_API_TIMEOUT=10000

# Authentication
NEXT_PUBLIC_AUTH_COOKIE_NAME=auth_token
NEXT_PUBLIC_AUTH_COOKIE_DOMAIN=localhost

# Payment Gateways
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
NEXT_PUBLIC_PAYPAL_CLIENT_ID=...

# Analytics
NEXT_PUBLIC_GA_TRACKING_ID=G-...
NEXT_PUBLIC_GTM_ID=GTM-...

# Feature Flags
NEXT_PUBLIC_ENABLE_WISHLIST=true
NEXT_PUBLIC_ENABLE_REVIEWS=true
NEXT_PUBLIC_ENABLE_LOYALTY=true

# CDN & Assets
NEXT_PUBLIC_CDN_URL=https://cdn.example.com
NEXT_PUBLIC_IMAGE_DOMAIN=images.example.com

# App Configuration
NEXT_PUBLIC_APP_NAME=My E-Commerce Store
NEXT_PUBLIC_APP_URL=https://example.com
NEXT_PUBLIC_SUPPORT_EMAIL=support@example.com
```

### Next.js Configuration

```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  
  images: {
    domains: [
      'localhost',
      'images.example.com',
      'cdn.example.com',
    ],
    formats: ['image/avif', 'image/webp'],
  },
  
  // Internationalization
  i18n: {
    locales: ['en', 'vi'],
    defaultLocale: 'en',
  },
  
  // Redirects
  async redirects() {
    return [
      {
        source: '/home',
        destination: '/',
        permanent: true,
      },
    ];
  },
  
  // Headers for security
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=63072000; includeSubDomains; preload',
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
        ],
      },
    ];
  },
  
  // Webpack configuration
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        net: false,
        tls: false,
      };
    }
    return config;
  },
};

module.exports = nextConfig;
```

### Tailwind Configuration

```javascript
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#3B82F6',
          50: '#EFF6FF',
          100: '#DBEAFE',
          200: '#BFDBFE',
          300: '#93C5FD',
          400: '#60A5FA',
          500: '#3B82F6',
          600: '#2563EB',
          700: '#1D4ED8',
          800: '#1E40AF',
          900: '#1E3A8A',
        },
        secondary: {
          DEFAULT: '#10B981',
          50: '#ECFDF5',
          100: '#D1FAE5',
          200: '#A7F3D0',
          300: '#6EE7B7',
          400: '#34D399',
          500: '#10B981',
          600: '#059669',
          700: '#047857',
          800: '#065F46',
          900: '#064E3B',
        },
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        heading: ['Poppins', 'sans-serif'],
      },
      container: {
        center: true,
        padding: {
          DEFAULT: '1rem',
          sm: '2rem',
          lg: '4rem',
          xl: '5rem',
          '2xl': '6rem',
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio'),
  ],
};
```


---

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ and npm/yarn/pnpm
- Git
- Code editor (VS Code recommended)

### Installation Steps

```bash
# 1. Create Next.js project
npx create-next-app@latest web-storefront --typescript --tailwind --app --src-dir

# 2. Navigate to project
cd web-storefront

# 3. Install dependencies
npm install zustand axios react-query @tanstack/react-query
npm install @headlessui/react @radix-ui/react-dialog framer-motion
npm install react-hook-form zod @hookform/resolvers
npm install next-seo sharp
npm install -D @types/node @types/react @types/react-dom

# 4. Install dev dependencies
npm install -D eslint prettier husky lint-staged
npm install -D @testing-library/react @testing-library/jest-dom jest
npm install -D @playwright/test

# 5. Setup environment variables
cp .env.example .env.local

# 6. Run development server
npm run dev
```

### Project Initialization Script

```bash
#!/bin/bash
# scripts/init-project.sh

echo "🚀 Initializing Web Storefront Project..."

# Create directory structure
mkdir -p src/{app,components,lib,styles}
mkdir -p src/components/{ui,layout,product,cart,checkout}
mkdir -p src/lib/{api,hooks,store,utils,types}
mkdir -p public/{images,icons,fonts}
mkdir -p tests/{unit,integration,e2e}

# Create base files
touch src/lib/api/client.ts
touch src/lib/api/endpoints.ts
touch src/lib/store/cart-store.ts
touch src/lib/store/auth-store.ts
touch src/lib/utils/format.ts
touch src/lib/utils/validation.ts

# Install dependencies
npm install

echo "✅ Project initialized successfully!"
echo "📝 Next steps:"
echo "  1. Configure .env.local with your API endpoints"
echo "  2. Run 'npm run dev' to start development server"
echo "  3. Visit http://localhost:3000"
```

### Development Commands

```json
// package.json scripts
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "lint:fix": "next lint --fix",
    "format": "prettier --write \"src/**/*.{js,jsx,ts,tsx,json,css,md}\"",
    "type-check": "tsc --noEmit",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:e2e": "playwright test",
    "analyze": "ANALYZE=true next build",
    "prepare": "husky install"
  }
}
```


---

## 📱 Key Pages & Routes

### Route Structure

| Route | Description | Type | Data Source |
|-------|-------------|------|-------------|
| `/` | Homepage | SSG | CMS Service |
| `/products` | Product listing | SSR | Catalog Service |
| `/products/[slug]` | Product detail | SSR | Catalog + Pricing |
| `/products/category/[slug]` | Category page | SSR | Catalog Service |
| `/cart` | Shopping cart | Client | Local State |
| `/checkout` | Checkout flow | Client | Multiple Services |
| `/search` | Search results | SSR | Search Service |
| `/login` | Login page | Client | Auth Service |
| `/register` | Registration | Client | Auth + Customer |
| `/account/profile` | User profile | SSR | Customer Service |
| `/account/orders` | Order history | SSR | Order Service |
| `/account/orders/[id]` | Order detail | SSR | Order Service |
| `/account/addresses` | Address book | SSR | Customer Service |
| `/account/wishlist` | Wishlist | SSR | Customer Service |
| `/about` | About page | SSG | CMS Service |
| `/contact` | Contact page | SSG | CMS Service |
| `/blog` | Blog listing | SSG | CMS Service |
| `/blog/[slug]` | Blog post | SSG | CMS Service |

### Homepage Implementation

```typescript
// src/app/(shop)/page.tsx
import { HeroSection } from '@/components/home/hero-section';
import { FeaturedProducts } from '@/components/home/featured-products';
import { CategoryGrid } from '@/components/home/category-grid';
import { PromoBanner } from '@/components/home/promo-banner';
import { Newsletter } from '@/components/home/newsletter';
import { getFeaturedProducts, getCategories } from '@/lib/api/catalog';
import { getActivePromotions } from '@/lib/api/promotion';

export const revalidate = 3600; // Revalidate every hour

export default async function HomePage() {
  const [featuredProducts, categories, promotions] = await Promise.all([
    getFeaturedProducts(),
    getCategories(),
    getActivePromotions(),
  ]);

  return (
    <main>
      <HeroSection />
      
      {promotions.length > 0 && (
        <PromoBanner promotions={promotions} />
      )}
      
      <section className="container mx-auto px-4 py-12">
        <h2 className="text-3xl font-bold mb-8">Featured Products</h2>
        <FeaturedProducts products={featuredProducts} />
      </section>
      
      <section className="bg-gray-50 py-12">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold mb-8">Shop by Category</h2>
          <CategoryGrid categories={categories} />
        </div>
      </section>
      
      <Newsletter />
    </main>
  );
}
```

### Search Page

```typescript
// src/app/(shop)/search/page.tsx
import { Suspense } from 'react';
import { SearchResults } from '@/components/search/search-results';
import { SearchFilters } from '@/components/search/search-filters';
import { searchProducts } from '@/lib/api/search';

export default async function SearchPage({
  searchParams,
}: {
  searchParams: { q?: string; category?: string; price?: string };
}) {
  const results = await searchProducts({
    query: searchParams.q || '',
    category: searchParams.category,
    priceRange: searchParams.price,
  });

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-8">
        Search Results for "{searchParams.q}"
      </h1>
      
      <div className="flex gap-8">
        <aside className="w-64">
          <SearchFilters />
        </aside>
        
        <main className="flex-1">
          <Suspense fallback={<SearchResultsSkeleton />}>
            <SearchResults results={results} />
          </Suspense>
        </main>
      </div>
    </div>
  );
}
```


---

## 🔐 Authentication & Authorization

### Auth Context Provider

```typescript
// src/lib/contexts/auth-context.tsx
'use client';

import { createContext, useContext, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { login, logout, getCurrentUser } from '@/lib/api/auth';

interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = async () => {
    try {
      const token = localStorage.getItem('auth_token');
      if (token) {
        const currentUser = await getCurrentUser();
        setUser(currentUser);
      }
    } catch (error) {
      console.error('Auth check failed:', error);
      localStorage.removeItem('auth_token');
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async (email: string, password: string) => {
    const response = await login(email, password);
    localStorage.setItem('auth_token', response.token);
    setUser(response.user);
    router.push('/account');
  };

  const handleLogout = async () => {
    await logout();
    localStorage.removeItem('auth_token');
    setUser(null);
    router.push('/');
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        loading,
        login: handleLogin,
        logout: handleLogout,
        isAuthenticated: !!user,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
```

### Protected Route Component

```typescript
// src/components/auth/protected-route.tsx
'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/contexts/auth-context';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && !isAuthenticated) {
      router.push('/login?redirect=' + window.location.pathname);
    }
  }, [isAuthenticated, loading, router]);

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!isAuthenticated) {
    return null;
  }

  return <>{children}</>;
}
```

### Login Page

```typescript
// src/app/(auth)/login/page.tsx
'use client';

import { useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useAuth } from '@/lib/contexts/auth-context';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      await login(email, password);
      const redirect = searchParams.get('redirect') || '/account';
      router.push(redirect);
    } catch (err) {
      setError('Invalid email or password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container mx-auto px-4 py-16">
      <div className="max-w-md mx-auto">
        <h1 className="text-3xl font-bold mb-8">Login</h1>
        
        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="bg-red-50 text-red-600 p-3 rounded">
              {error}
            </div>
          )}
          
          <div>
            <label className="block text-sm font-medium mb-2">
              Email
            </label>
            <Input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">
              Password
            </label>
            <Input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
          
          <Button type="submit" className="w-full" loading={loading}>
            Login
          </Button>
        </form>
        
        <div className="mt-4 text-center">
          <a href="/forgot-password" className="text-sm text-primary">
            Forgot password?
          </a>
        </div>
        
        <div className="mt-4 text-center">
          <span className="text-sm text-gray-600">
            Don't have an account?{' '}
            <a href="/register" className="text-primary font-medium">
              Register
            </a>
          </span>
        </div>
      </div>
    </div>
  );
}
```


---

## 🎯 Performance Optimization

### Image Optimization

```typescript
// Use Next.js Image component for automatic optimization
import Image from 'next/image';

<Image
  src="/product.jpg"
  alt="Product"
  width={500}
  height={500}
  priority // For above-the-fold images
  placeholder="blur" // Show blur while loading
  blurDataURL="data:image/..." // Low-quality placeholder
/>
```

### Code Splitting & Lazy Loading

```typescript
// Dynamic imports for heavy components
import dynamic from 'next/dynamic';

const ProductReviews = dynamic(
  () => import('@/components/product/product-reviews'),
  {
    loading: () => <ReviewsSkeleton />,
    ssr: false, // Disable SSR for this component
  }
);

// Lazy load images below the fold
<Image
  src="/product.jpg"
  alt="Product"
  loading="lazy"
/>
```

### Caching Strategy

```typescript
// src/lib/api/client.ts - Add caching headers
apiClient.interceptors.request.use((config) => {
  // Add cache control for GET requests
  if (config.method === 'get') {
    config.headers['Cache-Control'] = 'public, max-age=300';
  }
  return config;
});

// React Query caching configuration
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      cacheTime: 10 * 60 * 1000, // 10 minutes
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});
```

### Bundle Size Optimization

```javascript
// next.config.js
module.exports = {
  // Enable SWC minification
  swcMinify: true,
  
  // Analyze bundle size
  webpack: (config, { isServer }) => {
    if (process.env.ANALYZE === 'true') {
      const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
      config.plugins.push(
        new BundleAnalyzerPlugin({
          analyzerMode: 'static',
          reportFilename: isServer
            ? '../analyze/server.html'
            : './analyze/client.html',
        })
      );
    }
    return config;
  },
};
```

### Core Web Vitals Monitoring

```typescript
// src/app/layout.tsx
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        {children}
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
```


---

## 🧪 Testing Strategy

### Unit Testing with Jest

```typescript
// tests/unit/components/product-card.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { ProductCard } from '@/components/product/product-card';

const mockProduct = {
  id: '1',
  sku: 'PROD-001',
  name: 'Test Product',
  slug: 'test-product',
  price: 99.99,
  images: ['/test-image.jpg'],
};

describe('ProductCard', () => {
  it('renders product information correctly', () => {
    render(<ProductCard product={mockProduct} />);
    
    expect(screen.getByText('Test Product')).toBeInTheDocument();
    expect(screen.getByText('$99.99')).toBeInTheDocument();
  });

  it('adds product to cart when button clicked', () => {
    const { getByText } = render(<ProductCard product={mockProduct} />);
    const addButton = getByText('Add to Cart');
    
    fireEvent.click(addButton);
    
    // Assert cart state updated
  });
});
```

### Integration Testing

```typescript
// tests/integration/checkout-flow.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { CheckoutPage } from '@/app/(shop)/checkout/page';

describe('Checkout Flow', () => {
  it('completes checkout successfully', async () => {
    const user = userEvent.setup();
    render(<CheckoutPage />);
    
    // Fill shipping form
    await user.type(screen.getByLabelText('Full Name'), 'John Doe');
    await user.type(screen.getByLabelText('Address'), '123 Main St');
    await user.click(screen.getByText('Continue to Payment'));
    
    // Fill payment form
    await user.type(screen.getByLabelText('Card Number'), '4242424242424242');
    await user.type(screen.getByLabelText('Expiry'), '12/25');
    await user.type(screen.getByLabelText('CVC'), '123');
    
    // Submit order
    await user.click(screen.getByText('Place Order'));
    
    // Assert order confirmation
    await waitFor(() => {
      expect(screen.getByText('Order Confirmed')).toBeInTheDocument();
    });
  });
});
```

### E2E Testing with Playwright

```typescript
// tests/e2e/product-purchase.spec.ts
import { test, expect } from '@playwright/test';

test('complete product purchase flow', async ({ page }) => {
  // Navigate to homepage
  await page.goto('/');
  
  // Search for product
  await page.fill('[data-testid="search-input"]', 'laptop');
  await page.click('[data-testid="search-button"]');
  
  // Click on first product
  await page.click('[data-testid="product-card"]:first-child');
  
  // Add to cart
  await page.click('[data-testid="add-to-cart"]');
  await expect(page.locator('[data-testid="cart-count"]')).toHaveText('1');
  
  // Go to cart
  await page.click('[data-testid="cart-icon"]');
  await expect(page).toHaveURL('/cart');
  
  // Proceed to checkout
  await page.click('[data-testid="checkout-button"]');
  
  // Fill checkout form
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="name"]', 'John Doe');
  await page.fill('[name="address"]', '123 Main St');
  
  // Complete payment (test mode)
  await page.fill('[name="cardNumber"]', '4242424242424242');
  await page.fill('[name="expiry"]', '12/25');
  await page.fill('[name="cvc"]', '123');
  
  // Place order
  await page.click('[data-testid="place-order"]');
  
  // Verify order confirmation
  await expect(page).toHaveURL(/\/order-confirmation\/.+/);
  await expect(page.locator('h1')).toContainText('Order Confirmed');
});
```


---

## 🚢 Deployment

### Vercel Deployment (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Deploy to production
vercel --prod

# Environment variables are managed in Vercel dashboard
```

### Docker Deployment

```dockerfile
# Dockerfile
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED 1

RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  web-storefront:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://api-gateway:8080
      - NODE_ENV=production
    depends_on:
      - api-gateway
    networks:
      - ecommerce-network

networks:
  ecommerce-network:
    external: true
```

### Kubernetes Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-storefront
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-storefront
  template:
    metadata:
      labels:
        app: web-storefront
    spec:
      containers:
      - name: web-storefront
        image: your-registry/web-storefront:latest
        ports:
        - containerPort: 3000
        env:
        - name: NEXT_PUBLIC_API_URL
          valueFrom:
            configMapKeyRef:
              name: web-config
              key: api-url
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: web-storefront
  namespace: ecommerce
spec:
  selector:
    app: web-storefront
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: LoadBalancer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-storefront-ingress
  namespace: ecommerce
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    secretName: web-storefront-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-storefront
            port:
              number: 80
```


---

## 📊 Monitoring & Analytics

### Performance Monitoring

```typescript
// src/lib/monitoring/performance.ts
export function reportWebVitals(metric: any) {
  // Send to analytics
  if (process.env.NEXT_PUBLIC_GA_TRACKING_ID) {
    window.gtag('event', metric.name, {
      value: Math.round(metric.value),
      event_label: metric.id,
      non_interaction: true,
    });
  }
  
  // Log to console in development
  if (process.env.NODE_ENV === 'development') {
    console.log(metric);
  }
}
```

### Error Tracking with Sentry

```typescript
// src/lib/monitoring/sentry.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 1.0,
  beforeSend(event, hint) {
    // Filter out certain errors
    if (event.exception) {
      const error = hint.originalException;
      if (error && error.message?.includes('ResizeObserver')) {
        return null;
      }
    }
    return event;
  },
});
```

### Google Analytics Integration

```typescript
// src/lib/analytics/gtag.ts
export const GA_TRACKING_ID = process.env.NEXT_PUBLIC_GA_TRACKING_ID;

// Track page views
export const pageview = (url: string) => {
  window.gtag('config', GA_TRACKING_ID, {
    page_path: url,
  });
};

// Track events
export const event = ({ action, category, label, value }: any) => {
  window.gtag('event', action, {
    event_category: category,
    event_label: label,
    value: value,
  });
};

// Track e-commerce events
export const trackPurchase = (order: any) => {
  window.gtag('event', 'purchase', {
    transaction_id: order.id,
    value: order.total,
    currency: 'USD',
    items: order.items.map((item: any) => ({
      item_id: item.sku,
      item_name: item.name,
      price: item.price,
      quantity: item.quantity,
    })),
  });
};
```

---

## 🔒 Security Best Practices

### Content Security Policy

```typescript
// next.config.js
const securityHeaders = [
  {
    key: 'Content-Security-Policy',
    value: `
      default-src 'self';
      script-src 'self' 'unsafe-eval' 'unsafe-inline' *.google-analytics.com;
      style-src 'self' 'unsafe-inline';
      img-src 'self' data: https:;
      font-src 'self' data:;
      connect-src 'self' *.google-analytics.com;
    `.replace(/\s{2,}/g, ' ').trim()
  },
];
```

### XSS Protection

```typescript
// Sanitize user input
import DOMPurify from 'isomorphic-dompurify';

export function sanitizeHTML(dirty: string) {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p'],
    ALLOWED_ATTR: ['href'],
  });
}
```

### Rate Limiting

```typescript
// src/middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const rateLimit = new Map();

export function middleware(request: NextRequest) {
  const ip = request.ip ?? 'unknown';
  const now = Date.now();
  const windowMs = 60 * 1000; // 1 minute
  const maxRequests = 100;

  if (!rateLimit.has(ip)) {
    rateLimit.set(ip, { count: 1, resetTime: now + windowMs });
  } else {
    const record = rateLimit.get(ip);
    
    if (now > record.resetTime) {
      record.count = 1;
      record.resetTime = now + windowMs;
    } else {
      record.count++;
      
      if (record.count > maxRequests) {
        return new NextResponse('Too Many Requests', { status: 429 });
      }
    }
  }

  return NextResponse.next();
}
```

---

## 📚 Additional Resources

### Documentation Links
- [Next.js Documentation](https://nextjs.org/docs)
- [React Documentation](https://react.dev)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [TypeScript Handbook](https://www.typescriptlang.org/docs)

### Design Resources
- [Figma Design System](link-to-figma)
- [Brand Guidelines](link-to-brand-guide)
- [Component Library](link-to-storybook)

### API Documentation
- [API Gateway Docs](../infrastructure/api-gateway.md)
- [Service Endpoints](../services/)
- [Authentication Guide](../security/security-overview.md)

---

## ✅ Implementation Checklist

### Phase 1: Setup (Week 1)
- [ ] Initialize Next.js project
- [ ] Setup TypeScript and ESLint
- [ ] Configure Tailwind CSS
- [ ] Setup folder structure
- [ ] Configure environment variables
- [ ] Setup Git repository

### Phase 2: Core Features (Weeks 2-4)
- [ ] Implement homepage
- [ ] Product listing page
- [ ] Product detail page
- [ ] Shopping cart functionality
- [ ] Search functionality
- [ ] Category pages

### Phase 3: User Features (Weeks 5-6)
- [ ] Authentication (login/register)
- [ ] User profile page
- [ ] Order history
- [ ] Address management
- [ ] Wishlist

### Phase 4: Checkout (Week 7)
- [ ] Checkout flow
- [ ] Payment integration
- [ ] Order confirmation
- [ ] Email notifications

### Phase 5: Content & SEO (Week 8)
- [ ] CMS integration
- [ ] Blog pages
- [ ] SEO optimization
- [ ] Sitemap generation
- [ ] Meta tags

### Phase 6: Testing & Optimization (Weeks 9-10)
- [ ] Unit tests
- [ ] Integration tests
- [ ] E2E tests
- [ ] Performance optimization
- [ ] Accessibility audit

### Phase 7: Deployment (Week 11)
- [ ] Setup CI/CD pipeline
- [ ] Configure production environment
- [ ] Deploy to staging
- [ ] Deploy to production
- [ ] Setup monitoring

---

**Document Status**: Ready for Implementation  
**Last Updated**: November 7, 2024  
**Maintainer**: Frontend Team  
**Next Review**: December 2024
