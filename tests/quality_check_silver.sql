/*
=====================================================================
Quality Checks
====================================================================
Script Purpose:
	This script performs various checks for data consistency,
	accuracy and standardization across the 'silver' schemas.
	It includes checks for:
	- Null or duplicate primary keys
	- Unwanted spaces in string fields
	- Data standardization and consistency
	- Invalid date ranges and orders
	- Data consistency between related fields

Usage Notes:
	- Run these checks after loading data into the silver layer
	- Investigate and resolve any discrepancies found during the checks
======================================================================

*/

/*
===================================================
Customer Detail Table Check (Silver Layer)
===================================================
*/

--- Check for Nulls or Duplicates in Primary Key
--- Expectation: None


SELECT
cst_id,
COUNT(*) as Occurence
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL


--- Check for unwanted spaces
--- Expectation: No Result
SELECT
cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)

SELECT
cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname)

--- Check for Data Standardization & Consistency
--- Expectation: None

SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info

SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info


/*
===================================================
Product Information Table Check (Silver Layer)
===================================================
*/

--- Check for Nulls or Duplicates in Primary Key
--- Expectation: None
SELECT
prd_id,
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL


--- Check for unwanted spaces
--- Expectation: No Result
SELECT
prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)


--- Check for NULL or Negative Cost
--- Expectation: None

SELECT
prd_cost
FROM silver.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0


--- Check for Data Standardization & Consistency
--- Expectation: None

SELECT DISTINCT prd_line
FROM silver.crm_prd_info

--- Check for Invalid Date Orders
--- Expectation: None
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt

/*
==================================================
Sales Details Table Check (silver Layer)
==================================================
*/

--- Check for Invalid Date Orders
--- Expectation: None

SELECT
NULLIF(sls_order_dt,0) sls_order_dt
FROM silver.crm_sales_details
WHERE LEN(sls_order_dt) < 8 OR LEN(sls_order_dt) > 8 OR sls_order_dt <= 0

SELECT
NULLIF(sls_due_dt,0) sls_due_dt
FROM silver.crm_sales_details
WHERE LEN(sls_due_dt) < 8 OR LEN(sls_due_dt) > 8 OR sls_due_dt <= 0


SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

--- Check for NULL or Negative Cost, Price or Quantity
--- Expectation: None

SELECT DISTINCT
	   sls_sales ,
	   sls_quantity,
	   sls_price 
FROM silver.crm_sales_details
WHERE sls_sales != sls_price * sls_quantity
OR sls_sales <= 0 OR sls_price <= 0 OR sls_quantity <= 0
OR sls_sales IS NULL OR sls_price IS NULL  OR sls_quantity IS NULL 
ORDER BY sls_sales,sls_quantity,sls_price

/*
==================================================
ERP Customer Information Table Check (Silver Layer)
==================================================
*/

--- Check for Invalid Date Orders
--- Expectation: None

SELECT
CASE WHEN bdate > GETDATE() THEN NULL
	ELSE bdate
END AS bdate
FROM silver.erp_cust_az12
WHERE bdate > GETDATE()

--- Check for Data Standardization & Consistency
--- Expectation: None

SELECT DISTINCT gen FROM silver.erp_cust_az12

/*
==================================================
ERP Location Information Table Check (Silver Layer)
==================================================
*/

--- Check for Data Standardization & Consistency
--- Expectation: None

SELECT DISTINCT cntry FROM silver.erp_loc_a101
