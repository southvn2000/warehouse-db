# ULD Line Allocation Not Created - Quick Reference

## Summary: 10 Cases Where ULD Lines Are NOT Allocated

| Case | Condition | Root Cause | SQL Check |
|------|-----------|-----------|-----------|
| **1** | OrderNumber IS NULL | Missing parameter | `@OrderNumber IS NULL` |
| **2** | Order On Hold | `Orders.OnHold = 1` | `SELECT OnHold FROM dbo.Orders WHERE order_number = @OrderNumber` |
| **3** | Item Not Exist | ItemId is NULL | `WHERE NOT EXISTS (SELECT 1 FROM dbo.Items WHERE ItemNumber = @OrderItemNumber AND TenantCode = @TenantCode)` |
| **4** | DHL No HsTariffCode | Compliance failure | `WHERE CarrierID = 3 AND (HsTariffCode IS NULL OR HsTariffCode = '')` |
| **5** | Composite + Single Pick | Incompatible configuration | `WHERE ItemIsComposite = 1 AND CompositeType = 'Order' AND PickingCondition = 'Single'` |
| **6** | No Items in Order | Empty order lines | `SELECT COUNT(*) FROM #TempChildItemsTable = 0` |
| **7** | No Available ULDs | Physical stock doesn't exist | `WHERE NOT EXISTS (SELECT 1 FROM fn_GetULDsHavingStockOfTenantAtWarehouse(...))` |
| **8** | Insufficient Quantity | Stock less than required | `SUM(ULD.Qty) < OrdersLine.Quantity` |
| **9** | Transaction Error | INSERT into ULDLine fails | TRY-CATCH block rollback |
| **10** | @IsEnough = 0 | Any of cases 2-9 occurred | `IF @IsEnough = 1 -- create allocated ULD line` |

---

## Files Created

### 1. **Analysis Document**

- **File**: `Analysis/ULDLineAllocation_Cases_Not_Created.md`
- **Content**: Detailed explanation of each case with code references
- **Use Case**: Understanding the problem space

### 2. **Stored Procedure for Diagnosis**

- **File**: `Diagnostics/sp_CheckULDAllocationFailures.sql`
- **Type**: T-SQL Stored Procedure
- **Input**: `@OrderNumber VARCHAR(50)`
- **Output**: Step-by-step diagnosis with specific failures
- **Usage**:

  ```sql
  EXEC sp_CheckULDAllocationFailures @OrderNumber = 'ORD-20260519-001';
  ```

### 3. **Quick Lookup Query**

- **File**: `Diagnostics/ULDAllocation_DiagnosticCheck.sql`
- **Type**: Ad-hoc diagnostic script (simpler version)
- **Use Case**: Quick checks without stored procedure

---

## How to Use the Diagnostic Tools

### **Step 1: Create the Stored Procedure**

```sql
-- Run this once to create the procedure:
-- Execute the contents of: Diagnostics/sp_CheckULDAllocationFailures.sql
```

### **Step 2: Run Diagnosis for an Order**

```sql
DECLARE @OrderNumber VARCHAR(50) = 'YOUR-ORDER-NUMBER';
EXEC sp_CheckULDAllocationFailures @OrderNumber;
```

### **Step 3: Interpret Results**

The procedure will stop at the FIRST failure point and show:

- Which case failed
- Detailed data about the failure
- Recommended action

---

## Example Scenarios

### Scenario A: Order doesn't exist

```
>>> CASE 1: Order Exists Check
FAILED: Order does not exist
[Procedure exits]
```

**Action**: Verify order number is correct

### Scenario B: Insufficient stock

```
>>> CASE 6: Stock Availability Check
FAILED: Insufficient stock for some items
ItemNumber | RequiredQty | AvailableQty | ShortfallQty
ITEM-001   | 100         | 60           | 40
[Procedure exits]
```

**Action**: Receive 40 more units of ITEM-001

### Scenario C: Item doesn't exist

```
>>> CASE 4: Non-Existent Items Check
FAILED: Found items that do not exist in master data
ItemNumber | Quantity | Reason
UNKNOWN-01 | 50       | NotExist
[Procedure exits]
```

**Action**: Add UNKNOWN-01 to Items master

### Scenario D: All checks pass but no allocation

```
>>> CASE 7: ULD Line Allocation Status
NO ALLOCATION FOUND: Check for deleted allocations
Found DELETED allocations - may indicate rollback
ULDID | ItemNumber | Qty | DeletedTime | DeletedBy
[Procedure shows deleted records]
```

**Action**: Investigate transaction failure

---

## Key Stored Procedure References

| Procedure | Purpose |
|-----------|---------|
| `SP_VI_TBL_Items_CheckAvailableStockForOrder` | Main stock check + allocation (source procedure) |
| `sp_CheckULDAllocationFailures` | Diagnostic tool (created in this analysis) |

## Key Function References

| Function | Purpose |
|----------|---------|
| `fn_GetULDsHavingStockOfTenantAtWarehouse()` | Returns available ULDs for an item at warehouse |
| `fn_GetAllChildrenItemsOfCompositeItem()` | Expands composite items to children |

---

## Key Tables Involved

| Table | Role |
|-------|------|
| `dbo.Orders` | Order header (OnHold status, CarrierID, WarehouseCode) |
| `dbo.OrdersLine` | Order details (ItemNumber, Quantity) |
| `dbo.Items` | Item master (HsTariffCode, ItemIsComposite, PickingCondition) |
| `dbo.ULD` | Stock containers (Qty, Location) |
| `dbo.ULDLine` | Transaction log (Allocated entries with TransactionReference) |

---

## Performance Notes

- Diagnosis includes sequential checks (stops on first failure)
- For bulk order analysis, consider creating indexed views
- Stock check (Case 6-8) uses function calls - may be slow with large datasets

---

## Maintenance

| Task | Frequency |
|------|-----------|
| Verify procedure syntax | Before each release |
| Update item master | As needed (Case 3) |
| Audit stock levels | Daily/Weekly |
| Check On Hold orders | Real-time |
| Monitor transaction errors | Real-time |
