USE [3PLWMS_QA]
GO

/*
Purpose:
- Check which charge items are applicable for one tenant.
- Mirror cost-resolution behavior from:
  - SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode

How to use:
1) Set @TenantCode.
2) Optionally set @WarehouseCode (recommended for exact apply/not-apply result).
3) Run the script.
*/

DECLARE @TenantCode VARCHAR(10) = 'pepprb';
DECLARE @WarehouseCode VARCHAR(20) = NULL; -- Example: 'MEL'
DECLARE @OnlyShowApplied BIT = 1; -- 1 = only show items with TenantChargeItem subscription

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Tenant t
    WHERE t.TenantCode = @TenantCode
      AND t.Deleted = 0
)
BEGIN
    RAISERROR('TenantCode not found or deleted: %s', 16, 1, @TenantCode);
    RETURN;
END

PRINT '==== INPUT ====';
SELECT
    @TenantCode AS TenantCode,
    @WarehouseCode AS WarehouseCode,
    @OnlyShowApplied AS OnlyShowApplied;

PRINT '==== 1) TENANT CHARGE ITEM SUBSCRIPTIONS ====';
SELECT
    tci.TenantChargeItemID,
    tci.TenantCode,
    tci.ChargeItemID,
    ci.ChargeItemName,
    ci.ChargeItemGroup,
    ci.ChargeItemUnit,
    tci.ChargeType,
    tci.EffectiveDate,
    tci.EndDate,
    tci.CustomCost,
    tci.CreatedDateTime,
    tci.CreatedBy
FROM dbo.TenantChargeItem tci
JOIN dbo.ChargeItem ci
  ON ci.ChargeItemID = tci.ChargeItemID
 AND ci.Deleted = 0
WHERE tci.TenantCode = @TenantCode
  AND tci.Deleted = 0
ORDER BY ci.ChargeItemGroup, ci.ChargeItemName;

PRINT '==== 2) APPLICABILITY CHECK (ALL CHARGE ITEMS) ====';
;WITH Base AS
(
    SELECT
        ci.ChargeItemID,
        ci.ChargeItemName,
        ci.ChargeItemGroup,
        ci.ChargeItemUnit,
        ci.Mandatory,
        tci.TenantChargeItemID,
        tci.ChargeType,
        tci.EffectiveDate,
        tci.EndDate
    FROM dbo.ChargeItem ci
    LEFT JOIN dbo.TenantChargeItem tci
           ON tci.ChargeItemID = ci.ChargeItemID
          AND tci.TenantCode = @TenantCode
          AND tci.Deleted = 0
    WHERE ci.Deleted = 0
),
Resolution AS
(
    SELECT
        b.*,
        cic.ChargeItemPrice AS StandardPrice,
        cic.ChargeItemCurrency AS StandardCurrency,
        tcc.ChargeItemPrice AS CustomPrice,
        tcc.ChargeItemCurrency AS CustomCurrency,
        CASE
            WHEN b.TenantChargeItemID IS NULL THEN 'NOT_APPLIED_NO_TENANT_CHARGE_ITEM'
            WHEN @WarehouseCode IS NULL THEN 'SUBSCRIBED_WAREHOUSE_NOT_PROVIDED'
            WHEN b.ChargeType = 'Standard' AND cic.ChargeItemPrice IS NOT NULL THEN 'APPLIED_STANDARD_PRICE_FOUND'
            WHEN b.ChargeType = 'Standard' AND cic.ChargeItemPrice IS NULL THEN 'NOT_APPLIED_STANDARD_PRICE_MISSING'
            WHEN b.ChargeType <> 'Standard' AND tcc.ChargeItemPrice IS NOT NULL THEN 'APPLIED_CUSTOM_PRICE_FOUND'
            WHEN b.ChargeType <> 'Standard' AND tcc.ChargeItemPrice IS NULL THEN 'NOT_APPLIED_CUSTOM_PRICE_MISSING'
            ELSE 'UNKNOWN'
        END AS ApplyStatus,
        CASE
            WHEN b.TenantChargeItemID IS NULL THEN 0
            WHEN @WarehouseCode IS NULL THEN 0
            WHEN b.ChargeType = 'Standard' AND cic.ChargeItemPrice IS NOT NULL THEN 1
            WHEN b.ChargeType <> 'Standard' AND tcc.ChargeItemPrice IS NOT NULL THEN 1
            ELSE 0
        END AS IsAppliedForWarehouse
    FROM Base b
    LEFT JOIN dbo.ChargeItemCost cic
           ON cic.ChargeItemID = b.ChargeItemID
          AND cic.WarehouseCode = @WarehouseCode
          AND cic.Deleted = 0
          AND b.ChargeType = 'Standard'
    LEFT JOIN dbo.TenantCustomCost tcc
           ON tcc.TenantChargeItemID = b.TenantChargeItemID
          AND tcc.WarehouseCode = @WarehouseCode
          AND tcc.Deleted = 0
          AND b.ChargeType <> 'Standard'
)
SELECT
    r.ChargeItemID,
    r.ChargeItemName,
    r.ChargeItemGroup,
    r.ChargeItemUnit,
    r.Mandatory,
    r.TenantChargeItemID,
    r.ChargeType,
    r.EffectiveDate,
    r.EndDate,
    r.StandardPrice,
    r.StandardCurrency,
    r.CustomPrice,
    r.CustomCurrency,
    r.IsAppliedForWarehouse,
    r.ApplyStatus
FROM Resolution r
WHERE (@OnlyShowApplied = 0 OR r.TenantChargeItemID IS NOT NULL)
ORDER BY r.ChargeItemGroup, r.ChargeItemName;

PRINT '==== 3) SUMMARY ====';
;WITH Base AS
(
    SELECT
        ci.ChargeItemID,
        tci.TenantChargeItemID,
        tci.ChargeType
    FROM dbo.ChargeItem ci
    LEFT JOIN dbo.TenantChargeItem tci
           ON tci.ChargeItemID = ci.ChargeItemID
          AND tci.TenantCode = @TenantCode
          AND tci.Deleted = 0
    WHERE ci.Deleted = 0
),
Resolution AS
(
    SELECT
        b.*,
        cic.ChargeItemPrice AS StandardPrice,
        tcc.ChargeItemPrice AS CustomPrice
    FROM Base b
    LEFT JOIN dbo.ChargeItemCost cic
           ON cic.ChargeItemID = b.ChargeItemID
          AND cic.WarehouseCode = @WarehouseCode
          AND cic.Deleted = 0
          AND b.ChargeType = 'Standard'
    LEFT JOIN dbo.TenantCustomCost tcc
           ON tcc.TenantChargeItemID = b.TenantChargeItemID
          AND tcc.WarehouseCode = @WarehouseCode
          AND tcc.Deleted = 0
          AND b.ChargeType <> 'Standard'
)
SELECT
    @TenantCode AS TenantCode,
    @WarehouseCode AS WarehouseCode,
    COUNT(1) AS TotalChargeItems,
    SUM(CASE WHEN r.TenantChargeItemID IS NOT NULL THEN 1 ELSE 0 END) AS SubscribedChargeItems,
    SUM(CASE WHEN r.TenantChargeItemID IS NULL THEN 1 ELSE 0 END) AS NotSubscribedChargeItems,
    SUM(CASE
            WHEN @WarehouseCode IS NOT NULL
             AND r.TenantChargeItemID IS NOT NULL
             AND r.ChargeType = 'Standard'
             AND r.StandardPrice IS NOT NULL THEN 1
            WHEN @WarehouseCode IS NOT NULL
             AND r.TenantChargeItemID IS NOT NULL
             AND r.ChargeType <> 'Standard'
             AND r.CustomPrice IS NOT NULL THEN 1
            ELSE 0
        END) AS AppliedForWarehouse,
    SUM(CASE
            WHEN @WarehouseCode IS NOT NULL
             AND r.TenantChargeItemID IS NOT NULL
             AND r.ChargeType = 'Standard'
             AND r.StandardPrice IS NULL THEN 1
            WHEN @WarehouseCode IS NOT NULL
             AND r.TenantChargeItemID IS NOT NULL
             AND r.ChargeType <> 'Standard'
             AND r.CustomPrice IS NULL THEN 1
            ELSE 0
        END) AS SubscribedButNoPriceForWarehouse
FROM Resolution r;
