# Stored Procedures Index

**Total:** 562 stored procedures  
**Schema:** `dbo`  
**Database:** `3PLWMS_Developers`  
**Last Script Date:** 3 February 2026

---

## Table of Contents

- [Stored Procedures Index](#stored-procedures-index)
  - [Table of Contents](#table-of-contents)
  - [1. Australia Post (AP) — Integration \& Shipment](#1-australia-post-ap--integration--shipment)
  - [2. API Management](#2-api-management)
  - [3. Bay \& Bin Tenant Allocation](#3-bay--bin-tenant-allocation)
  - [4. Carrier \& Carrier Lines](#4-carrier--carrier-lines)
  - [5. Charge Groups \& Charge Items](#5-charge-groups--charge-items)
  - [6. CMC Packing Wave](#6-cmc-packing-wave)
  - [7. Country](#7-country)
  - [8. CourierPlease (CP) — Integration \& Shipment](#8-courierplease-cp--integration--shipment)
  - [9. Current Warehouse Printer / User](#9-current-warehouse-printer--user)
  - [10. Dashboard \& Widgets](#10-dashboard--widgets)
  - [11. DHL — Integration \& Shipment](#11-dhl--integration--shipment)
  - [12. DOTWMS Sort Labels](#12-dotwms-sort-labels)
  - [13. Fulfilment \& Fulfilment Lines](#13-fulfilment--fulfilment-lines)
  - [14. Investigating Items](#14-investigating-items)
  - [15. Invoice](#15-invoice)
  - [16. IP Address Status List (Rate Limiting / Blocking)](#16-ip-address-status-list-rate-limiting--blocking)
  - [17. Item Charge Groups, Composites \& Trade Units](#17-item-charge-groups-composites--trade-units)
  - [18. Items (Stock)](#18-items-stock)
  - [19. Location Hierarchy](#19-location-hierarchy)
    - [Warehouse](#warehouse)
    - [Area](#area)
    - [Section](#section)
    - [Row](#row)
    - [Column](#column)
    - [Shelf](#shelf)
    - [Bin](#bin)
    - [Sub-Bin (SBin)](#sub-bin-sbin)
    - [Temporary Location](#temporary-location)
    - [Location Utilities](#location-utilities)
  - [20. Logging](#20-logging)
  - [21. Manifest](#21-manifest)
  - [22. Manual Integration](#22-manual-integration)
  - [23. Mobile Devices \& Version Info](#23-mobile-devices--version-info)
  - [24. On Hold Orders](#24-on-hold-orders)
  - [25. Order History](#25-order-history)
  - [26. Orders \& Order Lines](#26-orders--order-lines)
  - [27. Packing Results](#27-packing-results)
  - [28. Receipt Inbound \& Receipt Inbound Lines](#28-receipt-inbound--receipt-inbound-lines)
  - [29. Reports](#29-reports)
  - [30. Report Dashboard Config](#30-report-dashboard-config)
  - [31. Report Data](#31-report-data)
  - [32. Report Definitions](#32-report-definitions)
  - [33. Report Schedules](#33-report-schedules)
  - [34. Report Scripts](#34-report-scripts)
  - [35. Section Printers](#35-section-printers)
  - [36. Services (Kitting, Stock Take, Other)](#36-services-kitting-stock-take-other)
  - [37. Service Lines](#37-service-lines)
  - [38. Shipments](#38-shipments)
  - [39. Standard Boxes](#39-standard-boxes)
  - [40. Tenants](#40-tenants)
  - [41. Tenant Permissions \& Section Permissions](#41-tenant-permissions--section-permissions)
  - [42. Tenant Custom Costs](#42-tenant-custom-costs)
  - [43. ULD (Unit Load Device)](#43-uld-unit-load-device)
  - [44. ULD Lines](#44-uld-lines)
  - [45. User Permissions](#45-user-permissions)
  - [46. Users](#46-users)
  - [47. Warehouse Printers](#47-warehouse-printers)
  - [48. Wave \& Wave Lines](#48-wave--wave-lines)
  - [49. Widget](#49-widget)

---

## 1. Australia Post (AP) — Integration & Shipment

| Stored Procedure | Description |
|---|---|
| `dbo.sp_CP_createManifest` | Create a CourierPlease manifest |
| `dbo.sp_CP_GetItemsDomestic` | Get domestic CP items |
| `dbo.sp_CP_GetShipmentDomestic` | Get domestic CP shipment |
| `dbo.sp_CP_Update_Manifest_JobNumber` | Update manifest job number |
| `dbo.sp_CP_Update_ShipmentDomestic_QuoteResponse` | Update domestic shipment with quote response |
| `dbo.sp_CP_Update_ShipmentDomestic_ShipmentResponse` | Update domestic shipment with shipment response |
| `dbo.SP_VI_TBL_APIntegration_DeleteIntegration` | Delete an AP integration record |
| `dbo.SP_VI_TBL_APIntegration_DeleteStandardService` | Delete a standard AP service |
| `dbo.SP_VI_TBL_APIntegration_InsertIntegration` | Insert a new AP integration |
| `dbo.SP_VI_TBL_APIntegration_InsertStandardService` | Insert a standard AP service |
| `dbo.SP_VI_TBL_APIntegration_ListAllServicesByIds` | List all AP services by IDs |
| `dbo.SP_VI_TBL_APIntegration_ListAllStandardServices` | List all AP standard services |
| `dbo.SP_VI_TBL_APIntegration_ListStandardServices` | List AP standard services (paginated) |
| `dbo.SP_VI_TBL_APIntegration_UpdateIntegration` | Update an AP integration |
| `dbo.SP_VI_TBL_APIntegration_UpdateStandardService` | Update a standard AP service |
| `dbo.SP_VI_TBL_APIntegration_ViewIntegration` | View a single AP integration |
| `dbo.SP_VI_TBL_APIntegration_ViewIntegrationByTenant` | View AP integration by tenant |
| `dbo.SP_VI_TBL_APIntegration_ViewIntegrationByTenantAndWarehouse` | View AP integration by tenant and warehouse |
| `dbo.SP_VI_TBL_APIntegration_ViewIntegrationServiceByTenantAndWarehouse` | View AP integration service by tenant and warehouse |
| `dbo.SP_VI_TBL_APIntegration_ViewStandardService` | View a single AP standard service |
| `dbo.SP_VI_TBL_APIntegrationLine_ViewIntegrationLinesByID` | View AP integration lines by ID |
| `dbo.SP_VI_TBL_APShipment_DeleteAPShipment` | Delete an AP shipment |
| `dbo.SP_VI_TBL_APShipment_InsertAPIntShipment` | Insert an AP international shipment |
| `dbo.SP_VI_TBL_APShipment_InsertAPLocalShipment` | Insert an AP local shipment |
| `dbo.SP_VI_TBL_APShipment_InsertAPManifest` | Insert an AP manifest |
| `dbo.SP_VI_TBL_APShipment_InsertAPShipment` | Insert a generic AP shipment |
| `dbo.SP_VI_TBL_APShipment_InsertManualAPIntShipment` | Insert a manual AP international shipment |
| `dbo.SP_VI_TBL_APShipment_InsertManualAPLocalShipment` | Insert a manual AP local shipment |
| `dbo.SP_VI_TBL_APShipment_ViewAPIntShipment` | View an AP international shipment |
| `dbo.SP_VI_TBL_APShipment_ViewAPLocalShipment` | View an AP local shipment |
| `dbo.SP_VI_TBL_APShipment_ViewShipmentInfoOfOrders` | View AP shipment info for given orders |
| `dbo.SP_VI_TBL_APShipmentItem_ViewAPIntShipmentItemsByID` | View AP international shipment items by ID |
| `dbo.SP_VI_TBL_APShipmentItem_ViewAPLocalShipmentItemsByID` | View AP local shipment items by ID |
| `dbo.SP_VI_TBL_APShipmentItems_AddItems` | Add items to an AP shipment |

---

## 2. API Management

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_API_DeleteAPI` | Delete an API record |
| `dbo.SP_VI_TBL_API_InsertAPI` | Insert a new API record |
| `dbo.SP_VI_TBL_API_ListAPIs` | List APIs (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_API_UpdateAPI` | Update an API record |
| `dbo.SP_VI_TBL_API_ViewAPI` | View a single API record |

---

## 3. Bay & Bin Tenant Allocation

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_BayTenantAllocation_AllocateForTenant` | Allocate a bay to a tenant |
| `dbo.SP_VI_TBL_BayTenantAllocation_CheckValidReAllocate` | Check if bay re-allocation is valid |
| `dbo.SP_VI_TBL_BayTenantAllocation_GetAllAllocatedOfTenant` | Get all bay allocations of a tenant |
| `dbo.SP_VI_TBL_BayTenantAllocation_ReAllocate` | Re-allocate a bay to a different tenant |
| `dbo.SP_VI_TBL_BinTenantAllocation_AllocateForTenant` | Allocate a bin to a tenant |
| `dbo.SP_VI_TBL_BinTenantAllocation_CheckValidReAllocate` | Check if bin re-allocation is valid |
| `dbo.SP_VI_TBL_BinTenantAllocation_GetAllAllocatedOfTenant` | Get all bin allocations of a tenant |
| `dbo.SP_VI_TBL_BinTenantAllocation_ReAllocate` | Re-allocate a bin to a different tenant |

---

## 4. Carrier & Carrier Lines

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Carrier_DeleteCarrier` | Delete a carrier |
| `dbo.SP_VI_TBL_Carrier_InsertCarrier` | Insert a new carrier |
| `dbo.SP_VI_TBL_Carrier_ListCarriers` | List carriers (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Carrier_UpdateCarrier` | Update a carrier |
| `dbo.SP_VI_TBL_Carrier_ViewCarrier` | View a single carrier |
| `dbo.SP_VI_TBL_CarrierLine_DeleteCarrierLine` | Delete a carrier line |
| `dbo.SP_VI_TBL_CarrierLine_InsertCarrierLine` | Insert a new carrier line |
| `dbo.SP_VI_TBL_CarrierLine_ListCarrierLines` | List carrier lines (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_CarrierLine_UpdateCarrierLine` | Update a carrier line |
| `dbo.SP_VI_TBL_CarrierLine_ViewCarrierLine` | View a single carrier line |
| `dbo.SP_VI_TBL_CarrierLine_ViewCarrierLineByCarrierID` | View carrier lines by carrier ID |

---

## 5. Charge Groups & Charge Items

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ChargeGroup_DeleteChargeGroup` | Delete a charge group |
| `dbo.SP_VI_TBL_ChargeGroup_InsertChargeGroup` | Insert a new charge group |
| `dbo.SP_VI_TBL_ChargeGroup_ListChargeGroups` | List charge groups (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_ChargeGroup_ListChargeGroupsByCategory` | List charge groups filtered by category |
| `dbo.SP_VI_TBL_ChargeGroup_UpdateChargeGroup` | Update a charge group |
| `dbo.SP_VI_TBL_ChargeGroup_ViewChargeGroupCost` | View cost info of a charge group |
| `dbo.SP_VI_TBL_ChargeItem_ApplyChargeItem` | Apply a charge item to tenants |
| `dbo.SP_VI_TBL_ChargeItem_CheckZeroCost` | Check if any charge item has zero cost |
| `dbo.SP_VI_TBL_ChargeItem_ConvertTenant2Custom` | Convert a tenant charge item to a custom charge item |
| `dbo.SP_VI_TBL_ChargeItem_DeleteChargeItem` | Delete a charge item |
| `dbo.SP_VI_TBL_ChargeItem_GetAppliedStatusById` | Get the applied status of a charge item by ID |
| `dbo.SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode` | Get cost info for a tenant by warehouse code |
| `dbo.SP_VI_TBL_ChargeItem_InsertChargeItem` | Insert a new charge item |
| `dbo.SP_VI_TBL_ChargeItem_ListChargeItems` | List charge items (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_ChargeItem_UpdateAppliedTenantsStatusOfChargeItem` | Update applied status for multiple tenants on a charge item |
| `dbo.SP_VI_TBL_ChargeItem_UpdateAppliedTenantStatus` | Update applied status for a single tenant |
| `dbo.SP_VI_TBL_ChargeItem_UpdateAppliedTenantStatusOfChargeItems` | Update applied tenant status across multiple charge items |
| `dbo.SP_VI_TBL_ChargeItem_UpdateChargeItem` | Update a charge item |
| `dbo.SP_VI_TBL_ChargeItem_ViewAppliedChargeItemByTenant` | View charge items applied to a tenant |
| `dbo.SP_VI_TBL_ChargeItem_ViewAppliedTenantById` | View tenants applied to a charge item by ID |
| `dbo.SP_VI_TBL_ChargeItem_ViewChargeItem` | View a single charge item |
| `dbo.SP_VI_TBL_ChargeItemCost_InsertChargeItemCostById` | Insert charge item cost by ID |
| `dbo.SP_VI_TBL_ChargeItemCost_ListChargeItemCostById` | List charge item costs by ID |
| `dbo.SP_VI_TBL_ChargeItemCost_UpdateChargeItemCostById` | Update charge item cost by ID |

---

## 6. CMC Packing Wave

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_CMCPackingWaveResult_GetPendingItemByWaveNumber` | Get pending CMC packing wave items by wave number |

---

## 7. Country

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Country_ListAllCountries` | List all countries |

---

## 8. CourierPlease (CP) — Integration & Shipment

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_CPIntegration_DeleteIntegration` | Delete a CP integration |
| `dbo.SP_VI_TBL_CPIntegration_InsertIntegration` | Insert a new CP integration |
| `dbo.SP_VI_TBL_CPIntegration_UpdateIntegration` | Update a CP integration |
| `dbo.SP_VI_TBL_CPIntegration_ViewIntegration` | View a single CP integration |
| `dbo.SP_VI_TBL_CPIntegration_ViewIntegrationByTenant` | View CP integration by tenant |
| `dbo.SP_VI_TBL_CPIntegration_ViewIntegrationByTenantAndWarehouse` | View CP integration by tenant and warehouse |
| `dbo.SP_VI_TBL_CPIntegrationLine_ViewIntegrationLinesByID` | View CP integration lines by ID |

---

## 9. Current Warehouse Printer / User

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_CurrentWarehousePrinterUser_GetCurrentWarehousePrinterOfUser` | Get the current warehouse printer assigned to a user |
| `dbo.SP_VI_TBL_CurrentWarehousePrinterUser_ResetWarehousePrinterOfUser` | Reset the warehouse printer assignment for a user |
| `dbo.SP_VI_TBL_CurrentWarehousePrinterUser_SetCurrentWarehousePrinterForUser` | Set the current warehouse printer for a user |

---

## 10. Dashboard & Widgets

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Dashboard_GetDashboardInfo` | Get general dashboard info |
| `dbo.SP_VI_TBL_Dashboard_GetOrderHistoryWidget` | Get order history widget data |
| `dbo.SP_VI_TBL_Dashboard_GetOrderSourceDetail` | Get order source detail (paginated) |
| `dbo.SP_VI_TBL_Dashboard_GetOrderSourceWidget` | Get order source widget summary |
| `dbo.SP_VI_TBL_Dashboard_GetOrderStatusDetail` | Get order status detail (paginated) |
| `dbo.SP_VI_TBL_Dashboard_GetOrderStatusWidget` | Get order status widget summary |
| `dbo.SP_VI_TBL_DashboardConfig_DeleteDashboardConfig` | Delete a dashboard configuration |
| `dbo.SP_VI_TBL_DashboardConfig_InsertDashboardConfig` | Insert a new dashboard configuration |
| `dbo.SP_VI_TBL_DashboardConfig_ListDashboardConfigs` | List dashboard configurations (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_DashboardConfig_UpdateDashboardConfig` | Update a dashboard configuration |
| `dbo.SP_VI_TBL_DashboardConfig_ViewDashboardConfig` | View a single dashboard configuration |
| `dbo.SP_VI_TBL_Widget_ListAllWidgets` | List all dashboard widgets |

---

## 11. DHL — Integration & Shipment

| Stored Procedure | Description |
|---|---|
| `dbo.sp_DHL_Response` | Process raw DHL response |
| `dbo.sp_DHL_Response_JSON` | Process DHL response as JSON (dynamic SQL) |
| `dbo.sp_DHLGetImageOptions` | Get DHL image options |
| `dbo.sp_DHLGetShipmentData` | Get DHL shipment data |
| `dbo.sp_DHLGetShipmentLineItems` | Get DHL shipment line items |
| `dbo.sp_DHLGetShipmentPackages` | Get DHL shipment packages |
| `dbo.SP_VI_TBL_DHLIntegration_DeleteIntegration` | Delete a DHL integration |
| `dbo.SP_VI_TBL_DHLIntegration_InsertIntegration` | Insert a new DHL integration |
| `dbo.SP_VI_TBL_DHLIntegration_UpdateIntegration` | Update a DHL integration |
| `dbo.SP_VI_TBL_DHLIntegration_ViewIntegration` | View a single DHL integration |
| `dbo.SP_VI_TBL_DHLIntegration_ViewIntegrationByTenant` | View DHL integration by tenant |
| `dbo.SP_VI_TBL_DHLIntegration_ViewIntegrationByTenantAndWarehouse` | View DHL integration by tenant and warehouse |
| `dbo.SP_VI_TBL_DHLIntegrationLine_ViewIntegrationLinesByID` | View DHL integration lines by ID |
| `dbo.SP_VI_TBL_DHLPackages_AddPackages` | Add packages to a DHL shipment |
| `dbo.SP_VI_TBL_DHLShipment_DeleteDHLShipment` | Delete a DHL shipment |
| `dbo.SP_VI_TBL_DHLShipment_GetTrackingNumber` | Get DHL shipment tracking number |
| `dbo.SP_VI_TBL_DHLShipment_InsertDHLShipment` | Insert a new DHL shipment |
| `dbo.SP_VI_TBL_DHLShipment_InsertManualDHLShipment` | Insert a manual DHL shipment |
| `dbo.SP_VI_TBL_DHLShipment_ViewDHLShipment` | View a DHL shipment |

---

## 12. DOTWMS Sort Labels

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_DOTWMS_GetSortLabelInfo` | Get sort label info for DOTWMS |
| `dbo.SP_VI_TBL_DOTWMS_InsertSortLabelInfo` | Insert sort label info for DOTWMS |

---

## 13. Fulfilment & Fulfilment Lines

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment` | Copy orders to fulfilment (supports Orders, Kitting, Release Stock, Destroy Stock types) |
| `dbo.SP_VI_TBL_Fulfilment_DeleteShipment` | Delete a fulfilment shipment |
| `dbo.SP_VI_TBL_Fulfilment_ListAvailableFulfilments` | List fulfilments available for processing |
| `dbo.SP_VI_TBL_Fulfilment_ListAvailableMailingFulfilmentOrders` | List fulfilment orders available for mailing (paginated) |
| `dbo.SP_VI_TBL_Fulfilment_ListFulfilmentsByStatus` | List fulfilments filtered by status (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Fulfilment_SearchFulfilments` | Search fulfilments with full-text and filters (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Fulfilment_SearchFulfilmentsByStatus` | Search fulfilments by status (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Fulfilment_UpdateFulfilment` | Update a fulfilment record |
| `dbo.SP_VI_TBL_Fulfilment_UpdateTrackingInfo` | Update tracking info on a fulfilment |
| `dbo.SP_VI_TBL_Fulfilment_ViewFulfilmentByOrderNumber` | View fulfilment by order number |
| `dbo.SP_VI_TBL_Fulfilment_ViewShipmentBoxesByOrderNumber` | View shipment boxes for a fulfilment order |
| `dbo.SP_VI_TBL_FulfilmentLine_ViewFulfilmentLinesByIDs` | View fulfilment lines by IDs |
| `dbo.SP_VI_TBL_FulfilmentLine_ViewFulfilmentLinesByManualShipmentOrderNumbers` | View fulfilment lines by manual shipment order numbers |
| `dbo.SP_VI_TBL_FulfilmentLine_ViewFulfilmentLinesByOrderNumbers` | View fulfilment lines by order numbers |

---

## 14. Investigating Items

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_InvestigatingItems_InsertInvestigatingItem` | Insert an item under investigation |

---

## 15. Invoice

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Invoice_AutoCreatingBayAllocationInvoices` | Auto-create bay allocation invoices |
| `dbo.SP_VI_TBL_Invoice_AutoCreatingITFlatformInvoices` | Auto-create IT platform invoices |
| `dbo.SP_VI_TBL_Invoice_AutoCreatingPalletStorageInvoices` | Auto-create pallet storage invoices |
| `dbo.SP_VI_TBL_Invoice_CompleteReceivingInvoice` | Mark a receiving invoice as complete |
| `dbo.SP_VI_TBL_Invoice_InsertAPMailingInvoice` | Insert an AP mailing invoice |
| `dbo.SP_VI_TBL_Invoice_InsertBayAllocationInvoice` | Insert a bay allocation invoice |
| `dbo.SP_VI_TBL_Invoice_InsertBinAllocationInvoice` | Insert a bin allocation invoice |
| `dbo.SP_VI_TBL_Invoice_InsertChargeGroupInvoice` | Insert a charge group invoice |
| `dbo.SP_VI_TBL_Invoice_InsertDHLMailingInvoice` | Insert a DHL mailing invoice |
| `dbo.SP_VI_TBL_Invoice_InsertLabourServiceInvoice` | Insert a labour service invoice |
| `dbo.SP_VI_TBL_Invoice_InsertMailingInvoice` | Insert a generic mailing invoice |
| `dbo.SP_VI_TBL_Invoice_InsertOtherServiceInvoice` | Insert an other-service invoice |
| `dbo.SP_VI_TBL_Invoice_InsertPackingInvoice` | Insert a packing invoice |
| `dbo.SP_VI_TBL_Invoice_InsertPalletStorageInvoice` | Insert a pallet storage invoice |
| `dbo.SP_VI_TBL_Invoice_InsertPickingInvoice` | Insert a picking invoice |
| `dbo.SP_VI_TBL_Invoice_InsertReceivingInvoice` | Insert a receiving invoice |
| `dbo.SP_VI_TBL_Invoice_ListInvoices` | List invoices (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Invoice_SearchInvoices` | Search invoices with full-text and date filters (paginated, dynamic sort) |

---

## 16. IP Address Status List (Rate Limiting / Blocking)

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_IPAddressStatusList_InsertIPAddressStatusList` | Insert an IP address status record |
| `dbo.SP_VI_TBL_IPAddressStatusList_IsIPAddressBlocked` | Check if an IP address is currently blocked |
| `dbo.SP_VI_TBL_IPAddressStatusList_ListIPAddressStatusLists` | List IP address status records (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_IPAddressStatusList_RecordIPAddressStatus` | Record a failed attempt for an IP; auto-block after 5 failures |
| `dbo.SP_VI_TBL_IPAddressStatusList_ResetIPAddressStatus` | Reset failed count and unblock an IP address |
| `dbo.SP_VI_TBL_IPAddressStatusList_UpdateIPAddressStatusList` | Update an IP address status record |
| `dbo.SP_VI_TBL_IPAddressStatusList_ViewIPAddressStatusList` | View a single IP address status record |

---

## 17. Item Charge Groups, Composites & Trade Units

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ItemChargeGroup_ViewItemChargeGroupByItemId` | View charge group assigned to an item |
| `dbo.SP_VI_TBL_ItemComposite_ViewItemCompositeByItemId` | View composite item details by item ID |
| `dbo.SP_VI_TBL_ItemKitingCost_ViewItemKitingCostByItemId` | View kitting cost for an item by ID |
| `dbo.SP_VI_TBL_ItemTradeUnit_ViewItemTradeUnitByItemId` | View trade unit info for an item by ID |

---

## 18. Items (Stock)

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Items_CheckAvailableStockForKitting` | Check available stock for a kitting service |
| `dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder` | Check available stock for an order |
| `dbo.SP_VI_TBL_Items_CheckAvailableStockForOrderInLocation` | Check available stock for an order in a specific location |
| `dbo.SP_VI_TBL_Items_CheckAvailableStockOfItemsInLocation` | Check available stock of multiple items in a location |
| `dbo.SP_VI_TBL_Items_DeleteItem` | Soft-delete an item |
| `dbo.SP_VI_TBL_Items_GetAllChildrenItemsOfCompositeItem` | Get all child items of a composite item |
| `dbo.SP_VI_TBL_Items_GetStockOnHandOfTenantItem` | Get stock on hand for a specific tenant item |
| `dbo.SP_VI_TBL_Items_InsertItem` | Insert a new item |
| `dbo.SP_VI_TBL_Items_ListAllItems` | List all items for a tenant |
| `dbo.SP_VI_TBL_Items_ListItems` | List items (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Items_SearchItemByBarcodeAndTenantCode` | Search items by barcode and tenant code |
| `dbo.SP_VI_TBL_Items_SearchItemByBarcodeAndTenantCodeAndULDBarcode` | Search items by barcode, tenant, and ULD barcode |
| `dbo.SP_VI_TBL_Items_SearchItemCodeAndItemNameByTenantCode` | Search item code and name by tenant code |
| `dbo.SP_VI_TBL_Items_SearchItemCodeByTenantCode` | Search item code by tenant code |
| `dbo.SP_VI_TBL_Items_SearchMaterialItemByBarcodeAndTenantCode` | Search material items by barcode and tenant code |
| `dbo.SP_VI_TBL_Items_UpdateItem` | Update an item |
| `dbo.SP_VI_TBL_Items_ViewItem` | View a single item |
| `dbo.SP_VI_TBL_Items_ViewULDLinesOfTenantItemInWarehouse` | View ULD lines for a tenant item in a warehouse (paginated) |

---

## 19. Location Hierarchy

### Warehouse
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocWarehouse_DeleteLocWarehouse` | Delete a warehouse location |
| `dbo.SP_VI_TBL_LocWarehouse_InsertSingleWarehouseLocation` | Insert a single warehouse location |
| `dbo.SP_VI_TBL_LocWarehouse_ListLocWarehouses` | List warehouse locations |
| `dbo.SP_VI_TBL_LocWarehouse_UpdateLocWarehouse` | Update a warehouse location |
| `dbo.SP_VI_TBL_LocWarehouse_ViewLocWarehouse` | View a warehouse location |
| `dbo.SP_VI_TBL_LocWarehouse_ViewShipmentAccountWarehouse` | View shipment account warehouse |

### Area
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocArea_DeleteLocArea` | Delete a location area |
| `dbo.SP_VI_TBL_LocArea_ListAllAreasByWarehouseId` | List all areas in a warehouse |
| `dbo.SP_VI_TBL_LocArea_ListLocArea` | List location areas (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_LocArea_UpdateLocArea` | Update a location area |
| `dbo.SP_VI_TBL_LocArea_ViewLocArea` | View a location area |

### Section
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocSection_DeleteLocSection` | Delete a location section |
| `dbo.SP_VI_TBL_LocSection_ListAllSectionsByAreaId` | List all sections in an area |
| `dbo.SP_VI_TBL_LocSection_ListLocSection` | List location sections (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_LocSection_UpdateLocSection` | Update a location section |
| `dbo.SP_VI_TBL_LocSection_ViewLocSection` | View a location section |

### Row
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocRow_DeleteLocRow` | Delete a location row |
| `dbo.SP_VI_TBL_LocRow_ListAllRowsBySectionId` | List all rows in a section |
| `dbo.SP_VI_TBL_LocRow_ListLocRow` | List location rows (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_LocRow_UpdateLocRow` | Update a location row |
| `dbo.SP_VI_TBL_LocRow_ViewLocRow` | View a location row |

### Column
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocColumn_DeleteLocColumn` | Delete a location column |
| `dbo.SP_VI_TBL_LocColumn_ListAllColumnsByRowId` | List all columns in a row |
| `dbo.SP_VI_TBL_LocColumn_ListLocColumn` | List location columns (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_LocColumn_UpdateLocColumn` | Update a location column |
| `dbo.SP_VI_TBL_LocColumn_ViewLocColumn` | View a location column |

### Shelf
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocShelf_DeleteLocShelf` | Delete a shelf |
| `dbo.SP_VI_TBL_LocShelf_ListAllShelvesByColumnId` | List all shelves in a column |
| `dbo.SP_VI_TBL_LocShelf_ListLocShelf` | List shelves (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_LocShelf_UpdateLocShelf` | Update a shelf |
| `dbo.SP_VI_TBL_LocShelf_ViewLocShelf` | View a shelf |

### Bin
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocBin_DeleteLocBin` | Delete a bin |
| `dbo.SP_VI_TBL_LocBin_ListAllBinsByShelfId` | List all bins on a shelf |
| `dbo.SP_VI_TBL_LocBin_ListLocBin` | List bins (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_LocBin_UpdateLocBin` | Update a bin |
| `dbo.SP_VI_TBL_LocBin_ViewLocBin` | View a bin |

### Sub-Bin (SBin)
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocSBin_DeleteLocSBin` | Delete a sub-bin |
| `dbo.SP_VI_TBL_LocSBin_ListAllSBinsByBinId` | List all sub-bins in a bin |
| `dbo.SP_VI_TBL_LocSBin_ListLocSBin` | List sub-bins (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_LocSBin_UpdateLocSBin` | Update a sub-bin |
| `dbo.SP_VI_TBL_LocSBin_ViewLocSBin` | View a sub-bin |

### Temporary Location
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_LocTempLocation_CheckLocationAvailable` | Check if a temp location is available |
| `dbo.SP_VI_TBL_LocTempLocation_DeleteEmptyLocTempLocations` | Delete all empty temp locations |
| `dbo.SP_VI_TBL_LocTempLocation_DeleteLocTempLocation` | Delete a specific temp location |
| `dbo.SP_VI_TBL_LocTempLocation_GetLocationBarcode` | Get the barcode of a temp location |
| `dbo.SP_VI_TBL_LocTempLocation_InsertTemporaryLocation` | Insert a new temporary location |
| `dbo.SP_VI_TBL_LocTempLocation_ListLocTempLocations` | List temp locations (paginated, dynamic sort) |

### Location Utilities
| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Loc_ChangePerfectPickDivider` | Change the perfect pick divider for a location |
| `dbo.SP_VI_TBL_Loc_CheckLocationAvailable` | Check if a location is available |
| `dbo.SP_VI_TBL_Loc_CheckLocationAvailableAtWarehouse` | Check if a location is available at a warehouse |
| `dbo.SP_VI_TBL_Loc_GetAllAllocatedPalletOfTenant` | Get all pallet allocations for a tenant |
| `dbo.SP_VI_TBL_Loc_GetAvailableLocationNumber` | Get next available location number |
| `dbo.SP_VI_TBL_Loc_GetFullLocationInfoFromCode` | Get full location info from a location code |
| `dbo.SP_VI_TBL_Loc_GetFullLocationInfoFromCodes` | Get full location info for multiple codes |
| `dbo.SP_VI_TBL_Loc_GetLocationBarcode` | Get barcode for a location |
| `dbo.SP_VI_TBL_Loc_GetLocationBarcodesByArea` | Get all barcodes for locations in an area |
| `dbo.SP_VI_TBL_Loc_GetLocationBarcodesByBin` | Get all barcodes for locations in a bin |
| `dbo.SP_VI_TBL_Loc_GetLocationBarcodesByColumn` | Get all barcodes for locations in a column |
| `dbo.SP_VI_TBL_Loc_GetLocationBarcodesByRow` | Get all barcodes for locations in a row |
| `dbo.SP_VI_TBL_Loc_GetLocationBarcodesBySection` | Get all barcodes for locations in a section |
| `dbo.SP_VI_TBL_Loc_GetLocationInfoFromCode` | Get basic location info from a code |
| `dbo.SP_VI_TBL_Loc_GetStorageSummaryOfTenant` | Get storage summary for a tenant |
| `dbo.SP_VI_TBL_Loc_InsertBulkLocation` | Insert multiple locations at once |
| `dbo.SP_VI_TBL_Loc_InsertPerfectPickLocation` | Insert a perfect pick location |
| `dbo.SP_VI_TBL_Loc_InsertSingleLocation` | Insert a single location |
| `dbo.SP_VI_TBL_Loc_ResetOrderNumber` | Reset the order number sequence for a location |
| `dbo.SP_VI_TBL_Loc_ShowULDsOfSBin` | Show ULDs stored in a sub-bin |

---

## 20. Logging

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Log_InsertLog` | Insert a log entry (dynamic table target) |
| `dbo.SP_VI_TBL_Log_ListLogs` | List logs (paginated, dynamic SQL) |
| `dbo.SP_VI_TBL_LogAccessLink_CheckExistedLogAccessLink` | Check if a log access link already exists |
| `dbo.SP_VI_TBL_LogTypeMapping_GetLogMapping` | Get log type mapping |

---

## 21. Manifest

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Manifest_GetManifestsOfOrders` | Get manifests for given orders |
| `dbo.SP_VI_TBL_Manifest_InsertManifest` | Insert a new manifest |
| `dbo.SP_VI_TBL_Manifest_ListManifests` | List manifests (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Manifest_UpdateManifest` | Update a manifest |

---

## 22. Manual Integration

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ManualIntegration_InsertIntegration` | Insert a manual integration |
| `dbo.SP_VI_TBL_ManualIntegration_ViewIntegrationByTenantAndWarehouse` | View manual integration by tenant and warehouse |

---

## 23. Mobile Devices & Version Info

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_MobileDevice_CheckExistedMobileDevice` | Check if a mobile device already exists |
| `dbo.SP_VI_TBL_MobileDevice_InsertMobileDevice` | Register a new mobile device |
| `dbo.SP_VI_TBL_MobileDevice_ListMobileDevice` | List mobile devices (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_MobileDevice_UpdateMobileDevice` | Update a mobile device record |
| `dbo.SP_VI_TBL_MobileVersionInfo_ListAllMobileVersionInfo` | List all mobile app version info |

---

## 24. On Hold Orders

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_OnHold_ClearByOrderNumbers` | Clear on-hold status for given order numbers |
| `dbo.SP_VI_TBL_OnHold_ListOnHoldClearedOrders` | List orders that have been cleared from on-hold |
| `dbo.SP_VI_TBL_OnHold_ListOnHoldFulfilments` | List fulfilments currently on hold |
| `dbo.SP_VI_TBL_OnHold_ListOnHoldOrders` | List orders currently on hold |
| `dbo.SP_VI_TBL_OnHold_SetByOrderNumbers` | Set on-hold status for given order numbers |

---

## 25. Order History

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_OrderHistory_ViewOrderHistoryByOrderID` | View order history events by order ID |

---

## 26. Orders & Order Lines

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Orders_CancelOrder` | Cancel an order |
| `dbo.SP_VI_TBL_Orders_CheckUploadOrder` | Validate an order before upload |
| `dbo.SP_VI_TBL_Orders_CheckUploadOrderItems` | Validate order items before upload |
| `dbo.SP_VI_TBL_Orders_GetTenantInfoByOrderNumbers` | Get tenant info for given order numbers |
| `dbo.SP_VI_TBL_Orders_GetTenantInfoByShopDomains` | Get tenant info by shop domains |
| `dbo.SP_VI_TBL_Orders_InsertOrder` | Insert a new order |
| `dbo.SP_VI_TBL_Orders_StartPickingOrder` | Start the picking process for an order |
| `dbo.SP_VI_TBL_Orders_UpdateOrder` | Update an order |
| `dbo.SP_VI_TBL_Orders_ViewOrder` | View a single order |
| `dbo.SP_VI_TBL_OrdersLine_UploadOrderLine` | Upload an order line |
| `dbo.SP_VI_TBL_OrdersLine_ViewOrdersLinesByID` | View order lines by order ID |

---

## 27. Packing Results

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_PackingResult_UpdatePackingResultStatus` | Update the status of a packing result |
| `dbo.SP_VI_TBL_PackingResult_ViewPackingResultOfOrderByStatus` | View packing results for an order by status |
| `dbo.SP_VI_TBL_PackingResult_ViewPackingResultOfWaveByStatus` | View packing results for a wave by status |

---

## 28. Receipt Inbound & Receipt Inbound Lines

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ReceiptInbound_CancelReceiptReceivingProcess` | Cancel the receiving process for a receipt |
| `dbo.SP_VI_TBL_ReceiptInbound_DeleteReceiptInbound` | Delete a receipt inbound |
| `dbo.SP_VI_TBL_ReceiptInbound_GetManualReceiptInboundLineDetail` | Get manual receipt inbound line detail |
| `dbo.SP_VI_TBL_ReceiptInbound_GetPendingManualReceiptInboundDetail` | Get pending manual receipt inbound detail |
| `dbo.SP_VI_TBL_ReceiptInbound_GetPendingRandomReceiptInboundDetail` | Get pending random receipt inbound detail |
| `dbo.SP_VI_TBL_ReceiptInbound_GetRandomReceiptInboundLineDetail` | Get random receipt inbound line detail |
| `dbo.SP_VI_TBL_ReceiptInbound_GetTenantInfoOfReceiptInbound` | Get tenant info for a receipt inbound |
| `dbo.SP_VI_TBL_ReceiptInbound_InsertRandomReceiptInbound` | Insert a random receipt inbound |
| `dbo.SP_VI_TBL_ReceiptInbound_InsertReceiptInbound` | Insert a new receipt inbound |
| `dbo.SP_VI_TBL_ReceiptInbound_ListReceiptInbounds` | List receipt inbounds (paginated, dynamic SQL) |
| `dbo.SP_VI_TBL_ReceiptInbound_ListReceiptInboundsByTypeAndStatusAndTenantCode` | List receipt inbounds by type, status, and tenant |
| `dbo.SP_VI_TBL_ReceiptInbound_ListTenantsOfReceiptInboundsByTypeAndStatus` | List tenants of receipt inbounds by type and status |
| `dbo.SP_VI_TBL_ReceiptInbound_UpdateReceiptStatus` | Update the status of a receipt inbound |
| `dbo.SP_VI_TBL_ReceiptInbound_ViewReceiptInbound` | View a single receipt inbound |
| `dbo.SP_VI_TBL_ReceiptInbound_ViewULDsOfReceiptInbound` | View ULDs associated with a receipt inbound |
| `dbo.SP_VI_TBL_ReceiptInboundLine_CheckBarcodeInReceiptInboundLineById` | Check if a barcode exists in receipt inbound lines by ID |
| `dbo.SP_VI_TBL_ReceiptInboundLine_ListReceiptInboundLines` | List receipt inbound lines (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_ReceiptInboundLine_ViewReceiptInboundLineById` | View receipt inbound lines by ID |

---

## 29. Reports

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Report_DeleteReport` | Delete a report |
| `dbo.SP_VI_TBL_Report_InsertReport` | Insert a new report |
| `dbo.SP_VI_TBL_Report_ListReports` | List reports (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Report_RunReportByID` | Run a report by its ID |
| `dbo.SP_VI_TBL_Report_RunReportOfCompleteStocktake` | Run report for completed stock take |
| `dbo.SP_VI_TBL_Report_RunReportOfReceivingReceipt` | Run report for receiving receipt |
| `dbo.SP_VI_TBL_Report_UpdateReport` | Update a report |
| `dbo.SP_VI_TBL_Report_ViewReport` | View a single report |
| `dbo.SP_VI_TBL_ReportWidget_ListAllReportWidgets` | List all report widgets |

---

## 30. Report Dashboard Config

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ReportDashboardConfig_DeleteReportDashboardConfig` | Delete a report dashboard config |
| `dbo.SP_VI_TBL_ReportDashboardConfig_InsertReportDashboardConfig` | Insert a report dashboard config |
| `dbo.SP_VI_TBL_ReportDashboardConfig_ListReportDashboardConfigs` | List report dashboard configs (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_ReportDashboardConfig_UpdateReportDashboardConfig` | Update a report dashboard config |
| `dbo.SP_VI_TBL_ReportDashboardConfig_ViewReportDashboardConfig` | View a single report dashboard config |

---

## 31. Report Data

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ReportData_DownloadReportData` | Download report data (dynamic SQL) |
| `dbo.SP_VI_TBL_ReportData_ListReportData` | List report data (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_ReportData_ListReportDataByTenant` | List report data filtered by tenant |

---

## 32. Report Definitions

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ReportDefinition_ApplyReportDefinition` | Apply a report definition to tenants |
| `dbo.SP_VI_TBL_ReportDefinition_GetAllManualReportDefinitions` | Get all manual report definitions |
| `dbo.SP_VI_TBL_ReportDefinition_GetTodayReportDefinitions` | Get report definitions scheduled for today |
| `dbo.SP_VI_TBL_ReportDefinition_ListReportDefinitions` | List report definitions (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_ReportDefinition_UpdateAppliedTenantsStatusOfReportDefinition` | Update applied tenant status for a report definition |
| `dbo.SP_VI_TBL_ReportDefinition_UpdateAppliedTenantStatusOfReportDefinitions` | Update applied tenant status across multiple report definitions |
| `dbo.SP_VI_TBL_ReportDefinition_ViewAppliedReportDefinitionByTenant` | View report definitions applied to a tenant |
| `dbo.SP_VI_TBL_ReportDefinition_ViewAppliedTenantById` | View tenants applied to a report definition |

---

## 33. Report Schedules

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ReportSchedule_ApplyReportSchedule` | Apply a report schedule to tenants |
| `dbo.SP_VI_TBL_ReportSchedule_DeleteReportSchedule` | Delete a report schedule |
| `dbo.SP_VI_TBL_ReportSchedule_GetTodayReportSchedules` | Get report schedules due today |
| `dbo.SP_VI_TBL_ReportSchedule_InitReportSchedules` | Initialise report schedules |
| `dbo.SP_VI_TBL_ReportSchedule_InsertReportSchedule` | Insert a new report schedule |
| `dbo.SP_VI_TBL_ReportSchedule_ListReportSchedules` | List report schedules (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_ReportSchedule_RunReportSchedules` | Execute all due report schedules |
| `dbo.SP_VI_TBL_ReportSchedule_UpdateAppliedTenantsStatusOfReportSchedule` | Update applied tenant status for a schedule |
| `dbo.SP_VI_TBL_ReportSchedule_UpdateAppliedTenantStatusOfReportSchedules` | Update applied tenant status across multiple schedules |
| `dbo.SP_VI_TBL_ReportSchedule_UpdateReportSchedule` | Update a report schedule |
| `dbo.SP_VI_TBL_ReportSchedule_ViewAppliedReportScheduleByTenant` | View report schedules applied to a tenant |
| `dbo.SP_VI_TBL_ReportSchedule_ViewAppliedTenantById` | View tenants applied to a report schedule |
| `dbo.SP_VI_TBL_ReportSchedule_ViewReportSchedule` | View a single report schedule |

---

## 34. Report Scripts

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ReportScript_CloseJobManualReport` | Close job manual report |
| `dbo.SP_VI_TBL_ReportScript_GetReportDateRange` | Get the date range for a report |
| `dbo.SP_VI_TBL_ReportScript_InvoiceManualReport` | Generate invoice manual report |
| `dbo.SP_VI_TBL_ReportScript_InvoiceMonthlyReport` | Generate invoice monthly report |
| `dbo.SP_VI_TBL_ReportScript_InvoiceWeeklyReport` | Generate invoice weekly report |
| `dbo.SP_VI_TBL_ReportScript_OpenJobManualReport` | Open job manual report |
| `dbo.SP_VI_TBL_ReportScript_ReceivingDetailManualReport` | Generate receiving detail manual report |
| `dbo.SP_VI_TBL_ReportScript_ReceivingDetailWeeklyReport` | Generate receiving detail weekly report |
| `dbo.SP_VI_TBL_ReportScript_ReceivingSummaryManualReport` | Generate receiving summary manual report |
| `dbo.SP_VI_TBL_ReportScript_ReceivingSummaryWeeklyReport` | Generate receiving summary weekly report |
| `dbo.SP_VI_TBL_ReportScript_StockExpiredAlertDailyReport` | Daily report for expiring stock alerts |
| `dbo.SP_VI_TBL_ReportScript_StockExpiredAlertManualReport` | Manual report for expiring stock alerts |
| `dbo.SP_VI_TBL_ReportScript_StockOnHandDailyReport` | Daily stock on hand report |
| `dbo.SP_VI_TBL_ReportScript_StockOnHandDetailDailyReport` | Daily stock on hand detail report |
| `dbo.SP_VI_TBL_ReportScript_StockOnHandDetailManualReport` | Manual stock on hand detail report |
| `dbo.SP_VI_TBL_ReportScript_StockOnHandDetailMonthlyReport` | Monthly stock on hand detail report |
| `dbo.SP_VI_TBL_ReportScript_StockOnHandDetailWeeklyReport` | Weekly stock on hand detail report |
| `dbo.SP_VI_TBL_ReportScript_StockOnHandManualReport` | Manual stock on hand report |
| `dbo.SP_VI_TBL_ReportScript_StockOnHandMonthlyReport` | Monthly stock on hand report |
| `dbo.SP_VI_TBL_ReportScript_StockOnHandWeeklyReport` | Weekly stock on hand report |
| `dbo.SP_VI_TBL_ReportScript_StockReachLimitDailyReport` | Daily report for stock reaching limit |
| `dbo.SP_VI_TBL_ReportScript_StockReachLimitManualReport` | Manual report for stock reaching limit |
| `dbo.SP_VI_TBL_ReportScript_StockTakeDetailManualReport` | Manual stock take detail report |
| `dbo.SP_VI_TBL_ReportScript_StockTakeDetailWeeklyReport` | Weekly stock take detail report |
| `dbo.SP_VI_TBL_ReportScript_StockTakeSummaryManualReport` | Manual stock take summary report |
| `dbo.SP_VI_TBL_ReportScript_StockTakeSummaryWeeklyReport` | Weekly stock take summary report |
| `dbo.SP_VI_TBL_ReportScript_SummaryInvoiceWeeklyReport` | Weekly invoice summary report |
| `dbo.SP_VI_TBL_ReportScript_TotalInvoiceWeeklyReport` | Weekly total invoice report |

---

## 35. Section Printers

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_SectionPrinter_DeleteSectionPrinter` | Delete a section printer |
| `dbo.SP_VI_TBL_SectionPrinter_GetAllSectionPrinterOfWareHouse` | Get all section printers for a warehouse |
| `dbo.SP_VI_TBL_SectionPrinter_InsertSectionPrinter` | Insert a new section printer |
| `dbo.SP_VI_TBL_SectionPrinter_ListSectionPrinters` | List section printers (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_SectionPrinter_UpdateSectionPrinter` | Update a section printer |
| `dbo.SP_VI_TBL_SectionPrinter_ViewSectionPrinter` | View a single section printer |

---

## 36. Services (Kitting, Stock Take, Other)

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Service_AddStockTakeResult` | Add stock take result ⚠️ *Currently a stub — no DML executed* |
| `dbo.SP_VI_TBL_Service_CancelKittingService` | Cancel a kitting service |
| `dbo.SP_VI_TBL_Service_CancelService` | Cancel a service |
| `dbo.SP_VI_TBL_Service_CheckValidBeforeCompleteKittingService` | Validate before completing a kitting service |
| `dbo.SP_VI_TBL_Service_CheckValidBeforeCompleteStockTakeService` | Validate before completing a stock take service |
| `dbo.SP_VI_TBL_Service_CompleteKittingService` | Complete a kitting service |
| `dbo.SP_VI_TBL_Service_CompletePickingTaskOfKitting` | Complete the picking task for a kitting service |
| `dbo.SP_VI_TBL_Service_CompleteService` | Complete a service |
| `dbo.SP_VI_TBL_Service_CompleteStockTakeTask` | Complete a stock take task |
| `dbo.SP_VI_TBL_Service_ExitPickingTaskOfKitting` | Exit the picking task for kitting without completing |
| `dbo.SP_VI_TBL_Service_ExitStockTakeTask` | Exit a stock take task without completing |
| `dbo.SP_VI_TBL_Service_GetTenantInfoOfService` | Get tenant info for a service |
| `dbo.SP_VI_TBL_Service_InsertKittingService` | Insert a new kitting service |
| `dbo.SP_VI_TBL_Service_InsertService` | Insert a new service |
| `dbo.SP_VI_TBL_Service_InsertStockTakeService` | Insert a new stock take service |
| `dbo.SP_VI_TBL_Service_ListAllKittingPendingServices` | List all pending kitting services |
| `dbo.SP_VI_TBL_Service_ListAllStockTakePendingServices` | List all pending stock take services |
| `dbo.SP_VI_TBL_Service_ListKittingServices` | List kitting services (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Service_ListServices` | List services (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Service_StartOtherService` | Start a non-kitting/non-stock-take service |
| `dbo.SP_VI_TBL_Service_StartPickingTaskOfKitting` | Start the picking task for a kitting service |
| `dbo.SP_VI_TBL_Service_StartStockTakeService` | Start a stock take service |
| `dbo.SP_VI_TBL_Service_StartStockTakeTask` | Start a stock take task |
| `dbo.SP_VI_TBL_Service_UpdateKittingService` | Update a kitting service |
| `dbo.SP_VI_TBL_Service_UpdateService` | Update a service |
| `dbo.SP_VI_TBL_Service_UpdateStockTakeService` | Update a stock take service |
| `dbo.SP_VI_TBL_Service_ViewKittingItemOfService` | View kitting items for a service |
| `dbo.SP_VI_TBL_Service_ViewKittingResultsOfService` | View kitting results for a service |
| `dbo.SP_VI_TBL_Service_ViewService` | View a single service |
| `dbo.SP_VI_TBL_Service_ViewStockTakeItemsOfService` | View stock take items for a service |
| `dbo.SP_VI_TBL_Service_ViewStockTakeResultsOfService` | View stock take results for a service |

---

## 37. Service Lines

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ServiceLine_InsertServiceLine` | Insert a new service line |
| `dbo.SP_VI_TBL_ServiceLine_ListServiceLines` | List service lines |
| `dbo.SP_VI_TBL_ServiceLine_UpdateServiceLine` | Update a service line |

---

## 38. Shipments

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Shipment_CopyShipment` | Copy a shipment |
| `dbo.SP_VI_TBL_Shipment_InsertManualShipment` | Insert a manual shipment |
| `dbo.SP_VI_TBL_Shipment_ListShipments` | List shipments (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Shipment_ViewShipment` | View a single shipment |

---

## 39. Standard Boxes

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_StandardBox_DeleteStandardBox` | Delete a standard box |
| `dbo.SP_VI_TBL_StandardBox_InsertStandardBox` | Insert a new standard box |
| `dbo.SP_VI_TBL_StandardBox_ListAllStandardBoxes` | List all standard boxes |
| `dbo.SP_VI_TBL_StandardBox_ListStandardBoxes` | List standard boxes (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_StandardBox_UpdateStandardBox` | Update a standard box |
| `dbo.SP_VI_TBL_StandardBox_ViewStandardBox` | View a single standard box |

---

## 40. Tenants

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Tenant_CheckTenantInit` | Check if a tenant has been initialised |
| `dbo.SP_VI_TBL_Tenant_CheckTenantLock` | Check if a tenant is locked |
| `dbo.SP_VI_TBL_Tenant_DeleteTenant` | Soft-delete a tenant |
| `dbo.SP_VI_TBL_Tenant_DeleteTenantIntegration` | Delete a tenant integration |
| `dbo.SP_VI_TBL_Tenant_GetAllCompositeItemsOfTenantByType` | Get all composite items for a tenant by type |
| `dbo.SP_VI_TBL_Tenant_GetAllNotificationEmailInfoTenants` | Get notification email info for all tenants |
| `dbo.SP_VI_TBL_Tenant_GetAllStockItemsOfTenantAtWarehouse` | Get all stock items for a tenant at a warehouse |
| `dbo.SP_VI_TBL_Tenant_GetAllULDsOfTenant` | Get all ULDs belonging to a tenant |
| `dbo.SP_VI_TBL_Tenant_GetCarriersFromMappingNames` | Get carriers from carrier mapping names |
| `dbo.SP_VI_TBL_Tenant_GetMaterialBoxItemsAndULDs` | Get material box items and their ULDs |
| `dbo.SP_VI_TBL_Tenant_GetStockOnHandOfTenant` | Get stock on hand for a tenant (paginated, dynamic SQL) |
| `dbo.SP_VI_TBL_Tenant_GetStockOnHandOfTenantForExport` | Get stock on hand for tenant export |
| `dbo.SP_VI_TBL_Tenant_GetWarehouseHavingStocks` | Get warehouses that have tenant stock |
| `dbo.SP_VI_TBL_Tenant_InsertTenant` | Insert a new tenant |
| `dbo.SP_VI_TBL_Tenant_InsertTenantIntegration` | Insert a tenant integration |
| `dbo.SP_VI_TBL_Tenant_ListAllTenants` | List all tenants |
| `dbo.SP_VI_TBL_Tenant_ListAllTenantsOfWarehouse` | List all tenants at a warehouse |
| `dbo.SP_VI_TBL_Tenant_ListTenants` | List tenants (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Tenant_LockTenant` | Lock a tenant account |
| `dbo.SP_VI_TBL_Tenant_UnLockTenant` | Unlock a tenant account |
| `dbo.SP_VI_TBL_Tenant_UpdateTenant` | Update tenant details |
| `dbo.SP_VI_TBL_Tenant_ViewAllTenantIntegration` | View all integrations for a tenant |
| `dbo.SP_VI_TBL_Tenant_ViewTenantIntegrationByTenantAndWarehouse` | View a tenant integration by tenant and warehouse |
| `dbo.SP_VI_TBL_Tenant_ViewTenant` | View a single tenant |
| `dbo.SP_VI_TBL_Tenant_ViewTenantLockInfo` | View tenant lock info |

---

## 41. Tenant Permissions & Section Permissions

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_TenantPermission_ListAllTenantPermissions` | List all tenant permissions |
| `dbo.SP_VI_TBL_TenantPermissionConfig_DeleteTenantPermissionConfig` | Delete a tenant permission config |
| `dbo.SP_VI_TBL_TenantPermissionConfig_InsertTenantPermissionConfig` | Insert a tenant permission config |
| `dbo.SP_VI_TBL_TenantPermissionConfig_ListTenantPermissionConfigs` | List tenant permission configs (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_TenantPermissionConfig_UpdateTenantPermissionConfig` | Update a tenant permission config |
| `dbo.SP_VI_TBL_TenantPermissionConfig_ViewTenantPermissionConfig` | View a single tenant permission config |
| `dbo.SP_VI_TBL_TenantSectionPermission_ListAllTenantSectionPermissions` | List all tenant section permissions |
| `dbo.SP_VI_TBL_TenantSectionPermission_ListAllTenantSectionPermissionsByTenantPermissionID` | List all section permissions by tenant permission ID |
| `dbo.SP_VI_TBL_TenantSectionPermissionConfig_ViewTenantSectionPermissionConfigByID` | View section permission config by ID |

---

## 42. Tenant Custom Costs

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_TenantCustomCost_ListChargeItemCostByTenantAndId` | List custom charge item costs by tenant and charge item ID |
| `dbo.SP_VI_TBL_TenantCustomCost_UpdateChargeItemCostById` | Update custom charge item cost by ID |

---

## 43. ULD (Unit Load Device)

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ULD_ChangeULDLocation` | Change the location of a ULD |
| `dbo.SP_VI_TBL_ULD_CheckHavingStockOfTenantAtLocation` | Check if tenant has stock at a location (dynamic SQL) |
| `dbo.SP_VI_TBL_ULD_CheckHavingStockOfTenantAtWarehouse` | Check if tenant has stock at a warehouse (dynamic SQL) |
| `dbo.SP_VI_TBL_ULD_CheckValidDestinationOfTransferULD` | Validate the destination for a ULD transfer |
| `dbo.SP_VI_TBL_ULD_CheckValidSourceOfTransferULD` | Validate the source for a ULD transfer |
| `dbo.SP_VI_TBL_ULD_CheckValidToChangeULDLocation` | Check if a ULD can be moved to a new location |
| `dbo.SP_VI_TBL_ULD_CopyULDIntoExistedLocation` | Copy a ULD into an existing location |
| `dbo.SP_VI_TBL_ULD_CopyULDIntoNewTemporaryLocation` | Copy a ULD into a new temporary location |
| `dbo.SP_VI_TBL_ULD_DeductBoxStockForPacking` | Deduct box stock from a ULD for packing |
| `dbo.SP_VI_TBL_ULD_DeleteEmptyULDByBarcode` | Delete an empty ULD by barcode |
| `dbo.SP_VI_TBL_ULD_DeleteEmptyULDs` | Delete all empty ULDs |
| `dbo.SP_VI_TBL_ULD_DeleteULD` | Soft-delete a ULD |
| `dbo.SP_VI_TBL_ULD_GetAllSerialNumberByULD` | Get all serial numbers associated with a ULD |
| `dbo.SP_VI_TBL_ULD_GetAllSerialNumberByULDs` | Get all serial numbers for multiple ULDs |
| `dbo.SP_VI_TBL_ULD_GetAvailableQtyOfULD` | Get the available quantity of a ULD |
| `dbo.SP_VI_TBL_ULD_GetNextLocationForPicking` | Get the next location to pick from for a ULD |
| `dbo.SP_VI_TBL_ULD_GetULDsByLocation` | Get ULDs by location |
| `dbo.SP_VI_TBL_ULD_GetULDsHavingStockOfTenantAtLocation` | Get ULDs with tenant stock at a location (dynamic SQL) |
| `dbo.SP_VI_TBL_ULD_GetULDsHavingStockOfTenantAtWarehouse` | Get ULDs with tenant stock at a warehouse (dynamic SQL) |
| `dbo.SP_VI_TBL_ULD_InActiveEmptyULDs` | Mark all empty ULDs as inactive |
| `dbo.SP_VI_TBL_ULD_InsertULDFromReceipt` | Insert a ULD from a receipt inbound |
| `dbo.SP_VI_TBL_ULD_InsertULDLineFromReceipt` | Insert a ULD line from a receipt inbound |
| `dbo.SP_VI_TBL_ULD_ListAllLockedULDs` | List all locked ULDs (dynamic SQL) |
| `dbo.SP_VI_TBL_ULD_ListULDs` | List ULDs (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_ULD_ListULDsByItem` | List ULDs filtered by item (paginated, dynamic SQL) |
| `dbo.SP_VI_TBL_ULD_ListUnavailableULDsByItem` | List unavailable ULDs filtered by item (paginated, dynamic SQL) |
| `dbo.SP_VI_TBL_ULD_RemoveSerialNumberByULD` | Remove a serial number from a ULD |
| `dbo.SP_VI_TBL_ULD_RemoveULDLineFromReceipt` | Remove a ULD line from a receipt |
| `dbo.SP_VI_TBL_ULD_SearchULDs` | Search ULDs with filters (paginated, dynamic SQL) |
| `dbo.SP_VI_TBL_ULD_TransferULDToAnotherULD` | Transfer stock from one ULD to another |
| `dbo.SP_VI_TBL_ULD_UpdateLockedStatusByULD` | Update locked status for a single ULD |
| `dbo.SP_VI_TBL_ULD_UpdateLockedStatusByULDs` | Update locked status for multiple ULDs |
| `dbo.SP_VI_TBL_ULD_UpdateOnHoldByULD` | Set or clear on-hold status on a ULD |
| `dbo.SP_VI_TBL_ULD_UpdateQuantityByULD` | Update quantity on a ULD |
| `dbo.SP_VI_TBL_ULD_UpdateULDFromReceipt` | Update a ULD record from a receipt |
| `dbo.SP_VI_TBL_ULD_ViewULD` | View a single ULD |
| `dbo.SP_VI_TBL_ULD_ViewULDContent` | View the contents of a ULD (dynamic sort) |

---

## 44. ULD Lines

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_ULDLine_InsertULDLine` | Insert a ULD transaction line |
| `dbo.SP_VI_TBL_ULDLIne_ResetULDLineSequence` | Reset the sequence number for ULD lines |
| `dbo.SP_VI_TBL_ULDLine_RevertAllocatedULDOfOrders` | Revert allocated ULD lines back for given orders |
| `dbo.SP_VI_TBL_ULDLine_ViewULDLinesByID` | View ULD lines by ID (paginated, dynamic sort) |

---

## 45. User Permissions

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_UserPermission_ListUserPermission` | List permissions for a user |
| `dbo.SP_VI_TBL_UserPermission_UpdateUserPermission` | Update a single user permission |
| `dbo.SP_VI_TBL_UserPermission_UpdateUserPermissionByIDs` | Update multiple user permissions by IDs |

---

## 46. Users

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Users_AssignDefaultWarehouseForUser` | Assign a default warehouse for a user |
| `dbo.SP_VI_TBL_Users_AssignSuperUser` | Assign super-user role to a user |
| `dbo.SP_VI_TBL_Users_ChangeUserMobilePassword` | Change a user's mobile password (hashed SHA2_256) |
| `dbo.SP_VI_TBL_Users_CheckAPIAuthentication` | Validate API key authentication for a user |
| `dbo.SP_VI_TBL_Users_CheckAPIAuthenticationByEmail` | Validate API key authentication by email |
| `dbo.SP_VI_TBL_Users_CheckExistedUser` | Check if a user already exists |
| `dbo.SP_VI_TBL_Users_CheckMobileAPIAuthentication` | Validate mobile API authentication |
| `dbo.SP_VI_TBL_Users_CheckMobileAuthentication` | Validate mobile password authentication (SHA2_256 hash comparison) |
| `dbo.SP_VI_TBL_Users_DeleteCurrentWorkstationOfUser` | Delete the current workstation assignment for a user |
| `dbo.SP_VI_TBL_Users_DeleteUser` | Soft-delete a user |
| `dbo.SP_VI_TBL_Users_GetCurrentWarehouseOfUser` | Get the current warehouse for a user |
| `dbo.SP_VI_TBL_Users_GetCurrentWorkstationOfUser` | Get the current workstation for a user |
| `dbo.SP_VI_TBL_Users_GetFailedLogin` | Get the failed login count for a user (by Azure ID) |
| `dbo.SP_VI_TBL_Users_GetUserInfoByAzureId` | Get user info by Azure user ID (dynamic SQL) |
| `dbo.SP_VI_TBL_Users_GetUserStatus` | Get the current status of a user |
| `dbo.SP_VI_TBL_Users_InsertUser` | Insert a new user (generates API key via SHA2_256; hashes mobile password) |
| `dbo.SP_VI_TBL_Users_ListUsers` | List users (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Users_ResetUserMobilePassword` | Reset a user's mobile password (hashed SHA2_256) |
| `dbo.SP_VI_TBL_Users_ResetWarehouseOfUser` | Reset the warehouse assignment for a user |
| `dbo.SP_VI_TBL_Users_SetCurrentWarehouseForUser` | Set the current warehouse for a user |
| `dbo.SP_VI_TBL_Users_SetCurrentWorkstationForUser` | Set the current workstation for a user |
| `dbo.SP_VI_TBL_Users_UpdateFailedLogin` | Increment the failed login counter for a user |
| `dbo.SP_VI_TBL_Users_UpdateUser` | Update user details |
| `dbo.SP_VI_TBL_Users_UpdateUserStatus` | Update user status (active/inactive/blocked) |
| `dbo.SP_VI_TBL_Users_ViewUser` | View a single user (dynamic SQL) |

---

## 47. Warehouse Printers

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_WarehousePrinter_DeleteWarehousePrinter` | Delete a warehouse printer |
| `dbo.SP_VI_TBL_WarehousePrinter_InsertWarehousePrinter` | Insert a new warehouse printer |
| `dbo.SP_VI_TBL_WarehousePrinter_ListAllWarehousePrintersByWarehouseCode` | List all printers for a warehouse by code |
| `dbo.SP_VI_TBL_WarehousePrinter_ListWarehousePrinters` | List warehouse printers (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_WarehousePrinter_UpdateWarehousePrinter` | Update a warehouse printer |
| `dbo.SP_VI_TBL_WarehousePrinter_ViewWarehousePrinter` | View a single warehouse printer |

---

## 48. Wave & Wave Lines

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Wave_AutoCompletePackingTask` | Auto-complete a packing task in a wave |
| `dbo.SP_VI_TBL_Wave_AutoCompleteWavePacking` | Auto-complete all packing in a wave |
| `dbo.SP_VI_TBL_Wave_CheckValidBeforeCompletePacking` | Validate before completing packing for a wave |
| `dbo.SP_VI_TBL_Wave_CompletePackingTask` | Complete a packing task |
| `dbo.SP_VI_TBL_Wave_CompletePickingTask` | Complete a picking task |
| `dbo.SP_VI_TBL_Wave_CompleteWaveRequest` | Complete a wave |
| `dbo.SP_VI_TBL_Wave_CreateShipmentsForCMCPackingWave` | Create shipments for a CMC packing wave |
| `dbo.SP_VI_TBL_Wave_DeleteWave` | Delete a wave |
| `dbo.SP_VI_TBL_Wave_ExitPackingTask` | Exit a packing task without completing |
| `dbo.SP_VI_TBL_Wave_ExitPickingTask` | Exit a picking task without completing |
| `dbo.SP_VI_TBL_Wave_GetShipmentInfoOfWaveByOrders` | Get shipment info for wave orders |
| `dbo.SP_VI_TBL_Wave_GetWaveInfoByID` | Get wave info by ID |
| `dbo.SP_VI_TBL_Wave_GetWaveInfoForPrintByID` | Get wave info formatted for printing by ID |
| `dbo.SP_VI_TBL_Wave_InsertOrdersToWave` | Insert orders into a wave |
| `dbo.SP_VI_TBL_Wave_ListAllWavesByTypeAndStatuses` | List all waves by type and statuses |
| `dbo.SP_VI_TBL_Wave_ListOrders` | List orders in a wave (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Wave_ListPickedULDsByWaveOrderAndItem` | List picked ULDs by wave, order, and item |
| `dbo.SP_VI_TBL_Wave_ListWaves` | List waves (paginated, dynamic sort) |
| `dbo.SP_VI_TBL_Wave_StartPackingTask` | Start a packing task |
| `dbo.SP_VI_TBL_Wave_StartPickingTask` | Start a picking task |
| `dbo.SP_VI_TBL_Wave_StartWaveRequest` | Start a wave |
| `dbo.SP_VI_TBL_Wave_UpdateShippmentInfoForWave` | Update shipment info for a wave |
| `dbo.SP_VI_TBL_Wave_UpdateStockStatus` | Update stock status for a wave |
| `dbo.SP_VI_TBL_Wave_ViewWave` | View a single wave |
| `dbo.SP_VI_TBL_WaveLine_UpdateOrdersStatus` | Update order statuses in a wave line |
| `dbo.SP_VI_TBL_WaveLine_UpdateShipment` | Update shipment info in a wave line |
| `dbo.SP_VI_TBL_WaveLine_ViewWaveLinesByID` | View wave lines by ID |

---

## 49. Widget

| Stored Procedure | Description |
|---|---|
| `dbo.SP_VI_TBL_Widget_ListAllWidgets` | List all dashboard widgets |

---

*Generated: April 29, 2026*
