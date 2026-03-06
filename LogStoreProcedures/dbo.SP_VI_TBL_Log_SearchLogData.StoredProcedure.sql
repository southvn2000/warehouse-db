USE [3PLWMS_LOGS_DEV]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Log_SearchLogData]    Script Date: 3/5/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Nam nguyen>
-- Create date: <05 Mar, 2026>
-- Description:	<Search Log Data>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_Log_SearchLogData]
	@Search NVARCHAR(100) = NULL,
    @LogTable NVARCHAR(200) = NULL,
    @LogStartDate DATETIME,
    @LogEndDate DATETIME,
	@CallingInterfaceIPAddress NVARCHAR(500) = NULL,
	@LoggedInUser NVARCHAR(255) = NULL,
	@TransactionResult NVARCHAR(50) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @OrderBy NVARCHAR(50) = 'LogTableName',
    @OrderDir NVARCHAR(4) = 'ASC',
    @TotalRecords INT OUTPUT,
    @TotalPages INT OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN

	SET NOCOUNT ON;

	IF @PageNumber IS NULL OR @PageNumber < 1 SET @PageNumber = 1;
	IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 10;
	SET @Search = NULLIF(LTRIM(RTRIM(@Search)), '');
	SET @LogTable = NULLIF(LTRIM(RTRIM(@LogTable)), '');

	DECLARE @OrderBySafe NVARCHAR(50) = CASE 
		WHEN @OrderBy IN (
			'LogTableName', 'AppName', 'LogFileName', 'CallingInterfaceIPAddress', 'LoggedInUser',
			'FileName', 'MessageType', 'TransactionResult', 'Message', 'LogTime'
		) THEN @OrderBy
		ELSE 'LogTableName'
	END;

	DECLARE @OrderDirSafe NVARCHAR(4) = CASE WHEN UPPER(@OrderDir) = 'DESC' THEN 'DESC' ELSE 'ASC' END;
	DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
	DECLARE @UnionSQL NVARCHAR(MAX) = N'';
	DECLARE @CountSQL NVARCHAR(MAX);
	DECLARE @DataSQL NVARCHAR(MAX);

	IF @LogStartDate IS NULL OR @LogEndDate IS NULL
	BEGIN
		RAISERROR('LogStartDate and LogEndDate are required.', 16, 1);
		RETURN;
	END

	IF @LogTable IS NOT NULL
	BEGIN
		IF NOT EXISTS (
			SELECT 1
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_SCHEMA = 'dbo'
			  AND TABLE_TYPE = 'BASE TABLE'
			  AND TABLE_NAME = @LogTable
			  AND TABLE_NAME LIKE '%Log'
		)
		BEGIN
			SET @TotalRecords = 0;
			SET @TotalPages = 0;

			SELECT 
				CAST(NULL AS NVARCHAR(200)) AS LogTableName,
				CAST(NULL AS VARCHAR(255)) AS AppName,
				CAST(NULL AS VARCHAR(255)) AS LogFileName,
				CAST(NULL AS VARCHAR(500)) AS CallingInterfaceIPAddress,
				CAST(NULL AS VARCHAR(255)) AS LoggedInUser,
				CAST(NULL AS VARCHAR(255)) AS FileName,
				CAST(NULL AS VARCHAR(50)) AS MessageType,
				CAST(NULL AS VARCHAR(50)) AS TransactionResult,
				CAST(NULL AS VARCHAR(MAX)) AS Message,
				CAST(NULL AS DATETIME) AS LogTime
			WHERE 1 = 0;

			RETURN;
		END

		SET @UnionSQL = N'
			SELECT
				''' + REPLACE(@LogTable, '''', '''''') + N''' AS LogTableName,
				AppName,
				LogFileName,
				CallingInterfaceIPAddress,
				LogFileName,
				LoggedInUser,
				FileName,
				MessageType,
				TransactionResult,
				Message,
				Comment1,
				Comment2,
				Comment3,
				PayloadRequest,
				PayloadResponse,
				ResponseStatus,
				MobileDeviceID,
				LogTime
			FROM [dbo].' + QUOTENAME(@LogTable) + N'
			WHERE LogTime >= @LogStartDate
			  AND LogTime <= @LogEndDate
			  AND (@CallingInterfaceIPAddress IS NULL OR LOWER(ISNULL(CallingInterfaceIPAddress, '''')) LIKE ''%'' + LOWER(@CallingInterfaceIPAddress) + ''%'')
			  AND (@LoggedInUser IS NULL OR LOWER(ISNULL(LoggedInUser, '''')) LIKE ''%'' + LOWER(@LoggedInUser) + ''%'')
			  AND (@TransactionResult IS NULL OR LOWER(ISNULL(TransactionResult, '''')) LIKE ''%'' + LOWER(@TransactionResult) + ''%'')
			  AND (
				@Search IS NULL
				OR LOWER(ISNULL(CallingInterfaceIPAddress, '''')) LIKE ''%'' + LOWER(@Search) + ''%''
				OR LOWER(ISNULL(LoggedInUser, '''')) LIKE ''%'' + LOWER(@Search) + ''%''
				OR LOWER(ISNULL(TransactionResult, '''')) LIKE ''%'' + LOWER(@Search) + ''%''
				OR LOWER(ISNULL(Message, '''')) LIKE ''%'' + LOWER(@Search) + ''%''
			  )';
	END
	ELSE
	BEGIN
		SELECT @UnionSQL = @UnionSQL + CASE WHEN LEN(@UnionSQL) > 0 THEN N' UNION ALL ' ELSE N'' END + N'
			SELECT
				''' + TABLE_NAME + N''' AS LogTableName,
				AppName,
				LogFileName,
				CallingInterfaceIPAddress,
				LogFileName,
				LoggedInUser,
				FileName,
				MessageType,
				TransactionResult,
				Message,
				Comment1,
				Comment2,
				Comment3,
				PayloadRequest,
				PayloadResponse,
				ResponseStatus,
				MobileDeviceID,
				LogTime
			FROM [dbo].' + QUOTENAME(TABLE_NAME) + N'
			WHERE LogTime >= @LogStartDate
			  AND LogTime <= @LogEndDate
			  AND (@CallingInterfaceIPAddress IS NULL OR LOWER(ISNULL(CallingInterfaceIPAddress, '''')) LIKE ''%'' + LOWER(@CallingInterfaceIPAddress) + ''%'')
			  AND (@LoggedInUser IS NULL OR LOWER(ISNULL(LoggedInUser, '''')) LIKE ''%'' + LOWER(@LoggedInUser) + ''%'')
			  AND (@TransactionResult IS NULL OR LOWER(ISNULL(TransactionResult, '''')) LIKE ''%'' + LOWER(@TransactionResult) + ''%'')
			  AND (
				@Search IS NULL
				OR LOWER(ISNULL(CallingInterfaceIPAddress, '''')) LIKE ''%'' + LOWER(@Search) + ''%''
				OR LOWER(ISNULL(LoggedInUser, '''')) LIKE ''%'' + LOWER(@Search) + ''%''
				OR LOWER(ISNULL(TransactionResult, '''')) LIKE ''%'' + LOWER(@Search) + ''%''
				OR LOWER(ISNULL(Message, '''')) LIKE ''%'' + LOWER(@Search) + ''%''
			  )'
		FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_SCHEMA = 'dbo'
		  AND TABLE_TYPE = 'BASE TABLE'
		  AND TABLE_NAME LIKE '%Log';
	END

	IF @UnionSQL IS NULL OR LEN(@UnionSQL) = 0
	BEGIN
		SET @TotalRecords = 0;
		SET @TotalPages = 0;

		SELECT 
			CAST(NULL AS NVARCHAR(200)) AS LogTableName,
			CAST(NULL AS VARCHAR(255)) AS AppName,
			CAST(NULL AS VARCHAR(255)) AS LogFileName,
			CAST(NULL AS VARCHAR(500)) AS CallingInterfaceIPAddress,
			CAST(NULL AS VARCHAR(255)) AS LoggedInUser,
			CAST(NULL AS VARCHAR(255)) AS FileName,
			CAST(NULL AS VARCHAR(50)) AS MessageType,
			CAST(NULL AS VARCHAR(50)) AS TransactionResult,
			CAST(NULL AS VARCHAR(MAX)) AS Message,
			CAST(NULL AS DATETIME) AS LogTime
		WHERE 1 = 0;

		RETURN;
	END

	SET @CountSQL = N'SELECT @TotalRecords = COUNT(1) FROM (' + @UnionSQL + N') AS S';

	EXEC sp_executesql
		@CountSQL,
		N'@Search NVARCHAR(100), @CallingInterfaceIPAddress NVARCHAR(500), @LoggedInUser NVARCHAR(255), @TransactionResult NVARCHAR(50), @LogStartDate DATETIME, @LogEndDate DATETIME, @TotalRecords INT OUTPUT',
		@Search = @Search,
		@CallingInterfaceIPAddress = @CallingInterfaceIPAddress,
		@LoggedInUser = @LoggedInUser,
		@TransactionResult = @TransactionResult,
		@LogStartDate = @LogStartDate,
		@LogEndDate = @LogEndDate,
		@TotalRecords = @TotalRecords OUTPUT;

	SET @TotalPages = CASE 
		WHEN @TotalRecords = 0 THEN 0
		ELSE CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize)
	END;

	SET @DataSQL = N'
		SELECT *
		FROM (' + @UnionSQL + N') AS S
		ORDER BY ' + QUOTENAME(@OrderBySafe) + N' ' + @OrderDirSafe + N'
		OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY';

	EXEC sp_executesql
		@DataSQL,
		N'@Search NVARCHAR(100), @CallingInterfaceIPAddress NVARCHAR(500), @LoggedInUser NVARCHAR(255), @TransactionResult NVARCHAR(50), @LogStartDate DATETIME, @LogEndDate DATETIME, @Offset INT, @PageSize INT',
		@Search = @Search,
		@CallingInterfaceIPAddress = @CallingInterfaceIPAddress,
		@LoggedInUser = @LoggedInUser,
		@TransactionResult = @TransactionResult,
		@LogStartDate = @LogStartDate,
		@LogEndDate = @LogEndDate,
		@Offset = @Offset,
		@PageSize = @PageSize;

END
GO
