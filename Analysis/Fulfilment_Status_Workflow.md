# Fulfilment Status Workflow

This document summarises all `FulfilmentStatus` values, the stored procedures that set them, and the full lifecycle of a fulfilment order from creation to completion.

---

## FulfilmentStatus Values

| Status | Description |
| --- | --- |
| `Fulfilment` | Draft stage — record created but not yet active in a wave |
| `Moved` | Previous draft for the same source order was superseded; old row marked as moved |
| `Started` | Fulfilment is actively assigned to a wave and warehouse operations have started |
| `Error` | One or more wave operations (Pick / Sort / Pack) failed for this order |
| `Completed` | All required wave operations (up to and including Packing or Mailing) are done |
| `Cancelled` | Order was cancelled before completion (Kitting service only) |

> **Column definition** (`dbo.Fulfilment.FulfilmentStatus`, `varchar(30)`):  
> Extended property documents the values as: `Active, Picked, Packed, Lodged, Deleted`  
> — however, the stored procedures use the values in the table above.

---

## Status Transition Map

```text
[Stock Allocated]
      │
      ▼
  Fulfilment (Deleted = 1)   ← draft row, created by SP_VI_TBL_Fulfilment_CopyOrderToFulfilment
      │
      │  SP_VI_TBL_Wave_InsertOrdersToWave
      │  • activates row: Deleted = 0
      │  • keeps FulfilmentStatus = 'Fulfilment' (standard orders)
      │  • OR sets FulfilmentStatus = 'Started' (manual / kitting orders)
      │
      ▼
  Fulfilment / Started
      │
      │  SP_VI_TBL_Wave_StartWaveRequest  (when WaveStatus = 'Pending')
      │  • sets FulfilmentStatus = 'Started'
      │
      ▼
   Started
      │
      ├─── [Error path] ──────────────────────────────────────────────────────►  Error
      │      SP_VI_TBL_WaveLine_UpdateOrdersStatus
      │
      │  SP_VI_TBL_Wave_CompleteWaveRequest  (Packing operation complete)
      │  SP_VI_TBL_Manifest_UpdateManifest   (Mailing / manifest lodged)
      │  SP_VI_TBL_ReportScript_CloseJobManualReport (Manual job close)
      │  SP_VI_TBL_Service_CompleteKittingService    (Kitting only)
      ▼
  Completed
```

---

## Procedure-by-Procedure Breakdown

### 1. SP_VI_TBL_Fulfilment_CopyOrderToFulfilment

**Trigger:** Application calls this to prepare fulfilments from allocated stock.

| Action | Result |
| --- | --- |
| Insert `dbo.Fulfilment` with `Deleted = 1` | `FulfilmentStatus = 'Fulfilment'` (draft) |
| If a previous draft exists for the same source order | Old row updated to `FulfilmentStatus = 'Moved'` |
| Insert `dbo.FulfilmentLine` with `Deleted = 1` | Draft lines created alongside header |
| Insert `dbo.PickingSchedule` with `Deleted = 1`, `Status = 'Init'` | Draft picking tasks created |

At this point nothing is visible to warehouse operations.

---

### 2. SP_VI_TBL_Wave_InsertOrdersToWave

**Trigger:** Application calls this with the `FulfilmentID` list returned by step 1.

| Action | Result |
| --- | --- |
| Creates `dbo.Wave` row with `WaveStatus = 'Pending'` | Wave header created |
| Creates `dbo.WaveLine` rows | Links fulfilments to the wave |
| Updates `dbo.Fulfilment.Deleted = 0`, `dbo.FulfilmentLine.Deleted = 0` | Draft rows become active |
| Updates `dbo.PickingSchedule.Deleted = 0` | Draft picking tasks become active |
| For **manual orders**: `FulfilmentStatus = 'Started'` | Immediate start for manual jobs |
| For **standard orders**: `FulfilmentStatus = 'Fulfilment'` | Stays in Fulfilment until wave starts |

---

### 3. SP_VI_TBL_Wave_StartWaveRequest

**Trigger:** Warehouse operator starts a wave operation (Picking / Sorting / Packing / Mailing).

| Condition | Action |
| --- | --- |
| `WaveStatus = 'Pending'` (first operation) | Sets `WaveStatus = 'Started'` and `FulfilmentStatus = 'Started'` on all linked fulfilments |
| `WaveStatus = 'Started'` (subsequent operations) | Creates schedule data for the next operation step (Sort / Pack / Mail); no FulfilmentStatus change |

---

### 4. SP_VI_TBL_WaveLine_UpdateOrdersStatus

**Trigger:** A warehouse operation reports a failure.

| Action | Result |
| --- | --- |
| Sets `FulfilmentStatus = 'Error'` on the affected orders | `PickStatus = 'Error'`, `SortStatus = 'Error'`, `PackStatus = 'Error'` also updated |

### How Error Fulfilments Drop Out Of The Next Phase

When a fulfilment fails in **Picking**, **Sorting**, or **Packing**, it is **not physically removed** from `dbo.WaveLine`. Instead, it is excluded from the next operational phase by status-based filtering.

#### Step 1. Failure is recorded against the fulfilment and wave line

`SP_VI_TBL_WaveLine_UpdateOrdersStatus` marks the order as errored:

- `dbo.Fulfilment.FulfilmentStatus = 'Error'`
- If Picking failed: `dbo.WaveLine.PickStatus = 'Error'`, and later statuses are cleared
- If Sorting failed: `dbo.WaveLine.SortStatus = 'Error'`, and `PackStatus` is cleared
- If Packing failed: `dbo.WaveLine.PackStatus = 'Error'`

So the order still belongs to the same wave, but it no longer satisfies the criteria for the next phase.

#### Step 2. The next phase only pulls rows that completed the previous phase

`SP_VI_TBL_Wave_StartWaveRequest` generates data for the next phase using only successfully completed wave lines:

- **Sorting** data is created only for rows where `wl.PickStatus = 'Completed'`
- **Packing** data is created only for rows where `wl.SortStatus = 'Completed'`

That means:

- A fulfilment with `PickStatus = 'Error'` will not be included in Sorting
- A fulfilment with `SortStatus = 'Error'` will not be included in Packing
- A fulfilment with `PackStatus = 'Error'` will not move on to Mailing / completion logic

#### Step 3. Practical outcome

Errored fulfilments are therefore eliminated from later wave phases by **eligibility rules**, not by deleting them from the wave.

In short:

```text
WaveLine stays in the wave
    +
Status becomes Error
    +
Next phase selects only Completed rows
    =
Errored fulfilment drops out of Sorting / Packing / Mailing work
```

#### Important implementation note

For **Picking** and **Sorting**, `SP_VI_TBL_Wave_CompleteWaveRequest` broadly advances wave-line statuses and returns failed orders in its result set, but the actual persistent `Error` status is applied by `SP_VI_TBL_WaveLine_UpdateOrdersStatus`.

So if the application does not call `SP_VI_TBL_WaveLine_UpdateOrdersStatus` after receiving failed orders, the errored fulfilments may appear to continue in the wave even though the intended design is to exclude them.

For **Packing**, `SP_VI_TBL_Wave_CompleteWaveRequest` directly updates failed rows back to `PackStatus = 'Error'`.

---

### 5. SP_VI_TBL_Wave_CompleteWaveRequest

**Trigger:** Warehouse operator completes a wave operation step.

| Operation | Action |
| --- | --- |
| Picking | Records pick results; no FulfilmentStatus change yet |
| Sorting | Records sort results; no FulfilmentStatus change yet |
| Packing | Sets `FulfilmentStatus = 'Completed'` for all successfully packed fulfilments |
| Mailing | Handled by SP_VI_TBL_Manifest_UpdateManifest (see below) |

---

### 6. SP_VI_TBL_Manifest_UpdateManifest

**Trigger:** Carrier manifest is lodged (Australia Post / DHL Express mailing step).

| Action | Result |
| --- | --- |
| Sets `FulfilmentStatus = 'Completed'` on all linked orders | `WaveStatus = 'Completed'` also set |

---

### 7. SP_VI_TBL_Service_CancelKittingService *(Kitting only)*

**Trigger:** Kitting service job is cancelled before completion.

| Action | Result |
| --- | --- |
| Sets `FulfilmentStatus = 'Cancelled'` | `WaveStatus = 'Cancelled'` also set |

---

### 8. SP_VI_TBL_Service_CompleteKittingService *(Kitting only)*

**Trigger:** Kitting service job completes successfully.

| Action | Result |
| --- | --- |
| Sets `FulfilmentStatus = 'Completed'` | `WaveStatus = 'Completed'` also set |

---

## FulfilmentType Context

Status transitions apply across all fulfilment types, though some transitions are type-specific:

| FulfilmentType | Notes |
| --- | --- |
| `Orders` | Standard tenant orders; follows the full wave workflow |
| `Kitting` | Uses `SP_VI_TBL_Service_*` procedures; can reach `Cancelled` |
| `Release Stock` | Listed in SP parameters; follows Orders-like path |
| `Destroy Stock` | Listed in SP parameters; follows Orders-like path |

---

## OnHold Flag

`dbo.Fulfilment.OnHold` (`bit`, default `0`) is a parallel flag that pauses the order from appearing in operational lists without changing `FulfilmentStatus`. All list/search procedures filter with `AND OnHold = 0`.

---

## Wave Status Reference

Wave status (`dbo.Wave.WaveStatus`) runs in parallel with `FulfilmentStatus`:

| WaveStatus | Meaning |
| --- | --- |
| `Pending` | Wave created, no operation started yet |
| `Started` | At least one operation step has begun |
| `Completed` | All required operations finished |
| `Cancelled` | Kitting service cancelled |

---

## Related Files

- Table definition: [dbo.Fulfilment.Table.sql](../Tables/dbo.Fulfilment.Table.sql)
- Table definition: [dbo.Wave.Table.sql](../Tables/dbo.Wave.Table.sql)
- Workflow detail: [Allocated_ULD_to_Fulfilment_to_Wave.md](Allocated_ULD_to_Fulfilment_to_Wave.md)
- SP: [SP_VI_TBL_Fulfilment_CopyOrderToFulfilment](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql)
- SP: [SP_VI_TBL_Wave_InsertOrdersToWave](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql)
- SP: [SP_VI_TBL_Wave_StartWaveRequest](../StoreProcedures/dbo.SP_VI_TBL_Wave_StartWaveRequest.StoredProcedure.sql)
- SP: [SP_VI_TBL_Wave_CompleteWaveRequest](../StoreProcedures/dbo.SP_VI_TBL_Wave_CompleteWaveRequest.StoredProcedure.sql)
- SP: [SP_VI_TBL_WaveLine_UpdateOrdersStatus](../StoreProcedures/dbo.SP_VI_TBL_WaveLine_UpdateOrdersStatus.StoredProcedure.sql)
- SP: [SP_VI_TBL_Manifest_UpdateManifest](../StoreProcedures/dbo.SP_VI_TBL_Manifest_UpdateManifest.StoredProcedure.sql)
