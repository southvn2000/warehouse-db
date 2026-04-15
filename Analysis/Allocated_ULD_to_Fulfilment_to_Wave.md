# Allocated ULD to Fulfilment to Wave Workflow

This note summarizes the workflow that starts from allocated `ULDLine` rows, moves through `SP_VI_TBL_Fulfilment_CopyOrderToFulfilment`, and then into `SP_VI_TBL_Wave_InsertOrdersToWave`.

## High-Level Sequence

1. Stock is allocated against one or more ULDs by creating `dbo.ULDLine` rows with `TransactionType = 'Allocated'`.
2. `SP_VI_TBL_Fulfilment_CopyOrderToFulfilment` reads those allocated ULD lines and creates draft fulfilment records plus draft picking schedule rows.
3. `SP_VI_TBL_Wave_InsertOrdersToWave` receives the created fulfilment IDs, creates the wave, creates wave lines, and activates the fulfilment and picking schedule rows.

Important: in this repository, `SP_VI_TBL_Wave_InsertOrdersToWave` does **not** call `SP_VI_TBL_Fulfilment_CopyOrderToFulfilment` directly, and `SP_VI_TBL_Fulfilment_CopyOrderToFulfilment` does **not** call `SP_VI_TBL_Wave_InsertOrdersToWave` directly. The orchestration happens outside these procedures, likely in the application or API layer.

## Step 1: Create Allocated ULDLine Rows

The standard order allocation path is in [dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql#L589).

Key behavior:

- It loops through candidate ULDs from `#TempULDTable`.
- It calculates how much stock to allocate per ULD.
- It soft-deletes any previous failed allocation row for the same `ULDID` and `@OrderNumber`.
- It inserts a new `dbo.ULDLine` row with:
  - `TransactionType = 'Allocated'`
  - `TransactionQty = -@AllocatedQty`
  - `TransactionReference = @OrderNumber`
  - `AllocatedType = 'Orders'`

Relevant insert block:

- Insert start: [dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql#L661)
- `TransactionType = 'Allocated'`: [dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql#L688)
- `TransactionReference = @OrderNumber`: [dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql#L690)
- `AllocatedType = 'Orders'`: [dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Items_CheckAvailableStockForOrder.StoredProcedure.sql#L695)

The storage columns are defined in [dbo.ULDLine.Table.sql](../Tables/dbo.ULDLine.Table.sql#L15) and [dbo.ULDLine.Table.sql](../Tables/dbo.ULDLine.Table.sql#L23).

## Step 2: Copy Order to Fulfilment from Allocated ULD Lines

The fulfilment creation procedure is [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L13).

### Inputs and Outputs

- It accepts `@FulfilmentType`, `@PickingType`, `@OrderNumbers`, and `@OrderItems`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L14)
- It collects created fulfilment IDs in `@NewFulfilmentIDs`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L33)
- It returns those IDs at the end: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L706)

### Fulfilment Header and Lines

For each order, the procedure inserts:

- A `dbo.Fulfilment` row with `Deleted = 1` and `FulfilmentStatus = 'Fulfilment'`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L71)
- Matching `dbo.FulfilmentLine` rows, also as draft rows with `Deleted = 1`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L102)

For normal order fulfilment, another insert block creates the fulfilment header and lines around:

- Fulfilment line insert: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L384)
- New fulfilment ID is pushed into `@NewFulfilmentIDs`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L413)

### Read Allocated ULDLine Rows

After creating the fulfilment, the procedure opens a cursor over allocated ULD lines for the current source order:

- Cursor definition: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L417)
- It reads from `dbo.ULDLine`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L425)
- It filters by `TransactionReference = @CurrentOrderNumber`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L430)
- It requires `TransactionType = 'Allocated'`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L432)
- It matches `AllocatedType = @FulfilmentType`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L433)

This is the key handoff from stock allocation into fulfilment generation.

### Build Picking Schedule Rows

From each allocated ULD line, the procedure resolves the warehouse/location structure and builds draft `dbo.PickingSchedule` rows.

There are two modes:

1. `PickToOrder`
   - It inserts directly into `dbo.PickingSchedule` with `Deleted = 1` and `Status = 'Init'`.
   - Direct insert blocks: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L510) and [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L534)

2. `Single` or `Bulk`
   - It first stages rows in `@PickingScheduleTmpTable`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L132)
   - It inserts staged rows here: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L567) and [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L588)
   - It later aggregates by ULD/location/item and inserts into `dbo.PickingSchedule`: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L640)
   - It then assigns the generated fulfilment order number back to those inserted rows: [dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Fulfilment_CopyOrderToFulfilment.StoredProcedure.sql#L692)

At the end of this step, the system has:

- `ULDLine` rows that still represent allocated stock
- Draft `Fulfilment` and `FulfilmentLine` rows with `Deleted = 1`
- Draft `PickingSchedule` rows with `Deleted = 1`
- A returned set of new `FulfilmentID` values

## Step 3: Insert Fulfilments into Wave

The wave creation procedure is [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L13).

### Inputs

- It receives `@FulfilmentIDs`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L14)
- It also receives `@FulfilmentType` and `@PickingType`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L15)

### Create Wave Header

The procedure creates a wave number, inserts a `dbo.Wave` row, and stores the new ID in `@NewWaveID`:

- Wave insert: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L103)
- `@NewWaveID = SCOPE_IDENTITY()`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L139)

### Create Wave Lines from Fulfilment

It loops through the incoming fulfilment IDs, reads the fulfilment header, and creates `dbo.WaveLine` rows:

- Cursor over `@FulfilmentIDs`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L141)
- It reads `OrderNumber`, `order_number`, and `TenantCode` from `dbo.Fulfilment`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L162)
- It inserts into `dbo.WaveLine`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L167)

### Activate Draft Picking Schedule

This is the main handoff from fulfilment stage into wave stage.

If `@FulfilmentType = 'Kitting'` or orders use `PickToOrder`, it activates picking schedule rows by source order number:

- Update start: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L227)
- It sets `Deleted = 0`, `WaveID = @NewWaveID`, and `OrderNumber = @OrderNumber`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L229)
- It matches draft rows on `FulfilmentOrder = @SourceOrderNumber`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L234)

If `@PickingType` is `Single` or `Bulk`, it activates rows by generated fulfilment order number instead:

- Alternate update start: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L240)
- It sets `Deleted = 0`, `WaveID = @NewWaveID`, and clears `OrderNumber`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L241)
- It matches draft rows on `OrderNumber = @OrderNumber`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L246)

### Activate Draft Fulfilment

After the wave line and picking schedule update, it activates the draft fulfilment rows:

- Fulfilment activation block: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L253)
- It sets `dbo.Fulfilment.Deleted = 0`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L256)
- It sets `dbo.FulfilmentLine.Deleted = 0`: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L264)

For `PickToOrder` waves, it also creates `dbo.PickingInfo` slot assignments:

- Picking info insert: [dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql](../StoreProcedures/dbo.SP_VI_TBL_Wave_InsertOrdersToWave.StoredProcedure.sql#L275)

## Practical End-to-End Data Flow

The workflow can be viewed as a staged process:

1. `dbo.ULDLine`
   - Create stock reservation rows with `TransactionType = 'Allocated'`
   - These rows are the stock source for fulfilment preparation

2. `dbo.Fulfilment` and `dbo.FulfilmentLine`
   - Created by `SP_VI_TBL_Fulfilment_CopyOrderToFulfilment`
   - Initially inserted with `Deleted = 1` as draft rows

3. `dbo.PickingSchedule`
   - Also created by `SP_VI_TBL_Fulfilment_CopyOrderToFulfilment`
   - Initially inserted with `Deleted = 1` and `Status = 'Init'`

4. `dbo.Wave` and `dbo.WaveLine`
   - Created by `SP_VI_TBL_Wave_InsertOrdersToWave`
   - This step attaches the fulfilment to an operational wave

5. Activation step
   - `SP_VI_TBL_Wave_InsertOrdersToWave` flips draft fulfilment and picking schedule rows from `Deleted = 1` to `Deleted = 0`
   - After this point, the fulfilment and picking schedule become active for execution

## Key Observation

The real dependency is not a procedure-to-procedure `EXEC` chain. The dependency is data-driven:

- Allocated `ULDLine` rows feed `SP_VI_TBL_Fulfilment_CopyOrderToFulfilment`
- Returned `FulfilmentID` rows feed `SP_VI_TBL_Wave_InsertOrdersToWave`

So the actual orchestration is:

1. Allocate stock
2. Call `SP_VI_TBL_Fulfilment_CopyOrderToFulfilment`
3. Take the returned fulfilment IDs
4. Call `SP_VI_TBL_Wave_InsertOrdersToWave`
