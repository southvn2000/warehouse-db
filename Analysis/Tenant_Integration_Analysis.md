# Tenant Integration Analysis (AP, DHL, CP)

Date: 2026-04-28

## Scope

This analysis covers:

- `dbo.APIntegration` and `dbo.APIntegrationLine`
- `dbo.DHLIntegration` and `dbo.DHLIntegrationLine`
- `dbo.CPIntegration` and `dbo.CPIntegrationLine`
- Related stored procedures for create/update/delete/view and line mapping usage

## Core Integration Tables

### 1) AP Integration

- Main table: `dbo.APIntegration`
- Line table: `dbo.APIntegrationLine`
- Tenant scope pattern: `TenantCode + WarehouseCode + Deleted = 0`

### 2) DHL Integration

- Main table: `dbo.DHLIntegration`
- Line table: `dbo.DHLIntegrationLine`
- Tenant scope pattern: `TenantCode + WarehouseCode + Deleted = 0`

### 3) CP Integration

- Main table: `dbo.CPIntegration`
- Line table: `dbo.CPIntegrationLine`
- Tenant scope pattern: `TenantCode + WarehouseCode + Deleted = 0`

All three integrations use denormalized tenant fields (`TenantCode`, `TenantName`) and soft-delete (`Deleted`).

## Related Stored Procedures

### APIntegration / APIntegrationLine

- `dbo.SP_VI_TBL_APIntegration_InsertIntegration`
- `dbo.SP_VI_TBL_APIntegration_UpdateIntegration`
- `dbo.SP_VI_TBL_APIntegration_DeleteIntegration`
- `dbo.SP_VI_TBL_APIntegration_ViewIntegration`
- `dbo.SP_VI_TBL_APIntegration_ViewIntegrationByTenant`
- `dbo.SP_VI_TBL_APIntegration_ViewIntegrationByTenantAndWarehouse`
- `dbo.SP_VI_TBL_APIntegration_ViewIntegrationServiceByTenantAndWarehouse`
- `dbo.SP_VI_TBL_APIntegrationLine_ViewIntegrationLinesByID`

Related usage procedures:

- `dbo.SP_VI_TBL_APShipment_InsertAPIntShipment`
- `dbo.SP_VI_TBL_APShipment_InsertAPLocalShipment`
- `dbo.SP_VI_TBL_APShipment_InsertAPShipment`
- `dbo.SP_VI_TBL_APShipmentItems_AddItems`

### DHLIntegration / DHLIntegrationLine

- `dbo.SP_VI_TBL_DHLIntegration_InsertIntegration`
- `dbo.SP_VI_TBL_DHLIntegration_UpdateIntegration`
- `dbo.SP_VI_TBL_DHLIntegration_DeleteIntegration`
- `dbo.SP_VI_TBL_DHLIntegration_ViewIntegration`
- `dbo.SP_VI_TBL_DHLIntegration_ViewIntegrationByTenant`
- `dbo.SP_VI_TBL_DHLIntegration_ViewIntegrationByTenantAndWarehouse`
- `dbo.SP_VI_TBL_DHLIntegrationLine_ViewIntegrationLinesByID`

Related usage procedures:

- `dbo.SP_VI_TBL_DHLShipment_InsertDHLShipment`
- `dbo.SP_VI_TBL_DHLShipment_InsertManualDHLShipment`

### CPIntegration / CPIntegrationLine

- `dbo.SP_VI_TBL_CPIntegration_InsertIntegration`
- `dbo.SP_VI_TBL_CPIntegration_UpdateIntegration`
- `dbo.SP_VI_TBL_CPIntegration_DeleteIntegration`
- `dbo.SP_VI_TBL_CPIntegration_ViewIntegration`
- `dbo.SP_VI_TBL_CPIntegration_ViewIntegrationByTenant`
- `dbo.SP_VI_TBL_CPIntegration_ViewIntegrationByTenantAndWarehouse`
- `dbo.SP_VI_TBL_CPIntegrationLine_ViewIntegrationLinesByID`

## Integration Pattern Summary

1. Upsert-like setup is implemented in `InsertIntegration` procedures.

- Existing active row by tenant+warehouse is updated.
- Otherwise a new main integration row is created.
- Line mappings are inserted into corresponding `*IntegrationLine` tables.

1. Update and delete are soft-delete driven.

- `UpdateIntegration` refreshes main fields and line mappings.
- `DeleteIntegration` marks main rows (and line rows where applicable) as `Deleted = 1`.

1. Read patterns are tenant-centric.

- View by tenant ID/code and by tenant+warehouse are present for AP/DHL/CP.
- Line lookup is exposed by integration ID through `*Line_ViewIntegrationLinesByID` procedures.

## Risks and Recommendations

1. Potential duplicates for active integration rows.

- Recommendation: add unique filtered indexes per main table on `(TenantCode, WarehouseCode)` with `Deleted = 0`.

1. Denormalized tenant name drift.

- Recommendation: either keep `TenantName` synchronized from `dbo.Tenant` or read tenant display name via join at query time.

1. Ownership validation in update/delete entry points.

- Recommendation: validate tenant/warehouse ownership in update/delete procedures, not only by `IntegrationID`.

## Summary

`APIntegration`, `DHLIntegration`, and `CPIntegration` follow a consistent multi-tenant pattern with parallel line-table design and similar stored-procedure lifecycle (insert/update/delete/view). The main hardening opportunities are uniqueness constraints, ownership checks, and tenant-name consistency.
