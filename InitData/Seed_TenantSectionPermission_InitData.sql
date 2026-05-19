USE [3PLWMS_Developers]
GO

SET NOCOUNT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    INSERT INTO [dbo].[TenantSectionPermission] ([TenantPermissionID], [Section], [Deleted])
    SELECT v.TenantPermissionID, v.Section, v.Deleted
    FROM (VALUES
        (1, 'New', 0),
        (1, 'Pending', 0),
        (1, 'InProgress', 0),
        (1, 'Complete', 0),
        (1, 'Error', 0)
    ) AS v (TenantPermissionID, Section, Deleted)
    WHERE NOT EXISTS (
        SELECT 1
        FROM [dbo].[TenantSectionPermission] tsp
        WHERE tsp.[TenantPermissionID] = v.TenantPermissionID
          AND tsp.[Section] = v.Section
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
