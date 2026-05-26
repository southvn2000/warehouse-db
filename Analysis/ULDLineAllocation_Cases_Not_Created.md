# ULD Line Allocation Not Created - Analysis

## Overview
The stored procedure `SP_VI_TBL_Items_CheckAvailableStockForOrder` performs stock availability checks and allocates ULD lines. This document lists all cases where ULD line allocation is **NOT** created.

---

## Cases Where ULD Line Allocation is NOT Created

### **Case 1: OrderNumber is NULL**
- **Condition**: `@OrderNumber IS NULL`
- **Impact**: No order context, no allocation happens
- **Code Section**: Lines 39-60
- **Check**: If order number is not provided, procedure skips order validation and proceeds, but allocation requires an order number

---

### **Case 2: Order is On Hold**
- **Condition**: `Order.OnHold = 1`
- **Impact**: Stock check stops, `@IsEnough` is set to 0
- **Code Section**: Lines 45-60
- **SQL Check**: 
  ```sql
  SELECT OnHold FROM dbo.Orders WHERE order_number = @OrderNumber AND DELETED = 0
  ```

---

### **Case 3: Item Not Exist in System**
- **Condition**: `Items.ItemId IS NULL` for any order line item
- **Impact**: Item not found in Items table for the tenant
- **Code Section**: Lines 167-180
- **Missing Type**: `'NotExist'`
- **SQL Check**:
  ```sql
  SELECT ItemId FROM dbo.Items 
  WHERE ItemNumber = @OrderItemNumber AND DELETED = 0 AND TenantCode = @TenantCode
  ```

---

### **Case 4: Missing HsTariffCode for DHL Orders**
- **Condition**: `CarrierID = 3 (DHL) AND Items.HsTariffCode IS NULL OR EMPTY`
- **Impact**: DHL compliance requirement not met
- **Code Section**: Lines 181-199
- **Missing Type**: `'NoHsTariffCode'`
- **SQL Check**:
  ```sql
  SELECT HsTariffCode FROM dbo.Items 
  WHERE ItemId = @ItemId AND DELETED = 0
  ```

---

### **Case 5: Composite Item with Single Picking Type**
- **Condition**: `ItemIsComposite = 1 AND CompositeType = 'Order' AND @PickingType = 'Single'`
- **Impact**: Single-pick mode doesn't support composite items
- **Code Section**: Lines 217-230
- **Missing Type**: `'NotSupportSinglePickCompositeItem'`

---

### **Case 6: No Items in Order**
- **Condition**: `COUNT(#TempChildItemsTable) = 0`
- **Impact**: After processing all order lines and composite items, no actual items to allocate
- **Code Section**: Lines 429-440
- **SQL Check**:
  ```sql
  SELECT COUNT(*) FROM #TempChildItemsTable
  ```

---

### **Case 7: Insufficient Stock - No Available ULDs**
- **Condition**: `fn_GetULDsHavingStockOfTenantAtWarehouse() returns 0 rows`
- **Impact**: Physical stock doesn't exist at warehouse for the item
- **Code Section**: Lines 401-425
- **Missing Type**: `'NoStock'` (when `SUM(TotalQty) < @Quantity`)
- **SQL Check**:
  ```sql
  SELECT ULDID FROM dbo.fn_GetULDsHavingStockOfTenantAtWarehouse(
      @TenantCode, @WarehouseCode, @ItemNumber, @PickingCondition, 0)
  ```

---

### **Case 8: Required Quantity Exceeds Available Stock**
- **Condition**: `SUM(#TempItemULDTable.TotalQty) < @RequiredQuantity`
- **Impact**: Not enough stock to fulfill the order line
- **Code Section**: Lines 472-493
- **Missing Type**: `'NoStock'`
- **Sets**: `@IsEnough = 0`

---

### **Case 9: Transaction Exception/Failure**
- **Condition**: Error occurs during ULD line insert (TRY-CATCH block)
- **Impact**: INSERT statement fails, transaction rolls back
- **Code Section**: Lines 548-608
- **Impact**: No ULD lines created for any items in the order

---

### **Case 10: @IsEnough Remains 0**
- **Condition**: Any of Cases 2-9 occur
- **Impact**: Allocation section (lines 539-607) is skipped entirely
- **Code Section**: Line 538
  ```sql
  IF @IsEnough = 1 -- create allocated ULD line
  BEGIN
    -- ULD allocation code
  END
  ```

---

## Summary Table

| Case # | Condition | Missing Type | SQL Join Point | Severity |
|--------|-----------|--------------|-----------------|----------|
| 1 | OrderNumber IS NULL | N/A (no allocation) | Parameter | LOW |
| 2 | Order.OnHold = 1 | N/A | Orders.order_number | HIGH |
| 3 | Item doesn't exist | NotExist | Items.ItemNumber | HIGH |
| 4 | DHL no HsTariffCode | NoHsTariffCode | Items.ItemId | MEDIUM |
| 5 | Composite + Single Pick | NotSupportSinglePickCompositeItem | Items.ItemIsComposite | MEDIUM |
| 6 | No items in order | N/A (no allocation) | COUNT logic | LOW |
| 7 | No ULDs in warehouse | NoStock | fn_GetULDsHavingStockOfTenantAtWarehouse | HIGH |
| 8 | Insufficient stock qty | NoStock | SUM(ULD qty) | HIGH |
| 9 | Transaction error | N/A (rollback) | ULDLine INSERT | CRITICAL |
| 10 | @IsEnough = 0 | N/A (skipped) | IF statement | N/A |

---

## Key Tables Involved
- **Orders** - Order header information (OnHold status)
- **Items** - Item master data (ItemId, ItemNumber, HsTariffCode, ItemIsComposite)
- **ULD** - Unit Load Device (stock containers)
- **ULDLine** - Transaction records for ULD movements
- **fn_GetULDsHavingStockOfTenantAtWarehouse** - Function returning available stock

---

## Impact on Business Logic
When ULD lines are NOT allocated:
1. Order cannot proceed to picking/packing stages
2. Missing items are returned via `#TempMissingItemTable`
3. Fulfillment workflow is blocked
4. Stock remains unallocated and available for other orders
