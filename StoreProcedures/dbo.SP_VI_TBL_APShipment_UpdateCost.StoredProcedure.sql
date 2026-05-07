USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_APShipment_UpdateCost]    Script Date: 5/5/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:         <Nam Nguyen>
-- Create date: <05 May, 2026>
-- Description: <Update AP Shipment costs and AP Shipment item costs>
-- =============================================
ALTER PROCEDURE [dbo].[SP_VI_TBL_APShipment_UpdateCost]
	@ShipmentType VARCHAR(20) = 'Local',
	@AP_shipment_id NVARCHAR(150),
	@AP_total_cost DECIMAL(6, 2) = NULL,
	@AP_total_cost_ex_gst DECIMAL(6, 2) = NULL,
	@AP_shipping_cost DECIMAL(6, 2) = NULL,
	@AP_fuel_surcharge DECIMAL(4, 2) = NULL,
	@AP_total_gst DECIMAL(5, 2) = NULL,
	@APItemCosts dbo.APItemCost READONLY,
	@OperationBy VARCHAR(100) = NULL,
	@OperationDateTime DATETIME = NULL,
	@Message VARCHAR(4000) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @StartedTran BIT = 0;
	DECLARE @UpdatedShipmentRows INT = 0;
	DECLARE @UpdatedItemRows INT = 0;

	SET @ShipmentType = ISNULL(NULLIF(LTRIM(RTRIM(@ShipmentType)), ''), 'Local');

	IF UPPER(@ShipmentType) <> 'LOCAL'
	BEGIN
		SET @Message = 'ShipmentType ''' + @ShipmentType + ''' is not supported yet. Only ''Local'' is currently supported.';
		RETURN;
	END

	BEGIN TRY
		IF @@TRANCOUNT = 0
		BEGIN
			SET @StartedTran = 1;
			BEGIN TRANSACTION;
		END

		IF NOT EXISTS
		(
			SELECT 1
			FROM dbo.AP_Shipment s
			WHERE s.AP_shipment_id = @AP_shipment_id
				AND s.Deleted = 0
		)
		BEGIN
			SET @Message = 'No Local AP shipment found for AP_shipment_id = ' + ISNULL(@AP_shipment_id, 'NULL');

			IF @StartedTran = 1
				ROLLBACK TRANSACTION;

			RETURN;
		END

		UPDATE s
		SET
			s.AP_total_cost = @AP_total_cost,
			s.AP_total_cost_ex_gst = @AP_total_cost_ex_gst,
			s.AP_shipping_cost = @AP_shipping_cost,
			s.AP_fuel_surcharge = @AP_fuel_surcharge,
			s.AP_total_gst = @AP_total_gst,
			s.FirstEditedDateTime = COALESCE(s.FirstEditedDateTime, @OperationDateTime),
			s.FirstEditedBy = COALESCE(s.FirstEditedBy, @OperationBy),
			s.LastEditedDateTime = COALESCE(@OperationDateTime, s.LastEditedDateTime),
			s.LastEditedBy = COALESCE(@OperationBy, s.LastEditedBy)
		FROM dbo.AP_Shipment s
		WHERE s.AP_shipment_id = @AP_shipment_id
			AND s.Deleted = 0;

		SET @UpdatedShipmentRows = @@ROWCOUNT;

		;WITH ItemCosts AS
		(
			SELECT
				c.AP_item_id,
				MAX(c.AP_total_cost) AS AP_total_cost,
				MAX(c.AP_total_cost_ex_gst) AS AP_total_cost_ex_gst,
				MAX(c.AP_total_gst) AS AP_total_gst
			FROM @APItemCosts c
			WHERE c.AP_item_id IS NOT NULL
			GROUP BY c.AP_item_id
		)
		UPDATE si
		SET
			si.AP_total_cost = ic.AP_total_cost,
			si.AP_total_cost_ex_gst = ic.AP_total_cost_ex_gst,
			si.AP_total_gst = ic.AP_total_gst,
			si.FirstEditedDateTime = COALESCE(si.FirstEditedDateTime, @OperationDateTime),
			si.FirstEditedBy = COALESCE(si.FirstEditedBy, @OperationBy),
			si.LastEditedDateTime = COALESCE(@OperationDateTime, si.LastEditedDateTime),
			si.LastEditedBy = COALESCE(@OperationBy, si.LastEditedBy)
		FROM dbo.AP_ShipmentItems si
		INNER JOIN dbo.AP_Shipment s
			ON s.ShipmentID = si.ShipmentID
			AND s.AP_shipment_id = @AP_shipment_id
			AND s.Deleted = 0
		INNER JOIN ItemCosts ic
			ON ic.AP_item_id = si.AP_item_id
		WHERE si.Deleted = 0;

		SET @UpdatedItemRows = @@ROWCOUNT;

		IF @StartedTran = 1
			COMMIT TRANSACTION;

		SET @Message = '';
			
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 AND @StartedTran = 1
			ROLLBACK TRANSACTION;

		DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;

		SELECT
			@ErrorMessage = ERROR_MESSAGE(),
			@ErrorSeverity = ERROR_SEVERITY(),
			@ErrorState = ERROR_STATE();

		SET @Message = @ErrorMessage;
		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
	END CATCH;
END
GO
