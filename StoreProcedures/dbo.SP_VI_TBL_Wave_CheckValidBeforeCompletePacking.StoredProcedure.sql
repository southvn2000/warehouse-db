USE [3PLWMS_Developers]
GO
/****** Object:  StoredProcedure [dbo].[SP_VI_TBL_Wave_CheckValidBeforeCompletePacking]    Script Date: 3/25/2026 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:   <Nam Nguyen>
-- Create date: <25 Mar, 2026>
-- Description: <Check if wave is available to complete packing>
-- =============================================
CREATE PROCEDURE [dbo].[SP_VI_TBL_Wave_CheckValidBeforeCompletePacking]
    @WaveNumber VARCHAR(11),
    @IsAllow BIT OUTPUT,
    @Message VARCHAR(4000) OUTPUT
AS
BEGIN

    SET NOCOUNT ON;

    SET @IsAllow = 0;
    SET @Message = NULL;

    DECLARE @WaveID INT,
            @WaveStatus VARCHAR(20),
            @CurrentOperation VARCHAR(50),
            @OperationStatus VARCHAR(20),
            @PackRequired BIT,
            @ManualPacking BIT;

    SELECT @WaveID = WaveID,
           @WaveStatus = WaveStatus,
           @PackRequired = PackRequired,
            @ManualPacking = ManualPacking,
           @OperationStatus = StepStatus,
           @CurrentOperation = CurrentStep
    FROM dbo.Wave
    WHERE WaveNumber = @WaveNumber
      AND Deleted = 0;

    IF @WaveID IS NULL
    BEGIN
        SET @Message = 'This Wave does not exist.';
        RETURN;
    END

    IF ISNULL(@PackRequired, 0) = 0
    BEGIN
        SET @Message = 'Packing is not required for this Wave.';
        RETURN;
    END

    IF @WaveStatus = 'Pending'
    BEGIN
        SET @Message = 'This Wave has not been started yet.';
        RETURN;
    END

    IF @WaveStatus = 'Completed'
    BEGIN
        SET @Message = 'This Wave has already completed.';
        RETURN;
    END

    IF ISNULL(@CurrentOperation, '') <> 'Packing'
    BEGIN
        SET @Message = 'This Wave is not in Packing phase';
        RETURN;
    END

    IF @OperationStatus = 'Completed'
    BEGIN
        SET @Message = 'Packing phase has been already completed .';
        RETURN;
    END

    IF @OperationStatus = 'Pending'
    BEGIN
        SET @Message = 'Packing phase has not been started yet.';
        RETURN;
    END

    IF ISNULL(@ManualPacking, 0) = 1
       AND EXISTS
    (
        SELECT 1
        FROM dbo.PackingSchedule
        WHERE WaveID = @WaveID
          AND Deleted = 0
          AND Status = 'Taken'
    )
    BEGIN
        SET @Message = 'There is on-going packing task.';
        RETURN;
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.WaveLine
        WHERE WaveID = @WaveID
          AND Deleted = 0
    )
    BEGIN
        SET @Message = 'This Wave does not contain any WaveLine.';
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM dbo.WaveLine
        WHERE WaveID = @WaveID
          AND Deleted = 0
          AND ISNULL(PackStatus, '') <> 'Completed'
    )
    BEGIN
        SET @Message = 'There are WaveLines that have not completed packing yet.';
        RETURN;
    END

    SET @IsAllow = 1;
END
GO
