/*
====================================================
 Script: bronze_tables.sql
 Purpose:
   Defines the Bronze layer tables for the data warehouse.
   These tables store raw data ingested directly from CRM
   and ERP source systems with minimal transformation.

   The Bronze layer acts as the immutable landing zone
   in the Medallion Architecture, preserving source data
   structure and enabling traceability and data lineage.

 Notes:
   - Tables are created using final snake_case naming
   - No business logic or transformations are applied
   - Data types reflect source-system representations
   - utf8mb4 is used for full Unicode compatibility
====================================================
*/

-- ==================================================
-- Bronze Layer: CRM Source System Tables
-- ==================================================

CREATE TABLE IF NOT EXISTS bronze.crm_cust_info (
    cust_id INT,
    cst_key VARCHAR(50),
    cst_firstname VARCHAR(50),
    cst_lastname VARCHAR(50),
    cst_marital_status VARCHAR(50),
    cst_gndr VARCHAR(50),
    cst_create_date DATE
) CHARACTER SET utf8mb4;

CREATE TABLE IF NOT EXISTS bronze.crm_prd_info (
    prd_id INT,
    prd_key VARCHAR(50),
    prd_nm VARCHAR(50),
    prd_cost DECIMAL(10,2),
    prd_line VARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt DATE
) CHARACTER SET utf8mb4;

CREATE TABLE IF NOT EXISTS bronze.crm_sales_details (
    sls_ord_num VARCHAR(50),
    sls_prd_key VARCHAR(50),
    sls_cust_id INT,
    sls_order_dt DATE,
    sls_ship_dt DATE,
    sls_due_dt DATE,
    sls_sales DECIMAL(12,2),
    sls_quantity INT,
    sls_price DECIMAL(10,2)
) CHARACTER SET utf8mb4;

-- ==================================================
-- Bronze Layer: ERP Source System Tables
-- ==================================================
-- NOTE:
-- Tables are created directly using snake_case.
-- ==================================================

CREATE TABLE IF NOT EXISTS bronze.erp_cust_az12 (
    cid VARCHAR(50),
    bdate DATE,
    gen VARCHAR(50)
) CHARACTER SET utf8mb4;

CREATE TABLE IF NOT EXISTS bronze.erp_loc_a101 (
    cid VARCHAR(50),
    cntry VARCHAR(50)
) CHARACTER SET utf8mb4;

CREATE TABLE IF NOT EXISTS bronze.erp_px_cat_g1v2 (
    id VARCHAR(50),
    cat VARCHAR(50),
    subcat VARCHAR(50),
    maintenance VARCHAR(50)
) CHARACTER SET utf8mb4;
