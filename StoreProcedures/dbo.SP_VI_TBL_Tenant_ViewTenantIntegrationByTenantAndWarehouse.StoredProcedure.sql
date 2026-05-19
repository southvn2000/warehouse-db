USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Tenant_ViewTenantIntegrationByTenantAndWarehouse]    Script Date: 5/18/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:      <Nam nguyen>
-- Create date: <18 May, 2026>
-- Description: <View tenant integration by tenant and warehouse>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_Tenant_ViewTenantIntegrationByTenantAndWarehouse]
    @TenantCode VARCHAR(10),
    @WarehouseCode VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WarehouseName VARCHAR(150);

    SELECT @WarehouseName = WarehouseName
    FROM dbo.LocWarehouse
    WHERE WarehouseCode = @WarehouseCode
        AND Deleted = 0;


    IF @WarehouseName IS NULL
    BEGIN
        SELECT i.TenantCode, t.TenantName, i.IntegrationType, i.ShopDomain, i.LocationID
        FROM dbo.Integration i
            LEFT JOIN dbo.Tenant t ON i.TenantCode = t.TenantCode
        WHERE i.DELETED = 0
            AND i.TenantCode = @TenantCode;
    END
    ELSE
    BEGIN
        SELECT i.TenantCode, t.TenantName, i.IntegrationType, i.ShopDomain, i.LocationID
        FROM dbo.Integration i
            LEFT JOIN dbo.Tenant t ON i.TenantCode = t.TenantCode
        WHERE i.DELETED = 0
            AND i.TenantCode = @TenantCode
            AND LOWER(TRIM(i.WarehouseName)) = LOWER(TRIM(@WarehouseName));
    END

END
GO