USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_OnHold_ListOnHoldOrders]    Script Date: 4/16/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              Nam Nguyen
-- Create date: <16 Apr, 2026>
-- Description: <List OnHold Orders (Order Type) with search and paging>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_OnHold_ListOnHoldOrders]
    @WarehouseCode  VARCHAR(20)  = NULL,
    @TenantCode     VARCHAR(10)  = NULL,
    @Search         NVARCHAR(100) = NULL,
    @PageNumber     INT          = 1,
    @PageSize       INT          = 10,
    @OrderBy        NVARCHAR(50) = 'OrderID',
    @OrderDir       NVARCHAR(4)  = 'DESC',   -- 'ASC' or 'DESC'
    @TotalRecords   INT OUTPUT,
    @TotalPages     INT OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    DECLARE @SearchTrimmed NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@Search)), '');

    -- -------------------------------------------------------
    -- Count query
    -- -------------------------------------------------------
    SELECT @TotalRecords = COUNT(*)
    FROM
    (
        SELECT
            o.OrderID,
            o.order_number,                               
			CAST(NULL AS VARCHAR(50)) AS FulfilmentNumber,
            o.CreatedBy,
            o.CreatedDateTime,
            o.LastEditedBy,
            o.LastEditedDateTime,
            o.FirstEditedDateTime,
            o.FirstEditedBy,
            o.Deleted,
            o.OnHold,
            o.Source,
            o.OrderStatus,
            o.WarehouseName,
            o.WarehouseCode,
            o.TenantCode,
            o.CarrierID,
            o.CarrierServiceID,
            o.Carrier,
            o.CarrierService,
            o.shipping_address_name,
            o.shipping_address_company,
            o.shipping_address_address1,
            o.shipping_address_address2,
            o.shipping_address_city,
            o.shipping_address_province,
            o.shipping_address_zip,
            o.shipping_address_country,
            o.FulfilmentStatus,
            o.FulfilmentStatusDateTime,
            o.Phone,
            o.contact_email,
            o.ReferenceNumber,
            o.ShipmentNumber,
            o.SpecialInstructions
        FROM dbo.Orders o
        WHERE ISNULL(o.Deleted, 0) = 0
          AND ISNULL(o.OnHold, 0) = 1

        UNION ALL

        SELECT
            f.FulfilmentID AS OrderID,
            f.order_number AS order_number, 
			f.OrderNumber AS FulfilmentNumber, 
            f.CreatedBy,
            f.CreatedDateTime,
            f.LastEditedBy,
            f.LastEditedDateTime,
            f.FirstEditedDateTime,
            f.FirstEditedBy,
            f.Deleted,
            f.OnHold,
            f.OrderSource AS Source,
            f.FulfilmentStatus AS OrderStatus,
            f.WarehouseName,
            f.WarehouseCode,
            f.TenantCode,
            f.CarrierID,
            f.CarrierServiceID,
            f.Carrier,
            f.CarrierService,
            f.shipping_address_name,
            f.shipping_address_company,
            f.shipping_address_address1,
            f.shipping_address_address2,
            f.shipping_address_city,
            f.shipping_address_province,
            f.shipping_address_zip,
            f.shipping_address_country,
            f.FulfilmentStatus,
            CAST(NULL AS DATETIME) AS FulfilmentStatusDateTime,
            f.Phone,
            f.contact_email,
            f.ReferenceNumber,
            f.ShipmentNumber,
            f.SpecialInstructions
        FROM dbo.Fulfilment f
        WHERE ISNULL(f.Deleted, 0) = 0
          AND ISNULL(f.OnHold, 0) = 1
          AND f.FulfilmentType = 'Orders'
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.WaveLine wl
              INNER JOIN dbo.Wave w ON w.WaveID = wl.WaveID
              WHERE wl.Deleted = 0
                AND wl.OrderNumber = f.OrderNumber
          )
    ) src
    LEFT JOIN dbo.Tenant t ON t.TenantCode = src.TenantCode
    WHERE (@WarehouseCode IS NULL OR src.WarehouseCode = @WarehouseCode)
      AND (@TenantCode    IS NULL OR src.TenantCode    = @TenantCode)
      AND (
            @SearchTrimmed IS NULL
            OR LOWER(src.order_number)            LIKE '%' + LOWER(@SearchTrimmed) + '%'
            OR LOWER(src.OrderStatus)             LIKE '%' + LOWER(@SearchTrimmed) + '%'
            OR LOWER(src.Carrier)                 LIKE '%' + LOWER(@SearchTrimmed) + '%'
            OR LOWER(src.ReferenceNumber)         LIKE '%' + LOWER(@SearchTrimmed) + '%'
            OR LOWER(src.shipping_address_name)   LIKE '%' + LOWER(@SearchTrimmed) + '%'
        OR LOWER(t.TenantName)                LIKE '%' + LOWER(@SearchTrimmed) + '%'
          );

    SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / NULLIF(@PageSize, 0));

    -- -------------------------------------------------------
    -- Data query
    -- -------------------------------------------------------
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'
        SELECT
            src.*,
            t.TenantName,
            t.TenantID,
            lw.WarehouseName
        FROM
        (
            SELECT
                o.OrderID,
                o.order_number,
				CAST(NULL AS VARCHAR(50)) AS FulfilmentNumber,
                o.CreatedBy,
                o.CreatedDateTime,
                o.LastEditedBy,
                o.LastEditedDateTime,
                o.FirstEditedDateTime,
                o.FirstEditedBy,
                o.Deleted,
                o.OnHold,
                o.Source,
                o.OrderStatus,
                o.WarehouseName,
                o.WarehouseCode,
                o.TenantCode,
                o.CarrierID,
                o.CarrierServiceID,
                o.Carrier,
                o.CarrierService,
                o.shipping_address_name,
                o.shipping_address_company,
                o.shipping_address_address1,
                o.shipping_address_address2,
                o.shipping_address_city,
                o.shipping_address_province,
                o.shipping_address_zip,
                o.shipping_address_country,
                o.FulfilmentStatus,
                o.FulfilmentStatusDateTime,
                o.Phone,
                o.contact_email,
                o.ReferenceNumber,
                o.ShipmentNumber,
                o.SpecialInstructions
            FROM dbo.Orders o
            WHERE ISNULL(o.Deleted, 0) = 0
              AND ISNULL(o.OnHold, 0) = 1

            UNION ALL

            SELECT
                f.FulfilmentID AS OrderID,
                f.order_number AS order_number,
				f.OrderNumber AS FulfilmentNumber,
                f.CreatedBy,
                f.CreatedDateTime,
                f.LastEditedBy,
                f.LastEditedDateTime,
                f.FirstEditedDateTime,
                f.FirstEditedBy,
                f.Deleted,
                f.OnHold,
                f.OrderSource AS Source,
                f.FulfilmentStatus AS OrderStatus,
                f.WarehouseName,
                f.WarehouseCode,
                f.TenantCode,
                f.CarrierID,
                f.CarrierServiceID,
                f.Carrier,
                f.CarrierService,
                f.shipping_address_name,
                f.shipping_address_company,
                f.shipping_address_address1,
                f.shipping_address_address2,
                f.shipping_address_city,
                f.shipping_address_province,
                f.shipping_address_zip,
                f.shipping_address_country,
                f.FulfilmentStatus,
                CAST(NULL AS DATETIME) AS FulfilmentStatusDateTime,
                f.Phone,
                f.contact_email,
                f.ReferenceNumber,
                f.ShipmentNumber,
                f.SpecialInstructions
            FROM dbo.Fulfilment f
            WHERE ISNULL(f.Deleted, 0) = 0
              AND ISNULL(f.OnHold, 0) = 1
              AND f.FulfilmentType = ''Orders''
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.WaveLine wl
                  INNER JOIN dbo.Wave w ON w.WaveID = wl.WaveID
                  WHERE wl.Deleted = 0
                    AND wl.OrderNumber = f.OrderNumber
              )
        ) src
        LEFT JOIN dbo.Tenant       t  ON t.TenantCode     = src.TenantCode
        LEFT JOIN dbo.LocWarehouse lw ON lw.WarehouseCode = src.WarehouseCode
        WHERE (@WarehouseCode IS NULL OR src.WarehouseCode = @WarehouseCode)
          AND (@TenantCode    IS NULL OR src.TenantCode    = @TenantCode)
          AND (
                @SearchTrimmed IS NULL
                OR LOWER(src.order_number)            LIKE ''%'' + LOWER(@SearchTrimmed) + ''%''
                OR LOWER(src.OrderStatus)             LIKE ''%'' + LOWER(@SearchTrimmed) + ''%''
                OR LOWER(src.Carrier)                 LIKE ''%'' + LOWER(@SearchTrimmed) + ''%''
                OR LOWER(src.ReferenceNumber)         LIKE ''%'' + LOWER(@SearchTrimmed) + ''%''
                OR LOWER(src.shipping_address_name)   LIKE ''%'' + LOWER(@SearchTrimmed) + ''%''
                OR LOWER(t.TenantName)                LIKE ''%'' + LOWER(@SearchTrimmed) + ''%''
              )
        ORDER BY ' + QUOTENAME(@OrderBy) + N' ' + CASE WHEN UPPER(@OrderDir) = 'DESC' THEN N'DESC' ELSE N'ASC' END + N'
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;';

    EXEC sp_executesql
        @SQL,
        N'@WarehouseCode VARCHAR(20), @TenantCode VARCHAR(10), @SearchTrimmed NVARCHAR(100), @Offset INT, @PageSize INT',
        @WarehouseCode = @WarehouseCode,
        @TenantCode    = @TenantCode,
        @SearchTrimmed = @SearchTrimmed,
        @Offset        = @Offset,
        @PageSize      = @PageSize;
END
GO
