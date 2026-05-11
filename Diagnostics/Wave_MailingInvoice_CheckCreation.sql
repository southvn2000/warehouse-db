USE [3PLWMS_QA]
GO

/****** Diagnostic Script: Check Mailing Invoice Creation for a Wave ******/
-- Purpose: Verify if mailing invoices were created for a given WaveID
-- Author: Analysis Agent
-- Date: 2026-05-07

SET NOCOUNT ON;

DECLARE @WaveID INT = 407;  -- <-- SET THIS TO YOUR WAVE ID

IF @WaveID IS NULL
BEGIN
    PRINT '[ERROR] @WaveID is NULL. Please set @WaveID before running this script.';
    RETURN;
END

PRINT '========================================== MAILING INVOICE CREATION CHECK ==========================================';
PRINT 'Wave ID: ' + CAST(@WaveID AS VARCHAR(20));
PRINT '';

-- =====================================================================
-- STEP 1: Verify Wave Exists
-- =====================================================================

PRINT '--- STEP 1: Check if Wave exists ---';

DECLARE @WaveNumber VARCHAR(11);
DECLARE @WaveStatus VARCHAR(50);
DECLARE @WaveDeleted BIT;
DECLARE @WaveWarehouseCode VARCHAR(20);

SELECT TOP 1
    @WaveNumber = w.WaveNumber,
    @WaveStatus = w.WaveStatus,
    @WaveDeleted = w.Deleted,
    @WaveWarehouseCode = w.WarehouseCode
FROM dbo.Wave w
WHERE w.WaveID = @WaveID;

IF @WaveNumber IS NULL
BEGIN
    PRINT '[FAIL] Wave not found for WaveID = ' + CAST(@WaveID AS VARCHAR(20));
    RETURN;
END
ELSE
BEGIN
    PRINT '[OK] Wave found:';
    PRINT '  - WaveNumber: ' + @WaveNumber;
    PRINT '  - Status: ' + ISNULL(@WaveStatus, 'NULL');
    PRINT '  - Deleted: ' + CAST(@WaveDeleted AS VARCHAR(1));
    PRINT '  - WarehouseCode: ' + ISNULL(@WaveWarehouseCode, 'NULL');
    PRINT '';
END

-- =====================================================================
-- STEP 2: List Orders in Wave (Mail Perspective)
-- =====================================================================

PRINT '--- STEP 2: Orders in wave (mail status summary) ---';

DECLARE @WaveOrderCount INT;
DECLARE @MailedOrderCount INT;

SELECT
    @WaveOrderCount = COUNT(DISTINCT wl.OrderNumber),
    @MailedOrderCount = COUNT(DISTINCT CASE WHEN wl.MailStatus IS NOT NULL THEN wl.OrderNumber END)
FROM dbo.WaveLine wl
WHERE wl.WaveID = @WaveID
  AND wl.Deleted = 0;

PRINT 'Total orders in wave      : ' + CAST(ISNULL(@WaveOrderCount, 0) AS VARCHAR(10));
PRINT 'Orders with MailStatus set: ' + CAST(ISNULL(@MailedOrderCount, 0) AS VARCHAR(10));
PRINT '';

IF ISNULL(@WaveOrderCount, 0) = 0
BEGIN
    PRINT '[WARN] No active WaveLine rows found for this wave.';
    PRINT '';
END
ELSE
BEGIN
    ;WITH PsOrder AS
    (
        SELECT
            ps.WaveID,
            ps.OrderNumber,
            MIN(ps.WarehouseCode) AS WarehouseCode
        FROM dbo.PickingSchedule ps
        WHERE ps.Deleted = 0
        GROUP BY ps.WaveID, ps.OrderNumber
    )
    SELECT
        wl.TenantCode,
        po.WarehouseCode,
        wl.OrderNumber,
        wl.SourceOrderNumber,
        wl.MailStatus,
        wl.MailDateTime,
        wl.MailBy,
        wl.PackStatus,
        wl.PickStatus
    FROM dbo.WaveLine wl
    LEFT JOIN PsOrder po
        ON po.WaveID = wl.WaveID
       AND po.OrderNumber = wl.OrderNumber
    WHERE wl.WaveID = @WaveID
      AND wl.Deleted = 0
    ORDER BY wl.TenantCode, po.WarehouseCode, wl.OrderNumber;

    PRINT '';
END

-- =====================================================================
-- STEP 3: Check Conditions to Create Mailing Invoice
-- =====================================================================

PRINT '--- STEP 3: Tenant charge setup for mailing invoice ---';
PRINT '';

DECLARE @Step3TenantInfo TABLE
(
    TenantCode VARCHAR(10),
    MailingChargePercent INT,
    ExtraOrderCost DECIMAL(10,2)
);

INSERT INTO @Step3TenantInfo (TenantCode, MailingChargePercent, ExtraOrderCost)
SELECT
    wl.TenantCode,
    ISNULL(t.MailingChargePercent, 0),
    ISNULL(t.ExtraOrderCost, 0)
FROM
(
    SELECT DISTINCT
        TenantCode
    FROM dbo.WaveLine
    WHERE WaveID = @WaveID
      AND Deleted = 0
      AND TenantCode IS NOT NULL
) wl
LEFT JOIN dbo.Tenant t
    ON t.TenantCode = wl.TenantCode
   AND t.Deleted = 0;

SELECT
    s.TenantCode AS Tenant,
    s.MailingChargePercent,
    s.ExtraOrderCost
FROM @Step3TenantInfo s
ORDER BY s.TenantCode;

DECLARE @Step3TenantCode VARCHAR(10);
DECLARE @Step3MailingChargePercent INT;
DECLARE @Step3ExtraOrderCost DECIMAL(10,2);

DECLARE cur_Step3Tenant CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        s.TenantCode,
        s.MailingChargePercent,
        s.ExtraOrderCost
    FROM @Step3TenantInfo s
    ORDER BY s.TenantCode;

OPEN cur_Step3Tenant;

FETCH NEXT FROM cur_Step3Tenant
INTO @Step3TenantCode, @Step3MailingChargePercent, @Step3ExtraOrderCost;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT ISNULL(@Step3TenantCode, 'NULL')
          + ' - '
          + CAST(ISNULL(@Step3MailingChargePercent, 0) AS VARCHAR(20))
          + ' - '
          + CAST(ISNULL(@Step3ExtraOrderCost, 0) AS VARCHAR(30));

    FETCH NEXT FROM cur_Step3Tenant
    INTO @Step3TenantCode, @Step3MailingChargePercent, @Step3ExtraOrderCost;
END;

CLOSE cur_Step3Tenant;
DEALLOCATE cur_Step3Tenant;

PRINT '';

-- =====================================================================
-- STEP 4: Get ShipmentID by CarrierID Rule
-- =====================================================================

PRINT '--- STEP 4: ShipmentID by CarrierID rule ---';

DECLARE @Step4Info TABLE
(
    TenantCode VARCHAR(10),
    OrderNumber VARCHAR(50),
    CarrierID INT,
    CarrierName VARCHAR(100),
    ShipmentID INT,
    ShipmentSourceRule VARCHAR(100),
    ManualInvoiceComment VARCHAR(500),
    ShipmentCheckStatus VARCHAR(50)
);

;WITH WaveOrders AS
(
    SELECT DISTINCT
        wl.TenantCode,
        wl.OrderNumber
    FROM dbo.WaveLine wl
    WHERE wl.WaveID = @WaveID
      AND wl.Deleted = 0
),
FulfilmentCarrier AS
(
    SELECT
        f.OrderNumber,
        MIN(f.CarrierID) AS CarrierID,
        MIN(f.Carrier) AS CarrierName
    FROM dbo.Fulfilment f
    WHERE f.Deleted = 0
    GROUP BY f.OrderNumber
)
INSERT INTO @Step4Info
(
    TenantCode,
    OrderNumber,
    CarrierID,
    CarrierName,
    ShipmentID,
    ShipmentSourceRule,
    ManualInvoiceComment,
    ShipmentCheckStatus
)
SELECT
    wo.TenantCode,
    wo.OrderNumber,
    fc.CarrierID,
    fc.CarrierName,
    CASE
        WHEN fc.CarrierID = 1 THEN ap.ShipmentID
        WHEN fc.CarrierID = 3 AND LEFT(wo.OrderNumber, 3) = 'MS-' THEN dhlWave.ShipmentID
        ELSE dhlManual.ShipmentID
    END AS ShipmentID,
    CASE
        WHEN fc.CarrierID = 1 THEN 'AP_Shipment by Shipment_Reference'
        WHEN fc.CarrierID = 3 AND LEFT(wo.OrderNumber, 3) = 'MS-' THEN 'Fulfilment + PackingResult by OrderNumber'
        ELSE 'DHLShipment by MessageReference'
    END AS ShipmentSourceRule,
    dhlManual.ManualInvoiceComment,
    CASE
        WHEN
            (CASE
                WHEN fc.CarrierID = 1 THEN ap.ShipmentID
                WHEN fc.CarrierID = 3 AND LEFT(wo.OrderNumber, 3) = 'MS-' THEN dhlWave.ShipmentID
                ELSE dhlManual.ShipmentID
             END) IS NULL
        THEN '[WARN] ShipmentID not found by rule'
        ELSE '[OK] ShipmentID found by rule'
    END AS ShipmentCheckStatus
FROM WaveOrders wo
LEFT JOIN FulfilmentCarrier fc
    ON fc.OrderNumber = wo.OrderNumber
OUTER APPLY
(
    SELECT TOP 1
        f.ShipmentID
    FROM dbo.AP_Shipment AS f
    WHERE f.Deleted = 0
      AND f.Shipment_Reference = wo.OrderNumber
) ap
OUTER APPLY
(
    SELECT TOP 1
        ps.ShipmentID
    FROM dbo.Fulfilment AS f
    JOIN dbo.PackingResult AS ps ON ps.OrderNumber = f.OrderNumber AND ps.Deleted = 0
    WHERE f.Deleted = 0
      AND f.OrderNumber = wo.OrderNumber
) dhlWave
OUTER APPLY
(
    SELECT TOP 1
        f.ShipmentID,
        f.ManualInvoiceComment
    FROM dbo.DHLShipment AS f
    WHERE f.Deleted = 0
      AND f.MessageReference = wo.OrderNumber
) dhlManual
ORDER BY
    wo.TenantCode,
    wo.OrderNumber;

SELECT
    s.TenantCode,
    s.OrderNumber,
    s.CarrierID,
    s.CarrierName,
    s.ShipmentID,
    s.ShipmentSourceRule,
    s.ManualInvoiceComment,
    s.ShipmentCheckStatus
FROM @Step4Info s
ORDER BY s.TenantCode, s.OrderNumber;

DECLARE @Step4OrderNumber VARCHAR(50);
DECLARE @Step4CarrierID INT;
DECLARE @Step4CarrierName VARCHAR(100);
DECLARE @Step4ShipmentID INT;

DECLARE cur_Step4Info CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        s.OrderNumber,
        s.CarrierID,
        s.CarrierName,
        s.ShipmentID
    FROM @Step4Info s
    ORDER BY s.TenantCode, s.OrderNumber;

OPEN cur_Step4Info;

FETCH NEXT FROM cur_Step4Info
INTO @Step4OrderNumber, @Step4CarrierID, @Step4CarrierName, @Step4ShipmentID;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT ISNULL(@Step4OrderNumber, 'NULL')
          + ' - '
          + CAST(ISNULL(@Step4CarrierID, 0) AS VARCHAR(20))
          + ' - '
          + ISNULL(@Step4CarrierName, 'NULL')
          + ' - '
          + CAST(ISNULL(@Step4ShipmentID, 0) AS VARCHAR(20));

    FETCH NEXT FROM cur_Step4Info
    INTO @Step4OrderNumber, @Step4CarrierID, @Step4CarrierName, @Step4ShipmentID;
END;

CLOSE cur_Step4Info;
DEALLOCATE cur_Step4Info;

PRINT '';

PRINT '';
PRINT '========================================== END OF REPORT ==========================================';

SET NOCOUNT OFF;

GO
