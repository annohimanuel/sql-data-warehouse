/*
====================================================
 init.sql — Data Warehouse Initialization (MySQL)
====================================================

Author: Imanuel Annoh
Purpose:
- Initialize the database environment for the data warehouse
- Demonstrate Medallion Architecture concepts in MySQL

IMPORTANT (MySQL-specific note):
- In MySQL, SCHEMA and DATABASE are equivalent
- Creating a schema creates a separate database
- For this project, schemas are created intentionally
  to conceptually represent Bronze, Silver, and Gold layers
====================================================
*/

-- --------------------------------------------------
-- Create main warehouse database
-- --------------------------------------------------
CREATE DATABASE IF NOT EXISTS DataWarehouse;

-- --------------------------------------------------
-- Medallion Architecture Layers (MySQL Schemas)
--
-- NOTE:
-- In MySQL, each schema below is created as its own
-- database. These represent logical layers of the
-- data warehouse, not schemas inside one database.
--
-- Bronze  → Raw, unprocessed source data
-- Silver  → Cleaned and standardized data
-- Gold    → Analytics-ready star schema
-- --------------------------------------------------

CREATE SCHEMA IF NOT EXISTS Bronze;
CREATE SCHEMA IF NOT EXISTS Silver;
CREATE SCHEMA IF NOT EXISTS Gold;

-- --------------------------------------------------
-- Usage Example:
-- USE Bronze;
-- USE Silver;
-- USE Gold;
--
-- Tables will be created inside each layer explicitly
-- --------------------------------------------------