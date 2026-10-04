-- Closes a landing batch. Landing is append-only, so a successful batch must account for
-- every row read as inserted, unchanged (same hash already landed) or rejected, and must
-- report the watermark it reached. A failed batch never advances the watermark.
CREATE PROCEDURE [landing].[usp_EndLandingBatch]
    @BatchId            BIGINT,
    @Succeeded          BIT,
    @SourceWatermarkUtc DATETIME2 (3) = NULL,
    @RowsRead           INT           = 0,
    @RowsInserted       INT           = 0,
    @RowsUnchanged      INT           = 0,
    @RowsRejected       INT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Message NVARCHAR (400);
    DECLARE @PreviousWatermarkUtc DATETIME2 (3);
    DECLARE @IsLandingBatch BIT = 0;
    DECLARE @BatchStatusCode VARCHAR (20);

    BEGIN TRY
        SELECT
            @IsLandingBatch = CASE WHEN br.[SourceSystemCode] IS NOT NULL THEN 1 ELSE 0 END,
            @PreviousWatermarkUtc = br.[PreviousWatermarkUtc]
        FROM [audit].[BatchRun] AS br
        WHERE br.[BatchId] = @BatchId;

        IF @IsLandingBatch = 0
        BEGIN
            SET @Message = CONCAT(N'Batch ', @BatchId, N' is not a landing batch.');
            THROW 50011, @Message, 1;
        END;

        IF @Succeeded IS NULL
            THROW 50012, N'Succeeded must be 0 or 1.', 1;

        IF @Succeeded = 1
        BEGIN
            IF @SourceWatermarkUtc IS NULL
                THROW 50013, N'A successful landing batch must report the source watermark it reached.', 1;

            IF @SourceWatermarkUtc < @PreviousWatermarkUtc
                THROW 50014, N'Source watermark cannot move backwards.', 1;

            IF @RowsRead IS NULL OR @RowsInserted IS NULL OR @RowsUnchanged IS NULL OR @RowsRejected IS NULL
               OR @RowsRead <> @RowsInserted + @RowsUnchanged + @RowsRejected
            BEGIN
                SET @Message = CONCAT(N'Control totals do not balance for batch ', @BatchId,
                                      N': read must equal inserted + unchanged + rejected.');
                THROW 50015, @Message, 1;
            END;
        END
        ELSE IF @SourceWatermarkUtc IS NOT NULL
            THROW 50016, N'A failed landing batch must not report a watermark.', 1;

        SET @BatchStatusCode = CASE WHEN @Succeeded = 1 THEN 'SUCCEEDED' ELSE 'FAILED' END;

        EXEC [audit].[usp_LogBatchEnd]
            @BatchId = @BatchId,
            @BatchStatusCode = @BatchStatusCode,
            @SourceWatermarkUtc = @SourceWatermarkUtc,
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted,
            @RowsUpdated = 0,
            @RowsUnchanged = @RowsUnchanged,
            @RowsRejected = @RowsRejected;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT = 0 AND ERROR_PROCEDURE() = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID))
            EXEC [audit].[usp_LogError] @BatchId = @BatchId;

        THROW;
    END CATCH;
END;
