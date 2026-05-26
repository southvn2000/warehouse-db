-- =============================================
-- Diagnostic Script: ULD Line Allocation Not Created Cases
-- Purpose: Check all scenarios where ULD lines were NOT allocated for a given order
-- Input: @OrderNumber (VARCHAR(50))
-- Author: Analysis Tool
-- Date: 2026-05-19
-- =============================================

USE [3PLWMS_QA]
GO

DECLARE @OrderNumber VARCHAR(50) = '1287'; -- just for Manual Orders
-- ===========================================================
-- RESULT SUMMARY TABLE
-- ===========================================================
CREATE TABLE #AllocationIssues (
	IssueRank INT,
	CaseName VARCHAR(100),
	Condition VARCHAR(MAX),
	Status VARCHAR(20),
	AffectedCount INT,
	Details NVARCHAR(MAX),
	RecommendedAction VARCHAR(200)
);

-- ===========================================================
-- CASE 1: ORDER NUMBER IS NULL OR EMPTY
-- ===========================================================
INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	1,
	'OrderNumber is NULL',
	'@OrderNumber IS NULL',
	CASE WHEN @OrderNumber IS NULL OR LTRIM(RTRIM(@OrderNumber)) = '' THEN 'FAILED' ELSE 'PASSED' END,
	CASE WHEN @OrderNumber IS NULL OR LTRIM(RTRIM(@OrderNumber)) = '' THEN 1 ELSE 0 END,
	'No order number provided to procedure - allocation cannot occur without order context',
	'Provide valid OrderNumber parameter'
WHERE (@OrderNumber IS NULL OR LTRIM(RTRIM(@OrderNumber)) = '');

-- ===========================================================
-- CASE 2: ORDER IS ON HOLD
-- ===========================================================
INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	2,
	'Order On Hold',
	'Orders.OnHold = 1',
	CASE 
		WHEN EXISTS (
			SELECT 1
			FROM dbo.Orders o
			WHERE o.order_number = @OrderNumber
			  AND o.DELETED = 0
			  AND o.OnHold = 1
		) THEN 'FAILED'
		ELSE 'PASSED'
	END,
	CASE 
		WHEN EXISTS (
			SELECT 1
			FROM dbo.Orders o
			WHERE o.order_number = @OrderNumber
			  AND o.DELETED = 0
			  AND o.OnHold = 1
		) THEN 1
		ELSE 0
	END,
	CASE 
		WHEN EXISTS (
			SELECT 1
			FROM dbo.Orders o
			WHERE o.order_number = @OrderNumber
			  AND o.DELETED = 0
			  AND o.OnHold = 1
		) THEN 'Order ' + @OrderNumber + ' is marked as OnHold. No stock allocation occurs for held orders.'
		ELSE 'Order ' + @OrderNumber + ' is not on hold.'
	END,
	CASE 
		WHEN EXISTS (
			SELECT 1
			FROM dbo.Orders o
			WHERE o.order_number = @OrderNumber
			  AND o.DELETED = 0
			  AND o.OnHold = 1
		) THEN 'Remove hold status from order before allocation'
		ELSE 'No action required'
	END;

-- ===========================================================
-- CASE 3: ORDER ITEM NOT EXIST IN ITEMS TABLE
-- ===========================================================
INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	3,
	'Item Not Exist',
	'Items.ItemId IS NULL',
	'FAILED',
	COUNT(*),
	'Found ' + CAST(COUNT(*) AS VARCHAR(10)) + ' order line items that do not exist in Items table',
	'Verify item numbers exist in Items master data for tenant'
FROM dbo.OrdersLine ol
INNER JOIN dbo.Orders o ON o.OrderID = ol.OrderID AND o.DELETED = 0
WHERE o.order_number = @OrderNumber
  AND ol.DELETED = 0
  AND NOT EXISTS (
		SELECT 1 FROM dbo.Items i 
		WHERE i.ItemID = ol.ItemID 
		  AND i.DELETED = 0 
		  AND i.TenantCode = ol.TenantCode
	);

-- ===========================================================
-- CASE 4: DHL ORDER MISSING HSTARIFF CODE
-- ===========================================================
INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	4,
	'DHL Missing HsTariffCode',
	'CarrierID = 3 AND Items.HsTariffCode IS NULL',
	'FAILED',
	COUNT(*),
	'Found ' + CAST(COUNT(*) AS VARCHAR(10)) + ' items without HsTariffCode for DHL shipments',
	'Add HsTariffCode to Items master for DHL compliance'
FROM dbo.OrdersLine ol
INNER JOIN dbo.Items i ON i.ItemID = ol.ItemID AND i.TenantCode = ol.TenantCode AND i.DELETED = 0
INNER JOIN dbo.Orders o ON o.OrderID = ol.OrderID AND o.DELETED = 0
WHERE o.order_number = @OrderNumber
  AND ol.DELETED = 0
  AND o.CarrierID = 3
  AND (i.HsTariffCode IS NULL OR LTRIM(RTRIM(i.HsTariffCode)) = '');

-- ===========================================================
-- CASE 5: COMPOSITE ITEM WITH SINGLE PICKING TYPE
-- ===========================================================
INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	5,
	'Composite + Single Pick Incompatibility',
	'ItemIsComposite = 1 AND CompositeType = ''Order'' AND PickingType = ''Single''',
	'FAILED',
	COUNT(*),
	'Found ' + CAST(COUNT(*) AS VARCHAR(10)) + ' composite items with single-pick picking type',
	'Change picking type to Bulk or change composite handling mode'
FROM dbo.OrdersLine ol
INNER JOIN dbo.Items i ON i.ItemID = ol.ItemID AND i.TenantCode = ol.TenantCode AND i.DELETED = 0
INNER JOIN dbo.Orders o ON o.OrderID = ol.OrderID AND o.DELETED = 0
WHERE o.order_number = @OrderNumber
  AND ol.DELETED = 0
  AND i.ItemIsComposite = 1
  AND i.CompositeType = 'Order'
  AND i.PickingCondition = 'Single';

-- ===========================================================
-- CASE 6: INSUFFICIENT STOCK - NO AVAILABLE ULDS
-- ===========================================================
INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	6,
	'No Available ULDs for Item',
	'fn_GetULDsHavingStockOfTenantAtWarehouse() returns 0 rows',
	'FAILED',
	COUNT(*),
	'Found ' + CAST(COUNT(*) AS VARCHAR(10)) + ' items with no physical ULDs in warehouse',
	'Check warehouse stock levels and receive missing inventory'
FROM dbo.OrdersLine ol
INNER JOIN dbo.Items i ON i.ItemID = ol.ItemID AND i.TenantCode = ol.TenantCode AND i.DELETED = 0
INNER JOIN dbo.Orders o ON o.OrderID = ol.OrderID AND o.DELETED = 0
WHERE o.order_number = @OrderNumber
  AND ol.DELETED = 0
  AND NOT EXISTS (
		SELECT 1 FROM dbo.fn_GetULDsHavingStockOfTenantAtWarehouse(
			ol.TenantCode, 
			o.WarehouseCode, 
			ol.line_items_sku, 
			i.PickingCondition, 
			0
		)
	);

-- ===========================================================
-- CASE 7: INSUFFICIENT STOCK QUANTITY
-- ===========================================================
CREATE TABLE #StockComparison (
	ItemNumber VARCHAR(30),
	RequiredQty INT,
	AvailableQty INT,
	ShortfallQty INT
);

INSERT INTO #StockComparison
SELECT 
	ol.line_items_sku AS ItemNumber,
	ol.line_items_current_quantity AS RequiredQty,
	stock.AvailableQty,
	ol.line_items_current_quantity - stock.AvailableQty AS ShortfallQty
FROM dbo.OrdersLine ol
INNER JOIN dbo.Items i ON i.ItemID = ol.ItemID AND i.DELETED = 0
INNER JOIN dbo.Orders o ON o.OrderID = ol.OrderID AND o.DELETED = 0
OUTER APPLY (
	SELECT ISNULL(SUM(s.TotalQty), 0) AS AvailableQty
	FROM dbo.fn_GetULDsHavingStockOfTenantAtWarehouse(
		ol.TenantCode,
		o.WarehouseCode,
		ol.line_items_sku,
		i.PickingCondition,
		0
	) s
) stock
WHERE o.order_number = @OrderNumber
  AND ol.DELETED = 0
  AND ol.line_items_current_quantity > stock.AvailableQty;

INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	7,
	'Insufficient Stock Quantity',
	'AvailableQty < OrdersLine.line_items_current_quantity',
	'FAILED',
	COUNT(*),
	CAST(COUNT(*) AS VARCHAR(10)) + ' items have insufficient quantity. Total shortfall: ' + CAST(SUM(ShortfallQty) AS VARCHAR(10)) + ' units',
	'Receive additional stock or reduce order quantity'
FROM #StockComparison;

-- ===========================================================
-- CASE 8: ULD LINES ALREADY ALLOCATED (for comparison)
-- ===========================================================
INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	8,
	'ULD Lines Already Allocated',
	'ULDLine.TransactionType = ''Allocated'' AND TransactionReference = @OrderNumber',
	'SUCCESS',
	COUNT(*),
	'Found ' + CAST(COUNT(*) AS VARCHAR(10)) + ' ULD lines already allocated for this order',
	'Allocation completed successfully'
FROM dbo.ULDLine ul
WHERE ul.TransactionReference = @OrderNumber
  AND ul.TransactionType = 'Allocated'
  AND ul.DELETED = 0;

-- ===========================================================
-- CASE 9: DELETED ULD LINES (allocation was made then removed)
-- ===========================================================
INSERT INTO #AllocationIssues (IssueRank, CaseName, Condition, Status, AffectedCount, Details, RecommendedAction)
SELECT 
	9,
	'ULD Lines Deleted (Previous Allocation)',
	'ULDLine.TransactionType = ''Allocated'' AND TransactionReference = @OrderNumber AND DELETED = 1',
	'FAILED (Rollback)',
	COUNT(*),
	'Found ' + CAST(COUNT(*) AS VARCHAR(10)) + ' previously allocated ULD lines that were deleted',
	'Investigate reason for deletion and retry allocation'
FROM dbo.ULDLine ul
WHERE ul.TransactionReference = @OrderNumber
  AND ul.TransactionType = 'Allocated'
  AND ul.DELETED = 1;

-- ===========================================================
-- SUMMARY REPORT
-- ===========================================================
SELECT 
	'=== ULD LINE ALLOCATION DIAGNOSTIC REPORT ===' AS [REPORT],
	GETDATE() AS ReportTime,
	@OrderNumber AS OrderNumber;

SELECT 
	'DETAILED FINDINGS' AS [SECTION];

SELECT 
	IssueRank AS [#],
	CaseName AS [Issue Type],
	Status AS [Status],
	AffectedCount AS [Count],
	Details AS [Details],
	RecommendedAction AS [Action Required]
FROM #AllocationIssues
ORDER BY IssueRank;

-- ===========================================================
-- OVERALL VERDICT
-- ===========================================================
SELECT 
	CASE 
		WHEN EXISTS (SELECT 1 FROM #AllocationIssues WHERE Status = 'FAILED') THEN 'FAILED: ULD lines NOT allocated'
		WHEN EXISTS (SELECT 1 FROM #AllocationIssues WHERE IssueRank = 8 AND AffectedCount > 0) THEN 'SUCCESS: ULD lines allocated'
		ELSE 'UNKNOWN: Unable to determine allocation status'
	END AS [ALLOCATION_STATUS],
	CASE 
		WHEN @OrderNumber IS NULL OR LTRIM(RTRIM(@OrderNumber)) = '' THEN 0
		ELSE (SELECT COUNT(*) FROM dbo.Orders WHERE order_number = @OrderNumber AND DELETED = 0)
	END AS [ORDER_EXISTS],
	CASE 
		WHEN @OrderNumber IS NULL OR LTRIM(RTRIM(@OrderNumber)) = '' THEN 0
		ELSE (SELECT COUNT(*) FROM dbo.ULDLine WHERE TransactionReference = @OrderNumber AND TransactionType = 'Allocated' AND DELETED = 0)
	END AS [ULD_LINES_ALLOCATED],
	CASE 
		WHEN @OrderNumber IS NULL OR LTRIM(RTRIM(@OrderNumber)) = '' THEN 0
		ELSE (
			SELECT COUNT(*)
			FROM dbo.OrdersLine ol
			INNER JOIN dbo.Orders o ON o.OrderID = ol.OrderID AND o.DELETED = 0
			WHERE o.order_number = @OrderNumber
			  AND ol.DELETED = 0
		)
	END AS [ORDER_LINE_ITEMS];

-- ===========================================================
-- CLEANUP
-- ===========================================================
DROP TABLE #AllocationIssues;
DROP TABLE #StockComparison;

GO
