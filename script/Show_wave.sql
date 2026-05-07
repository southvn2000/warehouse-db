
USE [3PLWMS_QA]
GO


DECLARE @WaveId INT = 404;
DECLARE @TenantCode NVARCHAR(50) = 'pepprb';
DECLARE @TransactionType NVARCHAR(50) = 'Picked';--'Allocated';

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

Select 'Sorting Schedule Information';

select * from SortingSchedule Where WaveID = @WaveId and Deleted = 0

Select 'Packing Information';

select * from PackingSchedule Where WaveID = @WaveId and Deleted = 0

select * from PackingResult Where WaveID = @WaveId and Deleted = 0

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