USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Wave_ListPickedULDsByWaveOrderAndItem]    Script Date: 3/30/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Copilot>
-- Create date: <30 Mar, 2026>
-- Description: <List picked ULDs by wave number, order number and item number>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_Wave_ListPickedULDsByWaveOrderAndItem]
    @WaveNumber VARCHAR(11),
    @OrderNumber VARCHAR(50),
    @ItemNumber VARCHAR(30)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        u.ULDID,
        u.ULDBarcode,
        u.ULDCurrentLocation,
        ul.ItemNumber,
        u.ExpiryDate,
        u.BatchNumber
    FROM dbo.WaveLine AS wl
    INNER JOIN dbo.ULDLine AS ul
        ON ul.TransactionReference = wl.SourceOrderNumber
       AND ul.ItemNumber = @ItemNumber
       AND ul.TransactionType = 'Picked'
       AND ul.Deleted = 0
    INNER JOIN dbo.ULD AS u
        ON u.ULDID = ul.ULDID
       AND u.Deleted = 0
    WHERE wl.Deleted = 0
      AND wl.WaveNumber = @WaveNumber
      AND wl.OrderNumber = @OrderNumber
            AND wl.PickStatus = 'Completed'
    ORDER BY u.ULDBarcode;
END
GO
