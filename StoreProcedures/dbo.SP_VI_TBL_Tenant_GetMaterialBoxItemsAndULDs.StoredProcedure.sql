USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Tenant_GetMaterialBoxItemsAndULDs]    Script Date: 3/20/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Copilot>
-- Create date: <20 Mar, 2026>
-- Description:	<Get material Box items and their ULDs by tenant (or all tenants)>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_Tenant_GetMaterialBoxItemsAndULDs]
    @TenantCode VARCHAR(10) = NULL
AS
BEGIN

    SET NOCOUNT ON;

    SELECT
        I.ItemID,
        I.ItemNumber,
        I.ItemName,
        I.TenantCode,
        T.TenantName,
        I.MaterialType,
        U.ULDID,
        U.ULDBarcode,
        U.WarehouseCode,
        LW.WarehouseName,
        U.ULDCurrentLocation,
        ULStock.TotalTransactionQty AS ULDStockOnHand
    FROM dbo.Items I
    INNER JOIN dbo.ULD U
        ON U.ItemNumber = I.ItemNumber
        AND U.TenantCode = I.TenantCode
        AND U.Deleted = 0
    INNER JOIN
    (
        SELECT
            UL.ULDID,
            SUM(UL.TransactionQty) AS TotalTransactionQty
        FROM dbo.ULDLine UL
        WHERE UL.Deleted = 0
            AND UL.TransactionType <> 'Allocated'
        GROUP BY UL.ULDID
        HAVING SUM(UL.TransactionQty) > 0
    ) ULStock
        ON ULStock.ULDID = U.ULDID
    LEFT JOIN dbo.Tenant T
        ON T.TenantCode = I.TenantCode
        AND T.Deleted = 0
    LEFT JOIN dbo.LocWarehouse LW
        ON LW.WarehouseCode = U.WarehouseCode
        AND LW.Deleted = 0
    WHERE I.Deleted = 0
        AND I.ItemIsActive = 1
        AND I.ItemIsMaterial = 1
        AND LTRIM(RTRIM(ISNULL(I.MaterialType, ''))) = 'Box'
        AND (@TenantCode IS NULL OR I.TenantCode = @TenantCode)
        AND U.HoldStatus IS NULL
        AND U.Status NOT IN ('Draft', 'InActive', 'Locked')
        AND U.ULDCurrentLocation IS NOT NULL
    ORDER BY I.TenantCode, I.ItemNumber, U.WarehouseCode, U.ULDBarcode;

END
GO
