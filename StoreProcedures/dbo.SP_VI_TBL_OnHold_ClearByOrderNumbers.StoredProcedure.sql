USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_OnHold_ClearByOrderNumbers]    Script Date: 4/16/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Copilot>
-- Create date: <16 Apr, 2026>
-- Description: <Clear OnHold for Order/Fulfilment by array and write audit log>
-- =============================================
ALTER PROCEDURE [dbo].[SP_VI_TBL_OnHold_ClearByOrderNumbers]
    @OrderType VARCHAR(20), -- Order | Fulfilment
    @OrderNumbers dbo.OrderType READONLY,
    @EditedDateTime DATETIME = NULL,
    @EditedBy VARCHAR(100) = NULL,
    @Message VARCHAR(4000) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @OrderType NOT IN ('Order', 'Fulfilment')
        BEGIN
            SET @Message = 'OrderType must be either Order or Fulfilment.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @ActionDateTime DATETIME = COALESCE(@EditedDateTime, GETDATE());
        DECLARE @ActionBy VARCHAR(100) = COALESCE(@EditedBy, 'System');
        DECLARE @Updated TABLE (OrderNumber VARCHAR(50) PRIMARY KEY);

        IF @OrderType = 'Order'
        BEGIN
            UPDATE O
            SET
                O.OnHold = 0,
                O.FulfilmentStatus = 'Not Started',
                O.FulfilmentStatusDateTime = NULL,
                O.FirstEditedDateTime = COALESCE(O.FirstEditedDateTime, @ActionDateTime),
                O.FirstEditedBy = COALESCE(O.FirstEditedBy, @ActionBy),
                O.LastEditedDateTime = @ActionDateTime,
                O.LastEditedBy = @ActionBy
            OUTPUT inserted.order_number INTO @Updated(OrderNumber)
            FROM dbo.Orders O
            INNER JOIN @OrderNumbers N ON N.OrderNumber = O.order_number
            WHERE ISNULL(O.Deleted, 0) = 0
              AND ISNULL(O.OnHold, 0) = 1
              AND LOWER(ISNULL(O.Source, '')) = 'manual';

            UPDATE F
            SET
                F.OnHold = 0,
                F.FulfilmentStatus = 'OnHoldCleared',                
                F.FirstEditedDateTime = COALESCE(F.FirstEditedDateTime, @ActionDateTime),
                F.FirstEditedBy = COALESCE(F.FirstEditedBy, @ActionBy),
                F.LastEditedDateTime = @ActionDateTime,
                F.LastEditedBy = @ActionBy
            OUTPUT inserted.order_number INTO @Updated(OrderNumber)
            FROM dbo.Fulfilment F
            INNER JOIN @OrderNumbers N ON N.OrderNumber = F.OrderNumber
            WHERE ISNULL(F.Deleted, 0) = 0
              AND ISNULL(F.OnHold, 0) = 1
              AND LOWER(ISNULL(F.OrderSource, '')) = 'shopify';
            

            INSERT INTO dbo.OnHoldOrderLog
                ([OrderNumber], [OrderType], [LogType], [LogDate], [LogBy], [CreatedBy], [CreatedDateTime], [FirstEditedBy], [FirstEditedDateTime], [LastEditedBy], [LastEditedDateTime], [Deleted])
            SELECT
                U.OrderNumber,
                'Order',
                'Clear',
                @ActionDateTime,
                @ActionBy,
                @ActionBy,
                @ActionDateTime,
                @ActionBy,
                @ActionDateTime,
                @ActionBy,
                @ActionDateTime,
                0
            FROM @Updated U;
        END
        ELSE
        BEGIN
            UPDATE F
            SET
                F.OnHold = 0,
                F.FulfilmentStatus = 'OnHoldCleared',    
                F.FirstEditedDateTime = COALESCE(F.FirstEditedDateTime, @ActionDateTime),
                F.FirstEditedBy = COALESCE(F.FirstEditedBy, @ActionBy),
                F.LastEditedDateTime = @ActionDateTime,
                F.LastEditedBy = @ActionBy
            OUTPUT inserted.OrderNumber INTO @Updated(OrderNumber)
            FROM dbo.Fulfilment F
            INNER JOIN @OrderNumbers N ON N.OrderNumber = F.OrderNumber
            WHERE ISNULL(F.Deleted, 0) = 0
              AND ISNULL(F.OnHold, 0) = 1;

            INSERT INTO dbo.OnHoldOrderLog
                ([OrderNumber], [OrderType], [LogType], [LogDate], [LogBy], [CreatedBy], [CreatedDateTime], [FirstEditedBy], [FirstEditedDateTime], [LastEditedBy], [LastEditedDateTime], [Deleted])
            SELECT
                U.OrderNumber,
                'Fulfilment',
                'Clear',
                @ActionDateTime,
                @ActionBy,
                @ActionBy,
                @ActionDateTime,
                @ActionBy,
                @ActionDateTime,
                @ActionBy,
                @ActionDateTime,
                0
            FROM @Updated U;
        END

        SET @Message = CAST((SELECT COUNT(1) FROM @Updated) AS VARCHAR(20)) + ' ' + @OrderType + ' record(s) cleared from OnHold.';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @Message = ERROR_MESSAGE();
        THROW;
    END CATCH;
END
GO
