USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_BackupReport_ViewBackupReportByID]    Script Date: 5/20/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Nam Nguyen>
-- Create date: <20 May, 2026>
-- Description: <View Backup Report By ID>
-- =============================================
ALTER PROCEDURE [dbo].[SP_VI_TBL_BackupReport_ViewBackupReportByID]
    @BackupReportID INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT br.*, t.TenantName, lw.WarehouseName
    FROM dbo.BackupReport br
    LEFT JOIN dbo.Tenant t ON t.TenantCode = br.TenantCode AND ISNULL(t.Deleted, 0) = 0
    LEFT JOIN dbo.LocWarehouse lw ON lw.WarehouseCode = br.WarehouseCode AND ISNULL(lw.Deleted, 0) = 0
    WHERE br.BackupReportID = @BackupReportID
      AND br.Deleted = 0;
END
GO