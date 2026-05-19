# SP_VI_TBL_Wave_CompletePickingTask - Logic Summary

## Purpose

Complete a picking task for a wave, then reconcile scheduling, invoicing, picking results, and ULD inventory movements in one transaction.

## Inputs and Outputs

- Inputs:
  - `@WaveID`, `@PickingScheduleID`
  - `@CompletedDateTime`, `@OperationBy`
  - `@Results` (`dbo.OrderPickingResultType`)
- Outputs:
  - `@TaskStatus`: `End` (full pick), `Found` (short pick but replacement found), `Failed` (short pick and no replacement)
  - `@Message`: validation or error message

## High-Level Flow

1. Start transaction.
2. Load wave and picking schedule context (wave mode, status, source order, current ULD, wave orders).
3. Validate guard conditions.
4. Compute picked quantity from `@Results`.
5. Branch by `@PickedQty < @PickingQty` (short pick) or full pick.
6. Create picking invoices from `@Results` and allocated ULD lines.
7. Optionally write `PickingResult` rows (`@UpdateResult = 1`).
8. Reconcile `ULDLine` entries for short-pick outcomes (`Failed` / `Found`), including `Not Found` and `Missing` records when needed.
9. Commit; on error, rollback and re-raise.

## Validations (Early Exit)

The procedure rolls back and returns when any check fails:

- Wave current step is not `Picking`.
- Wave step status is already `Completed`.
- Wave type is not `Orders`.
- Picking schedule status is not `Taken`.
- Picked qty is greater than scheduled qty.

## Branch Logic

### A) Short Pick (`@PickedQty < @PickingQty`)

#### PickToOrder

- Calls `SP_VI_TBL_ULD_GetNextLocationForPicking` for missing qty.
- If no replacement ULD:
  - `@TaskStatus = 'Failed'`
  - Marks current and related schedules as failed.
  - Clears related allocated `ULDLine` rows and resets sequence on affected ULDs.
  - Sets `@UpdateResult = 0` (skip `PickingResult` insert section).
- If replacement found:
  - `@TaskStatus = 'Found'`
  - Ends current schedule with adjusted qty.
  - Re-checks related orders on same ULD and either fails or reallocates them.

#### Non-PickToOrder (Bulk/Single)

- Calls `SP_VI_TBL_ULD_GetNextLocationForPicking` for missing qty.
- If no replacement:
  - `@TaskStatus = 'Failed'`
  - Ends current schedule with picked qty.
- If replacement found:
  - `@TaskStatus = 'Found'`
  - Ends current schedule with picked qty.

#### Common Short-Pick Action

- Locks current ULD via `SP_VI_TBL_ULD_UpdateLockedStatusByULD` with a discrepancy reason.

### B) Full Pick (`@PickedQty = @PickingQty`)

- Marks schedule as `End` and sets picked qty.
- `@TaskStatus = 'End'`.

## Invoice Creation

- Runs after main status branch.
- Iterates each item row in `@Results`.
- PickToOrder: creates invoice against the source order.
- Non-PickToOrder: resolves allocated order references from current ULD and creates invoices per order allocation.

## PickingResult Logging

- Runs only when `@UpdateResult = 1`.
- Inserts one `PickingResult` row per result entry, enriched with item/order/ULD metadata.

## ULDLine Reconciliation for `Failed` / `Found`

- Handles serial and non-serial items differently.
- Converts/removes existing `Allocated` lines.
- Inserts `Picked` / `PickedButFailed` movement lines as needed.
- For unaccounted remainder, inserts balancing `Not Found` and `Missing` lines.
- Resets ULD line sequence using `SP_VI_TBL_ULDLine_ResetULDLineSequence`.

## Main Tables Affected

- Read: `Wave`, `WaveLine`, `ULD`, `Items`.
- Write: `PickingSchedule`, `PickingResult`, `ULDLine`.

## Called Procedures

- `SP_VI_TBL_ULD_GetNextLocationForPicking`
- `SP_VI_TBL_ULD_UpdateLockedStatusByULD`
- `SP_VI_TBL_Invoice_InsertPickingInvoice`
- `SP_VI_TBL_ULDLine_ResetULDLineSequence`

## Transaction and Error Handling

- Wrapped in `BEGIN TRY ... END TRY / BEGIN CATCH ... END CATCH`.
- Any exception triggers rollback and `RAISERROR` with original error details.
