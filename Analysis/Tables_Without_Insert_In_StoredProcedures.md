# Tables Without INSERT Usage In Stored Procedures

Generated: 2026-05-06

This document lists tables defined under `Tables/` that were not found in any `INSERT` statement across `*.StoredProcedure.sql` files.

## Summary

- Total table definitions scanned: 139
- Stored procedure files scanned: 582
- Tables without INSERT usage: 27

## Table List

1. dbo.APIEndpoint
2. dbo.Connote
3. dbo.Country
4. dbo.CPItemsDomestic
5. dbo.CPManifest
6. dbo.CPShipmentDomestic
7. dbo.CreateKitOrder
8. dbo.CreateKitOrderLine
9. dbo.LogFile
10. dbo.MobileVersionInfo
11. dbo.NumberingSequances
12. dbo.PickingResult
13. dbo.ReportDefinition
14. dbo.ReportScheduleParameter
15. dbo.ReportStockOnHand
16. dbo.ReportWidget
17. dbo.SecurityLog
18. dbo.Setting
19. dbo.TarekTest
20. dbo.TenantLog
21. dbo.TenantPermission
22. dbo.TenantSectionPermission
23. dbo.ULDLabelFileMapping
24. dbo.ULDPrefix
25. dbo.UserIpAddress
26. dbo.Weather
27. dbo.Widget

## Notes

- Matching was done against `INSERT ...` targets in stored procedures.
- Temporary tables (`#...`) and table variables (`@...`) were excluded.
- Both schema-qualified targets (for example, `dbo.Table`) and table-only targets were considered.

## Init Data Grouping

### Need init data: Yes

1. dbo.Country
2. dbo.ReportDefinition
3. dbo.Setting
4. dbo.Widget

### Need init data: No

1. dbo.Connote
2. dbo.CPItemsDomestic
3. dbo.CPManifest
4. dbo.CPShipmentDomestic
5. dbo.CreateKitOrder
6. dbo.CreateKitOrderLine
7. dbo.LogFile
8. dbo.MobileVersionInfo
9. dbo.NumberingSequances
10. dbo.PickingResult
11. dbo.ReportStockOnHand
12. dbo.ReportWidget
13. dbo.SecurityLog
14. dbo.TarekTest
15. dbo.TenantLog
16. dbo.TenantPermission
17. dbo.TenantSectionPermission
18. dbo.ULDLabelFileMapping
19. dbo.ULDPrefix
20. dbo.UserIpAddress
21. dbo.Weather
22. dbo.AP_StandardService
23. dbo.ReportScheduleParameter

## Stored Procedure Usage Grouping

### Stored procedure usage: None found

1. dbo.APIEndpoint
2. dbo.CreateKitOrder
3. dbo.CreateKitOrderLine
4. dbo.LogFile
5. dbo.NumberingSequances
6. dbo.ReportStockOnHand
7. dbo.ReportWidget
8. dbo.TarekTest
9. dbo.TenantLog
10. dbo.UserIpAddress
11. dbo.Weather
12. dbo.APIEndpoint

## Detailed Usage By Table

The descriptions below are inferred from table names and observed stored procedure access patterns.

### dbo.APIEndpoint

- Description: API endpoint configuration/metadata table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.Connote

- Description: Consignment note/shipping reference data.
- Stored procedure usage:
  - dbo.SP_VI_TBL_Wave_CreateShipmentsForCMCPackingWave (SELECT)
- Need init data: No

### dbo.Country

- Description: Country master/lookup table.
- Stored procedure usage:
  - dbo.SP_VI_TBL_Country_ListAllCountries (SELECT)
- Need init data: Yes

### dbo.CPItemsDomestic

- Description: Domestic carrier item records.
- Stored procedure usage:
  - dbo.sp_CP_GetItemsDomestic (SELECT)
- Need init data: No

### dbo.CPManifest

- Description: Carrier manifest data.
- Stored procedure usage:
  - dbo.sp_CP_createManifest (SELECT)
  - dbo.sp_CP_Update_Manifest_JobNumber (UPDATE)
- Need init data: No

### dbo.CPShipmentDomestic

- Description: Domestic shipment records.
- Stored procedure usage:
  - dbo.sp_CP_GetShipmentDomestic (SELECT)
  - dbo.sp_CP_Update_ShipmentDomestic_QuoteResponse (UPDATE)
  - dbo.sp_CP_Update_ShipmentDomestic_ShipmentResponse (UPDATE)
- Need init data: No

### dbo.CreateKitOrder

- Description: Kitting order header table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.CreateKitOrderLine

- Description: Kitting order line table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.LogFile

- Description: Log file metadata/content table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.MobileVersionInfo

- Description: Mobile app version metadata.
- Stored procedure usage:
  - dbo.SP_VI_TBL_MobileVersionInfo_ListAllMobileVersionInfo (SELECT)
- Need init data: No

### dbo.NumberingSequances

- Description: Numbering sequence configuration.
- Stored procedure usage: None found.
- Need init data: No

### dbo.PickingResult

- Description: Picking outcome/result records.
- Stored procedure usage:
  - dbo.SP_VI_TBL_Service_CheckValidBeforeCompleteKittingService (SELECT)
  - dbo.SP_VI_TBL_Service_CompletePickingTaskOfKitting (INSERT)
  - dbo.SP_VI_TBL_Service_StartPickingTaskOfKitting (SELECT)
  - dbo.SP_VI_TBL_Service_ViewKittingResultsOfService (SELECT)
  - dbo.SP_VI_TBL_Wave_CompletePickingTask (INSERT)
  - dbo.SP_VI_TBL_Wave_UpdateStockStatus (SELECT)
- Need init data: No

### dbo.ReportDefinition

- Description: Report definition and scheduling metadata.
- Stored procedure usage:
  - dbo.SP_VI_TBL_ReportData_ListReportData (SELECT)
  - dbo.SP_VI_TBL_ReportData_ListReportDataByTenant (SELECT)
  - dbo.SP_VI_TBL_ReportDefinition_GetAllManualReportDefinitions (SELECT)
  - dbo.SP_VI_TBL_ReportDefinition_GetTodayReportDefinitions (SELECT)
  - dbo.SP_VI_TBL_ReportDefinition_ListReportDefinitions (SELECT)
  - dbo.SP_VI_TBL_ReportDefinition_ViewAppliedReportDefinitionByTenant (SELECT)
  - dbo.SP_VI_TBL_ReportDefinition_ViewAppliedTenantById (SELECT)
  - dbo.SP_VI_TBL_ReportScript_InvoiceMonthlyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_InvoiceWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_ReceivingDetailWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_ReceivingSummaryWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockExpiredAlertDailyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockOnHandDailyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockOnHandDetailDailyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockOnHandDetailMonthlyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockOnHandDetailWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockOnHandMonthlyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockOnHandWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockReachLimitDailyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockTakeDetailWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_StockTakeSummaryWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_SummaryInvoiceWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportScript_TotalInvoiceWeeklyReport (SELECT)
  - dbo.SP_VI_TBL_ReportWidget_ListAllReportWidgets (SELECT)
- Need init data: Yes

### dbo.ReportScheduleParameter

- Description: Report schedule parameter table.
- Stored procedure usage:
  - dbo.SP_VI_TBL_ReportSchedule_DeleteReportSchedule (UPDATE)
- Need init data: Yes

### dbo.ReportStockOnHand

- Description: Materialized/reporting stock-on-hand table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.ReportWidget

- Description: Report widget definition table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.SecurityLog

- Description: Security event/audit log table.
- Stored procedure usage:
  - dbo.SP_VI_TBL_Log_ListLogs (SELECT)
- Need init data: No

### dbo.Setting

- Description: System/tenant settings table.
- Stored procedure usage:
  - dbo.SP_VI_TBL_Loc_GetAvailableLocationNumber (SELECT)
  - dbo.SP_VI_TBL_Loc_InsertBulkLocation (SELECT)
  - dbo.SP_VI_TBL_Loc_InsertPerfectPickLocation (SELECT)
  - dbo.SP_VI_TBL_Loc_InsertSingleLocation (SELECT)
  - dbo.SP_VI_TBL_Loc_ResetOrderNumber (SELECT)
  - dbo.SP_VI_TBL_LocArea_UpdateLocArea (SELECT)
  - dbo.SP_VI_TBL_LocColumn_UpdateLocColumn (SELECT)
  - dbo.SP_VI_TBL_LocRow_UpdateLocRow (SELECT)
  - dbo.SP_VI_TBL_LocSection_UpdateLocSection (SELECT)
- Need init data: Yes

### dbo.TarekTest

- Description: Test/sandbox table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.TenantLog

- Description: Tenant log table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.TenantPermission

- Description: Tenant-level permission mapping.
- Stored procedure usage:
  - dbo.SP_VI_TBL_TenantPermission_ListAllTenantPermissions (SELECT)
  - dbo.SP_VI_TBL_TenantSectionPermission_ListAllTenantSectionPermissions (SELECT)
- Need init data: No

### dbo.TenantSectionPermission

- Description: Tenant section permission mapping.
- Stored procedure usage:
  - dbo.SP_VI_TBL_TenantSectionPermission_ListAllTenantSectionPermissions (SELECT)
  - dbo.SP_VI_TBL_TenantSectionPermission_ListAllTenantSectionPermissionsByTenantPermissionID (SELECT)
- Need init data: No

### dbo.ULDLabelFileMapping

- Description: ULD label-to-file mapping table.
- Stored procedure usage:
  - dbo.SP_VI_TBL_Wave_CreateShipmentsForCMCPackingWave (SELECT)
- Need init data: No

### dbo.ULDPrefix

- Description: ULD prefix/number sequence configuration.
- Stored procedure usage:
  - dbo.SP_VI_TBL_Service_CompleteKittingService (SELECT, UPDATE)
  - dbo.SP_VI_TBL_ULD_CopyULDIntoExistedLocation (SELECT, UPDATE)
  - dbo.SP_VI_TBL_ULD_CopyULDIntoNewTemporaryLocation (SELECT, UPDATE)
  - dbo.SP_VI_TBL_ULD_InsertULDFromReceipt (SELECT, UPDATE)
- Need init data: No

### dbo.UserIpAddress

- Description: User IP tracking table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.Weather

- Description: Weather data table.
- Stored procedure usage: None found.
- Need init data: No

### dbo.Widget

- Description: Widget master/configuration table.
- Stored procedure usage:
  - dbo.SP_VI_TBL_Widget_ListAllWidgets (SELECT)
- Need init data: Yes
