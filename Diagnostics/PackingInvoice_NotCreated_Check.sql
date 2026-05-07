USE [3PLWMS_QA]
GO

/*
Purpose:
- Diagnose why packing invoice rows were not created for a specific Wave + Order.
- Mirrors current logic from:
  - SP_VI_TBL_Invoice_InsertPackingInvoice
  - SP_VI_TBL_Invoice_InsertChargeGroupInvoice
  - SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode

Important note:
- In current code, both SP_VI_TBL_Wave_CompletePackingTask and
  SP_VI_TBL_Wave_AutoCompletePackingTask call SP_VI_TBL_Invoice_InsertPackingInvoice
  unconditionally (legacy @IsCharge gate block is commented out).
- So IsWarehouseAccount is shown for reference only, not as an active blocker.

How to use:
1) Set @WaveID and @OrderNumber.
2) Run whole script.
3) Review each result set and the final summary row.
*/

DECLARE @WaveID INT = 404;
DECLARE @OrderNumber VARCHAR(50) = '1283';

DECLARE @TenantCode VARCHAR(10) = NULL;
DECLARE @WarehouseCode VARCHAR(20) = NULL;
DECLARE @WaveNumber VARCHAR(11) = NULL;
DECLARE @PackingResultID INT = NULL;
DECLARE @CarrierID INT = NULL;
DECLARE @CarrierName VARCHAR(30) = 'Unknown';
DECLARE @BoxQty INT = 0;
DECLARE @PackingResultStatus VARCHAR(50) = NULL;
DECLARE @PackingLineCount INT = 0;

SELECT TOP 1
       @TenantCode = f.TenantCode,
       @WarehouseCode = f.WarehouseCode
FROM dbo.Fulfilment f
WHERE f.OrderNumber = @OrderNumber
  AND f.Deleted = 0
ORDER BY f.FulfilmentID DESC;

Print 'Tenant and warehouse context for order:' + @TenantCode + ' / ' + @WarehouseCode;

SELECT @WaveNumber = w.WaveNumber
FROM dbo.Wave w
WHERE w.WaveID = @WaveID
  AND w.Deleted = 0;

SELECT TOP 1
       @PackingResultID = pr.PackingResultID,
       @CarrierID = pr.CarrierID,
       @BoxQty = COALESCE(pr.NumberOfBoxes, 0),
       @PackingResultStatus = pr.Status
FROM dbo.PackingResult pr
WHERE pr.WaveID = @WaveID
  AND pr.OrderNumber = @OrderNumber
  AND pr.Deleted = 0
ORDER BY pr.PackingResultID DESC;

SELECT @PackingLineCount = COUNT(1)
FROM dbo.PackingResultLine prl
WHERE prl.PackingResultID = @PackingResultID
  AND prl.Deleted = 0;

DECLARE @IsWarehouseAccount BIT = NULL;
IF @CarrierID = 1
BEGIN
    SELECT @IsWarehouseAccount = ISNULL(api.IsWarehouseAccount, 1)
    FROM dbo.APIntegration api
    WHERE api.TenantCode = @TenantCode
      AND api.Deleted = 0;
    SET @CarrierName = 'AP';
END
ELSE IF @CarrierID = 3
BEGIN
    SELECT @IsWarehouseAccount = ISNULL(dhl.IsWarehouseAccount, 1)
    FROM dbo.DHLIntegration dhl
    WHERE dhl.TenantCode = @TenantCode
      AND dhl.Deleted = 0;
    SET @CarrierName = 'DHL';
END
ELSE IF @CarrierID = 2
BEGIN
    SET @CarrierName = 'Manual';
END
ELSE IF @CarrierID = 4
BEGIN
    SET @CarrierName = 'CP';
END

PRINT '==== PARAMS / CONTEXT ====';
SELECT
    @WaveID AS WaveID,
    @WaveNumber AS WaveNumber,
    @OrderNumber AS OrderNumber,
    @TenantCode AS TenantCode,
    @WarehouseCode AS WarehouseCode,
    @CarrierName AS CarrierName,
    @PackingResultID AS PackingResultID,
    @PackingResultStatus AS PackingResultStatus,
    @CarrierID AS CarrierID,
    @IsWarehouseAccount AS IsWarehouseAccount,
    @BoxQty AS NumberOfBoxes;

PRINT '==== 1) EXISTING PACKING INVOICES (for this wave/order) ====';
SELECT
    i.InvoiceID,
    i.TenantCode,
    i.WarehouseCode,
    i.ChargeName,
    i.ChargeType,
    i.ChargeCategory,
    i.InvoiceReferences,
    i.WaveReferences,
    i.ItemReferences,
    i.Qty,
    i.Cost,
    i.Charge,
    i.Currency,
    i.Status,
    i.CreatedDateTime
FROM dbo.Invoice i
WHERE i.Deleted = 0
  AND i.ChargeCategory = 'Packing'
  AND i.InvoiceReferences = @OrderNumber
  AND (@TenantCode IS NULL OR i.TenantCode = @TenantCode)
  AND (@WarehouseCode IS NULL OR i.WarehouseCode = @WarehouseCode)
  AND (@WaveNumber IS NULL OR i.WaveReferences = @WaveNumber)
ORDER BY i.InvoiceID DESC;

  PRINT '==== 2) INVOCATION CHECK (current vs legacy) ====';
SELECT
    'INFO' AS InvocationStatus,
    'Current code path calls SP_VI_TBL_Invoice_InsertPackingInvoice unconditionally in both manual and auto complete packing SPs.' AS InvocationReason,
    @CarrierID AS CarrierID,
    @CarrierName AS CarrierName,
    @IsWarehouseAccount AS IsWarehouseAccount,
    CASE
      WHEN @CarrierID IN (1, 3) AND @IsWarehouseAccount = 0 THEN 'LEGACY_ONLY_NOTE: this would block invoice only if old @IsCharge block is re-enabled'
      WHEN @CarrierID IN (1, 3) AND @IsWarehouseAccount = 1 THEN 'LEGACY_ONLY_NOTE: integration allows charging'
      ELSE 'N/A'
    END AS LegacyGateNote;

PRINT '==== 3) BOX-LEVEL CHECK (ChargeItem Group=Packing, Unit=Box, Tenant subscription, warehouse cost) ====';
;WITH BoxChargeItems AS
(
    SELECT ci.ChargeItemID, ci.ChargeItemName
    FROM dbo.ChargeItem ci
    WHERE ci.Deleted = 0
      AND ci.ChargeItemGroup = 'Packing'
      AND ci.ChargeItemUnit = 'Box'
),
BoxResolution AS
(
    SELECT
        bci.ChargeItemID,
        bci.ChargeItemName,
        tci.TenantChargeItemID,
        tci.ChargeType,
        cic.ChargeItemPrice AS StandardPrice,
        cic.ChargeItemCurrency AS StandardCurrency,
        tcc.ChargeItemPrice AS CustomPrice,
        tcc.ChargeItemCurrency AS CustomCurrency
    FROM BoxChargeItems bci
    LEFT JOIN dbo.TenantChargeItem tci
           ON tci.ChargeItemId = bci.ChargeItemID
          AND tci.TenantCode = @TenantCode
          AND tci.Deleted = 0
    LEFT JOIN dbo.ChargeItemCost cic
           ON cic.ChargeItemID = bci.ChargeItemID
          AND cic.WarehouseCode = @WarehouseCode
          AND cic.Deleted = 0
          AND tci.ChargeType = 'Standard'
    LEFT JOIN dbo.TenantCustomCost tcc
           ON tcc.TenantChargeItemID = tci.TenantChargeItemID
          AND tcc.WarehouseCode = @WarehouseCode
          AND tcc.Deleted = 0
        AND tci.ChargeType <> 'Standard'
)
SELECT
    br.ChargeItemID,
    br.ChargeItemName,
    br.TenantChargeItemID,
    br.ChargeType,
    br.StandardPrice,
    br.StandardCurrency,
    br.CustomPrice,
    br.CustomCurrency,
    CASE
        WHEN br.TenantChargeItemID IS NULL THEN 'FAIL_NO_TENANT_SUBSCRIPTION'
        WHEN br.ChargeType = 'Standard' AND br.StandardPrice IS NULL THEN 'FAIL_NO_STANDARD_PRICE_FOR_WAREHOUSE'
        WHEN br.ChargeType <> 'Standard' AND br.CustomPrice IS NULL THEN 'FAIL_NO_CUSTOM_PRICE_FOR_WAREHOUSE'
      WHEN @BoxQty <= 0 THEN 'PASS_BUT_BOX_QTY_IS_ZERO'
        ELSE 'PASS_ELIGIBLE_FOR_BOX_INVOICE'
    END AS BoxEligibility
FROM BoxResolution br
ORDER BY br.ChargeItemID;

PRINT '==== 4) ITEM-LEVEL CHECK (ChargeGroup prerequisites per packed item) ====';
;WITH PackedItems AS
(
    SELECT
        prl.ItemNumber,
        SUM(COALESCE(prl.Qty, 0)) AS PackedQty
    FROM dbo.PackingResultLine prl
    WHERE prl.PackingResultID = @PackingResultID
      AND prl.Deleted = 0
    GROUP BY prl.ItemNumber
)
SELECT
    pi.ItemNumber,
    pi.PackedQty,
    it.ItemID,
    it.ItemName,
    icg.ChargeGroupID,
    cg.ChargeGroupName,
    cgc.ChargeItemPrice AS UnitPrice,
    cgc.ChargeItemCurrency AS UnitCurrency,
    CASE
        WHEN @PackingResultID IS NULL THEN 'FAIL_NO_PACKING_RESULT'
        WHEN it.ItemID IS NULL THEN 'FAIL_ITEM_NOT_FOUND_FOR_TENANT'
        WHEN icg.ChargeGroupID IS NULL THEN 'FAIL_NO_ITEM_CHARGE_GROUP_FOR_PACKING'
        WHEN cgc.ChargeItemPrice IS NULL THEN 'FAIL_NO_CHARGE_GROUP_COST_FOR_UNIT_AND_WAREHOUSE'
        ELSE 'PASS_ELIGIBLE_FOR_ITEM_LEVEL_INVOICE'
    END AS ItemEligibility
FROM PackedItems pi
LEFT JOIN dbo.Items it
       ON it.ItemNumber = pi.ItemNumber
      AND it.TenantCode = @TenantCode
      AND it.Deleted = 0
LEFT JOIN dbo.ItemChargeGroup icg
       ON icg.ItemID = it.ItemID
      AND icg.Category = 'Packing'
      AND icg.Deleted = 0
LEFT JOIN dbo.ChargeGroup cg
       ON cg.ChargeGroupID = icg.ChargeGroupID
      AND cg.Category = 'Packing'
      AND cg.Deleted = 0
LEFT JOIN dbo.ChargeGroupCost cgc
       ON cgc.ChargeGroupID = icg.ChargeGroupID
      AND cgc.WarehouseCode = @WarehouseCode
      AND cgc.ChargeItemUnit = 'Unit'
      AND cgc.Deleted = 0
ORDER BY pi.ItemNumber;

PRINT '==== 5) SUMMARY FLAGS ====';
;WITH ExistingPackingInvoices AS
(
    SELECT COUNT(1) AS Cnt
    FROM dbo.Invoice i
    WHERE i.Deleted = 0
      AND i.ChargeCategory = 'Packing'
      AND i.InvoiceReferences = @OrderNumber
      AND (@TenantCode IS NULL OR i.TenantCode = @TenantCode)
      AND (@WarehouseCode IS NULL OR i.WarehouseCode = @WarehouseCode)
      AND (@WaveNumber IS NULL OR i.WaveReferences = @WaveNumber)
),
BoxItems AS
(
    SELECT ci.ChargeItemID
    FROM dbo.ChargeItem ci
    WHERE ci.Deleted = 0
      AND ci.ChargeItemGroup = 'Packing'
      AND ci.ChargeItemUnit = 'Box'
),
BoxEligible AS
(
    SELECT COUNT(1) AS EligibleCnt,
           SUM(CASE WHEN @BoxQty > 0 THEN 1 ELSE 0 END) AS EligibleWithPositiveBoxQtyCnt
    FROM BoxItems b
    JOIN dbo.TenantChargeItem tci
      ON tci.ChargeItemId = b.ChargeItemID
     AND tci.TenantCode = @TenantCode
     AND tci.Deleted = 0
    LEFT JOIN dbo.ChargeItemCost cic
      ON cic.ChargeItemID = b.ChargeItemID
     AND cic.WarehouseCode = @WarehouseCode
     AND cic.Deleted = 0
     AND tci.ChargeType = 'Standard'
    LEFT JOIN dbo.TenantCustomCost tcc
      ON tcc.TenantChargeItemID = tci.TenantChargeItemID
     AND tcc.WarehouseCode = @WarehouseCode
     AND tcc.Deleted = 0
     AND tci.ChargeType <> 'Standard'
    WHERE (tci.ChargeType = 'Standard' AND cic.ChargeItemPrice IS NOT NULL)
       OR (tci.ChargeType <> 'Standard' AND tcc.ChargeItemPrice IS NOT NULL)
),
ItemFailures AS
(
    SELECT COUNT(1) AS FailCnt
    FROM
    (
        SELECT pi.ItemNumber,
               CASE
                   WHEN it.ItemID IS NULL THEN 1
                   WHEN icg.ChargeGroupID IS NULL THEN 1
                   WHEN cgc.ChargeItemPrice IS NULL THEN 1
                   ELSE 0
               END AS IsFail
        FROM
        (
            SELECT prl.ItemNumber
            FROM dbo.PackingResultLine prl
            WHERE prl.PackingResultID = @PackingResultID
              AND prl.Deleted = 0
            GROUP BY prl.ItemNumber
        ) pi
        LEFT JOIN dbo.Items it
               ON it.ItemNumber = pi.ItemNumber
              AND it.TenantCode = @TenantCode
              AND it.Deleted = 0
        LEFT JOIN dbo.ItemChargeGroup icg
               ON icg.ItemID = it.ItemID
              AND icg.Category = 'Packing'
              AND icg.Deleted = 0
        LEFT JOIN dbo.ChargeGroupCost cgc
               ON cgc.ChargeGroupID = icg.ChargeGroupID
              AND cgc.WarehouseCode = @WarehouseCode
              AND cgc.ChargeItemUnit = 'Unit'
              AND cgc.Deleted = 0
    ) x
    WHERE x.IsFail = 1
)
SELECT
    epi.Cnt AS ExistingPackingInvoiceRows,
  CASE WHEN @TenantCode IS NULL OR @WarehouseCode IS NULL THEN 1 ELSE 0 END AS Flag_NoFulfilmentContext,
    CASE WHEN @PackingResultID IS NULL THEN 1 ELSE 0 END AS Flag_NoPackingResult,
  CASE WHEN @PackingResultID IS NOT NULL AND @PackingLineCount = 0 THEN 1 ELSE 0 END AS Flag_NoPackingResultLines,
    CASE WHEN (SELECT COUNT(1) FROM BoxItems) = 0 THEN 1 ELSE 0 END AS Flag_NoPackingBoxChargeItem,
    CASE WHEN (SELECT EligibleCnt FROM BoxEligible) = 0 THEN 1 ELSE 0 END AS Flag_NoEligibleBoxChargeForTenantWarehouse,
  CASE WHEN (SELECT EligibleCnt FROM BoxEligible) > 0 AND @BoxQty <= 0 THEN 1 ELSE 0 END AS Flag_BoxEligibleButBoxQtyZero,
    (SELECT FailCnt FROM ItemFailures) AS ItemLevelFailureCount,
    CASE
        WHEN epi.Cnt > 0 THEN 'Packing invoice exists'
    WHEN @TenantCode IS NULL OR @WarehouseCode IS NULL THEN 'Not created: no active fulfilment context for order'
        WHEN @PackingResultID IS NULL THEN 'Not created: no PackingResult'
    WHEN @PackingLineCount = 0 AND (SELECT EligibleCnt FROM BoxEligible) = 0 THEN 'Not created: no PackingResultLine and no eligible box charge'
    WHEN @PackingLineCount = 0 AND (SELECT EligibleCnt FROM BoxEligible) > 0 AND @BoxQty <= 0 THEN 'Not created: eligible box charge exists but NumberOfBoxes is zero'
    WHEN @PackingLineCount = 0 AND (SELECT EligibleCnt FROM BoxEligible) > 0 THEN 'Check data: box-level invoice should still be insertable'
        WHEN (SELECT COUNT(1) FROM BoxItems) = 0
             AND (SELECT FailCnt FROM ItemFailures) > 0 THEN 'Not created: no box config and item-level setup failures'
        WHEN (SELECT EligibleCnt FROM BoxEligible) = 0
             AND (SELECT FailCnt FROM ItemFailures) > 0 THEN 'Not created: no eligible box charge and item-level setup failures'
    WHEN (SELECT FailCnt FROM ItemFailures) > 0 THEN 'Partially blocked: some item-level charge-group prerequisites failed'
    WHEN (SELECT EligibleCnt FROM BoxEligible) > 0 AND @BoxQty <= 0 THEN 'Box row may be inserted with zero qty/zero charge; verify consumer filtering'
        ELSE 'Check detailed result sets above'
    END AS LikelyRootCause
FROM ExistingPackingInvoices epi;
