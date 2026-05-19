USE [3PLWMS_Developers]
GO

SET NOCOUNT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    INSERT INTO [dbo].[TenantPermission] ([Permission], [IsViewEnable], [IsDeleteEnable], [IsEditEnable], [IsAddEnable], [Deleted])
    SELECT v.Permission, v.IsViewEnable, v.IsDeleteEnable, v.IsEditEnable, v.IsAddEnable, v.Deleted
    FROM (VALUES
        ('Order', 1, 1, 1, 1, 0),
        ('Item', 1, 0, 0, 0, 0),
        ('Report', 1, 0, 0, 0, 0),
        ('Dashboard', 1, 0, 0, 0, 0)
    ) AS v (Permission, IsViewEnable, IsDeleteEnable, IsEditEnable, IsAddEnable, Deleted)
    WHERE NOT EXISTS (
        SELECT 1
        FROM [dbo].[TenantPermission] tp
        WHERE tp.[Permission] = v.Permission
    );

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;
GO
