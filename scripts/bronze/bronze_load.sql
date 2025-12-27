/*
====================================================
 Script: bronze_load.sql
 Purpose:
   Performs a full refresh (FULL LOAD) of all Bronze
   layer tables by truncating existing data and
   reloading raw source data from CSV files.

   This script represents the ingestion step of the
   Medallion Architecture and is intentionally executed
   as standalone SQL due to MySQL limitations around
   bulk loading inside stored procedures.

   Query performance is measured using MySQL session
   profiling to capture per-table load durations.

 Notes:
   - Uses LOAD DATA LOCAL INFILE for bulk ingestion
   - Requires local_infile enabled on client & server
   - Profiling is enabled for development-time timing
   - No transformations are applied in the Bronze layer
   - Script is idempotent (safe to re-run)
====================================================
*/

-- --------------------------------------------------
-- Enable LOCAL INFILE (required for bulk loading)
-- --------------------------------------------------
SET GLOBAL local_infile = 1;

-- --------------------------------------------------
-- Enable session profiling (development only)
-- --------------------------------------------------
SET profiling = 1;

-- --------------------------------------------------
-- CRM Source System Loads
-- --------------------------------------------------

TRUNCATE TABLE bronze.crm_cust_info;
LOAD DATA LOCAL INFILE '/Users/imanuelannoh/Desktop/sql-warehouse/datasets/source_crm/cust_info.csv'
INTO TABLE bronze.crm_cust_info
FIELDS TERMINATED BY ','
IGNORE 1 ROWS;

TRUNCATE TABLE bronze.crm_prd_info;
LOAD DATA LOCAL INFILE '/Users/imanuelannoh/Desktop/sql-warehouse/datasets/source_crm/prd_info.csv'
INTO TABLE bronze.crm_prd_info
FIELDS TERMINATED BY ','
IGNORE 1 ROWS;

TRUNCATE TABLE bronze.crm_sales_details;
LOAD DATA LOCAL INFILE '/Users/imanuelannoh/Desktop/sql-warehouse/datasets/source_crm/sales_details.csv'
INTO TABLE bronze.crm_sales_details
FIELDS TERMINATED BY ','
IGNORE 1 ROWS;

-- --------------------------------------------------
-- ERP Source System Loads
-- --------------------------------------------------

TRUNCATE TABLE bronze.erp_cust_az12;
LOAD DATA LOCAL INFILE '/Users/imanuelannoh/Desktop/sql-warehouse/datasets/source_erp/CUST_AZ12.csv'
INTO TABLE bronze.erp_cust_az12
FIELDS TERMINATED BY ','
IGNORE 1 ROWS;

TRUNCATE TABLE bronze.erp_loc_a101;
LOAD DATA LOCAL INFILE '/Users/imanuelannoh/Desktop/sql-warehouse/datasets/source_erp/LOC_A101.csv'
INTO TABLE bronze.erp_loc_a101
FIELDS TERMINATED BY ','
IGNORE 1 ROWS;

TRUNCATE TABLE bronze.erp_px_cat_g1v2;
LOAD DATA LOCAL INFILE '/Users/imanuelannoh/Desktop/sql-warehouse/datasets/source_erp/PX_CAT_G1V2.csv'
INTO TABLE bronze.erp_px_cat_g1v2
FIELDS TERMINATED BY ','
IGNORE 1 ROWS;

-- --------------------------------------------------
-- Review execution times for each load operation
-- --------------------------------------------------
SHOW PROFILES;
