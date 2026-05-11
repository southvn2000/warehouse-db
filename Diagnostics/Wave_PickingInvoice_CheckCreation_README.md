# Picking Invoice Creation Diagnostic Script

## Overview

This SQL diagnostic script systematically checks whether picking invoices were created for a given WaveID. It validates prerequisites, identifies bottlenecks, and provides actionable diagnostics.

**Script Location:** [Diagnostics/Wave_PickingInvoice_CheckCreation.sql](Wave_PickingInvoice_CheckCreation.sql)

**Usage:**
```sql
DECLARE @WaveID INT = 123;  -- Replace 123 with your WaveID
-- Then run the script
```

---

## What the Script Does: Step-by-Step

### STEP 1: Verify Wave Exists
**Purpose:** Ensure the WaveID is valid and retrieve wave metadata.

**Checks:**
- Wave exists in `dbo.Wave` for the given `@WaveID`
- Wave is not soft-deleted (`Deleted = 0`)

**Output:**
- Wave number (e.g., `WAVE-001`)
- Wave status (e.g., `Completed`, `In Progress`)
- Tenant code and warehouse code (needed for invoice validation)

**Failure scenario:**
- If wave is not found, script terminates early. This prevents downstream checks on non-existent data.

---

### STEP 2: Check Orders/Fulfilments Picked in Wave
**Purpose:** Identify all orders that had items picked in this wave.

**Checks:**
- Count distinct `OrderNumber` in `dbo.PickingSchedule` for this wave
- Count total `ItemLineCount` (how many item lines were picked)

**Output:**
- Total number of orders picked
- Total number of item lines picked
- Breakdown by order: `OrderNumber`, `ItemLineCount`, `TotalQtyPicked`

**Interpretation:**
- If 0 orders: Wave may be empty or picking not completed. Invoices should not be expected.
- If 10 orders: Expect invoices for 10 different orders (or more, if multiple charge items per order).

---

### STEP 3: Check Picking Invoice Prerequisites (Per Item)
**Purpose:** Validate that each picked item has the necessary master data configuration to generate invoices.

**For each unique item picked, validates:**

#### 3a. Item Exists
- Row exists in `dbo.Items` with `ItemNumber + TenantCode + Deleted = 0`
- Retrieve: `ItemName`, `UnitOfMeasure` (ItemUnit)

**Failure impact:** If item not found, `SP_VI_TBL_Invoice_InsertChargeGroupInvoice` returns without inserting.

#### 3b. Charge Group for Picking
- Row exists in `dbo.ItemChargeGroup` for this item with `Category = 'Picking'`
- Links item to a charge group

**Failure impact:** If no charge group, item-level group invoice not created.

#### 3c. Matching Charge Items
- Count of `dbo.ChargeItem` rows where:
  - `ChargeItemGroup = 'Picking'`
  - `ChargeItemUnit = [item's unit]` (exact string match)
  - `Deleted = 0`

**Failure impact:** If 0 matching charge items, no charge-item-level invoices created.

**Output Summary Table:**
| Item | Unit | Item Found | Charge Group OK | Charge Items | Status |
|------|------|-----------|-----------------|--------------|--------|
| SKU-001 | Unit | ✓ | ✓ | 2 | ✓ OK |
| SKU-002 | Carton | ✓ | ❌ | 0 | ⚠ No group |
| SKU-003 | Unit | ❌ | ❌ | 0 | ❌ Not found |

---

### STEP 4: Check Actual Picking Invoices Created
**Purpose:** Query the `dbo.Invoice` table to see if invoices were actually inserted.

**Lookup method:**
- Search by `WaveReferences = @WaveNumber`
- Filter: `ChargeCategory = 'Picking'` AND `Deleted = 0`

**Output:**
- Count of invoices found
- Full invoice details: `InvoiceID`, `ChargeName`, `Qty`, `Charge`, `Status`, `CreatedDateTime`, `CreatedBy`

**⚠ Important note:**
The main invoice lookup uses `WaveReferences` (which should match the wave number). However, `SP_VI_TBL_Invoice_InsertPickingInvoice` also creates invoices with `InvoiceReferences` set to `@TransactionReference` (e.g., order number). Step 5 checks the secondary lookup.

**Failure scenario:**
- If 0 invoices: Script provides a list of possible reasons.

---

### STEP 5: Check Picking Invoices by Order Number (Alternative Lookup)
**Purpose:** Cross-check by looking up invoices using order numbers instead of wave number.

**Lookup method:**
- For each distinct `OrderNumber` in the picked items
- Search `dbo.Invoice` by `InvoiceReferences = @OrderNumber`
- Filter: `ChargeCategory = 'Picking'` AND `Deleted = 0`

**Output:**
- Per-order invoice count
- Total charge per order
- YES/NO indicator for each order

**Why this step?**
- `SP_VI_TBL_Invoice_InsertChargeGroupInvoice` inserts with `InvoiceReferences = @TransactionReference` (order number)
- Some invoices may only be discoverable via order number, not wave number
- If STEP 4 found 0 invoices but STEP 5 finds invoices, it indicates invoices exist but with different reference pattern

---

### STEP 6: Check Tenant Subscription to Picking Charges
**Purpose:** Verify that the wave's tenant is subscribed to all available `Picking` charge items.

**Checks:**
- For each `ChargeItem` with `ChargeItemGroup = 'Picking'`:
  - Look for matching `TenantChargeItem` row for this wave's `TenantCode`
  - If found: `ChargeType = 'Standard'` or `'Custom'`
  - If not found: ❌ Not Subscribed

**Output:**
| Charge Item | Unit | Subscription | Type | Effective Date | End Date |
|-------------|------|--------------|------|----------------|----------|
| Picking - Unit | Unit | ✓ Subscribed | Standard | 2025-01-01 | NULL |
| Picking - Carton | Carton | ❌ Not Subscribed | - | - | - |

**Failure impact:**
- If tenant is not subscribed to a charge item, `SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode` returns `@ChargeType = NULL`
- Parent procedure skips invoice insert (`IF @ChargeType IS NOT NULL`)
- Result: No invoice created for that charge item

---

### STEP 7: Check Charge Item Cost Configuration
**Purpose:** Verify that pricing is configured for picking charge items at the warehouse level.

**Checks:**
- For each `ChargeItem` with `ChargeItemGroup = 'Picking'`:
  - Look for `ChargeItemCost` row matching `WarehouseCode` and `Deleted = 0`
  - Retrieve: `ChargeItemPrice`, `Currency`

**Output:**
| Charge Item | Unit | Warehouse | Price | Currency | Cost Status |
|-------------|------|-----------|-------|----------|-------------|
| Picking - Unit | Unit | SYD-01 | 0.50 | AUD (A$) | ✓ Has cost |
| Picking - Carton | Carton | SYD-01 | NULL | NULL | ❌ NO COST |

**Failure impact:**
- If no cost row found, `GetCostInfoOfTenantByWarehouseCode` defaults `@Charge = 0` and `@Currency = 'AUD (A$)'`
- Invoice is still created with `Cost = 0` and `Charge = 0`
- **This is a logic gap:** 0-charge invoices should probably be blocked

---

### STEP 8: Summary and Recommendations
**Purpose:** Synthesize findings and provide next steps.

**Output scenarios:**

#### ✓ Invoices Found
- Prints wave metadata, item count, order count, invoice count
- Script completes successfully

#### ❌ No Invoices Found
- Prints **"NO PICKING INVOICES FOUND FOR THIS WAVE"**
- Lists possible reasons:
  1. `SP_VI_TBL_Invoice_InsertPickingInvoice` was not called
  2. All items failed prerequisites (item not found, charge group not configured, etc.)
  3. Tenant not subscribed to charge items
  4. Invoices were created but rolled back due to error
  5. Warehouse/pricing misconfiguration
- Shows recent Picking invoices in system for comparison (to see if picking invoices are created at all)

---

## How to Interpret Results

### Scenario 1: All Green (✓)
```
✓ Wave found
✓ Orders picked: 5
✓ All items configured (item exists, charge group, charge items)
✓ Invoices found: 8
✓ Tenant subscribed to all charge items
✓ All charge items have pricing
```
**Interpretation:** Everything is working. Picking invoices were created successfully.

---

### Scenario 2: Missing Item
```
ItemNumber: SKU-999
ItemExists: ❌ Item not found
```
**Interpretation:** 
- Item was picked but doesn't exist in `dbo.Items` table
- `SP_VI_TBL_Invoice_InsertChargeGroupInvoice` returns without inserting
- **Action:** Insert missing item into `dbo.Items` table, then re-run invoice creation

---

### Scenario 3: No Charge Group
```
ItemNumber: SKU-001
ItemExists: ✓
ChargeGroupExists: ❌ No charge group for Picking
```
**Interpretation:**
- Item exists but has no `ItemChargeGroup` mapping for `Picking` category
- No group-level invoice created
- Charge-item invoices may still be created (if units match)
- **Action:** Create `ItemChargeGroup` row linking this item to a `ChargeGroup` with category `Picking`

---

### Scenario 4: Unit Mismatch
```
ItemNumber: SKU-001
ItemUnit: Carton
ChargeItemsCount: 0
```
**Interpretation:**
- Item is configured to use unit `Carton`
- But there are no `ChargeItem` rows with `ChargeItemGroup = 'Picking'` AND `ChargeItemUnit = 'Carton'`
- **Possible unit names in system:** `Unit`, `Carton`, `Box`, `Pallet`, `Week`, `Receipt`, `Person per Hour`
- **Action:** Either create a `Carton` charge item, or change the item's unit to a configured unit (e.g., `Unit`)

---

### Scenario 5: Tenant Not Subscribed
```
Charge Item: Picking - Unit
Subscription: ❌ Not Subscribed
```
**Interpretation:**
- Charge item exists and is properly configured with pricing
- But the tenant does NOT have a `TenantChargeItem` subscription for this item
- `SP_VI_TBL_ChargeItem_GetCostInfoOfTenantByWarehouseCode` returns `@ChargeType = NULL`
- Invoice not created
- **Action:** Add a `TenantChargeItem` row subscribing this tenant to this charge item

---

### Scenario 6: No Pricing
```
Charge Item: Picking - Unit
Warehouse: SYD-01
Price: NULL
Cost Status: ❌ NO COST
```
**Interpretation:**
- Charge item exists and tenant is subscribed
- But there's no `ChargeItemCost` row for this warehouse
- Invoice created with `Cost = 0` (system default)
- **Action:** Add `ChargeItemCost` row with actual price, or create generic warehouse-level pricing

---

### Scenario 7: No Invoices Found at All
```
❌ NO PICKING INVOICES FOUND FOR THIS WAVE

Recent invoice activity (last 10 Picking invoices in system):
[Empty result set]
```
**Interpretation:**
- Not a single picking invoice exists for this wave
- AND no picking invoices exist in the system at all
- **Possible causes:**
  1. `SP_VI_TBL_Invoice_InsertPickingInvoice` is never called by the application
  2. Entire picking charging feature is disabled
  3. All items/tenants fail the prerequisites consistently
- **Action:** Trace the application code to see if/when invoice procedures are called

---

## Quick Reference: Data Model

### Key Tables

| Table | Purpose |
|-------|---------|
| `dbo.Wave` | Wave records |
| `dbo.PickingSchedule` | Item picking lines assigned to wave |
| `dbo.Items` | Master item catalog |
| `dbo.ItemChargeGroup` | Maps item to charge group (per category) |
| `dbo.ChargeGroup` | Group of related charges |
| `dbo.ChargeGroupCost` | Pricing for charge group by warehouse/unit |
| `dbo.ChargeItem` | Individual charge line items (e.g., "Picking per Unit") |
| `dbo.ChargeItemCost` | Pricing for charge item by warehouse |
| `dbo.TenantChargeItem` | Tenant subscription to charge item (Standard/Custom) |
| `dbo.TenantCustomCost` | Custom pricing override for subscribed tenant |
| `dbo.Invoice` | Billing records (Pending status at creation) |

---

## Common Fixes

| Problem | Solution |
|---------|----------|
| Item not found | Insert missing item in `dbo.Items` |
| No charge group | Create `ItemChargeGroup` row for Picking category |
| No charge items for unit | Create `ChargeItem` with matching `ChargeItemUnit` |
| Tenant not subscribed | Insert `TenantChargeItem` row |
| No pricing | Insert `ChargeItemCost` row |
| Invoices rolled back | Check application error logs; re-trigger invoice creation |
| SP never called | Verify application integration layer calls the SP |

---

## Next Steps After Running Script

1. **If invoices found:** Script completes successfully. Invoices are in `dbo.Invoice` table with `Status = 'Pending'`.

2. **If invoices not found:**
   - Review the per-item prerequisite check (STEP 3) and note all items marked ❌
   - Check tenant subscription (STEP 6) and note missing subscriptions
   - Check pricing (STEP 7) and note missing costs
   - Fix any configuration issues (see Common Fixes table above)
   - Manually call `SP_VI_TBL_Invoice_InsertPickingInvoice` for affected orders:
     ```sql
     EXEC dbo.SP_VI_TBL_Invoice_InsertPickingInvoice
         @TenantCode = 'TENANT1',
         @WarehouseCode = 'SYD-01',
         @ItemCode = 'SKU-001',
         @TransactionReference = 'ORD-12345',
         @WaveReferences = 'WAVE-001',
         @ItemUnit = 'Unit',
         @ItemQty = 10,
         @Message = @Msg OUTPUT;
     PRINT @Msg;
     ```

