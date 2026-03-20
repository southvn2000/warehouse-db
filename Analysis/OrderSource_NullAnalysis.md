# OrderSource NULL Analysis - Wave CreateShipmentsForCMCPackingWave

## Problem Summary
The `@OrderSource` variable becomes NULL during execution of the `SP_VI_TBL_Wave_CreateShipmentsForCMCPackingWave` stored procedure, even though it's selected and populated. This analysis identifies the root causes.

## Root Causes Identified

### 1. **Missing Fulfilment Records (Most Likely)**
**Location:** Line 140-150 in the stored procedure
```sql
SELECT TOP 1
    @OrderSource = f.OrderSource,
    ...
FROM dbo.Waveline wl
LEFT JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
WHERE wl.Deleted = 0 AND wl.WaveID = @WaveID AND wl.OrderNumber = @OrderNumber;
```

**Problem:**
- Uses `LEFT JOIN` - if no matching Fulfilment record exists for an OrderNumber, all columns from Fulfilment (including OrderSource) will be NULL
- The procedure continues without error, storing NULL values

**Impact:** HIGH - This is likely the primary cause

---

### 2. **NULL OrderSource in Existing Fulfilment Records**
**Table Schema:** [dbo].[Fulfilment]
```sql
[OrderSource] [varchar](50) NULL  -- Can be NULL
```

**Problem:**
- Fulfilment records exist but the OrderSource column was never populated during order creation/import
- No COALESCE or ISNULL fallback to provide a default value

**Impact:** MEDIUM - Affects records created before OrderSource population was implemented

---

### 3. **Unused Variable in Final Output**
**Location:** Lines 278-365 (Final INSERT into CMCPackingWaveResult)

**Problem:**
- The `@OrderSource` variable is populated in the temp table `#PackingTaskResults`
- But the final INSERT into `dbo.CMCPackingWaveResult` **does NOT include OrderSource column**
- This suggests OrderSource may have been stored in a different column or table

---

## Data Dependencies

### Fulfilment Table Structure
| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| FulfilmentID | int | NO | Primary Key |
| OrderNumber | varchar(50) | NO | Links to Waveline |
| OrderSource | varchar(50) | **YES** | ⚠️ Can be NULL |
| order_number | varchar(50) | NO | Alternative order number |
| TenantCode | varchar(10) | NO | |

### Wave & Waveline Link
```
Wave.WaveID 
  ├─ Waveline.WaveID (one-to-many)
  │  └─ Waveline.OrderNumber ──LEFT JOIN──> Fulfilment.OrderNumber (LEFT JOIN = may not exist)
```

---

## Recommended Fixes

### Option 1: Add NULL Check with Default (Minimal Change)
```sql
-- Line 142-145: Change from:
@OrderSource = f.OrderSource,

-- To:
@OrderSource = COALESCE(f.OrderSource, 'Unknown'),  -- Or empty string ''
```

### Option 2: Inner Join (Enforced Requirements)
```sql
-- Line 148: Change from:
LEFT JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0

-- To:
INNER JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
```
**Risk:** Will fail if any Waveline lacks a Fulfilment record. Add error handling.

### Option 3: Store OrderSource in Final Table (Schema Change)
1. Add `OrderSource` column to `dbo.CMCPackingWaveResult` table
2. Include in final INSERT statement (lines 278-365)
3. Ensures OrderSource is persisted for audit trail

---

## Investigation Steps

### Run Diagnostic Queries
Use the file: `Diagnostics/OrderSource_NullAnalysis.sql`

This will show:
1. **Query 1:** Wavelines WITHOUT matching Fulfilment records
2. **Query 2:** Wavelines WITH Fulfilment but NULL OrderSource
3. **Query 3:** Summary statistics

### Example Expected Results
```
Issue                      | Count
---------------------------|--------
NO_FULFILMENT_RECORD       | 45
NULL_ORDERSOURCE           | 12
```

---

## Recommended Action Plan

### Immediate (Fix the NULL)
1. Run diagnostic queries to identify the actual distribution
2. If mostly missing Fulfilment: Add error handling before continuing
3. If mostly NULL OrderSource: Add COALESCE() fallback

### Short-term (Data Quality)
1. Ensure all orders have Fulfilment records created
2. Backfill NULL OrderSource values with correct data source
3. Add NOT NULL constraint to OrderSource column (after cleanup)

### Long-term (Schema/Process)
1. Add OrderSource to CMCPackingWaveResult for audit trail
2. Implement validation in order creation process
3. Add triggers or application logic to prevent NULL OrderSource

---

## Code Locations

- **Main Procedure:** `StoreProcedures/dbo.SP_VI_TBL_Wave_CreateShipmentsForCMCPackingWave.StoredProcedure.sql`
- **Table Definition:** `Tables/dbo.Fulfilment.Table.sql`
- **Related Table:** `LogTables/dbo.FulfilmentLog.Table.sql` (for audit trail)
- **Target Table:** `Tables/dbo.CMCPackingWaveResult.Table.sql`
