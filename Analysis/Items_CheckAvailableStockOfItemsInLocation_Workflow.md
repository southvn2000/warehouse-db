# SP_VI_TBL_Items_CheckAvailableStockOfItemsInLocation Workflow

This document explains the end-to-end workflow of:

- `StoreProcedures/dbo.SP_VI_TBL_Items_CheckAvailableStockOfItemsInLocation.StoredProcedure.sql`

## Purpose

Select up to `@NumberOfOrders` candidate orders that can be created from current stock, with optional location constraints.

The procedure validates each order, then attempts stock allocation/creation. Final order-level results are returned as `Created` or `Failed` with reason.

## Inputs

- `@NumberOfOrders INT`: max number of orders to create.
- `@OrderNumbers dbo.OrderType READONLY`: input order headers.
- `@OrderItems dbo.OrderLineType READONLY`: input order lines.
- `@LocationType VARCHAR(20) = NULL`: optional location scope (`Area`/`Section`).
- `@LocationID INT = NULL`: optional location identifier.
- `@PickingType VARCHAR(50) = NULL`: affects composite-item eligibility.
- `@OperationDateTime DATETIME = NULL`, `@OperationBy VARCHAR(100) = NULL`: audit fields for downstream updates.
- `@Message VARCHAR(4000) OUTPUT`: error message in catch block.

## Outputs

Result set:

- `SELECT * FROM @CreatedOrderNumbers`
- Typical statuses:
  - `Created`
  - `Failed` (with `Reason`)

## Main Data Structures

- `@AvailableOrderNumbers dbo.CheckOrderType`: collects **all** input orders after Phase 1 — both `Available` and `Error` statuses. Despite the name, Error orders are also present and processed in Phase 2.
- `@CreatedOrderNumbers dbo.CheckOrderType`: final outcome per processed order (only orders explicitly inserted here appear in the result set).
- `@AvailableOrderNumberItems dbo.OrderLineType`: per-order line items copied from input for the current iteration.
- `#TempMissingItemTable`: captures missing item details from `SP_VI_TBL_Items_CheckAvailableStockForOrder` (Branch A and failure paths).

## Workflow Overview

## 1) Pre-validation pass per order

For each row in `@OrderNumbers`:

1. Initialize `@IsOK = 1`.
2. Loop through all item numbers for this order from `@OrderItems`.
3. For each item:
   - Verify item exists for tenant (`dbo.Items`, `Deleted = 0`).
   - If `CarrierID = 3` (DHL), enforce non-empty `HsTariffCode`.
   - Determine if item is a composite order item (`CompositeType = 'Order'`).
4. Composite logic:
   - If composite and `@PickingType = 'Single'` => reject order (`@IsOK = 0`).
   - Otherwise expand child items using `fn_GetAllChildrenItemsOfCompositeItem` and check each child stock at location via `SP_VI_TBL_ULD_CheckHavingStockOfTenantAtLocation`.
5. Non-composite logic:
   - Check stock at location via `SP_VI_TBL_ULD_CheckHavingStockOfTenantAtLocation`.
6. Any validation/stock failure breaks item loop and marks order as `Error`; otherwise mark as `Available`.
7. All orders (both `Available` and `Error`) are inserted into `@AvailableOrderNumbers`.

> **Note on NULL location params:** `SP_VI_TBL_ULD_CheckHavingStockOfTenantAtLocation` is always called with whatever `@LocationID`/`@LocationType` were passed in, including NULL. When both are NULL the behavior depends on that SP's handling of NULL params (likely falls back to a warehouse-wide existence check). This pass is an eligibility filter only — it does not finalize order creation or write allocation rows.

## 2) Creation/allocation pass for available orders

If `@AvailableOrderNumbers` is not empty (it will contain all input orders, both `Available` and `Error`):

1. Iterate all rows in `@AvailableOrderNumbers` in cursor order.
2. Stop early when `COUNT(*) FROM @CreatedOrderNumbers = @NumberOfOrders`. Note: only explicitly inserted rows count — orders silently dropped in Branch A do not contribute to this count, meaning stock can be consumed beyond the intended `@NumberOfOrders` limit.
3. Load current order lines into `@AvailableOrderNumberItems`.
4. Branch on the pre-validation status of the current order:

### Branch A — `@Status = 'Error'` (pre-validation flagged an issue)

- Call `SP_VI_TBL_Items_CheckAvailableStockForOrder` with `@ReturnMissing = 1`.
- If `@IsEnough = 0`:
  - Build failure reason from `#TempMissingItemTable` as `ItemNumber_MissingType` list.
  - Revert any `Allocated` rows already in `dbo.ULDLine` for this order (`Deleted = 1`, audit fields updated).
  - Insert `Failed` into `@CreatedOrderNumbers` with the reason.
  - `CONTINUE` to next order.
- If `@IsEnough = 1`:
  - No insert into `@CreatedOrderNumbers`. The order silently falls out of the result set.
  - **Note:** This is a gap — an order that failed pre-validation but then passes the broad check is neither `Created` nor `Failed` in the output.

### Branch B — `@Status = 'Available'` (pre-validation passed)

Sub-branch on whether a location constraint was provided:

- **`IF @LocationID IS NULL OR @LocationType IS NULL`** (no location):
  - Calls `SP_VI_TBL_Items_CheckAvailableStockForOrderInLocation` passing NULL `@LocationType`/`@LocationID`.
- **`ELSE`** (location IS provided — comment in code reads `-- not location`, which is misleading):
  - Calls `SP_VI_TBL_Items_CheckAvailableStockForOrder` (warehouse-wide; carrier/picking-type validations apply).

> **Bug — conditions are inverted.** When a location constraint IS provided, you would expect `CheckAvailableStockForOrderInLocation` to run so stock is verified at that specific location. Instead the code calls the warehouse-wide `CheckAvailableStockForOrder`, which ignores the location entirely. When no location is provided, the code calls `CheckAvailableStockForOrderInLocation` with NULL location params. See [Known Issue: Branch B IF/ELSE condition is inverted](#known-issue-branch-b-ifelse-condition-is-inverted).

In both sub-branches:

- If `@IsEnough = 1` => insert `Created` into `@CreatedOrderNumbers`.
- If `@IsEnough = 0` => revert `Allocated` rows in `dbo.ULDLine` for this order, insert `Failed` with reason `Not enough stock for item`.

**Note:** Only **one** sub-procedure is called per order per iteration. Rollback is present in both failure paths within Branch B.

## Decision Points

- Item existence by tenant.
- DHL item tariff requirement (`HsTariffCode`).
- Composite item + picking type compatibility.
- Child-item stock availability in chosen location scope.
- Whether pre-validation `@Status` is `Error` or `Available` (drives which sub-procedure is called).
- Whether a location constraint is provided (drives which allocator runs in Branch B).
- Early cutoff when created count reaches requested order count.

## Side Effects

- Both failure branches revert `Allocated` rows in `dbo.ULDLine` (`Deleted = 1`) written by the sub-procedure, with audit timestamp/user fields updated.
- An `Error`-status order that passes the broad check (`@IsEnough = 1`) in Branch A writes `Allocated` rows but is **not inserted** into `@CreatedOrderNumbers` — stock is allocated but no result row is returned for that order.

## Error Handling

- Wrapped in `TRY...CATCH`.
- On exception, sets `@Message = ERROR_MESSAGE()`.
- Procedure does not raise exception outward (rethrow is commented out).

## Dependencies

- `dbo.SP_VI_TBL_ULD_CheckHavingStockOfTenantAtLocation`
- `dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder`
- `dbo.SP_VI_TBL_Items_CheckAvailableStockForOrderInLocation`
- `dbo.fn_GetAllChildrenItemsOfCompositeItem`
- `dbo.Items`
- `dbo.ULDLine`

## Practical Notes

- The procedure uses multiple cursors and `GOTO` for early exit in validation loops.
- Processing order of input rows affects which orders become `Created` when `@NumberOfOrders` limit is reached.
- Broad stock check can allocate before final location check, requiring explicit rollback path in this procedure.

---

## Known Issue: Silent Drop of Error-Status Orders That Pass Broad Check

### What happens

In Branch A (`@Status = 'Error'`), when `SP_VI_TBL_Items_CheckAvailableStockForOrder` returns `@IsEnough = 1` (the order actually has enough warehouse stock despite failing pre-validation), the procedure:

- Writes `Allocated` rows to `dbo.ULDLine` (side effect of the sub-procedure).
- Does **not** insert a row into `@CreatedOrderNumbers`.
- Moves on to the next cursor row.

The order is silently dropped from the output result set. The caller receives no `Created` or `Failed` row for it, yet stock has been consumed.

### Why this matters for callers

The caller expects every input order to appear in the result set as either `Created` or `Failed`. A missing row means:

- The order cannot be acted on (no creation confirmation).
- The `Allocated` ULDLine rows remain active, reducing available stock for subsequent orders.

### Recommended fix

Add a `Created` insert for the `@IsEnough = 1` arm of Branch A:

```sql
IF @IsEnough = 0
BEGIN
    -- existing failure logic ...
END
ELSE
BEGIN
    -- Add this missing branch:
    INSERT INTO @CreatedOrderNumbers (OrderNumber, TenantCode, WarehouseCode, Status)
    VALUES (@CurrentOrderNumber, @TenantCode, @WarehouseCode, 'Created');
END
```

### Note: double-allocation issue is resolved in current code

An earlier version (now commented out at the bottom of the procedure) called `CheckAvailableStockForOrder` first and then `CheckAvailableStockForOrderInLocation` in sequence, which could cause double-allocation and missing rollback when the location check failed. The current live code calls only **one** sub-procedure per order and has rollback in both Branch B failure paths — that specific issue no longer applies.

---

## Known Issue: Branch B IF/ELSE Condition Is Inverted

### Root cause

The current code in Branch B reads:

```sql
ELSE --  @Status = 'Available'
BEGIN
    IF @LocationID IS NULL OR @LocationType IS NULL
    BEGIN
        -- No location provided → calls InLocation SP with NULL params
        EXEC [dbo].[SP_VI_TBL_Items_CheckAvailableStockForOrderInLocation]
            @LocationType = @LocationType,  -- NULL
            @LocationID   = @LocationID,    -- NULL
            ...
    END
    ELSE -- comment says "not location" but this runs when location IS provided
    BEGIN
        -- Location IS provided → calls warehouse-wide SP (location is ignored)
        EXEC [dbo].[SP_VI_TBL_Items_CheckAvailableStockForOrder]
            ...
    END
END
```

The practical effect:

| Location params | SP called | Location actually checked? |
| --- | --- | --- |
| NULL (not provided) | `CheckAvailableStockForOrderInLocation` with NULL | No — NULL location means warehouse-wide inside that SP |
| Provided | `CheckAvailableStockForOrder` | No — this SP never receives location params |

In both paths the allocation is warehouse-wide. The `@LocationID`/`@LocationType` inputs to the parent procedure have no effect on which ULDs are selected for allocation in Branch B.

### Impact

- Callers passing a specific `@LocationID` to constrain stock selection to an area or section will not get location-scoped allocation — any warehouse ULD may be picked.
- The pre-validation pass (Section 1) does filter by location (via `SP_VI_TBL_ULD_CheckHavingStockOfTenantAtLocation`), but that is only an existence check. The actual allocation in Branch B does not honour the same location scope.

### Fix

Swap the condition so the location-scoped SP is called when location IS provided:

```sql
IF @LocationID IS NOT NULL AND @LocationType IS NOT NULL
BEGIN
    -- Location provided → check and allocate within that location
    EXEC [dbo].[SP_VI_TBL_Items_CheckAvailableStockForOrderInLocation]
        @LocationType = @LocationType,
        @LocationID   = @LocationID,
        ...
END
ELSE
BEGIN
    -- No location constraint → warehouse-wide allocation with carrier/picking-type rules
    EXEC [dbo].[SP_VI_TBL_Items_CheckAvailableStockForOrder]
        @CarrierID   = @CarrierID,
        @PickingType = @PickingType,
        ...
END
```
