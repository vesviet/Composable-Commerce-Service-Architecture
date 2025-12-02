# ✅ Sprint 5 Checklist - Order Analytics & Reporting

**Duration**: Week 9-10  
**Goal**: Implement Order Analytics & Reporting System  
**Target Progress**: 95% → 96%

---

## 📋 Overview

- [ ] **Task**: Implement Order Analytics & Reporting (0% → 100%)

**Team**: 2 developers  
**Estimated Effort**: 2 weeks  
**Impact**: 🟢 LOW (Business intelligence)  
**Risk**: 🟢 LOW (Independent feature)

---

## 📊 Task: Order Analytics & Reporting

### Week 9: Analytics Infrastructure & Core Metrics

#### 9.1 Analytics Database Setup

**Assignee**: Dev 1

- [ ] **Choose Analytics Database**
  - [ ] Option 1: TimescaleDB (PostgreSQL extension for time-series)
  - [ ] Option 2: ClickHouse (columnar database for analytics)
  - [ ] Option 3: Separate PostgreSQL database with optimized schema
  - [ ] **Decision**: [Choose based on scale and requirements]

- [ ] **Database Setup**
  - [ ] Install and configure analytics database
  - [ ] Create database: `analytics_db`
  - [ ] Configure connection pooling
  - [ ] Set up replication (if needed)
  - [ ] Configure backup strategy

- [ ] **Schema Design**
  - [ ] Create `order_facts` table (fact table)
    ```sql
    - id (UUID, PK)
    - order_id (UUID, indexed)
    - customer_id (UUID, indexed)
    - order_date (timestamp, indexed)
    - order_status (varchar, indexed)
    - subtotal (decimal)
    - tax_amount (decimal)
    - shipping_cost (decimal)
    - discount_amount (decimal)
    - total_amount (decimal)
    - payment_method (varchar)
    - shipping_method (varchar)
    - warehouse_id (UUID)
    - created_at (timestamp)
    ```
  
  - [ ] Create `order_item_facts` table
    ```sql
    - id (UUID, PK)
    - order_id (UUID, FK, indexed)
    - product_id (UUID, indexed)
    - category_id (UUID, indexed)
    - brand_id (UUID, indexed)
    - quantity (int)
    - unit_price (decimal)
    - discount_amount (decimal)
    - total_amount (decimal)
    - created_at (timestamp)
    ```
  
  - [ ] Create `customer_facts` table
    ```sql
    - customer_id (UUID, PK)
    - first_order_date (timestamp)
    - last_order_date (timestamp)
    - total_orders (int)
    - total_spent (decimal)
    - average_order_value (decimal)
    - lifetime_value (decimal)
    - updated_at (timestamp)
    ```
  
  - [ ] Create `product_performance` table
    ```sql
    - product_id (UUID, PK)
    - date (date, indexed)
    - units_sold (int)
    - revenue (decimal)
    - orders_count (int)
    - updated_at (timestamp)
    ```
  
  - [ ] Create `daily_metrics` table (aggregated)
    ```sql
    - date (date, PK)
    - total_orders (int)
    - total_revenue (decimal)
    - total_customers (int)
    - new_customers (int)
    - average_order_value (decimal)
    - conversion_rate (decimal)
    - updated_at (timestamp)
    ```

- [ ] **Create Indexes**
  - [ ] Time-based indexes (order_date, created_at)
  - [ ] Customer indexes
  - [ ] Product indexes
  - [ ] Status indexes
  - [ ] Composite indexes for common queries

- [ ] **Create Views**
  - [ ] `v_sales_by_day` - Daily sales summary
  - [ ] `v_sales_by_product` - Product performance
  - [ ] `v_sales_by_category` - Category performance
  - [ ] `v_customer_segments` - Customer segmentation
  - [ ] `v_top_customers` - Top customers by revenue

#### 9.2 ETL Pipeline Implementation

**Assignee**: Dev 1

- [ ] **Create Analytics Service**
  - [ ] Create new service: `analytics-service`
  - [ ] Set up project structure (Kratos v2)
  - [ ] Configure database connections
  - [ ] Set up logging and monitoring

- [ ] **ETL Worker** (`cmd/etl-worker/`)
  - [ ] Create ETL worker application
  - [ ] Configure cron schedule (every 5 minutes for real-time, hourly for aggregations)
  - [ ] Set up error handling and retry logic

- [ ] **Data Extraction** (`internal/biz/etl/extract.go`)
  - [ ] Create `DataExtractor` struct
  - [ ] Implement `ExtractOrders(ctx, since)` method
    - [ ] Query Order Service for new/updated orders
    - [ ] Query Order Service for order items
    - [ ] Handle pagination
    - [ ] Handle errors
  - [ ] Implement `ExtractCustomers(ctx, since)` method
  - [ ] Implement `ExtractProducts(ctx, since)` method
  - [ ] Add incremental extraction (only new/updated data)

- [ ] **Data Transformation** (`internal/biz/etl/transform.go`)
  - [ ] Create `DataTransformer` struct
  - [ ] Implement `TransformOrder(order)` method
    - [ ] Map to order_facts schema
    - [ ] Calculate derived fields
    - [ ] Handle null values
    - [ ] Validate data
  - [ ] Implement `TransformOrderItems(items)` method
  - [ ] Implement `TransformCustomer(customer, orders)` method
    - [ ] Calculate total orders
    - [ ] Calculate total spent
    - [ ] Calculate average order value
    - [ ] Calculate lifetime value
  - [ ] Add data quality checks

- [ ] **Data Loading** (`internal/biz/etl/load.go`)
  - [ ] Create `DataLoader` struct
  - [ ] Implement `LoadOrders(ctx, facts)` method
    - [ ] Bulk insert to analytics database
    - [ ] Handle duplicates (upsert)
    - [ ] Handle errors
  - [ ] Implement `LoadOrderItems(ctx, facts)` method
  - [ ] Implement `LoadCustomers(ctx, facts)` method
  - [ ] Implement `LoadProductPerformance(ctx, facts)` method
  - [ ] Add transaction support
  - [ ] Add batch processing (1000 records per batch)

- [ ] **Aggregation Jobs** (`internal/biz/etl/aggregate.go`)
  - [ ] Create `AggregationJob` struct
  - [ ] Implement `AggregateDailyMetrics(ctx, date)` method
    - [ ] Calculate daily totals
    - [ ] Calculate averages
    - [ ] Calculate conversion rates
    - [ ] Store in daily_metrics table
  - [ ] Implement `AggregateProductPerformance(ctx, date)` method
  - [ ] Implement `AggregateCustomerMetrics(ctx)` method
  - [ ] Schedule jobs (daily at 00:00 UTC)

- [ ] **Event Consumers** (`internal/data/eventbus/`)
  - [ ] Create `OrderEventConsumer`
  - [ ] Subscribe to `order.created` event
    - [ ] Trigger ETL for new order
  - [ ] Subscribe to `order.updated` event
    - [ ] Update order facts
  - [ ] Subscribe to `order.completed` event
    - [ ] Update metrics
  - [ ] Add idempotency handling

- [ ] **Testing**
  - [ ] Unit tests for extraction logic
  - [ ] Unit tests for transformation logic
  - [ ] Unit tests for loading logic
  - [ ] Integration test: Full ETL pipeline
  - [ ] Test with large datasets (10k orders)
  - [ ] Test error handling
  - [ ] Test incremental updates

#### 9.3 Core Metrics Implementation

**Assignee**: Dev 1

- [ ] **Business Logic** (`internal/biz/metrics/`)
  - [ ] Create `MetricsUsecase` struct
  
  - [ ] **Sales Metrics**
    - [ ] Implement `GetSalesMetrics(ctx, dateRange)` method
      - [ ] Total revenue
      - [ ] Total orders
      - [ ] Average order value
      - [ ] Revenue by day/week/month
      - [ ] Growth rate (vs previous period)
    
    - [ ] Implement `GetSalesByProduct(ctx, dateRange, limit)` method
      - [ ] Top products by revenue
      - [ ] Top products by units sold
      - [ ] Product performance trends
    
    - [ ] Implement `GetSalesByCategory(ctx, dateRange)` method
      - [ ] Revenue by category
      - [ ] Category distribution
    
    - [ ] Implement `GetSalesByBrand(ctx, dateRange)` method
  
  - [ ] **Customer Metrics**
    - [ ] Implement `GetCustomerMetrics(ctx, dateRange)` method
      - [ ] Total customers
      - [ ] New customers
      - [ ] Returning customers
      - [ ] Customer retention rate
      - [ ] Churn rate
    
    - [ ] Implement `GetCustomerLifetimeValue(ctx)` method
      - [ ] Average CLV
      - [ ] CLV distribution
      - [ ] CLV by segment
    
    - [ ] Implement `GetTopCustomers(ctx, limit)` method
      - [ ] Top customers by revenue
      - [ ] Top customers by order count
  
  - [ ] **Order Metrics**
    - [ ] Implement `GetOrderMetrics(ctx, dateRange)` method
      - [ ] Order count by status
      - [ ] Order status distribution
      - [ ] Average order processing time
      - [ ] Order fulfillment rate
    
    - [ ] Implement `GetConversionMetrics(ctx, dateRange)` method
      - [ ] Conversion rate
      - [ ] Cart abandonment rate
      - [ ] Checkout completion rate
  
  - [ ] **Revenue Metrics**
    - [ ] Implement `GetRevenueBreakdown(ctx, dateRange)` method
      - [ ] Revenue by payment method
      - [ ] Revenue by shipping method
      - [ ] Revenue by warehouse
      - [ ] Revenue by customer segment

- [ ] **Data Layer** (`internal/data/postgres/`)
  - [ ] Create `MetricsRepo` interface
  - [ ] Implement repository methods for each metric
  - [ ] Optimize queries with indexes
  - [ ] Add caching for frequently accessed metrics (Redis, 5min TTL)

- [ ] **Service Layer** (`internal/service/`)
  - [ ] Add gRPC methods for all metrics
  - [ ] Add HTTP endpoints via gRPC-Gateway
  - [ ] Add date range validation
  - [ ] Add pagination for large results
  - [ ] Add export functionality (CSV, Excel)

- [ ] **Testing**
  - [ ] Unit tests for all metrics calculations
  - [ ] Test date range filtering
  - [ ] Test data accuracy
  - [ ] Test performance with large datasets
  - [ ] Test caching

### Week 10: Advanced Analytics & Dashboard

#### 9.4 Advanced Analytics Implementation

**Assignee**: Dev 2

- [ ] **Cohort Analysis** (`internal/biz/analytics/cohort.go`)
  - [ ] Create `CohortAnalysisUsecase` struct
  - [ ] Implement `GetCohortAnalysis(ctx, cohortType, dateRange)` method
    - [ ] Group customers by cohort (month of first order)
    - [ ] Calculate retention rate per cohort
    - [ ] Calculate revenue per cohort
    - [ ] Return cohort matrix
  - [ ] Implement `GetCohortRetention(ctx, cohortID)` method
  - [ ] Add visualization data format

- [ ] **RFM Analysis** (`internal/biz/analytics/rfm.go`)
  - [ ] Create `RFMAnalysisUsecase` struct
  - [ ] Implement `CalculateRFMScores(ctx)` method
    - [ ] Recency: Days since last order
    - [ ] Frequency: Number of orders
    - [ ] Monetary: Total spent
    - [ ] Score each dimension (1-5)
    - [ ] Combine into RFM score
  - [ ] Implement `GetRFMSegments(ctx)` method
    - [ ] Champions (555)
    - [ ] Loyal Customers (X5X)
    - [ ] At Risk (X1X)
    - [ ] Lost (1XX)
    - [ ] etc.
  - [ ] Implement `GetCustomersByRFMSegment(ctx, segment)` method

- [ ] **Product Performance Analysis** (`internal/biz/analytics/product.go`)
  - [ ] Create `ProductAnalysisUsecase` struct
  - [ ] Implement `GetProductPerformance(ctx, productID, dateRange)` method
    - [ ] Sales trend
    - [ ] Revenue trend
    - [ ] Conversion rate
    - [ ] Return rate
    - [ ] Customer reviews
  - [ ] Implement `GetProductComparison(ctx, productIDs, dateRange)` method
  - [ ] Implement `GetSlowMovingProducts(ctx, threshold)` method
  - [ ] Implement `GetFastMovingProducts(ctx, limit)` method

- [ ] **Customer Segmentation** (`internal/biz/analytics/segmentation.go`)
  - [ ] Create `SegmentationUsecase` struct
  - [ ] Implement `GetCustomerSegments(ctx)` method
    - [ ] By total spent (high, medium, low value)
    - [ ] By order frequency (frequent, occasional, one-time)
    - [ ] By recency (active, at-risk, lost)
    - [ ] By product preferences
  - [ ] Implement `GetSegmentMetrics(ctx, segmentID)` method
    - [ ] Segment size
    - [ ] Average CLV
    - [ ] Average order value
    - [ ] Retention rate

- [ ] **Churn Prediction** (`internal/biz/analytics/churn.go`)
  - [ ] Create `ChurnPredictionUsecase` struct
  - [ ] Implement `PredictChurn(ctx, customerID)` method
    - [ ] Calculate churn risk score (0-100)
    - [ ] Based on: recency, frequency, engagement
    - [ ] Return risk level (low, medium, high)
  - [ ] Implement `GetChurnRiskCustomers(ctx, riskLevel)` method
  - [ ] Implement `GetChurnRate(ctx, dateRange)` method

- [ ] **Testing**
  - [ ] Unit tests for cohort analysis
  - [ ] Unit tests for RFM calculations
  - [ ] Unit tests for segmentation
  - [ ] Test with real data
  - [ ] Test performance

#### 9.5 Admin Dashboard Implementation

**Assignee**: Dev 2

- [ ] **Dashboard API** (`internal/service/dashboard.go`)
  - [ ] Create `DashboardService`
  - [ ] Implement `GetDashboardOverview(ctx, dateRange)` method
    - [ ] Aggregate key metrics
    - [ ] Return dashboard data
  - [ ] Implement `GetDashboardCharts(ctx, dateRange)` method
    - [ ] Sales chart data
    - [ ] Revenue chart data
    - [ ] Customer chart data
  - [ ] Add caching (Redis, 5min TTL)

- [ ] **Admin Panel UI** (`admin/src/pages/Analytics/`)
  - [ ] Create analytics dashboard page (`/admin/analytics`)
  
  - [ ] **Overview Section**
    - [ ] Create metric cards
      - [ ] Total Revenue (with % change)
      - [ ] Total Orders (with % change)
      - [ ] Average Order Value (with % change)
      - [ ] Total Customers (with % change)
    - [ ] Add date range selector (today, 7d, 30d, 90d, custom)
    - [ ] Add comparison toggle (vs previous period)
  
  - [ ] **Sales Dashboard** (`/admin/analytics/sales`)
    - [ ] Create sales chart (line chart)
      - [ ] Revenue over time
      - [ ] Orders over time
      - [ ] Toggle between daily/weekly/monthly
    - [ ] Create revenue breakdown (pie chart)
      - [ ] By payment method
      - [ ] By shipping method
      - [ ] By warehouse
    - [ ] Create top products table
      - [ ] Product name, units sold, revenue
      - [ ] Sort by revenue/units
      - [ ] Pagination
    - [ ] Create category performance chart (bar chart)
  
  - [ ] **Customer Dashboard** (`/admin/analytics/customers`)
    - [ ] Create customer metrics cards
      - [ ] Total customers
      - [ ] New customers
      - [ ] Retention rate
      - [ ] Churn rate
    - [ ] Create customer growth chart (line chart)
    - [ ] Create CLV distribution chart (histogram)
    - [ ] Create RFM segments chart (scatter plot)
    - [ ] Create top customers table
      - [ ] Customer name, orders, revenue, CLV
      - [ ] Sort options
      - [ ] Pagination
  
  - [ ] **Product Dashboard** (`/admin/analytics/products`)
    - [ ] Create product performance table
      - [ ] Product name, units sold, revenue, growth
      - [ ] Filters: category, brand, date range
      - [ ] Sort options
      - [ ] Pagination
    - [ ] Create product comparison tool
      - [ ] Select multiple products
      - [ ] Compare metrics side-by-side
      - [ ] Trend charts
    - [ ] Create slow-moving products alert
    - [ ] Create out-of-stock impact report
  
  - [ ] **Cohort Analysis** (`/admin/analytics/cohorts`)
    - [ ] Create cohort matrix (heatmap)
      - [ ] Rows: cohorts (by month)
      - [ ] Columns: months since first order
      - [ ] Values: retention rate
    - [ ] Create cohort revenue chart
    - [ ] Add cohort filters
  
  - [ ] **Export Functionality**
    - [ ] Add export button to each dashboard
    - [ ] Export to CSV
    - [ ] Export to Excel
    - [ ] Export to PDF (charts as images)
    - [ ] Schedule automated reports (email)

- [ ] **UI Components**
  - [ ] Create reusable chart components
    - [ ] LineChart component
    - [ ] BarChart component
    - [ ] PieChart component
    - [ ] HeatmapChart component
  - [ ] Use charting library (recharts or Chart.js)
  - [ ] Add loading states
  - [ ] Add error states
  - [ ] Add empty states

- [ ] **Testing**
  - [ ] Test all dashboard components
  - [ ] Test data loading
  - [ ] Test chart rendering
  - [ ] Test export functionality
  - [ ] Test responsive design
  - [ ] Test performance with large datasets

#### 9.6 Documentation

- [ ] **API Documentation**
  - [ ] Document all analytics endpoints
  - [ ] Add request/response examples
  - [ ] Document query parameters
  - [ ] Document date range formats
  - [ ] Update OpenAPI spec

- [ ] **Metrics Documentation**
  - [ ] Document all metrics definitions
  - [ ] Document calculation formulas
  - [ ] Document data sources
  - [ ] Document update frequency
  - [ ] Document data accuracy

- [ ] **Dashboard User Guide**
  - [ ] How to use analytics dashboard
  - [ ] How to interpret metrics
  - [ ] How to export reports
  - [ ] How to schedule reports
  - [ ] Best practices

- [ ] **Developer Guide**
  - [ ] ETL pipeline architecture
  - [ ] How to add new metrics
  - [ ] How to optimize queries
  - [ ] Testing guide
  - [ ] Deployment guide

---

## 📊 Sprint 5 Success Criteria

- [ ] ✅ Analytics database operational
- [ ] ✅ ETL pipeline running (every 5 minutes)
- [ ] ✅ Core metrics implemented (sales, customers, orders)
- [ ] ✅ Advanced analytics implemented (cohort, RFM, churn)
- [ ] ✅ Admin dashboard complete with charts
- [ ] ✅ Export functionality working
- [ ] ✅ All tests passing
- [ ] ✅ Documentation complete
- [ ] ✅ Code review approved
- [ ] ✅ Deployed to staging environment

### Metrics
- [ ] ✅ Dashboard load time: <2 seconds
- [ ] ✅ ETL processing time: <5 minutes
- [ ] ✅ Query response time: <500ms
- [ ] ✅ Data accuracy: 100%
- [ ] ✅ Admin user satisfaction: >4.5/5

### Overall Progress
- [ ] ✅ New Analytics Service: 0% → 100%
- [ ] ✅ Admin Panel: 80% → 85%
- [ ] ✅ Overall Progress: 95% → 96%

---

## 🚀 Deployment Checklist

- [ ] **Pre-Deployment**
  - [ ] All tests passing
  - [ ] Code review approved
  - [ ] Documentation updated
  - [ ] Database setup complete
  - [ ] ETL jobs configured
  - [ ] Monitoring configured

- [ ] **Staging Deployment**
  - [ ] Deploy Analytics Service
  - [ ] Deploy ETL Worker
  - [ ] Deploy Admin Panel updates
  - [ ] Run initial ETL (backfill historical data)
  - [ ] Verify data accuracy
  - [ ] Test dashboard
  - [ ] Test export functionality

- [ ] **Production Deployment**
  - [ ] Create deployment plan
  - [ ] Deploy analytics database
  - [ ] Deploy Analytics Service
  - [ ] Deploy ETL Worker
  - [ ] Deploy Admin Panel
  - [ ] Run initial ETL (backfill)
  - [ ] Verify data accuracy
  - [ ] Monitor ETL jobs
  - [ ] Monitor dashboard performance

- [ ] **Post-Deployment**
  - [ ] Monitor ETL job success rate
  - [ ] Monitor query performance
  - [ ] Monitor dashboard usage
  - [ ] Gather admin feedback
  - [ ] Optimize slow queries
  - [ ] Update documentation

---

## 📝 Notes & Issues

### Blockers
- [ ] None identified

### Risks
- [ ] **LOW**: ETL may be slow with large datasets
  - **Mitigation**: Batch processing, incremental updates, optimize queries
- [ ] **LOW**: Dashboard may be slow with complex queries
  - **Mitigation**: Caching, pre-aggregation, query optimization

### Dependencies
- [ ] Order Service must be stable
- [ ] Historical order data must be available
- [ ] Admin users need training on analytics

### Questions
- [ ] Which analytics database to use? **Answer**: TimescaleDB (PostgreSQL extension)
- [ ] How often to run ETL? **Answer**: Every 5 minutes for real-time, hourly for aggregations
- [ ] How long to retain analytics data? **Answer**: 2 years
- [ ] Do we need real-time analytics? **Answer**: Near real-time (5min delay) is acceptable

---

**Last Updated**: December 2, 2025  
**Sprint Start**: [Date]  
**Sprint End**: [Date]  
**Sprint Review**: [Date]
