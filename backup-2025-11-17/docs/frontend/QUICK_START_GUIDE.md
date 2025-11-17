# Web Storefront - Quick Start Guide

> 🚀 Get your e-commerce frontend up and running in 15 minutes

---

## 📋 Prerequisites

Before you begin, ensure you have:
- ✅ Node.js 18+ installed
- ✅ npm, yarn, or pnpm package manager
- ✅ Git installed
- ✅ Code editor (VS Code recommended)
- ✅ Backend API Gateway running (or API endpoint URL)

---

## 🚀 Quick Setup (5 Steps)

### Step 1: Create Next.js Project

```bash
# Using create-next-app (recommended)
npx create-next-app@latest web-storefront \
  --typescript \
  --tailwind \
  --app \
  --src-dir \
  --import-alias "@/*"

# Navigate to project
cd web-storefront
```

### Step 2: Install Essential Dependencies

```bash
# State management & API
npm install zustand axios @tanstack/react-query

# UI Components
npm install @headlessui/react @radix-ui/react-dialog framer-motion

# Forms & Validation
npm install react-hook-form zod @hookform/resolvers

# SEO & Performance
npm install next-seo sharp

# Development tools
npm install -D @types/node @types/react @types/react-dom
npm install -D eslint prettier husky lint-staged
```

### Step 3: Setup Environment Variables

```bash
# Create .env.local file
cat > .env.local << EOF
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_API_TIMEOUT=10000

# App Configuration
NEXT_PUBLIC_APP_NAME=My E-Commerce Store
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Feature Flags
NEXT_PUBLIC_ENABLE_WISHLIST=true
NEXT_PUBLIC_ENABLE_REVIEWS=true
EOF
```

### Step 4: Create Project Structure

```bash
# Create directory structure
mkdir -p src/{components,lib,styles}
mkdir -p src/components/{ui,layout,product,cart,checkout}
mkdir -p src/lib/{api,hooks,store,utils,types}
mkdir -p public/{images,icons}

# Create essential files
touch src/lib/api/client.ts
touch src/lib/api/endpoints.ts
touch src/lib/store/cart-store.ts
touch src/lib/utils/format.ts
```

### Step 5: Run Development Server

```bash
# Start development server
npm run dev

# Open browser
# Visit http://localhost:3000
```

---

## 📁 Essential Files to Create

### 1. API Client (`src/lib/api/client.ts`)

```typescript
import axios from 'axios';

const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
});

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('auth_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export default apiClient;
```

### 2. Cart Store (`src/lib/store/cart-store.ts`)

```typescript
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  clearCart: () => void;
}

export const useCartStore = create<CartStore>()(
  persist(
    (set) => ({
      items: [],
      addItem: (item) => set((state) => ({ 
        items: [...state.items, item] 
      })),
      removeItem: (id) => set((state) => ({ 
        items: state.items.filter((i) => i.id !== id) 
      })),
      clearCart: () => set({ items: [] }),
    }),
    { name: 'cart-storage' }
  )
);
```

### 3. Format Utilities (`src/lib/utils/format.ts`)

```typescript
export function formatPrice(price: number, currency = 'USD'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
  }).format(price);
}

export function formatDate(date: Date | string): string {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(new Date(date));
}
```

### 4. Homepage (`src/app/page.tsx`)

```typescript
export default function HomePage() {
  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-4xl font-bold mb-8">
        Welcome to Our Store
      </h1>
      
      <section className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Add your featured products here */}
      </section>
    </main>
  );
}
```

---

## 🎨 Tailwind Configuration

Update `tailwind.config.js`:

```javascript
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#3B82F6',
        secondary: '#10B981',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
};
```

---

## 🔧 Next.js Configuration

Update `next.config.js`:

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    domains: ['localhost', 'your-cdn-domain.com'],
  },
};

module.exports = nextConfig;
```

---

## 📦 Package.json Scripts

Add these useful scripts:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "lint:fix": "next lint --fix",
    "format": "prettier --write \"src/**/*.{js,jsx,ts,tsx}\"",
    "type-check": "tsc --noEmit"
  }
}
```

---

## 🧪 Quick Test

Create a simple product card to test everything works:

```typescript
// src/components/product/product-card.tsx
import Image from 'next/image';
import { formatPrice } from '@/lib/utils/format';

interface ProductCardProps {
  name: string;
  price: number;
  image: string;
}

export function ProductCard({ name, price, image }: ProductCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md p-4">
      <div className="relative h-48 mb-4">
        <Image
          src={image}
          alt={name}
          fill
          className="object-cover rounded"
        />
      </div>
      <h3 className="font-semibold text-lg mb-2">{name}</h3>
      <p className="text-primary font-bold">{formatPrice(price)}</p>
    </div>
  );
}
```

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Development server runs without errors
- [ ] Homepage loads at http://localhost:3000
- [ ] Tailwind CSS styles are applied
- [ ] TypeScript compilation works
- [ ] API client can make requests
- [ ] Cart store persists data

---

## 🚨 Common Issues & Solutions

### Issue: Module not found errors
```bash
# Solution: Clear cache and reinstall
rm -rf node_modules .next
npm install
```

### Issue: TypeScript errors
```bash
# Solution: Check tsconfig.json paths
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

### Issue: Tailwind styles not working
```bash
# Solution: Ensure globals.css imports Tailwind
@tailwind base;
@tailwind components;
@tailwind utilities;
```

---

## 📚 Next Steps

Now that your project is set up:

1. **Read Full Documentation**: [web-storefront.md](./web-storefront.md)
2. **Implement Features**: Start with product listing
3. **Connect to API**: Configure API endpoints
4. **Add Components**: Build UI components
5. **Test**: Write tests for critical flows

---

## 🆘 Need Help?

- 📖 [Full Documentation](./web-storefront.md)
- 🔗 [Next.js Docs](https://nextjs.org/docs)
- 💬 [GitHub Issues](your-repo-issues-url)
- 📧 Email: dev-team@example.com

---

**Setup Time**: ~15 minutes  
**Difficulty**: Beginner-friendly  
**Last Updated**: November 7, 2024
