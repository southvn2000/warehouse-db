USE [3PLWMS_Developers]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_VI_TBL_ULD_GetULDsHavingStockOfTenantAtWarehouse]    Script Date: 4/15/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:      <Nam nguyen>
-- Create date: <15 Apr, 2026>
-- Description: <Get ULD Having Stock of Tenant At Warehouse>
-- =============================================
CREATE FUNCTION [dbo].[fn_GetULDsHavingStockOfTenantAtWarehouse]
(
    @TenantCode VARCHAR(10) = NULL,
    @WarehouseCode VARCHAR(20) = NULL,
    @ItemNumber VARCHAR(30),
    @PickingCondition VARCHAR(100) = NULL,
    @CountOnHold BIT = 1  -- 1: Count onHold ULD ; 0: Not Count onHold ULD
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        U.ULDID,
        U.ULDBarcode,
        U.ULDCurrentLocation,
        dbo.fn_GetLocationOrderNumberFromCode(U.ULDCurrentLocation) AS LocationOrderNumber,
        U.LocColumnID,
        U.LocShelfID,
        U.LocBinID,
        U.LocSBinID,
        U.ULDType,
        U.TenantCode,
        U.WarehouseCode,
        U.HoldStatus,
        U.CurrentZone,
        U.Status,
        U.ItemNumber,
        U.ItemName,
        U.ExpiryDate,
        U.BatchNumber,
        U.ReceivedDateTime AS CreatedDateTime,
        SUM(UL.TransactionQty) AS TotalQty
    FROM
    (
        SELECT DISTINCT
            l.*,
            t.Location
        FROM dbo.ULD l
        LEFT JOIN
        (
            SELECT
                (WarehouseCode + AreaCode + SectionCode + BinCode) AS Location
            FROM LocTempLocation
            WHERE Deleted = 0
        ) t ON l.ULDCurrentLocation = t.Location
        WHERE l.Deleted = 0
          AND l.ULDCurrentLocation IS NOT NULL
          AND (l.LocColumnID IS NULL OR l.LocColumnID = -1)

        UNION ALL

        SELECT DISTINCT
            l.*,
            'A' AS Location
        FROM dbo.ULD l
        WHERE l.Deleted = 0
          AND l.ULDCurrentLocation IS NOT NULL
          AND l.LocColumnID IS NOT NULL
          AND l.LocColumnID <> -1
    ) U
    INNER JOIN dbo.ULDLine UL ON UL.ULDID = U.ULDID
    WHERE UL.Deleted = 0
      AND U.Location IS NOT NULL
      AND U.TenantCode = @TenantCode
      AND U.ItemNumber = @ItemNumber
      AND U.Status NOT IN ('Draft', 'InActive', 'Locked')
      AND (@WarehouseCode IS NULL OR U.WarehouseCode = @WarehouseCode)
      AND (@CountOnHold = 1 OR U.HoldStatus IS NULL)
    GROUP BY
        U.ULDID,
        U.ULDBarcode,
        U.ULDCurrentLocation,
        U.LocColumnID,
        U.LocShelfID,
        U.LocBinID,
        U.LocSBinID,
        U.ULDType,
        U.TenantCode,
        U.WarehouseCode,
        U.HoldStatus,
        U.CurrentZone,
        U.Status,
        U.ItemNumber,
        U.ItemName,
        U.ExpiryDate,
        U.BatchNumber,
        U.ReceivedDateTime
    HAVING SUM(UL.TransactionQty) > 0
);
GO
