-- ==================================================
-- SILVER LAYER – TABLE DEFINITIONS (DDL)
-- Purpose:
--   Store cleaned, standardized, and business-ready
--   data sourced from Bronze layer systems.
--   All tables include a DWH load timestamp.
-- ==================================================


-- ==================================================
-- CRM SOURCE SYSTEM TABLES
-- ==================================================

/* --------------------------------------------------
   Table: silver.crm_cust_info
   Description:
     - One row per customer (latest record only)
     - Gender and marital status normalized
     - Names trimmed and standardized
   Notes:
     - cust_id is not enforced as PK to allow reloads
     - dwh_create_date tracks Silver load time
-------------------------------------------------- */
CREATE TABLE IF NOT EXISTS silver.crm_cust_info (
    cust_id INT,                              -- Business customer identifier
    cst_key VARCHAR(50),                      -- Natural key from CRM
    cst_firstname VARCHAR(50),                -- Cleaned first name
    cst_lastname VARCHAR(50),                 -- Cleaned last name
    cst_marital_status VARCHAR(50),            -- Standardized marital status
    cst_gndr VARCHAR(50),                     -- Standardized gender
    cst_create_date DATE,                     -- Source system create date
    dwh_create_date DATETIME 
        DEFAULT CURRENT_TIMESTAMP              -- Silver layer load timestamp
) CHARACTER SET utf8mb4;


-- ==================================================
-- CRM PRODUCT INFORMATION
-- ==================================================

/* --------------------------------------------------
   Table: silver.crm_prd_info
   Description:
     - Product master data
     - Category parsed from product key
     - Product line codes normalized
     - End date derived from next product version
   Notes:
     - prd_end_dt is NULL for the active/latest record
     - prd_cost defaults to 0 if missing in source
-------------------------------------------------- */
CREATE TABLE IF NOT EXISTS silver.crm_prd_info (
    prd_id INT,                               -- Product identifier
    cat_id VARCHAR(55),                       -- Parsed category ID
    prd_key VARCHAR(50),                      -- Product natural key
    prd_nm VARCHAR(50),                       -- Cleaned product name
    prd_cost DECIMAL(10,2),                   -- Standardized product cost
    prd_line VARCHAR(50),                     -- Normalized product line
    prd_start_dt DATE,                        -- Product effective start date
    prd_end_dt DATE,                          -- Product effective end date
    dwh_create_date DATETIME 
        DEFAULT CURRENT_TIMESTAMP              -- Silver layer load timestamp
) CHARACTER SET utf8mb4;


-- ==================================================
-- CRM SALES DETAILS
-- ==================================================

/* --------------------------------------------------
   Table: silver.crm_sales_details
   Description:
     - Transaction-level sales data
     - Invalid dates corrected
     - Sales and price recalculated if inconsistent
   Notes:
     - sls_sales and sls_price are validated against
       quantity to ensure financial consistency
-------------------------------------------------- */
CREATE TABLE IF NOT EXISTS silver.crm_sales_details (
    sls_ord_num VARCHAR(50),                  -- Sales order number
    sls_prd_key VARCHAR(50),                  -- Product key
    sls_cust_id INT,                          -- Customer identifier
    sls_order_dt DATE,                        -- Order date (NULL if invalid)
    sls_ship_dt DATE,                         -- Shipping date
    sls_due_dt DATE,                          -- Due date
    sls_sales DECIMAL(12,2),                  -- Total sales amount
    sls_quantity INT,                         -- Units sold
    sls_price DECIMAL(10,2),                  -- Unit price
    dwh_create_date DATETIME 
        DEFAULT CURRENT_TIMESTAMP              -- Silver layer load timestamp
) CHARACTER SET utf8mb4;


-- ==================================================
-- ERP SOURCE SYSTEM TABLES
-- ==================================================
-- Naming Convention:
--   snake_case is used to preserve ERP naming
-- ==================================================


/* --------------------------------------------------
   Table: silver.erp_cust_az12
   Description:
     - ERP customer master data
     - NAS prefix removed from customer ID
     - Gender normalized
     - Future birthdates nullified
-------------------------------------------------- */
CREATE TABLE IF NOT EXISTS silver.erp_cust_az12 (
    cid VARCHAR(50),                          -- Customer ID (cleaned)
    bdate DATE,                               -- Birthdate (NULL if invalid)
    gen VARCHAR(50),                          -- Normalized gender
    dwh_create_date DATETIME 
        DEFAULT CURRENT_TIMESTAMP              -- Silver layer load timestamp
) CHARACTER SET utf8mb4;


/* --------------------------------------------------
   Table: silver.erp_loc_a101
   Description:
     - Customer location reference
     - Country names standardized
     - Control characters removed
   Notes:
     - Country normalization performed during load
-------------------------------------------------- */
CREATE TABLE IF NOT EXISTS silver.erp_loc_a101 (
    cid VARCHAR(50),                          -- Customer ID
    cntry VARCHAR(50),                        -- Standardized country name
    dwh_create_date DATETIME 
        DEFAULT CURRENT_TIMESTAMP              -- Silver layer load timestamp
) CHARACTER SET utf8mb4;


/* --------------------------------------------------
   Table: silver.erp_px_cat_g1v2
   Description:
     - Price category reference data
     - Maintenance flag normalized to Yes/No
-------------------------------------------------- */
CREATE TABLE IF NOT EXISTS silver.erp_px_cat_g1v2 (
    id VARCHAR(50),                           -- Category identifier
    cat VARCHAR(50),                          -- Category
    subcat VARCHAR(50),                       -- Subcategory
    maintenance VARCHAR(50),                  -- Normalized maintenance flag
    dwh_create_date DATETIME 
        DEFAULT CURRENT_TIMESTAMP              -- Silver layer load timestamp
) CHARACTER SET utf8mb4;
