USE [3PLWMS_Developers]
GO
/****** Object:  UserDefinedTableType [dbo].[CMCResult]    Script Date: 3/24/2026 ******/
CREATE TYPE [dbo].[CMCResult] AS TABLE(        
        [FulfilmentNumber] [nvarchar](50) NULL,       
        [OrderStatus] [nvarchar](20) NULL,       
        [BoxSizeH] [decimal](10, 2) NULL,
        [BoxSzieL] [decimal](10, 2) NULL,
        [BoxSizeW] [decimal](10, 2) NULL,       
        [Weight_Carton] [decimal](18, 4) NULL,
        [Box_Weight] [decimal](18, 4) NULL
)
GO
