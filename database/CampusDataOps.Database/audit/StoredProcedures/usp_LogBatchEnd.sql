CREATE PROCEDURE [audit].[usp_LogBatchEnd]
    @BatchId            BIGINT,
    @BatchStatusCode    VARCHAR (20),
    @SourceWatermarkUtc DATETIME2 (3) = NULL,
    @RowsRead           INT           = NULL,
    @RowsInserted       INT           = NULL,
    @RowsUpdated        INT           = NULL,
    @RowsUnchanged      INT           = NULL,
    @RowsRejected       INT           = NULL,
    @ExceptionCount     INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1
            FROM [reference].[BatchStatus] AS bs
            WHERE bs.[BatchStatusCode] = @BatchStatusCode
              AND bs.[IsTerminal] = 1
        )
        BEGIN
            SET @Message = CONCAT(N'Batch status ', ISNULL(@BatchStatusCode, N'NULL'), N' is not a terminal status.');
            THROW 50004, @Message, 1;
        END;

        UPDATE br
        SET br.[BatchStatusCode] = @BatchStatusCode,
            br.[EndedAtUtc] = @NowUtc,
            br.[SourceWatermarkUtc] = @SourceWatermarkUtc,
            br.[RowsRead] = @RowsRead,
            br.[RowsInserted] = @RowsInserted,
            br.[RowsUpdated] = @RowsUpdated,
            br.[RowsUnchanged] = @RowsUnchanged,
            br.[RowsRejected] = @RowsRejected,
            br.[ExceptionCount] = @ExceptionCount,
            br.[UpdatedAtUtc] = @NowUtc
        FROM [audit].[BatchRun] AS br
        WHERE br.[BatchId] = @BatchId
          AND br.[BatchStatusCode] = 'RUNNING';

        IF @@ROWCOUNT = 0
        BEGIN
            SET @Message = CONCAT(N'Batch ', @BatchId, N' does not exist or is not RUNNING.');
            THROW 50005, @Message, 1;
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT = 0
            EXEC [audit].[usp_LogError] @BatchId = @BatchId;

        THROW;
    END CATCH;
END;
