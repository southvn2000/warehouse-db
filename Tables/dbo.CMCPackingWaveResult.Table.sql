USE [3PLWMS_Developers]
GO
/****** Object:  Table [dbo].[CMCPackingWaveResult]    Script Date: 3/17/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CMCPackingWaveResult](
	[CMCPackingWaveResultID] [int] IDENTITY(1,1) NOT NULL,
	[WaveNumber] [varchar](11) NULL,
	[SourceOrderNumber] [varchar](50) NULL,
	[TenantCode] [varchar](50) NULL,
	[TenantName] [varchar](100) NULL,
	[PickingSlipNumber] [varchar](100) NULL,
	[ItemCodes] [varchar](max) NULL,
	[ItemBarcode] [varchar](max) NULL,
	[ItemSerialNo] [varchar](max) NULL,
	[QTY] [varchar](50) NULL,
	[LabelDataLen] [varchar](50) NULL,
	[LabelData] [varchar](max) NULL,
	[Status] [varchar](20) NULL,
	[MatchLab] [varchar](50) NULL,
	[ShipmentID] [int] NULL,
	[IsLocal] [bit] NULL,
	[Carrier] [varchar](100) NULL,
	[OrderSource] [varchar](50) NULL,
	[Deleted] [bit] NULL,
	[CreatedDateTime] [datetime] NULL,
	[CreatedBy] [varchar](100) NULL,
	[FirstEditedDateTime] [datetime] NULL,
	[FirstEditedBy] [varchar](100) NULL,
	[LastEditedDateTime] [datetime] NULL,
	[LastEditedBy] [varchar](100) NULL,
 CONSTRAINT [PK_CMCPackingWaveResult] PRIMARY KEY CLUSTERED 
(
	[CMCPackingWaveResultID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[CMCPackingWaveResult] ADD  CONSTRAINT [DF_CMCPackingWaveResult_Status]  DEFAULT ('Pending') FOR [Status]
GO
ALTER TABLE [dbo].[CMCPackingWaveResult]  WITH CHECK ADD  CONSTRAINT [CK_CMCPackingWaveResult_Status] CHECK  (([Status]='Pending' OR [Status]='InProgress' OR [Status]='Completed' OR [Status]='Canceled'))
GO
ALTER TABLE [dbo].[CMCPackingWaveResult] CHECK CONSTRAINT [CK_CMCPackingWaveResult_Status]
GO
