/*
=============================================================================================================

Stored Procedure: Load Silver Layer (Bronze  -> Silver)

=============================================================================================================
Script Purpose:
	This stored procedure loads data into the 'silver' schema from the bronze layer. It performs the ETL
	(Extract, Transform, Load) process to populate the 'silver' schema tables from the 'bronze schema'

	It performs the following actions:
		- Truncates the silver tables before loading data
		- Inserts transformed and cleansed data from bronze into silver tables
	Parameters:
		None.
	 This stored procedure does not accept any parameters and does not return any values.

	Usage Example:
		EXEC silver.load_silver;

============================================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME
	BEGIN TRY
		SET @batch_start_time = GETDATE()
		PRINT '=======================================';
		PRINT 'Loading Silver Layer';
		PRINT '=======================================';

		PRINT '---------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '---------------------------------------';

/*
==============================================================
DDL Script: Insert Values into silver.crm_cust_info
=============================================================
Note: This scripts after checking for correctness and quality
	  inserts data from the bronze.crm_cust_info table into
	  the silver.crm_cust_info
=============================================================
*/
		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting Data into silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info(
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date)

		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname, --- remove leading and trailing spaces
			TRIM(cst_lastname) AS cst_lastname, --- remove leading and trailing spaces
			CASE WHEN TRIM( UPPER(cst_marital_status)) = 'S' THEN 'Single'
				 WHEN TRIM(UPPER(cst_marital_status)) = 'M' THEN 'Married'
				 ELSE 'n/a'
			END cst_marital_status, ----normalized marital status value to readable format
			CASE WHEN TRIM( UPPER(cst_gndr)) = 'F' THEN 'Female'
				 WHEN TRIM(UPPER(cst_gndr)) = 'M' THEN 'Male'
				 ELSE 'n/a'
			END cst_gndr, ----normalized gender value to readable format
			cst_create_date

		FROM

		-----Selecting from the most recent record for each customer by removing duplicate promary key
		(
			SELECT 
			*,
			ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		) t
		WHERE flag_last = 1
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		
		PRINT '-----------------------'
/*
================================================================
DDL Script: Insert Values into silver.crm_prd_info
===============================================================
Note: This script, after checking for correctness and quality,
	  inserts data from the bronze.crm_prd_info table into
	  the silver.crm_prd_info. 
	  Due to adding additional columns to the table, the intial
	  table is dropped first and a new one is created to include
	  the new fields
===============================================================
*/		SET @start_time = GETDATE()
		IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
			DROP TABLE silver.crm_prd_info;
		CREATE TABLE silver.crm_prd_info (
			prd_id INT,
			cat_id NVARCHAR(50),
			prd_key NVARCHAR(50),
			prd_nm NVARCHAR(50),
			prd_cost INT,
			prd_line NVARCHAR(50),
			prd_start_dt DATE,
			prd_end_dt DATE,
			dwh_create_date DATETIME DEFAULT GETDATE()
		);

		PRINT '>> Truncating Table: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting Data into silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info(
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt )

		SELECT 
			prd_id,
			REPLACE(SUBSTRING(prd_key,1,5),'-','_') cat_id, ----returns the first 5 characters as the cat id and replaces '-' with '_'
			SUBSTRING(prd_key, 7,LEN(prd_key)) prd_key, ----returns the character from the 7th position to end as the product key
			prd_nm,
			ISNULL(prd_cost,0) prd_cost, ---replaces NULL with 0
			CASE TRIM(UPPER(prd_line)) ----normalized Product Line value to readable format
				 WHEN  'M' THEN 'Mountain'
				 WHEN  'R' THEN 'Road'
				 WHEN  'S' THEN 'Other Sales'
				 WHEN  'T' THEN 'Touring'
				 ELSE 'n/a'
			END AS prd_line,
			CAST(prd_start_dt AS DATE) prd_start_dt, ---Convert date from Datetime to Date
			CAST(
				LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt)-1 
				AS DATE) prd_end_dt --- Calculate end date as one day before the next start date
		FROM bronze.crm_prd_info;
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '-----------------------'
/*
================================================================
DDL Script: Insert Values into silver.crm_sales_details
===============================================================
Note: This scripts after checking for correctness and quality
	  inserts data from the bronze.crm_sales_details table into
	  the silver.crm_sales_details. 
	  Due to adding additional columns to the table, the intial
	  table is dropped first and a new one is created to include
	  the new fields
===============================================================
*/
		SET @start_time = GETDATE()
		IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
		   DROP TABLE silver.crm_sales_details;

		CREATE TABLE silver.crm_sales_details(
		sls_ord_num NVARCHAR(50),
		sls_prd_key NVARCHAR(50),
		sls_cust_id INT,
		sls_order_dt DATE,
		sls_ship_dt DATE,
		sls_due_dt DATE,
		sls_sales INT,
		sls_quantity INT,
		sls_price INT,
		dh_create_date DATETIME2 DEFAULT GETDATE()
		);

		PRINT '>> Truncating Table: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting Data into silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details(
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price)


		SELECT  sls_ord_num
		,sls_prd_key
		,sls_cust_id
		,CASE 
			WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
		END AS sls_order_dt ----remove invalid dates or NULL and transforming the date from int to date
		,CASE 
			WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
		END AS sls_ship_dt ----remove invalid dates or NULL and transforming the date from int to date
		,CASE 
			WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
		END AS sls_due_dt ----remove invalid dates or NULL and transforming the date from int to date
		,CASE 
			WHEN sls_sales IS NULL OR sls_sales <0 OR sls_sales != sls_quantity*ABS(sls_price)
			THEN sls_quantity *ABS(sls_price)
			ELSE sls_sales
		END sls_sales -----Recalculate sales if original value is missing or incorrect
		,sls_quantity
		,CASE 
			WHEN sls_price IS NULL OR sls_price <0
			THEN sls_sales/NULLIF(sls_quantity,0)
			ELSE sls_price
		END sls_price  -----Recalculate price if original value is missing or incorrect
		FROM bronze.crm_sales_details
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '-----------------------'
/*
=============================================================
DDL Script: Insert Values into silver.erp_cust_az12
=============================================================
Note: This scripts after checking for correctness and quality
	  inserts data from the bronze.erp_cust_az12 table into
	  the silver.erp_cust_az12
=============================================================
*/
		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting Data into silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12(
			cid,
			bdate,
			gen)

		SELECT 
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))
			 ELSE cid
		END AS cid, ----Removed 'NAS' prefix if present
		CASE WHEN bdate > GETDATE() THEN NULL
			ELSE bdate
		END AS bdate, ---- Set future birthdates as NULL
		CASE WHEN UPPER(TRIM(gen)) IN ('F', 'Female') THEN 'Female'
			 WHEN UPPER(TRIM(gen)) IN ('M', 'Male') THEN 'Male'
			 ELSE 'n/a'
		END AS gen ---Normalize gender value and handles unknown cases
		FROM bronze.erp_cust_az12
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '-----------------------'
/*
=============================================================
DDL Script: Insert Values into silver.erp_loc_a101
=============================================================
Note: This scripts after checking for correctness and quality
	  inserts data from the bronze.erp_loc_a101 table into
	  the silver.erp_loc_a101
=============================================================
*/
		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting Data into silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101(
				cid,
				cntry)

		SELECT REPLACE(cid,'-','') cid --- Removed invalid characters
			  ,CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
					WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
					WHEN TRIM(cntry) IS NULL OR TRIM(cntry)= '' THEN 'n/a'
					ELSE TRIM(cntry)
				END AS cntry ---- Normalize and Handled missing or blank country codes
		FROM bronze.erp_loc_a101
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '-----------------------'

/*
=============================================================
DDL Script: Insert Values into silver.erp_px_cat_g1v2
=============================================================
Note: This scripts after checking for correctness and quality
	  inserts data from the bronze.erp_px_cat_g1v2 table into
	  the silver.erp_px_cat_g1v2
=============================================================
*/
		SET @start_time = GETDATE()
		PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting Data into silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2(
					id,
					cat,
					subcat,
					maintenance)
		SELECT id
			  ,cat
			  ,subcat
			  ,maintenance
		FROM bronze.erp_px_cat_g1v2
		SET @end_time = GETDATE()
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + 'seconds'
		PRINT '-----------------------'
		PRINT 'Loading Silver Layer is Completed';
		PRINT ' -Total Load Duration: '+ CAST(DATEDIFF(SECOND,@batch_start_time,@batch_end_time) AS NVARCHAR) + 'seconds'
		PRINT '============================'
	END TRY
	BEGIN CATCH
		PRINT '========================================================'
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '======================================================='
	END CATCH
END

