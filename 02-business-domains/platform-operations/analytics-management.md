# 📊 Analytics & Reporting Capability

## Core Domain
**Platform & Operations**

## Overview
Data analytics service providing multidimensional insights and reports on e-commerce platform performance. It extracts, aggregates, and processes data from sub-domains (Sales, Inventory, Customer...) via events/streams (Dapr PubSub).

## Key Capabilities
1. **Sales & Revenue Tracking:** Aggregates revenue, order volume, AOV (Average Order Value).
2. **Customer Cohort Analysis:** Purchase frequency, LTV (Lifetime Value).
3. **Fulfillment & Logistics Metrics:** Successful delivery rate, pickup/delivery SLAs, inventory status.
4. **Custom Dashboards:** Provides APIs to build dynamic charts for the Admin UI.

## Integrations
- Listens to events from: `Order`, `Payment`, `Shipping`, `Return`.
- Provides metrics for: Admin Dashboard.
