/* =========================================================
   SILVER LAYER LOAD SCRIPT
   Purpose: Clean, standardize, and deduplicate bronze data
   ========================================================= */


/* =========================================================
   CRM CUSTOMER INFO
   - Deduplicate customers using latest create date
   - Standardize gender & marital status codes
   - Trim text fields
   ========================================================= */

TRUNCATE TABLE silver.crm_cust_info;

INSERT INTO silver.crm_cust_info (
    cust_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_gndr,
    cst_marital_status,
    cst_create_date
)
SELECT 
    cust_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,      -- remove leading/trailing spaces
    TRIM(cst_lastname)  AS cst_lastname,
    CASE 
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    CASE 
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        ELSE 'n/a'
    END AS cst_marital_status,
    cst_create_date
FROM (
    -- Keep only the most recent record per customer
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY cust_id 
               ORDER BY cst_create_date DESC
           ) AS rnk
    FROM bronze.crm_cust_info
) t
WHERE rnk = 1
  AND cst_create_date IS NOT NULL;


/* =========================================================
   CRM PRODUCT INFO
   - Parse category ID from product key
   - Normalize product line codes
   - Handle NULL costs
   - Derive product end date using window function
   ========================================================= */

TRUNCATE TABLE silver.crm_prd_info;

INSERT INTO silver.crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
SELECT 
    prd_id,
    REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id,   -- normalize category ID
    SUBSTRING(prd_key,7,CHAR_LENGTH(prd_key)) AS prd_key,
    TRIM(prd_nm) AS prd_nm,
    IFNULL(prd_cost,0) AS prd_cost,                      -- default missing cost to 0
    CASE 
        WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
        WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
        WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
        WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    CAST(prd_start_dt AS DATE) AS prd_start_dt,
    -- End date is day before next start date (NULL for most recent product)
    CAST(
        DATE_SUB(
            LEAD(prd_start_dt) OVER (
                PARTITION BY prd_key 
                ORDER BY prd_start_dt
            ),
            INTERVAL 1 DAY
        ) AS DATE
    ) AS prd_end_dt
FROM bronze.crm_prd_info;


/* =========================================================
   CRM SALES DETAILS
   - Fix invalid dates
   - Recalculate sales if inconsistent
   - Ensure positive unit price
   ========================================================= */

TRUNCATE TABLE silver.crm_sales_details;

INSERT INTO silver.crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
)
SELECT 
    TRIM(sls_ord_num) AS sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    CASE 
        WHEN CAST(sls_order_dt AS CHAR(10)) = '0000-00-00' THEN NULL
        ELSE sls_order_dt
    END AS sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    CASE 
        -- Recalculate sales if invalid or inconsistent
        WHEN sls_sales <= 0 
          OR sls_sales IS NULL 
          OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS sls_sales,
    sls_quantity,
    CASE 
        -- Derive unit price if missing or inconsistent
        WHEN sls_price <= 0 
          OR sls_price IS NULL 
          OR sls_price != sls_sales / NULLIF(sls_quantity,0)
        THEN ABS(sls_sales / NULLIF(sls_quantity,0))
        ELSE sls_price 
    END AS sls_price
FROM bronze.crm_sales_details;


/* =========================================================
   ERP CUSTOMER (AZ12)
   - Remove NAS prefix from customer ID
   - Nullify future birthdates
   - Normalize gender values
   ========================================================= */

TRUNCATE TABLE silver.erp_cust_az12;

INSERT INTO silver.erp_cust_az12 (
    cid,
    bdate,
    gen
)
SELECT 
    CASE 
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4)
        ELSE cid 
    END AS cid,
    CASE 
        WHEN bdate > CURRENT_DATE() THEN NULL
        ELSE bdate 
    END AS bdate,
    CASE 
        WHEN LEFT(UPPER(TRIM(gen)), 1) = 'M' THEN 'Male'
        WHEN LEFT(UPPER(TRIM(gen)), 1) = 'F' THEN 'Female'
        ELSE 'n/a'
    END AS gen
FROM bronze.erp_cust_az12;


/* =========================================================
   ERP LOCATION
   - Remove control characters (\r, \n)
   - Normalize country codes and names
   ========================================================= */

TRUNCATE TABLE silver.erp_loc_a101;

INSERT INTO silver.erp_loc_a101 (
    cid,
    cntry
)
SELECT 
    REPLACE(cid, '-', '') AS cid,
    CASE
        WHEN UPPER(LEFT(TRIM(REPLACE(REPLACE(cntry,'\r',''),'\n','')),2)) = 'DE'
            THEN 'Germany'
        WHEN UPPER(LEFT(TRIM(REPLACE(REPLACE(cntry,'\r',''),'\n','')),2)) = 'US'
            THEN 'United States'
        WHEN cntry IS NULL 
          OR TRIM(REPLACE(REPLACE(cntry,'\r',''),'\n','')) = ''
            THEN 'n/a'
        ELSE TRIM(REPLACE(REPLACE(cntry,'\r',''),'\n',''))
    END AS cntry
FROM bronze.erp_loc_a101;


/* =========================================================
   ERP PRICE CATEGORY
   - Remove control characters
   - Normalize Yes / No flags
   ========================================================= */

TRUNCATE TABLE silver.erp_px_cat_g1v2;

INSERT INTO silver.erp_px_cat_g1v2 (
    id,
    cat,
    subcat,
    maintenance
)
SELECT 
    id,
    cat,
    subcat,
    CASE
        WHEN UPPER(TRIM(REPLACE(REPLACE(maintenance,'\r',''),'\n',''))) = 'YES' THEN 'Yes'
        WHEN UPPER(TRIM(REPLACE(REPLACE(maintenance,'\r',''),'\n',''))) = 'NO'  THEN 'No'
        ELSE 'n/a'
    END AS maintenance
FROM bronze.erp_px_cat_g1v2;
