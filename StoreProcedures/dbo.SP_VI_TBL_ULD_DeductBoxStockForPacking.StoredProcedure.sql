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
			BoxNumberCount INT NOT NULL,
			ULDID INT NULL
		);

		INSERT INTO #TmpBoxCount (ItemBoxID, ULDID, BoxNumberCount)
		SELECT
			r.StandardBoxID,
			u.ULDID,
			COUNT(r.BoxNumber) AS BoxNumberCount
		FROM @Results r
		LEFT JOIN dbo.ULD u ON u.ULDBarcode = r.ULDBarcode AND u.Deleted = 0		
		GROUP BY r.StandardBoxID, u.ULDID;

		DECLARE @ItemBoxID INT;
		DECLARE @ItemBoxNumber VARCHAR(50);
		DECLARE @ItemBoxName VARCHAR(250);
		DECLARE @BoxNumberCount INT;
		DECLARE @TargetBoxULDID INT;
		DECLARE @CurrentBoxULDLocation VARCHAR(50);
		DECLARE @CurrentBoxULDQty INT;
		DECLARE @DeductQty INT;
		DECLARE @BoxSequenceNumber INT;
		DECLARE @BoxTransactionMovement VARCHAR(1000);

		DECLARE cur_TmpBoxCount CURSOR LOCAL FAST_FORWARD FOR
		SELECT ItemBoxID, ULDID, BoxNumberCount
		FROM #TmpBoxCount;

		OPEN cur_TmpBoxCount;
		FETCH NEXT FROM cur_TmpBoxCount INTO @ItemBoxID, @TargetBoxULDID, @BoxNumberCount;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @ItemBoxNumber = i.ItemNumber,
				   @ItemBoxName = i.ItemName
			FROM dbo.Items i
			JOIN dbo.ItemTradeUnit itu ON itu.ItemID = i.ItemID AND itu.Deleted = 0
			WHERE itu.ItemTradeUnitID = @ItemBoxID
			  AND i.TenantCode = @TenantCode
			  AND i.Deleted = 0;

			IF @ItemBoxNumber IS NULL
			BEGIN
				SET @Message = 'Can not find box item.';
				CLOSE cur_TmpBoxCount;
				DEALLOCATE cur_TmpBoxCount;
				RETURN;
			END

			SELECT
				@CurrentBoxULDLocation = l.ULDCurrentLocation,
				@CurrentBoxULDQty = SUM(ul.TransactionQty)
			FROM dbo.ULD l
			INNER JOIN dbo.ULDLine ul ON ul.ULDID = l.ULDID AND ul.Deleted = 0
			WHERE l.ULDID = @TargetBoxULDID
			  AND l.Deleted = 0
			  AND l.ULDCurrentLocation IS NOT NULL
			  AND l.WarehouseCode = @WarehouseCode
			  AND l.TenantCode = @TenantCode
			  AND l.ItemNumber = @ItemBoxNumber
			  AND l.Status NOT IN ('Draft','InActive','Locked')
			  AND l.HoldStatus IS NULL
			GROUP BY l.ULDCurrentLocation
			HAVING SUM(ul.TransactionQty) > 0;

			IF @TargetBoxULDID IS NULL OR ISNULL(@CurrentBoxULDQty, 0) <= 0 OR @CurrentBoxULDQty < @BoxNumberCount
			BEGIN
				SET @Message = 'Not enough box stock for packing.';
				CLOSE cur_TmpBoxCount;
				DEALLOCATE cur_TmpBoxCount;
				RETURN;
			END

			SET @DeductQty = @BoxNumberCount;

			SELECT @BoxSequenceNumber = COUNT(*)
			FROM dbo.ULDLine
			WHERE ULDID = @TargetBoxULDID AND Deleted = 0;

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
				@TargetBoxULDID,
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
				@ULDID = @TargetBoxULDID;

			SET @CurrentBoxULDLocation = NULL;
			SET @CurrentBoxULDQty = NULL;

			FETCH NEXT FROM cur_TmpBoxCount INTO @ItemBoxID, @TargetBoxULDID, @BoxNumberCount;
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
