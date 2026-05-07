USE [3PLWMS_QA]
GO

/*
Purpose:
- Reproduce input for dbo.SP_VI_TBL_Items_CheckAvailableStockOfItemsInLocation
- Payload source: 4 Shopify orders (1142, 1151, 1152, 1153)
- Requested OperationBy: 271000105152599

Notes:
- OrderLineType expects OrderItemNumber, so ItemSKU is mapped to OrderItemNumber.
- @LocationType/@LocationID should match your real picking scope.
*/

DECLARE @NumberOfOrders INT = 4;
DECLARE @LocationType VARCHAR(20) = NULL;   -- Change to 'Section' if needed
DECLARE @LocationID INT = NULL;                  -- Change to the real AreaID/SectionID
DECLARE @PickingType VARCHAR(50) = NULL;      -- e.g. 'Single' or NULL
DECLARE @OperationDateTime DATETIME = GETDATE();
DECLARE @OperationBy VARCHAR(100) = '271000105152599';
DECLARE @Message VARCHAR(4000);

DECLARE @OrderNumbers dbo.OrderType;
DECLARE @OrderItems dbo.OrderLineType;

INSERT INTO @OrderNumbers (
    OrderNumber,
    OrderSource,
    CarrierID,
    Carrier,
    TenantCode,
    Phone,
    Email,
    WarehouseCode,
    ShippingAddressName,
    ShippingAddressCompany,
    ShippingAddressAddress1,
    ShippingAddressAddress2,
    ShippingAddressCity,
    ShippingAddressProvince,
    ShippingAddressZip,
    ShippingAddressCountry
)
VALUES
(
    N'1142', N'shopify', 1, N'Australia+Post+AP+Standard', N'YENAURA',
    N'+61410226186', N'dtseuser001@gmail.com', N'Y',
    N'Rodion+Kor', NULL, N'85+Grose+Street', NULL,
    N'North+Parramatta', N'NSW', N'2151', N'Australia'
),
(
    N'1151', N'shopify', 1, N'Australia+Post+AP+Free', N'YENAURA',
    N'0410226186', N'dtseuser001@gmail.com', N'Y',
    N'Rodion+Kor', NULL, N'85+Grose+Street', NULL,
    N'North+Parramatta', N'NSW', N'2151', N'Australia'
),
(
    N'1152', N'shopify', 1, N'Australia+Post+AP+Standard', N'YENAURA',
    N'0410226186', N'dtseuser001@gmail.com', N'Y',
    N'Rodion+Kor', NULL, N'85+Grose+Street', NULL,
    N'North+Parramatta', N'NSW', N'2151', N'Australia'
),
(
    N'1153', N'shopify', 1, N'Australia+Post+AP+Standard', N'YENAURA',
    N'+61410226186', N'dtseuser001@gmail.com', N'Y',
    N'Rodion+Kor', NULL, N'85+Grose+Street', NULL,
    N'North+Parramatta', N'NSW', N'2151', N'Australia'
);

INSERT INTO @OrderItems (
    OrderNumber,
    ItemID,
    OrderItemNumber,
    OrderItemName,
    OrderQuantity
)
VALUES
(N'1142', 0, N'SB-HNY-001', N'Skin+Clearning+Honey+and+Turmeric+Bar', 1),
(N'1151', 0, N'SRM-SC-001', N'Skin+Clearing+Serum', 3),
(N'1152', 0, N'SRM-SC-001', N'Skin+Clearing+Serum', 2),
(N'1153', 0, N'SRM-SC-001', N'Skin+Clearing+Serum', 1);

-- Optional: inspect TVP payload before execution
--SELECT * FROM @OrderNumbers;
--SELECT * FROM @OrderItems;

EXEC [dbo].[SP_VI_TBL_Items_CheckAvailableStockOfItemsInLocation]
    @NumberOfOrders = @NumberOfOrders,
    @OrderNumbers = @OrderNumbers,
    @OrderItems = @OrderItems,
    @LocationType = @LocationType,
    @LocationID = @LocationID,
    @PickingType = @PickingType,
    @OperationDateTime = @OperationDateTime,
    @OperationBy = @OperationBy,
    @Message = @Message OUTPUT;

SELECT @Message AS Message;
