/*
  Calculate mailing cost for Fulfilment orders (non-MS flow), aligned with current SP logic:

  - AP (CarrierID = 1):
    charge = CEILING(AP_order_total_cost * (1 + MailingChargePercent/100))
    only when APIntegration.IsWarehouseAccount = 1 and MailingChargePercent > 0

  - DHL (CarrierID = 3):
    mailing charge = CEILING(DHLResponse.price * (1 + MailingChargePercent/100))
    plus Extra Order Cost (Tenant.ExtraOrderCost) per matched PackingResult shipment row
    only when DHLIntegration.IsWarehouseAccount = 1

  Notes:
  - Input is dbo.StringArray (column: Value).
  - This script calculates only; it does not insert invoices.
*/

USE [3PLWMS_QA]
GO

SET NOCOUNT ON;

------------------------------------------------------------
-- 1) Input array of Fulfilment.OrderNumber
------------------------------------------------------------
DECLARE @OrderNumbers dbo.StringArray;

-- Example input:
INSERT INTO @OrderNumbers ([Value])
VALUES
  ('1371'),
  ('1372'),
  ('1373');

IF OBJECT_ID('tempdb..#AllCharges') IS NOT NULL
        DROP TABLE #AllCharges;

------------------------------------------------------------
-- 2) Normalize input to existing Fulfilment orders
------------------------------------------------------------
;WITH InputOrders AS
(
    SELECT DISTINCT
        f.OrderNumber,
        f.TenantCode,
        f.WarehouseCode
    FROM dbo.Fulfilment f
    INNER JOIN @OrderNumbers i
        ON i.[Value] = f.OrderNumber
    WHERE f.Deleted = 0
),
LatestWaveLine AS
(
    SELECT
        io.OrderNumber,
        wl.WaveID,
        wl.CarrierID,
        wl.ShipmentType,
        wl.ShipmentID
    FROM InputOrders io
    OUTER APPLY
    (
        SELECT TOP (1)
            w.WaveID,
            w.CarrierID,
            w.ShipmentType,
            w.ShipmentID
        FROM dbo.WaveLine w
        WHERE w.OrderNumber = io.OrderNumber
          AND w.Deleted = 0
        ORDER BY w.WaveID DESC
    ) wl
),

------------------------------------------------------------
-- 3) AP mailing charge rows
------------------------------------------------------------
APBase AS
(
    SELECT
        io.OrderNumber,
        io.TenantCode,
        io.WarehouseCode,
        wl.WaveID,
        wl.ShipmentType,
        wl.ShipmentID,
        ISNULL(t.MailingChargePercent, 0) AS MailingChargePercent,
        ISNULL(t.ExtraOrderCost, 0) AS ExtraOrderCost,
        ISNULL(api.IsWarehouseAccount, 1) AS IsWarehouseAccount,
        lwc.Currency
    FROM InputOrders io
    INNER JOIN dbo.WaveLine wl
        ON wl.OrderNumber = io.OrderNumber
       AND wl.Deleted = 0
       AND wl.CarrierID = 1
    INNER JOIN dbo.Tenant t
        ON t.TenantCode = io.TenantCode
       AND t.Deleted = 0
    INNER JOIN dbo.LocWarehouse lwc
        ON lwc.WarehouseCode = io.WarehouseCode
       AND lwc.Deleted = 0
    LEFT JOIN dbo.APIntegration api
        ON api.TenantCode = io.TenantCode
       AND api.Deleted = 0
),
APCharges AS
(
    SELECT
        a.OrderNumber,
        a.TenantCode,
        a.WarehouseCode,
        a.WaveID,
        CAST('AP Shipping Charge' AS VARCHAR(100)) AS ChargeName,
        CAST
        (
            CEILING
            (
                ISNULL(
                    CASE
                        WHEN a.ShipmentType = 'Local' THEN
                            (SELECT TOP (1) s.AP_order_total_cost
                             FROM dbo.AP_Shipment s
                             WHERE s.ShipmentID = a.ShipmentID
                               AND s.Deleted = 0)
                        ELSE
                            (SELECT TOP (1) s.AP_order_total_cost
                             FROM dbo.AP_ShipmentINT s
                             WHERE s.ShipmentID = a.ShipmentID
                               AND s.Deleted = 0)
                    END
                , 0)
            )
            AS DECIMAL(10,2)
        ) AS OriginCharge,
        CAST
        (
            CEILING
            (
                ISNULL(
                    CASE
                        WHEN a.ShipmentType = 'Local' THEN
                            (SELECT TOP (1) s.AP_order_total_cost
                             FROM dbo.AP_Shipment s
                             WHERE s.ShipmentID = a.ShipmentID
                               AND s.Deleted = 0)
                        ELSE
                            (SELECT TOP (1) s.AP_order_total_cost
                             FROM dbo.AP_ShipmentINT s
                             WHERE s.ShipmentID = a.ShipmentID
                               AND s.Deleted = 0)
                    END
                , 0)
                * (1 + CAST(a.MailingChargePercent AS DECIMAL(10,4)) / 100.0)
            )
            AS DECIMAL(10,2)
        ) AS Charge,
        0 as Extra,
        a.Currency
    FROM APBase a
    WHERE a.ShipmentID IS NOT NULL
      AND a.ShipmentType IS NOT NULL
      AND a.IsWarehouseAccount = 1
      AND a.MailingChargePercent > 0
),
APExtraCharges AS
(
    SELECT
        a.OrderNumber,
        a.TenantCode,
        a.WarehouseCode,
        a.WaveID,
        CAST('Extra Order Cost' AS VARCHAR(100)) AS ChargeName,
        0 as OriginCharge,
        0 as Charge,
        CAST(a.ExtraOrderCost AS DECIMAL(10,2)) AS Extra,
        a.Currency
    FROM APBase a
    WHERE a.ExtraOrderCost <> 0
),

------------------------------------------------------------
-- 4) DHL mailing + extra rows
------------------------------------------------------------
DHLBase AS
(
    SELECT
        io.OrderNumber,
        io.TenantCode,
        io.WarehouseCode,
        lw.WaveID,
        pr.ShipmentID,
        ISNULL(t.MailingChargePercent, 0) AS MailingChargePercent,
        ISNULL(t.ExtraOrderCost, 0) AS ExtraOrderCost,
        lwc.Currency
    FROM InputOrders io
    INNER JOIN LatestWaveLine lw
        ON lw.OrderNumber = io.OrderNumber
    INNER JOIN dbo.PackingResult pr
        ON pr.OrderNumber = io.OrderNumber
       AND pr.Deleted = 0
       AND pr.ShipmentID IS NOT NULL
    INNER JOIN dbo.Tenant t
        ON t.TenantCode = io.TenantCode
       AND t.Deleted = 0
    INNER JOIN dbo.LocWarehouse lwc
        ON lwc.WarehouseCode = io.WarehouseCode
       AND lwc.Deleted = 0
    LEFT JOIN dbo.DHLIntegration di
        ON di.TenantCode = io.TenantCode
       AND di.Deleted = 0
    WHERE lw.CarrierID = 3
      AND ISNULL(di.IsWarehouseAccount, 1) = 1
),
DHLMailingCharges AS
(
    SELECT
        d.OrderNumber,
        d.TenantCode,
        d.WarehouseCode,
        d.WaveID,
        CAST('DHL Shipping Charge' AS VARCHAR(100)) AS ChargeName,
        CAST
        (
            CEILING
            (
                ISNULL(
                    (SELECT TOP (1) r.price
                     FROM dbo.DHLResponse r
                     WHERE r.MessageReference = d.OrderNumber)
                , 0)
            )
            AS DECIMAL(10,2)
        ) AS OriginCharge,
        CAST
        (
            CEILING
            (
                ISNULL(
                    (SELECT TOP (1) r.price
                     FROM dbo.DHLResponse r
                     WHERE r.MessageReference = d.OrderNumber)
                , 0)
                * (1 + CAST(d.MailingChargePercent AS DECIMAL(10,4)) / 100.0)
            )
            AS DECIMAL(10,2)
        ) AS Charge,
        0 as Extra,
        d.Currency
    FROM DHLBase d
    WHERE d.MailingChargePercent > 0
),
DHLExtraCharges AS
(
    SELECT
        d.OrderNumber,
        d.TenantCode,
        d.WarehouseCode,
        d.WaveID,
        CAST('Extra Order Cost' AS VARCHAR(100)) AS ChargeName,
        0 as OriginCharge,
        0 as Charge,
        CAST(d.ExtraOrderCost AS DECIMAL(10,2)) AS Extra,
        d.Currency
    FROM DHLBase d
    WHERE d.ExtraOrderCost <> 0
),
AllCharges AS
(
    SELECT * FROM APCharges
    UNION ALL
    SELECT * FROM APExtraCharges
    UNION ALL
    SELECT * FROM DHLMailingCharges
    UNION ALL
    SELECT * FROM DHLExtraCharges
)

SELECT
    c.OrderNumber,
    c.WaveID,
    c.TenantCode,
    c.WarehouseCode,
    c.ChargeName,
    c.OriginCharge,
    c.Extra,
    c.Charge,
    c.Currency
INTO #AllCharges
FROM AllCharges c;

------------------------------------------------------------
-- 5) Single consolidated result table
------------------------------------------------------------
SELECT
    c.OrderNumber,
    MAX(w.WaveNumber) AS WaveNumber,
    c.TenantCode,
    COALESCE(
        MAX(CASE
                WHEN c.ChargeName LIKE 'DHL %' THEN 'DHL'
                WHEN c.ChargeName LIKE 'AP %' THEN 'AP'
            END),
        MAX(ct.CarrierType)
    ) AS [Type],
    MAX(CAST(ISNULL(t.ExtraOrderCost, 0) AS DECIMAL(10,2))) AS ExtraOrderCostOfTenant,
    MAX(CAST(ISNULL(t.MailingChargePercent, 0) AS DECIMAL(10,2))) AS MailingChargePercentOfTenant,
    CAST(SUM(CASE WHEN c.ChargeName LIKE '%Shipping%' THEN c.OriginCharge ELSE 0 END) AS DECIMAL(10,2)) AS [Cost of AP or DHL],  
    CAST(
        SUM(c.Extra)
        AS DECIMAL(10,2)
    ) AS ExtraOrderTotal,
    CAST(
        SUM(c.Charge)
        AS DECIMAL(10,2)
    ) AS [TotalMailing Cost (CEILING(cost * (1 + MailingChargePercent/100)))],
    MAX(c.Currency) AS Currency
FROM #AllCharges c
LEFT JOIN dbo.Wave w
    ON w.WaveID = c.WaveID
   AND w.Deleted = 0
LEFT JOIN dbo.Tenant t
    ON t.TenantCode = c.TenantCode
   AND t.Deleted = 0
LEFT JOIN
(
    SELECT
        wl.OrderNumber,
        MAX(CASE
                WHEN wl.CarrierID = 3 THEN 'DHL'
                WHEN wl.CarrierID = 1 THEN 'AP'
            END) AS CarrierType
    FROM dbo.WaveLine wl
    WHERE wl.Deleted = 0
    GROUP BY wl.OrderNumber
) ct
    ON ct.OrderNumber = c.OrderNumber
GROUP BY c.OrderNumber, c.TenantCode
ORDER BY c.OrderNumber;


Select ChargeName,  InvoiceReferences, Qty, Cost, Charge, Currency 
from Invoice Where Deleted = 0 and ChargeCategory = 'Shipping' and InvoiceReferences IN (SELECT [Value] FROM @OrderNumbers) 
ORDER BY InvoiceReferences;

DROP TABLE #AllCharges;
