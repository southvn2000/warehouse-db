USE [3PLWMS_Developers]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[InitMasterData]
AS
BEGIN
    -- Master initialization procedure that merges all Seed_* init scripts.
    -- Safe to re-run because each insert is protected by NOT EXISTS checks.
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Clear existing master seed data before re-initialization.
        DELETE FROM [dbo].[Widget];
        DELETE FROM [dbo].[Setting];
        DELETE FROM [dbo].[AP_StandardService];
        DELETE FROM [dbo].[TenantReportDefinition];
        DELETE FROM [dbo].[ReportDefinition];
        DELETE FROM [dbo].[Country];

        -- Reset identity values so next inserted row starts from 1.
        IF EXISTS (
            SELECT 1
            FROM sys.identity_columns
            WHERE [object_id] = OBJECT_ID(N'[dbo].[Widget]')
        )
            DBCC CHECKIDENT (N'[dbo].[Widget]', RESEED, 0);

        IF EXISTS (
            SELECT 1
            FROM sys.identity_columns
            WHERE [object_id] = OBJECT_ID(N'[dbo].[Setting]')
        )
            DBCC CHECKIDENT (N'[dbo].[Setting]', RESEED, 0);

        IF EXISTS (
            SELECT 1
            FROM sys.identity_columns
            WHERE [object_id] = OBJECT_ID(N'[dbo].[AP_StandardService]')
        )
            DBCC CHECKIDENT (N'[dbo].[AP_StandardService]', RESEED, 0);

        IF EXISTS (
            SELECT 1
            FROM sys.identity_columns
            WHERE [object_id] = OBJECT_ID(N'[dbo].[ReportDefinition]')
        )
            DBCC CHECKIDENT (N'[dbo].[ReportDefinition]', RESEED, 0);

        IF EXISTS (
            SELECT 1
            FROM sys.identity_columns
            WHERE [object_id] = OBJECT_ID(N'[dbo].[Country]')
        )
            DBCC CHECKIDENT (N'[dbo].[Country]', RESEED, 0);

        -- Seed country master data.
        INSERT INTO [dbo].[Country] ([CountryName], [CountryCode], [Deleted])
        SELECT v.CountryName, v.CountryCode, v.Deleted
        FROM (VALUES
            ('AUSTRALIA', 'AU', 0),
            ('America', 'US', 1),
            ('ARGENTINA', 'AR', 0),
            ('GUERNSEY', 'GG', 0),
            ('ANTIGUA', 'AG', 0),
            ('ARUBA', 'AW', 0),
            ('BAHAMAS', 'BS', 0),
            ('UNITED ARAB EMIRATES', 'AE', 0),
            ('BRAZIL', 'BR', 0),
            ('ANDORRA', 'AD', 0),
            ('AUSTRIA', 'AT', 0),
            ('ALBANIA', 'AL', 0),
            ('ANGUILLA', 'AI', 0),
            ('BAHRAIN', 'BH', 0),
            ('BULGARIA', 'BG', 0),
            ('BURKINA FASO', 'BF', 0),
            ('AMERICAN SAMOA', 'AS', 0),
            ('BARBADOS', 'BB', 0),
            ('BERMUDA', 'BM', 0),
            ('BRUNEI', 'BN', 0),
            ('CUBA', 'CU', 0),
            ('DOMINICAN REPUBLIC', 'DO', 0),
            ('LIBYA', 'LY', 0),
            ('NEW ZEALAND', 'NZ', 0),
            ('PORTUGAL', 'PT', 0),
            ('SOLOMON ISLANDS', 'SB', 0),
            ('SENEGAL', 'SN', 0),
            ('SURINAME', 'SR', 0),
            ('RUSSIA', 'RU', 0),
            ('BONAIRE', 'XB', 0),
            ('CONGO, THE DEMOCRATIC REPUBLIC OF', 'CD', 0),
            ('BANGLADESH', 'BD', 0),
            ('BELGIUM', 'BE', 0),
            ('DJIBOUTI', 'DJ', 0),
            ('EGYPT', 'EG', 0),
            ('JAMAICA', 'JM', 0),
            ('KENYA', 'KE', 0),
            ('MAURITANIA', 'MR', 0),
            ('MONTSERRAT', 'MS', 0),
            ('MALDIVES', 'MV', 0),
            ('SAUDI ARABIA', 'SA', 0),
            ('SINGAPORE', 'SG', 0),
            ('COOK ISLANDS', 'CK', 0),
            ('EQUATORIAL GUINEA', 'GQ', 0),
            ('INDONESIA', 'ID', 0),
            ('NIGER', 'NE', 0),
            ('QATAR', 'QA', 0),
            ('SUDAN', 'SD', 0),
            ('UNITED STATES', 'US', 0),
            ('CURACAO', 'XC', 0),
            ('SOUTH AFRICA', 'ZA', 0),
            ('CZECHIA', 'CZ', 0),
            ('BENIN', 'BJ', 0),
            ('SWITZERLAND', 'CH', 0),
            ('ETHIOPIA', 'ET', 0),
            ('FRANCE', 'FR', 0),
            ('UNITED KINGDOM', 'GB', 0),
            ('GRENADA', 'GD', 0),
            ('GUYANA', 'GY', 0),
            ('BOSNIA AND HERZEGOVINA', 'BA', 0),
            ('IRAN', 'IR', 0),
            ('JAPAN', 'JP', 0),
            ('BHUTAN', 'BT', 0),
            ('BELIZE', 'BZ', 0),
            ('LAO PEOPLE''S DEMOCRATIC REPUBLIC', 'LA', 0),
            ('ST. LUCIA', 'LC', 0),
            ('SPAIN', 'ES', 0),
            ('FINLAND', 'FI', 0),
            ('MONACO', 'MC', 0),
            ('NAURU', 'NR', 0),
            ('REUNION', 'RE', 0),
            ('KUWAIT', 'KW', 0),
            ('LATVIA', 'LV', 0),
            ('ROMANIA', 'RO', 0),
            ('GEORGIA', 'GE', 0),
            ('PARAGUAY', 'PY', 0),
            ('RWANDA', 'RW', 0),
            ('TIMOR-LESTE', 'TL', 0),
            ('VIETNAM', 'VN', 0),
            ('KAZAKHSTAN', 'KZ', 0),
            ('ESTONIA', 'EE', 0),
            ('GUATEMALA', 'GT', 0),
            ('ITALY', 'IT', 0),
            ('MADAGASCAR', 'MG', 0),
            ('MONGOLIA', 'MN', 0),
            ('MAURITIUS', 'MU', 0),
            ('SOMALIA', 'SO', 0),
            ('VIRGIN ISLANDS, U.S.', 'VI', 0),
            ('TAJIKISTAN', 'TJ', 0),
            ('BOTSWANA', 'BW', 0),
            ('CANADA', 'CA', 0),
            ('ECUADOR', 'EC', 0),
            ('GUAM', 'GU', 0),
            ('GUINEA-BISSAU', 'GW', 0),
            ('HAITI', 'HT', 0),
            ('SAINT KITTS AND NEVIS', 'KN', 0),
            ('SAINT HELENA, ASCENSION AND TRISTAN DA CUNHA', 'SH', 0),
            ('MARTINIQUE', 'MQ', 0),
            ('SLOVAKIA', 'SK', 0),
            ('SAO TOME AND PRINCIPE', 'ST', 0),
            ('TUVALU', 'TV', 0),
            ('URUGUAY', 'UY', 0),
            ('MOLDOVA', 'MD', 0),
            ('CHINA', 'CN', 0),
            ('COSTA RICA', 'CR', 0),
            ('ALGERIA', 'DZ', 0),
            ('FAROE ISLANDS', 'FO', 0),
            ('HUNGARY', 'HU', 0),
            ('CAYMAN ISLANDS', 'KY', 0),
            ('SRI LANKA', 'LK', 0),
            ('LESOTHO', 'LS', 0),
            ('NIGERIA', 'NG', 0),
            ('ESWATINI', 'SZ', 0),
            ('CHAD', 'TD', 0),
            ('ST. MAARTEN', 'XM', 0),
            ('ARMENIA', 'AM', 0),
            ('CABO VERDE', 'CV', 0),
            ('FRENCH GUIANA', 'GF', 0),
            ('CANARY ISLANDS, THE', 'IC', 0),
            ('HOLY SEE', 'VA', 0),
            ('NORTHERN MARIANA ISLANDS', 'MP', 0),
            ('MALAYSIA', 'MY', 0),
            ('MOZAMBIQUE', 'MZ', 0),
            ('NORWAY', 'NO', 0),
            ('TURKS AND CAICOS ISLANDS', 'TC', 0),
            ('THAILAND', 'TH', 0),
            ('TANZANIA', 'TZ', 0),
            ('ST. BARTHELEMY', 'XY', 0),
            ('KOREA, DEMOCRATIC PEOPLE''S REPUBLIC OF', 'KP', 0),
            ('ANGOLA', 'AO', 0),
            ('GUINEA', 'GN', 0),
            ('HONG KONG', 'HK', 0),
            ('LIECHTENSTEIN', 'LI', 0),
            ('LUXEMBOURG', 'LU', 0),
            ('MARSHALL ISLANDS', 'MH', 0),
            ('NETHERLANDS', 'NL', 0),
            ('TOGO', 'TG', 0),
            ('VIRGIN ISLANDS, BRITISH', 'VG', 0),
            ('ISRAEL', 'IL', 0),
            ('UKRAINE', 'UA', 0),
            ('UZBEKISTAN', 'UZ', 0),
            ('JERSEY', 'JE', 0),
            ('MOROCCO', 'MA', 0),
            ('NAMIBIA', 'NA', 0),
            ('TONGA', 'TO', 0),
            ('TUNISIA', 'TN', 0),
            ('TURKMENISTAN', 'TM', 0),
            ('CAMEROON', 'CM', 0),
            ('COLOMBIA', 'CO', 0),
            ('GABON', 'GA', 0),
            ('GREECE', 'GR', 0),
            ('CAMBODIA', 'KH', 0),
            ('LIBERIA', 'LR', 0),
            ('LITHUANIA', 'LT', 0),
            ('MALI', 'ML', 0),
            ('NEPAL', 'NP', 0),
            ('PUERTO RICO', 'PR', 0),
            ('TAIWAN', 'TW', 0),
            ('SAINT VINCENT AND THE GRENADINES', 'VC', 0),
            ('VANUATU', 'VU', 0),
            ('AZERBAIJAN', 'AZ', 0),
            ('NIUE', 'NU', 0),
            ('BURUNDI', 'BI', 0),
            ('COTE D IVOIRE', 'CI', 0),
            ('FALKLAND ISLANDS', 'FK', 0),
            ('DOMINICA', 'DM', 0),
            ('ERITREA', 'ER', 0),
            ('ICELAND', 'IS', 0),
            ('LEBANON', 'LB', 0),
            ('MACAO', 'MO', 0),
            ('MALAWI', 'MW', 0),
            ('NICARAGUA', 'NI', 0),
            ('PAPUA NEW GUINEA', 'PG', 0),
            ('PAKISTAN', 'PK', 0),
            ('SWEDEN', 'SE', 0),
            ('SLOVENIA', 'SI', 0),
            ('SYRIA', 'SY', 0),
            ('SERBIA', 'RS', 0),
            ('IRAQ', 'IQ', 0),
            ('SAN MARINO', 'SM', 0),
            ('HONDURAS', 'HN', 0),
            ('INDIA', 'IN', 0),
            ('KOREA, REPUBLIC OF', 'KR', 0),
            ('SOUTH SUDAN', 'SS', 0),
            ('MYANMAR', 'MM', 0),
            ('NEW CALEDONIA', 'NC', 0),
            ('PHILIPPINES', 'PH', 0),
            ('POLAND', 'PL', 0),
            ('SEYCHELLES', 'SC', 0),
            ('VENEZUELA', 'VE', 0),
            ('SAMOA', 'WS', 0),
            ('MAYOTTE', 'YT', 0),
            ('MICRONESIA, FEDERATED STATES OF', 'FM', 0),
            ('BOLIVIA', 'BO', 0),
            ('CENTRAL AFRICAN REPUBLIC', 'CF', 0),
            ('CONGO', 'CG', 0),
            ('CYPRUS', 'CY', 0),
            ('GERMANY', 'DE', 0),
            ('FIJI', 'FJ', 0),
            ('COMOROS', 'KM', 0),
            ('OMAN', 'OM', 0),
            ('PANAMA', 'PA', 0),
            ('PERU', 'PE', 0),
            ('EL SALVADOR', 'SV', 0),
            ('TRINIDAD AND TOBAGO', 'TT', 0),
            ('SINT EUSTATIUS', 'XE', 0),
            ('ZAMBIA', 'ZM', 0),
            ('BELARUS', 'BY', 0),
            ('KYRGYZSTAN', 'KG', 0),
            ('KOSOVO', 'KV', 0),
            ('CHILE', 'CL', 0),
            ('DENMARK', 'DK', 0),
            ('GIBRALTAR', 'GI', 0),
            ('GREENLAND', 'GL', 0),
            ('GAMBIA', 'GM', 0),
            ('GUADELOUPE', 'GP', 0),
            ('JORDAN', 'JO', 0),
            ('KIRIBATI', 'KI', 0),
            ('MALTA', 'MT', 0),
            ('MEXICO', 'MX', 0),
            ('FRENCH POLYNESIA', 'PF', 0),
            ('NEVIS', 'XN', 1),
            ('NORTH MACEDONIA', 'MK', 0),
            ('SOMALILAND, REP OF (NORTH SOMALIA)', 'XS', 0),
            ('PALAU', 'PW', 0),
            ('SIERRA LEONE', 'SL', 0),
            ('AFGHANISTAN', 'AF', 0),
            ('IRELAND', 'IE', 0),
            ('GHANA', 'GH', 0),
            ('CROATIA', 'HR', 0),
            ('TURKEY', 'TR', 0),
            ('ZIMBABWE', 'ZW', 0),
            ('MONTENEGRO', 'ME', 0),
            ('UGANDA', 'UG', 0),
            ('YEMEN', 'YE', 0),
            ('UNITED STATES OF AMERICA', 'US', 0)
        ) AS v (CountryName, CountryCode, Deleted)
        WHERE NOT EXISTS (
            SELECT 1
            FROM [dbo].[Country] c
            WHERE c.[CountryName] = v.CountryName
              AND c.[CountryCode] = v.CountryCode
        );

        -- Seed report definitions used by system and portal reporting.
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

        -- Seed system settings for warehouse structure generation.
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

        -- Seed dashboard widgets.
        INSERT INTO [dbo].[Widget] ([WidgetName], [Deleted])
        SELECT v.WidgetName, v.Deleted
        FROM (VALUES
            ('Order Status', 0),
            ('Order Source', 0),
            ('Delay Order', 0),
            ('Order History', 0)
        ) AS v (WidgetName, Deleted)
        WHERE NOT EXISTS (
            SELECT 1
            FROM [dbo].[Widget] w
            WHERE w.[WidgetName] = v.WidgetName
        );

        -- Seed Australia Post standard services from postage_products.
        INSERT INTO [dbo].[AP_StandardService]
        (
            [ServiceName],
            [ServiceCode],
            [ProductCode],
            [Description],
            [SignatureOnDeliveryReceiverDrop],
            [SignatureAlwaysRequired],
            [SignatureOnDeliverySenderDrop],
            [NoSignature],
            [AuthorityToLeave],
            [SafeDropEnabled],
            [AllowPartialDelivery],
            [ProductID],
            [WarehouseCode],
            [Deleted]
        )
        SELECT
            REPLACE(v.[Type], ' ', '') AS [ServiceName],
            '0' AS [ServiceCode],
            '0' AS [ProductCode],
            v.[Type] AS [Description],
            0 AS [SignatureOnDeliveryReceiverDrop],
            0 AS [SignatureAlwaysRequired],
            0 AS [SignatureOnDeliverySenderDrop],
            0 AS [NoSignature],
            0 AS [AuthorityToLeave],
            0 AS [SafeDropEnabled],
            0 AS [AllowPartialDelivery],
            v.[ProductID] AS [ProductID],
            '0' AS [WarehouseCode],
            0 AS [Deleted]
        FROM (VALUES
            ('INTL STANDARD/PACK & TRACK', 'PTI8'),
            ('INT''L STANDARD WITH SIGNATURE', 'PTI7'),
            ('INTL EXPRESS MERCH', 'ECM8'),
            ('INTL EXPRESS DOCS', 'ECD8'),
            ('EXPRESS POST + SIGNATURE', '3J55'),
            ('PARCEL POST + SIGNATURE', '3D55')
        ) AS v ([Type], [ProductID]);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Roll back all seeds together on any failure.
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO
