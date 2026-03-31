USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Tenant_CheckTenantInit]    Script Date: 3/30/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Nam nguyen>
-- Create date: <30 Mar, 2026>
-- Description: <Check tenant initialization status>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_Tenant_CheckTenantInit]
	@TenantCode VARCHAR(10),
	@IsInit BIT OUTPUT,
	@Reason VARCHAR(1000) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN

	SET NOCOUNT ON;

	SET @IsInit = 0;
	SET @Reason = '';

	IF @TenantCode IS NULL OR LEN(LTRIM(RTRIM(@TenantCode))) = 0
	BEGIN
		SET @Reason = 'TenantCode is required.';
		RETURN;
	END

	DECLARE @TenantInit BIT;

	SELECT @TenantInit = ISNULL(IsInit, 0)
	FROM dbo.Tenant
	WHERE TenantCode = @TenantCode AND DELETED = 0;

	IF @TenantInit IS NULL
	BEGIN
		SET @Reason = 'Tenant not found.';
		RETURN;
	END

	SET @IsInit = @TenantInit;

	IF @IsInit = 0
	BEGIN
		SET @Reason = 'Tenant has not been initialized.';
	END

END
GO