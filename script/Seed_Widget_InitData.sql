USE [3PLWMS_Developers]
GO

SET NOCOUNT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    INSERT INTO [dbo].[Widget] ([WidgetName], [Deleted])
    SELECT v.WidgetName, v.Deleted
    FROM (VALUES
        ('Order Status', 0),
        ('Order Source', 0),
        ('Delay Order', 0),
        ('Order History', 0)
    ) AS v (WidgetName, Deleted)
    WHERE NOT EXISTS (
        SELECT 1
        FROM [dbo].[Widget] w
        WHERE w.[WidgetName] = v.WidgetName
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
