# Bulk Wave Workflow — Picking Phase & Error Handling

## Overview

Three stored procedures collaborate to manage the Bulk picking phase of a Wave:

| SP | When Called | Scope |
|----|-------------|-------|
| `SP_VI_TBL_Wave_CompletePickingTask` | Per picking task (per ULD/PickingSchedule) | Physical pick from one ULD |
| `SP_VI_TBL_Wave_CompleteWaveRequest` | Once, when ALL tasks are done | Wave-level phase transition |
| `SP_VI_TBL_WaveLine_UpdateOrdersStatus` | After CompleteWaveRequest returns result set | Per-order Error stamping |

---

## Part 1 — SP_VI_TBL_Wave_CompletePickingTask

### Signature

```sql
SP_VI_TBL_Wave_CompletePickingTask
    @WaveID              INT,
    @PickingScheduleID   INT,
    @CompletedDateTime   DATETIME,
    @OperationBy         VARCHAR(100),
    @Results             dbo.OrderPickingResultType READONLY,  -- scanned items
    @TaskStatus          VARCHAR(20) OUTPUT,   -- 'End' | 'Failed' | 'Found'
    @Message             VARCHAR(4000) OUTPUT
```

### Pre-checks (abort if any fails)

- `Wave.CurrentStep = 'Picking'`
- `Wave.StepStatus ≠ 'Completed'`
- `Wave.WaveType = 'Orders'`
- `PickingSchedule.Status = 'Taken'`
- `PickedQty ≤ PickingQty`

### Bulk path — decision tree

```
Worker submits scanned result (@PickedQty)
              │
    ┌─────────▼──────────────────────────────────────────┐
    │        PickedQty = PickingQty (full pick)?          │
    └─────────────────────────────────────────────────────┘
         YES │                              NO │
             ▼                                 ▼
    TaskStatus = 'End'          Try SP_VI_TBL_ULD_GetNextLocationForPicking
    PickingSchedule:              (find replacement ULD for short qty)
      Status='End'                          │
      PickedQty=@PickingQty     ┌───────────▼───────────┐
                                │  Replacement found?    │
    ULDLine changes:            └───────────────────────┘
    · 'Allocated' → 'Picked'     NOT FOUND │   FOUND │
    · Insert invoices                      │          │
    (per order in ULD)                     ▼          ▼
                             TaskStatus='Failed'  TaskStatus='Found'
                             PickingSchedule:     PickingSchedule:
                               Status='End'         Status='End'
                               PickedQty=actual     Qty = @PickedQty  ← qty reduced
                                                    PickedQty=@PickedQty
                                                  New PickingSchedule created
                                                  for replacement ULD (Status='Taken')
```

### When TaskStatus = 'Failed' or 'Found' — ULDLine redistribution

#### Background: what is `@ULDOrderNumbers`?

Before any redistribution, the SP builds `@ULDOrderNumbers` by querying `dbo.ULDLine` for the current ULD:

```sql
SELECT DISTINCT ul.TransactionReference,   -- the order number (FOrderNumber)
                ul.TransactionQty,          -- stored as NEGATIVE (e.g. -4)
                ul.ULDLineID
FROM dbo.ULDLine AS ul
WHERE ul.ULDID = @CurrentULDID
  AND ul.Deleted = 0
  AND ul.TransactionType = 'Allocated'      -- only pre-allocated lines
  AND ul.TransactionReference IN (WaveOrderNumbers)
```

Each row is one **Allocated** line — meaning: before the pick, N units of the item were reserved (allocated) in this ULD for a specific order. The `TransactionQty` is negative by convention (e.g. `-4` means 4 units allocated).

`@TmpQty` is initialised to `@PickedQty` (the actual units the worker physically scanned/picked).

---

#### Redistribution cursor — order of iteration

```sql
DECLARE ULDOrdersCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT SourceOrderNumber, TransactionQty, ULDLineID
    FROM @ULDOrderNumbers
    ORDER BY TransactionQty DESC;   -- DESC on negative values = biggest absolute qty first
                                   -- e.g. -2, -4, -6 → order of 2 units, then 4, then 6
```

> Smallest-quantity orders are processed **first**, so they get stock priority.

Inside the loop, `@RelatedTransactionQty` is flipped to positive:  
`SET @RelatedTransactionQty = -@RelatedTransactionQty`

---

#### Case-by-case: TaskStatus = 'Failed' (no replacement ULD found)

For each Allocated ULDLine row:

---

**Case 1 — TmpQty = 0 (stock exhausted before reaching this order)**

```
Condition : @TmpQty = 0

ULDLine update:
  UPDATE dbo.ULDLine
  SET Deleted = 1                       -- soft-delete the Allocated line
  WHERE ULDLineID = @ULDLineID

Invoice : None
TmpQty  : stays 0
```

The order's allocation is simply removed. The order will have no picked units recorded.

---

**Case 2 — TmpQty = RelatedTransactionQty (exactly enough stock for this order)**

```
Condition : @TmpQty = @RelatedTransactionQty

ULDLine update:
  UPDATE dbo.ULDLine
  SET TransactionType     = 'Picked'
      TransactionMovement = 'Picked N ItemNumber for OrderNumber order'
      -- TransactionQty unchanged, still = -RelatedTransactionQty (original full qty)
  WHERE ULDLineID = @ULDLineID

Invoice : SP_VI_TBL_Invoice_InsertPickingInvoice
          @ItemQty = @RelatedTransactionQty   (full order qty)
TmpQty  : SET @TmpQty = 0
```

The Allocated line is promoted to Picked with its original full quantity. Invoice covers the full order.

---

**Case 3 — TmpQty < RelatedTransactionQty (partial stock — order cannot be fully filled)**

```
Condition : @TmpQty < @RelatedTransactionQty

ULDLine update:
  UPDATE dbo.ULDLine
  SET TransactionType     = 'Picked'
      TransactionQty      = -@TmpQty           -- ← qty REDUCED to what was actually available
      TransactionMovement = 'Picked TmpQty ItemNumber for OrderNumber order'
  WHERE ULDLineID = @ULDLineID

Invoice : SP_VI_TBL_Invoice_InsertPickingInvoice
          @ItemQty = @TmpQty               (only the partial qty)
TmpQty  : SET @TmpQty = 0
```

This order is partially fulfilled. The ULDLine qty is reduced from its original allocation to only what was physically picked. The remaining gap (`RelatedTransactionQty - TmpQty`) will appear in the Missing entries below.

---

**Case 4 — TmpQty > RelatedTransactionQty (more stock than needed, full fill for this order)**

```
Condition : @TmpQty > @RelatedTransactionQty

ULDLine update:
  UPDATE dbo.ULDLine
  SET TransactionType     = 'Picked'
      TransactionMovement = 'Picked N ItemNumber for OrderNumber order'
      -- TransactionQty unchanged, still = -RelatedTransactionQty
  WHERE ULDLineID = @ULDLineID

Invoice : SP_VI_TBL_Invoice_InsertPickingInvoice
          @ItemQty = @RelatedTransactionQty   (full order qty)
TmpQty  : SET @TmpQty = @TmpQty - @RelatedTransactionQty
```

This order is fully filled. TmpQty is reduced by the amount consumed. The loop continues to the next order with the remaining stock.

---

#### After all orders are processed — 'Not Found' + 'Missing' entries

Once the cursor closes, the SP checks whether the ULDLine balance in the current ULD is still positive (meaning some allocated qty was never matched to a picked qty):

```sql
SELECT @MissingNumber = SUM(TransactionQty)     -- sum of negative values still on the ULD
FROM dbo.ULDLine
WHERE ULDID = @CurrentULDID
  AND Deleted = 0
  AND TransactionType NOT IN ('Not Found', 'Missing')
GROUP BY ULDID;
```

If `@MissingNumber > 0`, two audit ULDLine records are inserted:

| New ULDLine row | TransactionType | TransactionQty | TransactionReference | Meaning |
|---|---|---|---|---|
| 1 | `'Not Found'` | `-@MissingNumber` | `@WaveNumber` | Units expected but not physically found in the ULD |
| 2 | `'Missing'` | `-@MissingNumber` | `@WaveNumber` | Units confirmed missing from inventory |

Both rows point to `@CurrentULDID` and record the wave number as the reference.

---

#### Case-by-case: TaskStatus = 'Found' (replacement ULD was located)

When a replacement ULD exists (`@NewULDID` is not NULL), the logic differs — the goal is to split stock between the current ULD (partial pick) and the new ULD (remainder to pick later):

| TmpQty condition | Current ULD action | New ULD action |
|---|---|---|
| `TmpQty = 0` (nothing picked for this order) | — | Insert **new Allocated** line in `@NewULDID` for full `RelatedTransactionQty` |
| `TmpQty = RelatedTransactionQty` (full pick) | `TransactionType = 'Picked'`, invoice for full qty | — |
| `TmpQty < RelatedTransactionQty` (partial pick) | `TransactionType = 'Picked'`, `TransactionQty = -TmpQty`, invoice for TmpQty | Insert **new Allocated** line in `@NewULDID` for remaining `RelatedTransactionQty - TmpQty` |
| `TmpQty > RelatedTransactionQty` (full pick, surplus) | `TransactionType = 'Picked'`, invoice for `RelatedTransactionQty` | — |

The new Allocated lines in `@NewULDID` become the input for the next picking task on the replacement ULD.

---

#### Sequence reset and ULD locking

After redistribution (both 'Failed' and 'Found'):

```
1. SP_VI_TBL_ULDLine_ResetULDLineSequence(@ULDID = @NewULDID)       -- if Found
2. SP_VI_TBL_ULDLine_ResetULDLineSequence(@ULDID = @CurrentULDID)   -- always
3. SP_VI_TBL_ULD_UpdateLockedStatusByULD(@ULDID = @CurrentULDID, @Locked = 1)
   LockReason = 'Real quantity of this ULD is not correct. Found when picking for wave number WAVENUM'
```

The current ULD is **always locked** after a short pick because its physical inventory count does not match the system records.

---

## Part 2 — SP_VI_TBL_Wave_CompleteWaveRequest (@Operation = 'Picking')

### Signature

```sql
SP_VI_TBL_Wave_CompleteWaveRequest
    @Operation         VARCHAR(20),   -- 'Picking'
    @WaveNumber        VARCHAR(11),
    @OperationDateTime DATETIME,
    @OperationBy       VARCHAR(100),
    @Message           VARCHAR(4000) OUTPUT
-- Returns result set: SELECT OrderNumber, Status ('Completed'|'Failed')
```

### Pre-checks

- No `PickingSchedule.Status = 'Taken'` (all tasks must be finished)
- `Wave.WaveStatus ≠ 'Pending'` and `≠ 'Completed'`
- `Wave.CurrentStep = 'Picking'`
- `Wave.StepStatus ≠ 'Completed'` and `≠ 'Pending'`

### Bulk failure analysis algorithm

The algorithm runs entirely inside a single transaction after all picking tasks are complete. It uses five temporary tables and two nested cursors to determine which orders can be fulfilled with the stock that was actually picked.

---

#### Step 1 — Collect shortfalls per item

```sql
INSERT INTO @FailedPicking (ItemNumber, TenantCode, Qty)
SELECT  ps.ItemNumber,
        u.TenantCode,
        SUM(ps.Qty - ps.PickedQty) AS Qty          -- total units short
FROM dbo.PickingSchedule ps
LEFT JOIN dbo.ULD u ON u.ULDID = ps.ULDID AND u.Deleted = 0
WHERE ps.Deleted = 0
  AND ps.FulfilmentType = 'Orders'
  AND ps.Qty <> ps.PickedQty                       -- only schedules where worker picked less
  AND ps.WaveID = @WaveID
GROUP BY ps.ItemNumber, u.TenantCode;
```

**What this produces:** one row per (ItemNumber, TenantCode) pair that has a shortfall, holding the total number of units that could NOT be picked across all PickingSchedules for this wave.

> Example: If two ULDs were supposed to provide 5 units each of ItemX but one only yielded 3, `@FailedPicking` contains `ItemX → Qty = 2`.

---

#### Step 2 — Build order requirement table

```sql
INSERT INTO @Results (OrderNumber, ItemNumber, TenantCode, Qty)
SELECT f.OrderNumber,
       fl.line_items_sku      AS ItemNumber,
       fl.TenantCode,
       SUM(fl.line_items_current_quantity) AS Qty
FROM dbo.WaveLine wl
LEFT JOIN dbo.Fulfilment f       ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
INNER JOIN dbo.FulfilmentLine fl ON fl.FulfilmentID = f.FulfilmentID AND fl.Deleted = 0
WHERE wl.WaveID = @WaveID AND wl.Deleted = 0
GROUP BY f.OrderNumber, fl.line_items_sku, fl.TenantCode
ORDER BY f.OrderNumber, fl.line_items_sku, fl.TenantCode;
```

**What this produces:** one row per (Order, Item, Tenant) combination — how many units of each item each order needs.

```sql
INSERT INTO @RequiredPicking (ItemNumber, TenantCode, Qty)
SELECT ItemNumber, TenantCode, SUM(Qty)
FROM @Results
GROUP BY ItemNumber, TenantCode;
```

**What this produces:** total units required per item across all orders in the wave.

---

#### Step 3 — Determine which orders fail (outer cursor + inner cursor)

For each item that has a shortfall, the algorithm simulates filling orders one by one, smallest first:

```
OUTER CURSOR — iterates @FailedPicking (one item at a time):

  CurQty = @RequiredPicking.Qty - @FailedPicking.Qty
         = (total needed) - (total short)
         = units that were actually picked

  INNER CURSOR — iterates @Results for this item, ORDER BY Qty ASC:

    Each iteration:

      ┌───────────────────────────────────────────┐
      │  order.Qty ≤ CurQty ?                     │
      └───────────────────────────────────────────┘
           YES                       NO
            │                         │
            ▼                         ▼
      CurQty -= order.Qty     INSERT INTO @FailedResults(OrderNumber)
      (order is satisfied)    CurQty = 0
                              (all remaining orders also fail,
                               since CurQty is now 0)
```

**Key design decision — smallest orders first (ORDER BY Qty ASC):**  
This maximises the number of orders that can be completed. A shortfall of 2 units can still satisfy two orders of 1 unit each, but would fail a single order of 3 units. By processing small orders first, the algorithm keeps as many orders alive as possible.

**CurQty reaches 0:** Once an order's `Qty > CurQty`, `CurQty` is set to 0. Every subsequent order in the inner cursor will also have `Qty > 0 = CurQty`, so they all go into `@FailedResults`. No further subtraction happens.

**Multiple items with shortfalls:** The outer cursor loops once per short item. An order can be added to `@FailedResults` multiple times (once per item it requires that is short), but because `@FailedResults` only holds `OrderNumber`, duplicates are harmless — the final `UPDATE` just marks the order `'Failed'` again.

---

#### Step 4 — Rebuild result statuses

```sql
-- Reset: assume all orders completed
DELETE FROM @Results;

INSERT INTO @Results (OrderNumber, Status)
SELECT wl.OrderNumber, 'Completed'
FROM dbo.WaveLine wl
WHERE wl.WaveID = @WaveID AND wl.Deleted = 0;

-- Override: stamp failed orders
UPDATE r
SET r.Status = 'Failed'
FROM @Results AS r
WHERE r.OrderNumber IN (SELECT OrderNumber FROM @FailedResults);
```

The table is rebuilt cleanly rather than patching in-place. This avoids residual item/qty columns from Step 2 leaking into the final result set.

---

#### Step 5 — Return result set to caller

```sql
SELECT OrderNumber, Status FROM @Results;
```

This is the **only** data returned by the SP. The caller (client application) receives a row per wave order with status `'Completed'` or `'Failed'`, and must pass this to `SP_VI_TBL_WaveLine_UpdateOrdersStatus` to persist the error state.

---

#### Summary of temporary tables used

| Table | Populated by | Contains |
|---|---|---|
| `@FailedPicking` | Step 1 | Items with shortfall + total units short |
| `@RequiredPicking` | Step 2 | Total units required per item across all orders |
| `@Results` | Step 2 → rebuilt in Step 4 | Per-order final status |
| `@FailedResults` | Step 3 inner cursor | Orders that cannot be fulfilled |

---

> **Key behaviour:** Orders with **smaller quantities are fulfilled first**. When stock is insufficient, the orders with the largest unfilled requirements are the ones marked `'Failed'`.

### Wave & WaveLine updates (Bulk — same as all PickingTypes)

```
Determine next step:
  SortRequired = 1  → NextOperation = 'Sorting',  WaveLine.SortStatus = 'Pending'
  PackRequired = 1  → NextOperation = 'Packing',  WaveLine.PackStatus = 'Pending'
  MailingRequired=1 → NextOperation = 'Mailing',  WaveLine.MailStatus = 'Pending'
  None required     → NextOperation = 'Done'

Wave table:
  CurrentStep         = NextOperation
  StepStatus          = 'Pending'   (or 'Completed' if Done)
  PickCompletedDateTime = @OperationDateTime

WaveLine table (ALL rows for this WaveID):
  PickStatus          = 'Completed'     ← set for EVERY order including future-failed ones
  SortStatus          = 'Pending' | NULL
  PackStatus          = 'Pending' | NULL
  MailStatus          = 'Pending' | NULL
```

> ⚠️ **Important:** At this point `WaveLine.PickStatus = 'Completed'` for all orders, including those the algorithm marked 'Failed'. The Error status is applied in the next step.

---

## Part 3 — SP_VI_TBL_WaveLine_UpdateOrdersStatus (@Operation = 'Picking')

### Signature

```sql
SP_VI_TBL_WaveLine_UpdateOrdersStatus
    @Operation         VARCHAR(20),    -- 'Picking'
    @Orders            dbo.ParameterArray READONLY,  -- Name=FOrderNumber, Value='Completed'|'Failed'
    @OperationDateTime DATETIME,
    @OperationBy       VARCHAR(100),
    @Message           VARCHAR(4000) OUTPUT
```

### Logic

Only **Failed** orders receive explicit updates. Completed orders retain the status set by CompleteWaveRequest.

```
For each order in @Orders:
  IF Value = 'Failed':
    Fulfilment.FulfilmentStatus = 'Error'

    IF @Operation = 'Picking':
      WaveLine.PickStatus  = 'Error'
      WaveLine.SortStatus  = NULL    ← clears pending sort
      WaveLine.PackStatus  = NULL    ← clears pending pack

    IF @Operation = 'Sorting':
      WaveLine.SortStatus  = 'Error'
      WaveLine.PackStatus  = NULL

    IF @Operation = 'Packing':
      WaveLine.PackStatus  = 'Error'
```

> ⚠️ **Known bug:** In the Sorting block there is a missing `ELSE` before `IF @Operation = 'Packing'`, meaning the Packing block always executes after the Sorting block when Operation='Sorting'.

---

## Full Bulk Wave Workflow (Picking Phase)

```
┌──────────────────────────────────────────────────────────────────────┐
│  WAVE CREATED (PickingType = 'Bulk')                                 │
│  Wave.CurrentStep = 'Picking'                                        │
│  Wave.StepStatus  = 'InProgress'                                     │
│  WaveLine rows created (one per order in wave)                       │
│  PickingSchedule rows created (one per ULD, Status='Taken')          │
└──────────────────────┬───────────────────────────────────────────────┘
                       │  [Workers pick from ULDs]
                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  SP_VI_TBL_Wave_CompletePickingTask  (called per ULD/worker)         │
│                                                                      │
│  ┌─ Task A: PickedQty = PickingQty ──────────────────────────────┐   │
│  │  TaskStatus = 'End'                                           │   │
│  │  PickingSchedule → Status='End', PickedQty=full              │   │
│  │  ULDLine: Allocated → Picked, invoices created               │   │
│  └───────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─ Task B: PickedQty < PickingQty ──────────────────────────────┐   │
│  │  Try find replacement ULD                                     │   │
│  │                                                               │   │
│  │  ┌─ No replacement ────────────────────────────────────────┐  │   │
│  │  │  TaskStatus = 'Failed'                                  │  │   │
│  │  │  PickingSchedule → Status='End', PickedQty=partial      │  │   │
│  │  │  ULDLine: redistribute picked qty to orders (ASC Qty)   │  │   │
│  │  │  ULDLine: insert 'Missing' entries for shortfall        │  │   │
│  │  │  ULD locked                                             │  │   │
│  │  └─────────────────────────────────────────────────────────┘  │   │
│  │                                                               │   │
│  │  ┌─ Replacement found ─────────────────────────────────────┐  │   │
│  │  │  TaskStatus = 'Found'                                   │  │   │
│  │  │  Current PickingSchedule → Status='End', Qty=partial    │  │   │
│  │  │  New PickingSchedule → Status='Taken' (new ULD)         │  │   │
│  │  │  ULDLine: redistribute, ULD locked                      │  │   │
│  │  └─────────────────────────────────────────────────────────┘  │   │
│  └───────────────────────────────────────────────────────────────┘   │
└──────────────────────┬───────────────────────────────────────────────┘
                       │
                       │  [All PickingSchedules.Status ≠ 'Taken']
                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  SP_VI_TBL_Wave_CompleteWaveRequest (@Operation='Picking')           │
│                                                                      │
│  1. Compute shortfall per item (Qty - PickedQty where Qty≠PickedQty) │
│  2. For each short item, iterate orders ASC by Qty:                  │
│     · CurQty sufficient → order = 'Completed',  CurQty -= order.Qty │
│     · CurQty insufficient → order = 'Failed',   CurQty = 0          │
│                                                                      │
│  3. Wave:    CurrentStep='Sorting'/'Packing'/'Mailing'/'Done'        │
│              StepStatus='Pending'                                    │
│              PickCompletedDateTime = now                             │
│                                                                      │
│  4. WaveLine (ALL orders):                                           │
│              PickStatus  = 'Completed'   ← even future-failed ones   │
│              SortStatus  = 'Pending'  (if SortRequired)              │
│              PackStatus  = 'Pending'  (if PackRequired, no sort)     │
│                                                                      │
│  5. RETURNS result set:  OrderNumber | Status                        │
│       ─────────────────────────────────                              │
│       ORDER-001          Completed                                   │
│       ORDER-002          Failed       ← not enough stock             │
│       ORDER-003          Completed                                   │
└──────────────────────┬───────────────────────────────────────────────┘
                       │  [Client passes result set to next SP]
                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  SP_VI_TBL_WaveLine_UpdateOrdersStatus (@Operation='Picking')        │
│                                                                      │
│  For each Failed order:                                              │
│    Fulfilment.FulfilmentStatus = 'Error'                             │
│    WaveLine.PickStatus         = 'Error'                             │
│    WaveLine.SortStatus         = NULL   (overrides 'Pending')        │
│    WaveLine.PackStatus         = NULL   (overrides 'Pending')        │
│                                                                      │
│  Completed orders: unchanged (PickStatus='Completed', next='Pending')│
└──────────────────────┬───────────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  FINAL STATE after Picking phase                                     │
│                                                                      │
│  ┌─ Order = ERROR ──────────────────────────────────────────────┐    │
│  │  Fulfilment.FulfilmentStatus = 'Error'                       │    │
│  │  WaveLine.PickStatus  = 'Error'                              │    │
│  │  WaveLine.SortStatus  = NULL                                 │    │
│  │  WaveLine.PackStatus  = NULL                                 │    │
│  │  → EXCLUDED from all subsequent wave operations              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ Order = OK ─────────────────────────────────────────────────┐    │
│  │  Fulfilment.FulfilmentStatus = unchanged (e.g. 'Picking')    │    │
│  │  WaveLine.PickStatus  = 'Completed'                          │    │
│  │  WaveLine.SortStatus  = 'Pending'  (if SortRequired)         │    │
│  │  WaveLine.PackStatus  = 'Pending'  (if PackRequired, no sort)│    │
│  │  → CONTINUES to Sorting / Packing / Mailing                  │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Error Scenario Deep-Dive: One Order Fails

### Example

Wave has 3 orders for the same item. ULD has 10 units. Required: 4+4+4=12.

```
PickingSchedule.Qty      = 12
PickingSchedule.PickedQty= 10  (worker only found 10)
```

**Inside CompletePickingTask (Bulk, short pick):**

- Calls `SP_VI_TBL_ULD_GetNextLocationForPicking` — no other ULD found → `TaskStatus='Failed'`
- Redistributes 10 units across the 3 orders (sorted ASC by Qty = 4,4,4):
  - ORDER-001 (4): TmpQty=10 ≥ 4 → Picked 4, TmpQty=6, invoice for 4
  - ORDER-002 (4): TmpQty=6 ≥ 4  → Picked 4, TmpQty=2, invoice for 4
  - ORDER-003 (4): TmpQty=2 < 4  → Picked 2 (partial), TmpQty=0, invoice for 2
- ULDLine `'Missing' -2` inserted for ORDER-003 shortfall
- ULD locked

**Inside CompleteWaveRequest (Bulk algorithm):**

```
FailedPicking: ItemX, TenantA, Qty=2   (12 required, 10 picked)
RequiredPicking: ItemX, TenantA, Qty=12
CurQty = 12 - 2 = 10   (what was actually picked)

Iterate orders ASC by Qty (4, 4, 4):
  ORDER-001 Qty=4 ≤ 10 → Completed, CurQty=6
  ORDER-002 Qty=4 ≤ 6  → Completed, CurQty=2
  ORDER-003 Qty=4 > 2  → Failed, CurQty=0

Result set returned:
  ORDER-001 → Completed
  ORDER-002 → Completed
  ORDER-003 → Failed
```

**Inside WaveLine_UpdateOrdersStatus:**

```
ORDER-003 (Failed):
  Fulfilment.FulfilmentStatus = 'Error'
  WaveLine.PickStatus  = 'Error'
  WaveLine.SortStatus  = NULL
  WaveLine.PackStatus  = NULL

ORDER-001, ORDER-002 (Completed):
  No changes → keep PickStatus='Completed', SortStatus='Pending'
```

---

## Error Scenario: All Orders Fail (Total Pick = 0)

If `PickedQty = 0` and no replacement ULD:

- `FailedPicking.Qty = PickingQty` (full shortfall)
- `CurQty = RequiredPicking.Qty - PickingQty = 0`
- First order in loop: `Qty > 0 = CurQty` → **Failed immediately**
- All subsequent orders also **Failed**

All orders end up:

```
FulfilmentStatus = 'Error'
WaveLine.PickStatus = 'Error'
WaveLine.SortStatus = NULL
WaveLine.PackStatus = NULL
Wave continues to next phase but with zero eligible orders
```

---

## Notes & Observations

1. **Bulk vs Single failure logic in CompleteWaveRequest** — Single uses per-schedule `ps.Status = 'Failed'` to flag orders 1:1. Bulk uses aggregate shortfall and distributes failure to the largest unfilled orders.

2. **Caller responsibility** — The client application must read the result set from `CompleteWaveRequest` and pass it to `WaveLine_UpdateOrdersStatus`. These two SPs are not automatically chained.

3. **Wave-level vs order-level** — `CompleteWaveRequest` updates Wave and WaveLine for all orders at once. `WaveLine_UpdateOrdersStatus` then corrects only the failed ones.

4. **SortStatus/PackStatus preservation** — When an Error order's `SortStatus = NULL` is set, it is excluded from Sorting via the `WHERE PickStatus = 'Completed'` filter in CompleteWaveRequest's Sorting block.

5. **NumberOfOrders** — The commented-out block in `WaveLine_UpdateOrdersStatus` that would update `Wave.NumberOfOrders` is currently inactive.

6. **Missing ELSE bug** — In `WaveLine_UpdateOrdersStatus`, the `IF @Operation = 'Packing'` block inside the Sorting case lacks an `ELSE` prefix, so packing updates also fire when Operation='Sorting'.
