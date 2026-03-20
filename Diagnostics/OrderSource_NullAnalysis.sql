-- =============================================
-- Diagnostic Query: OrderSource NULL Analysis
-- Purpose: Identify why OrderSource is NULL in Wave Processing
-- =============================================

USE [3PLWMS_Developers]
GO

-- Query 1: Orders in Wave WITHOUT matching Fulfilment records
-- These will cause OrderSource to be NULL due to LEFT JOIN
SELECT 
    wl.OrderNumber,
    wl.WaveID,
    w.WaveNumber,
    wl.ShipmentID,
    'NO_FULFILMENT_RECORD' AS Issue,
    'Waveline has no matching Fulfilment record - OrderSource will be NULL' AS Reason
FROM dbo.Waveline wl
INNER JOIN dbo.Wave w ON w.WaveID = wl.WaveID AND w.Deleted = 0
LEFT JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
WHERE wl.Deleted = 0
  AND f.FulfilmentID IS NULL  -- No matching fulfilment
ORDER BY w.WaveNumber, wl.OrderNumber;


-- Query 2: Orders in Wave WITH Fulfilment records but OrderSource IS NULL
-- These have a fulfilment record but the OrderSource column is not populated
SELECT 
    wl.OrderNumber,
    wl.WaveID,
    w.WaveNumber,
    wl.ShipmentID,
    f.FulfilmentID,
    f.OrderSource,
    f.order_number,
    f.TenantCode,
    'NULL_ORDERSOURCE' AS Issue,
    'Fulfilment record exists but OrderSource column is NULL' AS Reason
FROM dbo.Waveline wl
INNER JOIN dbo.Wave w ON w.WaveID = wl.WaveID AND w.Deleted = 0
INNER JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
WHERE wl.Deleted = 0
  AND f.OrderSource IS NULL
ORDER BY w.WaveNumber, wl.OrderNumber;


-- Query 3: Summary statistics
SELECT 
    'Total Wavelines in active waves' AS Metric,
    COUNT(*) AS Count
FROM dbo.Waveline wl
INNER JOIN dbo.Wave w ON w.WaveID = wl.WaveID AND w.Deleted = 0
WHERE wl.Deleted = 0

UNION ALL

SELECT 
    'Wavelines WITHOUT matching Fulfilment',
    COUNT(*)
FROM dbo.Waveline wl
INNER JOIN dbo.Wave w ON w.WaveID = wl.WaveID AND w.Deleted = 0
LEFT JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
WHERE wl.Deleted = 0 AND f.FulfilmentID IS NULL

UNION ALL

SELECT 
    'Wavelines WITH Fulfilment but NULL OrderSource',
    COUNT(*)
FROM dbo.Waveline wl
INNER JOIN dbo.Wave w ON w.WaveID = wl.WaveID AND w.Deleted = 0
INNER JOIN dbo.Fulfilment f ON f.OrderNumber = wl.OrderNumber AND f.Deleted = 0
WHERE wl.Deleted = 0 AND f.OrderSource IS NULL;
