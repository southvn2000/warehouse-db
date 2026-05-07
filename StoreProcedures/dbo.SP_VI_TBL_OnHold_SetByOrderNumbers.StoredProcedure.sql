USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_OnHold_SetByOrderNumbers]    Script Date: 4/16/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Nam Nguyen>
-- Create date: <16 Apr, 2026>
-- Description: <Set OnHold for Order/Fulfilment by array and write audit log>
-- =============================================
ALTER PROCEDURE [dbo].[SP_VI_TBL_OnHold_SetByOrderNumbers]
    @OrderType VARCHAR(20), -- Order | Fulfilment
	@Reason VARCHAR(5000) = NULL,
    @OrderNumbers dbo.OrderType READONLY,
	@OrderItems dbo.OrderLineType READONLY,
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
                O.OnHold = 1,
                O.FulfilmentStatus = 'OnHold',
                O.FulfilmentStatusDateTime = @ActionDateTime,
                O.FirstEditedDateTime = COALESCE(O.FirstEditedDateTime, @ActionDateTime),
                O.FirstEditedBy = COALESCE(O.FirstEditedBy, @ActionBy),
                O.LastEditedDateTime = @ActionDateTime,
                O.LastEditedBy = @ActionBy
            OUTPUT inserted.order_number INTO @Updated(OrderNumber)
            FROM dbo.Orders O
            INNER JOIN @OrderNumbers N ON N.OrderNumber = O.order_number
            WHERE ISNULL(O.Deleted, 0) = 0
              AND ISNULL(O.OnHold, 0) = 0
              AND LOWER(ISNULL(N.OrderSource, '')) = 'manual';


            -- fulfilment

            DECLARE @Phone				  VARCHAR(70),
                @ContactEmail             VARCHAR(200),
                @ShippingAddressName      VARCHAR(100),
                @ShippingAddressCompany   VARCHAR(300),
                @ShippingAddressAddress1  VARCHAR(300),
                @ShippingAddressAddress2  VARCHAR(300),
                @ShippingAddressCity      VARCHAR(150),
                @ShippingAddressProvince  VARCHAR(150),
                @ShippingAddressZip       VARCHAR(20),
                @ShippingAddressCountry   VARCHAR(50);

            DECLARE @TenantContactEmail VARCHAR(100),
					@TenantContactMobile VARCHAR(70),
					@OrderSource VARCHAR(50),					
					@Carrier VARCHAR(500),
					@CurrentOrderNumber VARCHAR(50),
			        @TenantCode VARCHAR(10),
					@WarehouseCode VARCHAR(10),
					@WarehouseName VARCHAR(200),
                    @FulfilmentOrder VARCHAR(21),
                    @FulfilmentID INT,
                    @CarrierID INT,
                    @NewFulfilmentID INT,
					@FulfilmentOrderID INT;


            DECLARE OrderNumbersCursor CURSOR FOR
			SELECT  OrderNumber, TenantCode, WarehouseCode, OrderSource, Carrier, Phone, Email, CarrierID, 
					ShippingAddressName,
					ShippingAddressCompany,
					ShippingAddressAddress1,
					ShippingAddressAddress2,
					ShippingAddressCity,
					ShippingAddressProvince,
					ShippingAddressZip,
					ShippingAddressCountry
			FROM @OrderNumbers
            WHERE OrderSource = 'shopify';

			OPEN OrderNumbersCursor;

			FETCH NEXT FROM OrderNumbersCursor 
			INTO @CurrentOrderNumber, @TenantCode, @WarehouseCode, @OrderSource, @Carrier, @Phone, @ContactEmail, @CarrierID,
						@ShippingAddressName, @ShippingAddressCompany, @ShippingAddressAddress1, @ShippingAddressAddress2, 
						@ShippingAddressCity, @ShippingAddressProvince, @ShippingAddressZip, @ShippingAddressCountry;
            
            WHILE @@FETCH_STATUS = 0
			BEGIN

				SELECT @WarehouseName = WarehouseName
				FROM LocWarehouse
				WHERE WarehouseCode = @WarehouseCode AND DELETED = 0;

				-- Get next sequence value
				SET @FulfilmentOrderID = NEXT VALUE FOR dbo.FulfilmentNumberSequence;

				-- Format it with leading zeroes (21 digits)
				SET @FulfilmentOrder = CAST(@FulfilmentOrderID AS VARCHAR(21));  --RIGHT('000000000000000000000' + CAST(@FulfilmentOrderID AS varchar), 21);

				SELECT @TenantContactEmail = TenantContactEmail
					   --@TenantContactMobile = TenantContactMobile
				FROM dbo.Tenant
				WHERE TenantCode = @TenantCode AND Deleted = 0;
				
				-- delete previous failure
				SELECT @FulfilmentID = FulfilmentID
				FROM dbo.Fulfilment
				WHERE Deleted = 1 AND order_number = @CurrentOrderNumber AND FulfilmentStatus = 'Fulfilment';
				
				DELETE FROM dbo.FulfilmentLine
				WHERE Deleted = 1 AND FulfilmentID = @FulfilmentID;

				DELETE FROM dbo.Fulfilment
				WHERE Deleted = 1 AND FulfilmentID = @FulfilmentID;

				IF @OrderSource = 'shopify'
				BEGIN
					SET @TenantContactMobile = @Phone;
					SET @TenantContactEmail = @ContactEmail;
				END

				INSERT INTO dbo.Fulfilment
				   (
						OrderNumber
					   ,OrderSource
					   ,Carrier
					   ,order_number
					   ,shipping_address_name
					   ,shipping_address_company
					   ,shipping_address_address1
					   ,shipping_address_address2
					   ,shipping_address_city
					   ,shipping_address_province
					   ,shipping_address_zip
					   ,shipping_address_country					   
					   ,contact_email
					   ,Phone
					   ,CreatedBy
					   ,CreatedDateTime
					   ,Deleted
					   ,FulfilmentType
					   ,FulfilmentStatus
					   ,WarehouseCode
					   ,WarehouseName
					   ,TenantCode
					   ,CarrierID
				   )
				VALUES
					( 
						@FulfilmentOrder,
						@OrderSource,
						@Carrier,
						@CurrentOrderNumber, 
						@ShippingAddressName, 
						@ShippingAddressCompany, 
						@ShippingAddressAddress1, 
						@ShippingAddressAddress2, 
						@ShippingAddressCity, 
						@ShippingAddressProvince, 
						@ShippingAddressZip, 
						@ShippingAddressCountry,
						@TenantContactEmail,
					    @TenantContactMobile,
						@ActionBy, 
						@ActionDateTime, 
						1, 
						'Orders', 
						'OnHold', 
						@WarehouseCode, 
						@WarehouseName,
						@TenantCode,
						@CarrierID
					);

				-- set new ID
				SET @NewFulfilmentID = SCOPE_IDENTITY();

				-- insert line
				INSERT INTO dbo.FulfilmentLine
				   (
					   FulfilmentID
					   ,line_items_name
					   ,line_items_sku
					   ,line_items_current_quantity
					   ,TenantCode
					   ,ItemID
					   ,Deleted
					   ,CreatedBy
					   ,CreatedDateTime
				   )
				SELECT 
					@NewFulfilmentID, 
					oi.OrderItemName,
					oi.OrderItemNumber,
					oi.OrderQuantity,
					@TenantCode,
					i.ItemID,  -- get ItemID from Items table
					1,
					@ActionBy,
					@ActionDateTime
				FROM @OrderItems oi
				INNER JOIN Items i
					ON i.ItemNumber = oi.OrderItemNumber
					AND i.TenantCode = @TenantCode
				WHERE oi.OrderNumber = @CurrentOrderNumber AND i.Deleted = 0;

                FETCH NEXT FROM OrderNumbersCursor 
					INTO @CurrentOrderNumber, @TenantCode, @WarehouseCode, @OrderSource, @Carrier, @Phone, @ContactEmail, @CarrierID,
					     @ShippingAddressName, @ShippingAddressCompany, @ShippingAddressAddress1, @ShippingAddressAddress2, 
						 @ShippingAddressCity, @ShippingAddressProvince, @ShippingAddressZip, @ShippingAddressCountry;
			END

			CLOSE OrderNumbersCursor;
			DEALLOCATE OrderNumbersCursor;

            INSERT INTO dbo.OnHoldOrderLog
                ([OrderNumber], [OrderType], [LogType], [LogDate], [LogBy], [CreatedBy], [CreatedDateTime], [FirstEditedBy], [FirstEditedDateTime], [LastEditedBy], [LastEditedDateTime], [Reason],[Deleted])
            SELECT
                U.OrderNumber,
                'Order',
                'Hold',
                @ActionDateTime,
                @ActionBy,
                @ActionBy,
                @ActionDateTime,
                @ActionBy,
                @ActionDateTime,
                @ActionBy,
                @ActionDateTime,
                @Reason,
                0
            FROM @Updated U;
        END
        ELSE
        BEGIN
            UPDATE F
            SET
                F.OnHold = 1,
				F.FulfilmentStatus = 'OnHold',
                F.FirstEditedDateTime = COALESCE(F.FirstEditedDateTime, @ActionDateTime),
                F.FirstEditedBy = COALESCE(F.FirstEditedBy, @ActionBy),
                F.LastEditedDateTime = @ActionDateTime,
                F.LastEditedBy = @ActionBy
            OUTPUT inserted.OrderNumber INTO @Updated(OrderNumber)
            FROM dbo.Fulfilment F
			LEFT JOIN 
			( 
				SELECT l.OrderNumber, w.WaveNumber, w.WaveStatus , w.StepStatus
				FROM WaveLine l 
				LEFT JOIN Wave w ON w.WaveID = l.WaveID 
				WHERE l.Deleted = 0
				AND w.Deleted = 0           
			) w 
			ON w.OrderNumber = f.OrderNumber
            INNER JOIN @OrderNumbers N ON N.OrderNumber = F.OrderNumber
            WHERE ISNULL(F.Deleted, 0) = 0
              AND ISNULL(F.OnHold, 0) = 0
			  AND w.StepStatus NOT IN ('Started', 'Completed');    

            INSERT INTO dbo.OnHoldOrderLog
                ([OrderNumber], [OrderType], [LogType], [LogDate], [LogBy], [CreatedBy], [CreatedDateTime], [FirstEditedBy], [FirstEditedDateTime], [LastEditedBy], [LastEditedDateTime], [Reason], [Deleted])
            SELECT
                U.OrderNumber,
                'Fulfilment',
                'Hold',
                @ActionDateTime,
                @ActionBy,
                @ActionBy,
                @ActionDateTime,
                @ActionBy,
                @ActionDateTime,
                @ActionBy,
                @ActionDateTime,
                @Reason,
                0
            FROM @Updated U;
        END

        SET @Message = CAST((SELECT COUNT(1) FROM @Updated) AS VARCHAR(20)) + ' ' + @OrderType + ' record(s) set to OnHold.';

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
