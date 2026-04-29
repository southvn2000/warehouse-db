USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_OnHold_ListOnHoldFulfilments]    Script Date: 4/16/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Copilot>
-- Create date: <16 Apr, 2026>
-- Description: <List OnHold Orders (Fulfilment Type) with search and paging>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_OnHold_ListOnHoldFulfilments]
    @WarehouseCode   VARCHAR(20)   = NULL,
    @TenantCode      VARCHAR(10)   = NULL,
    @Search          NVARCHAR(100) = NULL,
    @PageNumber      INT           = 1,
    @PageSize        INT           = 10,
    @OrderBy         NVARCHAR(50)  = 'FulfilmentID',
    @OrderDir        NVARCHAR(4)   = 'DESC',   -- 'ASC' or 'DESC'
    @TotalRecords    INT OUTPUT,
    @TotalPages      INT OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    -- -------------------------------------------------------
    -- Count query
    -- -------------------------------------------------------
    SELECT @TotalRecords = COUNT(*)
    FROM dbo.Fulfilment f
    LEFT JOIN dbo.Tenant t ON t.TenantCode = f.TenantCode
    LEFT JOIN
    (
        SELECT l.OrderNumber, w.WaveID, w.WaveNumber, w.WaveStatus
        FROM dbo.WaveLine l
        LEFT JOIN dbo.Wave w ON w.WaveID = l.WaveID
        WHERE l.Deleted = 0
    ) w ON w.OrderNumber = f.OrderNumber
    WHERE ISNULL(f.Deleted, 0) = 0
      AND ISNULL(f.OnHold, 0)  = 1
      AND (@WarehouseCode  IS NULL OR f.WarehouseCode  = @WarehouseCode)
      AND (@TenantCode     IS NULL OR f.TenantCode     = @TenantCode)
      AND f.FulfilmentType = 'Orders'
            AND w.WaveID IS NOT NULL
      AND (
            @Search IS NULL OR LEN(LTRIM(RTRIM(@Search))) = 0
            OR LOWER(f.order_number)          LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(f.OrderNumber)           LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(f.FulfilmentStatus)      LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(f.Carrier)               LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(f.ReferenceNumber)        LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(f.shipping_address_name) LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(t.TenantName)            LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(w.WaveNumber)            LIKE '%' + LOWER(@Search) + '%'
          );

    SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / NULLIF(@PageSize, 0));

    -- -------------------------------------------------------
    -- Data query
    -- -------------------------------------------------------
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'
        SELECT
            f.*,
            t.TenantName,
            t.TenantID,
            lw.WarehouseName,
            w.WaveID,
            w.WaveNumber,
            w.WaveStatus,
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
        LEFT JOIN dbo.Tenant       t  ON t.TenantCode     = f.TenantCode
        LEFT JOIN dbo.LocWarehouse lw ON lw.WarehouseCode = f.WarehouseCode
        LEFT JOIN
        (
            SELECT l.OrderNumber, w.WaveID, w.WaveNumber, w.WaveStatus
            FROM dbo.WaveLine l
            LEFT JOIN dbo.Wave w ON w.WaveID = l.WaveID
            WHERE l.Deleted = 0
        ) w ON w.OrderNumber = f.OrderNumber
        LEFT JOIN dbo.WaveLine wl
            ON wl.OrderNumber = f.OrderNumber AND wl.Deleted = 0
        LEFT JOIN dbo.AP_Shipment ash
            ON wl.ShipmentID = ash.ShipmentID AND ash.Deleted = 0
        LEFT JOIN dbo.AP_ShipmentINT asht
            ON wl.ShipmentID = asht.ShipmentID AND asht.Deleted = 0
        LEFT JOIN dbo.DHLResponse d
            ON f.OrderNumber = d.MessageReference
        WHERE ISNULL(f.Deleted, 0) = 0
          AND ISNULL(f.OnHold, 0)  = 1
          AND (@WarehouseCode  IS NULL OR f.WarehouseCode  = @WarehouseCode)
          AND (@TenantCode     IS NULL OR f.TenantCode     = @TenantCode)
          AND f.FulfilmentType = ''Orders''
                    AND w.WaveID IS NOT NULL
          AND (
                @Search IS NULL OR LEN(LTRIM(RTRIM(@Search))) = 0
                OR LOWER(f.order_number)          LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(f.OrderNumber)           LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(f.FulfilmentStatus)      LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(f.Carrier)               LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(f.ReferenceNumber)        LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(f.shipping_address_name) LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(t.TenantName)            LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(w.WaveNumber)            LIKE ''%'' + LOWER(@Search) + ''%''
              )
        ORDER BY ' + QUOTENAME(@OrderBy) + N' ' + CASE WHEN UPPER(@OrderDir) = 'DESC' THEN N'DESC' ELSE N'ASC' END + N'
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;';

    EXEC sp_executesql
        @SQL,
        N'@WarehouseCode VARCHAR(20), @TenantCode VARCHAR(10), @Search NVARCHAR(100), @Offset INT, @PageSize INT',
        @WarehouseCode  = @WarehouseCode,
        @TenantCode     = @TenantCode,
        @Search         = @Search,
        @Offset         = @Offset,
        @PageSize       = @PageSize;
END
GO
