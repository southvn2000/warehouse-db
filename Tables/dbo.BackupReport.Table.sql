USE [3PLWMS_Developers]
GO
/****** Object:  Table [dbo].[BackupReport]    Script Date: 5/5/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BackupReport](
	[BackupReportID] [int] IDENTITY(1,1) NOT NULL,
	[TenantCode] [varchar](10) NULL,
	[ReportName] [varchar](100) NULL,
	[WarehouseCode] [varchar](10) NULL,
	[BackupDate] [datetime] NULL,
	[ExcelFileContent] [varbinary](max) NULL,
	[Deleted] [bit] NULL,
	[CreatedDateTime] [datetime] NULL,
	[CreatedBy] [varchar](100) NULL,
	[UpdatedDateTime] [datetime] NULL,
	[UpdatedBy] [varchar](100) NULL,
 CONSTRAINT [PK_BackupReport] PRIMARY KEY CLUSTERED 
(
	[BackupReportID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[BackupReport] ADD  CONSTRAINT [DF_BackupReport_Deleted]  DEFAULT ((0)) FOR [Deleted]
GO
