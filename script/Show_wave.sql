
USE [3PLWMS_DEVELOPERS]
GO




DECLARE @WaveId INT;;
DECLARE @WaveNumber NVARCHAR(50) = '996';
DECLARE @TenantCode NVARCHAR(50) = 'ATKGEAR';--'YENAURA';--'ATKGEAR';
DECLARE @TransactionType NVARCHAR(50) = 'Allocated'; --'Picked';--'Allocated';
DECLARE @OrderNumber NVARCHAR(50) = '3979';

IF @WaveId IS NOT NULL
BEGIN
    select @WaveNumber = WaveNumber from Wave Where waveId = @WaveId and Deleted = 0;
END
ELSE
BEGIN
    select @WaveId = WaveID from Wave Where WaveNumber = @WaveNumber and Deleted = 0;
END

SELECT PackingResultID as 'a'
		FROM dbo.PackingResult WHERE WaveID = 937 AND OrderNumber = @OrderNumber AND Deleted = 0;	

SELECT 'Wave Information';
select * from Wave Where waveId = @WaveId and Deleted = 0
SELECT 'Wave Line Information';
select * from WaveLine Where waveId = @WaveId and Deleted = 0

SELECT 'Fulfilment Information';
Select * from Fulfilment 
Where order_number IN (select SourceOrderNumber from WaveLine Where waveId = @WaveId and Deleted = 0) and Deleted = 0 
AND TenantCode = @TenantCode;


Select line_items_name, Sum(line_items_current_quantity) 
from FulfilmentLine WHERE FulfilmentID IN (Select FulfilmentID from Fulfilment 
Where order_number IN (select SourceOrderNumber from WaveLine Where waveId = @WaveId and Deleted = 0) and Deleted = 0 
AND TenantCode = @TenantCode)
GROUP BY line_items_name;

Select *
from FulfilmentLine WHERE FulfilmentID IN (Select FulfilmentID from Fulfilment 
Where order_number IN (select SourceOrderNumber from WaveLine Where waveId = @WaveId and Deleted = 0) and Deleted = 0 
AND TenantCode = @TenantCode) Order By FulfilmentID;

Select 'Picking Schedule Information';
select ItemName, Sum(Qty) from PickingSchedule Where WaveID = @WaveId and Deleted = 0
group by ItemName

select * from PickingSchedule Where WaveID = @WaveId and Deleted = 0

Select 'Picking Result Information';
select * from PickingResult Where Deleted = 0 AND PickingScheduleID IN (select PickingScheduleID from PickingSchedule Where WaveID = @WaveId and Deleted = 0);

Select 'Sorting Schedule Information';

select * from SortingSchedule Where WaveID = @WaveId and Deleted = 0

Select 'Packing Information';

select * from PackingSchedule Where WaveID = @WaveId and Deleted = 0

select * from PackingResult Where WaveID = @WaveId and Deleted = 0

select * from PackingResultLine Where PackingResultID IN (select PackingResultID from PackingResult Where WaveID = @WaveId and Deleted = 0) and Deleted = 0;

select * from CMCPackingWaveResult Where WaveNumber = @WaveNumber and Deleted = 0

Select 'ULD Line Information';
Select u.TenantCode, ul.ItemName, Sum(ul.TransactionQty) 
from ULDLine ul
left join ULD u ON ul.ULDID = u.ULDID
Where ul.TransactionReference IN (
    select SourceOrderNumber from WaveLine Where waveId = @WaveId and Deleted = 0
    ) 
    and ul.Deleted = 0 AND ul.TransactionType=@TransactionType And u.TenantCode = @TenantCode
Group by u.TenantCode, ul.ItemName;

Select u.TenantCode, ul.*
from ULDLine ul
left join ULD u ON ul.ULDID = u.ULDID
Where ul.TransactionReference IN (
    select SourceOrderNumber from WaveLine Where waveId = @WaveId and Deleted = 0
    ) 
    and ul.Deleted = 0 AND ul.TransactionType=@TransactionType And u.TenantCode = @TenantCode


Select 'Picking Invoice Information';
Select * from Invoice Where WaveReferences = @WaveNumber And ChargeCategory ='Picking' and Deleted = 0 order by InvoiceReferences;

Select 'Packing Invoice Information';
Select * from Invoice Where WaveReferences = @WaveNumber And ChargeCategory ='Packing' and Deleted = 0 order by InvoiceReferences;

Select 'Shipping Invoice Information';
Select * from Invoice Where WaveReferences = @WaveNumber And ChargeCategory ='Mailing' and Deleted = 0 order by InvoiceReferences;