-- Runs one source system's landing load as one atomic batch: open the batch, land the rows,
-- close it SUCCEEDED with balanced totals, all in one transaction. On failure nothing is
-- landed, the error is logged against the landing batch, the batch is closed FAILED and its
-- watermark does not advance. Landing accepts every row as received (validation happens in
-- staging), so rows rejected is always 0 here.
CREATE PROCEDURE [landing].[usp_RunLandingLoad]
    @SourceSystemCode VARCHAR (20),
    @ParentBatchId    BIGINT = NULL,
    @LandingBatchId   BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PreviousWatermarkUtc DATETIME2 (3);
    DECLARE @SourceWatermarkUtc DATETIME2 (3);
    DECLARE @RowsRead INT;
    DECLARE @RowsInserted INT;
    DECLARE @RowsUnchanged INT;
    DECLARE @Message NVARCHAR (400);

    -- Logs its own failures (unknown source, a batch already RUNNING).
    EXEC [landing].[usp_BeginLandingBatch]
        @SourceSystemCode = @SourceSystemCode,
        @BatchId = @LandingBatchId OUTPUT,
        @PreviousWatermarkUtc = @PreviousWatermarkUtc OUTPUT,
        @ParentBatchId = @ParentBatchId;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @SourceSystemCode = 'SLATE_SIM'
            EXEC [landing].[usp_LoadSlateSim]
                @BatchId = @LandingBatchId,
                @PreviousWatermarkUtc = @PreviousWatermarkUtc,
                @RowsRead = @RowsRead OUTPUT,
                @RowsInserted = @RowsInserted OUTPUT,
                @SourceWatermarkUtc = @SourceWatermarkUtc OUTPUT;
        ELSE IF @SourceSystemCode = 'J1_SIM'
            EXEC [landing].[usp_LoadJ1Sim]
                @BatchId = @LandingBatchId,
                @PreviousWatermarkUtc = @PreviousWatermarkUtc,
                @RowsRead = @RowsRead OUTPUT,
                @RowsInserted = @RowsInserted OUTPUT,
                @SourceWatermarkUtc = @SourceWatermarkUtc OUTPUT;
        ELSE IF @SourceSystemCode = 'DIRECTORY_SIM'
            EXEC [landing].[usp_LoadDirectorySim]
                @BatchId = @LandingBatchId,
                @PreviousWatermarkUtc = @PreviousWatermarkUtc,
                @RowsRead = @RowsRead OUTPUT,
                @RowsInserted = @RowsInserted OUTPUT,
                @SourceWatermarkUtc = @SourceWatermarkUtc OUTPUT;
        ELSE
        BEGIN
            SET @Message = CONCAT(N'No landing loader exists for source system ', @SourceSystemCode, N'.');
            THROW 50030, @Message, 1;
        END;

        SET @RowsUnchanged = @RowsRead - @RowsInserted;

        EXEC [landing].[usp_EndLandingBatch]
            @BatchId = @LandingBatchId,
            @Succeeded = 1,
            @SourceWatermarkUtc = @SourceWatermarkUtc,
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted,
            @RowsUnchanged = @RowsUnchanged,
            @RowsRejected = 0;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        EXEC [audit].[usp_LogError] @BatchId = @LandingBatchId;

        EXEC [landing].[usp_EndLandingBatch] @BatchId = @LandingBatchId, @Succeeded = 0;

        THROW;
    END CATCH;
END;
