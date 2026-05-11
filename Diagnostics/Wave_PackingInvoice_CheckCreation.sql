USE [3PLWMS_DEVELOPERS]
GO

/****** Diagnostic Script: Check Packing Invoice Creation for a Wave ******/
-- Purpose: Verify if packing invoices were created for a given WaveID
-- Author: Analysis Agent
-- Date: 2026-05-07

SET NOCOUNT ON;

DECLARE @WaveID INT = 879;  -- <-- SET THIS TO YOUR WAVE ID

IF @WaveID IS NULL
BEGIN
    PRINT '[ERROR] @WaveID is NULL. Please set @WaveID before running this script.';
    RETURN;
END

PRINT '========================================== PACKING INVOICE CREATION CHECK ==========================================';
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
    PRINT '[FAIL] Wave not found for WaveID = ' + CAST(@WaveID AS VARCHAR(20));
    RETURN;
END
ELSE
BEGIN
    PRINT '[OK] Wave found:';
    PRINT '  - WaveNumber: ' + @WaveNumber;
    PRINT '  - Status: ' + ISNULL(@WaveStatus, 'NULL');
    PRINT '  - Deleted: ' + CAST(@WaveDeleted AS VARCHAR(1));
    PRINT '  - WarehouseCode: ' + ISNULL(@WaveWarehouseCode, 'NULL');
    PRINT '';
END

-- =====================================================================
-- STEP 2: List Packed Orders in Wave
-- =====================================================================

PRINT '--- STEP 2: Packed Orders in Wave ---';

DECLARE @PackedOrderCount INT;
DECLARE @PackingResultCount INT;
DECLARE @TotalBoxesUsed INT;

SELECT
    @PackedOrderCount = COUNT(DISTINCT pr.OrderNumber),
        @PackingResultCount = COUNT(*),
        @TotalBoxesUsed = SUM(COALESCE(pr.NumberOfBoxes, 0))
FROM dbo.PackingResult pr
WHERE pr.WaveID = @WaveID
  AND pr.Deleted = 0;

PRINT 'Total packed orders   : ' + CAST(ISNULL(@PackedOrderCount, 0) AS VARCHAR(10));
PRINT 'Total packing records : ' + CAST(ISNULL(@PackingResultCount, 0) AS VARCHAR(10));
PRINT 'Total boxes used      : ' + CAST(ISNULL(@TotalBoxesUsed, 0) AS VARCHAR(10));
PRINT '';

IF ISNULL(@PackedOrderCount, 0) = 0
BEGIN
    PRINT '[WARN] No active PackingResult rows found for this wave.';
    PRINT '';
END
ELSE
BEGIN
    ;WITH PsOrder AS
    (
        SELECT
            ps.WaveID,
            ps.OrderNumber,
            MIN(ps.TenantCode) AS TenantCode,
            MIN(ps.WarehouseCode) AS WarehouseCode
        FROM dbo.PickingSchedule ps
        WHERE ps.Deleted = 0
        GROUP BY ps.WaveID, ps.OrderNumber
    )
    SELECT
        po.TenantCode,
        po.WarehouseCode,
        pr.OrderNumber,
        pr.PackingType,
        COUNT(*) AS PackingRows,
        SUM(COALESCE(pr.NumberOfBoxes, 0)) AS TotalBoxes,
        MIN(pr.Status) AS [Status]
    FROM dbo.PackingResult pr
    LEFT JOIN PsOrder po
        ON po.WaveID = pr.WaveID
       AND po.OrderNumber = pr.OrderNumber
    WHERE pr.WaveID = @WaveID
      AND pr.Deleted = 0
    GROUP BY
        po.TenantCode,
        po.WarehouseCode,
        pr.OrderNumber,
        pr.PackingType
    ORDER BY
        po.TenantCode,
        po.WarehouseCode,
        pr.OrderNumber;

    PRINT '';
END

-- =====================================================================
-- STEP 3: List Packed Items of Each Order in Wave
-- =====================================================================

PRINT '--- STEP 3: Packed Items per Order in Wave ---';

DECLARE @PackedItemLineCount INT;

SELECT @PackedItemLineCount = COUNT(*)
FROM dbo.PackingResultLine prl
INNER JOIN dbo.PackingResult pr
    ON pr.PackingResultID = prl.PackingResultID
   AND pr.Deleted = 0
WHERE pr.WaveID = @WaveID
  AND prl.Deleted = 0;

PRINT 'Total packed item lines in wave: ' + CAST(ISNULL(@PackedItemLineCount, 0) AS VARCHAR(10));
PRINT '';

IF ISNULL(@PackedItemLineCount, 0) = 0
BEGIN
    PRINT '[WARN] No packed item lines found for this wave.';
    PRINT '';
END
ELSE
BEGIN
    ;WITH PsOrder AS
    (
        SELECT
            ps.WaveID,
            ps.OrderNumber,
            MIN(ps.TenantCode) AS TenantCode,
            MIN(ps.WarehouseCode) AS WarehouseCode
        FROM dbo.PickingSchedule ps
        WHERE ps.Deleted = 0
        GROUP BY ps.WaveID, ps.OrderNumber
    )
    SELECT
        po.TenantCode,
        po.WarehouseCode,
        pr.OrderNumber,
        pr.PackingType,
        prl.BoxNumber,
        prl.StandardBoxName,
        prl.ItemNumber,
        prl.ItemName,
        prl.Qty AS PackedQty,
        pr.Status AS PackingStatus,
        pr.CreatedDateTime
    FROM dbo.PackingResult pr
    INNER JOIN dbo.PackingResultLine prl
        ON prl.PackingResultID = pr.PackingResultID
       AND prl.Deleted = 0
    LEFT JOIN PsOrder po
        ON po.WaveID = pr.WaveID
       AND po.OrderNumber = pr.OrderNumber
    WHERE pr.WaveID = @WaveID
      AND pr.Deleted = 0
    ORDER BY
        po.TenantCode,
        po.WarehouseCode,
        pr.OrderNumber,
        prl.BoxNumber,
        prl.ItemNumber;

    PRINT '';
END

-- =====================================================================
-- STEP 4: Check ChargeGroup (Packing) Configuration for Packed Items
-- =====================================================================

PRINT '--- STEP 4: ChargeGroup (Packing) configuration per packed item ---';

DECLARE @PackedItemsWithChargeGroup INT;
DECLARE @PackedItemsWithoutChargeGroup INT;

;WITH PackedItems AS
(
    SELECT DISTINCT
        po.TenantCode,
        prl.ItemNumber,
        prl.ItemName
    FROM dbo.PackingResult pr
    INNER JOIN dbo.PackingResultLine prl
        ON prl.PackingResultID = pr.PackingResultID
       AND prl.Deleted = 0
    LEFT JOIN
    (
        SELECT
            ps.WaveID,
            ps.OrderNumber,
            MIN(ps.TenantCode) AS TenantCode
        FROM dbo.PickingSchedule ps
        WHERE ps.Deleted = 0
        GROUP BY ps.WaveID, ps.OrderNumber
    ) po
        ON po.WaveID = pr.WaveID
       AND po.OrderNumber = pr.OrderNumber
    WHERE pr.WaveID = @WaveID
      AND pr.Deleted = 0
)
SELECT
    @PackedItemsWithChargeGroup = COUNT(DISTINCT CASE WHEN cg.ChargeGroupID IS NOT NULL THEN pi.ItemNumber END),
    @PackedItemsWithoutChargeGroup = COUNT(DISTINCT CASE WHEN cg.ChargeGroupID IS NULL THEN pi.ItemNumber END)
FROM PackedItems pi
LEFT JOIN dbo.Items i
    ON i.ItemNumber = pi.ItemNumber
   AND i.TenantCode = pi.TenantCode
   AND i.Deleted = 0
LEFT JOIN dbo.ItemChargeGroup icg
    ON icg.ItemID = i.ItemID
   AND icg.Category = 'Packing'
   AND icg.Deleted = 0
LEFT JOIN dbo.ChargeGroup cg
    ON cg.ChargeGroupID = icg.ChargeGroupID
   AND cg.Deleted = 0;

PRINT 'Packed items with Packing ChargeGroup   : ' + CAST(ISNULL(@PackedItemsWithChargeGroup, 0) AS VARCHAR(10));
PRINT 'Packed items without Packing ChargeGroup: ' + CAST(ISNULL(@PackedItemsWithoutChargeGroup, 0) AS VARCHAR(10));
PRINT '';

;WITH PackedItems AS
(
    SELECT DISTINCT
        po.TenantCode,
        prl.ItemNumber,
        prl.ItemName
    FROM dbo.PackingResult pr
    INNER JOIN dbo.PackingResultLine prl
        ON prl.PackingResultID = pr.PackingResultID
       AND prl.Deleted = 0
    LEFT JOIN
    (
        SELECT
            ps.WaveID,
            ps.OrderNumber,
            MIN(ps.TenantCode) AS TenantCode
        FROM dbo.PickingSchedule ps
        WHERE ps.Deleted = 0
        GROUP BY ps.WaveID, ps.OrderNumber
    ) po
        ON po.WaveID = pr.WaveID
       AND po.OrderNumber = pr.OrderNumber
    WHERE pr.WaveID = @WaveID
      AND pr.Deleted = 0
)
SELECT
    pi.TenantCode,
    pi.ItemNumber,
    pi.ItemName AS [ItemName (PackingResultLine)],
    cg.ChargeGroupID,
    cg.ChargeGroupName,
    cg.ChargeGroupDescription
FROM PackedItems pi
INNER JOIN dbo.Items i
    ON i.ItemNumber = pi.ItemNumber
   AND i.TenantCode = pi.TenantCode
   AND i.Deleted = 0
INNER JOIN dbo.ItemChargeGroup icg
    ON icg.ItemID = i.ItemID
   AND icg.Category = 'Packing'
   AND icg.Deleted = 0
INNER JOIN dbo.ChargeGroup cg
    ON cg.ChargeGroupID = icg.ChargeGroupID
   AND cg.Deleted = 0
ORDER BY
    pi.TenantCode,
    pi.ItemNumber;

PRINT '';

-- =====================================================================
-- STEP 5: List Packing Charge Items Configured per Tenant per Order
-- =====================================================================

PRINT '--- STEP 5: Packing ChargeItem config per tenant/order ---';

DECLARE @Step5ConfiguredRows INT;

;WITH WaveOrders AS
(
    SELECT DISTINCT
        po.TenantCode,
        po.WarehouseCode,
        pr.OrderNumber
    FROM dbo.PackingResult pr
    LEFT JOIN
    (
        SELECT
            ps.WaveID,
            ps.OrderNumber,
            MIN(ps.TenantCode) AS TenantCode,
            MIN(ps.WarehouseCode) AS WarehouseCode
        FROM dbo.PickingSchedule ps
        WHERE ps.Deleted = 0
        GROUP BY ps.WaveID, ps.OrderNumber
    ) po
        ON po.WaveID = pr.WaveID
       AND po.OrderNumber = pr.OrderNumber
    WHERE pr.WaveID = @WaveID
      AND pr.Deleted = 0
)
SELECT
    @Step5ConfiguredRows = COUNT(*)
FROM WaveOrders wo
INNER JOIN dbo.TenantChargeItem tci
    ON tci.TenantCode = wo.TenantCode
   AND tci.Deleted = 0
   AND (tci.EffectiveDate IS NULL OR tci.EffectiveDate <= GETDATE())
   AND (tci.EndDate IS NULL OR tci.EndDate >= GETDATE())
INNER JOIN dbo.ChargeItem ci
    ON ci.ChargeItemID = tci.ChargeItemId
   AND ci.Deleted = 0
   AND ci.ChargeItemGroup = 'Packing';

PRINT 'Configured Packing ChargeItem rows (tenant/order): ' + CAST(ISNULL(@Step5ConfiguredRows, 0) AS VARCHAR(10));
PRINT '';

IF ISNULL(@Step5ConfiguredRows, 0) = 0
BEGIN
    PRINT '[WARN] No active TenantChargeItem config found for Packing charge items in this wave.';
    PRINT '';
END
ELSE
BEGIN
    ;WITH WaveOrders AS
    (
        SELECT DISTINCT
            po.TenantCode,
            po.WarehouseCode,
            pr.OrderNumber
        FROM dbo.PackingResult pr
        LEFT JOIN
        (
            SELECT
                ps.WaveID,
                ps.OrderNumber,
                MIN(ps.TenantCode) AS TenantCode,
                MIN(ps.WarehouseCode) AS WarehouseCode
            FROM dbo.PickingSchedule ps
            WHERE ps.Deleted = 0
            GROUP BY ps.WaveID, ps.OrderNumber
        ) po
            ON po.WaveID = pr.WaveID
           AND po.OrderNumber = pr.OrderNumber
        WHERE pr.WaveID = @WaveID
          AND pr.Deleted = 0
    )
    SELECT
        wo.TenantCode,
        wo.WarehouseCode,
        wo.OrderNumber,
        ci.ChargeItemID,
        ci.ChargeItemName,
        ci.ChargeItemUnit,
        ci.ChargeItemGroup,
        tci.TenantChargeItemID,
        tci.ChargeType,
        COALESCE(tcc.ChargeItemPrice, cic.ChargeItemPrice) AS ConfiguredCharge,
        COALESCE(tcc.ChargeItemCurrency, cic.ChargeItemCurrency) AS Currency,
        CASE
            WHEN tci.ChargeType = 'Standard' AND cic.ChargeItemCostID IS NULL THEN '[FAIL] Missing ChargeItemCost (warehouse)'
            WHEN tci.ChargeType = 'Custom' AND tcc.TenantCustomCostID IS NULL THEN '[FAIL] Missing TenantCustomCost (warehouse)'
            ELSE '[OK] Configured'
        END AS CostConfigStatus
    FROM WaveOrders wo
    INNER JOIN dbo.TenantChargeItem tci
        ON tci.TenantCode = wo.TenantCode
       AND tci.Deleted = 0
       AND (tci.EffectiveDate IS NULL OR tci.EffectiveDate <= GETDATE())
       AND (tci.EndDate IS NULL OR tci.EndDate >= GETDATE())
    INNER JOIN dbo.ChargeItem ci
        ON ci.ChargeItemID = tci.ChargeItemId
       AND ci.Deleted = 0
       AND ci.ChargeItemGroup = 'Packing'
    LEFT JOIN dbo.ChargeItemCost cic
        ON tci.ChargeType = 'Standard'
       AND cic.ChargeItemID = ci.ChargeItemID
       AND cic.WarehouseCode = wo.WarehouseCode
       AND cic.Deleted = 0
    LEFT JOIN dbo.TenantCustomCost tcc
        ON tci.ChargeType = 'Custom'
       AND tcc.TenantChargeItemID = tci.TenantChargeItemID
       AND tcc.WarehouseCode = wo.WarehouseCode
       AND tcc.Deleted = 0
    ORDER BY
        wo.TenantCode,
        wo.WarehouseCode,
        wo.OrderNumber,
        ci.ChargeItemName;

    PRINT '';
END

-- =====================================================================
-- STEP 6: Show Packing Invoices of This Wave in Invoice Table
-- =====================================================================

PRINT '--- STEP 6: Packing invoices for this wave (Invoice table) ---';

DECLARE @Step6PackingInvoiceCount INT;

SELECT
    @Step6PackingInvoiceCount = COUNT(*)
FROM dbo.Invoice inv
WHERE inv.Deleted = 0
  AND inv.ChargeCategory = 'Packing'
  AND (
        inv.WaveReferences = @WaveNumber
        OR inv.WaveReferences = CAST(@WaveID AS VARCHAR(20))
      );

PRINT 'Packing invoice rows found: ' + CAST(ISNULL(@Step6PackingInvoiceCount, 0) AS VARCHAR(10));
PRINT '';

IF ISNULL(@Step6PackingInvoiceCount, 0) = 0
BEGIN
    PRINT '[WARN] No Packing invoice row found in Invoice for this wave.';
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
      AND inv.ChargeCategory = 'Packing'
      AND (
            inv.WaveReferences = @WaveNumber
            OR inv.WaveReferences = CAST(@WaveID AS VARCHAR(20))
          )
    ORDER BY inv.CreatedDateTime, inv.InvoiceID;

    PRINT '';
END

PRINT '';
PRINT '========================================== END OF REPORT ==========================================';

SET NOCOUNT OFF;

GO
