-- =============================================
-- SQL DIAGNOSTIC SCRIPT
-- Purpose: Check why ULD lines were NOT allocated for an order
-- Input Parameter: @OrderNumber
-- Usage: DECLARE @OrderNumber VARCHAR(50) = 'YOUR-ORDER-NUM'; EXEC [script]
-- =============================================

USE [3PLWMS_Developers]
GO

CREATE PROCEDURE sp_CheckULDAllocationFailures
	@OrderNumber VARCHAR(50)
AS
BEGIN
	SET NOCOUNT ON;

	PRINT '============================================';
	PRINT 'ULD ALLOCATION FAILURE DIAGNOSTIC';
	PRINT 'Order: ' + COALESCE(@OrderNumber, '[NULL]');
	PRINT '============================================';
	PRINT '';

	-- ===== CASE 1: ORDER DOESN'T EXIST =====
	PRINT '>>> CASE 1: Order Exists Check';
	IF NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE order_number = @OrderNumber AND DELETED = 0)
	BEGIN
		PRINT 'FAILED: Order does not exist';
		RETURN;
	END
	PRINT 'PASSED: Order exists';
	PRINT '';

	-- ===== CASE 2: ORDER IS ON HOLD =====
	PRINT '>>> CASE 2: Order On Hold Check';
	IF EXISTS (SELECT 1 FROM dbo.Orders WHERE order_number = @OrderNumber AND DELETED = 0 AND OnHold = 1)
	BEGIN
		PRINT 'FAILED: Order is On Hold';
		SELECT 'Order On Hold' AS [Issue], OnHold, CreatedDateTime, CreatedBy FROM dbo.Orders WHERE order_number = @OrderNumber;
		RETURN;
	END
	PRINT 'PASSED: Order is not on hold';
	PRINT '';

	-- ===== CASE 3: GET ORDER DETAILS =====
	DECLARE @TenantCode VARCHAR(10);
	DECLARE @WarehouseCode VARCHAR(20);
	DECLARE @CarrierID INT;
	
	SELECT 
		@TenantCode = TenantCode,
		@WarehouseCode = WarehouseCode,
		@CarrierID = CarrierID
	FROM dbo.Orders 
	WHERE order_number = @OrderNumber AND DELETED = 0;

	PRINT '>>> CASE 3: Order Items Existence Check';
	PRINT 'Order Details: Tenant=' + COALESCE(@TenantCode, 'NULL') + ' | Warehouse=' + COALESCE(@WarehouseCode, 'NULL') + ' | Carrier=' + CAST(COALESCE(@CarrierID, 0) AS VARCHAR(5));
	
	IF NOT EXISTS (SELECT 1 FROM dbo.OrdersLine WHERE OrderNumber = @OrderNumber AND DELETED = 0)
	BEGIN
		PRINT 'FAILED: Order has no line items';
		RETURN;
	END
	PRINT 'PASSED: Order has line items';
	
	SELECT 
		COUNT(*) AS [Total Items],
		SUM(Quantity) AS [Total Quantity]
	FROM dbo.OrdersLine 
	WHERE OrderNumber = @OrderNumber AND DELETED = 0;
	PRINT '';

	-- ===== CASE 4: NON-EXISTENT ITEMS =====
	PRINT '>>> CASE 4: Non-Existent Items Check';
	IF EXISTS (
		SELECT 1 FROM dbo.OrdersLine ol
		WHERE ol.OrderNumber = @OrderNumber 
		  AND ol.DELETED = 0
		  AND NOT EXISTS (
			SELECT 1 FROM dbo.Items i 
			WHERE i.ItemNumber = ol.ItemNumber 
			  AND i.DELETED = 0 
			  AND i.TenantCode = ol.TenantCode
		  )
	)
	BEGIN
		PRINT 'FAILED: Found items that do not exist in master data';
		SELECT 
			ol.ItemNumber,
			ol.Quantity,
			'NotExist' AS [Reason]
		FROM dbo.OrdersLine ol
		WHERE ol.OrderNumber = @OrderNumber 
		  AND ol.DELETED = 0
		  AND NOT EXISTS (
			SELECT 1 FROM dbo.Items i 
			WHERE i.ItemNumber = ol.ItemNumber 
			  AND i.DELETED = 0 
			  AND i.TenantCode = ol.TenantCode
		  );
		RETURN;
	END
	PRINT 'PASSED: All items exist in master data';
	PRINT '';

	-- ===== CASE 5: DHL HSTARIFF CODE =====
	PRINT '>>> CASE 5: DHL HsTariffCode Check (if DHL carrier)';
	IF @CarrierID = 3
	BEGIN
		IF EXISTS (
			SELECT 1 FROM dbo.OrdersLine ol
			INNER JOIN dbo.Items i ON i.ItemNumber = ol.ItemNumber AND i.TenantCode = ol.TenantCode AND i.DELETED = 0
			WHERE ol.OrderNumber = @OrderNumber
			  AND ol.DELETED = 0
			  AND (i.HsTariffCode IS NULL OR LTRIM(RTRIM(i.HsTariffCode)) = '')
		)
		BEGIN
			PRINT 'FAILED: DHL shipment items missing HsTariffCode';
			SELECT 
				ol.ItemNumber,
				i.ItemName,
				'NoHsTariffCode' AS [Reason]
			FROM dbo.OrdersLine ol
			INNER JOIN dbo.Items i ON i.ItemNumber = ol.ItemNumber AND i.TenantCode = ol.TenantCode AND i.DELETED = 0
			WHERE ol.OrderNumber = @OrderNumber
			  AND ol.DELETED = 0
			  AND (i.HsTariffCode IS NULL OR LTRIM(RTRIM(i.HsTariffCode)) = '');
			RETURN;
		END
		PRINT 'PASSED: All items have HsTariffCode for DHL';
	END
	ELSE
	BEGIN
		PRINT 'SKIPPED: Not a DHL order (CarrierID=' + CAST(@CarrierID AS VARCHAR(5)) + ')';
	END
	PRINT '';

	-- ===== CASE 6: STOCK AVAILABILITY =====
	PRINT '>>> CASE 6: Stock Availability Check';
	
	CREATE TABLE #RequiredStock (
		ItemNumber VARCHAR(30),
		RequiredQty INT,
		AvailableQty INT,
		ShortfallQty INT
	);

	INSERT INTO #RequiredStock
	SELECT 
		ol.ItemNumber,
		ol.Quantity,
		(
			SELECT ISNULL(SUM(u.Qty), 0)
			FROM dbo.ULD u
			WHERE u.TenantCode = ol.TenantCode
			  AND u.WarehouseCode = @WarehouseCode
			  AND u.ItemNumber = ol.ItemNumber
			  AND u.DELETED = 0
		) AS AvailableQty,
		ol.Quantity - ISNULL(
			(SELECT SUM(u.Qty) FROM dbo.ULD u
			 WHERE u.TenantCode = ol.TenantCode
			   AND u.WarehouseCode = @WarehouseCode
			   AND u.ItemNumber = ol.ItemNumber
			   AND u.DELETED = 0), 0
		) AS ShortfallQty
	FROM dbo.OrdersLine ol
	WHERE ol.OrderNumber = @OrderNumber
	  AND ol.DELETED = 0;

	IF EXISTS (SELECT 1 FROM #RequiredStock WHERE ShortfallQty > 0)
	BEGIN
		PRINT 'FAILED: Insufficient stock for some items';
		SELECT 
			ItemNumber,
			RequiredQty,
			AvailableQty,
			ShortfallQty
		FROM #RequiredStock 
		WHERE ShortfallQty > 0
		ORDER BY ShortfallQty DESC;
		RETURN;
	END
	PRINT 'PASSED: Sufficient stock available for all items';
	PRINT '';

	-- ===== CASE 7: ULD LINE ALLOCATION STATUS =====
	PRINT '>>> CASE 7: ULD Line Allocation Status';
	
	DECLARE @AllocatedCount INT = (
		SELECT COUNT(*) FROM dbo.ULDLine 
		WHERE TransactionReference = @OrderNumber 
		  AND TransactionType = 'Allocated' 
		  AND DELETED = 0
	);

	IF @AllocatedCount > 0
	BEGIN
		PRINT 'SUCCESS: ULD lines are allocated';
		SELECT 
			ul.ULDID,
			ul.ItemNumber,
			ul.ItemName,
			ABS(ul.TransactionQty) AS AllocatedQty,
			ul.CreatedDateTime,
			ul.CreatedBy
		FROM dbo.ULDLine ul
		WHERE ul.TransactionReference = @OrderNumber 
		  AND ul.TransactionType = 'Allocated' 
		  AND ul.DELETED = 0
		ORDER BY ul.CreatedDateTime DESC;
	END
	ELSE
	BEGIN
		PRINT 'NO ALLOCATION FOUND: Check for deleted allocations or allocation process failure';
		
		-- Check for deleted allocations
		IF EXISTS (
			SELECT 1 FROM dbo.ULDLine 
			WHERE TransactionReference = @OrderNumber 
			  AND TransactionType = 'Allocated' 
			  AND DELETED = 1
		)
		BEGIN
			PRINT '  >> Found DELETED allocations - may indicate rollback';
			SELECT 
				ul.ULDID,
				ul.ItemNumber,
				ABS(ul.TransactionQty) AS Qty,
				ul.LastEditedDateTime AS DeletedTime,
				ul.LastEditedBy AS DeletedBy
			FROM dbo.ULDLine ul
			WHERE ul.TransactionReference = @OrderNumber 
			  AND ul.TransactionType = 'Allocated' 
			  AND ul.DELETED = 1
			ORDER BY ul.LastEditedDateTime DESC;
		END
	END
	PRINT '';

	-- ===== FINAL SUMMARY =====
	PRINT '>>> FINAL SUMMARY';
	SELECT 
		CASE 
			WHEN @AllocatedCount > 0 THEN 'SUCCESS: Allocation Completed'
			ELSE 'FAILURE: Allocation Not Completed'
		END AS [Status],
		GETDATE() AS [CheckTime],
		@OrderNumber AS [Order];

	DROP TABLE #RequiredStock;
END
GO

-- =====================================================
-- EXECUTE THE DIAGNOSTIC PROCEDURE
-- =====================================================
-- Uncomment and change the order number to test:
-- EXEC sp_CheckULDAllocationFailures @OrderNumber = 'ORD-20260519-001';

-- To see all available procedures, run:
-- SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'sp_CheckULDAllocationFailures';
