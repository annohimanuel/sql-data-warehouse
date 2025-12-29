/* ============================================================
   GOLD LAYER (Serving) — Dimensions + Fact (Star Schema)
   - Goal: expose business-ready entities (dims) and events (fact)
   - Gold objects are modeled for BI: stable names, clean columns,
     and surrogate keys for joins/performance.
   - NOTE: Views are *logical* (not materialized). If you need
     stable surrogate keys across time, persist dims as tables.
   - Assumes MySQL 8+ (ROW_NUMBER requires window functions).
   ============================================================ */


/* ============================================================
   DIM: CUSTOMERS
   - customer_key: surrogate key for BI joins (small int, fast)
   - customer_id/customer_number: business keys from source
   - gender: prefer CRM value unless it is 'n/a', else fall back
     to ERP value; final fallback 'n/a'
   - LEFT JOINs keep all CRM customers even if ERP attributes missing
   ============================================================ */
CREATE VIEW gold.dim_customers AS 
SELECT
    /* Surrogate key: generated from row ordering.
       WARNING: In a VIEW this can change if source rows change
       or ordering changes. For stable keys, store dim as a table
       and maintain keys via ETL. */
	ROW_NUMBER() OVER (ORDER BY ci.cust_id) AS customer_key,

	/* Business identifiers */
	ci.cust_id  AS customer_id,
    ci.cst_key  AS customer_number,

    /* Core descriptive attributes */
    ci.cst_firstname AS first_name,
    ci.cst_lastname  AS last_name,
    la.cntry          AS country,
    ci.cst_marital_status AS marital_status,

    /* Data standardization / survivorship rule:
       - use CRM gender if it's not 'n/a'
       - else use ERP gender
       - else 'n/a' */
    CASE 
        WHEN ci.cst_gndr <> 'n/a' THEN ci.cst_gndr
		ELSE COALESCE(az.gen, 'n/a')
	END AS gender,

    az.bdate          AS birth_date,
    ci.cst_create_date AS create_date

FROM silver.crm_cust_info ci

/* Location lookup by customer number (cst_key) */
LEFT JOIN silver.erp_loc_a101 la 
    ON ci.cst_key = la.cid

/* Additional customer attributes (ERP) */
LEFT JOIN silver.erp_cust_az12 az 
    ON az.cid = ci.cst_key
;


/* ============================================================
   DIM: PRODUCTS
   - product_key: surrogate key
   - product_number: business key used to link from sales
   - Filter: current products only (prd_end_dt IS NULL)
     This makes the dim "current-state". Historical product changes
     would require SCD logic (Type 2) and storing rows, not just views.
   - LEFT JOIN category table to enrich with category/subcategory
   ============================================================ */
CREATE VIEW gold.dim_products AS 
SELECT
    /* Surrogate key based on start date ordering.
       WARNING: same issue as above—row_number in a view can shift.
       Also: if multiple products share same start date, ordering can
       be non-deterministic. Consider ORDER BY prd_start_dt, prd_id. */
	ROW_NUMBER() OVER (ORDER BY pi.prd_start_dt, pi.prd_id) AS product_key,

    /* Business identifiers */
	pi.prd_id  AS product_id,
	pi.cat_id  AS category_id,
	pi.prd_key AS product_number,

    /* Descriptive attributes */
	pi.prd_nm   AS product_name,
	pi.prd_cost AS product_cost,
	pi.prd_line AS product_line,

    /* Category enrichment */
    px.cat        AS category,
    px.subcat     AS subcategory,
    px.maintenance,

    /* Effective dating (current-state only because end_dt filtered) */
    pi.prd_start_dt AS start_date

FROM silver.crm_prd_info pi

LEFT JOIN silver.erp_px_cat_g1v2 px
    ON px.id = pi.cat_id

/* Current products only: removes historical versions.
   If you later want full history, remove this filter and implement SCD. */
WHERE pi.prd_end_dt IS NULL
;


/* ============================================================
   FACT: SALES
   - Grain: one row per sales line (order_number + product + customer)
     depending on how CRM sales_details is structured.
   - Joins to dimensions using business keys:
       sd.sls_prd_key   -> dp.product_number
       sd.sls_cust_id   -> dc.customer_id
   - Outputs surrogate keys (dp.product_key, dc.customer_key) to make
     the fact table star-schema friendly.
   - LEFT JOIN keeps sales rows even if dimension lookup fails;
     you should then run FK integrity checks to find orphans.
   ============================================================ */
CREATE VIEW gold.fact_sales AS 
SELECT 
    /* Surrogate keys for star-schema joins */
	dp.product_key   AS product_key,
    dc.customer_key  AS customer_key,

    /* Degenerate dimension: order number lives in fact */
    sd.sls_ord_num   AS order_number,

    /* Dates (keep as DATE types if possible) */
    sd.sls_order_dt  AS order_date,
    sd.sls_ship_dt   AS ship_date,
    sd.sls_due_dt    AS due_date,

    /* Measures */
    sd.sls_sales     AS sales_amount,
    sd.sls_quantity  AS sales_quantity,
    sd.sls_price     AS sales_price

FROM silver.crm_sales_details sd

/* Map product business key to product surrogate key */
LEFT JOIN gold.dim_products dp
    ON dp.product_number = sd.sls_prd_key

/* Map customer business key to customer surrogate key */
LEFT JOIN gold.dim_customers dc 
    ON dc.customer_id = sd.sls_cust_id
;


/* ============================================================
   POST-BUILD VALIDATION (run as checks)
   - Find orphan product keys (fact references missing dim row)
   - Find orphan customer keys
   - If you expect perfect integrity, these should return 0 rows.
   ============================================================ */

-- Orphan product references
SELECT f.*
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
WHERE p.product_key IS NULL;

-- Orphan customer references
SELECT f.*
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;
