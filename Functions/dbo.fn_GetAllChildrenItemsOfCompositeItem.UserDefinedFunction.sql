USE [3PLWMS_Developers]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetAllChildrenItemsOfCompositeItem]    Script Date: 4/15/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:              <Nam nguyen>
-- Create date: <15 Apr, 2026>
-- Description: <Get All Children Items of Composite Item (TVF replacing SP to avoid nested INSERT...EXEC)>
-- =============================================
CREATE FUNCTION [dbo].[fn_GetAllChildrenItemsOfCompositeItem]
(
        @CompositeItemID INT
)
RETURNS TABLE
AS
RETURN
(
        WITH RecursiveComponents AS (
                -- Anchor: start from root
                SELECT 
                        ic.ItemID,
                        ic.Quantity AS CumulativeQuantity,
                        1 AS Level
                FROM dbo.ItemComposite ic
                WHERE ic.ParentItemID = @CompositeItemID AND ic.Deleted = 0

                UNION ALL

                -- Recursive: find sub-components of current composite items
                SELECT 
                        ic.ItemID,
                        rc.CumulativeQuantity * ic.Quantity AS CumulativeQuantity,
                        rc.Level + 1
                FROM dbo.ItemComposite ic
                INNER JOIN RecursiveComponents rc ON ic.ParentItemID = rc.ItemID AND ic.Deleted = 0
                INNER JOIN dbo.Items i ON rc.ItemID = i.ItemID AND i.Deleted = 0
                WHERE i.CompositeType = 'Order' AND i.ItemIsComposite = 1
        )

        SELECT 
                rc.ItemID,
                CAST(SUM(rc.CumulativeQuantity) AS INT) AS Qty
        FROM RecursiveComponents rc
        INNER JOIN dbo.Items i ON i.ItemID = rc.ItemID AND i.Deleted = 0
        WHERE i.ItemIsComposite IS NULL OR i.ItemIsComposite = 0 OR (i.ItemIsComposite = 1 AND i.CompositeType <> 'Order')
        GROUP BY rc.ItemID
);
GO
