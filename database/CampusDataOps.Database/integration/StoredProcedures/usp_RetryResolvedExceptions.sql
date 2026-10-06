-- Approves resolved exceptions for retry at the start of the QUEUE step. A resolved blocking
-- exception on an application becomes RETRY_READY; anything else resolved is CLOSED. When an
-- OUTBOUND_WRITE_FAILURE becomes RETRY_READY, its permanently failed queue row is reset to
-- PENDING with a fresh attempt allowance.
CREATE PROCEDURE [integration].[usp_RetryResolvedExceptions]
    @BatchId      BIGINT,
    @RowsAffected INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @Retry [integration].[ExceptionTransitionList];
    DECLARE @Close [integration].[ExceptionTransitionList];

    BEGIN TRY
        INSERT INTO @Retry ([ExceptionId], [ToStatusCode])
        SELECT e.[ExceptionId], 'RETRY_READY' AS [ToStatusCode]
        FROM [integration].[IntegrationException] AS e
        INNER JOIN [reference].[ExceptionReason] AS r ON e.[ExceptionReasonCode] = r.[ExceptionReasonCode]
        WHERE e.[ExceptionStatusCode] = 'RESOLVED'
          AND e.[ApplicationId] IS NOT NULL
          AND r.[BlocksProcessing] = 1;

        INSERT INTO @Close ([ExceptionId], [ToStatusCode])
        SELECT e.[ExceptionId], 'CLOSED' AS [ToStatusCode]
        FROM [integration].[IntegrationException] AS e
        WHERE e.[ExceptionStatusCode] = 'RESOLVED'
          AND NOT EXISTS (SELECT 1 FROM @Retry AS rt WHERE rt.[ExceptionId] = e.[ExceptionId]);

        BEGIN TRANSACTION;

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Retry, @ReasonText = N'Approved for retry.', @Actor = N'SYSTEM', @BatchId = @BatchId;

        EXEC [integration].[usp_TransitionExceptions]
            @Transitions = @Close,
            @ReasonText = N'Resolved; no reprocessing is needed.',
            @Actor = N'SYSTEM',
            @BatchId = @BatchId,
            @ClearSourceHash = 1;

        UPDATE q
        SET q.[QueueStatusCode] = 'PENDING',
            q.[AttemptCount] = 0,
            q.[RetryGeneration] = q.[RetryGeneration] + 1,
            q.[UpdatedAtUtc] = @NowUtc
        FROM [integration].[OutboundStudentQueue] AS q
        INNER JOIN [integration].[IntegrationException] AS e
            ON q.[ApplicationId] = e.[ApplicationId]
           AND e.[ExceptionReasonCode] = 'OUTBOUND_WRITE_FAILURE'
        INNER JOIN @Retry AS rt ON e.[ExceptionId] = rt.[ExceptionId]
        WHERE q.[QueueStatusCode] = 'FAILED_PERMANENT';

        SET @RowsAffected = (SELECT COUNT(*) FROM @Retry) + (SELECT COUNT(*) FROM @Close);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
