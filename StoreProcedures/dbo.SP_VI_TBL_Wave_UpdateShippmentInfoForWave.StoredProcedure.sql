USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Wave_UpdateShippmentInfoForWave]    Script Date: 3/24/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:      <Nam Nguyen>
-- Create date: <24 Mar, 2026>
-- Description: <Update CMC shipment info by wave and source order number>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_Wave_UpdateShippmentInfoForWave]
    @CMCResults dbo.CMCResult READONLY,
    @OperationDateTime DATETIME = NULL,
    @OperationBy VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @UpdatedRows TABLE
        (
            WaveNumber VARCHAR(50),
            SourceOrderNumber VARCHAR(50)
        );

        DECLARE @ShipmentUpdates TABLE
        (
            ShipmentID INT,
            Carrier VARCHAR(100),
            IsLocal BIT,
            BoxLength DECIMAL(18, 3),
            BoxHeight DECIMAL(18, 3),
            BoxWidth DECIMAL(18, 3),
            BoxWeight DECIMAL(18, 4)
        );

        -- Update CMCPackingWaveResult with the provided CMCResults, only for valid rows with non-empty WaveNumber and SourceOrderNumber
        ;WITH InputRows AS
        (
            SELECT
                LTRIM(RTRIM(ISNULL(r.WaveNumber, ''))) AS WaveNumber,
                LTRIM(RTRIM(ISNULL(r.SourceOrderNumber, ''))) AS SourceOrderNumber,
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(r.OrderStatus)), '') = 'Failed' THEN 'Canceled'
                    ELSE NULLIF(LTRIM(RTRIM(r.OrderStatus)), '')
                END AS OrderStatus
            FROM @CMCResults r
        ),
        ValidRows AS
        (
            SELECT DISTINCT
                i.WaveNumber,
                i.SourceOrderNumber,
                i.OrderStatus
            FROM InputRows i
            WHERE i.WaveNumber <> ''
              AND i.SourceOrderNumber <> ''
        )
        UPDATE c
        SET
            c.Status = COALESCE(v.OrderStatus, c.Status),
            c.LastEditedDateTime = COALESCE(@OperationDateTime, GETDATE()),
            c.LastEditedBy = COALESCE(NULLIF(LTRIM(RTRIM(@OperationBy)), ''), '')
        OUTPUT
            inserted.WaveNumber,
            inserted.SourceOrderNumber
        INTO @UpdatedRows (WaveNumber, SourceOrderNumber)
        FROM dbo.CMCPackingWaveResult c
        INNER JOIN ValidRows v
            ON v.WaveNumber = c.WaveNumber
           AND v.SourceOrderNumber = c.SourceOrderNumber
        WHERE ISNULL(c.Deleted, 0) = 0;

        -- Update 
        UPDATE wl
        SET
            wl.PackStatus = 'Completed',
            wl.FirstEditedDateTime = COALESCE(@OperationDateTime, wl.FirstEditedDateTime),
            wl.FirstEditedBy = COALESCE(@OperationBy, wl.FirstEditedBy),
            wl.LastEditedDateTime = COALESCE(@OperationDateTime, wl.LastEditedDateTime),
            wl.LastEditedBy = COALESCE(@OperationBy, wl.LastEditedBy),
            wl.PackDateTime = COALESCE(@OperationDateTime, wl.PackDateTime),
            wl.PackBy = COALESCE(@OperationBy, wl.PackBy)
        FROM dbo.WaveLine wl
        INNER JOIN @UpdatedRows u
            ON u.WaveNumber = wl.WaveNumber
           AND u.SourceOrderNumber = wl.SourceOrderNumber
        INNER JOIN dbo.CMCPackingWaveResult c
            ON c.WaveNumber = u.WaveNumber
           AND c.SourceOrderNumber = u.SourceOrderNumber
           AND ISNULL(c.Deleted, 0) = 0
        WHERE ISNULL(wl.Deleted, 0) = 0
          AND c.Status = 'Completed';

        --update shipment info for DHL and AP/AU Post based on the updated wave results
        
        INSERT INTO @ShipmentUpdates
        (
            ShipmentID,
            Carrier,
            IsLocal,
            BoxLength,
            BoxHeight,
            BoxWidth,
            BoxWeight
        )
        SELECT DISTINCT
            c.ShipmentID,
            c.Carrier,
            c.IsLocal,
            TRY_CONVERT(DECIMAL(18, 3), r.BoxSzieL),
            TRY_CONVERT(DECIMAL(18, 3), r.BoxSizeH),
            TRY_CONVERT(DECIMAL(18, 3), r.BoxSizeW),
            COALESCE(TRY_CONVERT(DECIMAL(18, 4), r.Box_Weight), 0)
                + COALESCE(TRY_CONVERT(DECIMAL(18, 4), r.Weight_Carton), 0)
        FROM @CMCResults r
        INNER JOIN dbo.CMCPackingWaveResult c
            ON c.WaveNumber = LTRIM(RTRIM(ISNULL(r.WaveNumber, '')))
           AND c.SourceOrderNumber = LTRIM(RTRIM(ISNULL(r.SourceOrderNumber, '')))
           AND ISNULL(c.Deleted, 0) = 0
        WHERE c.ShipmentID IS NOT NULL;

        UPDATE dhl
        SET
            dhl.[length] = COALESCE(u.BoxLength, dhl.[length]),
            dhl.[height] = COALESCE(u.BoxHeight, dhl.[height]),
            dhl.[width] = COALESCE(u.BoxWidth, dhl.[width]),
            dhl.[weight] = COALESCE(u.BoxWeight, dhl.[weight]),
            dhl.LastEditedDateTime = COALESCE(@OperationDateTime, GETDATE()),
            dhl.LastEditedBy = COALESCE(NULLIF(LTRIM(RTRIM(@OperationBy)), ''), '')
        FROM dbo.DHLPackages dhl
        INNER JOIN @ShipmentUpdates u
            ON u.ShipmentID = dhl.ShipmentID
        WHERE ISNULL(dhl.Deleted, 0) = 0
          AND u.Carrier LIKE 'DHL%';

        UPDATE apLocal
        SET
            apLocal.[Length] = COALESCE(CONVERT(VARCHAR(20), u.BoxLength), apLocal.[Length]),
            apLocal.[Height] = COALESCE(CONVERT(VARCHAR(20), u.BoxHeight), apLocal.[Height]),
            apLocal.[Width] = COALESCE(CONVERT(VARCHAR(20), u.BoxWidth), apLocal.[Width]),
            apLocal.[Weight] = COALESCE(CONVERT(VARCHAR(20), u.BoxWeight), apLocal.[Weight]),
            apLocal.LastEditedDateTime = COALESCE(@OperationDateTime, GETDATE()),
            apLocal.LastEditedBy = COALESCE(NULLIF(LTRIM(RTRIM(@OperationBy)), ''), '')
        FROM dbo.AP_ShipmentItems apLocal
        INNER JOIN @ShipmentUpdates u
            ON u.ShipmentID = apLocal.ShipmentID
           AND u.Carrier LIKE 'AP%'
           AND ISNULL(u.IsLocal, 0) = 1
        WHERE ISNULL(apLocal.Deleted, 0) = 0;

        UPDATE apInt
        SET
            apInt.[Length] = COALESCE(CONVERT(VARCHAR(20), u.BoxLength), apInt.[Length]),
            apInt.[Height] = COALESCE(CONVERT(VARCHAR(20), u.BoxHeight), apInt.[Height]),
            apInt.[Width] = COALESCE(CONVERT(VARCHAR(20), u.BoxWidth), apInt.[Width]),
            apInt.[Weight] = COALESCE(CONVERT(VARCHAR(20), u.BoxWeight), apInt.[Weight]),
            apInt.LastEditedDateTime = COALESCE(@OperationDateTime, GETDATE()),
            apInt.LastEditedBy = COALESCE(NULLIF(LTRIM(RTRIM(@OperationBy)), ''), '')
        FROM dbo.AP_ShipmentItemsINT apInt
        INNER JOIN @ShipmentUpdates u
            ON u.ShipmentID = apInt.ShipmentID
           AND u.Carrier LIKE 'AP%'
           AND ISNULL(u.IsLocal, 0) = 0
        WHERE ISNULL(apInt.Deleted, 0) = 0;
        

        SELECT
            c.ShipmentID,
            w.WarehouseCode,
            c.IsLocal,
            c.Carrier,
            wl.OrderNumber
        FROM @UpdatedRows u
        INNER JOIN dbo.CMCPackingWaveResult c
            ON c.WaveNumber = u.WaveNumber
           AND c.SourceOrderNumber = u.SourceOrderNumber
           AND ISNULL(c.Deleted, 0) = 0
        LEFT JOIN dbo.Wave w
            ON w.WaveNumber = c.WaveNumber
           AND ISNULL(w.Deleted, 0) = 0
        OUTER APPLY
        (
            SELECT TOP 1 x.OrderNumber
            FROM dbo.WaveLine x
            WHERE x.WaveNumber = c.WaveNumber
              AND x.SourceOrderNumber = c.SourceOrderNumber
              AND ISNULL(x.Deleted, 0) = 0
            ORDER BY x.WaveLineID DESC
        ) wl;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;

        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END
GO
