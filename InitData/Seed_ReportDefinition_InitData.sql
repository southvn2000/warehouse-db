USE [3PLWMS_QA]
GO

SET NOCOUNT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    INSERT INTO [dbo].[ReportDefinition]
    (
        [ReportName],
        [StoreProcedure],
        [Type],
        [Cat],
        [Invoice],
        [CurrentData],
        [Mandatory],
        [OutputType],
        [Deleted]
    )
    SELECT
        v.ReportName,
        v.StoreProcedure,
        v.[Type],
        v.Cat,
        v.Invoice,
        v.CurrentData,
        v.Mandatory,
        v.OutputType,
        v.Deleted
    FROM (VALUES
        ('InvoiceWeekly - Server', 'SP_VI_TBL_ReportScript_InvoiceWeeklyReport', 'Schedule', 'System', 1, 0, 1, 'Server', 0),
        ('StockOnHandSummaryDaily - Portal', 'SP_VI_TBL_ReportScript_StockOnHandDailyReport', 'Schedule', 'System', 0, 1, 0, 'Portal', 0),
        ('InvoiceWeekly - Portal', 'SP_VI_TBL_ReportScript_InvoiceWeeklyReport', 'Schedule', 'System', 1, 0, 1, 'Portal', 0),
        ('StockOnHandMonthly - Portal', 'SP_VI_TBL_ReportScript_StockOnHandMonthlyReport', 'Schedule', 'System', 0, 1, 0, 'Portal', 0),
        ('StockOnHandWeekly - Portal', 'SP_VI_TBL_ReportScript_StockOnHandWeeklyReport', 'Schedule', 'System', 0, 1, 0, 'Portal', 0),
        ('ReceivingSummaryWeekly - Portal', 'SP_VI_TBL_ReportScript_ReceivingSummaryWeeklyReport', 'Schedule', 'System', 0, 0, 0, 'Portal', 0),
        ('ReceivingDetailWeekly - Portal', 'SP_VI_TBL_ReportScript_ReceivingDetailWeeklyReport', 'Schedule', 'System', 0, 0, 0, 'Portal', 0),
        ('StockTakeSummaryWeekly - Portal', 'SP_VI_TBL_ReportScript_StockTakeSummaryWeeklyReport', 'Schedule', 'System', 0, 0, 0, 'Portal', 0),
        ('StockTakeDetailWeekly - Portal', 'SP_VI_TBL_ReportScript_StockTakeDetailWeeklyReport', 'Schedule', 'System', 0, 0, 0, 'Portal', 0),
        ('StockOnHandSummary', 'SP_VI_TBL_ReportScript_StockOnHandManualReport', 'Manual', 'System', 0, 1, 0, NULL, 0),
        ('ReceivingSummary', 'SP_VI_TBL_ReportScript_ReceivingSummaryManualReport', 'Manual', 'System', 0, 0, 0, NULL, 0),
        ('StockTakeSummary', 'SP_VI_TBL_ReportScript_StockTakeSummaryManualReport', 'Manual', 'System', 0, 0, 0, NULL, 0),
        ('StockTakeDetail', 'SP_VI_TBL_ReportScript_StockTakeDetailManualReport', 'Manual', 'System', 0, 0, 0, NULL, 0),
        ('ReceivingDetail', 'SP_VI_TBL_ReportScript_ReceivingDetailManualReport', 'Manual', 'System', 0, 0, 0, NULL, 0),
        ('StockOnHandDetailDaily - Portal', 'SP_VI_TBL_ReportScript_StockOnHandDetailDailyReport', 'Schedule', 'System', 0, 1, 0, 'Portal', 0),
        ('StockOnHandDetail', 'SP_VI_TBL_ReportScript_StockOnHandDetailManualReport', 'Manual', 'System', 0, 1, 0, NULL, 0),
        ('TotalInvoiceWeekly - Server', 'SP_VI_TBL_ReportScript_TotalInvoiceWeeklyReport', 'Schedule', 'System', 1, 0, 1, 'Server', 0),
        ('SummaryInvoiceWeekly - Server', 'SP_VI_TBL_ReportScript_SummaryInvoiceWeeklyReport', 'Schedule', 'System', 1, 0, 1, 'Server', 0),
        ('StockReachLimitDaily - Portal', 'SP_VI_TBL_ReportScript_StockReachLimitDailyReport', 'Schedule', 'System', 0, 1, 0, 'Portal', 0),
        ('StockExpiredAlertDaily - Portal', 'SP_VI_TBL_ReportScript_StockExpiredAlertDailyReport', 'Schedule', 'System', 0, 1, 0, 'Portal', 0),
        ('StockReachLimit', 'SP_VI_TBL_ReportScript_StockReachLimitManualReport', 'Manual', 'System', 0, 1, 0, NULL, 0),
        ('StockExpiredAlert', 'SP_VI_TBL_ReportScript_StockExpiredAlertManualReport', 'Manual', 'System', 0, 1, 0, NULL, 0),
        ('CloseJob', 'SP_VI_TBL_ReportScript_CloseJobManualReport', 'Manual', 'System', 0, 0, 0, NULL, 0),
        ('OpenJob', 'SP_VI_TBL_ReportScript_OpenJobManualReport', 'Manual', 'System', 0, 1, 0, NULL, 0),
        ('Stock Inventory', 'SP_VI_TBL_ReportScript_StockOnHandManualReport', 'Manual', NULL, 0, 1, 0, NULL, 0),
        ('Pending jobs', 'SP_VI_TBL_ReportScript_OpenJobManualReport', 'Manual', NULL, 0, 1, 0, NULL, 0),
        ('Closed jobs', 'SP_VI_TBL_ReportScript_CloseJobManualReport', 'Manual', 'Custom', 0, 0, 0, NULL, 0),
        ('Receiving reports', 'SP_VI_TBL_ReportScript_ReceivingDetailManualReport', 'Manual', 'Custom', 0, 0, 0, NULL, 0)
    ) AS v
    (
        ReportName,
        StoreProcedure,
        [Type],
        Cat,
        Invoice,
        CurrentData,
        Mandatory,
        OutputType,
        Deleted
    )
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [dbo].[ReportDefinition] r
        WHERE ISNULL(r.[ReportName], '') = ISNULL(v.ReportName, '')
          AND ISNULL(r.[StoreProcedure], '') = ISNULL(v.StoreProcedure, '')
          AND ISNULL(r.[Type], '') = ISNULL(v.[Type], '')
          AND ISNULL(r.[OutputType], '') = ISNULL(v.OutputType, '')
    );

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;
GO
