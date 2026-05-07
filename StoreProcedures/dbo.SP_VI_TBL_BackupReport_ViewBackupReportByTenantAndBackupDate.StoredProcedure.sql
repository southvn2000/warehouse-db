USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_BackupReport_ViewBackupReportByTenantAndBackupDate]    Script Date: 5/5/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Nam Nguyen>
-- Create date: <05 May, 2026>
-- Description: <Get Backup Report by TenantCode and BackupDate>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_BackupReport_ViewBackupReportByTenantAndBackupDate]
    @TenantCode VARCHAR(10),
    @BackupDate DATETIME
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        br.*
    FROM dbo.BackupReport br
    WHERE br.Deleted = 0
      AND br.TenantCode = @TenantCode
      AND CAST(br.BackupDate AS DATE) = CAST(@BackupDate AS DATE)
    ORDER BY br.BackupDate DESC, br.BackupReportID DESC;
END
GO
