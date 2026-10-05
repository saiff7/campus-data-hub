-- Sends sendable queue rows to J1-Sim through integration.usp_WriteApplicantToSis.
-- Rows are processed one at a time, each in its own short transaction, because every row is a
-- separate write to an external system: one bad row must not roll back the others. This is the
-- documented exception to set-based processing (docs/specifications/integration-controls.md).
-- A success marks the row SUCCEEDED, writes the crosswalk and moves the application's
-- RETRY_READY exceptions to REPROCESSED, all in the row's transaction. A failure rolls that
-- back, logs the error against the batch and step, counts the attempt and, at the attempt
-- limit, raises OUTBOUND_WRITE_FAILURE. If any attempt failed, the procedure raises an error
-- after the remaining rows are processed, so the pipeline step fails visibly.
CREATE PROCEDURE [integration].[usp_ProcessOutboundQueue]
    @BatchId      BIGINT,
    @BatchStepId  BIGINT = NULL,
    @RowsAffected INT    = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @QueueId BIGINT = 0;
    DECLARE @ApplicationId UNIQUEIDENTIFIER;
    DECLARE @SlatePersonId UNIQUEIDENTIFIER;
    DECLARE @ResultIdNumber INT;
    DECLARE @ExistingTarget INT;
    DECLARE @ErrorLogId BIGINT;
    DECLARE @ErrorNumber INT;
    DECLARE @Attempted INT = 0;
    DECLARE @Failed INT = 0;
    DECLARE @Message NVARCHAR (400);
    DECLARE @Transitions [integration].[ExceptionTransitionList];
    DECLARE @Conditions [integration].[ExceptionCondition];

    SET @RowsAffected = 0;

    -- Snapshot of the work at the start, so rows that fail are not retried within this run.
    SELECT q.[QueueId]
    INTO #Work
    FROM [integration].[OutboundStudentQueue] AS q
    INNER JOIN [reference].[OutboundQueueStatus] AS s ON q.[QueueStatusCode] = s.[QueueStatusCode]
    WHERE s.[IsSendable] = 1
      AND q.[AttemptCount] < q.[MaxAttempts];

    WHILE 1 = 1
    BEGIN
        SET @QueueId = (SELECT MIN(w.[QueueId]) FROM #Work AS w WHERE w.[QueueId] > @QueueId);
        IF @QueueId IS NULL
            BREAK;

        SET @Attempted += 1;
        SET @ResultIdNumber = NULL;
        SELECT @ApplicationId = q.[ApplicationId], @SlatePersonId = q.[SlatePersonId]
        FROM [integration].[OutboundStudentQueue] AS q
        WHERE q.[QueueId] = @QueueId;

        BEGIN TRY
            BEGIN TRANSACTION;

            EXEC [integration].[usp_WriteApplicantToSis] @QueueId = @QueueId, @ResultIdNumber = @ResultIdNumber OUTPUT;

            IF @ResultIdNumber IS NULL
                THROW 50301, N'The J1-Sim import interface returned no ID number.', 1;

            UPDATE q
            SET q.[QueueStatusCode] = 'SUCCEEDED',
                q.[AttemptCount] = q.[AttemptCount] + 1,
                q.[LastAttemptAtUtc] = SYSUTCDATETIME(),
                q.[ResultIdNumber] = @ResultIdNumber,
                q.[CompletedAtUtc] = SYSUTCDATETIME(),
                q.[ProcessedBatchId] = @BatchId,
                q.[UpdatedAtUtc] = SYSUTCDATETIME()
            FROM [integration].[OutboundStudentQueue] AS q
            WHERE q.[QueueId] = @QueueId;

            SET @ExistingTarget = (
                SELECT c.[TargetIdNumber]
                FROM [integration].[SourceCrosswalk] AS c
                WHERE c.[SourceSystemCode] = 'SLATE_SIM'
                  AND c.[SourceRecordId] = CAST(@SlatePersonId AS VARCHAR (64))
            );

            IF @ExistingTarget IS NULL
                INSERT INTO [integration].[SourceCrosswalk] (
                    [SourceSystemCode], [SourceRecordId], [TargetIdNumber], [CreatedByQueueId], [CreatedBatchId]
                )
                VALUES ('SLATE_SIM', CAST(@SlatePersonId AS VARCHAR (64)), @ResultIdNumber, @QueueId, @BatchId);
            ELSE IF @ExistingTarget <> @ResultIdNumber
            BEGIN
                SET @Message = CONCAT(
                    N'Queue row ', @QueueId, N' wrote ID number ', @ResultIdNumber,
                    N' but the Slate-Sim person is already linked to ', @ExistingTarget, N'.'
                );
                THROW 50302, @Message, 1;
            END;

            DELETE FROM @Transitions;
            INSERT INTO @Transitions ([ExceptionId], [ToStatusCode])
            SELECT e.[ExceptionId], 'REPROCESSED' AS [ToStatusCode]
            FROM [integration].[IntegrationException] AS e
            WHERE e.[ApplicationId] = @ApplicationId
              AND e.[ExceptionStatusCode] = 'RETRY_READY';

            EXEC [integration].[usp_TransitionExceptions]
                @Transitions = @Transitions,
                @ReasonText = N'The retry wrote the application to J1-Sim.',
                @Actor = N'SYSTEM',
                @BatchId = @BatchId;

            COMMIT TRANSACTION;
            SET @RowsAffected += 1;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            SET @Failed += 1;
            SET @ErrorNumber = ERROR_NUMBER();
            EXEC [audit].[usp_LogError] @BatchId = @BatchId, @BatchStepId = @BatchStepId, @ErrorLogId = @ErrorLogId OUTPUT;

            UPDATE q
            SET q.[AttemptCount] = q.[AttemptCount] + 1,
                q.[LastAttemptAtUtc] = SYSUTCDATETIME(),
                q.[LastErrorLogId] = @ErrorLogId,
                q.[QueueStatusCode] = CASE WHEN q.[AttemptCount] + 1 >= q.[MaxAttempts] THEN 'FAILED_PERMANENT' ELSE 'FAILED_RETRYABLE' END,
                q.[UpdatedAtUtc] = SYSUTCDATETIME()
            FROM [integration].[OutboundStudentQueue] AS q
            WHERE q.[QueueId] = @QueueId;

            IF EXISTS (
                SELECT 1 FROM [integration].[OutboundStudentQueue] AS q
                WHERE q.[QueueId] = @QueueId AND q.[QueueStatusCode] = 'FAILED_PERMANENT'
            )
            BEGIN
                DELETE FROM @Conditions;
                INSERT INTO @Conditions ([ApplicationId], [ExceptionReasonCode], [IsPresent], [DetailCode], [SourceHash])
                SELECT
                    a.[ApplicationId], 'OUTBOUND_WRITE_FAILURE' AS [ExceptionReasonCode], 1 AS [IsPresent],
                    CONCAT('ERROR:', @ErrorNumber) AS [DetailCode], a.[SourceHash]
                FROM [staging].[Applicant] AS a
                WHERE a.[ApplicationId] = @ApplicationId;

                EXEC [integration].[usp_RecordExceptionConditions]
                    @BatchId = @BatchId, @Conditions = @Conditions, @RaisedBy = N'integration.usp_ProcessOutboundQueue';
            END;
        END CATCH;
    END;

    IF @Failed > 0
    BEGIN
        SET @Message = CONCAT(
            @Failed, N' of ', @Attempted, N' outbound writes failed in batch ', @BatchId,
            N'; see audit.ErrorLog and integration.OutboundStudentQueue.LastErrorLogId.'
        );
        THROW 50300, @Message, 1;
    END;
END;
