-- Opens a landing batch for one source system and returns the watermark the loader must
-- read from: the highest watermark of the last SUCCEEDED batch for that source, or NULL
-- for a first full load.
CREATE PROCEDURE [landing].[usp_BeginLandingBatch]
    @SourceSystemCode     VARCHAR (20),
    @RequestedAtUtc       DATETIME2 (3) = NULL,
    @BatchId              BIGINT        OUTPUT,
    @PreviousWatermarkUtc DATETIME2 (3) OUTPUT,
    @ParentBatchId        BIGINT        = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ProcessName VARCHAR (100) = CONCAT('LANDING_', @SourceSystemCode);
    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1
            FROM [reference].[SourceSystem] AS ss
            WHERE ss.[SourceSystemCode] = @SourceSystemCode
              AND ss.[IsActive] = 1
        )
        BEGIN
            SET @Message = CONCAT(N'Source system ', ISNULL(@SourceSystemCode, N'NULL'), N' is unknown or inactive.');
            THROW 50010, @Message, 1;
        END;

        SELECT @PreviousWatermarkUtc = MAX(br.[SourceWatermarkUtc])
        FROM [audit].[BatchRun] AS br
        WHERE br.[ProcessName] = @ProcessName
          AND br.[BatchStatusCode] = 'SUCCEEDED';

        EXEC [audit].[usp_LogBatchStart]
            @ProcessName = @ProcessName,
            @SourceSystemCode = @SourceSystemCode,
            @PreviousWatermarkUtc = @PreviousWatermarkUtc,
            @RequestedAtUtc = @RequestedAtUtc,
            @BatchId = @BatchId OUTPUT,
            @ParentBatchId = @ParentBatchId;
    END TRY
    BEGIN CATCH
        -- usp_LogBatchStart logs its own failures; only log errors raised here.
        IF @@TRANCOUNT = 0 AND ERROR_PROCEDURE() = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID), N'.', OBJECT_NAME(@@PROCID))
            EXEC [audit].[usp_LogError];

        THROW;
    END CATCH;
END;
