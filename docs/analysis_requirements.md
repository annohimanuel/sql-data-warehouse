# Analytics Requirements (SQL Analysis)

This document defines the analytics requirements implemented in `Advanced_sql_analysis.sql`.  
Goal: produce a repeatable set of exploratory and business analytics queries on the **Gold** star schema (fact + dimensions), and publish two reporting views for customers and products.

---

## 1) Scope

### In scope
- Exploration of Gold-layer dimensions and fact table
- Core business KPI rollups (sales, orders, quantity, customers, products)
- Slice-and-dice by country, gender, category/subcategory, customer, product
- Trend analysis over time (monthly)
- Cumulative analysis (running totals)
- Performance analysis (current vs average and vs prior year)
- Part-to-whole contribution by category
- Segmentation (product cost buckets, customer spend behavior)
- Publish reporting views:
  - `gold.report` (customer-level report)
  - `gold.products_report_new` (product-level report)

### Out of scope
- Full historization / SCD handling
- Forecasting / advanced statistical modeling
- Data ingestion / ETL (handled elsewhere in the repo)
- Production scheduling/orchestration

---

## 2) Data Model Assumptions

### Source tables (Gold layer)
- `gold.fact_sales`  
  Contains transactional order line information and sales measures.
- `gold.dim_customers`  
  Customer attributes (name, birth_date, country, gender, etc.).
- `gold.dim_products`  
  Product attributes (name, category, subcategory, cost, etc.).

### Key relationships
- `gold.fact_sales.customer_key` → `gold.dim_customers.customer_key`
- `gold.fact_sales.product_key` → `gold.dim_products.product_key`

### Required fields used by analysis
**From `gold.fact_sales`:**
- `order_number`
- `order_date`
- `customer_key`
- `product_key`
- `sales_amount` (used for sales KPIs in exploration sections)
- `sales_price`, `sales_quantity` (used in reporting views)
  
**From `gold.dim_customers`:**
- `customer_key`
- `first_name`, `last_name`
- `birth_date`
- `country`
- `gender`

**From `gold.dim_products`:**
- `product_key`
- `product_id`
- `product_name`
- `category`, `subcategory`
- `product_cost`

---

## 3) Metric Definitions (single source of truth)

### Transaction-level measures
- **Sales Amount**: `sales_amount` (as stored in `gold.fact_sales`)
- **Unit Price**: `sales_price`
- **Quantity**: `sales_quantity`

### Order-level concepts
- **Distinct Orders**: `COUNT(DISTINCT order_number)`
- **Average Order Revenue (AOR)**: `total_sales / total_orders`  
  - Important: AOR is **not** `total_sales / total_quantity`.  
  - AOR is computed correctly in `gold.products_report_new`.

### Customer-level concepts
- **Customer Age**: `TIMESTAMPDIFF(YEAR, birth_date, CURDATE())`
- **Customer Lifespan (months)**: `TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date))`
- **Recency (months)**: `TIMESTAMPDIFF(MONTH, last_order_date, CURDATE())`
- **Avg Order Value**: `total_sales / num_orders`
- **Avg Monthly Spend**: `total_sales / lifespan_months` (guard divide-by-zero in production code)

### Product-level concepts
- **Product Lifespan (months)**: `TIMESTAMPDIFF(MONTH, first_order_date, last_order_date)`
- **Product Recency (months)**: `TIMESTAMPDIFF(MONTH, last_order_date, CURDATE())`

---

## 4) Required Analytics (what the script must produce)

### A) Schema / Column Discovery
**Requirement**
- Ability to explore columns across Bronze/Silver/Gold.
**Implementation**
- Query `INFORMATION_SCHEMA.COLUMNS` filtered by schema names.

---

### B) Dimension Exploration
**Requirement**
- List distinct customer countries.
- Count subcategories per category.
- View product hierarchy (category/subcategory/product_name).
**Tables**
- `gold.dim_customers`, `gold.dim_products`

---

### C) Date Exploration
**Requirement**
- Identify dataset time span (min/max `order_date`).
- Identify oldest/youngest customers and compute ages.
**Tables**
- `gold.fact_sales`, `gold.dim_customers`

---

### D) Measures Exploration (Core KPIs)
**Required KPI outputs**
- Total Sales
- Total Quantity
- Total Orders (distinct)
- Average Price (avg `sales_amount`)
- Total Customers (distinct)
- Total Products (distinct product_name)
**Output format**
- A single consolidated KPI query using `UNION ALL` into:
  - `measure_name`
  - `measure_value`

---

### E) Magnitude Analysis (distribution / volumes)
**Required outputs**
- Customers by country
- Customers by gender
- Products by category/subcategory
- Avg product cost by category
- Revenue by customer
- Revenue by category
- Order distribution by country
**Tables**
- Join `gold.fact_sales` to dimensions as needed.

---

### F) Ranking Analysis
**Required outputs**
- Top 5 products by revenue
- Bottom 5 products by revenue
**Implementation**
- Aggregate sales by `product_name`, order by SUM descending/ascending, `LIMIT 5`.

---

### G) Changes Over Time (trend)
**Required outputs**
- Monthly sales
- Monthly distinct customers
**Grain**
- Month (`DATE_FORMAT(order_date, '%y-%m')`)

---

### H) Cumulative Analysis (running totals)
**Requirement**
- Monthly sales and running total within each year.
**Implementation**
- Aggregate to monthly first.
- Running total: `SUM(monthly_sales) OVER (PARTITION BY year ORDER BY month)`

---

### I) Performance Analysis (current vs average vs prior year)
**Requirement**
For each product and year:
- Current year sales
- Avg sales across all years for that product
- Previous year sales (LAG)
- Difference from avg
- Performance label: Good/Neutral/Bad
- Trend label vs prior year: Increase/Decrease/No change

**Implementation**
- CTE aggregates `current_sales` by product + year.
- Window functions:
  - `AVG(...) OVER (PARTITION BY product_name)`
  - `LAG(...) OVER (PARTITION BY product_name ORDER BY order_year)`

---

### J) Part-to-Whole Analysis
**Requirement**
- Category contribution to total sales (% of total).
**Output**
- category
- total_sales
- perc_total (category_sales / overall_sales)

---

### K) Segmentation Analysis
**Product cost buckets**
- Below 100
- 100–500
- 501–1000
- Above 1000  
Output: number of products per bucket.

**Customer segments (behavioral)**
- VIP: at least 12 (orders or months of history per logic) and >= $5000 total spend
- Regular: at least 12 and < $5000
- New: else

> Note: In production, decide whether “12” means **months** (lifespan) or **orders**. Current segmentation query uses order counts; customer report uses lifespan months.

---

## 5) Required Reporting Views

### View 1: `gold.report` (Customer Report)
**Purpose**
Consolidate customer identity + key metrics + segment.

**Required columns**
- customer_key
- customer_fullname
- age_customer
- age_groups
- num_orders
- total_quantity
- total_sales
- avg_order_value
- avg_monthly_spend
- num_products
- last_order_date
- lifespan (months)
- recency (months since last order)
- segment_customers (VIP/Regular/New)

**Segment logic (as implemented)**
- VIP: lifespan >= 12 AND total_sales >= 5000
- Regular: lifespan >= 12 AND total_sales < 5000
- New: otherwise

---

### View 2: `gold.products_report_new` (Product Report)
**Purpose**
Consolidate product attributes + key metrics + performance segment.

**Required columns**
- product_name
- product_key
- category
- subcategory
- lifespan_months
- total_customers
- total_orders
- total_quantity_sold
- product_segment (High Performer / Mid Range / Low Performer)
- total_sales
- recency_months
- average_order_revenue (AOR = total_sales / total_orders)
- average_monthly_revenue (guard divide by 0)

**Segment logic (as implemented)**
- High Performer: total_sales > 10000
- Mid Range: total_sales between 5000 and 10000
- Low Performer: else

---

## 6) Data Quality Requirements (minimum checks)

Before trusting outputs:
- `order_date` must not be NULL in time-series and reports.
- Check join completeness:
  - Every `fact_sales.product_key` matches a record in `dim_products`
  - Every `fact_sales.customer_key` matches a record in `dim_customers`
- Validate totals:
  - Category sales sum ≈ overall sales
  - Monthly sums roll up to total sales
- Guard divisions:
  - `NULLIF(total_orders, 0)`
  - `GREATEST(lifespan_months, 1)` or `NULLIF(lifespan_months, 0)`

---

## 7) Execution Order

1. Confirm Gold tables exist:
   - `gold.fact_sales`, `gold.dim_customers`, `gold.dim_products`
2. Run exploration queries (optional).
3. Run analytics sections as needed.
4. Create/Replace views:
   - `gold.report`
   - `gold.products_report_new`

---

## 8) Output Expectations

A reviewer should be able to:
- Understand the dataset coverage (dates, customers, products)
- See KPI totals and distributions
- Identify top/bottom products
- Observe monthly trends and yearly running totals
- Compare product yearly performance vs average and prior year
- Use `gold.report` and `gold.products_report_new` as “BI-ready” tables for dashboards

---
