# SortingSchedule Creation Logic

**Source:** `SP_VI_TBL_Wave_StartWaveRequest`

---

## Trigger Conditions

Records are inserted only when **all conditions** are met:

1. The wave has already been **started** (`StepStatus` was previously set to `'Started'`)
2. The current operation matches the requested one (`@CurrentOperation = @Operation`)
3. The operation status is `'Pending'` (transitioning from the previous phase)
4. `@Operation = 'Sorting'`

---

## Step-by-step Flow

```
Wave.StepStatus = 'Started'
  └─ @Operation = 'Sorting' AND @OperationStatus = 'Pending'
       │
       ├─ UPDATE Wave SET StepStatus = 'Started'
       │
       └─ CURSOR: cur_FulfilmentItems
            Selects FulfilmentLine rows WHERE:
              - WaveLine.WaveID = @WaveID
              - WaveLine.PickStatus = 'Completed'   ← only picked orders
              - Fulfilment.FulfilmentStatus <> 'OnHold'
              - FulfilmentLine.Deleted = 0
```

---

## Per Fulfilment Line — Two Paths

### Path A — Composite Item (`ItemIsComposite = 1` AND `CompositeType = 'Order'`)

- Calls `SP_VI_TBL_Items_GetAllChildrenItemsOfCompositeItem` to expand child items
- For **each child item**, opens `cur_ULDLine`:
  ```sql
  SELECT ULDID, ULDBarcode, TransactionQty, SerialNumber
  FROM ULDLine ul JOIN ULD u ON u.ULDID = ul.ULDID
  WHERE ul.TransactionReference = @SourceOrderNumber
    AND ul.TransactionType = 'Picked'
    AND ul.Deleted = 0
    AND ul.ItemNumber = @ChildItemName
  ```
- `@TransactionQty = -TransactionQty * @CurrentQty` (negative qty reversed, scaled by child multiplier)
- **Inserts one row per unit** (loop `1..@TransactionQty`) using **child item** details

### Path B — Simple Item (`ItemIsComposite` is NULL or `0`)

- Opens `cur_ULDLine` directly for the fulfilment line item:
  ```sql
  WHERE ul.TransactionType = 'Picked'
    AND ul.ItemNumber = @ItemNumber
  ```
- `@TransactionQty = -TransactionQty`
- **Inserts one row per unit** (loop `1..@TransactionQty`) using the item itself

---

## Columns Populated on Insert

| Column | Value |
|---|---|
| `WaveID` | `@WaveID` |
| `ULDID` / `ULDBarcode` | from `ULD` table (where item was picked into) |
| `ItemID` / `ItemNumber` / `ItemName` | child item (composite path) or the item itself (simple path) |
| `Qty` | always `1` |
| `OrderNumber` | from `Fulfilment.OrderNumber` |
| `SerialNumber` | from `ULDLine.SerialNumber` |
| `Deleted` | `0` |
| `CreatedDateTime` / `CreatedBy` | `@OperationDateTime` / `@OperationBy` |

---

## Key Rule

> One `SortingSchedule` row = **one physical unit** to be sorted.  
> `Qty` is always `1` — rows are created by iterating a `WHILE` loop up to the picked quantity from `ULDLine`.
