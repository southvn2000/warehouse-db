$ErrorActionPreference = "Stop"
$path1 = "e:\document\Loi\Australia-Logistic\sql-src\StoreProcedures\dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql"
$path2 = "e:\document\Loi\Australia-Logistic\sql-src\StoreProcedures\dbo.SP_VI_TBL_Items_CheckAvailableStockForOrderInLocation.StoredProcedure.sql"

$earlyBlock = @"
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

"@

$latePattern = "\r?\n\s*-- Always revert any prior Allocated rows for this order before re-evaluating,\r?\n\s*-- so a failed re-check does not leave stale allocations that over-consume stock\.\r?\n\s*IF @OrderNumber IS NOT NULL\r?\n\s*BEGIN\r?\n\s*UPDATE dbo\.ULDLine\r?\n\s*SET Deleted = 1,\r?\n\s*FirstEditedDateTime = COALESCE\(FirstEditedDateTime, @OperationDateTime\),\r?\n\s*FirstEditedBy\s*=\s*COALESCE\(FirstEditedBy, @OperationBy\),\r?\n\s*LastEditedDateTime\s*=\s*COALESCE\(@OperationDateTime, LastEditedDateTime\),\r?\n\s*LastEditedBy\s*=\s*COALESCE\(@OperationBy, LastEditedBy\)\r?\n\s*WHERE Deleted = 0\r?\n\s*AND TransactionType = 'Allocated'\r?\n\s*AND TransactionReference = @OrderNumber;\r?\n\s*END\r?\n"

$content1 = Get-Content $path1 -Raw -Encoding Unicode
$content2 = Get-Content $path2 -Raw -Encoding Unicode

$content1 = [regex]::Replace($content1, $latePattern, "`r`n", 'Singleline')
$content2 = [regex]::Replace($content2, $latePattern, "`r`n", 'Singleline')

$pattern1 = "(RETURN;\r?\n\s*END\r?\n\s*END\r?\n\r?\n)\s*(CREATE TABLE #TempItemULDTable)"
if([regex]::IsMatch($content1,$pattern1,'Singleline')) {
  $content1 = [regex]::Replace($content1,$pattern1,"$1$earlyBlock`t$2",'Singleline')
}

$pattern2 = "(SET @IsEnough = 1;\r?\n\r?\n)\s*(CREATE TABLE #TempItemULDTable)"
if([regex]::IsMatch($content2,$pattern2,'Singleline')) {
  $content2 = [regex]::Replace($content2,$pattern2,"$1$earlyBlock`t$2",'Singleline')
}

Set-Content $path1 -Value $content1 -Encoding Unicode
Set-Content $path2 -Value $content2 -Encoding Unicode
Write-Output "Applied regex edits successfully."
