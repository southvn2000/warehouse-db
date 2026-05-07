/* ============================================================
   DIAGNOSTIC: Wave 347 – Fulfilment 1086 & 1088 (Yen Aura)
   Issue  : Both fulfilments show Completed in 3PLWMS but
            never reached Sorting; both still waiting to be
            packed.  1086 shows 100% picked despite insufficient
            stock; 1088 went to Error.
   Run each section independently or all at once.
   ============================================================ */

-- ─────────────────────────────────────────────────────────────
-- SECTION 1: Fulfilment header + WaveLine status snapshot
-- Expected: FulfilmentStatus, PickStatus, SortStatus, PackStatus
-- ─────────────────────────────────────────────────────────────

USE [3PLWMS_QA]
GO
SELECT
    f.FulfilmentID,
    f.OrderNumber          AS FulfilmentNumber,
    f.order_number         AS SourceOrderNumber,
    f.TenantCode,
    f.FulfilmentStatus,
    f.Deleted              AS F_Deleted,
    f.OnHold,
    wl.WaveLineID,
    wl.WaveID,
    wl.WaveNumber,
    wl.PickStatus,
    wl.SortStatus,
    wl.PackStatus,
    wl.MailStatus,
    wl.PickDateTime,
    wl.SortDateTime,
    wl.PackDateTime,
    wl.Deleted             AS WL_Deleted
FROM dbo.Fulfilment  f
JOIN dbo.WaveLine    wl ON wl.OrderNumber = f.OrderNumber
WHERE f.FulfilmentID IN (1086, 1088);

-- ─────────────────────────────────────────────────────────────
-- SECTION 2: Wave header for the wave(s) linked above
-- Expected: WaveStatus, WaveType, operation counts
-- ─────────────────────────────────────────────────────────────
SELECT
    w.WaveID,
    w.WaveNumber,
    w.WaveStatus,
    w.WaveType,
    w.WarehouseCode,
    w.Deleted              AS W_Deleted,
    w.CreatedDateTime,
    w.LastEditedDateTime,
    COUNT(wl.WaveLineID)   AS TotalOrders,
    SUM(CASE WHEN wl.PickStatus  = 'Completed' THEN 1 ELSE 0 END) AS PickCompleted,
    SUM(CASE WHEN wl.PickStatus  = 'Error'     THEN 1 ELSE 0 END) AS PickError,
    SUM(CASE WHEN wl.SortStatus  = 'Completed' THEN 1 ELSE 0 END) AS SortCompleted,
    SUM(CASE WHEN wl.SortStatus  = 'Error'     THEN 1 ELSE 0 END) AS SortError,
    SUM(CASE WHEN wl.PackStatus  = 'Completed' THEN 1 ELSE 0 END) AS PackCompleted,
    SUM(CASE WHEN wl.PackStatus  = 'Error'     THEN 1 ELSE 0 END) AS PackError,
    SUM(CASE WHEN wl.PackStatus  IS NULL       THEN 1 ELSE 0 END) AS PackNull
FROM dbo.Wave     w
JOIN dbo.WaveLine wl ON wl.WaveID = w.WaveID
WHERE w.WaveID IN (
    SELECT wl2.WaveID
    FROM   dbo.Fulfilment f2
    JOIN   dbo.WaveLine   wl2 ON wl2.OrderNumber = f2.OrderNumber
    WHERE  f2.FulfilmentID IN (1086, 1088)
)
GROUP BY
    w.WaveID, w.WaveNumber, w.WaveStatus, w.WaveType,
    w.WarehouseCode, w.Deleted,
    w.CreatedDateTime, w.LastEditedDateTime;

-- ─────────────────────────────────────────────────────────────
-- SECTION 3: PickingSchedule – qty required vs qty picked
-- Key check for 1086 "100% picking" with insufficient stock
-- ─────────────────────────────────────────────────────────────
SELECT
    ps.PickingScheduleID,
    ps.FulfilmentOrder     AS FulfilmentNumber,
    ps.OrderNumber         AS SourceOrderNumber,
    ps.ItemID,
    ps.ItemNumber,
    ps.ItemName,
    ps.Qty                 AS RequiredQty,
    ps.PickedQty,
    ps.Status              AS PickingStatus,
    ps.ULDID,
    ps.ULDBarcode,
    ps.ULDCurrentLocation,
    ps.StartDate,
    ps.CompletedDate,
    ps.OperationStaff,
    ps.Deleted             AS PS_Deleted
FROM dbo.PickingSchedule ps
JOIN dbo.Fulfilment      f  ON f.OrderNumber = ps.FulfilmentOrder
WHERE f.FulfilmentID IN (1086, 1088)
ORDER BY ps.FulfilmentOrder, ps.PickingScheduleID;

-- ─────────────────────────────────────────────────────────────
-- SECTION 4: PickingResult – actual scanned qty per line
-- Compare with PickingSchedule.Qty to confirm real pick vs
-- inflated/auto-completed qty
-- ─────────────────────────────────────────────────────────────
SELECT
    pr.PickingResultID,
    pr.OrderNumber,
    pr.PickingScheduleID,
    pr.ItemID,
    pr.ItemNumber,
    pr.ItemName,
    pr.RequiredQty,
    pr.Qty                 AS ActualPickedQty,
    pr.ScannedQty,
    pr.ScannedType,
    pr.ScannedUnit,
    pr.ULDBarcode,
    pr.ULDCurrentLocation,
    pr.Deleted             AS PR_Deleted,
    pr.CreatedDateTime,
    pr.CreatedBy
FROM dbo.PickingResult   pr
JOIN dbo.PickingSchedule ps ON ps.PickingScheduleID = pr.PickingScheduleID
JOIN dbo.Fulfilment      f  ON f.OrderNumber = ps.FulfilmentOrder
WHERE f.FulfilmentID IN (1086, 1088)
ORDER BY pr.OrderNumber, pr.PickingScheduleID;

-- ─────────────────────────────────────────────────────────────
-- SECTION 5: SortingSchedule – did sorting rows ever get created?
-- If empty for these OrderNumbers → sorting was never triggered
-- ─────────────────────────────────────────────────────────────
SELECT
    ss.SortingScheduleID,
    ss.WaveID,
    ss.OrderNumber,
    ss.ItemID,
    ss.ItemNumber,
    ss.ItemName,
    ss.Qty,
    ss.ULDBarcode,
    ss.ULDID,
    ss.Deleted             AS SS_Deleted,
    ss.CreatedDateTime,
    ss.CreatedBy
FROM dbo.SortingSchedule ss
JOIN dbo.Fulfilment      f  ON f.OrderNumber = ss.OrderNumber
WHERE f.FulfilmentID IN (1086, 1088)
ORDER BY ss.OrderNumber, ss.SortingScheduleID;

-- ─────────────────────────────────────────────────────────────
-- SECTION 6: PackingSchedule – why are they in packing queue?
-- Status = 'Init'/'Started' with no prior Sort means they were
-- created directly without going through sorting
-- ─────────────────────────────────────────────────────────────
SELECT
    pks.PackingScheduleID,
    pks.OrderNumber,
    pks.WaveID,
    pks.Status             AS PackingStatus,
    pks.StartDate,
    pks.CompletedDate,
    pks.OperationStaff,
    pks.Deleted            AS PKS_Deleted,
    pks.CreatedDateTime,
    pks.CreatedBy
FROM dbo.PackingSchedule pks
JOIN dbo.Fulfilment      f  ON f.OrderNumber = pks.OrderNumber
WHERE f.FulfilmentID IN (1086, 1088)
ORDER BY pks.OrderNumber, pks.PackingScheduleID;

-- ─────────────────────────────────────────────────────────────
-- SECTION 7: FulfilmentLine vs PickingSchedule qty reconciliation
-- Flags lines where Qty scheduled for picking ≠ ordered qty
-- ─────────────────────────────────────────────────────────────
SELECT
    f.FulfilmentID,
    f.OrderNumber          AS FulfilmentNumber,
    fl.FulfilmentLineID,
    fl.line_items_sku      AS SKU,
    fl.line_items_name     AS ItemName,
    fl.line_items_current_quantity AS OrderedQty,
    SUM(ps.Qty)            AS TotalScheduledPickQty,
    SUM(ps.PickedQty)      AS TotalPickedQty,
    CASE
        WHEN SUM(ps.PickedQty) >= fl.line_items_current_quantity THEN 'OK'
        WHEN SUM(ps.PickedQty) = 0                               THEN 'NOT PICKED'
        ELSE 'SHORT PICK'
    END                    AS PickStatus
FROM dbo.Fulfilment        f
JOIN dbo.FulfilmentLine    fl ON fl.FulfilmentID = f.FulfilmentID AND fl.Deleted = 0
LEFT JOIN dbo.PickingSchedule ps
       ON ps.FulfilmentOrder = f.OrderNumber
      AND ps.ItemID          = fl.ItemID
      AND ps.Deleted         = 0
WHERE f.FulfilmentID IN (1086, 1088)
GROUP BY
    f.FulfilmentID, f.OrderNumber,
    fl.FulfilmentLineID, fl.line_items_sku, fl.line_items_name,
    fl.line_items_current_quantity
ORDER BY f.FulfilmentID, fl.FulfilmentLineID;

-- ─────────────────────────────────────────────────────────────
-- SECTION 8: Full wave-347 order status overview
-- Spots if 1086/1088 are the only anomalies or a wider problem
-- ─────────────────────────────────────────────────────────────
SELECT
    wl.WaveLineID,
    wl.OrderNumber,
    wl.SourceOrderNumber,
    wl.TenantCode,
    wl.PickStatus,
    wl.SortStatus,
    wl.PackStatus,
    wl.MailStatus,
    f.FulfilmentID,
    f.FulfilmentStatus,
    f.Deleted              AS F_Deleted
FROM dbo.WaveLine   wl
JOIN dbo.Wave       w  ON w.WaveID = wl.WaveID
LEFT JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
WHERE w.WaveNumber = '347'          -- adjust if WaveNumber stores as int/padded
   OR w.WaveID    IN (
        SELECT wl2.WaveID
        FROM   dbo.Fulfilment f2
        JOIN   dbo.WaveLine   wl2 ON wl2.OrderNumber = f2.OrderNumber
        WHERE  f2.FulfilmentID IN (1086, 1088)
      )
ORDER BY wl.PickStatus, wl.SortStatus, wl.PackStatus, wl.OrderNumber;
