USE [3PLWMS_Developers]
GO
/****** Object:  UserDefinedTableType [dbo].[CMCResult]    Script Date: 3/24/2026 ******/
CREATE TYPE [dbo].[CMCResult] AS TABLE(
        [WaveNumber] [nvarchar](50) NULL,
        [SourceOrderNumber] [nvarchar](50) NULL,
        [TenantCode] [nvarchar](50) NULL,
        [TenantName] [nvarchar](100) NULL,
        [PickingSlipNumber] [nvarchar](100) NULL,
        [OrderStatus] [nvarchar](20) NULL,
        [BoxEventID] [nvarchar](20) NULL,
        [BoxEventText] [nvarchar](200) NULL,
        [PackID] [int] NULL,
        [BoxSizeH] [decimal](10, 2) NULL,
        [BoxSzieL] [decimal](10, 2) NULL,
        [BoxSizeW] [decimal](10, 2) NULL,
        [BoxArea] [decimal](18, 2) NULL,
        [Weight_Carton] [decimal](18, 4) NULL,
        [Box_Weight] [decimal](18, 4) NULL
)
GO
