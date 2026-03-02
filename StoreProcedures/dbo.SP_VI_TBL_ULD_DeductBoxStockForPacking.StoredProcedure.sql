USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_ULD_DeductBoxStockForPacking]    Script Date: 3/2/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Nam Nguyen>
-- Create date: <02 Mar, 2026>
-- Description:	<Deduct box stock for packing result>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_ULD_DeductBoxStockForPacking]
	@WarehouseCode VARCHAR(20),
	@TenantCode VARCHAR(10),
	@OrderNumber VARCHAR(50),
	@CompletedDateTime DATETIME = NULL,
	@OperationBy VARCHAR(100) = NULL,
	@Results dbo.OrderPackingResultType READONLY,
	@Message VARCHAR(4000) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SET @Message = NULL;

		CREATE TABLE #TmpBoxCount
		(
			ItemBoxID INT NULL,
			BoxNumberCount INT NOT NULL
		);

		INSERT INTO #TmpBoxCount (ItemBoxID, BoxNumberCount)
		SELECT
			StandardBoxID,
			COUNT(BoxNumber) AS BoxNumberCount
		FROM @Results
		GROUP BY StandardBoxID;

		CREATE TABLE #TmpBoxULDStock
		(
			RowID INT IDENTITY(1,1) NOT NULL,
			ULDID INT NOT NULL,
			ULDBarcode VARCHAR(30) NOT NULL,
			ULDCurrentLocation VARCHAR(50) NULL,
			LocationOrderNumber VARCHAR(200) NULL,
			LocColumnID INT NULL,
			LocShelfID INT NULL,
			LocBinID INT NULL,
			LocSBinID INT NULL,
			ULDType VARCHAR(30) NULL,
			TenantCode VARCHAR(10) NULL,
			WarehouseCode VARCHAR(20) NULL,
			HoldStatus VARCHAR(20) NULL,
			CurrentZone VARCHAR(20) NULL,
			Status VARCHAR(20) NULL,
			ItemNumber VARCHAR(30) NULL,
			ItemName VARCHAR(250) NULL,
			ExpiryDate DATETIME NULL,
			BatchNumber VARCHAR(30) NULL,
			CreatedDateTime DATETIME NULL,
			TotalQty INT NULL
		);

		DECLARE @ItemBoxID INT;
		DECLARE @ItemBoxNumber VARCHAR(50);
		DECLARE @ItemBoxName VARCHAR(250);
		DECLARE @ItemPickingCondition VARCHAR(100);
		DECLARE @BoxNumberCount INT;
		DECLARE @IsEmpty BIT;
		DECLARE @CurrentBoxULDID INT;
		DECLARE @CurrentBoxULDLocation VARCHAR(50);
		DECLARE @CurrentBoxULDQty INT;
		DECLARE @DeductQty INT;
		DECLARE @RemainingDeductQty INT;
		DECLARE @BoxSequenceNumber INT;
		DECLARE @BoxTransactionMovement VARCHAR(1000);

		DECLARE cur_TmpBoxCount CURSOR LOCAL FAST_FORWARD FOR
		SELECT ItemBoxID, BoxNumberCount
		FROM #TmpBoxCount;

		OPEN cur_TmpBoxCount;
		FETCH NEXT FROM cur_TmpBoxCount INTO @ItemBoxID, @BoxNumberCount;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @ItemBoxNumber = i.ItemNumber,
				   @ItemBoxName = i.ItemName,
				   @ItemPickingCondition = i.PickingCondition
			FROM dbo.Items i
			JOIN dbo.ItemTradeUnit itu ON itu.ItemID = i.ItemID AND itu.Deleted = 0
			WHERE itu.ItemTradeUnitID = @ItemBoxID
			  AND i.TenantCode = @TenantCode
			  AND i.Deleted = 0;

			IF @ItemBoxNumber IS NULL
			BEGIN
				SET @Message = 'Can not find box item by ItemTradeUnitID.';
				CLOSE cur_TmpBoxCount;
				DEALLOCATE cur_TmpBoxCount;
				RETURN;
			END

			SET @IsEmpty = 0;
			EXEC [dbo].[SP_VI_TBL_ULD_CheckHavingStockOfTenantAtWarehouse]
				@WarehouseCode = @WarehouseCode,
				@TenantCode = @TenantCode,
				@ItemNumber = @ItemBoxNumber,
				@IsEmpty = @IsEmpty OUTPUT;

			IF @IsEmpty = 1
			BEGIN
				SET @Message = 'No stock of box item at this Warehouse.';
				CLOSE cur_TmpBoxCount;
				DEALLOCATE cur_TmpBoxCount;
				RETURN;
			END

			SET @RemainingDeductQty = @BoxNumberCount;

			WHILE @RemainingDeductQty > 0
			BEGIN
				DELETE FROM #TmpBoxULDStock;

				INSERT INTO #TmpBoxULDStock (
					ULDID,
					ULDBarcode,
					ULDCurrentLocation,
					LocationOrderNumber,
					LocColumnID,
					LocShelfID,
					LocBinID,
					LocSBinID,
					ULDType,
					TenantCode,
					WarehouseCode,
					HoldStatus,
					CurrentZone,
					Status,
					ItemNumber,
					ItemName,
					ExpiryDate,
					BatchNumber,
					CreatedDateTime,
					TotalQty
				)
				EXEC [dbo].[SP_VI_TBL_ULD_GetULDsHavingStockOfTenantAtWarehouse]
					@TenantCode = @TenantCode,
					@WarehouseCode = @WarehouseCode,
					@ItemNumber = @ItemBoxNumber,
					@PickingCondition = @ItemPickingCondition,
					@CountOnHold = 0;

				SELECT TOP 1
					@CurrentBoxULDID = ULDID,
					@CurrentBoxULDLocation = ULDCurrentLocation,
					@CurrentBoxULDQty = TotalQty
				FROM #TmpBoxULDStock
				WHERE ISNULL(TotalQty, 0) > 0
				ORDER BY RowID ASC;

				IF @CurrentBoxULDID IS NULL OR ISNULL(@CurrentBoxULDQty, 0) <= 0
				BEGIN
					SET @Message = 'Not enough box stock for packing.';
					CLOSE cur_TmpBoxCount;
					DEALLOCATE cur_TmpBoxCount;
					RETURN;
				END

				SET @DeductQty = CASE
					WHEN @RemainingDeductQty > @CurrentBoxULDQty THEN @CurrentBoxULDQty
					ELSE @RemainingDeductQty
				END;

				SELECT @BoxSequenceNumber = COUNT(*)
				FROM dbo.ULDLine
				WHERE ULDID = @CurrentBoxULDID AND Deleted = 0;

				SET @BoxSequenceNumber = @BoxSequenceNumber + 1;
				SET @BoxTransactionMovement = 'Deduct ' + CAST(@DeductQty AS VARCHAR(10)) + 'x ' + @ItemBoxNumber + ' for packing order ' + @OrderNumber;

				INSERT INTO [dbo].[ULDLine] (
					ULDID,
					SequenceNumber,
					SerialNumber,
					TransactionDate,
					TransactionUser,
					TransactionType,
					TransactionQty,
					TransactionReference,
					TransactionMovement,
					TransactionLocation,
					ItemNumber,
					ItemName,
					Deleted,
					CreatedDateTime,
					CreatedBy
				)
				VALUES (
					@CurrentBoxULDID,
					@BoxSequenceNumber,
					NULL,
					COALESCE(@CompletedDateTime, GETDATE()),
					@OperationBy,
					'Picked',
					-@DeductQty,
					@OrderNumber,
					@BoxTransactionMovement,
					@CurrentBoxULDLocation,
					@ItemBoxNumber,
					@ItemBoxName,
					0,
					COALESCE(@CompletedDateTime, GETDATE()),
					@OperationBy
				);

				EXEC dbo.SP_VI_TBL_ULDLIne_ResetULDLineSequence
					@ULDID = @CurrentBoxULDID;

				SET @RemainingDeductQty = @RemainingDeductQty - @DeductQty;
				SET @CurrentBoxULDID = NULL;
				SET @CurrentBoxULDLocation = NULL;
				SET @CurrentBoxULDQty = NULL;
			END

			FETCH NEXT FROM cur_TmpBoxCount INTO @ItemBoxID, @BoxNumberCount;
		END

		CLOSE cur_TmpBoxCount;
		DEALLOCATE cur_TmpBoxCount;

	END TRY
	BEGIN CATCH
		SET @Message = ERROR_MESSAGE();

		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;

		SELECT
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();

		RAISERROR(@Message, @ErrorSeverity, @ErrorState);
	END CATCH;
END
GO
