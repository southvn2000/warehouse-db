USE [3PLWMS_Developers]
GO

SET NOCOUNT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    INSERT INTO [dbo].[Setting] ([SettingName], [SettingDescription], [SettingValue], [Deleted])
    SELECT v.SettingName, v.SettingDescription, v.SettingValue, v.Deleted
    FROM (VALUES
        ('MAX_NUMBER_WAREHOUSES', 'Max number of Warehouses to be created', '1', 0),
        ('MAX_NUMBER_AREAS', 'Max number of Areas to be created', '5', 0),
        ('MAX_NUMBER_SECTIONS', 'Max number of Sections to be created', '5', 0),
        ('MAX_NUMBER_ROWS', 'Max number of rows to be created', '10', 0),
        ('MAX_NUMBER_COLUMNS', 'Max number of columns to be created', '20', 0),
        ('MAX_NUMBER_SHELVES', 'Max number of shelves to be created', '20', 0),
        ('MAX_NUMBER_BINS', 'Max number of bins to be created', '20', 0),
        ('MAX_NUMBER_SBINS', 'Max number of sub bins to be created', '20', 0),
        ('WAREHOUSE_INCREMENT', 'Increment steps of warehouse order number', '50', 0),
        ('AREA_INCREMENT', 'Increment steps of area order number', '50', 0),
        ('SECTION_INCREMENT', 'Increment steps of section order number', '50', 0),
        ('ROW_INCREMENT', 'Increment steps of row order number', '100', 0),
        ('COLUMN_INCREMENT', 'Increment steps of column order number', '200', 0),
        ('SHELF_INCREMENT', 'Increment steps of column order number', '500', 0),
        ('BIN_INCREMENT', 'Increment steps of bin order number', '1000', 0),
        ('SBIN_INCREMENT', 'Increment steps of sun bin order number', '10000', 0),
        ('SECTION_CODE_MAX_VALUE', 'Max value used for section code', '99', 0),
        ('ROW_CODE_MAX_VALUE', 'Max value used for row code', '999', 0),
        ('COLUMN_CODE_MAX_VALUE', 'Max value used for column code', '99999', 0),
        ('SHELF_CODE_MAX_VALUE', 'Max value used for shelf code', '999', 0),
        ('BIN_CODE_MAX_VALUE', 'Max value used for bin code', '999999', 0),
        ('SBIN_CODE_MAX_VALUE', 'Max value used for sbin code', '999999', 0),
        ('NUMBER_CHARS_OF_PREFIX', 'Number characters of prefix', '1', 0)
    ) AS v (SettingName, SettingDescription, SettingValue, Deleted)
    WHERE NOT EXISTS (
        SELECT 1
        FROM [dbo].[Setting] s
        WHERE s.[SettingName] = v.SettingName
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
