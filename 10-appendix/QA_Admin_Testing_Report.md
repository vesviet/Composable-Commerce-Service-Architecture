# Admin QA Testing Report

## 🚩 PENDING ISSUES (Unfixed)

- [Critical] [Admin - Dashboard/Global] 502 Bad Gateway: Intermittent availability on first load of the admin dashboard.
- [Critical] [Admin - Dashboard/Global] CORS Policy Blocking: Endpoint `https://api.tanhdev.com/admin/v1/operations/tasks` missing `Access-Control-Allow-Origin` header. Occurs on every page.
- [Critical] [Admin - Custom] API 500 Error (List): `GET /admin/v1/customers` returns 500. Table shows "No data".
- [Critical] [Admin - Customer] API 500 Error (Segments): `GET /admin/v1/customers/segments` returns 500.
- [Critical] [Admin - Customer] API 500 Error (Create): `POST /admin/v1/customers` returns 500 in Add Customer modal.
- [Critical] [Admin - Catalog/Products] Display Bug: Category and Brand columns show raw internal UUIDs instead of names.
- [Critical] [Admin - Fulfillments] Page Crash (502 Bad Gateway): `FulfillmentsPage-*.js` fails to load, triggering a "Something went wrong" React crash screen.
- [Critical] [Admin - Orders] Broken Calculation Logic: Order Detail shows wildly incorrect Tax and Total Price calculations (e.g., Subtotal ₫5,500, Tax ₫82,500, Total ₫6,325).
- [Critical] [Admin - Pricing] Forceful Logout / API 401: Navigating to the 'Prices' page (`/pricing/prices`) returns `401 Unauthorized` and consistently triggers a redirect to the login page.
- [Critical] [Admin - Auth/Session] Auth Refresh Failure: The endpoint `.../api/v1/auth/refresh` returns a `405 Method Not Allowed`, breaking session management and causing random logouts.
- [High] [Admin - Orders] Missing Data: Order Details show "N/A" for Email and Shipping Address on CONFIRMED orders. Customer column in Order List also shows "N/A" for secondary info.
- [High] [Admin - Dashboard] Analytics API Failure: Endpoint `https://api.tanhdev.com/api/analytics-service/admin/dashboard/stats` returns `400 Bad Request`.
- [High] [Admin - Users] Incorrect Created Date: On initial load, the "Created" date shows 1/1/1970 (UNIX epoch zero).
- [High] [Admin - Catalog/Products] Broken Images: `via.placeholder.com` throws `ERR_NAME_NOT_RESOLVED`. Product thumbnails fail to load.
- [Medium] [Admin - Login] Missing Asset: `vite.svg` returns a 404 error on the login page.
- [Medium] [Admin - Warehouses] Missing Data: Type and Default columns display only a dash (`-`).
- [Medium] [Admin - Customer] Field Mismatch: UI shows Customer, Type, Status, Verification, Registration. But task requested Name, Email, Phone, Status, Segment. No Email/Phone columns visible.
- [Medium] [Admin - Users] Missing Roles: The "Roles" column for the primary admin user is empty on initial load.
- [Medium] [Admin - Roles] "Unknown" Scope: Every role displays "Unknown" under the Scope column.
- [Medium] [Admin - Roles] Initial Load Delay: Roles list takes several seconds to load sometimes.
- [Medium] [Admin - Catalog/Products] Missing Data: Price shows "Not set" and Stock shows "0" (dummy data).
- [Medium] [Admin - Catalog/Categories] UX Issue: Parent column shows generic "Has Parent" instead of the actual parent category name.
- [Medium] [Admin - Catalog/Brands] Missing Data (Logos): The Logo column only displays a placeholder text without rendering actual brand logos.
- [Medium] [Admin - Settings] Sidebar Routing Bug: Clicking "Integrations" or "System Settings" in the sidebar directs to the right URL, but the page content defaults to "General".
- [Low] [Admin - Dashboard/Global] HTTP 404: `favicon.ico` missing.
- [Low] [Admin - Shipments] Shipments page load successfully but displays empty data.
- [Low] [Admin - Promotions] Promotions table load successfully but displays empty data ("No data").
- [Low] [Admin - CMS] CMS Pages/Blogs/Banners display "No data" (API returns 200 OK empty).
- [Low] [Admin - Customer] UX: Silent failures on empty data when 500 error happens.
- [Low] [Admin - Users] Data Inconsistency: Searching for "admin" briefly populated inconsistent data.

## 🆕 NEWLY DISCOVERED ISSUES

## ✅ RESOLVED / FIXED
