USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_CMCPackingWaveResult_GetPendingItemByWaveNumber]    Script Date: 3/17/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Nam nguyen>
-- Create date: <17 Mar, 2026>
-- Description:	<Get one pending CMC packing row by wave number and mark it InProgress>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_CMCPackingWaveResult_GetPendingItemByWaveNumber]
	@WaveNumber VARCHAR(11),
	@FulfillmentNumbers dbo.StringArray READONLY,
	@OperationDateTime DATETIME = NULL,
	@OperationBy VARCHAR(100) = NULL,
	@Message VARCHAR(4000) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		DECLARE @Picked TABLE
		(
			CMCPackingWaveResultID INT,
			WaveNumber VARCHAR(11),
			SourceOrderNumber VARCHAR(50),
			TenantCode VARCHAR(50),
			TenantName VARCHAR(100),
			PickingSlipNumber VARCHAR(100),
			ItemCodes VARCHAR(MAX),
			ItemBarcode VARCHAR(MAX),
			ItemSerialNo VARCHAR(MAX),
			QTY VARCHAR(50),
			LabelDataLen VARCHAR(50),
			LabelData VARCHAR(MAX),
			Status VARCHAR(20),
			MatchLab VARCHAR(50),
			ShipmentID INT,
			IsLocal BIT,
			Carrier VARCHAR(100),
			PrinterResolution VARCHAR(50),
			OrderSource VARCHAR(50),
			Deleted BIT,
			CreatedDateTime DATETIME,
			CreatedBy VARCHAR(100),
			FirstEditedDateTime DATETIME,
			FirstEditedBy VARCHAR(100),
			LastEditedDateTime DATETIME,
			LastEditedBy VARCHAR(100)
		);

		;WITH MatchedRows AS
		(
			SELECT c.*
			FROM dbo.CMCPackingWaveResult c WITH (ROWLOCK, READPAST, UPDLOCK)
			WHERE c.Deleted = 0
			  AND c.WaveNumber = @WaveNumber
			  AND EXISTS
			  (
				SELECT 1
				FROM @FulfillmentNumbers w
				WHERE w.[Value] IS NOT NULL
				  AND w.[Value] = c.MatchLab
			  )
		)
		UPDATE MatchedRows
		SET Status = CASE WHEN Status = 'Pending' THEN 'InProgress' ELSE Status END,
			FirstEditedDateTime = CASE
				WHEN Status = 'Pending' THEN COALESCE(@OperationDateTime, FirstEditedDateTime)
				ELSE FirstEditedDateTime
			END,
			FirstEditedBy = CASE
				WHEN Status = 'Pending' THEN COALESCE(@OperationBy, FirstEditedBy)
				ELSE FirstEditedBy
			END,
			LastEditedDateTime = CASE
				WHEN Status = 'Pending' THEN COALESCE(@OperationDateTime, GETDATE())
				ELSE LastEditedDateTime
			END,
			LastEditedBy = CASE
				WHEN Status = 'Pending' THEN COALESCE(@OperationBy, LastEditedBy)
				ELSE LastEditedBy
			END
		OUTPUT
			inserted.CMCPackingWaveResultID,
			inserted.WaveNumber,
			inserted.SourceOrderNumber,
			inserted.TenantCode,
			inserted.TenantName,
			inserted.PickingSlipNumber,
			inserted.ItemCodes,
			inserted.ItemBarcode,
			inserted.ItemSerialNo,
			inserted.QTY,
			inserted.LabelDataLen,
			inserted.LabelData,
			inserted.Status,
			inserted.MatchLab,
			inserted.ShipmentID,
			inserted.IsLocal,
			inserted.Carrier,
			'300' as PrinterResolution,
			inserted.OrderSource,
			inserted.Deleted,
			inserted.CreatedDateTime,
			inserted.CreatedBy,
			inserted.FirstEditedDateTime,
			inserted.FirstEditedBy,
			inserted.LastEditedDateTime,
			inserted.LastEditedBy
		INTO @Picked;

		IF NOT EXISTS (SELECT 1 FROM @Picked)
		BEGIN
			SET @Message = 'No item found for the supplied fulfillment numbers.';
			COMMIT TRANSACTION;
			RETURN;
		END

		SET @Message = 'OK';
		COMMIT TRANSACTION;

		SELECT * FROM @Picked;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
		END

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
