$ErrorActionPreference = "Stop"
$path1 = "e:\document\Loi\Australia-Logistic\sql-src\StoreProcedures\dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql"
$path2 = "e:\document\Loi\Australia-Logistic\sql-src\StoreProcedures\dbo.SP_VI_TBL_Items_CheckAvailableStockForOrderInLocation.StoredProcedure.sql"

$content1 = Get-Content $path1 -Raw -Encoding Unicode
$content2 = Get-Content $path2 -Raw -Encoding Unicode

$replacement1 = @"
SET @IsEnough = 1;

-- Check if Order is On Hold
IF @OrderNumber IS NOT NULL
BEGIN
DECLARE @OrderOnHold BIT;
SELECT @OrderOnHold = OnHold 
FROM dbo.Orders 
WHERE order_number = @OrderNumber 
  AND DELETED = 0;

IF @OrderOnHold = 1
BEGIN
SET @IsEnough = 0;

IF @ReturnMissing = 1
BEGIN
SELECT 
@OrderNumber AS ItemNumber,
'Order' AS ItemName,
0 AS TotalQty,
'OrderOnHold' AS MissingType;
END

RETURN;
END
END

-- Revert any prior Allocated rows for this order before stock checking,
-- so existing allocations of the same order do not reduce current availability.
IF @OrderNumber IS NOT NULL
BEGIN
UPDATE dbo.ULDLine
SET Deleted = 1,
FirstEditedDateTime = COALESCE(FirstEditedDateTime, @OperationDateTime),
FirstEditedBy       = COALESCE(FirstEditedBy, @OperationBy),
LastEditedDateTime  = COALESCE(@OperationDateTime, LastEditedDateTime),
LastEditedBy        = COALESCE(@OperationBy, LastEditedBy)
WHERE Deleted = 0
  AND TransactionType = 'Allocated'
  AND TransactionReference = @OrderNumber;
END

CREATE TABLE #TempItemULDTable (
"@

$pattern1 = "SET @IsEnough = 1;[\s\S]*?\(\r?\n\s*ULDID INT NOT NULL,"
$content1 = [regex]::Replace($content1, $pattern1, $replacement1 + "`t`tULDID INT NOT NULL,", 'Singleline')

$replacement2 = @"
SET @IsEnough = 1;

-- Revert any prior Allocated rows for this order before stock checking,
-- so existing allocations of the same order do not reduce current availability.
IF @OrderNumber IS NOT NULL
BEGIN
UPDATE dbo.ULDLine
SET Deleted = 1,
FirstEditedDateTime = COALESCE(FirstEditedDateTime, @OperationDateTime),
FirstEditedBy       = COALESCE(FirstEditedBy, @OperationBy),
LastEditedDateTime  = COALESCE(@OperationDateTime, LastEditedDateTime),
LastEditedBy        = COALESCE(@OperationBy, LastEditedBy)
WHERE Deleted = 0
  AND TransactionType = 'Allocated'
  AND TransactionReference = @OrderNumber;
END

CREATE TABLE #TempItemULDTable (
"@

$pattern2 = "SET NOCOUNT ON;[\s\S]*?\(\r?\n\s*ULDID INT NOT NULL,"
$content2 = [regex]::Replace($content2, $pattern2, "SET NOCOUNT ON;`r`n`r`n" + $replacement2 + "`t`tULDID INT NOT NULL,", 'Singleline')

Set-Content $path1 -Value $content1 -Encoding Unicode
Set-Content $path2 -Value $content2 -Encoding Unicode
Write-Output "Header blocks repaired."
