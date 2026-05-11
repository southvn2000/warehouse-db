# Invoice Charging Logic

## Overview

The invoice charging system in this 3PL WMS handles billing tenants for warehouse services. Charges are created at event time (receiving, picking, packing, shipping) and by automated schedulers (weekly storage, bay, and IT platform fees). All charges land in the `Invoice` table with a `Status = 'Pending'`.

### Latest Logic Update (2026-05-07)

- Weekly scheduler invoices (`Bay`, `Pallet`, `IT Platform`) are orchestrated by `SP_VI_TBL_ReportSchedule_RunReportSchedules` and execute only when the scheduler runs on Monday (`DATEFIRST 1`, `DATEPART(WEEKDAY, GETDATE()) = 1`).
- AP/DHL mailing invoice procedures exist and contain full calculation logic, but in this SQL repository there is no active SQL caller for AP mailing and no active SQL caller for DHL mailing (the DHL invocation block in `SP_VI_TBL_Wave_CompleteWaveRequest` is currently commented out).
- Practical implication: mailing invoice creation is currently expected to be triggered by the application/integration layer (or by re-enabling SQL-side invocation).

---

## Data Model

### Core Tables

#### `dbo.Invoice`

The central billing record. One row per charge line.

| Column | Type | Notes |
|--------|------|-------|
| `InvoiceID` | int IDENTITY | PK |
| `TenantCode` | varchar(10) | FK → `Tenant` |
| `ChargeName` | varchar(100) | Human-readable name of the charge |
| `ChargeType` | varchar(20) | `Standard`, `Custom`, `PalletStorage`, `BayAllocation`, `BinAllocation`, `IT Platform` |
| `ChargeCategory` | varchar(100) | Logical grouping: `Receiving`, `Picking`, `Packing`, `Storage`, `Regular`, `Shipping`, `Services - Stock Take`, `Services - Other`, `Account Management` |
| `InvoiceReferences` | varchar(500) | Order/receipt/shipment reference |
| `ItemReferences` | varchar(500) | Item name + code |
| `WaveReferences` | varchar(20) | Wave number (picking/packing only) |
| `WarehouseCode` | varchar(20) | FK → `LocWarehouse` |
| `Qty` | int | Quantity billed |
| `Cost` | decimal(18,2) | Unit rate |
| `Charge` | decimal(18,2) | Total charge (`Cost × Qty`) |
| `Currency` | varchar(20) | e.g. `AUD (A$)` |
| `Status` | varchar(20) | Always `Pending` at creation |
| `Deleted` | bit | Soft-delete flag |

---

#### `dbo.ChargeItem`

Master list of billable charge items (e.g. "Receiving per Carton", "Storage - PALLET").

| Column | Notes |
|--------|-------|
| `ChargeItemName` | Human-readable name, used as lookup key in many SPs |
| `ChargeItemUnit` | Unit of measure: `Carton`, `Pallet`, `Box`, `Week`, `Person per Hour`, `Receipt`, `Unit` |
| `ChargeItemGroup` | Logical group: `Receiving`, `Picking`, `Packing`, `Storage`, `Regular`, `Labour Service`, `Account Management` |
| `ChargeItemType` | Additional classification |
| `Mandatory` | Whether always billed (default 0) |
| `APIID` | FK → `API` (optional carrier linkage) |

---

#### `dbo.ChargeItemCost`

**Standard** pricing for a charge item, per warehouse. Supports a `Division` field for multi-division warehouses.

| Column | Notes |
|--------|-------|
| `ChargeItemID` | FK → `ChargeItem` |
| `WarehouseCode` | FK → `LocWarehouse` |
| `ChargeItemPrice` | Price per unit |
| `ChargeItemCurrency` | Currency code |
| `Division` | Optional warehouse division discriminator |

---

#### `dbo.TenantChargeItem`

Links a tenant to an applicable charge item with `Standard` or `Custom` pricing, date-ranged.

| Column | Notes |
|--------|-------|
| `TenantCode` | FK → `Tenant` |
| `ChargeItemId` | FK → `ChargeItem` |
| `ChargeType` | `Standard` or `Custom` |
| `EffectiveDate` / `EndDate` | Validity window |
| `CustomCost` | Used when type is `Custom` (inline; actual lookup is in `TenantCustomCost`) |

---

#### `dbo.ChargeGroup`

Groups of charges applied per-item (linked via `ItemChargeGroup`). Has a `Category` matching the operation type (Receiving, Picking, Packing).

#### `dbo.ChargeGroupCost`

Standard pricing for a `ChargeGroup`, per warehouse, per unit.

| Column | Notes |
|--------|-------|
| `ChargeGroupID` | FK → `ChargeGroup` |
| `WarehouseCode` | FK → `LocWarehouse` |
| `ChargeItemPrice` | Price per unit |
| `ChargeItemUnit` | Unit of measure for the group |
| `ChargeItemCurrency` | Currency |

#### `dbo.ItemChargeGroup`

Maps an `Item` to a `ChargeGroup` by category. Allows different items to have different group pricing for the same operation.

| Column | Notes |
|--------|-------|
| `ItemID` | FK → `Items` |
| `ChargeGroupID` | FK → `ChargeGroup` |
| `Category` | Matches operation: `Receiving`, `Picking`, `Packing` |

---

#### `dbo.ReportInvoice`

Snapshot table for report data. Populated during report generation, linked to `ReportDataID`.

#### `dbo.InvoiceLog` _(3PLWMS_LOGS_DEV)_

API-level audit log recording request/response payloads, transaction results, and timestamps for invoice-related API calls.

---

## Pricing Resolution

**`SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode`**

This SP is the central pricing lookup for all `ChargeItem`-based invoices. It resolves the effective rate and type for a given tenant, charge item, and warehouse.

```
INPUT:  @ChargeItemID, @TenantCode, @WarehouseCode
OUTPUT: @Charge, @Currency, @ChargeType
```

**Resolution logic:**

```
1. Query TenantChargeItem WHERE TenantCode + ChargeItemID
   → yields @ChargeType (Standard | Custom) and @TenantChargeItemID

2. If @ChargeType = 'Standard':
   → SELECT price FROM ChargeItemCost WHERE ChargeItemID + WarehouseCode

3. If @ChargeType = 'Custom':
   → SELECT price FROM TenantCustomCost WHERE TenantChargeItemID + WarehouseCode

4. Defaults: @Charge = 0, @Currency = 'AUD (A$)' if no match
```

> **If `@ChargeType IS NULL`** (tenant not subscribed to this charge item), no invoice row is inserted by the caller. This acts as the per-tenant charge opt-in gate.

---

## Invoice Types and Creation Flows

### 1. Receiving Invoice

**Triggered:** At item receiving time (per item line).
**SPs:** `SP_VI_TBL_Invoice_InsertReceivingInvoice`, `SP_VI_TBL_Invoice_CompleteReceivingInvoice`

**Per-item flow (`InsertReceivingInvoice`):**

1. Calls `InsertChargeGroupInvoice` with category `Receiving` — creates a group-rate charge based on `ItemChargeGroup` → `ChargeGroupCost`.
2. Iterates `ChargeItem` with `ChargeItemGroup = 'Receiving'`, filters by matching `@ItemUnit`.
3. For each match, calls `GetCostInfoOfTenantByWarehouseCode` to resolve rate.
4. If tenant is subscribed (`@ChargeType IS NOT NULL`), inserts an `Invoice` row:
   - `ChargeCategory = 'Receiving'`, `Status = 'Pending'`, `Charge = Cost × Qty`

**Per-receipt completion flow (`CompleteReceivingInvoice`):**

- Triggered once when the receipt inbound is completed.
- Iterates `ChargeItem` with `ChargeItemGroup = 'Receiving'` AND `ChargeItemUnit = 'Receipt'`.
- Inserts one flat receipt-level charge row per matching charge item.
- `Qty = 1`, `Charge = Cost`.

---

### 2. Picking Invoice

**Triggered:** When a fulfilment item is picked.
**SP:** `SP_VI_TBL_Invoice_InsertPickingInvoice`

**Flow:**

1. Calls `InsertChargeGroupInvoice` with category `Picking` — item-level group rate.
2. Iterates `ChargeItem` with `ChargeItemGroup = 'Picking'`, matches `@ItemUnit`.
3. Resolves rate via `GetCostInfoOfTenantByWarehouseCode`, inserts if subscribed.
4. `WaveReferences` is populated.

#### Detailed Procedure Analysis: `SP_VI_TBL_Invoice_InsertPickingInvoice`

#### Primary objective

- Insert `Picking` category invoice rows for one item movement (`Tenant + Warehouse + Item + Unit + Qty`), combining charge-group billing and charge-item billing.

#### Execution flow (actual behavior)

1. Sets `@ChargeItemCat = 'Picking'`.
2. Calls `SP_VI_TBL_Invoice_InsertChargeGroupInvoice` with category `Picking`.
3. Reads item name from `dbo.Items` by `ItemNumber + TenantCode + Deleted = 0`.
4. Opens a cursor over all active `dbo.ChargeItem` rows in group `Picking`.
5. For each charge item, processes only when `@ItemUnit = ChargeItemUnit`.
6. Calls `SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode`.
7. Inserts into `dbo.Invoice` only when `@ChargeType IS NOT NULL`.

#### Dependencies used by the procedure

- `SP_VI_TBL_Invoice_InsertChargeGroupInvoice`
- `SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode`
- `dbo.Items`
- `dbo.ChargeItem`
- `dbo.Invoice`

#### Net insert effect per single call

- Can create **multiple rows**:
  - 1 row from charge-group path (if all charge-group prerequisites are valid).
  - 0..N rows from charge-item path (for matching units and subscribed tenant charge items).
- Not idempotent by design: repeat calls with same references can insert duplicates.

#### Current risk notes

- Child message not enforced: parent does not stop when `InsertChargeGroupInvoice` returns validation text via `@Message`.
- Partial success possible: no explicit transaction wraps the full parent workflow.
- Null item name possible in invoice line (`ItemReferences`) if item lookup fails in parent.
- Zero-charge invoices can still be inserted (cost lookup defaults `@Charge = 0` when charge type exists).
- Unit matching is exact string comparison; formatting/casing variance can skip expected charges.

#### Operational implication

- A caller that retries this SP after timeout/interruption should assume duplicate risk unless deduplication exists upstream.

---

### 3. Packing Invoice

**Triggered:** At wave packing completion.
**SP:** `SP_VI_TBL_Invoice_InsertPackingInvoice`

**Flow — item-level:**

1. Iterates `PackingResultLine` (items packed in wave), grouped by `ItemNumber`.
2. For each item calls `InsertChargeGroupInvoice` with category `Packing` and unit `'Unit'` → group-rate per unit.

**Flow — box-level:**

1. Looks up `ChargeItem` with `ChargeItemGroup = 'Packing'` AND `ChargeItemUnit = 'Box'`.
2. Resolves rate, inserts one row with `Qty = NumberOfBoxes` from `PackingResult`.

#### Detailed Procedure Analysis: `SP_VI_TBL_Invoice_InsertPackingInvoice`

**Primary objective**

- Insert `Packing` category invoice rows for one wave/order completion, combining item-level group charges and box-level charges.

**Execution flow (actual behavior)**

1. Fetches `WaveNumber` from `dbo.Wave` by `WaveID + Deleted = 0`.
2. Looks up `PackingResultID` and `NumberOfBoxes` from `dbo.PackingResult` by `WaveID + OrderNumber + Deleted = 0`.
3. If `PackingResultID` exists:
   - Opens cursor over `PackingResultLine` grouped by `ItemNumber`.
   - For each item, calls `SP_VI_TBL_Invoice_InsertChargeGroupInvoice` with category `Packing`, unit `'Unit'`.
   - Closes cursor.
4. If `PackingResultID` is null, sets `@BoxQty = 0` (skips item-level loop).
5. Opens cursor over `dbo.ChargeItem` where `ChargeItemGroup = 'Packing'` AND `ChargeItemUnit = 'Box'` AND `Deleted = 0`.
6. For each charge item:
   - Calls `SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode`.
   - Inserts into `dbo.Invoice` only when `@ChargeType IS NOT NULL`.
   - Qty is set to `@BoxQty` (NumberOfBoxes).

**Dependencies used by the procedure**

- `SP_VI_TBL_Invoice_InsertChargeGroupInvoice`
- `SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode`
- `dbo.Wave`
- `dbo.PackingResult`
- `dbo.PackingResultLine`
- `dbo.ChargeItem`
- `dbo.Invoice`

**Net insert effect per single call**

- Can create **multiple rows**:
  - 1..N rows from item-level path (one per packed item with valid charge group setup).
  - 0..M rows from box-level path (one per matching `Box` charge item subscribed by tenant).
- Not idempotent: repeat calls with same wave/order can insert duplicates.
- If `PackingResultID` is null, only box-level inserts can happen, but with `@BoxQty = 0`, resulting in zero-quantity invoices if inserted.

**Current risk notes**

- Item-level message not enforced: parent does not stop when `InsertChargeGroupInvoice` returns validation failure via `@Message`.
- Partial success possible: no explicit transaction wraps the full workflow.
- No `PackingResult` → zero item-level charges and zero-qty box charges: if procedure is called for a wave/order with no packed items, box-level charges will insert with `Qty = 0`.
- `ItemReferences` is empty string for box-level charges, making line-item details blank.
- Box quantity can be null in `PackingResult.NumberOfBoxes`; defaults to 0 via `COALESCE`.
- No deduplication guard on `InvoiceReferences` or `WaveReferences` in insert statements.

**Operational implication**

- This procedure can be called from wave completion or manual triggers; retries should account for duplicate risk.
- If `PackingResult` is missing (transient data loss or timing issue), the procedure will still execute but produce only box-level charges with zero quantity.

**Investigation — when packing invoice is not created:**

The packing invoice path can be skipped at two layers: caller-level gating and invoice-proc internal gating.

1. **No matching `PackingResult` for the wave/order**
   - `SP_VI_TBL_Invoice_InsertPackingInvoice` fetches `PackingResultID` by `WaveID + OrderNumber + Deleted = 0`.
   - If no row is found, item-level charging is skipped entirely (`PackingResultLine` cursor is never opened).
   - In this case, only box-level charging may still happen (depending on charge-item setup and tenant subscription below).

2. **Item-level charge group setup is missing (per packed item)**
   - Item-level lines are inserted through `SP_VI_TBL_Invoice_InsertChargeGroupInvoice`.
   - That proc returns without insert when any prerequisite is missing:
     - `Items` row not found for `ItemNumber + TenantCode`
     - no `ItemChargeGroup` mapping for category `Packing`
     - no `ChargeGroupCost` for `ChargeGroupID + WarehouseCode + ItemUnit = 'Unit'`
   - Result: zero item-level packing invoice rows for that item.

3. **No `Packing + Box` charge item configured**
   - Box-level insert iterates `ChargeItem` where `ChargeItemGroup = 'Packing'`, `ChargeItemUnit = 'Box'`, `Deleted = 0`.
   - If this query returns no rows, no box-level packing invoice is inserted.

4. **Tenant is not subscribed to the box charge item**
   - For each box charge item, `SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode` is called.
   - Insert only occurs when `@ChargeType IS NOT NULL`.
   - If tenant has no applicable `TenantChargeItem` (or no effective pricing path resolving a charge type), the box-level invoice is skipped.

5. **All insert paths skip at once (common real-world “no packing invoice” outcome)**
   - Typical combinations that produce no packing invoice rows at all:
     - charging disabled at caller (`@IsCharge = 0`)
     - no valid item charge-group setup for all packed items AND no valid box charge item subscription
     - no `PackingResult` row and no eligible box charge insert

6. **Failure/rollback scenarios**
   - `SP_VI_TBL_Invoice_InsertPackingInvoice` and callers are wrapped in `TRY...CATCH`; runtime SQL errors are rethrown.
   - In caller procedures, transaction rollback on error means invoice inserts in that transaction do not persist.
   - So a transient insert that happened before an error can still end as “not created” after rollback.

---

### 4. Pallet Storage Invoice

**Triggered manually or by scheduler.**
**SPs:** `SP_VI_TBL_Invoice_InsertPalletStorageInvoice`, `SP_VI_TBL_Invoice_AutoCreatingPalletStorageInvoices`

**Single insert flow:**

- Looks up `ChargeItem` named `'Storage - PALLET'` (`ChargeItemGroup = 'Regular'`, `ChargeItemUnit = 'Week'`).
- Fetches rate from `ChargeItemCost` directly (no tenant subscription check).
- Inserts: `ChargeType = 'PalletStorage'`, `ChargeCategory = 'Storage'`.

**Auto-create (scheduler):**

- Scans all non-deleted `ULD` records where `IsPallete = 1`, has stock (`ULDLine.TransactionQty > 0`), and is not in `Draft` status.
- Resolves location label via `fn_GetLocationNameFromCode` and `SP_VI_TBL_LocTempLocation_CheckLocationAvailable`.
- Filters by storage type: only inserts for `Bulk`, `Receiving`, `Temp`, or unknown (`''`) storage types — **not** for Bay-allocated locations.
- One invoice row per ULD per scheduler run.

---

### 5. Bay Allocation Invoice

**Triggered manually or by scheduler.**
**SPs:** `SP_VI_TBL_Invoice_InsertBayAllocationInvoice`, `SP_VI_TBL_Invoice_AutoCreatingBayAllocationInvoices`

**Single insert flow:**

- Looks up `ChargeItem` named `'Storage - BAY'` (`ChargeItemGroup = 'Storage'`, `ChargeItemUnit = 'Week'`).
- Fetches rate from `ChargeItemCost`.
- Inserts: `ChargeType = 'BayAllocation'`, `ChargeCategory = 'Storage'`.

**Auto-create (scheduler):**

- Iterates `BayTenantAllocation` (all non-deleted, `AllocationDate IS NULL OR <= GETDATE()`).
- Resolves warehouse from `LocSection` → `LocArea` → `LocWarehouse`.
- Constructs human-readable `InvoiceReferences` (`W: ... A: ... S: ... R: ... C: ...`).
- `Qty = 1` per bay slot per run.

---

### 6. Bin Allocation Invoice (PerfectPick)

**SP:** `SP_VI_TBL_Invoice_InsertBinAllocationInvoice`

- Looks up `ChargeItem` named `'PerfectPick Location'` (`ChargeItemGroup = 'Regular'`, `ChargeItemUnit = 'Week'`).
- Supports `@Division` parameter to select pricing from a specific warehouse division (`ChargeItemCost.Division`).
- Inserts: `ChargeType = 'BinAllocation'`, `ChargeCategory = 'Regular'`.

---

### 7. Mailing / Shipping Invoice (Australia Post)

**SP:** `SP_VI_TBL_Invoice_InsertAPMailingInvoice`

**Invocation note (current SQL repo state):** No active SQL caller was found for this SP in repository procedures. It appears intended to be invoked by the application/integration layer.

Handles both wave-based and manually-created AP shipments. Accepts a list of order numbers (`dbo.StringArray`).

**Order classification:**

- Orders prefixed `MS-` → manual shipments from `AP_Shipment` (local) or `AP_ShipmentINT` (international).
- All other orders → wave-based fulfilments from `Fulfilment` → linked `AP_Shipment`.

**Charge calculation:**

```
Charge = CEILING(AP_order_total_cost + AP_order_total_cost × MailingChargePercent / 100)
```

- `MailingChargePercent` is pulled from `Tenant.MailingChargePercent`.
- Only creates invoice if `MailingChargePercent > 0`.
- Delegates actual insert to `InsertMailingInvoice`: `ChargeType = 'Standard'`, `ChargeCategory = 'Shipping'`, `Qty = 1`.

---

### 8. Mailing / Shipping Invoice (DHL)

**SP:** `SP_VI_TBL_Invoice_InsertDHLMailingInvoice`

**Invocation note (current SQL repo state):** A call-site exists in `SP_VI_TBL_Wave_CompleteWaveRequest`, but it is inside a commented block. No active SQL caller was found in this repository.

Same pattern as AP mailing but for DHL shipments.

**Order classification:**

- `MS-` prefix → manual from `DHLShipment`.
- Others → wave-based via `Fulfilment` + `PackingResult` + `DHLShipment`.

**Charge calculation:**

```
Mailing charge = CEILING(DHL_price + DHL_price × MailingChargePercent / 100)
Extra charge   = Tenant.ExtraOrderCost (flat amount, inserted as separate 'Extra Order Cost' line)
```

- `DHL_price` comes from `DHLResponse.price` by `MessageReference`.
- `ExtraOrderCost` is a flat per-order surcharge from `Tenant`.
- Both are delegated to `InsertMailingInvoice`.

#### Detailed Procedure Analysis: `SP_VI_TBL_Invoice_InsertMailingInvoice`

**Primary objective**

- Insert a single `Shipping` category invoice row with pre-calculated charge, amount, and metadata. Acts as a generic mailing/shipping invoice writer for AP/DHL and any other carrier that calculates charges upstream.

**Execution flow (actual behavior)**

1. If `@WaveID` is not null:
   - Attempts to fetch `WaveNumber` from `dbo.Wave` WHERE `WaveID = @WaveID AND Deleted = 0`.
   - **Bug note:** The query has a condition `WHERE WaveID = WaveID` which is always true and will match the first non-deleted Wave, not the intended one. Should be `WHERE WaveID = @WaveID`.
2. If `@WaveID` is null, sets `@WaveNumber = ''`.
3. If `@InvoiceReferences` is provided and non-empty:
   - Uses `@InvoiceReferences` as references.
4. Otherwise:
   - Uses `@OrderNumber` as references.
5. Inserts one row into `dbo.Invoice`:
   - `ChargeType = 'Standard'`, `ChargeCategory = 'Shipping'`, `Qty = 1`, `Cost = @Charge` (passed in).
   - `ItemReferences` is always empty string.

**Dependencies used by the procedure**

- `dbo.Wave` (for wave number lookup)
- `dbo.Invoice` (insert target)

**Net insert effect per single call**

- Creates exactly **1 row** per call (deterministic, simple insert).
- Not idempotent: repeat calls with same order/references will insert duplicates.

**Current risk notes**

- **Critical bug:** `WHERE WaveID = WaveID` condition always evaluates to true. The procedure will select the first non-deleted Wave row in the table, not the intended one. Callers relying on `WaveNumber` being correct will get incorrect values.
- `@Charge` is passed in without validation. Caller is responsible for ensuring it's non-negative and sensible.
- `@Currency` is passed in without validation (no check for supported currency codes).
- `ItemReferences` is hardcoded to empty string, providing no line-item detail.
- `@ChargeItemName` is passed in without validation; can be null or arbitrary text.
- No check whether the order actually exists (no FK validation).
- No check whether the wave actually exists before using `@WaveNumber`.

**Operational implication**

- This is a "leaf" procedure: it receives pre-calculated charges from AP/DHL parent procedures and simply writes them.
- Do not call this directly with arbitrary `@WaveID` values; the wave lookup bug will return wrong results.
- Callers should validate `@Charge > 0` and `@Currency` is in a known set before invoking this procedure.
- Since there are no active callers in the SQL repo (per documentation), this procedure may be invoked from the application/integration layer; ensure the application handles the WaveID bug or passes null.

---

### 9. Labour Service Invoice

**SP:** `SP_VI_TBL_Invoice_InsertLabourServiceInvoice`

- Iterates `ServiceLine` rows for a given `ServiceID`.
- Matches each `Activity` to a `ChargeItem.ChargeItemName` in group `'Labour Service'`, unit `'Person per Hour'`.
- Resolves rate via `GetCostInfoOfTenantByWarehouseCode`.
- `Qty = NumberOfHours × NumberOfPeople`, `Charge = Rate × Qty`.
- `ChargeCategory = 'Services - Stock Take'`.

---

### 10. Other Service Invoice

**SP:** `SP_VI_TBL_Invoice_InsertOtherServiceInvoice`

- Reads service name from `Service.ServiceName`.
- `@OtherCost` is passed directly by the caller — no lookup from charge tables.
- `Qty = 1`, `Charge = OtherCost`.
- `ChargeCategory = 'Services - Other'`, `ChargeType = 'Standard'`.

---

### 11. IT Platform Fee (Account Management)

**SP:** `SP_VI_TBL_Invoice_AutoCreatingITFlatformInvoices` _(scheduler-triggered)_

- Looks up `ChargeItem` named `'IT Platform /Customer Service fee'` (`ChargeItemGroup = 'Account Management'`, `ChargeItemUnit = 'Week'`).
- Iterates all tenants enrolled via `TenantChargeItem`.
- For each tenant, iterates all active warehouses.
- Resolves rate via `GetCostInfoOfTenantByWarehouseCode`.
- Only inserts if `@ChargeType IS NOT NULL` AND `@Charge != 0`.
- `ChargeType = 'IT Platform'`, `ChargeCategory = 'Account Management'`, `InvoiceReferences = 'Auto'`, `Qty = 1`.

---

## Charge Group vs Charge Item Pattern

The system uses two parallel pricing patterns:

| Pattern | Tables | When Used |
|---------|--------|-----------|
| **Charge Group** | `ItemChargeGroup` → `ChargeGroup` → `ChargeGroupCost` | Per-item, item-specific group rate. Used in Receiving, Picking, Packing per-unit charges. Rate is `Standard` only. |
| **Charge Item** | `TenantChargeItem` → `ChargeItemCost` or `TenantCustomCost` | Per-service, per-storage. Supports `Standard` and `Custom` tenant pricing. |

`InsertChargeGroupInvoice` implements the charge-group path:

```
Item → ItemChargeGroup (by category) → ChargeGroup → ChargeGroupCost (by unit + warehouse)
```

`GetCostInfoOfTenantByWarehouseCode` implements the charge-item path:

```
TenantChargeItem (by tenant + chargeItem) → ChargeType
  Standard → ChargeItemCost (by chargeItem + warehouse)
  Custom   → TenantCustomCost (by TenantChargeItemID + warehouse)
```

---

## Automatic Scheduler Invoices

Three SPs are intended to be executed on a **weekly schedule**:

| SP | Charge Item | ChargeType | Category |
|----|-------------|------------|----------|
| `AutoCreatingPalletStorageInvoices` | `Storage - PALLET` | `PalletStorage` | `Storage` |
| `AutoCreatingBayAllocationInvoices` | `Storage - BAY` | `BayAllocation` | `Storage` |
| `AutoCreatingITFlatformInvoices` | `IT Platform /Customer Service fee` | `IT Platform` | `Account Management` |

All three use explicit transactions with rollback on error. The first two use `EXECUTE AS OWNER`.

**Orchestration logic:** `SP_VI_TBL_ReportSchedule_RunReportSchedules` runs these three invoice schedulers only on Monday. Each call is wrapped in independent `TRY...CATCH`, so one scheduler failure does not block the others.

---

## Invoice Status Lifecycle

All invoices are created with `Status = 'Pending'`. The codebase does not contain status transition SPs in this repository — status changes (e.g. Approved, Paid) are expected to be managed by the application layer or external processing.

---

## Query / Reporting SPs

| SP | Purpose |
|----|---------|
| `SP_VI_TBL_Invoice_ListInvoices` | Paginated list with optional free-text search across `ChargeType`, `ChargeName`, `InvoiceReferences`, tenant name, warehouse name. Uses dynamic SQL. |
| `SP_VI_TBL_Invoice_SearchInvoices` | Filtered search by warehouse, tenant, category, date range, and free text. Uses parameterised dynamic SQL. |
| `SP_VI_TBL_ReportScript_TotalInvoiceWeeklyReport` | Weekly invoice report per tenant/warehouse. Populates `#TempInvoiceTable` with charge details for the report period. |
| `SP_VI_TBL_ReportScript_SummaryInvoiceWeeklyReport` | Summary version of the weekly invoice report. |

> **Security note:** `ListInvoices` builds a dynamic `ORDER BY` clause by concatenating `@OrderBy` and `@OrderDir` directly into the SQL string without validation. This is a SQL injection risk — the calling application must restrict these values to a known safe list.

---

## Charge Category Reference

| ChargeCategory | Trigger | SP |
|----------------|---------|-----|
| `Receiving` | Item received into inbound | `InsertReceivingInvoice`, `CompleteReceivingInvoice` |
| `Picking` | Item picked in wave | `InsertPickingInvoice` |
| `Packing` | Wave packing completed | `InsertPackingInvoice` |
| `Storage` | Weekly scheduler (pallet/bay) | `AutoCreatingPalletStorageInvoices`, `AutoCreatingBayAllocationInvoices`, `InsertBayAllocationInvoice`, `InsertPalletStorageInvoice` |
| `Regular` | Weekly scheduler (bin) | `InsertBinAllocationInvoice` |
| `Shipping` | Application/integration-triggered AP/DHL shipment invoicing (no active SQL caller in this repo) | `InsertAPMailingInvoice`, `InsertDHLMailingInvoice` |
| `Services - Stock Take` | Labour service completed | `InsertLabourServiceInvoice` |
| `Services - Other` | Ad-hoc service | `InsertOtherServiceInvoice` |
| `Account Management` | Weekly scheduler | `AutoCreatingITFlatformInvoices` |

---

## Key Observations

1. **Dual pricing architecture:** Items can have group-based pricing (`ItemChargeGroup` → `ChargeGroupCost`) and/or item-level pricing (`TenantChargeItem` → `ChargeItemCost`/`TenantCustomCost`). The insert SPs apply both in sequence for Receiving, Picking, and Packing.

2. **Tenant subscription gate:** For `ChargeItem`-based invoices, a tenant must have a `TenantChargeItem` record to be billed. If absent, `GetCostInfoOfTenantByWarehouseCode` returns `@ChargeType = NULL` and no invoice is inserted.

3. **Mailing charge is percentage-based:** Unlike most charges that are flat-rate lookups, AP and DHL shipping charges are calculated as `CEILING(carrier_cost × (1 + percent/100))`, making them dynamic based on actual shipment cost.

4. **Division support in bin allocation:** `ChargeItemCost` has a `Division` column allowing warehouses with multiple physical divisions to have different bin pricing. `InsertBinAllocationInvoice` supports this via `@Division` parameter.

5. **Pallet storage excludes Bay storage areas:** The auto-creating pallet storage SP explicitly skips ULDs in Bay and PerfectPick storage types to avoid double-billing with `AutoCreatingBayAllocationInvoices`.

6. **Mailing invocation ownership is external in current repo state:** AP/DHL invoice procedures are implemented, but SQL-side invocation is not active here (DHL call block is commented; AP call site not found), so mailing invoice timing depends on application/integration orchestration.
