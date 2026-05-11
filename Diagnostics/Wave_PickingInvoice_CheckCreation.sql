USE [3PLWMS_DEVELOPERS]
GO

/****** Diagnostic Script: Check Picking Invoice Creation for a Wave ******/
-- Purpose: Verify if picking invoices were created for a given WaveID
-- Author: Analysis Agent
-- Date: 2026-05-07
-- Usage: 
--   DECLARE @WaveID INT = 123;
--   EXEC sp_executesql N'[diagnostic script content]', N'@WaveID INT', @WaveID

-- =====================================================================
-- INPUT PARAMETER
-- =====================================================================

DECLARE @WaveID INT = 879;  -- <-- SET THIS TO YOUR WAVE ID

IF @WaveID IS NULL
BEGIN
    PRINT '❌ ERROR: @WaveID is NULL. Please set @WaveID before running this script.';
    RETURN;
END

PRINT '========================================== PICKING INVOICE CREATION CHECK ==========================================';
PRINT 'Wave ID: ' + CAST(@WaveID AS VARCHAR(20));
PRINT '';

-- =====================================================================
-- STEP 1: Verify Wave Exists
-- =====================================================================

PRINT '--- STEP 1: Check if Wave exists ---';

DECLARE @WaveNumber VARCHAR(11);
DECLARE @WaveStatus VARCHAR(50);
DECLARE @WaveDeleted BIT;
DECLARE @WaveWarehouseCode VARCHAR(20);

SELECT TOP 1
    @WaveNumber = WaveNumber,
    @WaveStatus = WaveStatus,
    @WaveDeleted = Deleted,    
    @WaveWarehouseCode = WarehouseCode
FROM dbo.Wave
WHERE WaveID = @WaveID;

IF @WaveNumber IS NULL
BEGIN
    PRINT '❌ Wave not found for WaveID = ' + CAST(@WaveID AS VARCHAR(20));
    RETURN;
END
ELSE
BEGIN
    PRINT '✓ Wave found:';
    PRINT '  - WaveNumber: ' + @WaveNumber;
    PRINT '  - Status: ' + ISNULL(@WaveStatus, 'NULL');
    PRINT '  - Deleted: ' + CAST(@WaveDeleted AS VARCHAR(1));   
    PRINT '  - WarehouseCode: ' + ISNULL(@WaveWarehouseCode, 'NULL');
    PRINT '';
END

-- =====================================================================
-- STEP 2: List Fulfilment Orders in Wave
-- =====================================================================

PRINT '--- STEP 2: Fulfilment Orders in Wave ---';

DECLARE @PickedOrderCount INT;
DECLARE @PickedTenantCount INT;

SELECT
    @PickedOrderCount  = COUNT(DISTINCT OrderNumber),
    @PickedTenantCount = COUNT(DISTINCT TenantCode)
FROM dbo.PickingSchedule
WHERE WaveID = @WaveID AND Deleted = 0;

PRINT 'Total fulfilment orders : ' + CAST(ISNULL(@PickedOrderCount,  0) AS VARCHAR(10));
PRINT 'Total tenants in wave   : ' + CAST(ISNULL(@PickedTenantCount, 0) AS VARCHAR(10));
PRINT '';

IF @PickedOrderCount = 0
BEGIN
    PRINT '⚠ No active PickingSchedule rows found for this wave (check Deleted flag).';
    PRINT '';
END
ELSE
BEGIN
    SELECT
        ps.TenantCode,
        ps.WarehouseCode,
        ps.OrderNumber,
        ps.FulfilmentOrder,
        ps.FulfilmentType,       
        COUNT(DISTINCT ps.ItemNumber) AS UniqueItems,
        COUNT(*)                      AS ItemLines,
        SUM(ps.Qty)                   AS TotalQty,
        SUM(ps.PickedQty)             AS TotalPickedQty,
        MIN(ps.Status)                AS [Status]
    FROM dbo.PickingSchedule ps
    WHERE ps.WaveID  = @WaveID
      AND ps.Deleted = 0
    GROUP BY
        ps.TenantCode,
        ps.WarehouseCode,
        ps.OrderNumber,
        ps.FulfilmentOrder,
        ps.FulfilmentType
    ORDER BY
        ps.TenantCode,
        ps.WarehouseCode,
        ps.OrderNumber;

    PRINT '';
END

-- =====================================================================
-- STEP 3: List All Items of Each Order in Wave
-- =====================================================================

PRINT '--- STEP 3: Items per Order in Wave ---';

DECLARE @PickedItemLineCount INT;

SELECT @PickedItemLineCount = COUNT(*)
FROM dbo.PickingSchedule
WHERE WaveID = @WaveID AND Deleted = 0;

PRINT 'Total item lines in wave: ' + CAST(ISNULL(@PickedItemLineCount, 0) AS VARCHAR(10));
PRINT '';

IF @PickedItemLineCount = 0
BEGIN
    PRINT '⚠ No item lines found for this wave.';
    PRINT '';
END
ELSE
BEGIN
    SELECT
        ps.TenantCode,
        ps.WarehouseCode,
        ps.OrderNumber,
        ps.FulfilmentOrder,
        ps.ItemNumber,
        ps.ItemName,
        ps.Qty                  AS PlannedQty,
        ps.PickedQty,
        pr.ScannedUnit       
    FROM dbo.PickingSchedule ps
    LEFT JOIN dbo.PickingResult pr
        ON  pr.PickingScheduleID = ps.PickingScheduleID
        AND pr.Deleted           = 0
    WHERE ps.WaveID  = @WaveID
      AND ps.Deleted = 0
    ORDER BY
        ps.TenantCode,
        ps.WarehouseCode,
        ps.OrderNumber,
        ps.FulfilmentOrder,
        ps.ItemNumber;

    PRINT '';
END

-- =====================================================================
-- STEP 4: Check ChargeGroup (Picking) Configuration for Items in Wave
-- =====================================================================

PRINT '--- STEP 4: ChargeGroup (Picking) configuration per item ---';

DECLARE @ItemsWithChargeGroup    INT;
DECLARE @ItemsWithoutChargeGroup INT;

SELECT
    @ItemsWithChargeGroup    = COUNT(DISTINCT CASE WHEN cg.ChargeGroupID IS NOT NULL THEN ps.ItemNumber END),
    @ItemsWithoutChargeGroup = COUNT(DISTINCT CASE WHEN cg.ChargeGroupID IS NULL     THEN ps.ItemNumber END)
FROM dbo.PickingSchedule ps
LEFT JOIN dbo.Items i
    ON  i.ItemNumber  = ps.ItemNumber
    AND i.TenantCode  = ps.TenantCode
    AND i.Deleted     = 0
LEFT JOIN dbo.ItemChargeGroup icg
    ON  icg.ItemId    = i.ItemID
    AND icg.Category  = 'Picking'
    AND icg.Deleted   = 0
LEFT JOIN dbo.ChargeGroup cg
    ON  cg.ChargeGroupID = icg.ChargeGroupID
    AND cg.Deleted       = 0
WHERE ps.WaveID  = @WaveID
  AND ps.Deleted = 0;

PRINT 'Items with Picking ChargeGroup   : ' + CAST(ISNULL(@ItemsWithChargeGroup,    0) AS VARCHAR(10));
PRINT '';

SELECT DISTINCT
    ps.TenantCode,
    ps.ItemNumber,
    ps.ItemName        AS [ItemName (PickingSchedule)],
    cg.ChargeGroupID,
    cg.ChargeGroupName,
    cg.ChargeGroupDescription
FROM dbo.PickingSchedule ps
INNER JOIN dbo.Items i
    ON  i.ItemNumber  = ps.ItemNumber
    AND i.TenantCode  = ps.TenantCode
    AND i.Deleted     = 0
INNER JOIN dbo.ItemChargeGroup icg
    ON  icg.ItemId    = i.ItemID
    AND icg.Category  = 'Picking'
    AND icg.Deleted   = 0
INNER JOIN dbo.ChargeGroup cg
    ON  cg.ChargeGroupID = icg.ChargeGroupID
    AND cg.Deleted       = 0
WHERE ps.WaveID  = @WaveID
  AND ps.Deleted = 0
ORDER BY
    ps.TenantCode,
    ps.ItemNumber;

PRINT '';

-- =====================================================================
-- STEP 5: List Picking Charge Items Configured per Tenant per Order
-- =====================================================================

PRINT '--- STEP 5: Picking ChargeItem config per tenant/order ---';

DECLARE @Step5ConfiguredRows INT;

;WITH WaveOrders AS
(
    SELECT DISTINCT
        ps.TenantCode,
        ps.WarehouseCode,
        ps.OrderNumber,
        ps.FulfilmentOrder
    FROM dbo.PickingSchedule ps
    WHERE ps.WaveID  = @WaveID
      AND ps.Deleted = 0
)
SELECT
    @Step5ConfiguredRows = COUNT(*)
FROM WaveOrders wo
INNER JOIN dbo.TenantChargeItem tci
    ON  tci.TenantCode = wo.TenantCode
    AND tci.Deleted    = 0
    AND (tci.EffectiveDate IS NULL OR tci.EffectiveDate <= GETDATE())
    AND (tci.EndDate IS NULL OR tci.EndDate >= GETDATE())
INNER JOIN dbo.ChargeItem ci
    ON  ci.ChargeItemID    = tci.ChargeItemId
    AND ci.Deleted         = 0
    AND ci.ChargeItemGroup = 'Picking';

PRINT 'Configured Picking ChargeItem rows (tenant/order): ' + CAST(ISNULL(@Step5ConfiguredRows, 0) AS VARCHAR(10));
PRINT '';

IF ISNULL(@Step5ConfiguredRows, 0) = 0
BEGIN
    PRINT '⚠ No active TenantChargeItem config found for Picking charge items in this wave.''s tenants/orders.';
    PRINT '';
END
ELSE
BEGIN
    ;WITH WaveOrders AS
    (
        SELECT DISTINCT
            ps.TenantCode,
            ps.WarehouseCode,
            ps.OrderNumber,
            ps.FulfilmentOrder
        FROM dbo.PickingSchedule ps
        WHERE ps.WaveID  = @WaveID
          AND ps.Deleted = 0
    )
    SELECT
        wo.TenantCode,
        wo.WarehouseCode,
        wo.OrderNumber,
        wo.FulfilmentOrder,
        ci.ChargeItemID,
        ci.ChargeItemName,
        ci.ChargeItemUnit,
        ci.ChargeItemGroup,
        tci.TenantChargeItemID,
        tci.ChargeType,
        COALESCE(tcc.ChargeItemPrice, cic.ChargeItemPrice)       AS ConfiguredCharge,
        COALESCE(tcc.ChargeItemCurrency, cic.ChargeItemCurrency) AS Currency,
        CASE
            WHEN tci.ChargeType = 'Standard' AND cic.ChargeItemCostID   IS NULL THEN '❌ Missing ChargeItemCost (warehouse)'
            WHEN tci.ChargeType = 'Custom'   AND tcc.TenantCustomCostID  IS NULL THEN '❌ Missing TenantCustomCost (warehouse)'
            ELSE '✓ Configured'
        END AS [CostConfigStatus]
    FROM WaveOrders wo
    INNER JOIN dbo.TenantChargeItem tci
        ON  tci.TenantCode = wo.TenantCode
        AND tci.Deleted    = 0
        AND (tci.EffectiveDate IS NULL OR tci.EffectiveDate <= GETDATE())
        AND (tci.EndDate IS NULL OR tci.EndDate >= GETDATE())
    INNER JOIN dbo.ChargeItem ci
        ON  ci.ChargeItemID    = tci.ChargeItemId
        AND ci.Deleted         = 0
        AND ci.ChargeItemGroup = 'Picking'
    LEFT JOIN dbo.ChargeItemCost cic
        ON  tci.ChargeType   = 'Standard'
        AND cic.ChargeItemID = ci.ChargeItemID
        AND cic.WarehouseCode = wo.WarehouseCode
        AND cic.Deleted      = 0
    LEFT JOIN dbo.TenantCustomCost tcc
        ON  tci.ChargeType        = 'Custom'
        AND tcc.TenantChargeItemID = tci.TenantChargeItemID
        AND tcc.WarehouseCode      = wo.WarehouseCode
        AND tcc.Deleted            = 0
    ORDER BY
        wo.TenantCode,
        wo.WarehouseCode,
        wo.OrderNumber,
        ci.ChargeItemName;

    PRINT '';
END

-- =====================================================================
-- STEP 6: Show Picking Invoices of This Wave in Invoice Table
-- =====================================================================

PRINT '--- STEP 6: Picking invoices for this wave (Invoice table) ---';

DECLARE @Step6PickingInvoiceCount INT;

SELECT
    @Step6PickingInvoiceCount = COUNT(*)
FROM dbo.Invoice inv
WHERE inv.Deleted = 0
  AND inv.ChargeCategory = 'Picking'
  AND (
        inv.WaveReferences = @WaveNumber
        OR inv.WaveReferences = CAST(@WaveID AS VARCHAR(20))
      );

PRINT 'Picking invoice rows found: ' + CAST(ISNULL(@Step6PickingInvoiceCount, 0) AS VARCHAR(10));
PRINT '';

IF ISNULL(@Step6PickingInvoiceCount, 0) = 0
BEGIN
    PRINT '⚠ No Picking invoice row found in Invoice for this wave.';
    PRINT '  Checked WaveReferences against WaveNumber and WaveID.';
    PRINT '';
END
ELSE
BEGIN
    SELECT
        inv.InvoiceID,
        inv.TenantCode,
        inv.WarehouseCode,
        inv.ChargeName,
        inv.ChargeType,
        inv.ChargeCategory,
        inv.InvoiceReferences,
        inv.WaveReferences,
        inv.ItemReferences,
        inv.Qty,
        inv.Cost,
        inv.Charge,
        inv.Currency,
        inv.Status,
        inv.CreatedDateTime,
        inv.CreatedBy
    FROM dbo.Invoice inv
    WHERE inv.Deleted = 0
      AND inv.ChargeCategory = 'Picking'
      AND (
            inv.WaveReferences = @WaveNumber
            OR inv.WaveReferences = CAST(@WaveID AS VARCHAR(20))
          )
    ORDER BY inv.CreatedDateTime, inv.InvoiceID;

    PRINT '';
END

PRINT '';
PRINT '========================================== END OF REPORT ==========================================';

-- Cleanup

GO
