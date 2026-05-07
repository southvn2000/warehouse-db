USE [3PLWMS_QA];
GO


IF OBJECT_ID('tempdb..#TmpULD') IS NOT NULL
    DROP TABLE #TmpULD;

CREATE TABLE #TmpULD
(
    ULDID INT PRIMARY KEY
);

INSERT INTO #TmpULD
    (ULDID)
VALUES
    (1027),
    (1028);

DECLARE @CurrentULDID INT;

DECLARE uld_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT ULDID
FROM #TmpULD
ORDER BY ULDID;

OPEN uld_cursor;

FETCH NEXT FROM uld_cursor INTO @CurrentULDID;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '========================================';
    PRINT 'ULDID: ' + CAST(@CurrentULDID AS NVARCHAR(20));

    SELECT
       ul.*
    FROM dbo.ULDLine ul
    WHERE ul.ULDID = @CurrentULDID AND ul.Deleted = 0;       

    FETCH NEXT FROM uld_cursor INTO @CurrentULDID;
END;

CLOSE uld_cursor;
DEALLOCATE uld_cursor;

DROP TABLE #TmpULD;