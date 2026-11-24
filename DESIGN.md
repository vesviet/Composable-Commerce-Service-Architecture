---
version: "1.0.0"
standard: "W3C DTCG 2025.10"
apps:
  - frontend
  - admin
primary_font: "Plus Jakarta Sans"
mono_font: "JetBrains Mono"
brand_accent_hex: "#1d4ed8"
tokens_spec: "./design-tokens-spec.json"
---

# Design System Specification — E-Commerce Storefront & Admin Operations

## 1. Architecture & Two-Tier Token Model

All visual values flow through a strict two-tier hierarchy backed by [design-tokens-spec.json](./design-tokens-spec.json):

1. **Primitive Tokens** (`color.primitive.*`, `spacing.*`, `radius.*`): Raw OKLCH perceptual color ramps and base numeric scales (4px spacing grid). Components NEVER reference raw primitive scales directly.
2. **Semantic Tokens** (`color.semantic.*`, `typography.*`, `elevation.*`): Role-bound tokens mapped to surface canvas, elevated card, ink hierarchy, brand actions, status states, and focus rings (`--surface-canvas`, `--surface-card`, `--ink-primary`, `--ink-muted`, `--brand-primary`, `--border-subtle`).

## 2. Three Dials Calibration

| Surface | Variance / Density | Motion | Brand Expression |
| :--- | :--- | :--- | :--- |
| **Storefront (`frontend`)** | Calm editorial commerce grid, generous whitespace (`16px`/`24px` container rhythm) | Subtle state feedback (`150ms–200ms` transitions), strict `prefers-reduced-motion` bypass | Cobalt Blue `#1d4ed8` (`oklch(0.49 0.21 262)`) primary CTA + Warm Amber `#b45309` campaign accents on `#f8fafc` neutral canvas |
| **Operations (`admin`)** | Compact B2B operational tables, dense form drawers (`16px` card padding) | Instant table/modal feedback, no ornamental bounce | Same `#1d4ed8` Cobalt action primary + Slate `#0f172a` high-contrast table ink |

## 3. Concentric Radii & Elevation

Maintain concentric geometry on nested containers using:

$$R_{\text{outer}} = R_{\text{inner}} + \text{padding}$$

- **Nested control inside card:** `6px` (`--radius-sm`) input/button inside `8px`–`12px` (`--radius-md`/`--radius-lg`) card with `16px` padding (`0.75rem`).
- **Pill badges:** `9999px` (`--radius-full`) only for compact status chips and count badges.
- **Elevation:** Crisp `1px` borders (`#e2e8f0`) + lightweight multi-layer shadows on cards/drawers rather than heavy drop-shadows.

## 4. Typography & Tabular Numerals

- **UI Sans (`--font-sans`):** `Plus Jakarta Sans` (weights `400`, `500`, `600`, `700`) — clean geometric readability for bilingual Vietnamese/English storefronts and admin tables.
- **Code / IDs (`--font-mono`):** `JetBrains Mono` (weights `400`, `500`) — order numbers, SKUs, UUID snippets, audit JSON diffs.
- **`tabular-nums` Mandatory Rule:** Every currency amount, discount percentage, cart subtotal/total, inventory count, backorder ratio, and KPI metric MUST use `font-variant-numeric: tabular-nums` (`tabular-nums` utility in `frontend`, `.ant-table-cell` / `.ant-statistic-content` rule in `admin`) so columns align vertically and do not jitter on live updates.

## 5. Accessibility & Contrast Standards (WCAG 2.2 AA + APCA)

- **Body text (`--ink-primary` `#0f172a` on `#ffffff`/`#f8fafc`):** Contrast `> 15:1` ($L_c \ge 90$, target minimum `>= 4.5:1` / $L_c \ge 60$).
- **Secondary ink (`--ink-muted` `#475569` on `#ffffff`):** Contrast `7.5:1` (target minimum `>= 4.5:1` / $L_c \ge 60$).
- **Brand button (`#ffffff` on `--brand-primary` `#1d4ed8`):** Contrast `6.7:1` (passes AA large & normal text).
- **Keyboard Focus:** Visible `2px` focus ring (`outline: 2px solid #2563eb`, `outline-offset: 2px`) and top-of-document `"Skip to main content"` link.
- **ARIA & Tabs:** Tablists use `role="tablist"`, `role="tab"`, `aria-selected`, `aria-controls`, and `role="tabpanel"`; icon-only buttons require descriptive `aria-label`.

## 6. Interaction State Matrix & Copy Rules

Every asynchronous route and data panel must implement all applicable states cleanly:

1. **Loading:** Route-level `loading.tsx` / skeleton placeholders matching final geometry (`aria-busy="true"`).
2. **Empty:** Clear icon/explanation + direct recovery CTA (e.g., Browse Products, Clear Filters).
3. **Error:** Factual copy explaining what failed without exclamation marks (`!`) + explicit Retry action.
4. **Unauthorized (`401`/`403`):** ProtectedRoute / Role gate with Sign In or permission guidance.
5. **Reduced Motion:** Global `@media (prefers-reduced-motion: reduce)` collapses transition and animation durations to `0.01ms`.

## 7. EU AI Act Article 50 Transparency Disclosure

Automated ranking, semantic search results, and personalized recommendations MUST render `<AIDisclosureBanner>` carrying:
- Accessible `role="note"` landmark
- Machine-readable `data-ai-generated="true"` and `data-ai-feature="search" | "recommendations"` attributes
- Concise explanation + link to `/pages/ai-transparency`.
