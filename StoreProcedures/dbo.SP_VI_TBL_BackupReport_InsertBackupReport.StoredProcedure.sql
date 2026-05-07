USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_BackupReport_InsertBackupReport]    Script Date: 5/5/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Nam Nguyen>
-- Create date: <05 May, 2026>
-- Description: <Insert Backup Report>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_BackupReport_InsertBackupReport]
    @TenantCode VARCHAR(10),
    @BackupDate DATETIME,
    @ExcelFileContent VARBINARY(MAX),
    @CreatedDateTime DATETIME = NULL,
    @CreatedBy VARCHAR(100) = NULL,
    @BackupReportID INT OUTPUT,
    @Message VARCHAR(4000) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.BackupReport
        (
            TenantCode,
            BackupDate,
            ExcelFileContent,
            Deleted,
            CreatedDateTime,
            CreatedBy
        )
        VALUES
        (
            @TenantCode,
            @BackupDate,
            @ExcelFileContent,
            0,
            COALESCE(@CreatedDateTime, GETDATE()),
            @CreatedBy
        );

        SET @BackupReportID = SCOPE_IDENTITY();
        SET @Message = 'Backup report inserted successfully.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        SET @BackupReportID = NULL;
        SET @Message = ERROR_MESSAGE();
    END CATCH;
END
GO
