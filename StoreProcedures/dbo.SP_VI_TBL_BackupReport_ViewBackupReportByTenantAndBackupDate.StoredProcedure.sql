USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_BackupReport_ViewBackupReportByTenantAndBackupDate]    Script Date: 5/5/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Nam Nguyen>
-- Create date: <05 May, 2026>
-- Description: <Get Backup Report by TenantCode and BackupDate>
-- =============================================
ALTER PROCEDURE [dbo].[SP_VI_TBL_BackupReport_ViewBackupReportByTenantAndBackupDate]
    @TenantCode VARCHAR(10) = NULL,
    @WarehouseCode VARCHAR(10) = NULL,
    @ReportName VARCHAR(100) = NULL,
    @BackupDate DATETIME = NULL,
    @Search NVARCHAR(100) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @OrderBy NVARCHAR(50) = 'BackupDate',
    @OrderDir NVARCHAR(4) = 'DESC',    -- 'ASC' or 'DESC'
    @TotalRecords INT OUTPUT,
    @TotalPages INT OUTPUT
WITH
    EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NormalizedTenantCode VARCHAR(10) = NULLIF(LTRIM(RTRIM(@TenantCode)), '');
    DECLARE @NormalizedWarehouseCode VARCHAR(10) = NULLIF(LTRIM(RTRIM(@WarehouseCode)), '');
    DECLARE @NormalizedReportName VARCHAR(100) = NULLIF(LTRIM(RTRIM(@ReportName)), '');
    DECLARE @NormalizedSearch NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@Search)), '');
    DECLARE @BackupDateFrom DATETIME = CASE WHEN @BackupDate IS NULL THEN NULL ELSE DATEADD(DAY, DATEDIFF(DAY, 0, @BackupDate), 0) END;
    DECLARE @BackupDateTo DATETIME = CASE WHEN @BackupDateFrom IS NULL THEN NULL ELSE DATEADD(DAY, 1, @BackupDateFrom) END;
    DECLARE @Offset INT;
    DECLARE @ResolvedOrderBy NVARCHAR(50);
    DECLARE @ResolvedOrderDir NVARCHAR(4);
    DECLARE @SQL NVARCHAR(MAX);

    SET @PageNumber = CASE WHEN ISNULL(@PageNumber, 0) < 1 THEN 1 ELSE @PageNumber END;
    SET @PageSize = CASE WHEN ISNULL(@PageSize, 0) < 1 THEN 10 ELSE @PageSize END;
    SET @Offset = (@PageNumber - 1) * @PageSize;

    SET @ResolvedOrderBy = CASE UPPER(ISNULL(@OrderBy, ''))
        WHEN 'BACKUPREPORTID' THEN N'br.BackupReportID'
        WHEN 'TENANTCODE' THEN N'br.TenantCode'
        WHEN 'WAREHOUSECODE' THEN N'br.WarehouseCode'
        WHEN 'REPORTNAME' THEN N'br.ReportName'
        WHEN 'BACKUPDATE' THEN N'br.BackupDate'
        WHEN 'CREATEDDATETIME' THEN N'br.CreatedDateTime'
        WHEN 'CREATEDBY' THEN N'br.CreatedBy'
        WHEN 'UPDATEDDATETIME' THEN N'br.UpdatedDateTime'
        WHEN 'UPDATEDBY' THEN N'br.UpdatedBy'
        ELSE N'br.BackupDate'
    END;

    SET @ResolvedOrderDir = CASE WHEN UPPER(ISNULL(@OrderDir, 'DESC')) = 'ASC' THEN N'ASC' ELSE N'DESC' END;

    SELECT @TotalRecords = COUNT(1)
    FROM dbo.BackupReport br
    LEFT JOIN dbo.Tenant t ON t.TenantCode = br.TenantCode AND ISNULL(t.Deleted, 0) = 0
    LEFT JOIN dbo.LocWarehouse lw ON lw.WarehouseCode = br.WarehouseCode AND ISNULL(lw.Deleted, 0) = 0
    WHERE (br.Deleted = 0 OR br.Deleted IS NULL)
        AND (@NormalizedTenantCode IS NULL OR br.TenantCode = @NormalizedTenantCode)
        AND (@NormalizedWarehouseCode IS NULL OR br.WarehouseCode = @NormalizedWarehouseCode)
        AND (@NormalizedReportName IS NULL OR br.ReportName LIKE @NormalizedReportName + '%')
        AND (@BackupDateFrom IS NULL OR (br.BackupDate >= @BackupDateFrom AND br.BackupDate < @BackupDateTo))
        AND (
            @NormalizedSearch IS NULL
            OR br.TenantCode LIKE '%' + @NormalizedSearch + '%'
            OR br.WarehouseCode LIKE '%' + @NormalizedSearch + '%'
            OR t.TenantName LIKE '%' + @NormalizedSearch + '%'
            OR lw.WarehouseName LIKE '%' + @NormalizedSearch + '%'
            OR br.ReportName LIKE '%' + @NormalizedSearch + '%'
            OR br.CreatedBy LIKE '%' + @NormalizedSearch + '%'
            OR br.UpdatedBy LIKE '%' + @NormalizedSearch + '%'
        );

    SET @TotalPages = CASE
        WHEN @TotalRecords = 0 THEN 0
        ELSE CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize)
    END;

    SET @SQL = N'
        SELECT br.*, t.TenantName, lw.WarehouseName
        FROM dbo.BackupReport br
        LEFT JOIN dbo.Tenant t ON t.TenantCode = br.TenantCode AND ISNULL(t.Deleted, 0) = 0
        LEFT JOIN dbo.LocWarehouse lw ON lw.WarehouseCode = br.WarehouseCode AND ISNULL(lw.Deleted, 0) = 0
        WHERE (br.Deleted = 0 OR br.Deleted IS NULL)
            AND (@NormalizedTenantCode IS NULL OR br.TenantCode = @NormalizedTenantCode)
            AND (@NormalizedWarehouseCode IS NULL OR br.WarehouseCode = @NormalizedWarehouseCode)
            AND (@NormalizedReportName IS NULL OR br.ReportName LIKE  + @NormalizedReportName + ''%'')
            AND (@BackupDateFrom IS NULL OR (br.BackupDate >= @BackupDateFrom AND br.BackupDate < @BackupDateTo))
            AND (
                @NormalizedSearch IS NULL
                OR br.TenantCode LIKE ''%'' + @NormalizedSearch + ''%''
                OR br.WarehouseCode LIKE ''%'' + @NormalizedSearch + ''%''
                OR t.TenantName LIKE ''%'' + @NormalizedSearch + ''%''
                OR lw.WarehouseName LIKE ''%'' + @NormalizedSearch + ''%''
                OR br.ReportName LIKE ''%'' + @NormalizedSearch + ''%''
                OR br.CreatedBy LIKE ''%'' + @NormalizedSearch + ''%''
                OR br.UpdatedBy LIKE ''%'' + @NormalizedSearch + ''%''
            )
        ORDER BY ' + @ResolvedOrderBy + N' ' + @ResolvedOrderDir
        + CASE WHEN @ResolvedOrderBy = N'br.BackupReportID' THEN N'' ELSE N', br.BackupReportID DESC' END + N'
        OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;';

    EXEC sp_executesql
        @SQL,
        N'@NormalizedTenantCode VARCHAR(10),
          @NormalizedWarehouseCode VARCHAR(10),
          @NormalizedReportName VARCHAR(100),
          @BackupDateFrom DATETIME,
          @BackupDateTo DATETIME,
          @NormalizedSearch NVARCHAR(100),
          @Offset INT,
          @PageSize INT',
        @NormalizedTenantCode = @NormalizedTenantCode,
        @NormalizedWarehouseCode = @NormalizedWarehouseCode,
        @NormalizedReportName = @NormalizedReportName,
        @BackupDateFrom = @BackupDateFrom,
        @BackupDateTo = @BackupDateTo,
        @NormalizedSearch = @NormalizedSearch,
        @Offset = @Offset,
        @PageSize = @PageSize;
END
GO
