USE [3PLWMS_Developers];
GO

/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_OnHoldOrderLog_ListByOrderNumber]    Script Date: 5/4/2026 ******/
SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

-- =============================================
-- Author:      <Nam Nguyen>
-- Create date: <04 May, 2026>
-- Description: <List OnHoldOrderLog by OrderNumber and OrderType, ordered by LogDate DESC>
-- =============================================
ALTER PROCEDURE [dbo].[SP_VI_TBL_OnHoldOrderLog_ListByOrderNumber]
    @OrderNumber VARCHAR(50) = NULL,
    @OrderType   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        OnHoldOrderLogID,
        OrderNumber,
        OrderType,
        Reason,
        LogType,
        LogDate,
        LogBy,
        CreatedBy,
        CreatedDateTime,
        LastEditedBy,
        LastEditedDateTime,
        FirstEditedDateTime,
        FirstEditedBy,
        Deleted
    FROM dbo.OnHoldOrderLog
    WHERE ISNULL(Deleted, 0) = 0
      AND (@OrderNumber IS NULL OR OrderNumber = @OrderNumber)
      AND (@OrderType   IS NULL OR OrderType   = @OrderType)
    ORDER BY LogDate DESC;
END;
GO
