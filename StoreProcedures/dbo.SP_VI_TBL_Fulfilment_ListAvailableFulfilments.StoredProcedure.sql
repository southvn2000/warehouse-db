USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Fulfilment_ListAvailableFulfilments]    Script Date: 3/2/2026 10:38:03 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Nam nguyen>
-- Create date: <27 Jun, 2025>
-- Description:	<List Fulfilment Orders By Status>
-- =============================================
ALTER PROCEDURE [dbo].[SP_VI_TBL_Fulfilment_ListAvailableFulfilments]    
	 @WarehouseCode  VARCHAR(20) = NULL, 
     @TenantCode VARCHAR(20) = NULL,
	 @Search NVARCHAR(100) = NULL,
	 @PageNumber INT = 1,
	 @PageSize INT = 10,
	 @OrderBy NVARCHAR(50) = 'FulfilmentID',
	 @OrderDir NVARCHAR(4) = 'ASC', -- 'ASC' or 'DESC'
	 @TotalRecords INT OUTPUT,
     @TotalPages INT OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    DECLARE @SQL NVARCHAR(MAX);	
    DECLARE @SQLParams NVARCHAR(MAX) = N'@FulfilmentType NVARCHAR(20), @WarehouseCode VARCHAR(20), @TenantCode VARCHAR(20), @Search NVARCHAR(100), @Offset INT, @PageSize INT';
     
	DECLARE @FulfilmentType NVARCHAR(20) = 'Orders';
	
    IF @Search IS NULL OR LEN(@Search) = 0
    BEGIN
        -- Get the total number of records
        SELECT @TotalRecords = COUNT(*) 
        FROM dbo.Fulfilment f
        LEFT JOIN 
        ( 
            SELECT l.OrderNumber, w.WaveNumber, w.WaveStatus , w.StepStatus
            FROM WaveLine l 
            LEFT JOIN Wave w ON w.WaveID = l.WaveID 
            WHERE l.Deleted = 0
            AND w.Deleted = 0           
        ) w 
        ON w.OrderNumber = f.OrderNumber
        WHERE f.FulfilmentStatus IN ('Fulfilment', 'Started') 
                AND w.StepStatus NOT IN ('Started', 'Completed')     
                AND f.FulfilmentType = @FulfilmentType 
                AND f.OnHold = 0
                AND f.DELETED = 0 
                AND (@WarehouseCode IS NULL OR f.WarehouseCode = @WarehouseCode)
                AND (@TenantCode IS NULL OR f.TenantCode = @TenantCode);

        -- Calculate the total number of pages
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        SET @SQL = N'SELECT f.*, w.WaveID, w.WaveNumber, w.WaveStatus, w.StepStatus, lw.WarehouseName, t.TenantName, t.TenantID,

                
                    CASE
                        WHEN f.Carrier LIKE ''Australia Post%'' AND wl.ShipmentType LIKE ''%Local'' 
                            THEN ash.AP_ConsignmentID
                        WHEN f.Carrier LIKE ''Australia Post%'' AND wl.ShipmentType LIKE ''%INT'' 
                            THEN asht.AP_ConsignmentID
                        WHEN f.Carrier LIKE ''DHL Express%'' 
                            THEN d.shipmentTrackingNumber
                        WHEN f.TrackingNumber IS NOT NULL 
                            THEN f.TrackingNumber
                        ELSE ''''
                    END AS CarrierTrackingNumber

                    FROM dbo.Fulfilment f 
                    LEFT JOIN LocWarehouse lw ON lw.WarehouseCode = f.WarehouseCode
                    LEFT JOIN Tenant t ON t.TenantCode = f.TenantCode
                    LEFT JOIN 
                    ( 
                        SELECT l.OrderNumber, w.WaveID, w.WaveNumber, w.WaveStatus, w.StepStatus FROM WaveLine l 
                        LEFT JOIN Wave w ON w.WaveID = l.WaveID 
                        WHERE l.Deleted = 0
                        AND w.Deleted = 0
                    ) w
                    ON w.OrderNumber = f.OrderNumber

                    -- Required joins for Tracking
                    LEFT JOIN dbo.WaveLine wl 
                        ON wl.OrderNumber = f.OrderNumber 
                        AND wl.Deleted = 0

                    LEFT JOIN dbo.AP_Shipment ash
                        ON wl.ShipmentID = ash.ShipmentID 
                        AND ash.Deleted = 0

                    LEFT JOIN dbo.AP_ShipmentINT asht
                        ON wl.ShipmentID = asht.ShipmentID 
                        AND asht.Deleted = 0

                    LEFT JOIN dbo.DHLResponse d
                        ON f.OrderNumber = d.MessageReference

                    WHERE f.FulfilmentStatus IN (''Fulfilment'', ''Started'')
                    AND f.FulfilmentType = @FulfilmentType
                    AND w.StepStatus NOT IN (''Started'', ''Completed'')
                    AND (@WarehouseCode IS NULL OR f.WarehouseCode = @WarehouseCode)
                    AND (@TenantCode IS NULL OR f.TenantCode = @TenantCode)
                    AND OnHold = 0 AND f.DELETED = 0 ORDER BY ' + @OrderBy + ' ' + @OrderDir +
                ' OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY';
    END
    ELSE
    BEGIN
        -- Get the total number of records
        SET @Search = LOWER(@Search);

        SELECT @TotalRecords = COUNT(*) 
        FROM dbo.Fulfilment f
        LEFT JOIN 
        ( 
            SELECT l.OrderNumber, w.WaveNumber, w.WaveStatus, w.StepStatus FROM WaveLine l 
            LEFT JOIN Wave w ON w.WaveID = l.WaveID 
            WHERE l.Deleted = 0
            AND w.Deleted = 0           
        ) w 
        ON w.OrderNumber = f.OrderNumber
        LEFT JOIN dbo.Tenant t ON f.TenantCode = t.TenantCode 
        WHERE f.DELETED = 0 
        AND f.OnHold = 0
        AND f.FulfilmentStatus IN ('Fulfilment', 'Started')
        AND w.StepStatus NOT IN ('Started', 'Completed')        
        AND f.FulfilmentType = @FulfilmentType
        AND (@WarehouseCode IS NULL OR f.WarehouseCode = @WarehouseCode)
        AND (@TenantCode IS NULL OR f.TenantCode = @TenantCode)
        AND (
            LOWER(f.order_number) LIKE '%' + LOWER(@Search) + '%' 
            OR LOWER(f.OrderNumber) LIKE '%' + LOWER(@Search) + '%' 
            OR LOWER(w.WaveNumber) LIKE '%' + LOWER(@Search) + '%' 
            OR LOWER(w.WaveStatus) LIKE '%' + LOWER(@Search) + '%' 
            OR LOWER(t.TenantName) LIKE '%' + LOWER(@Search) + '%' 
            OR LOWER(f.TenantCode) LIKE '%' + LOWER(@Search) + '%' 
        );

        -- Calculate the total number of pages
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        SET @SQL = N'SELECT f.*, t.TenantName, w.WaveID, w.WaveNumber, w.WaveStatus , lw.WarehouseName, t.TenantID,

            -- Add Tracking Number CASE
            CASE
                WHEN f.Carrier LIKE ''Australia Post%'' AND wl.ShipmentType LIKE ''%Local'' 
                    THEN ash.AP_ConsignmentID
                WHEN f.Carrier LIKE ''Australia Post%'' AND wl.ShipmentType LIKE ''%INT'' 
                    THEN asht.AP_ConsignmentID
                WHEN f.Carrier LIKE ''DHL Express%'' 
                    THEN d.shipmentTrackingNumber
                WHEN f.TrackingNumber IS NOT NULL 
                    THEN f.TrackingNumber
                ELSE ''''
            END AS CarrierTrackingNumber

            FROM dbo.Fulfilment f
            LEFT JOIN LocWarehouse lw ON lw.WarehouseCode = f.WarehouseCode
            LEFT JOIN 
            ( 
                SELECT l.OrderNumber, w.WaveID, w.WaveNumber, w.WaveStatus, w.StepStatus FROM WaveLine l 
                LEFT JOIN Wave w ON w.WaveID = l.WaveID 
                WHERE l.Deleted = 0
                AND w.Deleted = 0                
            ) w
            ON w.OrderNumber = f.OrderNumber

            -- Required joins for Tracking
            LEFT JOIN dbo.WaveLine wl 
                ON wl.OrderNumber = f.OrderNumber 
                AND wl.Deleted = 0

            LEFT JOIN dbo.AP_Shipment ash
                ON wl.ShipmentID = ash.ShipmentID 
                AND ash.Deleted = 0

            LEFT JOIN dbo.AP_ShipmentINT asht
                ON wl.ShipmentID = asht.ShipmentID 
                AND asht.Deleted = 0

            LEFT JOIN dbo.DHLResponse d
                ON f.OrderNumber = d.MessageReference

            LEFT JOIN dbo.Tenant t ON f.TenantCode = t.TenantCode 
            WHERE f.DELETED = 0 
            AND f.OnHold = 0 
            AND f.FulfilmentStatus IN (''Fulfilment'', ''Started'')
            AND w.StepStatus NOT IN (''Started'', ''Completed'')
            AND f.FulfilmentType = @FulfilmentType
            AND (@WarehouseCode IS NULL OR f.WarehouseCode = @WarehouseCode)
            AND (@TenantCode IS NULL OR f.TenantCode = @TenantCode)
            AND (
                LOWER(f.order_number) LIKE ''%'' + @Search + ''%'' 
                OR LOWER(f.OrderNumber) LIKE ''%'' + @Search + ''%'' 
                OR LOWER(w.WaveNumber) LIKE ''%'' + @Search + ''%'' 
                OR LOWER(w.WaveStatus) LIKE ''%'' + @Search + ''%'' 
                OR LOWER(t.TenantName) LIKE ''%'' + @Search + ''%'' 
                OR LOWER(f.TenantCode) LIKE ''%'' + @Search + ''%'' 
            ) 
            ORDER BY ' + @OrderBy + ' ' + @OrderDir + 
            ' OFFSET @Offset ROWS 
            FETCH NEXT @PageSize ROWS ONLY';
    END 

    -- Execute the dynamic SQL
    EXEC sp_executesql
        @SQL,
        @SQLParams,
        @FulfilmentType = @FulfilmentType,
        @WarehouseCode = @WarehouseCode,
        @TenantCode = @TenantCode,
        @Search = @Search,
        @Offset = @Offset,
        @PageSize = @PageSize; 
END
GO
