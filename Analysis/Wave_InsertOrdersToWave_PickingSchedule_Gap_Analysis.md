# Wave Insert Orders to Wave - PickingSchedule Gap Analysis

## Scope

- Procedure analyzed: [StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql)
- Main concern: order can be added to wave, but no PickingSchedule row is linked/activated.

## Current Workflow Summary

1. Create Wave record with status Pending.
2. Loop each FulfilmentID and insert one WaveLine with PickStatus = Pending.
3. Attempt to activate/link PickingSchedule rows:

- Kitting or PickToOrder: match by FulfilmentOrder + FulfilmentType + tenant condition.
- Single/Bulk: match by OrderNumber + FulfilmentType + tenant condition.

4. Update Fulfilment to FulfilmentStatus = Fulfilment (always, if draft row exists).
2. For Orders + PickToOrder, always create PickingInfo slot.

## Confirmed Gap

The procedure does not verify whether the PickingSchedule update actually affected any rows.

Result:

- WaveLine exists and stays PickStatus = Pending.
- Fulfilment is moved to Fulfilment.
- PickingInfo may be created (PickToOrder).
- But there may be zero active PickingSchedule rows for that order in the wave.

This creates an inconsistent wave state where an order is in the wave without executable picking tasks.

## Why This Happens

The UPDATE against PickingSchedule is conditional and depends on draft data alignment.
If no rows match (for example, wrong source key, tenant mismatch, missing pre-created draft rows), SQL executes successfully but affects 0 rows.
There is no @@ROWCOUNT guard or fallback error-status transition.

## Impact

- Order appears in wave but cannot progress through picking schedule flow.
- Downstream completion logic may classify/derive failures unpredictably.
- Operations team sees a wave order that has no real picking task rows.

## Recommended Fix Pattern

Inside the loop, after each PickingSchedule UPDATE branch:

1. Capture @@ROWCOUNT into local variable (example: @PickingScheduleUpdated).
2. If @PickingScheduleUpdated = 0:

- Mark WaveLine as error for picking:
  - PickStatus = Error
  - SortStatus = NULL
  - PackStatus = NULL
- Mark Fulfilment as Error instead of Fulfilment.
- Do not create PickingInfo slot for this order.

## Suggested SQL Change Points

In [StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql):

- Add variable declaration near loop variables:
  - DECLARE @PickingScheduleUpdated INT;
- After each PickingSchedule UPDATE branch, set:
  - SET @PickingScheduleUpdated = @@ROWCOUNT;
- Add guard block:
  - IF ISNULL(@PickingScheduleUpdated, 0) = 0
    - UPDATE WaveLine ... PickStatus = 'Error'
- Change Fulfilment status assignment:
  - FulfilmentStatus = CASE WHEN ISNULL(@PickingScheduleUpdated, 0) = 0 THEN 'Error' ELSE 'Fulfilment' END
- Restrict PickingInfo insert:
  - only when ISNULL(@PickingScheduleUpdated, 0) > 0

## Validation Queries

Use these checks after running wave insertion:

### 1) Orders in wave without active PickingSchedule

SELECT wl.WaveID, wl.OrderNumber, wl.SourceOrderNumber, wl.PickStatus
FROM dbo.WaveLine wl
LEFT JOIN dbo.PickingSchedule ps
  ON ps.WaveID = wl.WaveID
 AND ps.OrderNumber = wl.OrderNumber
 AND ps.Deleted = 0
WHERE wl.WaveID = @WaveID
  AND wl.Deleted = 0
  AND ps.PickingScheduleID IS NULL;

### 2) Fulfilment status alignment

SELECT f.FulfilmentID, f.OrderNumber, f.FulfilmentStatus, wl.PickStatus
FROM dbo.Fulfilment f
JOIN dbo.WaveLine wl ON wl.OrderNumber = f.OrderNumber
WHERE wl.WaveID = @WaveID
  AND wl.Deleted = 0;

## Expected Behavior After Fix

- Any order added to wave without matching PickingSchedule is explicitly marked as error order in wave context.
- Fulfilment state reflects Error for that mismatch.
- PickingInfo is created only for orders that have valid picking schedule linkage.
