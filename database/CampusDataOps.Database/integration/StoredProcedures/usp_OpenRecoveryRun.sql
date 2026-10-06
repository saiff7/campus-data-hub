-- Opens a recovery run for a FAILED nightly run, resuming at @ResumeAtStepCode
-- (docs/runbooks/failed-job-recovery.md). The new run is linked by RecoveryOfBatchId (at most
-- one recovery per failed run, database-enforced) and the steps before the recovery point are
-- recorded as SKIPPED, so the audit trail shows exactly what the recovery did and did not
-- repeat. Every step works from database state, so any step is a safe recovery point.
CREATE PROCEDURE [integration].[usp_OpenRecoveryRun]
    @FailedBatchId    BIGINT,
    @ResumeAtStepCode VARCHAR (20),
    @BatchId          BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ResumeOrder SMALLINT;
    DECLARE @NowUtc DATETIME2 (3) = SYSUTCDATETIME();
    DECLARE @Message NVARCHAR (400);

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1
            FROM [audit].[BatchRun] AS br
            WHERE br.[BatchId] = @FailedBatchId
              AND br.[ProcessName] = 'NIGHTLY_INTEGRATION'
              AND br.[BatchStatusCode] = 'FAILED'
        )
        BEGIN
            SET @Message = CONCAT(N'Batch ', @FailedBatchId, N' is not a FAILED NIGHTLY_INTEGRATION run.');
            THROW 50510, @Message, 1;
        END;

        IF EXISTS (SELECT 1 FROM [audit].[BatchRun] AS br WHERE br.[RecoveryOfBatchId] = @FailedBatchId)
        BEGIN
            SET @Message = CONCAT(N'Batch ', @FailedBatchId, N' already has a recovery run; recover that run instead.');
            THROW 50512, @Message, 1;
        END;

        SET @ResumeOrder = (SELECT ps.[StepOrder] FROM [reference].[PipelineStep] AS ps WHERE ps.[StepCode] = @ResumeAtStepCode);
        IF @ResumeOrder IS NULL
        BEGIN
            SET @Message = CONCAT(N'Unknown pipeline step ', ISNULL(@ResumeAtStepCode, N'NULL'), N'.');
            THROW 50511, @Message, 1;
        END;

        BEGIN TRANSACTION;

        EXEC [audit].[usp_LogBatchStart]
            @ProcessName = 'NIGHTLY_INTEGRATION', @BatchId = @BatchId OUTPUT, @RecoveryOfBatchId = @FailedBatchId;

        INSERT INTO [audit].[BatchStep] (
            [BatchId], [StepName], [StepOrder], [AttemptNumber], [BatchStepStatusCode], [StartedAtUtc], [EndedAtUtc], [RowsAffected]
        )
        SELECT
            @BatchId AS [BatchId], ps.[StepCode] AS [StepName], ps.[StepOrder], 1 AS [AttemptNumber],
            'SKIPPED' AS [BatchStepStatusCode], @NowUtc AS [StartedAtUtc], @NowUtc AS [EndedAtUtc], 0 AS [RowsAffected]
        FROM [reference].[PipelineStep] AS ps
        WHERE ps.[StepOrder] < @ResumeOrder;

        COMMIT TRANSACTION;

        SELECT @BatchId AS [BatchId];
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        EXEC [audit].[usp_LogError] @BatchId = @FailedBatchId;

        THROW;
    END CATCH;
END;
