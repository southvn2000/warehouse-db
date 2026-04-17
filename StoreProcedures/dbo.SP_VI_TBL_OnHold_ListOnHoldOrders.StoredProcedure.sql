USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_OnHold_ListOnHoldOrders]    Script Date: 4/16/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Copilot>
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

    -- -------------------------------------------------------
    -- Count query
    -- -------------------------------------------------------
    SELECT @TotalRecords = COUNT(*)
    FROM dbo.Orders o
    LEFT JOIN dbo.Tenant t ON t.TenantCode = o.TenantCode
    WHERE ISNULL(o.Deleted, 0) = 0
      AND ISNULL(o.OnHold, 0) = 1
      AND (@WarehouseCode IS NULL OR o.WarehouseCode = @WarehouseCode)
      AND (@TenantCode    IS NULL OR o.TenantCode    = @TenantCode)
      AND (
            @Search IS NULL OR LEN(LTRIM(RTRIM(@Search))) = 0
            OR LOWER(o.order_number)              LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(o.OrderStatus)               LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(o.Carrier)                   LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(o.ReferenceNumber)            LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(o.shipping_address_name)     LIKE '%' + LOWER(@Search) + '%'
            OR LOWER(t.TenantName)                LIKE '%' + LOWER(@Search) + '%'
          );

    SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / NULLIF(@PageSize, 0));

    -- -------------------------------------------------------
    -- Data query
    -- -------------------------------------------------------
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'
        SELECT
            o.*,
            t.TenantName,
            t.TenantID,
            lw.WarehouseName
        FROM dbo.Orders o
        LEFT JOIN dbo.Tenant       t  ON t.TenantCode     = o.TenantCode
        LEFT JOIN dbo.LocWarehouse lw ON lw.WarehouseCode = o.WarehouseCode
        WHERE ISNULL(o.Deleted, 0) = 0
          AND ISNULL(o.OnHold, 0) = 1
          AND (@WarehouseCode IS NULL OR o.WarehouseCode = @WarehouseCode)
          AND (@TenantCode    IS NULL OR o.TenantCode    = @TenantCode)
          AND (
                @Search IS NULL OR LEN(LTRIM(RTRIM(@Search))) = 0
                OR LOWER(o.order_number)              LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(o.OrderStatus)               LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(o.Carrier)                   LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(o.ReferenceNumber)            LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(o.shipping_address_name)     LIKE ''%'' + LOWER(@Search) + ''%''
                OR LOWER(t.TenantName)                LIKE ''%'' + LOWER(@Search) + ''%''
              )
        ORDER BY ' + QUOTENAME(@OrderBy) + N' ' + CASE WHEN UPPER(@OrderDir) = 'DESC' THEN N'DESC' ELSE N'ASC' END + N'
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;';

    EXEC sp_executesql
        @SQL,
        N'@WarehouseCode VARCHAR(20), @TenantCode VARCHAR(10), @Search NVARCHAR(100), @Offset INT, @PageSize INT',
        @WarehouseCode = @WarehouseCode,
        @TenantCode    = @TenantCode,
        @Search        = @Search,
        @Offset        = @Offset,
        @PageSize      = @PageSize;
END
GO
