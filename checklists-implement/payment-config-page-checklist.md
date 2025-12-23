# Payment Config Page Implementation Checklist

> **Reference Pattern**: Shipping Settings Page (`/settings/shipping`)  
> **Target**: Payment Settings Page (`/settings/payment`)  
> **Goal**: Create payment configuration page with tabs for payment methods and gateways

## 📋 Overview

Implement payment configuration page in admin dashboard following shipping settings pattern. This will allow admins to configure:
- Payment methods (COD, Bank Transfer, Stripe, PayPal)
- Payment gateway settings
- Payment-related system settings

---

## ✅ Implementation Tasks

### 1. Backend API Endpoint (Already Exists)
- [x] GET `/api/v1/settings/payment` - Returns payment settings
- [x] Verified working: Returns `stripeEnabled`, `paypalEnabled`, `codEnabled`, `bankTransferEnabled`, `stripePublicKey`

### 2. Frontend Components

#### 2.1 Create Payment Settings Page Container
**File**: `admin/src/pages/settings/PaymentSettingsPage.tsx`
- [ ] Create main container component with Ant Design Tabs
- [ ] Follow pattern from `ShippingSettingsPage.tsx`
- [ ] Default tabs:
  - `payment-methods` - Payment Methods configuration
  - `gateways` - Gateway configuration (Stripe, PayPal)

**Reference**:
```tsx
// Pattern from ShippingSettingsPage.tsx
<Tabs activeKey={activeTab} onChange={setActiveTab}>
  <TabPane tab="Payment Methods" key="payment-methods">
    <PaymentMethodsPage />
  </TabPane>
  <TabPane tab="Gateways" key="gateways">
    <PaymentGatewaysPage />
  </TabPane>
</Tabs>
```

#### 2.2 Create Payment Methods Sub-Page
**File**: `admin/src/pages/payment/PaymentMethodsPage.tsx`
- [ ] Create component to display/edit payment methods
- [ ] Use Ant Design Card, Switch, Form components
- [ ] Fields to configure:
  - [ ] COD (Cash on Delivery) - Enable/Disable toggle
  - [ ] Bank Transfer - Enable/Disable toggle
  - [ ] Additional instructions/notes per method
- [ ] Save button to update settings via API

#### 2.3 Create Payment Gateways Sub-Page  
**File**: `admin/src/pages/payment/PaymentGatewaysPage.tsx`
- [ ] Create component for gateway configuration
- [ ] Stripe configuration section:
  - [ ] Enable/Disable toggle
  - [ ] Public Key input field
  - [ ] Secret Key input field (password type)
- [ ] PayPal configuration section:
  - [ ] Enable/Disable toggle
  - [ ] Client ID input field
  - [ ] Client Secret input field (password type)
  - [ ] Environment selector (Sandbox/Production)

### 3. API Integration

#### 3.1 API Constants
**File**: `admin/src/utils/constants.ts`
- [ ] Add payment API endpoint constant
```typescript
SETTINGS: {
  // ...existing
  PAYMENT: '/admin/v1/settings/payment',
}
```

#### 3.2 API Client Methods
**File**: `admin/src/lib/api/settingsApi.ts` (or create if not exists)
- [ ] `getPaymentSettings()` - Fetch current payment settings
- [ ] `updatePaymentSettings(data)` - Update payment settings
- [ ] Type definitions for request/response

**Types needed**:
```typescript
interface PaymentSettings {
  stripeEnabled: boolean;
  stripePublicKey: string;
  stripeSecretKey?: string;
  paypalEnabled: boolean;
  paypalClientId?: string;
  paypalClientSecret?: string;
  paypalEnvironment?: 'sandbox' | 'production';
  codEnabled: boolean;
  bankTransferEnabled: boolean;
}
```

### 4. Routing Configuration

#### 4.1 Add Route in App.tsx
**File**: `admin/src/App.tsx`
- [ ] Add payment settings route inside `/settings` routes
```tsx
<Route path="payment" element={<PaymentSettingsPage />} />
```
- [ ] Add redirect for old `/payment` routes if needed

#### 4.2 Update Menu Configuration
**File**: `admin/src/lib/config/menuConfig.ts`
- [ ] Add "Payment" menu item under Settings group
- [ ] Position after "Shipping" menu item
```typescript
{
  key: '/settings',
  children: [
    // ...existing items
    {
      key: '/settings/shipping',
      label: 'Shipping',
    },
    {
      key: '/settings/payment',  // NEW
      label: 'Payment',
    },
  ],
}
```

### 5. State Management & Form Handling

#### 5.1 Payment Methods Form
- [ ] Use Ant Design Form with `useForm` hook
- [ ] Initial values from API response
- [ ] Validation rules (if any)
- [ ] Submit handler with API call
- [ ] Loading states during API calls
- [ ] Success/error notifications

#### 5.2 Payment Gateways Form
- [ ] Separate form or same form with different sections
- [ ] Secure handling of secret keys (mask display)
- [ ] Validation for required fields when gateway is enabled
- [ ] Test connection button (optional enhancement)

### 6. UI/UX Enhancements

#### 6.1 Visual Design
- [ ] Consistent styling with shipping settings page
- [ ] Card-based layout for each payment method/gateway
- [ ] Clear section headers and descriptions
- [ ] Help text for configuration fields
- [ ] Icons for each payment method (CreditCard, Bank, etc.)

#### 6.2 User Feedback
- [ ] Loading spinner while fetching settings
- [ ] Success message on save
- [ ] Error handling with user-friendly messages
- [ ] Confirmation dialog for sensitive changes (optional)
- [ ] Form dirty state detection (unsaved changes warning)

### 7. Security Considerations

#### 7.1 Sensitive Data Handling
- [ ] Never log secret keys to console
- [ ] Use password input type for secret fields
- [ ] Mask existing secret keys (show only last 4 chars)
- [ ] HTTPS-only for API calls (already configured)
- [ ] Admin permission check for accessing settings

#### 7.2 Validation
- [ ] Validate Stripe public key format (`pk_test_` or `pk_live_`)
- [ ] Validate PayPal client ID format
- [ ] Prevent enabling gateway without required credentials

---

## 🧪 Verification Plan

### Automated Tests
**Note**: Current admin dashboard doesn't have test infrastructure set up yet.
- [ ] Consider adding unit tests for form validation logic (future enhancement)
- [ ] Consider adding integration tests for API calls (future enhancement)

### Manual Testing Checklist

#### Test 1: Navigation & Menu
1. Login to admin dashboard
2. Navigate to **Settings** menu
3. Verify "Payment" submenu item appears after "Shipping"
4. Click "Payment" - should navigate to `/settings/payment`
5. **Expected**: Payment settings page loads without errors

#### Test 2: Payment Methods Tab
1. Navigate to `/settings/payment`
2. Verify "Payment Methods" tab is active by default
3. Check all payment method toggles are displayed:
   - COD (Cash on Delivery)
   - Bank Transfer
4. Verify toggle states match API response
5. Toggle COD off, click Save
6. Refresh page
7. **Expected**: COD remains disabled (settings persisted)

#### Test 3: Payment Gateways Tab
1. Click "Gateways" tab
2. Verify Stripe configuration section:
   - Enable/Disable toggle
   - Public Key field
   - Secret Key field (masked)
3. Verify PayPal configuration section:
   - Enable/Disable toggle
   - Client ID field
   - Client Secret field (masked)
   - Environment dropdown
4. Enable Stripe, enter test keys:
   - Public: `pk_test_51XXXXXX`
   - Secret: `sk_test_51XXXXXX`
5. Click Save
6. **Expected**: Success notification, settings saved

#### Test 4: Form Validation
1. Enable Stripe gateway
2. Leave public key empty
3. Try to save
4. **Expected**: Validation error "Public key required when Stripe is enabled"
5. Fill public key with invalid format (e.g., "invalid_key")
6. **Expected**: Validation error "Invalid Stripe public key format"

#### Test 5: API Integration
1. Open browser DevTools Network tab
2. Navigate to payment settings page
3. **Expected**: GET `/admin/v1/settings/payment` called successfully
4. Toggle a setting and save
5. **Expected**: PUT/POST to payment API with updated data
6. **Expected**: Success response, UI updates

#### Test 6: Security - Secret Key Masking
1. Save Stripe secret key: `sk_test_1234567890abcdef`
2. Refresh page
3. **Expected**: Secret key field shows `••••••••cdef` (masked except last 4)
4. Click "Edit" or focus on field
5. **Expected**: Can enter new value, old value not exposed

---

## 📁 Files to Create/Modify

### New Files
1. `admin/src/pages/settings/PaymentSettingsPage.tsx` - Main container
2. `admin/src/pages/payment/PaymentMethodsPage.tsx` - Payment methods tab
3. `admin/src/pages/payment/PaymentGatewaysPage.tsx` - Gateways tab
4. `admin/src/lib/api/settingsApi.ts` - API client methods (if not exists)
5. `admin/src/types/payment.ts` - Type definitions

### Modified Files
1. `admin/src/App.tsx` - Add payment route
2. `admin/src/lib/config/menuConfig.ts` - Add payment menu item
3. `admin/src/utils/constants.ts` - Add payment API constant

---

## 🎯 Success Criteria

- [ ] Payment config page accessible via `/settings/payment`
- [ ] Menu item "Payment" appears under Settings
- [ ] Tab navigation works (Payment Methods, Gateways)
- [ ] All payment methods can be toggled on/off
- [ ] Gateway credentials can be configured
- [ ] Settings persist after page refresh
- [ ] Form validation works correctly
- [ ] Secret keys are masked in UI
- [ ] API integration functional
- [ ] No console errors
- [ ] Responsive design (works on mobile/tablet)

---

## 📝 Notes

- Follow Ant Design component patterns used in shipping settings
- Maintain consistent styling with existing admin pages
- Consider adding "Test Connection" feature for gateways in future
- May need backend endpoint updates if PUT/POST not implemented yet
- Secret key storage should use environment variables or secure vault in production

---

## 🔗 References

- Shipping Settings: `admin/src/pages/settings/ShippingSettingsPage.tsx`
- Menu Config: `admin/src/lib/config/menuConfig.ts`
- API Constants: `admin/src/utils/constants.ts`
- Existing API: `GET /api/v1/settings/payment` (verified working)
