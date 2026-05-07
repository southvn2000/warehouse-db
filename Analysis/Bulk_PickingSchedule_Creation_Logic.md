# Bulk PickingSchedule Creation Logic

This document explains how PickingSchedule rows are created when PickingType is Bulk.

## Scope

This logic applies to FulfilmentType = Orders with PickingType not equal to PickToOrder.
In practice, this means Single and Bulk share the same creation branch, while PickToOrder has a separate branch.

Main procedures:

- StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql
- StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql
- StoreProcedures/dbo.SP_VI_TBL_ULD_GetNextLocationForPicking.StoredProcedure.sql

## 1) Draft creation (before wave activation)

Procedure:
StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql

High level flow:

1. For Orders flow, it creates a staging table variable named @PickingScheduleTmpTable.
2. While iterating allocated ULD lines, if PickingType is not PickToOrder, rows are inserted into this staging table instead of directly into PickingSchedule.
3. After loops end, staged rows are aggregated and inserted into dbo.PickingSchedule.

Important behavior for Bulk:

- Rows are grouped by tenant, item, ULD, and location fields.
- Qty is aggregated with SUM(Qty).
- New rows are inserted with:
  - Status = Init
  - Deleted = 1 (draft/inactive)
- OrderNumber for inserted rows is then updated to one fulfilment order value captured in @FOrderNumber.

Result:
Bulk schedule rows exist first as draft rows and are not active until wave insertion step.

## 2) Wave insertion activates Bulk rows

Procedure:
StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql

High level flow:

1. Creates Wave and WaveLine records.
2. For Bulk or Single branch, updates matching PickingSchedule rows by:
   - setting Deleted = 0
   - setting WaveID = new wave id
   - setting OrderNumber = NULL

Why this matters:

- Bulk picking tasks become wave scoped (not per individual order in active state).
- This matches Bulk operating model where downstream sort is required.

## 3) Additional on-demand creation during picking

Procedure:
StoreProcedures/dbo.SP_VI_TBL_ULD_GetNextLocationForPicking.StoredProcedure.sql

When this happens:

- During picking, if more stock/ULD allocation is needed and PickingType is Single or Bulk.

Behavior:

- Procedure resolves location metadata.
- Inserts new PickingSchedule rows directly for next-location work.
- In this Single or Bulk branch, inserted rows use:
  - FulfilmentOrder = NULL
  - WaveID = current wave
  - Status = Init
  - Deleted = 0

Result:
Bulk waves can get extra active PickingSchedule rows after initial draft rows were activated.

## 4) Logic when PickStatus = 'Error'

Main procedure:

- StoreProcedures/dbo.SP_VI_TBL_WaveLine_UpdateOrdersStatus.StoredProcedure.sql

When an order is Failed during Picking, the system uses this flow:

1. Caller sends the order into SP_VI_TBL_WaveLine_UpdateOrdersStatus with Name = FulfilmentOrderNumber and Value = Failed in the @Orders TVP, and @Operation = Picking.

1. Procedure updates dbo.Fulfilment for that fulfilment order to FulfilmentStatus = Error.

1. Procedure updates dbo.WaveLine for that fulfilment order to PickStatus = Error, SortStatus = NULL, PackStatus = NULL.

1. Timestamps and operator audit fields are also updated: FirstEditedDateTime/FirstEditedBy (if empty) and LastEditedDateTime/LastEditedBy.

Operational effect on next steps:

- StartWaveRequest only generates Sorting data from rows where WaveLine.PickStatus = Completed.
- Therefore, orders with PickStatus = Error are excluded from Sorting generation.
- Since they do not enter Sorting, they will not progress to Packing in normal flow.

What this means for PickingSchedule:

- Existing PickingSchedule rows are not deleted by this error update procedure.
- The order is effectively blocked by WaveLine/Fulfilment status gates, not by removing PickingSchedule rows.
- In practice, these orders require retry/rework handling instead of automatic downstream progression.

## 5) Error case inside SP_VI_TBL_Wave_CompleteWaveRequest

Main procedure:

- StoreProcedures/dbo.SP_VI_TBL_Wave_CompleteWaveRequest.StoredProcedure.sql

Picking phase behavior:

1. The procedure always moves the wave to next step and updates WaveLine.PickStatus = Completed for all rows in the wave.

1. It then calculates failed orders by comparing required vs picked quantities from PickingSchedule.

1. For Bulk, failed quantities are computed per ItemNumber and TenantCode from PickingSchedule where Qty <> PickedQty, then mapped back to orders and returned as OrderNumber + Status (Failed/Completed).

1. It returns failed orders but does not itself set WaveLine.PickStatus = Error or FulfilmentStatus = Error in this Picking path.

Required follow-up:

- Application must call SP_VI_TBL_WaveLine_UpdateOrdersStatus with returned failed orders to persist Error status.
- Without that follow-up call, orders may be returned as Failed by CompleteWaveRequest result set while WaveLine status remains Completed.

Packing phase contrast:

- In Packing, this procedure directly sets WaveLine.PackStatus = Error for rows that have non-completed PackingResult.

## 6) Error case inside SP_VI_TBL_Wave_CompletePickingTask

Main procedure:

- StoreProcedures/dbo.SP_VI_TBL_Wave_CompletePickingTask.StoredProcedure.sql

Trigger for error handling branch:

- Branch starts when PickedQty is less than required PickingQty.
- Procedure tries replacement allocation by calling SP_VI_TBL_ULD_GetNextLocationForPicking.

Shared effects when picked quantity is short:

- Current ULD is locked with reason about quantity mismatch.
- TaskStatus is set to Failed if replacement ULD is not found, or Found if replacement ULD is found.

PickToOrder behavior when replacement is not found:

- Current PickingSchedule row is set to Status = Failed.
- Other related PickingSchedule rows in same wave are also set to Failed.
- Related allocated ULDLine entries are soft-deleted/reset.
- UpdateResult is set to 0, so PickingResult insertion is skipped for this task.

Single or Bulk behavior when replacement is not found:

- TaskStatus is set to Failed, but current PickingSchedule row is set to Status = End with PickedQty recorded.
- UpdateResult remains 1, so PickingResult rows are still inserted.
- This means task-level failure is represented by quantity shortfall and task status, not always by PickingSchedule.Status = Failed.

Behavior when replacement is found:

- Current PickingSchedule row is ended with picked quantity.
- Additional/related allocations are moved to new location rows.
- Related rows can still become Failed if related replacement allocation is not found.

Operational implication for wave-level failure detection:

- Do not rely only on PickingSchedule.Status = Failed for Bulk.
- CompleteWaveRequest computes failure mainly from Qty versus PickedQty mismatch and returns failed orders.
- Application still needs follow-up status persistence via SP_VI_TBL_WaveLine_UpdateOrdersStatus to mark WaveLine/Fulfilment as Error.

Recommended operational check for failed picking orders:

- Confirm dbo.WaveLine.PickStatus = Error for the order.
- Confirm dbo.Fulfilment.FulfilmentStatus = Error for the same fulfilment order.
- Confirm no Sort schedule data was generated for that order in the current wave.

## End-to-end summary for Bulk

1. CopyOrderToFulfilment prepares draft PickingSchedule tasks in grouped form (Deleted = 1).
2. Wave_InsertOrdersToWave activates them for the wave (Deleted = 0, WaveID assigned, OrderNumber cleared).
3. ULD_GetNextLocationForPicking may append additional active tasks while picking progresses.

## Quick validation SQL

Use this query set to inspect a Bulk wave lifecycle.

SELECT WaveID, WaveNumber, PickingType, WaveStatus, Deleted
FROM dbo.Wave
WHERE WaveNumber = '347';

SELECT
    ps.PickingScheduleID,
    ps.WaveID,
    ps.OrderNumber,
    ps.FulfilmentOrder,
    ps.ItemNumber,
    ps.Qty,
    ps.ULDID,
    ps.ULDCurrentLocation,
    ps.Status,
    ps.Deleted,
    ps.CreatedDateTime,
    ps.CreatedBy
FROM dbo.PickingSchedule ps
WHERE ps.WaveID = 347
ORDER BY ps.PickingScheduleID;

SELECT
    wl.WaveLineID,
    wl.WaveID,
    wl.WaveNumber,
    wl.OrderNumber,
    wl.SourceOrderNumber,
    wl.PickStatus,
    wl.SortStatus,
    wl.PackStatus,
    wl.MailStatus,
    wl.Deleted
FROM dbo.WaveLine wl
WHERE wl.WaveNumber = '347'
ORDER BY wl.WaveLineID;

SELECT
  f.OrderNumber AS FulfilmentOrderNumber,
  f.FulfilmentStatus,
  wl.PickStatus,
  wl.SortStatus,
  wl.PackStatus,
  wl.MailStatus,
  wl.WaveNumber
FROM dbo.Fulfilment f
JOIN dbo.WaveLine wl ON wl.OrderNumber = f.OrderNumber AND wl.Deleted = 0
WHERE wl.WaveNumber = '347'
ORDER BY f.OrderNumber;
