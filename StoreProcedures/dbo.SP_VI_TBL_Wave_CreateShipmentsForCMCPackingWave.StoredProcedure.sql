USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Wave_CreateShipmentsForCMCPackingWave]    Script Date: 3/2/2026 10:38:03 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Nam nguyen>
-- Create date: <16 Mar, 2026>
-- Description:	<Create Shipment For CMC Packing Wave>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_Wave_CreateShipmentsForCMCPackingWave] 	
	@IsFirstCall BIT = 1,
	@WarehouseCode VARCHAR(20),
	@WaveNumber VARCHAR(11),
	@OperationDateTime DATETIME = NULL,
	@OperationBy VARCHAR(100) = NULL,
	@Message VARCHAR(4000) OUTPUT
AS
BEGIN
	
	SET NOCOUNT ON;

	BEGIN TRY		

		

		DECLARE @WaveID INT;
		DECLARE @ManualPacking BIT;
		DECLARE @StepSatus VARCHAR(20);
		DECLARE @CurrentStep VARCHAR(50);


		-- get info
		SELECT @WaveID = WaveID,
			   @ManualPacking = ManualPacking,
			   @StepSatus = StepStatus,
			   @CurrentStep = CurrentStep
		FROM dbo.Wave
		WHERE WaveNumber = @WaveNumber AND WarehouseCode = @WarehouseCode AND Deleted = 0;

		If @WaveID IS NULL
		BEGIN	
			SET @Message = 'Wave not Available';			
			RETURN;
		END

		IF @IsFirstCall = 0 AND @ManualPacking = 1 -- Only first call can process wave with manual packing, if it's already in manual packing, it means it's not first call
		BEGIN
			SET @Message = 'Wave not Available - Not First Call';			
			RETURN;
		END

		IF @IsFirstCall = 1 AND @ManualPacking = 0 -- If it's first call but manual packing is not set, it means the wave is already processed and not in manual packing, so return wave not available
		BEGIN
			SET @Message = 'Wave not Available - Already Processed First Call';			
			RETURN;
		END


		IF @IsFirstCall = 1 -- first call
		BEGIN

			BEGIN TRANSACTION

				IF EXISTS (
					SELECT 1
					FROM dbo.CMCPackingWaveResult r
					WHERE r.WaveNumber = @WaveNumber AND ISNULL(r.Deleted, 0) = 0
				)
				BEGIN
					SET @Message = 'Wave already imported to CMC System';
					ROLLBACK TRANSACTION;
					RETURN;
				END

				IF @ManualPacking = 0
				BEGIN
					SET @Message = 'Wave already imported to CMC System';
					ROLLBACK TRANSACTION;
					RETURN;
				END

				IF @CurrentStep = 'Packing' AND @StepSatus = 'InProgress'
				BEGIN
					SET @Message = 'Wave not Available - Manual Packing Started';
					ROLLBACK TRANSACTION;
					RETURN;
				END

				IF @CurrentStep = 'Packing' AND @StepSatus = 'Completed'
				BEGIN
					SET @Message = 'Wave not Available - Already packed';
					ROLLBACK TRANSACTION;
					RETURN;
				END

				IF @StepSatus <> 'Pending' OR @CurrentStep <> 'Packing'
				BEGIN
					SET @Message = 'Wave not Available';
					ROLLBACK TRANSACTION;
					RETURN;
				END
				
				IF EXISTS (
					SELECT 1
					FROM dbo.Waveline wl
					INNER JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
					WHERE wl.Deleted = 0
					AND wl.WaveID = @WaveID
					AND ISNULL(f.CarrierID, 0) = 2
				)
				BEGIN
					SET @Message = 'Wave not Available - Manual Shipment is not supported';
					ROLLBACK TRANSACTION;
					RETURN;
				END

				UPDATE dbo.Wave
				SET StepStatus = 'InProgress',
					FirstEditedDateTime = COALESCE(@OperationDateTime, FirstEditedDateTime),
					FirstEditedBy = COALESCE(@OperationBy, FirstEditedBy),
					LastEditedDateTime = COALESCE(@OperationDateTime, LastEditedDateTime),
					LastEditedBy = COALESCE(@OperationBy, LastEditedBy)
				WHERE WaveID = @WaveID
				AND Deleted = 0;

				SET @StepSatus = 'InProgress';


				-- Create temporary table to store results
				CREATE TABLE #PackingTaskResults (
					OrderNumber VARCHAR(50),
					ShipmentID INT,
					Carrier VARCHAR(50),
					IsLocal BIT,
					OrderSource VARCHAR(50),
					SourceOrderNumber VARCHAR(50),
					TenantName VARCHAR(100)
				);

				-- Declare cursor for order numbers
				DECLARE @OrderNumber VARCHAR(50);
				DECLARE @CarrierID INT,
						@ShipmentID INT,
						@CurrentShipmentID INT,
						@ShipmentType VARCHAR(20),
						@CarrierName VARCHAR(50),
						@ShipmentMessage VARCHAR(4000),
						@IsLocal BIT,
						@OrderSource VARCHAR(50),
						@SourceOrderNumber VARCHAR(50),
						@TenantName VARCHAR(100);

				DECLARE @BoxSize dbo.BoxSizeType;

				DECLARE OrderNumbers_Cursor CURSOR FOR
					SELECT OrderNumber FROM dbo.Waveline WHERE Deleted = 0 AND WaveID = @WaveID;

				OPEN OrderNumbers_Cursor;
				FETCH NEXT FROM OrderNumbers_Cursor INTO @OrderNumber;
				WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @Message = NULL;

					SET @CarrierID = NULL;
					SET @ShipmentID = NULL;
					SET @CurrentShipmentID = NULL;
					SET @ShipmentType = NULL;
					SET @CarrierName = NULL;
					SET @ShipmentMessage = NULL;
					SET @IsLocal = 0;
					SET @OrderSource = NULL;
					SET @SourceOrderNumber = NULL;
					SET @TenantName = NULL;

					SELECT TOP 1
						@CarrierID = ISNULL(f.CarrierID, 1),
						@CurrentShipmentID = wl.ShipmentID,
						@ShipmentType = wl.ShipmentType,
						@OrderSource = f.OrderSource,
						@SourceOrderNumber = f.order_number,
						@TenantName = t.TenantName
					FROM dbo.Waveline wl
					LEFT JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
					LEFT JOIN dbo.Tenant t ON t.TenantCode = f.TenantCode AND t.Deleted = 0
					WHERE wl.Deleted = 0 AND wl.WaveID = @WaveID AND wl.OrderNumber = @OrderNumber;

					IF @CarrierID IS NULL
					BEGIN
						SET @Message = 'Carrier is missing for order ' + ISNULL(@OrderNumber, '');
						ROLLBACK TRANSACTION;
						RETURN;
					END

					IF @CurrentShipmentID IS NOT NULL
					BEGIN
						SET @ShipmentID = @CurrentShipmentID;
						SET @IsLocal = CASE WHEN @ShipmentType = 'Local' THEN 1 ELSE 0 END;
					END
					ELSE
					BEGIN
						IF @CarrierID IN (1, 3)
						BEGIN
							DELETE FROM @BoxSize;
							INSERT INTO @BoxSize (Length, Height, Width)
							VALUES (100.00, 100.00, 100.00);
						END

						IF @CarrierID = 1 -- AP
						BEGIN
							EXEC [dbo].[SP_VI_TBL_APShipment_InsertAPShipment]
								@FulfilmentOrder = @OrderNumber,
								@BoxSize = @BoxSize,
								@CreatedDateTime = @OperationDateTime,
								@CreatedBy = @OperationBy,
								@WarehouseCode = NULL,
								@TenantCode = NULL,
								@NewShipmentID = @ShipmentID OUTPUT,
								@AccountNumber = NULL,
								@Token = NULL,
								@IsLocal = @IsLocal OUTPUT,
								@Message = @ShipmentMessage OUTPUT;

							IF @ShipmentMessage IS NOT NULL AND @ShipmentMessage <> ''
							BEGIN
								SET @Message = @ShipmentMessage;
								ROLLBACK TRANSACTION;
								RETURN;
							END

							SET @ShipmentType = CASE WHEN @IsLocal = 1 THEN 'Local' ELSE 'INT' END;
						END
						ELSE IF @CarrierID = 2 -- Manual
						BEGIN
							SET @ShipmentID = NULL;
							SET @ShipmentType = NULL;
						END
						ELSE IF @CarrierID = 3 -- DHL Express
						BEGIN
							EXEC [dbo].[SP_VI_TBL_DHLShipment_InsertDHLShipment]
								@FulfilmentOrder = @OrderNumber,
								@BoxSize = @BoxSize,
								@IsOneBox = 1,
								@PrinterDPI = 300,
								@CreatedDateTime = @OperationDateTime,
								@CreatedBy = @OperationBy,
								@WarehouseCode = NULL,
								@TenantCode = NULL,
								@AccountNumber = NULL,
								@Token = NULL,
								@NewShipmentID = @ShipmentID OUTPUT,
								@Message = @ShipmentMessage OUTPUT;

							IF @ShipmentMessage IS NOT NULL AND @ShipmentMessage <> ''
							BEGIN
								SET @Message = @ShipmentMessage;
								ROLLBACK TRANSACTION;
								RETURN;
							END

							SET @ShipmentType = 'INT';
							SET @IsLocal = 0;
						END
						ELSE IF @CarrierID = 4 -- CP
						BEGIN
							SET @ShipmentID = NULL;
							SET @ShipmentType = NULL;
						END

						UPDATE dbo.Waveline
						SET ShipmentID = @ShipmentID,
							ShipmentType = @ShipmentType,
							CarrierID = @CarrierID,
							FirstEditedDateTime = COALESCE(@OperationDateTime, FirstEditedDateTime),
							FirstEditedBy = COALESCE(@OperationBy, FirstEditedBy),
							LastEditedDateTime = COALESCE(@OperationDateTime, LastEditedDateTime),
							LastEditedBy = COALESCE(@OperationBy, LastEditedBy)
						WHERE OrderNumber = @OrderNumber AND Deleted = 0;
					END

					SET @CarrierName = CASE
						WHEN @CarrierID = 1 THEN 'AP'
						WHEN @CarrierID = 2 THEN 'Manual'
						WHEN @CarrierID = 3 THEN 'DHL Express'
						WHEN @CarrierID = 4 THEN 'CP'
						ELSE ''
					END;

					INSERT INTO #PackingTaskResults (OrderNumber, ShipmentID, Carrier, IsLocal, OrderSource, SourceOrderNumber, TenantName)
					VALUES (@OrderNumber, @ShipmentID, @CarrierName, @IsLocal, @OrderSource, @SourceOrderNumber, @TenantName);
					
					FETCH NEXT FROM OrderNumbers_Cursor INTO @OrderNumber;
				END

				CLOSE OrderNumbers_Cursor;
				DEALLOCATE OrderNumbers_Cursor;		
				
				-- Commit the transaction
				COMMIT TRANSACTION

				INSERT INTO dbo.CMCPackingWaveResult
				(
					WaveNumber,
					SourceOrderNumber,
					TenantCode,
					TenantName,
					PickingSlipNumber,
					ItemCodes,
					ItemBarcode,
					ItemSerialNo,
					QTY,
					LabelDataLen,
					LabelData,
					Status,
					MatchLab,
					ShipmentID,
					IsLocal,
					Carrier,
					OrderSource,
					Deleted,
					CreatedDateTime,
					CreatedBy,
					FirstEditedDateTime,
					FirstEditedBy,
					LastEditedDateTime,
					LastEditedBy
				)
				SELECT
					@WaveNumber AS WaveNumber,
					COALESCE(r.SourceOrderNumber, f.order_number, '') AS SourceOrderNumber,
					COALESCE(f.TenantCode, '') AS TenantCode,
					COALESCE(t.TenantName, r.TenantName, '') AS TenantName,
					COALESCE(c.PickingSlipNumber, '') AS PickingSlipNumber,
					COALESCE(flAgg.ItemCodes, '') AS ItemCodes,
					COALESCE(flAgg.ItemBarcode, '') AS ItemBarcode,
					COALESCE(ulAgg.ItemSerialNo, '') AS ItemSerialNo,
					COALESCE(flAgg.QTY, '0') AS QTY,
					COALESCE(lbl.LabelDataLen, 'ZPL-Length') AS LabelDataLen,
					COALESCE(lbl.LabelData, 'ZPL') AS LabelData,
					'Pending' AS Status,
					COALESCE(f.OrderNumber, '') AS MatchLab,
					r.ShipmentID AS ShipmentID,
					r.IsLocal AS IsLocal,
					r.Carrier AS Carrier,
					r.OrderSource AS OrderSource,
					0 AS Deleted,
					COALESCE(@OperationDateTime, GETDATE()) AS CreatedDateTime,
					@OperationBy AS CreatedBy,
					COALESCE(@OperationDateTime, GETDATE()) AS FirstEditedDateTime,
					@OperationBy AS FirstEditedBy,
					COALESCE(@OperationDateTime, GETDATE()) AS LastEditedDateTime,
					@OperationBy AS LastEditedBy
				FROM #PackingTaskResults r
				LEFT JOIN dbo.Fulfilment f ON f.OrderNumber = r.OrderNumber AND f.Deleted = 0
				LEFT JOIN dbo.Tenant t ON t.TenantCode = f.TenantCode AND t.Deleted = 0
				LEFT JOIN dbo.Connote c ON c.OrderNumber = COALESCE(r.SourceOrderNumber, f.order_number)
				OUTER APPLY (
					SELECT
						STRING_AGG(ISNULL(fl.line_items_sku, ''), '|') AS ItemCodes,
						STRING_AGG(ISNULL(itu.Barcode, ''), '|') AS ItemBarcode,
						CAST(SUM(ISNULL(fl.line_items_current_quantity, 0)) AS VARCHAR(50)) AS QTY
					FROM dbo.FulfilmentLine fl
					LEFT JOIN dbo.Items i ON i.ItemID = fl.ItemID AND i.Deleted = 0
					LEFT JOIN dbo.ItemTradeUnit itu ON itu.ItemID = i.ItemID AND itu.Deleted = 0 AND ISNULL(itu.PrimaryUnit, 0) = 1
					WHERE fl.Deleted = 0
					AND fl.FulfilmentID = f.FulfilmentID
				) flAgg
				OUTER APPLY (
					SELECT
						STRING_AGG(ul.SerialNumber, '|') AS ItemSerialNo
					FROM dbo.ULDLine ul
					WHERE ul.Deleted = 0
					AND ul.TransactionType = 'Picked'
					AND ul.AllocatedType = 'Orders'
					AND ul.TransactionReference = COALESCE(r.SourceOrderNumber, f.order_number)
					AND ISNULL(ul.SerialNumber, '') <> ''
				) ulAgg
				OUTER APPLY (
					SELECT TOP 1
						CAST(LEN(ISNULL(m.ZplFileLocation, '')) AS VARCHAR(50)) AS LabelDataLen,
						ISNULL(m.ZplFileLocation, '') AS LabelData
					FROM dbo.ULDLabelFileMapping m
					WHERE m.Deleted = 0
					AND EXISTS (
							SELECT 1
							FROM dbo.ULDLine ul2
							INNER JOIN dbo.ULD u ON u.ULDID = ul2.ULDID AND u.Deleted = 0
							WHERE ul2.Deleted = 0
							AND ul2.TransactionType = 'Picked'
							AND ul2.AllocatedType = 'Orders'
							AND ul2.TransactionReference = COALESCE(r.SourceOrderNumber, f.order_number)
							AND u.ULDBarcode = m.ULDBarcode
					)
					ORDER BY m.ULDLabelFileMappingID DESC
				) lbl;

				--Update wave manul packing to 0
				UPDATE dbo.Wave
				SET ManualPacking = 0,
					FirstEditedDateTime = COALESCE(@OperationDateTime, FirstEditedDateTime),
					FirstEditedBy = COALESCE(@OperationBy, FirstEditedBy),
					LastEditedDateTime = COALESCE(@OperationDateTime, LastEditedDateTime),
					LastEditedBy = COALESCE(@OperationBy, LastEditedBy)
				WHERE WaveID = @WaveID AND Deleted = 0;
			
		END -- End first call
		
		-- return results
		SELECT MatchLab as FulfilmentNumber
		FROM dbo.CMCPackingWaveResult
		WHERE WaveNumber = @WaveNumber AND Deleted = 0;		

		SET @Message = 'OK';
			
		
    END TRY
    BEGIN CATCH

		 -- Handle the error
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        DECLARE @ErrorMessage NVARCHAR(4000)
        DECLARE @ErrorSeverity INT
        DECLARE @ErrorState INT

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE()

        -- Rethrow the error
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
    END CATCH;
END
GO
